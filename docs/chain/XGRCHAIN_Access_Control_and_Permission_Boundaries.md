# XGR Chain — Access Control & Permission Boundaries

**Document ID:** XGRCHAIN-ACCESS-CONTROL  
**Last updated:** 2026-10-03  
**Audience:** Node operators, validator operators, RPC operators, protocol developers, auditors  
**Release baseline:** `xgr-node v3.1.1`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Public XGRChain access-control and permission boundaries

---

## 1. Scope

This document explains the access-control and permission boundaries relevant to XGRChain.

It covers:

- infrastructure access boundaries,
- P2P access boundaries,
- node and RPC exposure,
- JSON-RPC CORS boundaries,
- debug and txpool exposure,
- validator key isolation,
- transaction validity,
- txpool admission,
- chain-parameter address-list fields,
- validator authority,
- contract-level permissions,
- separation between chain authority and external protocol/service authority,
- operational security boundaries.

This document does not define:

- XDaLa permit logic,
- XDaLa grant logic,
- XRC standard behavior,
- UI authorization,
- application-specific contract roles,
- detailed interchain route authorization or security-module configuration.

Those mechanisms are documented separately.

---

## 2. Permission layers

XGRChain has multiple independent permission layers.

They must not be collapsed into one concept.

| Layer | Purpose | Controlled by |
| --- | --- | --- |
| Infrastructure access | Firewall, reverse proxy, TLS, rate limits, host access | Operator |
| P2P access | Node connectivity and peer discovery | libp2p configuration / network topology |
| Node/RPC exposure | Who can call local node interfaces | Operator |
| Transaction validity | Whether a transaction is valid for execution | Protocol rules |
| Txpool admission | Whether a valid transaction enters one node's local txpool | Node policy and protocol checks |
| Validator authority | Who participates in consensus | Consensus and staking state |
| Contract permissions | Contract-specific authorization | Smart contract logic |
| Chain-parameter address lists | Optional allow/block-list configuration | Published chain configuration if enabled |
| External protocol/service authority | Off-chain services, relayers or external protocol components | Separate service or contract configuration |

Important distinctions:

- a peer connection is not transaction authority,
- a valid transaction is not necessarily txpool-accepted,
- txpool acceptance is not consensus finality,
- staking active state is not always identical to current consensus participation,
- validator key possession is not sufficient if the validator is not part of the active validator set,
- schema availability does not imply network activation,
- control of an external service or interchain relayer does not grant XGRChain consensus authority,
- ownership of a smart contract does not grant node, validator or RPC authority.

---

## 3. Infrastructure boundary

Infrastructure controls operate outside the chain protocol.

They include:

- cloud firewall rules,
- host firewall rules,
- SSH access policy,
- reverse proxies,
- TLS termination,
- HTTP rate limits,
- WebSocket rate limits,
- RPC namespace filtering,
- monitoring-network isolation,
- VPN/private-network access,
- system-user permissions,
- filesystem permissions,
- backup access control.

These controls determine who can reach a node or service.

They do not modify chain rules.

Recommended baseline:

| Component | Recommended exposure |
| --- | --- |
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

A public HTTP endpoint is public even if the chain itself has validator or contract-level permissions.

---

## 4. P2P boundary

The P2P layer controls node connectivity.

It does not define transaction, application or consensus authorization.

P2P concepts:

| Concept | Meaning |
| --- | --- |
| Network key | Determines libp2p peer identity |
| Peer ID | Public identity derived from the network key |
| Bootnode | Helps peers discover each other |
| Peer connection | Active network link between nodes |
| Discovery | Mechanism for finding peers |
| P2P topic | PubSub channel for node messages |

Important boundaries:

- bootnodes help discovery,
- bootnodes do not grant validator authority,
- peer connectivity does not grant consensus authority,
- a network key does not sign transactions,
- validator keys are separate from network keys,
- public full nodes may connect without being validators,
- P2P health affects propagation and consensus reliability.

A node can be connected to peers while having no validator authority.

A validator can have validator authority but still fail operationally if P2P connectivity is broken.

---

## 5. Node/RPC exposure boundary

Node RPC exposure is controlled by the operator.

The node exposes several possible RPC surfaces.

