# XGR Chain — Networking & P2P

**Document ID:** XGRCHAIN-NETWORKING-P2P  
**Last updated:** 2026-10-03  
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
- interchain relayer operation,
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
| Transaction gossip | Distribution of txpool transactions |
| Protocol streams | Internal node-to-node services |
| Peer events | Connection-state tracking |
| Metrics | Connectivity and network-health visibility |

Consensus, synchronization, block propagation and transaction propagation all depend on healthy P2P connectivity.

A node can therefore be process-healthy while being network-unhealthy.

---

## 3. Mainnet bootnode

The canonical mainnet configuration currently contains one bootnode:

```text id="hoqbrx"
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes:

- provide initial peer discovery,
- should use stable peer identities,
- should remain reachable,
- should be monitored,
- do not grant validator authority,
- do not define validator membership,
- do not define transaction permission.

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

```text id="z7yxgn"
1478
```

Default network bind:

```text id="g3uz9e"
127.0.0.1:1478
```

This default is safe for local development but not sufficient for a publicly reachable production P2P node.

A production node that should accept inbound peers normally uses:

```bash id="2mowcq"
--libp2p 0.0.0.0:1478
```

---

## 5. Node identity

Each node has a libp2p private network key.

That key determines the node's peer ID.

Relationship:

```text id="pkmxbt"
network private key
        ↓
libp2p identity
        ↓
peer ID
```

Example bootnode multiaddr:

```text id="y8afzg"
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

The final `/p2p/...` component identifies the peer.

If the network key changes:

```text id="8ag6p6"
peer ID changes
```

For infrastructure whose multiaddr is published, this can break existing discovery references.

---

## 6. Network key versus validator key

The network identity key and validator signing material are separate.

| Key | Purpose |
| --- | --- |
| Network key | libp2p peer identity |
| Validator key | IBFT consensus signing |
| Account key | Normal account/transaction signing |
| Relayer key | External service transaction submission where used |

Possession of one does not imply authority associated with the others.

For example:

```text id="97e5bz"
libp2p peer
≠ validator
```

and:

```text id="lhgduo"
interchain relayer
≠ consensus validator
```

---

## 7. Network-key handling

Operational rules:

- do not delete production bootnode network keys casually,
- maintain stable network identity where published multiaddrs depend on it,
- do not reuse one data directory for multiple simultaneous nodes,
- restrict filesystem access,
- back up persistent network identities where necessary,
- keep validator key material separately protected.

Validator signing keys require a stricter security boundary than ordinary network identity keys.

---

## 8. Discovery startup requirements

When discovery is enabled, the node requires bootnode configuration.

The `v3.1.1` network implementation enforces:

```text id="h3psqq"
MinimumBootNodes = 1
```

If the chain configuration contains no bootnode field:

```text id="g7or9t"
no bootnodes specified
```

If the list exists but is empty:

```text id="jjpbvg"
minimum 1 bootnode is required
```

This requirement applies to discovery-enabled startup.

---

## 9. Discovery disable mode

Discovery can be disabled with:

```bash id="uztycc"
--no-discover
```

When enabled:

- automatic peer discovery is disabled,
- bootnode-driven discovery is skipped,
- managed/static peer topology becomes more important.

Use this mode only where peer connectivity is deliberately controlled.

For ordinary mainnet participation, discovery should normally remain enabled.

---

## 10. Peer discovery

The discovery service uses a Kademlia-style routing table.

Verified `v3.1.1` parameters:

| Parameter | Value |
| --- | ---: |
| Maximum requested peers per discovery query | `16` |
| Normal peer discovery interval | `5s` |
| Bootnode discovery interval | `60s` |
| Minimum peer connection target | `1` |
| Routing-table bucket size | `20` |

Discovery conceptually proceeds as follows:

```text id="67rsmn"
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

The current implementation uses:

```text id="amdw5g"
bucket size = 20
```

The routing table helps the node:

- track known peers,
- select peers for discovery,
- return nearby peers,
- remove disconnected peers,
- build connectivity over time.

Routing-table contents are local operational state.

They are not consensus state.

---

## 12. Peer store

The libp2p peer store retains peer identity and address information needed for connection attempts.

A peer can be:

- known,
- present in the routing table,
- queued for dialing,
- actively connected,
- disconnected.

These states are not equivalent.

For example:

```text id="07btav"
known peer
≠ connected peer
```

Monitoring should therefore focus on actual live connections rather than only discovered peer records.

---

## 13. Dial queue

The networking server uses an asynchronous dial queue.

Peers can enter the queue through:

- bootnode discovery,
- regular discovery,
- routing-table events,
- manual connection requests,
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

Persistent repeated failures to the same peer require investigation.

---

## 14. Connection limits

Current `v3.1.1` defaults:

| Setting | Default |
| --- | ---: |
| Maximum peers | `40` |
| Maximum inbound peers | `32` |
| Maximum outbound peers | `8` |

The ratio is therefore:

```text id="0r0056"
32 inbound
8 outbound
40 total
```

Relevant controls:

```text id="dd98lu"
--max-peers
--max-inbound-peers
--max-outbound-peers
```

These are local runtime limits.

They do not alter consensus rules.

---

## 15. Peer-limit guidance

### Validator

Prioritize:

- stable validator connectivity,
- sufficient outbound recovery paths,
- predictable resource use.

The defaults are a reasonable baseline unless monitoring shows a need to change them.

### Full node

Defaults are generally sufficient for normal synchronization.

### Public RPC node

Peer limits may be tuned independently from HTTP/RPC traffic.

Increasing RPC traffic is not by itself a reason to increase peer counts.

### Bootnode

Bootnodes may require tuning depending on discovery load, but resource limits should be monitored carefully.

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

Inbound connectivity is evidence that:

- the node is reachable,
- advertisement and firewall configuration may be working correctly.

A node can synchronize using outbound-only connectivity, but a publicly useful infrastructure peer should normally advertise a reachable address.

---

## 17. Bind address

The bind address determines where the local process listens.

Example:

```bash id="vwvn8o"
--libp2p 0.0.0.0:1478
```

This listens on all local IPv4 interfaces.

Default:

```text id="sjsv42"
127.0.0.1:1478
```

A node using the default cannot normally accept public inbound connections.

---

## 18. NAT advertisement

The `--nat` option allows a node to advertise a public IP distinct from its local bind address.

Example:

```bash id="m8i0hg"
--libp2p 0.0.0.0:1478 \
--nat 203.0.113.10
```

The node then advertises the configured public address using its P2P port.

The advertised IP must be externally reachable.

---

## 19. DNS advertisement

The node can also advertise a DNS multiaddr using:

```text id="19qa5n"
--dns
```

DNS advertisement and NAT advertisement are alternatives within the address factory behavior.

Operators should use a stable, resolvable DNS address if DNS advertisement is selected.

---

## 20. Bind versus advertisement

These are distinct:

| Function | Configuration |
| --- | --- |
| Where node listens locally | `--libp2p` |
| What public IPv4 address peers dial | `--nat` |
| What DNS multiaddr peers dial | `--dns` |

A common configuration failure is:

```text id="p8c19p"
listen correctly
+
advertise incorrectly
```

The node may appear in peer discovery while remaining unreachable.

---

## 21. Transport security

XGRChain P2P uses libp2p Noise security.

Noise provides encrypted authenticated transport between libp2p peers.

This transport security does not imply:

- validator authorization,
- application authorization,
- smart-contract permissions,
- transaction validity.

It protects P2P transport.

Protocol-level authorization is handled elsewhere.

---

## 22. Gossipsub

The node uses libp2p Gossipsub.

Verified `v3.1.1` queue settings:

| Setting | Value |
| --- | ---: |
| Peer outbound queue | `1024` |
| Validation queue | `1024` |

The code comments explicitly note that messages may be dropped when these queues are saturated.

Persistent queue pressure can therefore impair propagation.

---

## 23. Transaction propagation

Transactions submitted to a node typically flow:

```text id="pvdv3g"
RPC submission
      ↓
