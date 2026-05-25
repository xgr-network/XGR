# XGR Chain — Networking & P2P

**Document ID:** XGRCHAIN-NETWORKING-P2P  
**Last updated:** 2026-05-24  
**Audience:** Node operators, validator operators, RPC operators, infrastructure engineers  
**Release baseline:** `xgr-node` release tag `v2.0.5`  
**Mainnet genesis source:** `xgr-network/XGR` branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Public XGR Chain networking and P2P operation

---

## 1. Scope

This document describes the P2P networking layer used by XGR Chain nodes.

It covers:

- libp2p host setup
- node identity
- network key handling
- bootnodes
- peer discovery
- routing table behavior
- dial queue behavior
- connection limits
- NAT and DNS advertisement
- gossipsub
- transaction gossip
- protocol streams
- peer events
- networking metrics
- operator checks
- firewall and port guidance
- bootnode operation
- common failure modes
- P2P security guidance

This document does not define:

- validator onboarding commands
- staking commands
- JSON-RPC endpoint schemas
- XDaLa behavior
- XRC standards
- UI behavior

Node startup examples are provided in the node-operation runbook.

---

## 2. Networking overview

XGR Chain uses a libp2p-based networking layer.

The networking layer provides:

| Function | Purpose |
|---|---|
| Node identity | Stable peer ID derived from the node network key |
| Secure transport | libp2p Noise security |
| Peer discovery | Bootnode and peer-set based discovery |
| Peer routing | Kademlia-style routing table |
| Peer connection management | Inbound/outbound connection limits and dial queue |
| PubSub | Gossipsub message propagation |
| Transaction gossip | Propagation of validated txpool transactions |
| Protocol streams | Registered protocol handlers over libp2p streams |
| Metrics | Peer and connection metrics |

Consensus, block propagation and transaction propagation depend on a healthy P2P layer.

A node can be process-healthy and still network-unhealthy if it has no useful peers.

---

## 3. Mainnet bootnode

The published mainnet genesis contains this bootnode:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes:

- help new nodes discover peers
- provide stable initial connectivity
- should be reachable
- should keep stable network keys
- should be monitored
- do not grant validator authority
- do not define consensus membership

A node can discover peers through a bootnode and still not be a validator.

---

## 4. libp2p host

The network server creates a libp2p host with:

- Noise security
- TCP listen address
- configured libp2p identity key
- address factory for NAT/DNS advertisement
- gossipsub PubSub instance
- event emitter for peer events
- dial queue for outbound connections
- protocol stream registration

Default libp2p port:

```text
1478
```

Default local listen address:

```text
127.0.0.1:1478
```

Production nodes that should accept external P2P connections normally bind to:

```bash
--libp2p 0.0.0.0:1478
```

If a node binds only to:

```text
127.0.0.1:1478
```

remote peers cannot connect to it over the public network.

---

## 5. Node identity

Each node has a libp2p network key.

The network key determines the node peer ID.

The networking server loads the key from the configured secrets manager.

If the network key is missing, the node generates and stores a new networking private key.

Operational meaning:

- changing the network key changes the peer ID
- bootnode multiaddrs include peer IDs
- published bootnode addresses depend on stable peer IDs
- stale peer IDs break discovery
- validator and bootnode identities should remain stable
- the network key is infrastructure-critical

Example multiaddr:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

The `/p2p/...` component is the peer ID.

---

## 6. Network key handling

The network key is separate from validator signing material.

| Key type | Purpose |
|---|---|
| Network key | Determines libp2p peer identity |
| Validator key | Used for consensus participation |
| Account key | Used for normal account signing |

Operational rules:

- do not delete the network key on bootnodes
- do not rotate bootnode network keys casually
- do not reuse temporary local keys for production infrastructure
- back up stable infrastructure node identities where required
- protect validator keys more strictly than normal network keys
- never share one data directory between multiple running node processes

A changed peer ID means other nodes see the node as a different peer.

For bootnodes, this invalidates the published multiaddr.

---

## 7. Bootnode startup behavior

When discovery is enabled, the networking server reads bootnodes from the chain configuration.

