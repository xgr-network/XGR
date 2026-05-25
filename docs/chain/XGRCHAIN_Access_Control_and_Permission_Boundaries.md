# XGR Chain — Access Control & Permission Boundaries

**Document ID:** XGRCHAIN-ACCESS-CONTROL  
**Last updated:** 2026-05-24  
**Audience:** Node operators, validator operators, RPC operators, protocol developers, auditors  
**Release baseline:** `xgr-node` release tag `v2.0.5`  
**Mainnet genesis source:** `xgr-network/XGR` branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Public XGR Chain access-control and permission boundaries

---

## 1. Scope

This document explains access-control and permission boundaries relevant to XGR Chain.

It covers:

- infrastructure access boundaries
- P2P access boundaries
- node and RPC exposure
- JSON-RPC CORS boundary
- debug and txpool boundary
- validator key isolation
- transaction validity boundary
- txpool admission boundary
- chain-parameter address-list fields
- validator authority boundary
- contract-level permission boundary
- operational security boundaries

This document does not define:

- XDaLa permit logic
- XDaLa grant logic
- XRC standard behavior
- UI behavior
- application-specific contract roles

Those are outside this public chain-level access-control document.

---

## 2. Permission layers

XGR Chain has multiple permission layers.

They must not be collapsed into one concept.

| Layer | Purpose | Controlled by |
|---|---|---|
| Infrastructure access | Firewall, reverse proxy, TLS, rate limits, host access | Operator |
| P2P access | Node connectivity and peer discovery | libp2p configuration / network topology |
| Node/RPC exposure | Who can call local node interfaces | Operator |
| Transaction validity | Whether a transaction is valid for execution | Protocol rules |
| Txpool admission | Whether a valid transaction enters one node's local txpool | Node policy and protocol checks |
| Validator authority | Who participates in consensus | Consensus and staking state |
| Contract permissions | Contract-specific authorization | Smart contract logic |
| Chain-parameter address lists | Optional allow/block list configuration fields | Published chain configuration if configured |

Important distinctions:

- a peer connection is not transaction authority
- a valid transaction is not necessarily txpool-accepted
- txpool acceptance is not consensus finality
- staking active state is not always current consensus participation
- validator key possession is not enough if validator is not in the active validator set
- schema availability is not network activation

---

## 3. Infrastructure boundary

Infrastructure controls are operated outside the chain protocol.

They include:

- cloud firewall rules
- host firewall rules
- SSH access policy
- reverse proxies
- TLS termination
- HTTP rate limits
- WebSocket rate limits
- RPC namespace filtering
- monitoring-network isolation
- VPN/private-network access
- system user permissions
- file permissions
- backup access control

These controls decide who can reach a node or service.

They do not change chain rules.

Recommended baseline:

| Component | Recommended exposure |
|---|---|
| Validator SSH | Admin IPs only |
| Validator JSON-RPC | Localhost or private management network |
| Validator gRPC | Localhost/private only |
| Validator metrics | Monitoring network only |
| Validator P2P | Reachable according to validator topology |
| Public RPC HTTP | Reverse proxy / gateway |
| Public RPC WebSocket | Reverse proxy / gateway with limits |
| Debug RPC | Internal only |
| Txpool diagnostics | Internal or controlled |
| Metrics | Internal / monitoring network |

Operator security must not rely on chain-level logic.

A public HTTP endpoint is public even if the chain has validator permissions.

---

## 4. P2P boundary

The P2P layer controls node connectivity.

It does not define application authorization.

P2P concepts:

| Concept | Meaning |
|---|---|
| Network key | Determines libp2p peer identity |
| Peer ID | Public identity derived from network key |
| Bootnode | Helps peers discover each other |
| Peer connection | Active network link between nodes |
| Discovery | Mechanism for finding peers |
| P2P topic | PubSub channel for node messages |

Important boundaries:

- bootnodes help discovery
- bootnodes do not grant validator authority
- peer connection does not grant consensus authority
- network key does not sign transactions
- validator key is separate from network key
- public full nodes may connect without being validators
- P2P health affects propagation and consensus reliability

A node can be connected to peers and still have no validator authority.

A validator can have validator authority but fail operationally if P2P connectivity is broken.

---

## 5. Node/RPC exposure boundary

Node RPC exposure is operator-controlled.

The node may expose several RPC surfaces.

| Surface | Purpose | Recommended exposure |
|---|---|---|
| `eth_*` | Ethereum-compatible wallet/app/explorer RPC plus public XGR PoS methods | Public only with limits |
| `net_*` | Network metadata | Public only with limits |
| `web3_*` | Client/version/helper methods | Public only with limits |
| `txpool_*` | Transaction pool inspection | Internal / controlled |
| `debug_*` | Execution tracing | Internal only |
| gRPC operator services | Node management and diagnostics | Internal only |
| Metrics | Monitoring | Internal only |

Public XGR PoS methods under `eth_*`:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

Public RPC nodes should be separated from validator nodes.

