# XRC-137 Smart Contract Standard (Rule Container Contract)

**Document ID:** XRC-137-CONTRACT  
**Status:** Draft (pre-launch)  
**Language:** English  
**Audience:** Contract integrators, SDK/tooling developers, auditors.

---

## 1. Purpose

An XRC-137 contract is an on-chain **container** for a single XRC-137 rule document (JSON) plus minimal metadata:

- A human-friendly name (`nameXRC`)
- Optional encryption metadata (`encrypted`) to indicate the rule is stored as an encrypted XGR1 envelope
- Ownership for authorization of updates

The xDaLa Engine treats the XRC-137 contract address as the authoritative source of the rule document for a step.

---

## 2. Storage Model and Semantics

An XRC-137 contract stores:

- `ruleJson` (string): either
  - **Plain JSON** of an XRC-137 rule document, or
  - an **XGR1 envelope string** (encrypted form)
- `nameXRC` (string): display/name metadata
- `encrypted` (struct EncInfo):
  - `rid` (bytes32): rule identifier associated with encryption
  - `suite` (string): identifier of the crypto suite used (e.g., `XGR1-AESGCM-...`)
- `owner` (address): update authority

### 2.1 Encryption indicator

The contract exposes:

- `isEncrypted() → bool`
- `getEncrypted() → (bytes32 rid, string suite)`

When the rule is plain JSON:
- `encrypted.rid` is zero (`0x00…00`)
- `encrypted.suite` is the empty string

When the rule is encrypted:
- `ruleJson` contains an XGR1 envelope string
- `encrypted.rid` and `encrypted.suite` are set accordingly
- `isEncrypted()` returns `true`

### 2.2 XGR1 envelope (high-level)

The XGR1 envelope is a compact string representation of encrypted rule data. At minimum, it carries:

- the suite identifier
- the rule identifier (`rid`)
- the ciphertext (often base64 encoded)

The exact envelope grammar is part of the encryption standard used by the xDaLa ecosystem; XRC-137 only defines that **the rule string may be XGR1** and that `encrypted` provides the metadata required to interpret it.

---

## 3. Access Control

Only the `owner` may update rule and metadata.

Ownership transfer is performed via `transferOwnership(newOwner)`.

---

## 4. ABI (Authoritative Interface)

### 4.1 Solidity interface (canonical)

```solidity
pragma solidity ^0.8.0;

interface IXRC137 {
    // Events
    event RuleUpdated(string ruleJsonOrXGR1, bytes32 rid, string suite);
    event NameXRCUpdated(string nameXRC);
    event EncryptedUpdated(bytes32 rid, string suite);

    // Read API
    function getRule() external view returns (string memory);
    function getNameXRC() external view returns (string memory);

    // Returns EncInfo as a tuple
    function getEncrypted() external view returns (bytes32 rid, string memory suite);
    function isEncrypted() external view returns (bool);

    // Write API (onlyOwner)
    function setRule(string calldata jsonOrXgr1, bytes32 rid, string calldata suite) external;
    function transferOwnership(address newOwner) external;
}
```

Notes:
- `getRule()` must return the exact stored rule string (plain JSON or XGR1).
- `setRule()` updates the rule and the encryption metadata in a single atomic call.

### 4.2 JSON ABI fragment (tooling-friendly)

This is a minimal ABI fragment suitable for ethers/web3:

```json
[
  {
    "type": "event",
    "name": "RuleUpdated",
    "inputs": [
      { "indexed": false, "name": "ruleJsonOrXGR1", "type": "string" },
      { "indexed": false, "name": "rid",           "type": "bytes32" },
      { "indexed": false, "name": "suite",         "type": "string" }
    ]
  },
  {
    "type": "event",
    "name": "NameXRCUpdated",
    "inputs": [
      { "indexed": false, "name": "nameXRC", "type": "string" }
    ]
  },
  {
    "type": "event",
    "name": "EncryptedUpdated",
    "inputs": [
      { "indexed": false, "name": "rid",   "type": "bytes32" },
      { "indexed": false, "name": "suite", "type": "string" }
    ]
  },
  {
    "type": "function",
    "name": "getRule",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [ { "name": "", "type": "string" } ]
  },
  {
    "type": "function",
    "name": "getNameXRC",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [ { "name": "", "type": "string" } ]
  },
  {
    "type": "function",
    "name": "getEncrypted",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [
      { "name": "rid",   "type": "bytes32" },
      { "name": "suite", "type": "string" }
    ]
  },
  {
    "type": "function",
    "name": "isEncrypted",
    "stateMutability": "view",
    "inputs": [],
    "outputs": [ { "name": "", "type": "bool" } ]
  },
  {
    "type": "function",
    "name": "setRule",
    "stateMutability": "nonpayable",
    "inputs": [
      { "name": "jsonOrXgr1", "type": "string" },
      { "name": "rid",        "type": "bytes32" },
      { "name": "suite",      "type": "string" }
    ],
    "outputs": []
  },
  {
    "type": "function",
    "name": "transferOwnership",
    "stateMutability": "nonpayable",
    "inputs": [ { "name": "newOwner", "type": "address" } ],
    "outputs": []
  }
]
```

---

## 5. Integration Notes for xDaLa

A typical xDaLa consumer flow:

1. Resolve the XRC-137 contract address for the step.
2. Call `getRule()` to obtain:
   - plain JSON → parse as XRC-137 rule document
   - XGR1 envelope → decrypt using the available key material (as governed by your deployment) and parse the decrypted JSON
3. Evaluate and execute according to the XRC-137 rule document specification.

---

## 6. Conformance

A contract is XRC-137 conformant if it:

- Implements the read API exactly as specified
- Emits the specified events on updates
- Enforces owner-only updates for write functions
- Preserves the `encrypted` semantics (zero/empty indicates “not encrypted”)