Startup behavior:

| Condition | Behavior |
|---|---|
| Discovery enabled and bootnodes field missing | Startup fails with bootnode configuration error |
| Discovery enabled and bootnodes list empty | Startup fails because at least one bootnode is required |
| Discovery disabled with `--no-discover` | Bootnode discovery setup is skipped |

Minimum configured bootnodes when discovery is enabled:

```text
1
```

This is a startup requirement for discovery setup.

It does not mean a node needs to stay permanently connected to exactly one bootnode.

---

## 8. Peer discovery

Peer discovery is handled by the discovery service.

It maintains a Kademlia-style routing table and periodically asks peers for peer sets.

Code-level discovery parameters:

| Parameter | Value | Meaning |
|---|---:|---|
| `maxDiscoveryPeerReqCount` | `16` | Maximum peers requested from another peer |
| `peerDiscoveryInterval` | `5 seconds` | Interval for querying regular peers |
| `bootnodeDiscoveryInterval` | `60 seconds` | Interval for querying bootnodes |
| `MinimumPeerConnections` | `1` | Minimum peer count keepalive target |
| `defaultBucketSize` | `20` | Kademlia bucket size |

Discovery flow:

1. connect to configured bootnodes
2. add bootnodes to peer store and routing table
3. periodically query connected peers for peer sets
4. periodically query bootnodes for peer sets
5. add discovered peers to the peer store
6. add discovered peers to the routing table
7. dial peers when outbound slots are available
8. remove disconnected or failed peers from the routing table

Discovery is continuous while the node is running.

---

## 9. Discovery disable mode

Discovery can be disabled with:

```bash
--no-discover
```

When discovery is disabled:

- bootnode parsing/discovery setup is skipped
- the node does not actively discover peers through the discovery service
- manual peer connections or controlled infrastructure connectivity become more important
- peer connectivity depends on explicit joins, existing peerstore data or managed topology

Use this only when the node topology is intentionally managed.

Common use cases:

- controlled internal deployments
- isolated test networks
- manually connected infrastructure
- debugging peer behavior

For normal public network participation, discovery should generally remain enabled.

---

## 10. Peer routing

The discovery service maintains a Kademlia-style routing table.

The routing table is used to:

- track known peers
- select peers to query
- provide near-peer responses
- remove failed or disconnected peers
- support peer discovery over time

Routing table state is operationally important but not consensus state.

Nodes may temporarily have different peer routing tables while still following the same chain.

---

## 11. Dial queue

The networking server uses an asynchronous dial queue.

Peers can be added to the dial queue from:

- bootnode discovery
- regular peer discovery
- manual join requests
- keepalive logic

Dialing is asynchronous.

The server waits for available outbound connection slots before dialing.

Connection attempts can fail because of:

- unreachable peer address
- wrong advertised address
- firewall restrictions
- remote node offline
- connection limit reached
- protocol mismatch
- network timeout

Relevant log signal:

```text
failed to dial
```

A few failed dials are normal.

Repeated failed dials against the same peer usually indicate address, firewall or reachability problems.

---

## 12. Connection limits

Default connection configuration:

| Setting | Default |
|---|---:|
| `MaxPeers` | `40` |
| `MaxInboundPeers` | `32` |
| `MaxOutboundPeers` | `8` |

Relevant server flags:

```text
--max-peers
--max-inbound-peers
--max-outbound-peers
```

Operational guidance:

- validators need stable connectivity to other validators and enough peers for propagation
- public RPC nodes may use different peer limits than validators
- too few outbound peers can slow recovery after disconnects
- too many peers can increase CPU, memory and bandwidth usage
- connection limits should match machine size and network role

Recommended starting point:

| Role | Suggested approach |
|---|---|
| Validator | Keep defaults unless monitoring shows peer instability |
| Full node | Defaults are usually sufficient |
| Public RPC node | Increase only if traffic/indexing workload requires it |
| Bootnode | Tune based on expected discovery load and host resources |

---

## 13. Inbound and outbound connections

The network server tracks connection direction.

