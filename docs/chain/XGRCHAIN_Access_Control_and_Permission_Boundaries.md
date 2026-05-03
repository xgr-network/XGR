# XGR Chain — Access Control & Permission Boundaries

**Document ID:** XGRCHAIN-ACCESS-CONTROL  
**Last updated:** 2026-05-03  
**Audience:** Protocol developers, node operators, XDaLa integrators, auditors  
**Implementation status:** Current public baseline for node/RPC/contract boundaries; XDaLa permits and grants are release-dependent XGR extension components  
**Source of truth:** Public `xgr-network/xgr-node` releases, published XGR Chain configuration, XGR extension specifications, and official XGR Network operator announcements

---

## 1. Scope

This document explains the access-control and permission boundaries relevant to XGR Chain and XGR extension components.

It covers:

- infrastructure access boundaries
- P2P access boundaries
- node and RPC exposure
- validator key isolation
- transaction validity boundaries
- txpool admission boundaries
- chain-parameter address-list fields
- contract-level permissions
- XDaLa permit-based authorization
- XDaLa grant-based encrypted-data access
- operational security boundaries

Access control in XGR is not one single mechanism.

Different layers answer different questions.

---

## 2. Permission layers

XGR Chain uses multiple permission layers.

They must not be mixed.

| Layer | Purpose | Status |
|---|---|---|
| Infrastructure access | Firewall, reverse proxy, TLS, rate limits, host access | Operator-controlled |
| P2P access | Determines node connectivity and peer discovery | Public baseline |
| Node/RPC exposure | Determines who can call local node interfaces | Operator-controlled |
| Transaction validity | Determines whether a transaction is valid for execution | Public baseline |
| TxPool admission | Determines whether a valid transaction is accepted into a local pool | Public baseline |
| Validator authority | Determines who participates in consensus | Release/configuration-dependent |
| Contract-level permissions | Ownership, executor roles, contract-specific access | Contract-defined |
| XDaLa permits | EIP-712 signatures for XDaLa actions | XGR extension, release-dependent |
| XDaLa grants | Encrypted-data access rights | XGR extension, release-dependent |

A peer connection is not transaction authority.

A valid transaction is not necessarily txpool-accepted.

A staking contract state flag is not the same as current consensus participation.

A grant is not a chain-wide allowlist.

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
| TxPool RPC | Internal or controlled infrastructure |
| XDaLa extension RPC | Endpoint-specific policy |
| Database-backed grant services | Private service network |

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

Node RPC exposure is an operator-controlled boundary.

The node may expose several RPC surfaces.

| Surface | Purpose | Recommended exposure |
|---|---|---|
| `eth_*` | Ethereum-compatible wallet/app/explorer RPC | Public only with limits |
| `net_*` | Network metadata | Public only with limits |
| `web3_*` | Client/version/helper methods | Public only with limits |
| `txpool_*` | Transaction pool inspection | Internal / controlled |
| `debug_*` | Execution tracing | Internal only |
| `xgr_*` | XGR extension methods | Endpoint-specific |
| gRPC operator services | Node management and diagnostics | Internal only |
| Metrics | Monitoring | Internal only |

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

The node supports a CORS allow-origin setting through the runtime configuration.

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

Debug methods include tracing methods such as:

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

The node supports a concurrent debug request limit.

Relevant runtime control:

```text
--concurrent-requests-debug
```

Debug tracing should be isolated from public RPC workloads and validator-critical operation.

---

## 8. TxPool boundary

The TxPool is local node state.

It is not consensus state.

A transaction can be:

- validly signed but rejected by a local txpool
- accepted by one node but not yet seen by another
- queued because of nonce ordering
- replaced by a higher-priced transaction
- gossiped but rejected by peers
- mined without appearing in every public txpool view

TxPool admission checks include:

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

TxPool RPC methods should be considered operator/infrastructure APIs, not public application APIs.

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

The structure supports fields such as:

