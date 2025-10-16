# XRC‑137 Developer Guide (Unified)

**Audience:** engineers integrating with **XDaLa** / **XGRChain**.  
**Goal:** a single, cohesive specification that defines the **on‑chain contract (XRC‑137)** and the **off‑chain JSON rule format**, plus the exact way engines consume both.

---

## 1. Overview

**XRC‑137** is the _Rules‑as‑Contract (RaC)_ standard for XGR/XDaLa. A rule is **published on‑chain** as a string and **executed by the engine** against an input payload to produce a deterministic outcome (transformed payload, optional execution spec, and logs).

- **Contract (publisher & policy)**: stores the canonical rule as **plaintext JSON** or as an **encrypted envelope** and exposes a small read surface for engines.
- **Engine (consumer & executor)**: loads the rule from the contract, decrypts if needed, merges data from `contractReads`/`apiCalls`, evaluates `rules`, selects an outcome, and persists logs (optionally encrypted).

This separation keeps JSON engine‑agnostic and contracts minimal yet auditable.

---

## 2. Contract: storage & data structures

A minimal, interoperable storage layout looks like this (reference pattern):

```solidity
pragma solidity ^0.8.21;

contract XRC137Storage {
    /// @dev Canonical rule string: either plaintext JSON or an XGR1 envelope ("XGR1.<suite>.<rid>.<blob>").
    string public ruleJson;

    /// @dev Encryption metadata. Non‑zero rid indicates the stored rule is encrypted.
    struct EncInfo { bytes32 rid; string suite; }
    EncInfo public encrypted;

    /// @dev Minimal ownership for admin updates (implementations may differ).
    address public owner;
}
```

**Auto‑generated getters.**
- `ruleJson()` → returns the rule string.
- `encrypted()` → returns `(bytes32 rid, string suite)`.
- `owner()` → returns the owner address.

**Invariants.**
- If `encrypted.rid == 0x0`, `ruleJson` MUST be plaintext JSON.
- If `encrypted.rid != 0x0`, `ruleJson` MUST start with `XGR1.` and represent an encrypted envelope matching `encrypted.suite`.

---

## 3. Contract: public interface

### 3.1 View getters (required read surface)

Engines probe getters in this order (first hit wins):

```solidity
function getRule() external view returns (string memory);
function rule() external view returns (string memory);
function getRuleJSON() external view returns (string memory);
function ruleJSON() external view returns (string memory);
function encrypted() external view returns (bytes32 rid, string memory suite);
```

**Notes.**
- At least one of the string getters SHOULD be implemented. Many contracts simply expose `string public ruleJson;` (giving `ruleJson()` automatically) and additionally implement one alias like `getRule()` that returns `ruleJson`.
- Engines treat any returned string that starts with `XGR1.` as **encrypted content** and will attempt decryption (see §5).

### 3.2 Mutating functions (reference shape)

Implementations are free to choose names, but a practical, single‑call “upsert” is:

```solidity
/// @notice Upsert plaintext JSON (rid=0) or an encrypted XGR1 blob (rid!=0).
function setRule(string calldata jsonOrXgr1, bytes32 rid, string calldata suite) external;
```

**Required behavior.**
- If `rid == 0x0` → store `ruleJson=jsonOrXgr1`, **clear** `encrypted`.
- If `rid != 0x0` → `jsonOrXgr1` MUST start with `XGR1.` → store `ruleJson=jsonOrXgr1` and set `encrypted={rid, suite}`.
- Access control: `onlyOwner` (or equivalent).

Some implementations may expose separate functions, e.g. `setPlaintext(string)`, `setEncrypted(string,bytes32,string)`, and `clearEncryption()`; engines do not depend on these names.

### 3.3 Events (indexer/UI friendly)

```solidity
event RuleUpdated(string newRule);
event EncryptedSet(bytes32 rid, string suite);
event EncryptedCleared();
```

---

## 4. Engine integration (how contracts are consumed)

1. **Load**: call getters in order: `getRule()` → `rule()` → `getRuleJSON()` → `ruleJSON()`.  
2. **Decrypt** (if needed): if the string starts with `XGR1.`, decrypt via session owner’s permit (DEK); parse JSON result.  
3. **Default address**: if the JSON has no `address`, the engine injects the contract address.  
4. **Merge inputs**: execute `contractReads` and `apiCalls`, merge into the inbound payload.  
5. **Evaluate rules**: all expressions must be `true` (missing keys → expression `false`, no hard exception).  
6. **Pick outcome**: `onValid` if all rules pass else `onInvalid`.  
7. **Map payload**: copy (`"[Key]"`), template (no operators), or full expression (CEL).  
8. **Execution spec**: if `execution.to` is empty or missing → **meta‑only** step (no inner call).  
9. **Persist logs**: store `PayloadAll`, `APISaves`, `ContractSaves`; apply encryption policy (§7).
10. **Estimate gas**: compute total + split heuristic for budgeting (§8).

---

## 5. JSON rule format (developer reference)

### 5.1 Concepts

- `payload`: input field declarations (`type`, `optional`, hints).  
- `contractReads` / `apiCalls`: augmented inputs prior to rule evaluation.  
- `rules`: boolean expressions; all must be `true`.  
- `onValid` / `onInvalid`: outcome branches with `payload` mapping and optional `execution`, plus logging hints.

**Requiredness.** `optional:false` enforces existence **and non‑emptiness**; missing required keys mark the step **invalid** and set `missingRequired` meta.  
**Evaluation order.** Reads → APIs → rules → outcome build.  
**Mapping.** `"[Key]"` → copy; template without operators → substitution; otherwise **CEL evaluation**.

### 5.2 Full JSON specification (verbatim; integrated)

Below is the full JSON reference you ship today — preserved **without loss** and placed here so developers read it in context:

---

# XRC-137 — Technical Specification

> **Scope:** This document defines the XRC-137 JSON rule format and its runtime semantics for a **single validation step** with optional execution. **Expression language details are out of scope** and are covered in the companion document **“XRC-137 Expression Evaluation — Developer Guide.”**