| Direction | Meaning |
|---|---|
| Inbound | Remote peer connected to this node |
| Outbound | This node dialed the remote peer |

Both matter.

A node with only inbound connections may still function, but outbound capacity is important for active discovery and recovery.

A node with only outbound connections may follow the network, but other peers may not be able to discover or connect to it if its advertised address is wrong.

Healthy production nodes should normally have a mix of useful inbound and outbound connectivity, depending on role.

---

## 14. NAT and DNS advertisement

The node can advertise a different address than its bind address.

Relevant flags:

```text
--nat
--dns
```

Use `--nat` when the node binds locally but should advertise a public IP.

Example:

```bash
--libp2p 0.0.0.0:1478 --nat 203.0.113.10
```

Use `--dns` when a DNS multiaddr should be advertised.

Correct advertisement is critical.

If a node advertises an unreachable address:

- discovery may still find the peer
- peers may still store the peer
- actual connection attempts may fail
- the node may appear unstable or unreachable

NAT/DNS advertisement does not change the local bind interface.

The local bind address is controlled by:

```text
--libp2p
```

---

## 15. Bind address vs advertised address

The bind address controls where the node listens.

Example:

```bash
--libp2p 0.0.0.0:1478
```

The advertised address controls what other peers are told to dial.

Example:

```bash
--nat 203.0.113.10
```

These are different concepts.

| Concept | Controlled by | Example |
|---|---|---|
| Local listen interface | `--libp2p` | `0.0.0.0:1478` |
| Advertised public IP | `--nat` | `203.0.113.10` |
| Advertised DNS multiaddr | `--dns` | DNS-based multiaddr |

Common mistake:

```text
Node listens locally but advertises an unreachable address.
```

Result:

```text
Other peers discover the node but fail to connect.
```

---

## 16. Gossipsub and transaction gossip

The network server creates a gossipsub PubSub instance.

Relevant internal queue settings:

| Setting | Value |
|---|---:|
| Peer outbound queue size | `1024` |
| Validation queue size | `1024` |

Transaction gossip uses validated txpool transactions.

Important boundaries:

- P2P propagation does not make an invalid transaction valid
- txpool admission is local node policy plus protocol validation
- peers may reject transactions that another node accepted
- public RPC submission and P2P propagation are separate layers

If transaction propagation is weak, check:

- peer count
- txpool logs
- firewall rules
- node sync state
- advertised address
- network congestion

---

## 17. Protocol streams

The networking layer supports protocol streams over libp2p.

Protocol streams are used for internal node-to-node communication.

The discovery service uses a discovery gRPC client over peer protocol streams.

Operators usually do not interact with protocol streams directly.

Protocol-stream failures can appear operationally as:

- failed peer discovery
- failed peer queries
- repeated dial errors
- missing peers despite bootnodes
- disconnect churn

---

## 18. Peer events

The discovery service reacts to peer events.

On peer connected:

```text
add peer to routing table
```

On peer disconnected or failed to connect:

```text
remove peer from routing table
```

This keeps the routing table aligned with live connectivity.

Peer events are operational signals, not consensus messages.

---

## 19. Network metrics

The node exposes network-related metrics when metrics are enabled.

Useful operator signals:

| Signal | Meaning |
|---|---|
| Peer count | Whether node has network connectivity |
| Inbound peer count | Whether peers can reach this node |
| Outbound peer count | Whether this node can dial peers |
| Bootnode connection count | Whether bootnode connectivity exists |
| Dial failures | Address/firewall/reachability problems |
| Disconnect rate | Peer instability |
| Block propagation delay | Network or consensus health issue |
| Tx propagation delay | P2P or txpool issue |

For metrics setup, use the node-operation runbook.

---

## 20. Operator startup examples

Full node:

```bash
/opt/xgr/bin/xgrchain server   --chain /etc/xgr/genesis.json   --data-dir /var/lib/xgr/node   --libp2p 0.0.0.0:1478   --nat <PUBLIC_IP>   --jsonrpc 127.0.0.1:8545   --grpc-address 127.0.0.1:9632   --seal=false
```

