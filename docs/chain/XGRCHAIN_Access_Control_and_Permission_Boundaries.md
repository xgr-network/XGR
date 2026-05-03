# XGR Chain — Access Control & Permission Boundaries

**Document ID:** XGRCHAIN-ACCESS-CONTROL  
**Last updated:** 2026-05-03  
**Audience:** Protocol developers, node operators, XDaLa integrators, auditors  
**Implementation status:** Mixed  
**Source of truth:** `xgrchain`, `xgr-node`, `XGR/docs/XDaLa_Permit_Catalog.md`, `XGR/docs/xgr_encryptionGrants.md`

---

## 1. Scope

This document explains the **access-control and permission boundaries** relevant to XGR Chain and XDaLa.

It covers:

- chain-level access control boundaries
- operator-level access control
- XDaLa permit-based authorization
- XDaLa grants
- contract-level access control
- legacy Polygon Edge ACL precompiles
- what should not be documented as active XGR functionality

This document replaces old Polygon Edge allowlist/blocklist documentation as an XGR-specific boundary document.

---

## 2. Key distinction

XGR has multiple permission layers. They must not be mixed.

| Layer | Purpose | Implementation status |
|---|---|---|
| Network/p2p access | Controls peer connectivity operationally | Mainnet |
| Node/RPC exposure | Controls who can call node interfaces | Mainnet / operator policy |
| Ethereum transaction validity | Standard EVM transaction validation | Mainnet |
| Contract-level permissions | Solidity-level ownership/executor logic | Mainnet where used |
| XDaLa permits | EIP-712 authorization for XDaLa actions | Mainnet |
| XDaLa grants | Off-chain grant database for encrypted data access | Mainnet |
| Legacy Edge ACL precompiles | Network-level allow/block list precompiles | Legacy / not part of current XGR docs |

The old Edge allowlist documents described generic network-level ACL precompiles. Those must not be confused with XDaLa grants or EIP-712 permits.

---

## 3. Current XGR permission model

Current XGR documentation should describe permissioning through these mechanisms:

### 3.1 Operator-level controls

Operators control access using infrastructure:

- firewall rules
- reverse proxies
- CORS policy
- RPC namespace exposure
- rate limits
- debug endpoint isolation
- gRPC isolation
- validator key isolation
- public vs private node separation

This is documented in:

- `XGRCHAIN_Node_Operation.md`
- `XGRCHAIN_Node_Operator_RPC_Reference.md`
- `XGRCHAIN_Networking_P2P.md`

### 3.2 Transaction-level controls

Transactions are accepted or rejected according to:

- signature validity
- chain ID
- nonce
- balance
- intrinsic gas
- gas limit
- fee rules
- txpool price limits
- transaction type / active fork rules

This is not an allowlist. It is normal EVM transaction validation.

Relevant documents:

- `XGRCHAIN_Ethereum_JSON_RPC_Reference.md`
- `XRC-GAS_Gas_Price_Behavior.md`
- `XGRCHAIN_Node_Operator_RPC_Reference.md`

### 3.3 Contract-level controls

Smart contracts may implement their own access control.

Examples:

- owner-only functions
- executor lists
- rule owner checks
- orchestration owner checks
- contract-defined role systems

For XGR standards:

- XRC-137 has owner/executor-related behavior.
- XRC-729 has owner/executor/session-related behavior.
- XDaLa validates authority through contract state and signed permits where required.

Relevant documents:

- `XRC-137_Smart_Contract_Standard.md`
- `XRC-729_Smart_Contract_Standard.md`
- `XDaLa_Permit_Catalog.md`

### 3.4 XDaLa permits

XDaLa permits are EIP-712 typed-data signatures.

They authorize specific XDaLa actions without requiring an on-chain permission transaction for every action.

Permit properties:

- deterministic typed-data format
- replay protection through chain ID and expiry
- signer recovery
- action-specific authority checks
- wallet-friendly signing through `eth_signTypedData_v4`

Relevant permit types include:

| Permit | Purpose |
|---|---|
| `SessionPermit` | authorizes starting/continuing a session under an orchestration |
| `xdalaPermit` | authenticates grant-management and grant-listing calls |
| `ControlPermit` | authorizes session control actions such as pause/resume/kill/wake |

