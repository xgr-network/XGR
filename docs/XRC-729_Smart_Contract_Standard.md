# XRC-729 Smart Contract Standard (Orchestration Registry)

**Document ID:** XRC-729-CONTRACT  
**Status:** Draft (pre-launch)  
**Language:** English  
**Audience:** Contract integrators, SDK/tooling developers, auditors.

---

## 1. Purpose

XRC-729 defines an **on-chain, auditable orchestration registry** for xDaLa processes.

- An **orchestration** is a directed process graph (steps, spawns, joins) that determines *which* XRC-137 rules are executed *when*, and how their outcomes branch.
- The orchestration is stored **exclusively on-chain** in an XRC-729 contract and retrieved by xDaLa at runtime.
- Because the orchestration is on-chain and addressable by ID (and optionally pinned by hash), any third party can reproduce and audit the process topology and branching logic.
- An optional **executor allowlist** (`getExecutorList()`) supports delegated execution flows where external parties run processes on behalf of end users.

This document specifies the required external interface and semantics for XRC-729 contracts.

---

## 2. Key Terms

| Term | Description |
|------|-------------|
| **OSTC** | *Orchestration Specification Text (Canonical)* – the canonical orchestration document stored as a UTF-8 JSON string |
| **Orchestration ID (`ostcId`)** | A human-readable identifier (string) used to reference a specific orchestration in the registry |
| **Registry contract (`xrc729`)** | The deployed XRC-729 contract instance that stores and serves OSTCs |
| **Registry name (`nameXRC`)** | A string name for the registry contract instance (e.g., `"XGR_XRC729"`), used for introspection and tooling |
| **xDaLa** | The execution engine that loads OSTCs from XRC-729 and runs sessions accordingly |
| **Executor** | An address authorized to run xDaLa sessions referencing this registry (engine-side authorization only) |

---

## 3. Storage Model and Semantics

An XRC-729 contract stores:

- `ostcJSON` (`mapping(string => string)`): OSTC documents keyed by ID
- `ostcIds` (`string[]`): list of all registered OSTC IDs
- `nameXRC` (`string`): display identifier for the registry
- `owner` (`address`): on-chain mutation authority
- `executorList` (`address[]`, optional extension): allowlist of delegated executors for xDaLa authorization

### 3.1 Executor Allowlist (Optional Extension)

XRC-729 may expose an executor list via:

- `getExecutorList() → address[]`

This list is **not** used for on-chain OSTC mutability. It exists to support delegated operational models (e.g., FinTech-managed processes) where an external party runs or sells processes on behalf of end users.

A conforming xDaLa implementation may treat:

- `owner` as always authorized, and
- any `executor ∈ getExecutorList()` as authorized,

for **engine-side authorization** (e.g., preflight checks, permission to start sessions referencing this registry, etc.).

For backward compatibility, xDaLa must treat contracts that do **not** implement `getExecutorList()` as **owner-only**.

---

## 4. Access Control

### 4.1 On-chain (Solidity) Access Control

Only the `owner` may perform on-chain mutations, including:

- creating/updating OSTCs (`setOSTC`)
- deleting OSTCs (`deleteOSTC`)
- managing executors (`addExecutor`, `removeExecutor`) if the extension is implemented

**Executors have no on-chain write authority.** They cannot modify OSTCs or registry state.

### 4.2 Engine-side (xDaLa) Authorization

xDaLa may require the signer (from the permit / session start) to be:

- the `owner`, or
- an address present in `getExecutorList()` (if implemented)

If `getExecutorList()` is not implemented, xDaLa enforces **owner-only**.

---

## 5. On-chain Interface (ABI)

### 5.1 Read Interface (Required)

A conforming XRC-729 registry MUST expose the following read functions:

#### Registry Name

```solidity
function getNameXRC() external view returns (string memory);
function nameXRC() external view returns (string memory); // public state variable
```

Returns the registry identifier string for tooling and introspection.

#### Existence Check

```solidity
function hasOSTC(string calldata id) external view returns (bool);
```

Returns `true` if an OSTC with that `id` exists in the registry.

#### Retrieve OSTC JSON

```solidity
function getOSTC(string calldata id) external view returns (string memory json);
```

- Returns the canonical OSTC JSON string for `id`.
- If `id` does not exist, the call MUST revert.
- The returned string MUST be valid UTF-8 JSON matching the orchestration specification.