Validator nodes should not be exposed as public RPC infrastructure.

Recommended public RPC controls:

- reverse proxy
- TLS
- rate limits
- batch limits
- block-range limits
- WebSocket limits
- namespace restrictions where available
- abuse monitoring
- resource monitoring

Recommended validator controls:

- no public debug RPC
- no public gRPC
- no public txpool diagnostics
- no validator key material on public RPC nodes
- local/private JSON-RPC only
- metrics restricted to monitoring systems

---

## 6. JSON-RPC CORS boundary

CORS is a browser access-control mechanism.

It does not protect a node from direct non-browser clients.

The node supports CORS allow-origin settings through runtime configuration.

Relevant configuration fields:

```text
cors_allowed_origins
headers.access_control_allow_origins
```

Operational meaning:

| Setting | Effect |
|---|---|
| CORS origin allowed | Browser clients from that origin may call the RPC endpoint |
| CORS origin denied | Browser clients from that origin are blocked by browser policy |
| No firewall/rate limit | Non-browser clients can still call the endpoint if reachable |

Do not treat CORS as RPC security.

Public RPC endpoints still require:

- network-level exposure control
- reverse proxy rules
- rate limits
- method restrictions where applicable
- monitoring and abuse handling

---

## 7. Debug boundary

Debug methods are expensive and sensitive.

They can reveal detailed execution behavior and consume significant CPU/memory.

Examples:

```text
debug_traceTransaction
debug_traceCall
debug_traceBlockByNumber
debug_traceBlockByHash
debug_traceBlock
```

Recommended policy:

| Environment | Debug exposure |
|---|---|
| Public RPC | Disabled or blocked |
| Internal tracing node | Allowed for trusted operators |
| Validator node | Avoid heavy tracing; internal only if needed |
| Development node | Allowed as needed |

Relevant runtime control:

```text
--concurrent-requests-debug
```

Default:

```text
32
```

Debug tracing should be isolated from public RPC workloads and validator-critical operation.

---

## 8. Txpool boundary

The txpool is local node state.

It is not consensus state.

A transaction can be:

- validly signed but rejected by a local txpool
- accepted by one node but not yet seen by another
- queued because of nonce ordering
- replaced by a higher-priced transaction
- gossiped but rejected by peers
- included without appearing in every public txpool view

Txpool admission checks include:

- signature recovery
- chain ID
- nonce
- account balance
- intrinsic gas
- block gas limit
- transaction type support
- fork activation
- effective gas price
- node-level price limit
- replacement price rules
- txpool capacity
- per-account queue limits

Txpool RPC methods should be considered operator/infrastructure APIs, not public application APIs.

Recommended policy:

| Method group | Exposure |
|---|---|
| `txpool_status` | Internal or controlled |
| `txpool_content` | Internal only or heavily restricted |
| `txpool_inspect` | Internal or controlled |

---

## 9. Transaction validity boundary

Transaction validity is protocol-level.

A transaction must satisfy execution and signing rules.

Important validation dimensions:

| Check | Meaning |
|---|---|
| Chain ID | Transaction belongs to XGR Chain signing domain |
| Signature | Sender can be recovered and signature is valid |
| Nonce | Sender nonce is valid |
| Balance | Sender can pay value and gas |
| Intrinsic gas | Transaction gas covers intrinsic cost |
| Block gas limit | Transaction gas does not exceed block gas limit |
| Transaction type | Type is supported by active fork configuration |
| Fee fields | Fee fields are valid for the transaction type |
| Base fee | Effective price covers base-fee rules where applicable |
| Contract creation rules | Initcode rules apply where active |
| Access-list rules | Access-list rules apply where active |

This is not an allowlist system.

It is normal EVM-compatible transaction validation.

---

## 10. Chain-parameter address-list fields

The public node chain-parameter schema includes address-list configuration fields.

Supported schema fields:

```text
contractDeployerAllowList
contractDeployerBlockList
transactionsAllowList
transactionsBlockList
bridgeAllowList
bridgeBlockList
```

Each address-list config can contain:

```text
adminAddresses
enabledAddresses
```

The published mainnet genesis does not configure these address-list fields.

That means the current published XGR Chain configuration does not activate a chain-level contract-deployer or transaction allow/block list through genesis.

If a future published configuration uses these fields, operational behavior must be documented against the active release that activates them.

Do not infer active chain-level allowlist behavior merely because schema fields exist in code.

Schema availability is not network activation.

---

## 11. Burn-contract fields are not permission fields

The chain parameter schema includes:

```text
burnContract
burnContractDestinationAddress
```

Published mainnet values:

```text
burnContract = null
burnContractDestinationAddress = 0x0000000000000000000000000000000000000000
```

These fields are fee/gas configuration fields, not access-control fields.

They do not grant transaction permission, validator authority, RPC authority or contract execution rights.

---

## 12. Validator authority boundary

Validator authority is determined by the active consensus and validator-set rules.