---

## 1) Purpose & Design Goals

* Deterministic, fetch-only rule execution for a single step.
* Uniform authoring across payload, HTTP extracts, branching, and execution metadata.
* JSON-first, engine-agnostic; contracts return rules via `getRule()`/`rule()` and variants.

**Processing pipeline**: `Validate payload → Execute contractReads (on-chain) → Execute apiCalls (fetch) → Evaluate rules → Pick Outcome (onValid/onInvalid) → Optional execution → Receipt persistence`

---

## 2) Top-Level JSON Schema

```json
{
  "payload": { "<Key>": {"type":"string|number|bool|array|object", "optional": false } },
  "contractReads": [ ContractRead, ... ],
  "apiCalls": [ APICall, ... ],
  "rules": [ "<CEL>", ... ],
  "onValid":  Outcome,
  "onInvalid": Outcome,
  "address": "0x..."
}
```

**Notes**

* `payload` declares plain inputs and their requiredness.
* `contractReads` run **before** `apiCalls`; their results merge into inputs and are available to `apiCalls` templates and `rules` (see §4).
* `apiCalls` fetch JSON and write extracted aliases into the inputs map.
* `rules` are boolean expressions; **see companion Expression document** for language and functions.
* Outcomes define optional waits, **output payload mapping (flat)**, an optional execution, **and optional log-policy overrides** (see §7.2).

### 2.1 Top-level fields — parameter reference

| Field           | Type             | Required         | Description                                                                                                                  |
| --------------- | ---------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `payload`       | object           | yes              | Declares input keys available to expressions. Each entry defines `type` (doc hint) and `optional` (requiredness).            |
| `contractReads` | array            | no               | Declarative on-chain reads. ABI-aware (`to`/`function`/`args`) with optional `saveAs` + `defaults` for single/multi returns. |
| `apiCalls`      | array of APICall | no               | HTTP JSON fetches whose extracted aliases are merged into inputs. Executed **after** `contractReads`.                        |
| `rules`         | array of string  | no (recommended) | Boolean expressions; if omitted, validation succeeds when required inputs are present.                                       |
| `onValid`       | Outcome          | no               | Outcome executed when **all** rules evaluate to `true`. Supports **log policy overrides**.                                   |
| `onInvalid`     | Outcome          | no               | Outcome executed when **any** rule is `false` or a required key is missing. Supports **log policy overrides**.               |
| `address`       | string (0x…)     | no               | Authoring aid; target EVM address for UI/display. Engines may ignore at runtime and use `execution.to` instead.              |

---

## 3) Payload (Inputs)

* `type` is descriptive (documentation aid), not strictly enforced at parse time.
* `optional:false` means the key **must exist and be non-empty** before rule evaluation. Empty string/array/map are treated as missing.
* Duplicate input keys from different sources are rejected during merge.

### 3.1 Payload fields — parameter reference

| Property         | Type    | Required | Notes                                                                                     |
| ---------------- | ------- | -------- | ----------------------------------------------------------------------------------------- |
| `<Key>`          | object  | yes      | Declares one input. The map key is the input name (used as `[Key]` in templates).         |
| `<Key>.type`     | string  | no       | Doc hint: `string \| number \| bool \| array \| object`. Engines may use for UI only.     |
| `<Key>.optional` | boolean | yes      | When `false`, missing/empty values send the flow to `onInvalid` without evaluating rules. |

**Requiredness check (summary)**

* Missing or empty required keys → immediate invalid path (rules are not evaluated), unless a `ContinueInvalid` is provided by the orchestrator layer.

---

## 4) Contract Reads

Declarative, ABI-aware reads whose results become inputs and can be persisted. Executed **before** `apiCalls` so their keys are available to API templates and rules.

```json
ContractRead = {
  "to": "0x...",
  "function": "balanceOf(address) returns (uint256)",
  "args": ["<ExprOrLiteral>", ...],
  "saveAs": "Alias" | { "0": "Key0", "1": "Key1", "...": "..." },
  "defaults": <scalar> | { "0": <fallback0>, "1": <fallback1>, "Key0": <fallbackForKey0>, ... }
}
```

### 4.1 Semantics

* `to`: **direct EVM address (0x…)**.
* `function`: Solidity signature; determines ABI for args and return tuple.
* `args[i]`: evaluated first, then cast to ABI type.
* Return value is treated as a Solidity **tuple** (even for single return).

  * `saveAs: "Alias"` → persist index **0** under `"Alias"`.
  * `saveAs: { "0": "A", "1": "B", ... }` → persist **multiple indices** under provided keys.
* If `saveAs` is omitted, the engine may still execute the read for evaluation, but **no keys are added/persisted**.

### 4.2 SaveAs for multi-return — details

* Object keys are **stringified non-negative integers** (`"0"`, `"1"`, …).
* Values are non-empty strings naming the keys to write into the inputs map.
* Indices must be within the function’s return arity; otherwise error.

### 4.3 Defaults & errors

* `defaults` provides fallbacks when the read fails (RPC error/revert) **or** when a referenced return index is missing.

  * **Scalar form**: allowed only if `saveAs` is a single string (index `0`). Used as fallback for index `0`.
  * **Object form**: keys may be **tuple indices** ("0", "1", …) **or** the **names** used in `saveAs`. Values are the fallback literals.
  * All indices referenced by `saveAs` **must** be covered by `defaults` to proceed after a read failure; otherwise the engine aborts the step.
  * If the read succeeds but a specific index is out of range, the engine uses the corresponding default (if present) or fails.
* `to` must be a valid 0x address.
* `saveAs` string maps to index `0`; object form must use non-negative integer keys and non-empty string values.
* Arg evaluation/casting errors propagate as rule errors.

### 4.4 Example (reads only)

```json
{
  "contractReads": [
    {
      "to": "0x0000000000000000000000000000000000000001",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA",
      "defaults": 0
    },
    {
      "to": "0x0000000000000000000000000000000000000002",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" },
      "defaults": { "0": 0, "1": 0, "2": 0 }
    }
  ]
}
```