#### List All OSTCs

```solidity
function getAllOSTC() external view returns (string[] memory);
```

Returns an array of all registered OSTC IDs.

#### Ownership

```solidity
function owner() external view returns (address);
```

Returns the registry owner/administrator.

### 5.2 Write Interface (Owner Only)

```solidity
function setOSTC(string calldata id, string calldata json) external;
function deleteOSTC(string calldata id) external;
function transferOwnership(address newOwner) external;
```

- Only the `owner` may call these functions.
- `setOSTC` creates or updates the OSTC for the given `id`.
- `deleteOSTC` removes the entry; `hasOSTC(id)` becomes `false`.
- `transferOwnership` transfers registry ownership to a new address.
  - `newOwner` cannot be `address(0)`.
  - If `newOwner` was an executor, they are automatically removed from the executor list (owner is implicitly authorized).

### 5.3 Executor Extension (Optional, Owner Only)

```solidity
function addExecutor(address exec) external;
function removeExecutor(address exec) external;
function getExecutorList() external view returns (address[] memory);
```

Semantics:

- Only `owner` may add or remove executors.
- `exec` cannot be `address(0)`.
- `exec` cannot be the `owner` (owner is implicitly authorized).
- Adding an already-present executor is a no-op.
- Removing a non-present executor is a no-op.
- `getExecutorList()` returns all currently registered executor addresses.

### 5.4 Solidity Interface (Canonical)

```solidity
pragma solidity ^0.8.0;

interface IXRC729 {
    // Events
    event OSTCSet(string indexed id);
    event OSTCDeleted(string indexed id);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Optional executor extension events
    event ExecutorAdded(address indexed executor);
    event ExecutorRemoved(address indexed executor);

    // Read API
    function getNameXRC() external view returns (string memory);
    function nameXRC() external view returns (string memory);
    function hasOSTC(string calldata id) external view returns (bool);
    function getOSTC(string calldata id) external view returns (string memory);
    function getAllOSTC() external view returns (string[] memory);
    function owner() external view returns (address);

    // Write API (owner-only)
    function setOSTC(string calldata id, string calldata json) external;
    function deleteOSTC(string calldata id) external;
    function transferOwnership(address newOwner) external;

    // Optional executor extension (owner-only)
    function addExecutor(address exec) external;
    function removeExecutor(address exec) external;
    function getExecutorList() external view returns (address[] memory);
}
```

### 5.5 JSON ABI Fragment (Tooling-Friendly)

```json
[
  { "type": "event", "name": "OSTCSet", "inputs": [
    { "indexed": true, "name": "id", "type": "string" }
  ]},
  { "type": "event", "name": "OSTCDeleted", "inputs": [
    { "indexed": true, "name": "id", "type": "string" }
  ]},
  { "type": "event", "name": "OwnershipTransferred", "inputs": [
    { "indexed": true, "name": "previousOwner", "type": "address" },
    { "indexed": true, "name": "newOwner", "type": "address" }
  ]},
  { "type": "event", "name": "ExecutorAdded", "inputs": [
    { "indexed": true, "name": "executor", "type": "address" }
  ]},
  { "type": "event", "name": "ExecutorRemoved", "inputs": [
    { "indexed": true, "name": "executor", "type": "address" }
  ]},

  { "type": "function", "name": "getNameXRC", "stateMutability": "view",
    "inputs": [], "outputs": [{ "name": "", "type": "string" }] },

  { "type": "function", "name": "nameXRC", "stateMutability": "view",
    "inputs": [], "outputs": [{ "name": "", "type": "string" }] },

  { "type": "function", "name": "hasOSTC", "stateMutability": "view",
    "inputs": [{ "name": "id", "type": "string" }],
    "outputs": [{ "name": "", "type": "bool" }] },

  { "type": "function", "name": "getOSTC", "stateMutability": "view",
    "inputs": [{ "name": "id", "type": "string" }],
    "outputs": [{ "name": "", "type": "string" }] },

  { "type": "function", "name": "getAllOSTC", "stateMutability": "view",
    "inputs": [], "outputs": [{ "name": "", "type": "string[]" }] },

  { "type": "function", "name": "owner", "stateMutability": "view",
    "inputs": [], "outputs": [{ "name": "", "type": "address" }] },

  { "type": "function", "name": "setOSTC", "stateMutability": "nonpayable",
    "inputs": [
      { "name": "id", "type": "string" },
      { "name": "json", "type": "string" }
    ], "outputs": [] },

  { "type": "function", "name": "deleteOSTC", "stateMutability": "nonpayable",
    "inputs": [{ "name": "id", "type": "string" }], "outputs": [] },

  { "type": "function", "name": "transferOwnership", "stateMutability": "nonpayable",
    "inputs": [{ "name": "newOwner", "type": "address" }], "outputs": [] },

  { "type": "function", "name": "addExecutor", "stateMutability": "nonpayable",
    "inputs": [{ "name": "exec", "type": "address" }], "outputs": [] },

  { "type": "function", "name": "removeExecutor", "stateMutability": "nonpayable",
    "inputs": [{ "name": "exec", "type": "address" }], "outputs": [] },

  { "type": "function", "name": "getExecutorList", "stateMutability": "view",
    "inputs": [], "outputs": [{ "name": "", "type": "address[]" }] }
]
```

