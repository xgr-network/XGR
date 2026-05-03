# XGR Chain — Networking & P2P

**Document ID:** XGRCHAIN-NETWORKING-P2P  
**Last updated:** 2026-05-03  
**Audience:** Node operators, validator operators, infrastructure engineers, protocol developers  
**Implementation status:** Current public baseline  
**Source of truth:** Public `xgr-network/xgr-node` releases, published XGR Chain genesis configuration, and official XGR Network operator announcements

---

## 1. Scope

This document describes the P2P networking layer used by XGR Chain nodes.

It covers:

- libp2p host setup
- node identity
- network keys
- peer discovery
- bootnodes
- peer routing
- dial queue behavior
- connection limits
- NAT and DNS advertisement
- gossipsub
- transaction gossip
- protocol streams
- peer events
- network metrics
- operator checks
- firewall and port guidance
- bootnode operation
- common failure modes
- P2P security guidance

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
| Metrics | Peer count and connection count metrics |

Consensus, block propagation and transaction propagation depend on a healthy P2P layer.

A node can be locally healthy at the process level while still operationally unhealthy if it has no useful peers.

---

## 3. libp2p host

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

For production nodes that should accept external P2P connections, the libp2p listen address usually needs to bind to a reachable interface:

```bash
--libp2p 0.0.0.0:1478
```

If the node binds only to `127.0.0.1:1478`, remote peers cannot connect to it over the public network.

---

## 4. Node identity

Each node has a libp2p network key.

The network key determines the node's peer ID.

The networking server loads the key from the configured secrets manager.

If the key is missing, the node can generate and store a new networking private key.

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

## 5. Network key handling

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
- never share a validator data directory between multiple running nodes

A changed peer ID means other nodes will see the node as a different peer.

For bootnodes, this invalidates the published multiaddr.

---

## 6. Bootnodes

Bootnodes are stable peers used for initial peer discovery.

They are configured in the published chain configuration.

Published mainnet bootnode:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes:

- help new nodes discover peers
- provide stable initial connectivity
- should be reachable
- should have stable network keys
- should be monitored
- should not be confused with validator authority

Bootnodes do not grant validator rights.

A node can discover peers through a bootnode and still not be a validator.

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

Important discovery parameters:

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

When a peer connects, it can be added to the routing table.

When a peer disconnects or fails to connect, it can be removed.

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

Relevant log message:

```text
failed to dial
```

A few failed dials are normal.

Repeated failed dials against the same peer usually indicate an address, firewall or reachability problem.

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

- validators need stable connectivity to other validators and enough non-validator peers for propagation
- public RPC nodes may use different peer limits than validator nodes
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

A node with only outbound connections may follow the network, but other peers may not be able to discover or connect to it effectively if its advertised address is wrong.

Healthy production nodes should normally have a mix of useful inbound and outbound connectivity, depending on their role.

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

The local bind address is still controlled by:

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

## 16. Gossipsub

XGR Chain uses libp2p gossipsub for decentralized message propagation.

The network server initializes gossipsub with:

| Setting | Value |
|---|---:|
| Peer outbound queue size | `1024` |
| Validation queue size | `1024` |

Purpose:

- buffer outbound messages per peer
- buffer validation work
- avoid unbounded memory growth
- allow message propagation under normal network load

If outbound or validation queues saturate:

- messages can be dropped
- validation can be throttled
- propagation can degrade
- peers may see delayed transaction or block information

Persistent saturation indicates that the node is overloaded or under-provisioned.

---

## 17. Transaction gossip

The TxPool uses the network PubSub layer to broadcast transactions.

TxPool topic:

```text
txpool/0.1
```

Transaction gossip flow:

1. local transaction enters the TxPool
2. transaction passes txpool validation
3. if networking topic is available, the transaction is published
4. peers receive the gossiped transaction
5. receiving nodes decode the transaction
6. receiving nodes validate it locally
7. valid transactions enter the receiving node's txpool

Transaction gossip does not bypass validation.

Every node validates incoming transactions independently.

A transaction can be gossiped and still be rejected by a peer because of:

- underpriced fee
- invalid signature
- wrong chain ID
- nonce too low
- insufficient funds
- intrinsic gas failure
- block gas limit exceeded
- unsupported transaction type
- txpool pressure

---

## 18. Protocol streams

The network server can register named protocols over libp2p streams.

A protocol provides:

- client constructor
- stream handler

Registered protocols allow internal node modules to communicate with peers using structured streams over libp2p.

Discovery itself uses a discovery protocol to request peer sets from other peers.

Protocol streams are internal node networking infrastructure.

They are not JSON-RPC APIs.

---

## 19. Peer events

The networking layer emits peer events.

Relevant event categories include:

| Event | Meaning |
|---|---|
| Peer added to dial queue | Node plans to dial the peer |
| Peer connected | Peer connection established |
| Peer failed to connect | Dial attempt failed |
| Peer disconnected | Existing connection closed |

Peer events are used internally by:

- dial manager
- discovery service
- connection metrics
- peer table cleanup
- operational logging

Operators see the practical effects through logs and metrics.

Important log messages include:

```text
LibP2P server running
Join request
failed to dial
Peer disconnected
unable to parse bootnode data
unable to setup discovery
```

---

## 20. Network metrics

Network metrics use the `network` prefix.

Important metric themes:

| Metric theme | Meaning |
|---|---|
| peer count | Current connected peer count |
| inbound connection count | Active inbound connections |
| outbound connection count | Active outbound connections |
| pending inbound connections | Inbound connections in progress |
| pending outbound connections | Outbound connections in progress |

Operators should monitor:

- sustained low peer count
- repeated peer disconnects
- outbound connection starvation
- bootnode connectivity failure
- high pending connection count
- frequent failed dials
- sudden peer churn
- validator isolation
- network latency spikes

A validator with poor peer connectivity may miss consensus messages even if the local node process is running.

---

## 21. Operator checks

### 21.1 Check peer count

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

A healthy value depends on network size and topology.

Persistent zero peers is a problem unless the node is intentionally isolated.

### 21.2 Check whether node reports listening

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_listening","params":[]}'
```

This verifies RPC-level network listening status.

It does not by itself prove that the node has useful peer connectivity.

### 21.3 Check local socket

```bash
ss -lntp | grep 1478
```

Expected for a production P2P node:

```text
0.0.0.0:1478
```

or a specific externally reachable interface.

If the node only listens on `127.0.0.1:1478`, remote peers cannot connect.

### 21.4 Check logs

Useful log patterns:

```text
LibP2P server running
Peer disconnected
Join request
failed to dial
unable to setup discovery
unable to parse bootnode data
Omitting bootnode with same ID as host
```

Use these logs together with peer count and firewall checks.

---

## 22. Firewall and port guidance

Typical ports:

| Interface | Example | Exposure |
|---|---:|---|
| libp2p | `1478` | Reachable according to node role and network topology |
| JSON-RPC | `8545` | Local/private or public behind controlled gateway |
| gRPC | `9632` | Internal only |
| Prometheus | `9090` | Internal monitoring only |

Validator nodes should expose only what is necessary.

Recommended validator posture:

- expose libp2p as required by the network topology
- keep JSON-RPC private
- keep gRPC private
- keep Prometheus private
- keep debug RPC private
- avoid public RPC workloads on validators

Recommended public RPC posture:

- expose JSON-RPC through a reverse proxy or gateway
- keep libp2p reachable if the node participates in P2P
- keep gRPC private
- keep debug private
- apply rate limits
- monitor peer count and RPC load separately

---

## 23. Bootnode operation

Bootnodes should be:

- stable
- highly available
- reachable from validator and full nodes
- monitored
- configured with stable network keys
- operated with predictable network addresses
- protected from unnecessary key rotation
- sized for expected discovery traffic

Bootnodes do not need validator signing material.

Bootnodes do not need to seal blocks.

Bootnodes should generally run with:

```bash
--seal=false
```

when they are not validators.

Do not rotate bootnode network keys casually.

A rotated network key changes the peer ID and invalidates the published multiaddr.

---

## 24. Validator networking

Validators require reliable P2P connectivity.

A validator should have:

- stable network key
- stable advertised address
- reachable libp2p port
- sufficient peers
- low peer churn
- low network latency to other validators
- enough outbound connection capacity
- firewall configuration consistent with P2P requirements
- monitoring for peer count and consensus health

Validator networking problems can cause:

- missed proposals
- delayed message propagation
- round changes
- temporary isolation
- poor validator performance
- block production stalls if enough validators are affected

A running validator process is not enough.

The validator must also be connected to the validator network.

---

## 25. Full node and RPC node networking

Full nodes and RPC nodes need enough peer connectivity to follow the chain and serve accurate data.

A public RPC node should:

- maintain stable P2P connectivity
- avoid serving stale chain data
- monitor peer count
- monitor sync state
- monitor block height
- separate public HTTP traffic from P2P health
- avoid validator key material
- avoid unnecessary sealing

Recommended non-validator setting:

```bash
--seal=false
```

A public RPC node with zero peers may still answer JSON-RPC requests, but its chain data may be stale or useless.

---

## 26. Manual peer joining

The networking server supports manual peer join behavior internally.

Manual joins add a peer to the dial queue.

This is useful for:

- controlled infrastructure
- recovery from discovery issues
- test networks
- operator diagnostics
- static peer topologies

Manual joining does not override protocol compatibility.

A manually joined peer still needs:

- reachable multiaddr
- correct peer ID
- compatible network
- compatible genesis/configuration
- available connection slots

---

## 27. Common failure modes

### 27.1 Node has zero peers

Likely causes:

- bootnode unreachable
- wrong bootnode peer ID
- firewall blocks libp2p port
- cloud security group blocks libp2p port
- wrong NAT/DNS advertised address
- discovery disabled
- peer limits set too low
- incompatible genesis/configuration
- node only binds to localhost
- remote peers cannot dial advertised address

Checks:

```bash
ss -lntp | grep 1478
```

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

---

### 27.2 Peers connect then disconnect

Likely causes:

- unstable network
- protocol mismatch
- genesis/configuration mismatch
- incompatible release
- connection limits reached
- remote peer restart
- NAT misconfiguration
- duplicate or unstable node identity
- overloaded host

Check:

- node version
- genesis configuration
- peer count
- logs around disconnects
- firewall state
- CPU and memory
- disk I/O
- system clock

---

### 27.3 Transactions do not propagate

Likely causes:

- txpool validation rejection
- peer count too low
- gossipsub topic unavailable
- node not connected to transaction-propagating peers
- transaction underpriced
- wrong chain ID
- invalid nonce
- insufficient funds
- max txpool slots reached
- public RPC node is isolated

Check:

```text
txpool_status
txpool_content
net_peerCount
eth_blockNumber
```

Transaction gossip never bypasses txpool validation.

---

### 27.4 Validator misses consensus messages

Likely causes:

- insufficient peer connectivity
- validator isolated from other validators
- high latency
- overloaded CPU
- slow disk
- unstable network
- network key or peer ID mismatch
- firewall/NAT issue
- connection churn
- incorrect advertised address

Actions:

- verify peer count
- verify libp2p bind address
- verify NAT/DNS advertisement
- verify firewall rules
- check validator logs
- check consensus round changes
- check host resource pressure
- compare local block height with trusted reference

---

### 27.5 Bootnode unreachable

Likely causes:

- bootnode offline
- bootnode port blocked
- bootnode peer ID changed
- bootnode IP changed
- published multiaddr stale
- upstream firewall/security group issue
- DNS issue where DNS advertisement is used

Actions:

- verify bootnode process health
- verify bootnode `1478` reachability
- verify bootnode peer ID
- verify published multiaddr
- verify cloud firewall
- verify host firewall
- check bootnode logs

---

### 27.6 Node advertises wrong address

Symptoms:

- node can dial others
- others cannot dial the node
- peer count unstable
- repeated failed inbound connectivity
- node appears in peer lists but cannot be reached

Likely causes:

- wrong `--nat`
- wrong `--dns`
- public IP changed
- cloud NAT mismatch
- local bind address wrong
- firewall allows outbound but blocks inbound

Fix:

- verify public IP
- update `--nat`
- verify DNS multiaddr
- verify `--libp2p`
- restart node
- monitor peer count

---

## 28. Security guidance

P2P security rules:

- protect the network key
- protect validator key material separately
- do not share validator data directories
- do not reuse temporary local keys in production
- keep libp2p reachable only as intended
- monitor unexpected peer churn
- treat bootnode keys as infrastructure-critical
- isolate validator nodes from public RPC workloads
- use OS firewalls
- use cloud security groups
- keep host OS patched
- monitor failed dials and repeated disconnects
- do not expose gRPC publicly
- do not expose debug RPC publicly

The P2P network is not a substitute for validator key security.

A compromised validator key is a consensus/security issue independent of libp2p connectivity.

---

## 29. Operational checklist

Before starting a production node:

- published genesis configuration is installed
- libp2p bind address is intentional
- public P2P nodes bind to a reachable interface
- NAT/DNS advertisement is correct
- firewall allows intended P2P traffic
- bootnode list is present when discovery is enabled
- network key is stable
- validator key is separate from network key
- peer limits are appropriate for the node role
- discovery mode is intentional
- public RPC is separated from validator operation where possible
- monitoring covers peer count
- monitoring covers block height
- monitoring covers disconnect rate
- monitoring covers CPU, memory, disk and network
- logs are checked for failed dials and discovery errors

Recommended production P2P baseline:

```bash
--libp2p 0.0.0.0:1478
```

Recommended non-validator baseline:

```bash
--seal=false
```

Use `--nat` or `--dns` when the node must advertise an address different from its bind address.

---

## 30. Summary

| Category | Current baseline |
|---|---|
| P2P stack | libp2p |
| Transport security | Noise |
| Default P2P port | `1478` |
| Default bind address | `127.0.0.1:1478` |
| Production bind example | `0.0.0.0:1478` |
| Discovery default | enabled |
| Minimum configured bootnodes when discovery is enabled | `1` |
| Published mainnet bootnode count | `1` |
| Max peers default | `40` |
| Max inbound peers default | `32` |
| Max outbound peers default | `8` |
| Discovery peer request max | `16` |
| Regular peer discovery interval | `5 seconds` |
| Bootnode discovery interval | `60 seconds` |
| Gossipsub peer outbound queue | `1024` |
| Gossipsub validation queue | `1024` |
| TxPool gossip topic | `txpool/0.1` |
| Network metrics prefix | `network` |

Healthy P2P networking is required for reliable chain operation.

Validators need stable connectivity for consensus.

Full and RPC nodes need stable connectivity to follow the chain and serve accurate data.