```text
contractDeployerAllowList
contractDeployerBlockList
transactionsAllowList
transactionsBlockList
```

Each address-list config can contain:

```text
adminAddresses
enabledAddresses
```

The published mainnet genesis does not configure these address-list fields.

That means the current published XGR Chain configuration does not activate a chain-level contract-deployer or transaction allow/block list through genesis.

If a future published configuration uses these fields, the operational behavior must be documented against the active release that activates them.

Do not infer active chain-level allowlist behavior merely because schema fields exist in code.

Schema availability is not the same as network activation.

---

## 11. Validator authority boundary

Validator authority is determined by the active consensus and validator-set rules.

In the current published baseline, the genesis configures IBFT validator data through the genesis configuration.

In staking-enabled releases, validator authority may depend on additional staking state and activation rules.

Relevant concepts can include:

- validator registration
- validator key material
- validator set membership
- current consensus header validator set
- staking active flag
- self-stake
- delegated stake
- stake-weighted voting power
- epoch-boundary activation
- epoch-boundary deactivation
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

A dashboard should not infer current consensus participation from staking contract state alone when a dedicated consensus-derived field is available.

---

## 12. Validator key isolation

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

## 13. Contract-level permissions

Smart contracts can implement their own permissions.

Common patterns:

- owner-only functions
- executor lists
- role checks
- session owner checks
- rule owner checks
- grant manager checks
- upgrade authority
- emergency pause authority
- delegated execution authority

Contract-level permissions are enforced by contract logic.

They are separate from:

- P2P access
- RPC exposure
- txpool admission
- validator set membership
- XDaLa off-chain grant storage

For XGR standards, contract-level permissions can be used by:

- XRC-137 rule contracts
- XRC-729 orchestration/session contracts
- key registry contracts
- application-specific contracts

Contract ownership should be audited independently from node infrastructure.

---

## 14. XRC-137 permission boundary

XRC-137 belongs to the XGR extension layer.

It defines rule-document / rule-contract behavior.

Typical permission concerns include:

- who owns the rule contract
- who can update rule content
- who can execute or reference a rule
- whether rule content is plaintext or encrypted
- whether an owner read key exists
- whether XDaLa can load the rule
- whether the caller has the required permit or contract authority

XRC-137 permissions are not chain-wide RPC permissions.

They are rule-contract and XDaLa integration permissions.

Availability depends on the deployed contract and active XGR release stack.

---

## 15. XRC-729 permission boundary

XRC-729 belongs to the XGR extension layer.

It defines orchestration/session behavior.

Typical permission concerns include:

- orchestration owner
- session owner
- executor authority
- session control authority
- wake/pause/resume/kill authority
- gas budget authority
- contract-mediated execution authority
- permit-based execution authorization

XRC-729 permissions are not validator permissions.

They control process execution and session behavior.

Availability depends on deployed contracts and active XGR release stack.

---

## 16. XDaLa permit boundary

XDaLa permits are EIP-712 typed-data signatures.

They authorize specific XDaLa actions without requiring an on-chain authorization transaction for every action.

Permit properties:

- deterministic typed-data structure
- chain ID binding
- expiry
- signer recovery
- action-specific authority checks
- wallet signing through `eth_signTypedData_v4`

Permit payloads usually contain:

- `domain`
- `types`
- `primaryType`
- `message`
- `signature`

A permit proves signed authorization for a specific XDaLa action.

It does not make the signer a validator.

It does not grant P2P access.

It does not bypass transaction validity.

---

## 17. SessionPermit

`SessionPermit` authorizes starting or continuing a specific XDaLa session under a specific orchestration.

High-level domain fields:

| Field | Meaning |
|---|---|
| `name` | `XDaLa SessionPermit` |
| `version` | Permit version |
| `chainId` | Chain ID binding |

High-level message fields:

| Field | Meaning |
|---|---|
| `from` | Signer and authority holder |
| `ostcId` | Orchestration identifier |
| `ostcHash` | Hash of orchestration structure |
| `sessionId` | Root session ID |
| `maxTotalGas` | Total gas budget cap |
| `expiry` | Unix expiry timestamp |

High-level checks:

- typed-data domain must match expected domain
- chain ID must match network chain ID
- permit must not be expired
- recovered signer must match `message.from`
- signer must satisfy the required orchestration/session authority rule

---

## 18. xdalaPermit

`xdalaPermit` authenticates a caller for grant-management and grant-listing operations.

High-level domain fields:

| Field | Meaning |
|---|---|
| `name` | Non-empty domain name |
| `version` | Non-empty domain version |
| `chainId` | Chain ID binding |

High-level message fields:

| Field | Meaning |
|---|---|
| `from` | Signer / caller identity |
| `expiry` | Unix expiry timestamp |

High-level checks:

- chain ID must match
- permit must not be expired
- recovered signer identifies the caller
- endpoint parameters define the action scope

This permit is intentionally minimal.

The action scope is defined by the endpoint request parameters, such as RID, scope, grantee, owner or filters.

---

## 19. ControlPermit

`ControlPermit` authorizes XDaLa session control actions.

Typical actions:

```text
pause
resume
kill
wake
```

High-level domain fields:

| Field | Meaning |
|---|---|
| `name` | Non-empty domain name |
| `version` | Non-empty domain version |
| `chainId` | Chain ID binding |
| `verifyingContract` | Expected control-domain verifying contract |

High-level message fields:

| Field | Meaning |
|---|---|
| `from` | Signer identity |
| `sessionId` | Root session ID |
| `action` | Control action |
| `expiry` | Unix expiry timestamp |

High-level checks:

- chain ID must match
- verifying contract must match expected control domain
- action must be allowed
- permit must not be expired
- signer must satisfy the required session-control authority rule

---

## 20. XDaLa grants boundary

XDaLa grants control encrypted-data access.

They are not chain-level allowlists.

They are not validator permissions.

They are not P2P permissions.

The grant model protects encrypted content such as:

- XRC-137 rule documents
- XDaLa engine logs
- encrypted execution output where supported

Grant storage model:

| Component | Storage | Purpose |
|---|---|---|
| Read public keys | On-chain key registry | Public keys for wrapping DEKs |
| Grants | PostgreSQL grants database | Access rights and wrapped DEKs |
| Encrypted blobs | On-chain contract data or logs/responses | Ciphertext content |

Grants are database-backed authorization records for encrypted data access.

---

## 21. Grant rights

Grant rights are bitmask-based.

| Right | Value | Meaning |
|---|---:|---|
| READ | `1` | Can decrypt content |
| WRITE | `2` | Can update content where supported |
| MANAGE | `4` | Can manage sub-grants |

Common combinations:

| Rights | Meaning |
|---:|---|
| `1` | Reader |
| `3` | Reader + writer |
| `7` | Owner / full rights |

Grant rights apply to encrypted content access.

They do not authorize arbitrary chain transactions.

---

## 22. Grant scope

Grants are scoped.

| Scope | Meaning |
|---:|---|
| `1` | Session / prepare / rule document |
| `2` | Engine log |
| `3` | Field-level scope, reserved |

A grant is identified by:

- RID
- scope
- grantee address

The grant database enforces uniqueness by RID, grantee and scope.

A grant for one RID/scope does not automatically grant access to another RID/scope.

---

## 23. Encryption boundary

XDaLa encryption separates plaintext access from chain execution.

High-level model:

1. content is encrypted with a random data encryption key
2. the encrypted blob is stored or emitted
3. the data encryption key is wrapped for authorized recipients
4. wrapped keys and access rights are stored in grant records
5. recipients decrypt only if they have a valid grant and corresponding private key

Important security properties:

- plaintext is not exposed merely because ciphertext is public
- read public keys can be on-chain
- private read keys remain user-side
- grant records determine who can access wrapped DEKs
- expired grants should not authorize access
- READ permission is required for decryption