For XGR mainnet after block `5446500`, validator participation is derived through delegated PoS and IBFT.

Relevant concepts:

- validator key material
- validator BLS public key
- staking contract validator state
- validator self-stake
- delegated active stake
- total active current stake
- validator active flag
- epoch-boundary activation
- epoch-boundary deactivation
- current consensus header validator set
- effective voting power
- proposer uptime weighting
- reward eligibility
- slashing state

Important distinction:

| Field / concept | Meaning |
|---|---|
| Peer connection | Node is connected on P2P |
| Validator key | Node can sign consensus messages for that validator |
| Validator-set membership | Validator is part of active consensus set |
| Staking active | Validator is active in staking contract state |
| Currently validating | Validator is in current consensus header validator set |
| Delegated stake | Stake delegated to validator |
| Voting power | Consensus weight where stake-weighted PoS is active |

These concepts must not be collapsed into one boolean.

A dashboard should not infer current consensus participation from staking contract state alone when a consensus-derived field is available.

---

## 13. Validator key isolation

Validator key material is a high-value security boundary.

Rules:

- do not store validator keys on public RPC nodes
- do not expose validator machines as public RPC infrastructure
- restrict SSH access
- use a dedicated service user
- restrict filesystem permissions
- back up validator keys securely
- avoid interactive shell access where possible
- monitor signer errors
- monitor unexpected validator restarts
- separate validator infrastructure from indexing/tracing workloads

Validator key compromise is not an RPC configuration issue.

It is a consensus/security incident.

---

## 14. Contract-level permissions

Smart contracts can implement their own permissions.

Common patterns:

- owner-only functions
- role checks
- executor lists
- pause authority
- upgrade authority
- application-specific access control

Contract-level permissions are enforced by contract logic.

They are separate from:

- P2P access
- RPC exposure
- txpool admission
- validator set membership
- chain-parameter address-list fields unless the contract explicitly uses them

This chain-level document does not define application-specific contract roles.

---

## 15. Public RPC security baseline

Public RPC endpoints should be operated behind infrastructure controls.

Recommended controls:

- TLS reverse proxy
- request rate limits
- JSON-RPC batch limits
- block-range limits
- WebSocket read limits
- debug namespace blocked
- txpool diagnostics restricted
- CORS explicitly configured
- abuse monitoring
- health monitoring
- node separation from validators

Relevant default runtime limits:

| Setting | Default |
|---|---:|
| JSON-RPC batch request limit | `20` |
| JSON-RPC block range limit | `1000` |
| concurrent debug request limit | `32` |
| WebSocket read limit | `8192` bytes |

---

## 16. Validator RPC security baseline

Validator nodes should expose only what operators need.

Recommended exposure:

| Interface | Exposure |
|---|---|
| P2P | Public/allowlisted according to topology |
| JSON-RPC | Localhost/private management network |
| gRPC | Localhost/private management network |
| Metrics | Monitoring network |
| Debug | Avoid; internal only if needed |
| SSH | Admin IPs only |

Validator nodes should not be public RPC nodes.

A production validator should not carry public application traffic.

---

## 17. Data-directory boundary

The node data directory contains local chain data and secrets depending on node role.

Rules:

- do not share one data directory between multiple running nodes
- do not run validator and RPC workloads from the same validator data directory
- do not copy validator data directories to public RPC nodes
- keep validator data directory permissions restrictive
- back up validator key material securely
- treat accidental key exposure as a security incident

Recommended permissions:

```bash
sudo chown -R xgr:xgr /var/lib/xgr/validator
sudo chmod -R go-rwx /var/lib/xgr/validator
```

---

## 18. Permission-boundary checklist

For public full/RPC nodes:

- `--seal=false`
- no validator key material
- JSON-RPC behind proxy
- debug blocked
- txpool diagnostics restricted
- batch/range limits configured
- public methods monitored
- data directory isolated

For validator nodes:

- `--seal=true`
- validator key material present
- JSON-RPC local/private only
- gRPC local/private only
- P2P reachable
- metrics restricted
- no public app traffic
- filesystem permissions restricted
- key backups encrypted
- PoS status monitored

For bootnodes:

- stable network key
- stable public address
- P2P reachable
- no validator key required
- no public RPC unless intentionally configured
- monitored peer connectivity

---

## 19. Summary

| Boundary | Key rule |
|---|---|
| Infrastructure | Operator-controlled; does not change chain rules |
| P2P | Connectivity only; no validator authority |
| Bootnodes | Discovery only; no consensus rights |
| JSON-RPC | Operator exposure policy; protect public endpoints |
| CORS | Browser control only; not RPC security |
| Debug | Internal only |
| Txpool | Local node state; not consensus state |
| Transaction validity | Protocol-level EVM-compatible validation |
| Address-list schema fields | Not active on mainnet unless configured |
| Validator authority | Derived from consensus and staking state |
| Validator keys | Must not be on public RPC nodes |
| Contract permissions | Contract-defined, not P2P/RPC-defined |
