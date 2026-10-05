# XGR Chain — Networking & P2P

**Document ID:** XGRCHAIN-NETWORKING-P2P  
**Last updated:** 2026-10-05  
**Audience:** Node operators, validator operators, RPC operators, infrastructure engineers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Public XGRChain node networking and P2P operation

---

## 1. Scope

This document describes the P2P networking layer used by XGRChain nodes.

It covers:

- libp2p host setup,
- node identity,
- network-key handling,
- bootnodes,
- peer discovery,
- routing tables,
- dial queues,
- connection limits,
- inbound/outbound peers,
- NAT and DNS advertisement,
- Gossipsub,
- transaction gossip,
- node protocol streams,
- peer events,
- networking metrics,
- firewall guidance,
- bootnode operation,
- common failure modes,
- P2P security boundaries.

This document does not define:

- validator onboarding,
- staking commands,
- Ethereum JSON-RPC schemas,
- PoS endpoint schemas,
- XDaLa behavior,
- Interchain relayer operation,
- XRC standards.

Node startup and service-management procedures belong to the node-operation runbook.

---

## 2. Networking overview

XGRChain uses a libp2p-based networking stack.

The networking layer provides:

| Function | Purpose |
| --- | --- |
| Node identity | Stable peer ID derived from the node network key |
| Transport security | libp2p Noise |
| Peer discovery | Bootnode and peer-driven discovery |
| Peer routing | Kademlia-style routing table |
| Connection management | Inbound/outbound peer limits and dial queue |
| PubSub | Gossipsub propagation |
| Transaction gossip | Distribution of TxPool transactions |
| Protocol streams | Internal node-to-node services |
| Peer events | Connection-state tracking |
| Metrics | Connectivity and network-health visibility |

Consensus, synchronization, block propagation and transaction propagation depend on healthy P2P connectivity.

A node can therefore be process-healthy while being network-unhealthy.

---

## 3. Mainnet bootnode

The canonical XGRChain mainnet configuration currently contains one bootnode:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes:

- provide initial peer discovery,
- should use stable peer identities,
- should remain reachable,
- should be monitored,
- do not grant validator authority,
- do not define validator membership,
- do not define transaction permissions.

A node can discover XGRChain through a bootnode without being a validator.

---

## 4. libp2p implementation

The `v3.1.1` networking server creates a libp2p host using:

- TCP transport,
- Noise security,
- a persistent libp2p identity key,
- configured listen address,
- optional NAT/DNS address advertisement,
- Gossipsub,
- peer-event handling,
- asynchronous dialing,
- protocol stream registration.

Default P2P port:

```text
1478
```

Default network bind:

```text
127.0.0.1:1478
```

This default is suitable for local-only connectivity but is not sufficient for a publicly reachable production P2P node.

A production node that should accept inbound peers normally uses:

```bash
--libp2p 0.0.0.0:1478
```

---

## 5. Node identity

Each node has a libp2p private network key.

That key determines the node's peer ID.

Relationship:

```text
network private key
        ↓
libp2p identity
        ↓
peer ID
```

Example bootnode multiaddr:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

The final `/p2p/...` component identifies the peer.

If the network key changes:

```text
peer ID changes
```

For infrastructure whose multiaddr is published, changing the network key can therefore invalidate existing discovery references.

---

## 6. Network key versus validator key

The network identity key and validator signing material are separate.

| Key | Purpose |
| --- | --- |
| Network key | libp2p peer identity |
| Validator key | IBFT consensus signing |
| Account key | Normal account/transaction signing |
| Relayer key | External-service transaction submission |

Possession of one does not imply authority associated with another.

For example:

```text
libp2p peer
≠
consensus validator
```

and:

```text
Interchain relayer
≠
consensus validator
```

---

## 7. Network-key handling

Operational rules:

- do not delete production bootnode network keys casually,
- preserve stable identities where published multiaddrs depend on them,
- do not reuse one data directory for multiple simultaneous nodes,
- restrict filesystem access,
- back up persistent network identities where operationally required,
- keep validator signing material under a separate and stricter security boundary.

---

## 8. Discovery startup requirements

Discovery is enabled by default.

The `v3.1.1` network implementation defines:

```text
MinimumBootNodes = 1
```

When discovery is enabled and no bootnodes are configured, startup fails.

Relevant errors include:

```text
no bootnodes specified
```

and:

```text
minimum 1 bootnode is required
```

This requirement applies to discovery-enabled startup.

---

## 9. Disabling discovery

Discovery can be disabled with:

```bash
--no-discover
```

In this mode:

- automatic peer discovery is disabled,
- bootnode-driven discovery is skipped,
- manually controlled/static connectivity becomes more important.

For ordinary XGRChain mainnet operation, discovery should normally remain enabled.