A grant authorizes encrypted data access, not consensus behavior.

---

## 24. Access matrix

High-level access-control matrix:

| Action | Boundary |
|---|---|
| Connect to node as peer | P2P/network configuration |
| Discover peers | Bootnode/discovery configuration |
| Serve public RPC | Infrastructure/RPC exposure |
| Submit raw transaction | RPC exposure plus transaction validity |
| Enter local txpool | TxPool admission |
| Execute transaction | Protocol validity and block inclusion |
| Participate in consensus | Active validator-set rules |
| Sign consensus messages | Validator key material |
| Trace transaction | Debug RPC exposure |
| Inspect txpool | TxPool RPC exposure |
| Manage XDaLa grants | XDaLa permit plus grant rules |
| Decrypt XDaLa content | Grant rights plus recipient private key |
| Control XDaLa session | ControlPermit / session authority |
| Update contract state | Contract-level permission and valid transaction |

Use the correct boundary for the correct action.

---

## 25. Public RPC exposure policy

Recommended public RPC exposure:

| Namespace | Public exposure |
|---|---|
| `eth_*` | Yes, with rate limits and method controls |
| `net_*` | Yes, with rate limits |
| `web3_*` | Yes, with rate limits |
| `xgr_*` | Endpoint-specific |
| `txpool_*` | Usually no; internal or controlled |
| `debug_*` | No |
| gRPC | No |
| Metrics | No |

A public RPC node should not hold validator signing material.

A validator node should not be used as a high-volume public RPC endpoint.

---

## 26. XGR extension endpoint exposure

XGR extension endpoints can have different exposure requirements.

Some may be safe for public read access.

Some may require permits.

Some may be appropriate only behind application backends.

Some may depend on off-chain services such as a grant database.

Endpoint exposure should be decided per method based on:

- whether it mutates off-chain state
- whether it reveals metadata
- whether it requires a permit
- whether it has expensive execution cost
- whether it accesses encrypted grant records
- whether it depends on private infrastructure
- whether it can be abused for enumeration
- whether it requires rate limiting

Do not expose all XGR extension endpoints merely because standard Ethereum RPC is public.

---

## 27. Operator deployment patterns

### 27.1 Validator node

Recommended proxy / gateway |
| Public RPC WebSocket | Reverse proxy / gateway with limits |
| Debug RPC | Internal only |
| TxPool RPC | Internal or controlled infrastructure |
| XDaLa extension RPC | Endpoint-specific policy |
| Database-backed grant services | Private service network |

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

Node RPC exposure is an operator-controlled boundary.

The node may expose several RPC surfaces.

| Surface | Purpose | Recommended exposure |
|---|---|---|
| `eth_*` | Ethereum-compatible wallet/app/explorer RPC | Public only with limits |
| `net_*` | Network metadata | Public only with limits |
| `web3_*` | Client/version/helper methods | Public only with limits |
| `txpool_*` | Transaction pool inspection | Internal / controlled |
| `debug_*` | Execution tracing | Internal only |
| `xgr_*` | XGR extension methods | Endpoint-specific |
| gRPC operator services | Node management and diagnostics | Internal only |
| Metrics | Monitoring | Internal only |

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

The node supports a CORS allow-origin setting through the runtime configuration.

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

Debug methods include tracing methods such as:

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

The node supports a concurrent debug request limit.

Relevant runtime control:

```text
--concurrent-requests-debug
```

Debug tracing should be isolated from public RPC workloads and validator-critical operation.

---

## 8. TxPool boundary

The TxPool is local node state.

It is not consensus state.

A transaction can be:

- validly signed but rejected by a local txpool
- accepted by one node but not yet seen by another
- queued because of nonce ordering
- replaced by a higher-priced transaction
- gossiped but rejected by peers
- mined without appearing in every public txpool view

TxPool admission checks include:

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

TxPool RPC methods should be considered operator/infrastructure APIs, not public application APIs.

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