| Surface | Purpose | Recommended exposure |
| --- | --- | --- |
| `eth_*` | Ethereum-compatible wallet/app/explorer RPC plus public XGR PoS methods | Public only with limits |
| `net_*` | Network metadata | Public only with limits |
| `web3_*` | Client/version/helper methods | Public only with limits |
| `txpool_*` | Transaction-pool inspection | Internal / controlled |
| `debug_*` | Execution tracing | Internal only |
| gRPC operator services | Node management and diagnostics | Internal only |
| Metrics | Monitoring | Internal only |

Public XGR PoS methods available in the `v3.1.1` node baseline include:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

Public RPC nodes should be operationally separated from validator nodes.

Validator nodes should not be used as general public RPC infrastructure.

Recommended public RPC controls:

- reverse proxy,
- TLS,
- request rate limits,
- batch limits,
- block-range limits,
- WebSocket limits,
- namespace restrictions where available,
- abuse monitoring,
- resource monitoring.

Recommended validator controls:

- no public debug RPC,
- no public gRPC,
- no public txpool diagnostics,
- no validator key material on public RPC nodes,
- local/private JSON-RPC only,
- metrics restricted to monitoring systems.

---

## 6. JSON-RPC CORS boundary

CORS is a browser access-control mechanism.

It does not protect a node from direct non-browser clients.

The `v3.1.1` node configuration exposes CORS-related settings including:

```text
cors_allowed_origins
headers.access_control_allow_origins
```

Operational meaning:

| Setting | Effect |
| --- | --- |
| CORS origin allowed | Browser clients from that origin may call the RPC endpoint |
| CORS origin denied | Browser clients from that origin are blocked by browser policy |
| Endpoint remains reachable | Non-browser clients can still call it unless network controls prevent access |

Do not treat CORS as an RPC security boundary.

Public RPC endpoints still require:

- network-level exposure controls,
- reverse-proxy rules,
- rate limits,
- method restrictions where appropriate,
- monitoring and abuse handling.

---

## 7. Debug boundary

Debug methods are computationally expensive and may expose detailed execution behavior.

Examples include:

```text
debug_traceTransaction
debug_traceCall
debug_traceBlockByNumber
debug_traceBlockByHash
debug_traceBlock
```

Recommended policy:

| Environment | Debug exposure |
| --- | --- |
| Public RPC | Disabled or blocked |
| Internal tracing node | Allowed for trusted operators |
| Validator node | Avoid heavy tracing; internal only if required |
| Development node | Allowed as needed |

Relevant runtime control:

```text
--concurrent-requests-debug
```

Default in `xgr-node v3.1.1`:

```text
32
```

Debug tracing should be isolated from public RPC workloads and consensus-critical validator operation.

---

## 8. Txpool boundary

The txpool is local node state.

It is not consensus state.

A transaction can be:

- validly signed but rejected by a local txpool,
- accepted by one node but not yet seen by another,
- queued because of nonce ordering,
- replaced by a higher-priced transaction,
- gossiped but rejected by peers,
- included in a block without appearing in every public txpool view.

Txpool admission checks can include:

- signature recovery,
- chain ID,
- nonce,
- account balance,
- intrinsic gas,
- block gas limit,
- transaction-type support,
- fork activation,
- effective gas price,
- node-level price limits,
- replacement-price rules,
- txpool capacity,
- per-account queue limits.

Txpool RPC methods should be treated as operator or infrastructure APIs rather than normal public application APIs.

Recommended policy:

| Method group | Exposure |
| --- | --- |
| `txpool_status` | Internal or controlled |
| `txpool_content` | Internal only or heavily restricted |
| `txpool_inspect` | Internal or controlled |

---

## 9. Transaction validity boundary

Transaction validity is enforced at protocol level.

A transaction must satisfy execution and signing rules before it can be accepted for execution.

Important validation dimensions include:

| Check | Meaning |
| --- | --- |
| Chain ID | Transaction belongs to the XGRChain signing domain |
| Signature | Sender can be recovered and signature is valid |
| Nonce | Sender nonce is valid |
| Balance | Sender can pay value and execution fees |
| Intrinsic gas | Transaction gas covers intrinsic cost |
| Block gas limit | Transaction gas does not exceed the block gas limit |
| Transaction type | Type is supported by the active fork configuration |
| Fee fields | Fee fields are valid for the selected transaction type |
| Base-fee rules | Effective price satisfies active fee rules |
| Contract creation | Initcode rules apply where activated |
| Access list | Access-list rules apply where activated |

