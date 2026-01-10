# XRC-137 Smart Contract Standard (Rule Container Contract)

**Document ID:** XRC-137-CONTRACT  
**Status:** Draft (pre-launch)  
**Language:** English  
**Audience:** Contract integrators, SDK/tooling developers, auditors.

---

## 1. Purpose

An XRC-137 contract is an on-chain **container** for a single XRC-137 rule document plus minimal metadata required by xDaLa:

- The rule payload (`ruleJson`) as either:
  - **Plain JSON**, or
  - an **XGR1 envelope string** (encrypted form)
- A human-friendly identifier (`nameXRC`)
- Optional encryption metadata (`encrypted`) to describe the XGR1 envelope
- Ownership for authorization of on-chain mutations
- An optional **executor allowlist** (`getExecutorList()`) used by xDaLa to allow delegated execution flows

The xDaLa Engine treats the XRC-137 contract address as the authoritative source of the rule document for a step.

---

## 2. Storage Model and Semantics

An XRC-137 contract stores:

- `ruleJson` (`string`): either plain JSON (XRC-137 rule document) or an XGR1 envelope string
- `nameXRC` (`string`): display identifier (current implementation uses a constant string)
- `encrypted` (`EncInfo`): encryption header metadata
  - `rid` (`bytes32`): rule identifier associated with encryption (non-zero indicates “encrypted”)
  - `suite` (`string`): identifier of the crypto suite used (e.g., `XGR1-AESGCM-...`)
  - `encDEK` (`bytes`): encrypted data-encryption key material (opaque bytes)
- `owner` (`address`): on-chain mutation authority
- `executorList` (`address[]`, optional extension): allowlist of delegated executors for xDaLa authorization

### 2.1 Encryption indicator

The contract exposes:

- `isEncrypted() → bool`

When the rule is plain JSON:
- `encrypted.rid` is zero (`0x00…00`)
- `encrypted.suite` is the empty string
- `encrypted.encDEK` is empty
- `isEncrypted()` returns `false`

When the rule is encrypted:
- `ruleJson` contains an XGR1 envelope string
- `encrypted.rid` and `encrypted.suite` are set accordingly
- `encrypted.encDEK` may be set (deployment-dependent)
- `isEncrypted()` returns `true`

### 2.2 XGR1 envelope (high-level)

The XGR1 envelope is a compact string representation of encrypted rule data. At minimum, it carries:

- the suite identifier
- the rule identifier (`rid`)
- the ciphertext (often base64 encoded)

The exact envelope grammar is part of the encryption standard used by the xDaLa ecosystem; XRC-137 only defines that **the rule string may be XGR1** and that `encrypted` provides metadata required to interpret it.

### 2.3 Executor allowlist (optional extension)

XRC-137 may expose an executor list via:

- `getExecutorList() → address[]`

This list is **not** used for on-chain rule mutability. It exists to support delegated operational models (e.g., FinTech-managed processes) where an external party runs or sells processes on behalf of end users.

A conforming xDaLa implementation may treat:

- `owner` as always authorized, and
- any `executor ∈ getExecutorList()` as authorized,

for **engine-side authorization** (e.g., preflight checks, permission to start sessions referencing this rule contract, etc.).

For backward compatibility, xDaLa must treat contracts that do **not** implement `getExecutorList()` as **owner-only**.

---

## 3. Access Control

### 3.1 On-chain (Solidity) access control

Only the `owner` may perform on-chain mutations, including:

- updating the rule payload (`updateRule`, `setRuleAndEncrypted`)
- transferring ownership (`transferOwnership`)
- managing executors (`addExecutor`, `removeExecutor`) if the extension is implemented

**Executors must never have on-chain write authority** for the rule payload or encryption metadata.

### 3.2 Engine-side (xDaLa) authorization

xDaLa may require the signer (from the permit / session start) to be:

- the `owner`, or
- an address present in `getExecutorList()` (if implemented)

If `getExecutorList()` is not implemented, xDaLa enforces **owner-only**.

---

## 4. ABI (Authoritative Interface)

### 4.1 Solidity interface (canonical)

```solidity
pragma solidity ^0.8.0;

interface IXRC137 {
    // Events
    event RuleUpdated(string newRule);
    event EncryptedSet(bytes32 rid, string suite);
    event EncryptedCleared();

    // Optional executor extension events
    event ExecutorAdded(address indexed executor);
    event ExecutorRemoved(address indexed executor);

    // Read API
    function getRule() external view returns (string memory);
    function getNameXRC() external view returns (string memory);
    function isEncrypted() external view returns (bool);

    // Public struct getter (compiler-generated for `EncInfo public encrypted;`)
    function encrypted() external view returns (bytes32 rid, string memory suite, bytes memory encDEK);

    // Write API (owner-only)
    function updateRule(string memory jsonOrBlob) external;
    function setRuleAndEncrypted(
        string calldata jsonOrBlob,
        bytes32 rid,
        string calldata suite,
        bytes calldata encDEK
    ) external;
    function transferOwnership(address newOwner) external;

    // Optional executor extension (owner-only)
    function addExecutor(address exec) external;
    function removeExecutor(address exec) external;
    function getExecutorList() external view returns (address[] memory);
}
```