---

## 10. Peer discovery

The discovery service uses a Kademlia-style routing table.

Verified `v3.1.1` values:

| Parameter | Value |
| --- | ---: |
| Maximum requested peers per discovery query | `16` |
| Normal peer discovery interval | `5s` |
| Bootnode discovery interval | `60s` |
| Minimum peer connection target | `1` |
| Routing-table bucket size | `20` |

Conceptual flow:

```text
configured bootnodes
        ↓
initial peer connectivity
        ↓
peer discovery queries
        ↓
peer store
        ↓
routing table
        ↓
dial queue
        ↓
additional peer connections
```

Discovery continues throughout node operation.

---

## 11. Routing table

The discovery service maintains a Kademlia-style routing table.

Current bucket size:

```text
20
```

The routing table helps the node:

- track known connected peers,
- select peers for discovery,
- return nearby peers,
- remove disconnected or failed peers,
- build connectivity over time.

Routing-table contents are node-local operational state.

They are not consensus state.

---

## 12. Peer store

The libp2p peer store retains identity and address information required for connection attempts.

A peer can be:

- known,
- present in the routing table,
- queued for dialing,
- actively connected,
- disconnected.

These states are not equivalent.

For example:

```text
known peer ≠ connected peer
```

Monitoring should therefore focus on live connections rather than only discovered peer records.

---

## 13. Dial queue

The networking server uses an asynchronous dial queue.

Peers can enter connection workflows through:

- bootnode discovery,
- regular discovery,
- routing-table activity,
- manual peer operations,
- minimum-peer recovery behavior.

Connection attempts can fail because of:

- unreachable addresses,
- firewall rules,
- incorrect NAT advertisement,
- remote node downtime,
- connection limits,
- network timeouts,
- incompatible protocol behavior.

Occasional failed dials are normal.

Persistent repeated failures require investigation.

---

## 14. Connection limits

Current `v3.1.1` defaults:

| Setting | Default |
| --- | ---: |
| Maximum peers | `40` |
| Maximum inbound peers | `32` |
| Maximum outbound peers | `8` |

Default composition:

```text
32 inbound
 8 outbound
40 total
```

Relevant runtime controls:

```text
--max-peers
--max-inbound-peers
--max-outbound-peers
```

These are node-local networking limits.

They do not alter XGRChain consensus rules.

---

## 15. Peer-limit guidance

### Validator

Prioritize:

- stable connectivity,
- sufficient outbound recovery paths,
- predictable resource use.

The defaults are a reasonable baseline unless monitoring demonstrates a need for different limits.

### Full node

Defaults are generally sufficient for ordinary synchronization and propagation.

### Public RPC node

Peer limits and application RPC load are separate concerns.

High HTTP/JSON-RPC traffic does not automatically imply that additional P2P peers are required.

### Bootnode

Bootnodes can require different capacity planning because of discovery load, but peer limits should still be tuned from observed resource usage.

---

## 16. Inbound versus outbound connections

| Direction | Meaning |
| --- | --- |
| Inbound | Remote peer dialed this node |
| Outbound | This node dialed the remote peer |

Outbound capacity is important for:

- bootstrapping,
- recovery,
- active discovery.

Inbound connectivity is useful evidence that public advertisement and firewall configuration are functioning.

A node can synchronize using outbound connectivity without accepting public inbound peers.

---

## 17. Bind address

The bind address determines where the local process listens.

Example:

```bash
--libp2p 0.0.0.0:1478
```

Default:

```text
127.0.0.1:1478
```

A node using only the localhost default cannot normally accept connections from external peers.

---

## 18. NAT advertisement

The `--nat` option lets a node advertise a public IPv4 address distinct from its local bind address.

Example:

```bash
--libp2p 0.0.0.0:1478 \
  --nat 203.0.113.10
```

The advertised address uses the configured P2P port.

It must actually be reachable from the public network.

---

## 19. DNS advertisement

The node can alternatively advertise a DNS multiaddr through:

```text
--dns
```

DNS and NAT advertisement are alternative address-factory paths in the current implementation.

Use a stable, externally resolvable DNS name.

---

## 20. Bind versus advertised address

These concepts are distinct.

| Function | Configuration |
| --- | --- |
| Where the process listens | `--libp2p` |
| Public IPv4 advertised to peers | `--nat` |
| DNS multiaddr advertised to peers | `--dns` |

A common failure mode is:

```text
listen correctly
    +
advertise incorrectly
```

The node can then appear in discovery while still being unreachable.

---

## 21. Transport security

XGRChain P2P uses libp2p Noise.

Noise provides encrypted and authenticated transport between libp2p peers.

It does not itself grant:

- validator authority,
- staking authority,
- application authorization,
- contract permissions,
- transaction validity.

