# XGR Chain — Networking & P2P

**Document ID:** XGRCHAIN-NETWORKING-P2P  
**Last updated:** 2026-05-03  
**Audience:** Node operators, validator operators, infrastructure engineers, protocol developers  
**Implementation status:** Mainnet  
**Source of truth:** `xgrchain/network`, `xgrchain/txpool`, `genesis/mainnet/genesis.json`

---

## 1. Scope

This document describes the **P2P networking layer** used by XGR Chain nodes.

It covers:

- libp2p host setup
- node identity
- peer discovery
- bootnodes
- peer routing
- gossipsub
- transaction gossip
- network flags
- connection limits
- metrics
- operational and security guidance

This document does **not** define:

- IBFT consensus rules
- staking / PoS validator selection
- JSON-RPC APIs
- XDaLa Engine endpoints
- bridge/rootchain/Supernet networking

Those topics are documented separately.

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
| Peer connection management | inbound/outbound connection limits and dial queue |
| PubSub | gossipsub message propagation |
| Protocol streams | registered protocol handlers over libp2p streams |
| Metrics | peer count and connection count metrics |

Consensus, block propagation and transaction propagation depend on a healthy p2p layer.

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

Default libp2p port:

```text
1478
```

Default local listen address:

```text
127.0.0.1:1478
```

For production nodes, the libp2p listen address usually needs to bind to a reachable interface:

```bash
--libp2p 0.0.0.0:1478
```

---

## 4. Node identity

Each node has a libp2p network key.

The network key determines the node's peer ID.

The networking server loads the key from the configured secrets manager. If the key is missing, it can generate and store a new networking private key.

Operationally:

- validator node identity must remain stable
- changing the network key changes the peer ID
- bootnode multiaddrs include peer IDs
- stale peer IDs in bootnodes or configs break discovery

Example multiaddr:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

---

## 5. Bootnodes

Bootnodes are stable peers used for initial discovery.

They are configured in genesis / chain configuration:

```json
{
  "bootnodes": [
    "/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck"
  ]
}
```

Bootnodes:

- help new nodes discover peers
- do not grant validator rights
- do not define consensus authority
- should be stable and reachable
- should not be confused with validators

Minimum bootnodes required when discovery is enabled:

```text
1
```

If discovery is enabled and no bootnodes are configured, startup can fail with a bootnode configuration error.

---

## 6. Peer discovery

Peer discovery is handled by the discovery service.

It maintains a Kademlia-style routing table and periodically queries peers for peer sets.

Important discovery parameters:

| Parameter | Value | Meaning |
|---|---:|---|
| `maxDiscoveryPeerReqCount` | 16 | maximum peers requested from another peer |
| `peerDiscoveryInterval` | 5 seconds | interval for querying regular peers |
| `bootnodeDiscoveryInterval` | 60 seconds | interval for querying bootnodes |
| `MinimumPeerConnections` | 1 | minimum peer count keepalive target |
| `defaultBucketSize` | 20 | Kademlia bucket size |

Discovery loop:

1. query connected peers for near peers
2. query bootnodes periodically
3. add discovered peers to peer store and routing table
4. dial peers when outbound slots are available
5. remove disconnected / failed peers from routing table

---

## 7. Discovery disable mode

Discovery can be disabled with:

```bash
--no-discover
```

When discovery is disabled:

- bootnode parsing/discovery is skipped
- the node does not actively discover new peers through the discovery service
- manual peer joining or static connectivity becomes more important

Use this only for controlled local setups or tightly managed infrastructure.

---

## 8. Peer routing and dialing

The networking server uses a dial queue.

Peers can be added to the dial queue from:

- bootnode discovery
- regular peer discovery
- manual join requests
- keepalive logic

Dialing is asynchronous. Connection slots limit how many outbound connections can be opened.

The server tracks:

- connected peers
- inbound connections
- outbound connections
- pending inbound connections
- pending outbound connections
- bootnode connection count
- temporary bootnode dials

---

## 9. Connection limits

Default connection configuration:

| Setting | Default |
|---|---:|
| `MaxPeers` | 40 |
| `MaxInboundPeers` | 32 |
| `MaxOutboundPeers` | 8 |

Relevant server flags:

```text
--max-peers
--max-inbound-peers
--max-outbound-peers
```

Operational recommendation:

- validators need stable connectivity to other validators
- public RPC nodes may need different peer limits than validator nodes
- too few outbound peers can slow recovery after disconnects
- too many peers can increase CPU, memory and bandwidth usage

---

## 10. NAT and DNS advertisement

The node can advertise a different address than its bind address.

Relevant flags:

```text
--nat
--dns
```

Use `--nat` when the node is behind NAT but should advertise a public IP.

Example:

```bash
--libp2p 0.0.0.0:1478 --nat 203.0.113.10
```

Use `--dns` when a DNS multiaddr should be advertised.

Correct advertisement is critical. If peers receive an unreachable address, discovery may appear to work while actual connections fail.

---

## 11. Gossipsub

XGR Chain uses libp2p gossipsub for decentralized message propagation.

The network server initializes gossipsub with:

| Setting | Value |
|---|---:|
| peer outbound queue size | 1024 |
| validation queue size | 1024 |

The purpose is to provide enough buffering for peer message propagation while avoiding unbounded memory growth.