---

## 5) HTTP API Calls (fetch-only, JSON)

```json
APICall = {
  "name": "<id>",
  "method": "GET|POST|PUT|PATCH",
  "urlTemplate": "https://.../path?x=[key]",
  "headers": {"K": "V"},
  "bodyTemplate": "...",
  "contentType": "json",
  "extractMap": {"alias": "<CEL on resp>", ...},
  "defaults": {"alias": <fallback>}
}
```

**Determinism & limits**

* Timeout per call **8 s**; **≤3 redirects**; **response ≤1 MB**; **TLS ≥1.2**; HTTP/1.1 enforced; IPv4 dial only; no proxy from env.
* `contentType` must be `json`; array-root allowed.
* Each `extractMap` entry is a short **CEL** expression over variable `resp`.
* Extract results are **persisted automatically** if they are **scalar** (`string|number|bool|int`); reduce lists/objects in the expression when needed.
* On evaluation failure, engine uses `defaults[alias]` if present; otherwise the call fails.

**Alias rules**

* Regex: `^[A-Za-z][A-Za-z0-9._-]{0,63}$`; must not start with `_` or `sys.`; must be unique across all apiCalls in the rule.

### 5.1 Placeholders in `urlTemplate` / `bodyTemplate`

* Syntax: `[key]` references `inputs[key]`.
* URL templates URL-encode placeholder values; body templates use raw serialization.
* Escapes: `[[` → `[` and `]]` → `]`.
* Missing placeholder key ⇒ error.
* Complex/non-string values are JSON-serialized for body usage.

### 5.2 APICall fields — parameter reference

| Field          | Type   | Required | Constraints / Notes                                                                          |
| -------------- | ------ | -------- | -------------------------------------------------------------------------------------------- |
| `name`         | string | yes      | Identifier for logs and alias scoping. Unique per rule. 1–64 chars, regex above.             |
| `method`       | string | yes      | One of `GET`, `POST`, `PUT`, `PATCH`. Use `GET` for idempotent reads.                        |
| `urlTemplate`  | string | yes      | Absolute HTTPS URL recommended. May contain placeholders `[key]`. URL-escaped automatically. |
| `headers`      | object | no       | String→string map. Avoid auth headers that change per run; prefer static headers.            |
| `bodyTemplate` | string | no       | For non-GET methods. May include placeholders. Serialized as given (no URL-encoding).        |
| `contentType`  | string | yes      | Must be `json`. Response body is parsed as JSON (object or array root).                      |
| `extractMap`   | object | yes      | Map of `alias` → expression over `resp`. Result must be scalar to be persisted.              |
| `defaults`     | object | no       | Fallback values per alias when the corresponding extract expression errors.                  |

### 5.3 Example extracts

```json
{
  "extractMap": {
    "q.symbol": "resp.quote.symbol",
    "q.best_px": "max(resp.quote.venues.map(v, double(v.price.value)))"
  },
  "defaults": {"q.best_px": 0}
}
```

---

## 6) Rules (Boolean)

* `rules` is an array of boolean expressions. All must evaluate to `true`.
* Missing referenced keys make the individual expression evaluate to `false` (no exception).
* **Expression details (operators, helpers, timeouts, length limits) are documented in “XRC-137 Expression Evaluation — Developer Guide.”**

### 6.1 Rule behavior — parameter reference

| Aspect             | Specification                                                                                                           |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Evaluation order   | Rules are evaluated in listed order; the outcome requires all to be `true`. Engines may short-circuit on first `false`. |
| Missing input keys | Any reference to a missing key yields `false` for that rule.                                                            |
| Return type        | Each rule must return a boolean; non-boolean results are an error.                                                      |
| Length limit       | See Expression guide (authoring limit and timeout).                                                                     |

---

## 7) Outcomes (`onValid` / `onInvalid`)

```json
Outcome = {
  "waitMs": 0,
  "waitUntilMs": 0,
  "payload": { "<outKey>": "<TemplateOrExpr>" },
  "execution": Execution,
  "encryptLogs": true,
  "logExpireDays": 365
}
```

**Waiting**

* `waitUntilMs` (epoch ms) takes precedence; else `waitMs` (relative).
* Non-negative integers only. `0` means “no wait”.

**Output payload mapping**

* Exactly `"[Key]"` → direct copy from inputs.
* Plain strings containing **only** placeholders and text (no operators) → literal placeholder substitution (no expression engine).
* Otherwise → full expression evaluation (same environment as rules). **See companion Expression document** for semantics.

**Meta-only outcomes**

* If `execution` is omitted or has an empty `to`, no inner call is performed; outcome remains metadata-only (receipt still records payload and saves).

### 7.1 Outcome fields — parameter reference

| Field           | Type               | Required | Notes                                                                              |
| --------------- | ------------------ | -------- | ---------------------------------------------------------------------------------- |
| `waitMs`        | integer ≥ 0        | no       | Relative delay before applying the outcome. Ignored if `waitUntilMs` > 0.          |
| `waitUntilMs`   | integer (epoch ms) | no       | Absolute timestamp to apply the outcome. Overrides `waitMs`.                       |
| `payload`       | object             | no       | Output keys to persist. Values can be template strings or expressions.             |
| `execution`     | object             | no       | See §8. When omitted or `to==""`, the outcome is metadata-only.                    |
| `encryptLogs`   | boolean            | no       | **Override** for log encryption in this branch. See §9.2 for defaults & semantics. |
| `logExpireDays` | integer ≥ 1        | no       | **Override** for log grant expiry in days for this branch. Default **365**.        |

### 7.2 Log policy overrides — precedence & defaults

* Overrides are **per branch** (valid vs invalid) and **independent**.
* **Precedence**: If `encryptLogs` is provided in the branch → it **wins**.
  Otherwise the engine uses the **default** derived from the contract’s `encrypted()` status.
  If `encrypted()` is not available or fails, the default is treated as **false**.