Canonical document:

- `XDaLa_Permit_Catalog.md`

### 3.5 XDaLa grants

XDaLa grants control encrypted data access.

They are not chain-level allowlists.

Current grant model:

- read public keys are on-chain
- grants are stored off-chain in PostgreSQL
- encrypted content is accessed through grant records
- grants include rights such as READ, WRITE and MANAGE
- grants are scoped by RID and scope
- grants can expire
- grant operations are gasless RPC actions

Canonical document:

- `xgr_encryptionGrants.md`

---

## 4. Legacy Edge ACL model

Older Polygon Edge documentation described network-level ACL precompiles.

That model included:

| Legacy concept | Description |
|---|---|
| Admin role | address with authority to manage an ACL |
| Enabled role | address granted access by an ACL |
| NoRole | address without permissions |
| Contract deployer allow/block lists | controls which addresses can deploy contracts |
| Transaction allow/block lists | controls which addresses can send transactions |
| Bridge allow/block lists | controls bridge interactions |
| ACL precompile ABI | `setAdmin`, `setEnabled`, `setNone`, `readAddressList` |
| Genesis-only activation | lists enabled during network initialization |
| Mutual exclusion | allowlist and blocklist for same list type should not both be active |
| System transaction bypass | system address excluded from allow/block list checks |

This legacy model is retained here only to document why the old files should not be migrated as active XGR documentation.

---

## 5. Legacy ACL ABI reference

The old Edge ACL ABI was:

```solidity
function setAdmin(address account)
function setEnabled(address account)
function setNone(address account)
function readAddressList(address account) returns (uint256)
```

Roles:

| Role | Meaning |
|---|---|
| `NoRole` | no permissions |
| `EnabledRole` | enabled for the specific list |
| `AdminRole` | can manage list entries |

This ABI should not be presented as an active XGR public interface unless the corresponding precompile is intentionally reintroduced and verified in the current implementation.

---

## 6. Why old Edge ACL docs are not canonical for XGR

The old docs are not suitable as XGR public documentation because they mix several legacy concepts:

- Edge-powered chain wording
- Bridge allow/block lists
- Rootchain/Supernet deployment assumptions
- ACL precompiles not found as active implementation in the checked XGR code paths
- genesis-only allowlist setup that is not part of current XGR public docs
- examples referring to bridge allow/block lists
- generic placeholders instead of current XGR addresses and contracts

Current XGR access control is better represented by:

- infrastructure restrictions
- txpool/transaction validation
- contract-level ownership/executor logic
- EIP-712 permits
- grants database for encrypted data access

---

## 7. Public RPC access policy

Public RPC nodes should expose only the required public namespaces.

Recommended exposure:

| Namespace | Public? | Notes |
|---|---|---|
| `eth_*` | Yes, with rate limits | public wallet/explorer compatibility |
| `net_*` | Yes, with rate limits | basic network metadata |
| `web3_*` | Yes, with rate limits | client/version/hash helpers |
| `xgr_*` | Policy-dependent | some endpoints may require permits or private deployment policy |
| `debug_*` | No | internal/operator only |
| `txpool_*` | No / not active unless reintroduced | operator only if present |
| gRPC operator services | No | internal only |

Recommended controls:

- firewall private RPC interfaces
- use a reverse proxy for public RPC
- apply batch limits
- apply block-range limits
- limit WebSocket read size
- isolate debug tracing from public endpoints
- avoid exposing validator nodes directly to public RPC traffic

---

## 8. P2P access boundary

The p2p layer controls node connectivity, not application authorization.

Important points:

- bootnodes help discovery
- bootnodes do not grant validator rights
- peer connection does not imply consensus authority
- validator authority is determined by consensus/validator-set rules
- public full nodes may connect without being validators, depending on network policy
- network key controls peer identity, not transaction authority

Relevant document:

- `XGRCHAIN_Networking_P2P.md`

---

## 9. Validator access boundary

Validator participation is not controlled by old Edge ACL precompiles.

Current/future validator access belongs in:

- `XGRCHAIN_Consensus_IBFT.md`
- `XGRCHAIN_Staking_PoS_Model.md`

For the upcoming PoS model, the relevant concepts are expected to be:

- validator registration
- self-stake
- delegated stake
- weighted voting power
- active validator set selection
- activation/deactivation timing
- uptime/reward eligibility

Those must be documented in the PoS file, not in this legacy ACL section.

---

## 10. Contract-level access examples

XGR contract standards contain their own authorization logic.

### XRC-137

Typical permission concepts:

- owner
- rule updates
- executor management
- encrypted/plain rule handling

Documented in:

- `XRC-137_Smart_Contract_Standard.md`

### XRC-729

Typical permission concepts:

- owner
- orchestration/session definitions
- executor management
- session-related execution authority

Documented in:

- `XRC-729_Smart_Contract_Standard.md`

These are contract-level controls. They are not global chain allowlists.

---

## 11. XDaLa permit authority examples

### SessionPermit

Used for session execution/continuation.

High-level checks:

- typed-data domain is correct
- chain ID matches
- permit not expired
- recovered signer equals `message.from`
- signer has required authority, e.g. orchestration owner

### xdalaPermit

Used for grant listing and grant management.

High-level checks:

- typed-data domain is valid
- chain ID matches
- permit not expired
- recovered signer identifies the caller

### ControlPermit

Used for session control actions.

Actions include:

```text
pause
resume
kill
wake
```

These are XDaLa-specific authorization flows. They should not be documented as chain-wide ACLs.

---

## 12. XDaLa grant rights

Grant rights are bitmask-based.

| Right | Value | Meaning |
|---|---:|---|
| READ | 1 | can decrypt content |
| WRITE | 2 | can update content |
| MANAGE | 4 | can manage sub-grants |

Common combinations:

| Rights | Meaning |
|---:|---|
| 1 | reader |
| 3 | reader + writer |
| 7 | owner / full rights |

Grants are scoped:

| Scope | Meaning |
|---|---|
| 1 | session / prepare / rule document |
| 2 | engine log |
| 3 | field, reserved |

This is the active XDaLa data-access model.

---

## 13. What not to document as active XGR behavior

Do not document the following as active XGR Chain behavior unless reintroduced and verified:

| Legacy item | Decision |
|---|---|
| Contract deployer allowlist precompile | not canonical |
| Contract deployer blocklist precompile | not canonical |
| Transaction allowlist precompile | not canonical |
| Transaction blocklist precompile | not canonical |
| Bridge allowlist precompile | legacy / bridge removed |
| Bridge blocklist precompile | legacy / bridge removed |
| `setAdmin(address)` ACL precompile ABI | legacy unless reintroduced |
| `setEnabled(address)` ACL precompile ABI | legacy unless reintroduced |
| `setNone(address)` ACL precompile ABI | legacy unless reintroduced |
| `readAddressList(address)` ACL precompile ABI | legacy unless reintroduced |
| Genesis-only Edge ACL setup as public XGR guidance | not canonical |
| System transaction bypass in Edge ACLs | not part of current public XGR docs |

---

## 14. If network-level ACLs are reintroduced

If XGR later intentionally reintroduces network-level allow/block lists, the documentation must define:

1. exact precompile addresses
2. exact ABI
3. genesis activation fields
4. list types
5. admin initialization rules
6. allowlist vs blocklist precedence
7. system transaction behavior
8. static-call behavior
9. gas cost behavior
10. security implications
11. migration behavior
12. interaction with PoS validator join
13. interaction with XDaLa permits and grants

Until then, old Edge ACL docs remain legacy.

---

## 15. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Node_Operation.md` | node operation and RPC exposure |
| `XGRCHAIN_Node_Operator_RPC_Reference.md` | debug/txpool operator-only surfaces |
| `XGRCHAIN_Networking_P2P.md` | p2p networking and bootnodes |
| `XGRCHAIN_Consensus_IBFT.md` | validator consensus model |
| `XGRCHAIN_Staking_PoS_Model.md` | future staking/validator permission model |
| `XDaLa_Permit_Catalog.md` | EIP-712 XDaLa permits |
| `xgr_encryptionGrants.md` | XDaLa grant and encryption model |
| `XRC-137_Smart_Contract_Standard.md` | rule contract authorization |
| `XRC-729_Smart_Contract_Standard.md` | orchestration contract authorization |