local transaction validation
      ↓
txpool admission
      ↓
P2P propagation
      ↓
peer txpool admission
```

Important:

```text id="hwp5uy"
P2P propagation does not make an invalid transaction valid.
```

Each peer can independently reject a transaction that fails its validation or local txpool rules.

---

## 24. Block and consensus propagation

The P2P network transports information required for:

- block synchronization,
- proposal propagation,
- consensus messaging,
- canonical-head progression.

Poor network connectivity can therefore appear as:

- increased block intervals,
- repeated round changes,
- missed validator participation,
- stale nodes,
- delayed transaction inclusion.

P2P health is a prerequisite for consensus liveness.

It does not by itself grant consensus authority.

---

## 25. Internal protocol streams

The networking layer supports protocol-specific libp2p streams.

The discovery service, for example, establishes protocol streams to query peers.

These internal streams are not public JSON-RPC APIs.

Operators normally interact with them only indirectly through:

- peer connectivity,
- logs,
- metrics,
- diagnostics.

---

## 26. Peer events

The node emits internal peer events such as:

```text id="pv33rf"
PeerConnected
PeerDisconnected
```

The discovery layer uses these events to maintain routing-table state.

On connection:

```text id="0on983"
peer → routing table
```

On disconnection:

```text id="dmbp2k"
peer removed from routing table
```

Connection churn is therefore reflected in discovery state over time.

---

## 27. P2P versus consensus authority

A peer connection grants network communication only.

It does not imply:

- validator membership,
- voting power,
- staking status,
- proposer eligibility.

Conceptually:

```text id="97r1bd"
P2P connectivity
       ↓
communication capability

PoS + IBFT state
       ↓
consensus authority
```

These are separate layers.

---

## 28. P2P versus Interchain

The XGR interchain backend is also separate from XGRChain P2P.

An interchain relayer generally interacts with chains through:

- JSON-RPC,
- deployed contracts,
- chain logs/events,
- signed transactions,
- checkpoint/attestation data.

It does not become part of XGRChain's libp2p network merely by relaying interchain messages.

Therefore:

```text id="ni9hjv"
XGRChain P2P
≠ Hyperlane relayer transport
```

and:

```text id="qlv6xr"
XGRChain consensus validator
≠ interchain validator
```

These systems can depend on the same canonical chain data while maintaining separate networking and security models.

---

## 29. Mainnet node startup example

Full node:

```bash id="c23w36"
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false
```

Validator:

```bash id="umkmtm"
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

```text id="gnczj8"
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

```text id="y0es0t"
cloud firewall / security group
```

and:

```text id="sb37vg"
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
| Tx propagation delay | P2P or txpool pressure |

No single metric proves network health.

---

## 35. Basic RPC connectivity check

Connected peer count:

```bash id="p4brrh"
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

Also check:

```text id="0w38ch"
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

```text id="qj7nwg"
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

```text id="wfqg7r"
peer appears in discovery
but dial repeatedly fails
```

Likely cause:

```text id="3qry8a"
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

```text id="suy6bj"
P2P state
```

and:

```text id="kbjrl4"
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

However, heavy trie-sweep disk activity can indirectly affect node responsiveness if the host is resource-constrained.

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

```text id="kaw4te"
connectivity
discovery
propagation
```

It does not independently provide:

```text id="bckhhq"
validator authority
staking authority
smart-contract authority
interchain authority
```

Those permissions belong to separate protocol or service layers.

For production operation, healthy P2P connectivity is essential to synchronization and consensus liveness, but it must remain cleanly separated from consensus identity and external service credentials.