* `logExpireDays` (if provided in the branch) must be ≥1. If omitted → **365**.
* Overrides have **no effect** on the rule’s encryption-at-rest; sie betreffen nur die **Log-Persistenz** (siehe §9.2).

---

## 8) Execution

```json
Execution = {
  "to": "0x...",                // optional; empty ⇒ meta-only
  "function": "setMessage(string)",
  "args": ["<ExprOrLiteral>", ...],
  "value": "<ExprOrLiteral>",   // optional; Wei
  "gas": { "limit": 150000 }    // optional
}
```

**Semantics**

* `args[i]` are evaluated then cast to the ABI type of the declared `function` signature.
* `value` is evaluated to a non-negative integer (Wei). If omitted ⇒ 0.
* `gas.limit` (if present) is used as provided.
* When `to` is empty, the engine **must not** send an inner call.

**Error conditions (non-exhaustive)**

* Invalid target address; argument count/type mismatch; casting failures; negative `value`.

### 8.1 Execution fields — parameter reference

| Field       | Type    | Required        | Notes                                                                                     |
| ----------- | ------- | --------------- | ----------------------------------------------------------------------------------------- |
| `to`        | string  | no              | **Direct EVM address**. If empty ⇒ no inner call.                                         |
| `function`  | string  | yes if `to` set | Solidity signature (e.g., `transfer(address,uint256)`). Determines ABI casting of `args`. |
| `args`      | array   | yes if `to` set | Each entry may be a literal or expression. Evaluated at runtime, then ABI-encoded.        |
| `value`     | string  | no              | Expression/literal yielding Wei (uint256). If omitted ⇒ 0.                                |
| `gas.limit` | integer | no              | Base gas limit used if provided.                                                          |

---

## 9) Persistence (Receipt)

* **APISaves**: every `extractMap` alias that evaluates to a **scalar**.
* **ContractSaves**: every key produced via `contractReads.saveAs` (string or map entries).
* **PayloadAll**: final plain payload (non-API, non-contract) after outcome mapping.
* Optional log encryption may be applied by the engine when supported.

### 9.1 Persistence fields — parameter reference

| Bucket          | Source                          | Contains                                       |
| --------------- | ------------------------------- | ---------------------------------------------- |
| `APISaves`      | `apiCalls.extractMap` (scalars) | Scalar extracted values only.                  |
| `ContractSaves` | `contractReads.saveAs`          | Deterministic chain values.                    |
| `PayloadAll`    | Outcome `payload`               | Final authored payload (non-API/non-contract). |

### 9.2 Log encryption & grants (engine behavior)

When a branch dictates encrypted logs (either by override or by default):

* The engine aggregates **`payload` + `APISaves` + `ContractSaves`** to a log bundle and encrypts it (XGR v2):
  **ECDH P-256 + HKDF-SHA256 → AES-GCM**. HKDF `info` binds `version|scope|rid|alg`.
* The engine writes a **log-grant** (scope `2`) for the session **owner** in the `XgrGrants` registry so the owner can decrypt:
  **rights** typically `READ|WRITE` (implementation choice), **expireAt** = `now + logExpireDays * 24h` (default **365**).
* Requirements & failure mode:

  * The **owner** must have a **P-256 Read-Public-Key** registered (uncompressed 65-byte key starting with `0x04`).
    Missing keys or invalid owner addresses lead to a **fail-closed** log path (no plaintext leakage; engine records an error).
  * The engine may reduce metadata in the receipt when encrypting to avoid plaintext exposure.

---

## 10) Limits & Security

* Recommended `apiCalls` per rule ≤ 50.
* HTTP client: IPv4 only, TLS ≥1.2, HTTP/1.1 enforced, no environment proxy.
* Redirects ≤3; response size ≤1 MB.
* Alias collisions across apiCalls are rejected.
* Host allow-listing is engine policy (default open, configurable).

---

## 11) Error Handling (selected)

* **Placeholders**: invalid key syntax, missing keys, unclosed brackets.
* **HTTP**: non-2xx, non-JSON bodies, size/timeout/redirect limits.
* **Extracts**: empty expression, evaluation failure with no `defaults`, non-scalar results.
* **Rules**: syntax error, non-boolean result, timeout, expression length over limit.
* **Execution**: invalid `to`, ABI mismatch, cast errors, negative `value`.
* **Outputs**: missing referenced keys, invalid template substitution, evaluation errors.
* **Contract Reads**: invalid `to`, `saveAs` format, index out of range, arg evaluation/cast failures, missing required `defaults` after read failure.

---

## 12) Engine Integration (Rule Loading)

* Contracts may expose one of: `getRule()`, `rule()`, `getRuleJSON()`, `ruleJSON()` returning the JSON rule.
* Engines should attempt these in order and fall back to the next if empty.
* When a contract returns an `XGR1...` encrypted blob, engines may auto-decrypt via a configured crypto backend using the session owner’s permit.
* After load/decrypt, the engine parses the JSON into a structured `ParsedXRC137` model.

---

## 13) Validation Gas (informative)

* Engines may compute a simple validation-gas estimate (e.g., proportional to the number of rule expressions) for budgeting and logging.

---

## 14) Example (abridged)