Transport authentication and protocol authorization are separate layers.

---

## 22. Gossipsub

The node uses libp2p Gossipsub.

Verified `v3.1.1` queue settings:

| Setting | Value |
| --- | ---: |
| Peer outbound queue | `1024` |
| Validation queue | `1024` |

The implementation explicitly notes that messages can be dropped when these queues are saturated.

Sustained queue pressure can therefore degrade propagation.

---

## 23. Transaction propagation

Typical transaction flow:

```text
RPC submission
      ↓
local transaction validation
      ↓
TxPool admission
      ↓
P2P propagation
      ↓
peer TxPool validation
```

P2P propagation does not make an invalid transaction valid.

Each receiving node validates the transaction independently and can reject it according to chain rules and its local TxPool policy.

---

## 24. Block and consensus propagation

The P2P layer transports information required for:

- block synchronization,
- proposal propagation,
- consensus messaging,
- canonical-head progression.

Poor connectivity can manifest as:

- increased block intervals,
- repeated IBFT round changes,
- missed validator participation,
- stale nodes,
- delayed transaction inclusion.

Healthy P2P connectivity is necessary for consensus liveness.

It does not itself grant consensus authority.

---

## 25. Internal protocol streams

XGRChain networking supports protocol-specific libp2p streams.

The discovery subsystem, for example, creates protocol streams to query peers.

These are internal node-to-node interfaces.

They are not public JSON-RPC APIs.

Operators normally observe them through:

- connectivity,
- logs,
- metrics,
- node diagnostics.

---

## 26. Peer events

The node emits internal network events including:

```text
PeerConnected
PeerDisconnected
```

Failed connections are also handled by discovery cleanup.

On successful connection, the peer can be added to the routing table.

On disconnect or failed connection, the discovery service removes the peer from the routing table.

Connection churn is therefore reflected in discovery state.

---

## 27. P2P versus consensus authority

A P2P connection grants communication capability only.

It does not imply:

- validator membership,
- staking status,
- voting power,
- proposer eligibility.

Conceptually:

```text
XGRChain P2P
      ↓
communication capability

delegated PoS + IBFT
      ↓
consensus authority
```

These layers must remain separate.

---

## 28. P2P versus XGR Interchain

XGR Interchain infrastructure is separate from XGRChain P2P.

Interchain components interact with XGRChain through mechanisms such as:

- JSON-RPC,
- deployed contracts,
- logs and events,
- checkpoint and attestation data,
- signed destination transactions.

An Interchain relayer does not need to become an XGRChain libp2p peer merely because it transports messages between chains.

Therefore:

```text
XGRChain P2P
≠
Interchain relayer transport
```

and:

```text
XGRChain consensus validator
≠
Interchain validator
```

The systems can depend on the same canonical XGRChain data while having separate networking, keys and security policies.

---

## 29. Mainnet node startup examples

### Full node

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false
```

### Validator

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/validator \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=true
```

The actual production service configuration should additionally include logging, monitoring and storage settings appropriate to the node role.

---

## 30. Firewall guidance

Typical interfaces:

| Interface | Typical port | Recommended exposure |
| --- | ---: | --- |
| P2P | `1478` | Public/controlled |
| JSON-RPC | `8545` | Private or reverse-proxied |
| gRPC | `9632` | Private |
| Metrics | deployment-specific | Monitoring network |
| SSH | `22` or custom | Administrative sources only |

Validator baseline:

```text
1478/tcp → peer traffic
8545/tcp → private/local only
9632/tcp → private/local only
metrics  → monitoring only
SSH      → administration only
```

Do not expose a validator's full management plane merely because P2P must be reachable.

---

## 31. Cloud and host firewalls

Operators should account for both:

```text
cloud firewall / security group
```

and:

```text
host firewall
```

Opening only one layer may still leave the node unreachable.

When diagnosing reachability, verify:

- public IP,
- advertised IP/DNS,
- cloud firewall,
- host firewall,
- local listen address,
- active process,
- NAT/port forwarding where applicable.

---

## 32. Bootnode operation

A production bootnode should maintain:

- stable network private key,
- stable peer ID,
- stable public address,
- stable P2P port,
- correct chain configuration,
- healthy process supervision,
- network monitoring.

A bootnode does not require validator signing material merely because it is a bootnode.

Avoid combining public RPC load with a critical bootnode unless intentionally designed and capacity-tested.

---

## 33. Bootnode configuration changes

Changing the published bootnode list affects discovery defaults.

It does not change:

- state transition,
- block validity,
- validator voting power,
- chain ID.

Therefore bootnode maintenance is not a consensus hardfork.

However, changing a published bootnode peer ID requires updating documentation/configuration so new nodes can discover a valid peer.

---

## 34. Network monitoring

