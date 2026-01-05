# XRC-729 Smart Contract Standard (Orchestration Registry)

## Purpose

XRC-729 defines an **on-chain, auditable orchestration registry** for xDaLa processes.

- An **orchestration** is a directed process graph (steps, spawns, joins) that determines *which* XRC-137 rules are executed *when*, and how their outcomes branch.
- The orchestration is stored **exclusively on-chain** in an XRC-729 contract and retrieved by xDaLa at runtime.
- Because the orchestration is on-chain and addressable by ID (and optionally pinned by hash), any third party can reproduce and audit the process topology and branching logic.

This document specifies the required external interface and semantics for XRC-729 contracts. It intentionally avoids implementation and operations details.

---

## Key terms

- **OSTC**: *Orchestration Specification Text (Canonical)* — the canonical orchestration document stored as a UTF-8 JSON string.
- **Orchestration ID (`ostcId`)**: A human-readable identifier (string) used to reference a specific orchestration in the registry.
- **Registry contract (`xrc729`)**: The deployed XRC-729 contract instance that stores and serves OSTCs.
- **Registry name (`nameXRC`)**: A string name for the registry contract instance (e.g., `"XRC-729"`), used for introspection and tooling.
- **xDaLa**: The execution engine that loads OSTCs from XRC-729 and runs sessions accordingly.

---

## On-chain interface (ABI)

### Read interface (required)

A conforming XRC-729 registry MUST expose the following read functions:

1. **Registry name**

```solidity
function getNameXRC() external view returns (string memory);
function nameXRC() external view returns (string memory); // alias permitted
```

Semantics:
- Returns the registry identifier string for tooling and introspection.
- Implementations MAY expose both `getNameXRC()` and `nameXRC()`; tools should accept either.

2. **Existence check**

```solidity
function hasOSTC(string calldata id) external view returns (bool);
```

Semantics:
- Returns `true` if an OSTC with that `id` exists in the registry.

3. **Retrieve OSTC JSON**

```solidity
function getOSTC(string calldata id) external view returns (string memory json);
```

Semantics:
- Returns the canonical OSTC JSON string for `id`.
- If `id` does not exist, the call MUST revert **or** return an empty string. (Implementations should prefer revert; clients should treat empty as “not found”.)
- The returned string MUST be valid UTF-8 and MUST represent a JSON document in the format defined in the orchestration specification (see “Orchestration document format”).

4. **Ownership (recommended)**

```solidity
function owner() external view returns (address);
```

Semantics:
- Returns the registry owner/administrator.
- This is recommended for governance and change control. If not present, registry governance must be documented elsewhere.

### Write interface (recommended)

For practical use, a registry needs a way to create/update/delete OSTCs. The reference design is:

```solidity
function setOSTC(string calldata id, string calldata json) external;    // create or update
function deleteOSTC(string calldata id) external;                       // delete
```

Semantics:
- Only authorized writers (typically `owner`) may change entries.
- `setOSTC` stores the JSON text for the given `id`.
- `deleteOSTC` removes the entry, after which `hasOSTC(id)` becomes false.

Note: the exact write function names are not required by the read-only runtime, but they are strongly recommended for interoperability of authoring tools.

### Events (recommended)

Registries SHOULD emit events for audit trails:

```solidity
event OSTCSet(string indexed id, bytes32 indexed hash, address indexed by);
event OSTCDeleted(string indexed id, address indexed by);
```

Semantics:
- `hash` SHOULD be the Keccak-256 hash of the stored JSON bytes (UTF-8).
- Events provide a compact history of changes and enable efficient indexing by explorers.

---

## Orchestration document format (OSTC JSON)

XRC-729 stores orchestration documents as JSON strings. The exact JSON schema is defined in:

- **“XRC-729 Orchestration Document & Session Semantics”** (companion specification)

At a high level, an OSTC contains:

- a unique orchestration `id`
- a `structure` object: a map from `nodeId` to node definition
- each node references an **XRC-137 rule contract address** (`rule`) and defines **branch behavior**:
  - `onValid`: spawns, joins
  - `onInvalid`: spawns, joins

---

## Version pinning and auditability

### Why pinning matters

If the registry entry for `ostcId` changes over time, then the same `ostcId` might refer to different process graphs at different points in time. For auditability, a session SHOULD be able to prove which exact OSTC text it used.

### Recommended mechanism

- A session references `(xrc729Address, ostcId)` and MAY additionally carry an **expected hash** of the OSTC JSON.
- xDaLa loads the OSTC from `xrc729Address.getOSTC(ostcId)` and, if an expected hash is provided, verifies it matches.
- If the hash does not match, the session MUST fail deterministically (abort before executing any steps).

This achieves:
- **Determinism**: the orchestration topology is fixed for the session.
- **Auditability**: third parties can independently retrieve the OSTC and verify the hash.

---

## Security considerations

- **Access control**: Write functions should be owner- or role-restricted to prevent unauthorized process definition changes.
- **Large JSON strings**: Storing very large orchestration documents increases gas cost for updates. Prefer compact and modular orchestrations.
- **Immutable registries**: For maximal auditability, organizations may choose to deploy immutable registries (no updates) and use new `ostcId`s for changes.

---

## Compliance checklist

A contract is XRC-729 compliant if it:

- [ ] exposes `getOSTC(string) -> string`
- [ ] exposes `hasOSTC(string) -> bool`
- [ ] exposes a registry name function (`getNameXRC` and/or `nameXRC`)
- [ ] stores OSTCs as canonical UTF-8 JSON strings matching the orchestration spec

Recommended for ecosystem tooling:

- [ ] emits events on create/update/delete
- [ ] exposes `owner()` and enforces write access control
- [ ] provides `setOSTC` / `deleteOSTC` or equivalent write methods