---

## 6. Orchestration Document Format (OSTC JSON)

XRC-729 stores orchestration documents as JSON strings. The exact JSON schema is defined in:

- **"XRC-729 Orchestration Document & Session Semantics"** (companion specification)

At a high level, an OSTC contains:

- a unique orchestration `id`
- a `structure` object: a map from `nodeId` to node definition
- each node references an **XRC-137 rule contract address** (`rule`) and defines **branch behavior**:
  - `onValid`: spawns, joins
  - `onInvalid`: spawns, joins

---

## 7. Integration Notes for xDaLa

A typical xDaLa consumer flow:

1. Resolve the XRC-729 registry contract address.
2. Determine engine-side authorization:
   - read `owner()`
   - attempt `getExecutorList()` (if unsupported, treat as "no executors")
   - authorize signer if `signer == owner` OR `signer ∈ executorList`
3. Call `getOSTC(ostcId)` to obtain the orchestration JSON.
4. Parse and validate the OSTC against the orchestration schema.
5. Execute the process graph, loading XRC-137 rules as specified by each node.

**Backward compatibility:** If `getExecutorList()` is not implemented (legacy XRC-729 deployments), xDaLa must enforce **owner-only** authorization.

---

## 8. Version Pinning and Auditability

### Why Pinning Matters

If the registry entry for `ostcId` changes over time, then the same `ostcId` might refer to different process graphs at different points in time. For auditability, a session SHOULD be able to prove which exact OSTC text it used.

### Recommended Mechanism

- A session references `(xrc729Address, ostcId)` and MAY additionally carry an **expected hash** of the OSTC JSON.
- xDaLa loads the OSTC from `xrc729Address.getOSTC(ostcId)` and, if an expected hash is provided, verifies it matches.
- If the hash does not match, the session MUST fail deterministically (abort before executing any steps).

This achieves:

- **Determinism**: the orchestration topology is fixed for the session.
- **Auditability**: third parties can independently retrieve the OSTC and verify the hash.

---

## 9. Security Considerations

- **Access control**: Write functions are owner-restricted to prevent unauthorized process definition changes.
- **Executor separation**: Executors have engine-side authorization only; they cannot modify on-chain state.
- **Large JSON strings**: Storing very large orchestration documents increases gas cost for updates. Prefer compact and modular orchestrations.
- **Immutable registries**: For maximal auditability, organizations may choose to deploy immutable registries (no updates) and use new `ostcId`s for changes.

---

## 10. Conformance Checklist

A contract is XRC-729 compliant if it:

- [x] Exposes `getOSTC(string) → string`
- [x] Exposes `hasOSTC(string) → bool`
- [x] Exposes `getAllOSTC() → string[]`
- [x] Exposes a registry name function (`getNameXRC` and/or `nameXRC`)
- [x] Exposes `owner()`
- [x] Stores OSTCs as canonical UTF-8 JSON strings matching the orchestration spec
- [x] Enforces owner-only for write functions (`setOSTC`, `deleteOSTC`)

If the executor extension is implemented, the contract must additionally:

- [x] Implement `addExecutor`, `removeExecutor`, `getExecutorList`
- [x] Emit `ExecutorAdded` / `ExecutorRemoved` accordingly
- [x] Keep OSTC mutations strictly owner-only (executors have no write access)
- [x] Prevent owner from being added as executor (implicit authorization)