```json
{
  "payload": {
    "User":    {"type":"address","optional":false},
    "AmountA": {"type":"number","optional":false},
    "AmountB": {"type":"number","optional":false}
  },
  "contractReads": [
    {
      "to": "0x0000000000000000000000000000000000000001",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA",
      "defaults": 0
    },
    {
      "to": "0x0000000000000000000000000000000000000002",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" },
      "defaults": { "0": 0, "1": 0, "2": 0 }
    }
  ],
  "apiCalls": [
    {
      "name": "test-quote",
      "method": "GET",
      "urlTemplate": "https://api.test.xgr.network/quote/AAPL",
      "contentType": "json",
      "headers": {"Accept": "application/json"},
      "extractMap": {
        "q.symbol": "resp.quote.symbol",
        "q.price":  "double(resp.quote.price.value)",
        "q.bid":    "double(resp.quote.bid.value)",
        "q.ask":    "double(resp.quote.ask.value)"
      },
      "defaults": {"q.price":0, "q.bid":0, "q.ask":0}
    }
  ],
  "rules": [
    "[AmountA] > 0",
    "[AmountB] > 0",
    "[q.price] > 0",
    "[BalanceA] >= [AmountA]"
  ],
  "onValid": {
    "waitMs": 50000,
    "encryptLogs": true,
    "logExpireDays": 30,
    "payload": {
      "AmountA": "[AmountA]-[AmountB]",
      "AmountB": "[AmountB]",
      "fromApi": "[q.symbol]",
      "reserves": "{'r0': [Reserve0], 'r1': [Reserve1], 'ts': [ReservesTs]}"
    },
    "execution": {
      "to": "0x0000000000000000000000000000000000000003",
      "function": "setMessage(string)",
      "args": ["'Balance: ' + string([BalanceA])"],
      "value": "0",
      "gas": { "limit": 150000 }
    }
  },
  "onInvalid": {
    "waitMs": 1000,
    "encryptLogs": false,
    "payload": {"memo":"invalid-path","error":"Amount"}
  },
  "address": "0x7863b2E0Cb04102bc3758C8A70aC88512B46477C"
}
```

---

## 15) Versioning & Compatibility

* This document describes XRC-137 **v0.2**. Future versions may add fields while preserving existing ones. Engines should ignore unknown fields and treat missing new fields as defaults to maintain forward compatibility.

---

### Companion document

For the expression language (operators, helpers, placeholder rewriting, timeouts, limits, scalar persistence rules, etc.), read **“XRC-137 Expression Evaluation — Developer Guide.”**


---

## 6. ABI quick reference (for RPC/eth_call)

| Signature | Returns | Notes |
|---|---|---|
| `getRule()` | `string` | Primary getter (JSON or XGR1 envelope). |
| `rule()` | `string` | Alias. |
| `getRuleJSON()` | `string` | Alias. |
| `ruleJSON()` | `string` | Alias. |
| `encrypted()` | `(bytes32 rid, string suite)` | `rid!=0x0` ⇒ encrypted by default. |
| `ruleJson()` | `string` | Auto‑getter if `string public ruleJson;` is present. |
| `owner()` | `address` | Auto‑getter if `address public owner;` is present. |

> Engines compute `keccak256(<signature>)` and send the first 4 bytes as the function selector when using `eth_call`.

---

## 7. Log persistence & encryption policy

- **Default**: if `encrypted().rid != 0x0`, the engine treats the rule as **sensitive** and encrypts the log bundle by default.  
- **Branch overrides**: `onValid.encryptLogs` / `onInvalid.encryptLogs` and `logExpireDays` override defaults per branch.  
- **Fail‑closed**: if no owner/read key is available, clear‑text logs are not emitted; the step is flagged as an error path.

Encryption suite (engine‑side): ECDH P‑256 + HKDF‑SHA256 → AES‑GCM (_XGR v2_).

---

## 8. ValidationGas (structure‑driven heuristic)

The engine calculates an **additive** estimate across pipeline stages and also a **split** for _common_, _onValid_, _onInvalid_ to help precompiles budget accurately. The heuristic counts operators/functions/placeholders/regex hints and is **unclamped** (complex rules may exceed 300k).

---

## 9. End‑to‑end minimal example

**Rule JSON**

```json
{
  "payload": {
    "AmountA": { "type": "number", "optional": false }
  },
  "rules": [ "[AmountA] > 0" ],
  "onValid": {
    "payload": {
      "memo": "valid-path",
      "AmountA": "[AmountA] - 10"
    }
  },
  "onInvalid": {}
}
```

**Contract storage**  
- `ruleJson`: the JSON above (plaintext)  
- `encrypted.rid`: `0x00…00` (plaintext) → default log policy: not encrypted

**Engine result (valid input)**  
- Output payload: `{ "memo": "valid-path", "AmountA": <input-10> }`  
- Execution: none (meta‑only)  
- Logs: default policy unless branch overrides set

---

## Appendix — JSON reference (verbatim, unchanged)

# XRC-137 — Technical Specification

> **Scope:** This document defines the XRC-137 JSON rule format and its runtime semantics for a **single validation step** with optional execution. **Expression language details are out of scope** and are covered in the companion document **“XRC-137 Expression Evaluation — Developer Guide.”**

---

## 1) Purpose & Design Goals

* Deterministic, fetch-only rule execution for a single step.
* Uniform authoring across payload, HTTP extracts, branching, and execution metadata.
* JSON-first, engine-agnostic; contracts return rules via `getRule()`/`rule()` and variants.

**Processing pipeline**: `Validate payload → Execute contractReads (on-chain) → Execute apiCalls (fetch) → Evaluate rules → Pick Outcome (onValid/onInvalid) → Optional execution → Receipt persistence`

---

## 2) Top-Level JSON Schema

```json
{
  "payload": { "<Key>": {"type":"string|number|bool|array|object", "optional": false } },
  "contractReads": [ ContractRead, ... ],
  "apiCalls": [ APICall, ... ],
  "rules": [ "<CEL>", ... ],
  "onValid":  Outcome,
  "onInvalid": Outcome,
  "address": "0x..."
}
```

**Notes**

* `payload` declares plain inputs and their requiredness.
* `contractReads` run **before** `apiCalls`; their results merge into inputs and are available to `apiCalls` templates and `rules` (see §4).
* `apiCalls` fetch JSON and write extracted aliases into the inputs map.
* `rules` are boolean expressions; **see companion Expression document** for language and functions.
* Outcomes define optional waits, **output payload mapping (flat)**, an optional execution, **and optional log-policy overrides** (see §7.2).

### 2.1 Top-level fields — parameter reference