The structure supports fields such as:

```text
contractDeployerAllowList
contractDeployerBlockList
transactionsAllowList
transactionsBlockList
```

Each address-list config can contain:

```text
adminAddresses
enabledAddresses
```

The published mainnet genesis does not configure these address-list fields.

That means the current published XGR Chain configuration does not activate a chain-level contract-deployer or transaction allow/block list through genesis.

If a future published configuration uses these fields, the operational behavior must be documented against the active release that activates them.

Do not infer active chain-level allowlist behavior merely because schema fields exist in code.

Schema availability is not the same as network activation.

---

## 11. Validator authority boundary

Validator authority is determined by the active consensus and validator-set rules.

In the current published baseline, the genesis configures IBFT validator data through the genesis configuration.

In staking-enabled releases, validator authority may depend on additional staking state and activation rules.

Relevant concepts can include:

- validator registration
- validator key material
- validator set membership
- current consensus header validator set
- staking active flag
- self-stake
- delegated stake
- stake-weighted voting power
- epoch-boundary activation
- epoch-boundary deactivation
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

A dashboard should not infer current consensus participation from staking contract state alone when a dedicated consensus-derived field is available.

---

## 12. Validator key isolation

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

## 13. Contract-level permissions

Smart contracts can implement their own permissions.

Common patterns:

- owner-only functions
- executor lists
- role checks
- session owner checks
- rule owner checks
- grant manager checks
- upgrade authority
- emergency pause authority
- delegated execution authority

Contract-level permissions are enforced by contract logic.

They are separate from:

- P2P access
- RPC exposure
- txpool admission
- validator set membership
- XDaLa off-chain grant storage

For XGR standards, contract-level permissions can be used by:

- XRC-137 rule contracts
- XRC-729 orchestration/session contracts
- key registry contracts
- application-specific contracts

Contract ownership should be audited independently from node infrastructure.

---

## 14. XRC-137 permission boundary

XRC-137 belongs to the XGR extension layer.

It defines rule-document / rule-contract behavior.

Typical permission concerns include:

- who owns the rule contract
- who can update rule content
- who can execute or reference a rule
- whether rule content is plaintext or encrypted
- whether an owner read key exists
- whether XDaLa can load the rule
- whether the caller has the required permit or contract authority

XRC-137 permissions are not chain-wide RPC permissions.

They are rule-contract and XDaLa integration permissions.

Availability depends on the deployed contract and active XGR release stack.

---

## 15. XRC-729 permission boundary

XRC-729 belongs to the XGR extension layer.

It defines orchestration/session behavior.

Typical permission concerns include:

- orchestration owner
- session owner
- executor authority
- session control authority
- wake/pause/resume/kill authority
- gas budget authority
- contract-mediated execution authority
- permit-based execution authorization

XRC-729 permissions are not validator permissions.

They control process execution and session behavior.

Availability depends on deployed contracts and active XGR release stack.

---

## 16. XDaLa permit boundary

XDaLa permits are EIP-712 typed-data signatures.

They authorize specific XDaLa actions without requiring an on-chain authorization transaction for every action.

Permit properties:

- deterministic typed-data structure
- chain ID binding
- expiry
- signer recovery
- action-specific authority checks
- wallet signing through `eth_signTypedData_v4`

Permit payloads usually contain:

- `domain`
- `types`
- `primaryType`
- `message`
- `signature`

A permit proves signed authorization for a specific XDaLa action.

It does not make the signer a validator.

It does not grant P2P access.

It does not bypass transaction validity.

---

## 17. SessionPermit

`SessionPermit` authorizes starting or continuing a specific XDaLa session under a specific orchestration.

High-level domain fields:

| Field | Meaning |
|---|---|
| `name` | `XDaLa SessionPermit` |
| `version` | Permit version |
| `chainId` | Chain ID binding |

High-level message fields:

| Field | Meaning |
|---|---|
| `from` | Signer and authority holder |
| `ostcId` | Orchestration identifier |
| `ostcHash` | Hash of orchestration structure |
| `sessionId` | Root session ID |
| `maxTotalGas` | Total gas budget cap |
| `expiry` | Unix expiry timestamp |

High-level checks:

- typed-data domain must match expected domain
- chain ID must match network chain ID
- permit must not be expired
- recovered signer must match `message.from`
- signer must satisfy the required orchestration/session authority rule

---

## 18. xdalaPermit

`xdalaPermit` authenticates a caller for grant-management and grant-listing operations.

High-level domain fields:

| Field | Meaning |
|---|---|
| `name` | Non-empty domain name |
| `version` | Non-empty domain version |
| `chainId` | Chain ID binding |

High-level message fields:

| Field | Meaning |
|---|---|
| `from` | Signer / caller identity |
| `expiry` | Unix expiry timestamp |

High-level checks:

- chain ID must match
- permit must not be expired
- recovered signer identifies the caller
- endpoint parameters define the action scope

This permit is intentionally minimal.

The action scope is defined by the endpoint request parameters, such as RID, scope, grantee, owner or filters.

---

## 19. ControlPermit

`ControlPermit` authorizes XDaLa session control actions.

Typical actions:

```text
pause
resume
kill
wake
```

High-level domain fields:

| Field | Meaning |
|---|---|
| `name` | Non-empty domain name |
| `version` | Non-empty domain version |
| `chainId` | Chain ID binding |
| `verifyingContract` | Expected control-domain verifying contract |

High-level message fields:

| Field | Meaning |
|---|---|
| `from` | Signer identity |
| `sessionId` | Root session ID |
| `action` | Control action |
| `expiry` | Unix expiry timestamp |

High-level checks:

- chain ID must match
- verifying contract must match expected control domain
- action must be allowed
- permit must not be expired
- signer must satisfy the required session-control authority rule

---

## 20. XDaLa grants boundary

XDaLa grants control encrypted-data access.

They are not chain-level allowlists.

They are not validator permissions.

They are not P2P permissions.

The grant model protects encrypted content such as:

- XRC-137 rule documents
- XDaLa engine logs
- encrypted execution output where supported

Grant storage model:

| Component | Storage | Purpose |
|---|---|---|
| Read public keys | On-chain key registry | Public keys for wrapping DEKs |
| Grants | PostgreSQL grants database | Access rights and wrapped DEKs |
| Encrypted blobs | On-chain contract data or logs/responses | Ciphertext content |

Grants are database-backed authorization records for encrypted data access.

---

## 21. Grant rights

Grant rights are bitmask-based.

| Right | Value | Meaning |
|---|---:|---|
| READ | `1` | Can decrypt content |
| WRITE | `2` | Can update content where supported |
| MANAGE | `4` | Can manage sub-grants |

Common combinations:

| Rights | Meaning |
|---:|---|
| `1` | Reader |
| `3` | Reader + writer |
| `7` | Owner / full rights |

Grant rights apply to encrypted content access.

They do not authorize arbitrary chain transactions.

---

## 22. Grant scope

Grants are scoped.

| Scope | Meaning |
|---:|---|
| `1` | Session / prepare / rule document |
| `2` | Engine log |
| `3` | Field-level scope, reserved |

A grant is identified by:

- RID
- scope
- grantee address

The grant database enforces uniqueness by RID, grantee and scope.

A grant for one RID/scope does not automatically grant access to another RID/scope.

---

## 23. Encryption boundary

XDaLa encryption separates plaintext access from chain execution.

High-level model:

1. content is encrypted with a random data encryption key
2. the encrypted blob is stored or emitted
3. the data encryption key is wrapped for authorized recipients
4. wrapped keys and access rights are stored in grant records
5. recipients decrypt only if they have a valid grant and corresponding private key

Important security properties:

- plaintext is not exposed merely because ciphertext is public
- read public keys can be on-chain
- private read keys remain user-side
- grant records determine who can access wrapped DEKs
- expired grants should not authorize access
- READ permission is required for decryption

A grant authorizes encrypted data access, not consensus behavior.

---

## 24. Access matrix

High-level access-control matrix:

| Action | Boundary |
|---|---|
| Connect to node as peer | P2P/network configuration |
| Discover peers | Bootnode/discovery configuration |
| Serve public RPC | Infrastructure/RPC exposure |
| Submit raw transaction | RPC exposure plus transaction validity |
| Enter local txpool | TxPool admission |
| Execute transaction | Protocol validity and block inclusion |
| Participate in consensus | Active validator-set rules |
| Sign consensus messages | Validator key material |
| Trace transaction | Debug RPC exposure |
| Inspect txpool | TxPool RPC exposure |
| Manage XDaLa grants | XDaLa permit plus grant rules |
| Decrypt XDaLa content | Grant rights plus recipient private key |
| Control XDaLa session | ControlPermit / session authority |
| Update contract state | Contract-level permission and valid transaction |

Use the correct boundary for the correct action.

---

## 25. Public RPC exposure policy

Recommended public RPC exposure:

| Namespace | Public exposure |
|---|---|
| `eth_*` | Yes, with rate limits and method controls |
| `net_*` | Yes, with rate limits |
| `web3_*` | Yes, with rate limits |
| `xgr_*` | Endpoint-specific |
| `txpool_*` | Usually no; internal or controlled |
| `debug_*` | No |
| gRPC | No |
| Metrics | No |

A public RPC node should not hold validator signing material.

A validator node should not be used as a high-volume public RPC endpoint.

---

## 26. XGR extension endpoint exposure

XGR extension endpoints can have different exposure requirements.

Some may be safe for public read access.

Some may require permits.

Some may be appropriate only behind application backends.

Some may depend on off-chain services such as a grant database.

Endpoint exposure should be decided per method based on:

- whether it mutates off-chain state
- whether it reveals metadata
- whether it requires a permit
- whether it has expensive execution cost
- whether it accesses encrypted grant records
- whether it depends on private infrastructure
- whether it can be abused for enumeration
- whether it requires rate limiting

Do not expose all XGR extension endpoints merely because standard Ethereum RPC is public.

---

## 27. Operator deployment patterns

### 27.1 Validator node

Recommended validator node boundaries:

| Surface | Policy |
|---|---|
| P2P | Reachable according to validator topology |
| JSON-RPC | Local/private |
| gRPC | Local/private |
| Debug RPC | Internal only, preferably disabled from public paths |
| TxPool RPC | Internal only |
| Metrics | Monitoring network only |
| Validator key | Present and protected |
| Public HTTP gateway | Avoid |

### 27.2 Public RPC node

Recommended public RPC node boundaries:

| Surface | Policy |
|---|---|
| P2P | Reachable as needed |
| JSON-RPC | Public through reverse proxy |
| gRPC | Local/private |
| Debug RPC | Not public |
| TxPool RPC | Not public unless intentionally controlled |
| Metrics | Monitoring network only |
| Validator key | Absent |
| Sealing | Disabled for non-validator RPC nodes |

### 27.3 Internal tracing node

Recommended tracing node boundaries:

| Surface | Policy |
|---|---|
| JSON-RPC | Internal |
| Debug RPC | Internal only |
| TxPool RPC | Internal only |
| gRPC | Local/private |
| Metrics | Monitoring network |
| Validator key | Absent |
| Sealing | Disabled unless intentionally validator |

### 27.4 XDaLa service node

Recommended XDaLa service node boundaries:

| Surface | Policy |
|---|---|
| Standard RPC | As required by application |
| XGR extension RPC | Endpoint-specific |
| Grant database | Private service network |
| Permit validation | Required where applicable |
| Debug RPC | Internal only |
| Validator key | Absent unless also a validator by explicit design |