If outbound or validation queues saturate, messages can be dropped or validation can be throttled.

---

## 12. Transaction gossip

The TxPool uses the network PubSub layer to broadcast transactions.

TxPool topic:

```text
txpool/0.1
```

Flow:

1. local transaction enters the TxPool
2. transaction passes txpool validation
3. if networking topic is available, the transaction is published
4. peers receive the gossiped transaction
5. receiving nodes decode and validate before adding it to their own pool

Transaction gossip does not bypass validation. Every node still validates incoming transactions locally.

See also:

- `XGRCHAIN_Node_Operator_RPC_Reference.md`
- `XRC-GAS_Gas_Price_Behavior.md`

---

## 13. Protocol streams

The network server can register named protocols over libp2p streams.

A protocol provides:

- client constructor
- stream handler

Registered protocols allow internal node modules to communicate with peers using structured gRPC-like streams over libp2p.

Discovery itself uses a discovery protocol to request peer sets from other peers.

---

## 14. Peer events

The networking layer emits peer events.

Relevant event categories include:

- peer added to dial queue
- peer connected
- peer failed to connect
- peer disconnected

These events are used internally by:

- dial manager
- discovery service
- connection metrics
- peer table cleanup

Operators see the practical effects through logs and metrics.

---

## 15. Network metrics

Network metrics use the `network` prefix.

Important metric themes:

| Metric theme | Meaning |
|---|---|
| peer count | current connected peer count |
| inbound connection count | active inbound connections |
| outbound connection count | active outbound connections |
| pending inbound connections | inbound connections in progress |
| pending outbound connections | outbound connections in progress |

Operators should monitor:

- sustained low peer count
- repeated peer disconnects
- outbound connection starvation
- bootnode connectivity failure
- high pending connection count
- frequent failed dials

---

## 16. Operator checks

Check peer count through JSON-RPC:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

Check whether node is listening:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_listening","params":[]}'
```

Check logs for:

```text
LibP2P server running
Peer disconnected
Join request
failed to dial
unable to setup discovery
unable to parse bootnode data
```

---

## 17. Firewall and port guidance

Typical ports:

| Interface | Example | Exposure |
|---|---:|---|
| libp2p | `1478` | must be reachable for p2p nodes |
| JSON-RPC | `8545` | restrict or expose via controlled gateway |
| gRPC | `9632` | internal only |
| Prometheus | `9090` | internal monitoring only |

Validator nodes should expose only what is necessary.

Recommended:

- expose libp2p to validator/network peers
- keep gRPC private
- keep Prometheus private
- keep debug RPC private
- avoid exposing validator JSON-RPC publicly
- use dedicated non-validator RPC nodes for public access

---

## 18. Bootnode operation

Bootnodes should be:

- stable
- highly available
- reachable from validator and full nodes
- monitored
- geographically/network-topology distributed where possible
- configured with stable network keys

Bootnodes do not need to seal blocks.

Do not rotate bootnode network keys casually. A rotated key changes the peer ID and invalidates published multiaddrs.

---

## 19. Common failure modes

### Node has zero peers

Likely causes:

- bootnode unreachable
- wrong bootnode peer ID
- firewall blocks libp2p port
- wrong NAT/DNS advertised address
- discovery disabled
- peer limits set too low
- incompatible network/genesis

### Peers connect then disconnect

Likely causes:

- protocol mismatch
- genesis mismatch
- unstable network
- incompatible branch/version
- connection limits reached
- remote peer restart

### Transactions do not propagate

Likely causes:

- txpool validation rejection
- no gossipsub topic
- peer count too low
- node not connected to transaction-propagating peers
- tx underpriced or invalid
- max txpool slots reached

### Validator misses consensus messages

Likely causes:

- insufficient peer connectivity
- validator isolated from other validators
- high latency
- overloaded CPU/disk
- network key or peer ID mismatch
- firewall/NAT issue

---

## 20. Security guidance

P2P security rules:

- protect the network key
- do not share validator data directories
- do not reuse local test keys in production
- keep libp2p reachable only as intended
- monitor unexpected peer churn
- treat bootnode keys as infrastructure-critical
- isolate validator nodes from public RPC workloads
- use OS firewalling and cloud security groups
- keep host OS patched

The P2P network is not a replacement for validator key security. A compromised validator key is a consensus/security issue independent of libp2p connectivity.

---

## 21. Legacy exclusions

The old Polygon Edge networking document referenced Beacon Staking PoS. For XGR, the networking layer must be described independently.

Do not include these as active networking concepts:

| Legacy wording / concept | XGR documentation decision |
|---|---|
| Beacon Staking PoS as the networking context | removed |
| Supernet networking framing | removed |
| Bridge/rootchain networking | not part of this document |
| PolyBFT networking assumptions | not part of this document |
| Rootchain relayer peer flow | not part of this document |

XGR networking is simply the libp2p-based node networking layer used by the chain.

---

## 22. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Node_Operation.md` | Node operation and runtime flags |
| `XGRCHAIN_Consensus_IBFT.md` | Consensus behavior and validator roles |
| `XGRCHAIN_Node_Operator_RPC_Reference.md` | Debug, tracing and txpool internals |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Public Ethereum-compatible RPC |
| `XGRCHAIN_Genesis_and_Configuration.md` | Bootnodes and genesis-level network config |