| Field           | Type             | Required         | Description                                                                                                                  |
| --------------- | ---------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `payload`       | object           | yes              | Declares input keys available to expressions. Each entry defines `type` (doc hint) and `optional` (requiredness).            |
| `contractReads` | array            | no               | Declarative on-chain reads. ABI-aware (`to`/`function`/`args`) with optional `saveAs` + `defaults` for single/multi returns. |
| `apiCalls`      | array of APICall | no               | HTTP JSON fetches whose extracted aliases are merged into inputs. Executed **after** `contractReads`.                        |
| `rules`         | array of string  | no (recommended) | Boolean expressions; if omitted, validation succeeds when required inputs are present.                                       |
| `onValid`       | Outcome          | no               | Outcome executed when **all** rules evaluate to `true`. Supports **log policy overrides**.                                   |
| `onInvalid`     | Outcome          | no               | Outcome executed when **any** rule is `false` or a required key is missing. Supports **log policy overrides**.               |
| `address`       | string (0x…)     | no               | Authoring aid; target EVM address for UI/display. Engines may ignore at runtime and use `execution.to` instead.              |

---

## 3) Payload (Inputs)

* `type` is descriptive (documentation aid), not strictly enforced at parse time.
* `optional:false` means the key **must exist and be non-empty** before rule evaluation. Empty string/array/map are treated as missing.
* Duplicate input keys from different sources are rejected during merge.

### 3.1 Payload fields — parameter reference

| Property         | Type    | Required | Notes                                                                                     |
| ---------------- | ------- | -------- | ----------------------------------------------------------------------------------------- |
| `<Key>`          | object  | yes      | Declares one input. The map key is the input name (used as `[Key]` in templates).         |
| `<Key>.type`     | string  | no       | Doc hint: `string \| number \| bool \| array \| object`. Engines may use for UI only.     |
| `<Key>.optional` | boolean | yes      | When `false`, missing/empty values send the flow to `onInvalid` without evaluating rules. |

**Requiredness check (summary)**

* Missing or empty required keys → immediate invalid path (rules are not evaluated), unless a `ContinueInvalid` is provided by the orchestrator layer.

---

## 4) Contract Reads

Declarative, ABI-aware reads whose results become inputs and can be persisted. Executed **before** `apiCalls` so their keys are available to API templates and rules.

```json
ContractRead = {
  "to": "0x...",
  "function": "balanceOf(address) returns (uint256)",
  "args": ["<ExprOrLiteral>", ...],
  "saveAs": "Alias" | { "0": "Key0", "1": "Key1", "...": "..." },
  "defaults": <scalar> | { "0": <fallback0>, "1": <fallback1>, "Key0": <fallbackForKey0>, ... }
}
```

### 4.1 Semantics

* `to`: **direct EVM address (0x…)**.
* `function`: Solidity signature; determines ABI for args and return tuple.
* `args[i]`: evaluated first, then cast to ABI type.
* Return value is treated as a Solidity **tuple** (even for single return).

  * `saveAs: "Alias"` → persist index **0** under `"Alias"`.
  * `saveAs: { "0": "A", "1": "B", ... }` → persist **multiple indices** under provided keys.
* If `saveAs` is omitted, the engine may still execute the read for evaluation, but **no keys are added/persisted**.

### 4.2 SaveAs for multi-return — details

* Object keys are **stringified non-negative integers** (`"0"`, `"1"`, …).
* Values are non-empty strings naming the keys to write into the inputs map.
* Indices must be within the function’s return arity; otherwise error.

### 4.3 Defaults & errors

* `defaults` provides fallbacks when the read fails (RPC error/revert) **or** when a referenced return index is missing.

  * **Scalar form**: allowed only if `saveAs` is a single string (index `0`). Used as fallback for index `0`.
  * **Object form**: keys may be **tuple indices** ("0", "1", …) **or** the **names** used in `saveAs`. Values are the fallback literals.
  * All indices referenced by `saveAs` **must** be covered by `defaults` to proceed after a read failure; otherwise the engine aborts the step.
  * If the read succeeds but a specific index is out of range, the engine uses the corresponding default (if present) or fails.
* `to` must be a valid 0x address.
* `saveAs` string maps to index `0`; object form must use non-negative integer keys and non-empty string values.
* Arg evaluation/casting errors propagate as rule errors.

### 4.4 Example (reads only)

```json
{
  "contractReads": [
    {
      "to": "0x0000000000000000000000000000000000000001",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA",
      "defaults": 0
    },
    {
      "to": "0x0000000000000000000000000000000000000002",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" },
      "defaults": { "0": 0, "1": 0, "2": 0 }
    }
  ]
}
```

---

## 5) HTTP API Calls (fetch-only, JSON)

```json
APICall = {
  "name": "<id>",
  "method": "GET|POST|PUT|PATCH",
  "urlTemplate": "https://.../path?x=[key]",
  "headers": {"K": "V"},
  "bodyTemplate": "...",
  "contentType": "json",
  "extractMap": {"alias": "<CEL on resp>", ...},
  "defaults": {"alias": <fallback>}
}
```

**Determinism & limits**

* Timeout per call **8 s**; **≤3 redirects**; **response ≤1 MB**; **TLS ≥1.2**; HTTP/1.1 enforced; IPv4 dial only; no proxy from env.
* `contentType` must be `json`; array-root allowed.
* Each `extractMap` entry is a short **CEL** expression over variable `resp`.
* Extract results are **persisted automatically** if they are **scalar** (`string|number|bool|int`); reduce lists/objects in the expression when needed.
* On evaluation failure, engine uses `defaults[alias]` if present; otherwise the call fails.

**Alias rules**

* Regex: `^[A-Za-z][A-Za-z0-9._-]{0,63}$`; must not start with `_` or `sys.`; must be unique across all apiCalls in the rule.

### 5.1 Placeholders in `urlTemplate` / `bodyTemplate`

* Syntax: `[key]` references `inputs[key]`.
* URL templates URL-encode placeholder values; body templates use raw serialization.
* Escapes: `[[` → `[` and `]]` → `]`.
* Missing placeholder key ⇒ error.
* Complex/non-string values are JSON-serialized for body usage.

### 5.2 APICall fields — parameter reference