XDaLa service nodes may need database connectivity that normal public RPC nodes do not need.

That database boundary must be protected independently.

---

## 28. Common failure modes

### 28.1 Public RPC exposes debug methods

Impact:

- expensive tracing calls can overload the node
- execution internals become visible
- attackers can force high CPU/memory usage

Fix:

- block `debug_*` at proxy or method-filter layer
- route tracing to internal nodes only
- monitor debug request volume

---

### 28.2 Public RPC runs on validator node

Impact:

- validator resources compete with public traffic
- validator key material is colocated with public interface
- RPC abuse can affect consensus participation

Fix:

- move public RPC to non-validator nodes
- keep validator JSON-RPC local/private
- isolate validator infrastructure

---

### 28.3 CORS treated as security

Impact:

- browser access may be limited
- non-browser clients can still call the endpoint
- endpoint remains exposed

Fix:

- use firewall/reverse proxy/rate limits
- use CORS only as browser policy
- do not rely on CORS for authorization

---

### 28.4 Grant exists but decryption fails

Likely causes:

- grant expired
- READ right missing
- wrong RID
- wrong scope
- wrong grantee address
- stale read public key
- private read key mismatch
- corrupted `encDEK`
- unsupported encryption format

Fix:

- verify RID and scope
- verify grant rights
- verify expiry
- verify grantee address
- verify read key registration
- verify encrypted payload format

---

### 28.5 Permit rejected

Likely causes:

- wrong chain ID
- expired permit
- wrong domain name
- wrong version
- wrong verifying contract where required
- recovered signer mismatch
- signer lacks required authority
- malformed signature
- unsupported primary type
- action not allowed

Fix:

- rebuild typed data exactly
- verify chain ID
- verify expiry
- verify `primaryType`
- verify domain fields
- verify recovered signer
- verify contract/session authority

---

### 28.6 Transaction valid but not accepted into txpool

Likely causes:

- fee too low
- base fee not covered
- `priceLimit` not satisfied
- nonce too low
- nonce gap
- insufficient balance
- block gas limit exceeded
- txpool full
- replacement underpriced
- wrong transaction type for active fork

Fix:

- check txpool status
- check account nonce
- check account balance
- check effective gas price
- check transaction type
- retry through a synced node

---

## 29. Security checklist

For validators:

- validator key isolated
- public RPC avoided
- debug RPC not public
- gRPC not public
- metrics private
- P2P reachable as required
- firewall configured
- filesystem permissions restricted
- backups encrypted
- signer errors monitored

For public RPC:

- no validator keys
- debug blocked
- gRPC private
- metrics private
- rate limits active
- batch limits active
- block-range limits active
- WebSocket limits active
- txpool namespace controlled
- resource usage monitored

For XDaLa/grants:

- permits verified
- chain ID checked
- expiry checked
- grant rights enforced
- grant database private
- READ required for decryption
- MANAGE required for grant administration where applicable
- read private keys stay user-side
- encrypted content treated as ciphertext only
- grant enumeration controlled

For contracts:

- owner roles reviewed
- executor roles reviewed
- upgrade authority reviewed
- session authority reviewed
- pause/emergency authority reviewed where applicable
- permissions tested before production deployment

---

## 30. Summary

| Boundary | Controls |
|---|---|
| Infrastructure | Firewall, proxy, TLS, rate limits, host access |
| P2P | Network key, peer ID, bootnodes, discovery, peer limits |
| RPC | Namespace exposure, method filtering, CORS, rate limits |
| Debug | Internal tracing access and concurrency limits |
| TxPool | Local admission rules and pool limits |
| Transaction validity | Signature, chain ID, nonce, balance, gas and fee rules |
| Validator authority | Consensus validator set and active release rules |
| Contract permissions | Contract owner/executor/role logic |
| XDaLa permits | EIP-712 signed authorization |
| XDaLa grants | RID/scope/grantee rights for encrypted data access |

The correct security model is layered.

No single mechanism replaces the others.