Notes:
- `getRule()` must return the exact stored rule string (plain JSON or XGR1).
- `updateRule()` may be used for plaintext updates. If `jsonOrBlob` is an XGR1 envelope, the contract enforces that encryption metadata is set (either already or via `setRuleAndEncrypted`).
- `setRuleAndEncrypted()` updates the rule payload and encryption metadata atomically.

### 4.2 JSON ABI fragment (tooling-friendly)

Minimal ABI fragment suitable for ethers/web3 (includes executor extension):

```json
[
  { "type": "event", "name": "RuleUpdated", "inputs": [
    { "indexed": false, "name": "newRule", "type": "string" }
  ]},
  { "type": "event", "name": "EncryptedSet", "inputs": [
    { "indexed": false, "name": "rid", "type": "bytes32" },
    { "indexed": false, "name": "suite", "type": "string" }
  ]},
  { "type": "event", "name": "EncryptedCleared", "inputs": [] },

  { "type": "event", "name": "ExecutorAdded", "inputs": [
    { "indexed": true, "name": "executor", "type": "address" }
  ]},
  { "type": "event", "name": "ExecutorRemoved", "inputs": [
    { "indexed": true, "name": "executor", "type": "address" }
  ]},

  { "type": "function", "name": "getRule", "stateMutability": "view",
    "inputs": [], "outputs": [ { "name": "", "type": "string" } ] },

  { "type": "function", "name": "getNameXRC", "stateMutability": "view",
    "inputs": [], "outputs": [ { "name": "", "type": "string" } ] },

  { "type": "function", "name": "isEncrypted", "stateMutability": "view",
    "inputs": [], "outputs": [ { "name": "", "type": "bool" } ] },

  { "type": "function", "name": "encrypted", "stateMutability": "view",
    "inputs": [], "outputs": [
      { "name": "rid", "type": "bytes32" },
      { "name": "suite", "type": "string" },
      { "name": "encDEK", "type": "bytes" }
    ] },

  { "type": "function", "name": "updateRule", "stateMutability": "nonpayable",
    "inputs": [ { "name": "jsonOrBlob", "type": "string" } ],
    "outputs": [] },

  { "type": "function", "name": "setRuleAndEncrypted", "stateMutability": "nonpayable",
    "inputs": [
      { "name": "jsonOrBlob", "type": "string" },
      { "name": "rid", "type": "bytes32" },
      { "name": "suite", "type": "string" },
      { "name": "encDEK", "type": "bytes" }
    ],
    "outputs": [] },

  { "type": "function", "name": "transferOwnership", "stateMutability": "nonpayable",
    "inputs": [ { "name": "newOwner", "type": "address" } ],
    "outputs": [] },

  { "type": "function", "name": "addExecutor", "stateMutability": "nonpayable",
    "inputs": [ { "name": "exec", "type": "address" } ],
    "outputs": [] },

  { "type": "function", "name": "removeExecutor", "stateMutability": "nonpayable",
    "inputs": [ { "name": "exec", "type": "address" } ],
    "outputs": [] },

  { "type": "function", "name": "getExecutorList", "stateMutability": "view",
    "inputs": [], "outputs": [ { "name": "", "type": "address[]" } ] }
]
```

---

## 5. Integration Notes for xDaLa

A typical xDaLa consumer flow:

1. Resolve the XRC-137 contract address for the step.
2. Determine engine-side authorization:
   - read `owner` (via `owner()` or `getOwner()` depending on the contract)
   - attempt `getExecutorList()` (if unsupported, treat as “no executors”)
   - authorize signer if `signer == owner` OR `signer ∈ executorList`
3. Call `getRule()` to obtain:
   - plain JSON → parse as XRC-137 rule document
   - XGR1 envelope → decrypt using the available key material and parse the decrypted JSON
4. Evaluate and execute according to the XRC-137 rule document specification.

**Backward compatibility:** If `getExecutorList()` is not implemented (legacy XRC-137 deployments), xDaLa must enforce **owner-only** authorization.

---

## 6. Conformance

A contract is XRC-137 conformant if it:

- Implements the read API (`getRule`, `getNameXRC`, `isEncrypted`)
- Exposes the encryption header via the public getter `encrypted()`
- Enforces owner-only updates for write functions (`updateRule`, `setRuleAndEncrypted`, `transferOwnership`)
- Preserves the `encrypted` semantics (zero/empty indicates “not encrypted”)

If the executor extension is implemented, the contract must additionally:

- Implement `addExecutor`, `removeExecutor`, `getExecutorList`
- Emit `ExecutorAdded` / `ExecutorRemoved` accordingly
- Keep rule payload and encryption mutations strictly owner-only