| Field          | Type   | Required | Constraints / Notes                                                                          |
| -------------- | ------ | -------- | -------------------------------------------------------------------------------------------- |
| `name`         | string | yes      | Identifier for logs and alias scoping. Unique per rule. 1–64 chars, regex above.             |
| `method`       | string | yes      | One of `GET`, `POST`, `PUT`, `PATCH`. Use `GET` for idempotent reads.                        |
| `urlTemplate`  | string | yes      | Absolute HTTPS URL recommended. May contain placeholders `[key]`. URL-escaped automatically. |
| `headers`      | object | no       | String→string map. Avoid auth headers that change per run; prefer static headers.            |
| `bodyTemplate` | string | no       | For non-GET methods. May include placeholders. Serialized as given (no URL-encoding).        |
| `contentType`  | string | yes      | Must be `json`. Response body is parsed as JSON (object or array root).                      |
| `extractMap`   | object | yes      | Map of `alias` → expression over `resp`. Result must be scalar to be persisted.              |
| `defaults`     | object | no       | Fallback values per alias when the corresponding extract expression errors.                  |

### 5.3 Example extracts

```json
{
  "extractMap": {
    "q.symbol": "resp.quote.symbol",
    "q.best_px": "max(resp.quote.venues.map(v, double(v.price.value)))"
  },
  "defaults": {"q.best_px": 0}
}
```

---

## 6) Rules (Boolean)

* `rules` is an array of boolean expressions. All must evaluate to `true`.
* Missing referenced keys make the individual expression evaluate to `false` (no exception).
* **Expression details (operators, helpers, timeouts, length limits) are documented in “XRC-137 Expression Evaluation — Developer Guide.”**

### 6.1 Rule behavior — parameter reference

| Aspect             | Specification                                                                                                           |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Evaluation order   | Rules are evaluated in listed order; the outcome requires all to be `true`. Engines may short-circuit on first `false`. |
| Missing input keys | Any reference to a missing key yields `false` for that rule.                                                            |
| Return type        | Each rule must return a boolean; non-boolean results are an error.                                                      |
| Length limit       | See Expression guide (authoring limit and timeout).                                                                     |

---

## 7) Outcomes (`onValid` / `onInvalid`)

```json
Outcome = {
  "waitMs": 0,
  "waitUntilMs": 0,
  "payload": { "<outKey>": "<TemplateOrExpr>" },
  "execution": Execution,
  "encryptLogs": true,
  "logExpireDays": 365
}
```

**Waiting**

* `waitUntilMs` (epoch ms) takes precedence; else `waitMs` (relative).
* Non-negative integers only. `0` means “no wait”.

**Output payload mapping**

* Exactly `"[Key]"` → direct copy from inputs.
* Plain strings containing **only** placeholders and text (no operators) → literal placeholder substitution (no expression engine).
* Otherwise → full expression evaluation (same environment as rules). **See companion Expression document** for semantics.

**Meta-only outcomes**

* If `execution` is omitted or has an empty `to`, no inner call is performed; outcome remains metadata-only (receipt still records payload and saves).

### 7.1 Outcome fields — parameter reference

| Field           | Type               | Required | Notes                                                                              |
| --------------- | ------------------ | -------- | ---------------------------------------------------------------------------------- |
| `waitMs`        | integer ≥ 0        | no       | Relative delay before applying the outcome. Ignored if `waitUntilMs` > 0.          |
| `waitUntilMs`   | integer (epoch ms) | no       | Absolute timestamp to apply the outcome. Overrides `waitMs`.                       |
| `payload`       | object             | no       | Output keys to persist. Values can be template strings or expressions.             |
| `execution`     | object             | no       | See §8. When omitted or `to==""`, the outcome is metadata-only.                    |
| `encryptLogs`   | boolean            | no       | **Override** for log encryption in this branch. See §9.2 for defaults & semantics. |
| `logExpireDays` | integer ≥ 1        | no       | **Override** for log grant expiry in days for this branch. Default **365**.        |

### 7.2 Log policy overrides — precedence & defaults

* Overrides are **per branch** (valid vs invalid) and **independent**.
* **Precedence**: If `encryptLogs` is provided in the branch → it **wins**.
  Otherwise the engine uses the **default** derived from the contract’s `encrypted()` status.
  If `encrypted()` is not available or fails, the default is treated as **false**.
* `logExpireDays` (if provided in the branch) must be ≥1. If omitted → **365**.
* Overrides have **no effect** on the rule’s encryption-at-rest; sie betreffen nur die **Log-Persistenz** (siehe §9.2).

---

## 8) Execution

```json
Execution = {
  "to": "0x...",                // optional; empty ⇒ meta-only
  "function": "setMessage(string)",
  "args": ["<ExprOrLiteral>", ...],
  "value": "<ExprOrLiteral>",   // optional; Wei
  "gas": { "limit": 150000 }    // optional
}
```

**Semantics**

* `args[i]` are evaluated then cast to the ABI type of the declared `function` signature.
* `value` is evaluated to a non-negative integer (Wei). If omitted ⇒ 0.
* `gas.limit` (if present) is used as provided.
* When `to` is empty, the engine **must not** send an inner call.

**Error conditions (non-exhaustive)**

* Invalid target address; argument count/type mismatch; casting failures; negative `value`.

### 8.1 Execution fields — parameter reference

| Field       | Type    | Required        | Notes                                                                                     |
| ----------- | ------- | --------------- | ----------------------------------------------------------------------------------------- |
| `to`        | string  | no              | **Direct EVM address**. If empty ⇒ no inner call.                                         |
| `function`  | string  | yes if `to` set | Solidity signature (e.g., `transfer(address,uint256)`). Determines ABI casting of `args`. |
| `args`      | array   | yes if `to` set | Each entry may be a literal or expression. Evaluated at runtime, then ABI-encoded.        |
| `value`     | string  | no              | Expression/literal yielding Wei (uint256). If omitted ⇒ 0.                                |
| `gas.limit` | integer | no              | Base gas limit used if provided.                                                          |