Useful signals include:

| Signal | Meaning |
| --- | --- |
| Total peer count | Overall connectivity |
| Inbound peer count | Public reachability |
| Outbound peer count | Active connectivity/recovery |
| Bootnode connectivity | Discovery bootstrap health |
| Dial failures | Reachability problems |
| Disconnect rate | Connection instability |
| Block progression | Combined P2P/sync health |
| Round changes | Potential validator-network problem |
| Tx propagation delay | P2P or TxPool pressure |

No single metric proves network health.

---

## 35. Basic RPC connectivity check

Connected peer count:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

Also check:

```text
eth_blockNumber
```

A non-zero peer count with a frozen block height can still indicate a synchronization or consensus problem.

---

## 36. Failure: zero peers

Possible causes:

- bootnode unreachable,
- incorrect chain configuration,
- P2P port blocked,
- incorrect `--nat`,
- incorrect `--dns`,
- discovery disabled,
- no outbound capacity,
- host firewall,
- cloud firewall,
- local bind misconfiguration.

Check:

```text
process
--libp2p
--nat
--dns
bootnode
net_peerCount
firewall
```

---

## 37. Failure: discovered but unreachable

Typical symptom:

```text
peer appears in discovery
but dial repeatedly fails
```

Likely cause:

```text
advertised address is not reachable
```

Check:

- advertised IP,
- P2P port,
- NAT,
- firewall,
- DNS resolution.

---

## 38. Failure: slow synchronization

Possible causes:

- too few useful peers,
- unstable peers,
- network latency,
- disk I/O bottleneck,
- CPU saturation,
- simultaneous heavy RPC workloads,
- state database pressure.

Networking is only one possible cause.

Operators should correlate peer health with storage and resource metrics.

---

## 39. Failure: validator misses blocks

Possible causes include:

- P2P instability,
- signer problems,
- validator not active,
- insufficient voting power,
- synchronization lag,
- repeated round changes,
- CPU/disk overload.

A healthy peer count does not guarantee validator health.

Check both:

```text
P2P state
```

and:

```text
PoS / consensus state
```

---

## 40. Failure: one node has a stale head

Check:

- peer count,
- sync state,
- head number,
- head hash,
- node version,
- chain configuration,
- block import logs.

A stale node should not be used as the sole reference for network state.

---

## 41. Security guidance

Recommended practices:

- isolate validators from public RPC workloads,
- restrict JSON-RPC and gRPC on validators,
- expose only required P2P ports,
- maintain host and cloud firewalls,
- restrict SSH,
- preserve stable bootnode identities,
- monitor connection churn,
- monitor unexpected peer-count collapse,
- avoid exposing debug/tracing publicly,
- separate validator keys from network keys,
- separate relayer keys from validator keys,
- do not reuse production data directories.

---

## 42. Relation to trie pruning

Trie pruning is local storage behavior.

It does not change P2P identity or peer discovery.

However, heavy Trie Sweeper disk activity can indirectly affect node responsiveness if the host is resource-constrained.

Operators running the Trie Sweeper should therefore monitor:

- disk I/O,
- block progression,
- peer stability,
- CPU,
- sweep duration.

A local storage bottleneck can manifest as degraded network or consensus participation even though the P2P protocol itself is functioning correctly.

---

## 43. Current `v3.1.1` networking baseline

| Topic | Value / behavior |
| --- | --- |
| Node baseline | `xgr-node v3.1.1` |
| P2P implementation | libp2p |
| Transport security | Noise |
| Default port | `1478` |
| Default bind | `127.0.0.1:1478` |
| Typical public bind | `0.0.0.0:1478` |
| Mainnet bootnodes | `1` |
| Discovery default | Enabled |
| Disable discovery | `--no-discover` |
| Minimum bootnodes with discovery | `1` |
| Maximum peers | `40` |
| Maximum inbound peers | `32` |
| Maximum outbound peers | `8` |
| Discovery request maximum | `16` peers |
| Peer discovery interval | `5s` |
| Bootnode discovery interval | `60s` |
| Kademlia bucket size | `20` |
| Minimum-peer target | `1` |
| Gossipsub peer outbound queue | `1024` |
| Gossipsub validation queue | `1024` |
| P2P validator authority | None by itself |
| Interchain relayer transport | Separate from XGRChain P2P |

---

## 44. Design principle

XGRChain networking should be understood as the communication substrate for the blockchain node.

It provides:

```text
connectivity
discovery
propagation
```

It does not independently provide:

```text
validator authority
staking authority
smart-contract authority
Interchain authority
```

Those permissions belong to separate protocol or service layers.

For production operation, healthy P2P connectivity is essential to synchronization and consensus liveness, but it must remain cleanly separated from consensus identity and external service credentials.