Validator node:

```bash
/opt/xgr/bin/xgrchain server   --chain /etc/xgr/genesis.json   --data-dir /var/lib/xgr/validator   --libp2p 0.0.0.0:1478   --nat <PUBLIC_IP>   --jsonrpc 127.0.0.1:8545   --grpc-address 127.0.0.1:9632   --seal=true
```

The `--libp2p` value is the listen address.

The `--nat` value is the advertised public IP.

---

## 21. Firewall guidance

Typical ports:

| Interface | Typical port | Recommended exposure |
|---|---:|---|
| libp2p | `1478` | Public or allowlisted |
| JSON-RPC | `8545` | Local/private; public only behind proxy |
| gRPC | `9632` | Local/private |
| Prometheus | operator-defined | Monitoring network only |
| SSH | `22` or custom | Admin IPs only |

Validator firewall baseline:

| Port | Source | Action |
|---:|---|---|
| P2P `1478` | network peers | allow |
| JSON-RPC `8545` | localhost/private management network | allow |
| gRPC `9632` | localhost/private management network | allow |
| Metrics | monitoring network | allow |
| SSH | admin IPs | allow |
| Everything else | public internet | deny |

Public RPC nodes should expose HTTP/WebSocket through a reverse proxy, not directly through validator nodes.

---

## 22. Bootnode operation

A bootnode should:

- keep stable network identity
- keep stable public address
- keep stable P2P port
- run with correct published genesis
- keep P2P port reachable
- be monitored
- avoid unnecessary restarts
- avoid public RPC exposure unless intentionally configured

A bootnode does not need validator key material.

A bootnode should not be confused with a validator.

Published bootnode changes require updating the published genesis/configuration and operator docs.

---

## 23. Common failure modes

### 23.1 Node has zero peers

Likely causes:

- P2P port blocked
- wrong `--nat` address
- wrong `--dns` address
- bootnode unreachable
- wrong genesis/configuration
- discovery disabled unintentionally
- no outbound slots available
- cloud firewall denies traffic
- host firewall denies traffic

Check:

```bash
curl -s -X POST http://127.0.0.1:8545   -H 'content-type: application/json'   --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

### 23.2 Peers discover node but cannot connect

Likely cause:

```text
advertised address is unreachable
```

Check:

```text
--libp2p
--nat
--dns
cloud firewall
host firewall
public IP
```

### 23.3 Node syncs slowly

Likely causes:

- low peer count
- high latency peers
- disk bottleneck
- CPU saturation
- bad outbound connectivity
- RPC load on same node
- logs/debug overload

### 23.4 Validator misses participation

Likely causes:

- P2P instability
- low peer count
- validator not active
- node not synced
- signer/key problem
- repeated round changes
- host overload

P2P is necessary but not sufficient for validator participation.

Validator status must be checked through PoS and consensus state.

---

## 24. Security guidance

- keep validator nodes separate from public RPC nodes
- restrict validator JSON-RPC and gRPC to local/private networks
- use firewalls
- restrict SSH
- keep network keys stable on bootnodes
- back up network keys where peer identity stability matters
- protect validator keys more strictly than network keys
- monitor peer count and disconnect churn
- do not expose debug/tracing endpoints publicly
- do not share data directories between running nodes

---

## 25. Summary

| Topic | XGR Chain v2.0.5 behavior |
|---|---|
| P2P implementation | libp2p |
| Transport security | Noise |
| Default libp2p port | `1478` |
| Default bind address | `127.0.0.1:1478` |
| Production bind example | `0.0.0.0:1478` |
| Mainnet bootnode | `/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck` |
| Discovery default | enabled |
| Disable discovery | `--no-discover` |
| Minimum bootnodes when discovery enabled | `1` |
| Max peers default | `40` |
| Max inbound peers default | `32` |
| Max outbound peers default | `8` |
| Regular discovery interval | `5 seconds` |
| Bootnode discovery interval | `60 seconds` |
| Max discovery peer request count | `16` |
| Gossipsub outbound queue | `1024` |
| Gossipsub validation queue | `1024` |