This is not an allowlist system.

It is normal EVM-compatible transaction validation combined with XGRChain-specific protocol rules.

---

## 10. Chain-parameter address-list fields

The public `xgr-node v3.1.1` chain-parameter schema contains optional address-list configuration fields:

```text
contractDeployerAllowList
contractDeployerBlockList
transactionsAllowList
transactionsBlockList
bridgeAllowList
bridgeBlockList
```

Each address-list configuration can contain:

```text
adminAddresses
enabledAddresses
```

The current published XGRChain mainnet genesis does **not** configure any of these address-list fields.

Therefore the current mainnet configuration does not activate a chain-level contract-deployer, transaction or bridge allow/block list through genesis configuration.

If a future published chain configuration enables these fields, its behavior must be documented against the release and network configuration that activates them.

Do not infer active access-control behavior merely because the corresponding schema fields exist in the node implementation.

**Schema availability is not network activation.**

---

## 11. Burn-contract fields are not permission fields

The chain-parameter schema also contains:

```text
burnContract
burnContractDestinationAddress
```

Current published mainnet values:

```text
burnContract = null
burnContractDestinationAddress = 0x0000000000000000000000000000000000000000
```

These fields belong to fee and gas configuration.

They are not access-control fields.

They do not grant:

- transaction permission,
- validator authority,
- RPC authority,
- contract execution authority,
- interchain authority.

---

## 12. Validator authority boundary

Validator authority is determined by the active consensus and validator-set rules.

The published XGRChain mainnet configuration defines:

```text
IBFT
PoA: blocks 0 – 5,446,499
PoS: from block 5,446,500
validator type: BLS
```

For the current PoS phase, validator participation is derived from the staking-aware validator state and the active consensus validator set.

Relevant concepts include:

- validator key material,
- validator BLS public key,
- staking-contract validator state,
- validator self-stake,
- delegated active stake,
- total active current stake,
- validator active state,
- epoch-boundary activation,
- epoch-boundary deactivation,
- current consensus-header validator set,
- effective voting power,
- proposer uptime weighting,
- reward eligibility,
- slashing state.

Important distinctions:

| Field / concept | Meaning |
| --- | --- |
| Peer connection | Node is connected through P2P |
| Validator key | Node can sign consensus messages for that validator |
| Validator-set membership | Validator is part of the active consensus set |
| Staking active | Validator is active in staking state |
| Currently validating | Validator is represented in the current consensus validator set |
| Delegated stake | Stake delegated to a validator |
| Voting power | Consensus weight under stake-weighted PoS rules |

These concepts must not be collapsed into a single boolean.

For example, monitoring systems should not infer current consensus participation solely from staking-contract state when consensus-derived validator-set information is available.

---

## 13. Validator key isolation

Validator key material is a high-value security boundary.

Rules:

- do not store validator keys on public RPC nodes,
- do not expose validator machines as general public RPC infrastructure,
- restrict SSH access,
- use a dedicated service user,
- restrict filesystem permissions,
- back up validator keys securely,
- avoid unnecessary interactive shell access,
- monitor signer errors,
- monitor unexpected validator restarts,
- separate validator infrastructure from indexing and tracing workloads.

Validator key compromise is not an RPC-configuration incident.

It is a consensus and network-security incident.

---

## 14. Contract-level permissions

Smart contracts may implement their own permissions independently from node or consensus permissions.

Common patterns include:

- owner-only functions,
- role-based access checks,
- executor lists,
- pause authority,
- upgrade authority,
- administrative configuration,
- application-specific access control.

Contract-level permissions are enforced by contract logic.

They are separate from:

- P2P access,
- RPC exposure,
- txpool admission,
- validator-set membership,
- node filesystem permissions,
- chain-parameter address-list fields unless the contract explicitly interacts with those mechanisms.

This distinction also applies to infrastructure such as interchain routers and security modules: ownership or administrative authority over those contracts does not grant XGRChain validator or consensus authority.

Detailed contract-specific roles are outside the scope of this document.

---

## 15. External protocol and interchain authority

External protocol services may have their own operational authority boundaries.

Examples can include:

- relayer signing accounts,
- message-validation services,
- interchain validator or attestation processes,
- route-contract ownership,
- security-module administration,
- pause or emergency controls.

These are not XGRChain consensus permissions.

A relayer may be authorized to submit a transaction to XGRChain, but the submitted transaction is still subject to normal XGRChain transaction validation and contract execution rules.

Likewise, an interchain validator or security module does not become an XGRChain consensus validator merely by participating in cross-chain message verification.

Detailed XGR interchain architecture and operator security are documented separately.

---

## 16. Public RPC security baseline

Public RPC endpoints should be operated behind infrastructure controls.

Recommended controls:

- TLS reverse proxy,
- request rate limits,
- JSON-RPC batch limits,
- block-range limits,
- WebSocket read limits,
- debug namespace blocked,
- txpool diagnostics restricted,
- CORS explicitly configured,
- abuse monitoring,
- health monitoring,
- node separation from validators.

Relevant `xgr-node v3.1.1` default runtime limits:

| Setting | Default |
| --- | ---: |
| JSON-RPC batch request limit | `20` |
| JSON-RPC block-range limit | `1000` |
| Concurrent debug request limit | `32` |
| WebSocket read limit | `8192` bytes |

These are software defaults, not substitutes for infrastructure-level protection.

---

## 17. Validator RPC security baseline

Validator nodes should expose only the interfaces required for operation.

Recommended exposure:

| Interface | Exposure |
| --- | --- |
| P2P | Public/allowlisted according to topology |
| JSON-RPC | Localhost/private management network |
| gRPC | Localhost/private management network |
| Metrics | Monitoring network |
| Debug | Avoid; internal only if required |
| SSH | Admin IPs only |

Validator nodes should not serve as general public RPC nodes.

A production validator should not carry unrestricted public application traffic.

---

## 18. Data-directory boundary

The node data directory contains local chain state and, depending on node role, security-sensitive key material.

Rules:

- do not share one data directory between multiple running nodes,
- do not run validator and public-RPC workloads from the same validator data directory,
- do not copy validator data directories to public RPC nodes,
- keep validator data-directory permissions restrictive,
- back up validator key material securely,
- treat accidental validator-key exposure as a security incident.

Example restrictive permissions:

```bash
sudo chown -R xgr:xgr /var/lib/xgr/validator
sudo chmod -R go-rwx /var/lib/xgr/validator
```

Exact paths and service users depend on operator deployment.

---

## 19. Permission-boundary checklist

### Public full / RPC nodes

- `--seal=false`
- no validator key material
- JSON-RPC behind a reverse proxy or gateway
- debug methods blocked or restricted
- txpool diagnostics restricted
- batch and block-range limits configured
- public methods monitored
- data directory isolated from validators

### Validator nodes

- `--seal=true`
- validator key material present
- JSON-RPC local/private only
- gRPC local/private only
- P2P reachable according to network topology
- metrics restricted
- no unrestricted public application traffic
- filesystem permissions restricted
- key backups encrypted and controlled
- PoS and consensus status monitored

### Bootnodes

- stable network key
- stable advertised network address
- P2P reachable
- no validator key required solely for bootnode operation
- no public RPC unless intentionally configured
- peer connectivity monitored

### External services / relayers

- dedicated signing accounts where signing is required
- no validator private keys unless the service is explicitly also a validator
- least-privilege contract permissions
- restricted service credentials
- monitored transaction failures and abnormal retries
- separation from consensus validator key material

---

## 20. Summary

| Boundary | Key rule |
| --- | --- |
| Infrastructure | Operator-controlled; does not change chain rules |
| P2P | Connectivity only; no validator authority |
| Bootnodes | Discovery only; no consensus rights |
| JSON-RPC | Operator exposure policy; public endpoints require protection |
| CORS | Browser control only; not RPC security |
| Debug | Internal or tightly restricted |
| Txpool | Local node state; not consensus state |
| Transaction validity | Protocol-level EVM/XGRChain validation |
| Address-list schema fields | Not active on current mainnet unless explicitly configured |
| Validator authority | Derived from consensus and staking state |
| Validator keys | Must be isolated from public RPC infrastructure |
| Contract permissions | Contract-defined, not P2P/RPC-defined |
| External services / relayers | Separate authority domain; no implicit consensus rights |