---

## 9) Persistence (Receipt)

* **APISaves**: every `extractMap` alias that evaluates to a **scalar**.
* **ContractSaves**: every key produced via `contractReads.saveAs` (string or map entries).
* **PayloadAll**: final plain payload (non-API, non-contract) after outcome mapping.
* Optional log encryption may be applied by the engine when supported.

### 9.1 Persistence fields — parameter reference

| Bucket          | Source                          | Contains                                       |
| --------------- | ------------------------------- | ---------------------------------------------- |
| `APISaves`      | `apiCalls.extractMap` (scalars) | Scalar extracted values only.                  |
| `ContractSaves` | `contractReads.saveAs`          | Deterministic chain values.                    |
| `PayloadAll`    | Outcome `payload`               | Final authored payload (non-API/non-contract). |

### 9.2 Log encryption & grants (engine behavior)

When a branch dictates encrypted logs (either by override or by default):

* The engine aggregates **`payload` + `APISaves` + `ContractSaves`** to a log bundle and encrypts it (XGR v2):
  **ECDH P-256 + HKDF-SHA256 → AES-GCM**. HKDF `info` binds `version|scope|rid|alg`.
* The engine writes a **log-grant** (scope `2`) for the session **owner** in the `XgrGrants` registry so the owner can decrypt:
  **rights** typically `READ|WRITE` (implementation choice), **expireAt** = `now + logExpireDays * 24h` (default **365**).
* Requirements & failure mode:

  * The **owner** must have a **P-256 Read-Public-Key** registered (uncompressed 65-byte key starting with `0x04`).
    Missing keys or invalid owner addresses lead to a **fail-closed** log path (no plaintext leakage; engine records an error).
  * The engine may reduce metadata in the receipt when encrypting to avoid plaintext exposure.

---

## 10) Limits & Security

* Recommended `apiCalls` per rule ≤ 50.
* HTTP client: IPv4 only, TLS ≥1.2, HTTP/1.1 enforced, no environment proxy.
* Redirects ≤3; response size ≤1 MB.
* Alias collisions across apiCalls are rejected.
* Host allow-listing is engine policy (default open, configurable).

---

## 11) Error Handling (selected)

* **Placeholders**: invalid key syntax, missing keys, unclosed brackets.
* **HTTP**: non-2xx, non-JSON bodies, size/timeout/redirect limits.
* **Extracts**: empty expression, evaluation failure with no `defaults`, non-scalar results.
* **Rules**: syntax error, non-boolean result, timeout, expression length over limit.
* **Execution**: invalid `to`, ABI mismatch, cast errors, negative `value`.
* **Outputs**: missing referenced keys, invalid template substitution, evaluation errors.
* **Contract Reads**: invalid `to`, `saveAs` format, index out of range, arg evaluation/cast failures, missing required `defaults` after read failure.

---

## 12) Engine Integration (Rule Loading)

* Contracts may expose one of: `getRule()`, `rule()`, `getRuleJSON()`, `ruleJSON()` returning the JSON rule.
* Engines should attempt these in order and fall back to the next if empty.
* When a contract returns an `XGR1...` encrypted blob, engines may auto-decrypt via a configured crypto backend using the session owner’s permit.
* After load/decrypt, the engine parses the JSON into a structured `ParsedXRC137` model.

---

## 13) Validation Gas (informative)

* Engines may compute a simple validation-gas estimate (e.g., proportional to the number of rule expressions) for budgeting and logging.

---

## 14) Example (abridged)

```json
{
  "payload": {
    "User":    {"type":"address","optional":false},
    "AmountA": {"type":"number","optional":false},
    "AmountB": {"type":"number","optional":false}
  },
  "contractReads": [
    {
      "to": "0x0000000000000000000000000000000000000001",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA",
      "defaults": 0
    },
    {
      "to": "0x0000000000000000000000000000000000000002",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" },
      "defaults": { "0": 0, "1": 0, "2": 0 }
    }
  ],
  "apiCalls": [
    {
      "name": "test-quote",
      "method": "GET",
      "urlTemplate": "https://api.test.xgr.network/quote/AAPL",
      "contentType": "json",
      "headers": {"Accept": "application/json"},
      "extractMap": {
        "q.symbol": "resp.quote.symbol",
        "q.price":  "double(resp.quote.price.value)",
        "q.bid":    "double(resp.quote.bid.value)",
        "q.ask":    "double(resp.quote.ask.value)"
      },
      "defaults": {"q.price":0, "q.bid":0, "q.ask":0}
    }
  ],
  "rules": [
    "[AmountA] > 0",
    "[AmountB] > 0",
    "[q.price] > 0",
    "[BalanceA] >= [AmountA]"
  ],
  "onValid": {
    "waitMs": 50000,
    "encryptLogs": true,
    "logExpireDays": 30,
    "payload": {
      "AmountA": "[AmountA]-[AmountB]",
      "AmountB": "[AmountB]",
      "fromApi": "[q.symbol]",
      "reserves": "{'r0': [Reserve0], 'r1': [Reserve1], 'ts': [ReservesTs]}"
    },
    "execution": {
      "to": "0x0000000000000000000000000000000000000003",
      "function": "setMessage(string)",
      "args": ["'Balance: ' + string([BalanceA])"],
      "value": "0",
      "gas": { "limit": 150000 }
    }
  },
  "onInvalid": {
    "waitMs": 1000,
    "encryptLogs": false,
    "payload": {"memo":"invalid-path","error":"Amount"}
  },
  "address": "0x7863b2E0Cb04102bc3758C8A70aC88512B46477C"
}
```

---

## 15) Versioning & Compatibility

* This document describes XRC-137 **v0.2**. Future versions may add fields while preserving existing ones. Engines should ignore unknown fields and treat missing new fields as defaults to maintain forward compatibility.

---

### Companion document

For the expression language (operators, helpers, placeholder rewriting, timeouts, limits, scalar persistence rules, etc.), read **“XRC-137 Expression Evaluation — Developer Guide.”**

