# XRC‑137 Developer Guide (Unified Spec)

> **Audience:** Smart‑contract and backend engineers integrating with **XDaLa** / **XGRChain**.  
> **Scope:** This document unifies the **XRC‑137 contract interface** and the **XRC‑137 JSON rule format** into a single, end‑to‑end specification. It preserves all prior information while restructuring it for developer flow.

---

## 1. Purpose and mental model

**XRC‑137** defines _how rules are published on‑chain_ and _how those rules are executed off‑chain/in‑engine_ against a payload, optional chain reads, optional API calls, and outcome branches. Think of it as a **Rules‑as‑Contract (RaC)** surface:

- The **contract** is the **canonical publisher** of a single rule (as a string): either **plaintext JSON** or an **encrypted envelope**.  
- The **engine** (XDaLa) **loads** the rule from the contract, optionally **decrypts** it, **evaluates** it deterministically, and **emits** a result (payload transform, execution spec, logs).

This split keeps JSON **engine‑agnostic** and uses the contract as a **distribution/policy layer** (encryption defaults, auditability, versioning).

---

## 2. Contract interface (functions & events)

Implementations may vary, but engines rely on the following **read surface** and commonly seen **events**.

### 2.1 Read surface (canonical)

```solidity
/// @title IXRC137 — canonical read surface expected by engines
interface IXRC137 {
    /// Return the rule as string: plaintext JSON or XGR1 envelope (e.g. "XGR1.AESGCM.<rid>.<blob>").
    function getRule() external view returns (string memory);

    /// Aliases some contracts may expose. Engines probe these in order.
    function rule() external view returns (string memory);
    function getRuleJSON() external view returns (string memory);
    function ruleJSON() external view returns (string memory);

    /// Encryption signal. Non‑zero `rid` means “encrypted”.
    /// `suite` documents the crypto suite (e.g. "AESGCM").
    function encrypted() external view returns (bytes32 rid, string memory suite);
}
```

**Loader order (first hit wins):** `getRule()` → `rule()` → `getRuleJSON()` → `ruleJSON()`.  
If the returned string starts with `XGR1.`, the engine auto‑decrypts (owner grant / DEK) before parsing as JSON. If the JSON omits `address`, the engine injects the contract address for traceability.

### 2.2 Reference events (typical, not required by engines)

```solidity
event RuleUpdated(string newRule);
event EncryptedSet(bytes32 rid, string suite);
event EncryptedCleared();
```

These are useful for indexers/UIs. Engines do not require them for reads.

### 2.3 Minimal example

```solidity
pragma solidity ^0.8.21;

interface IXRC137 {
    function getRule() external view returns (string memory);
    function rule() external view returns (string memory);
    function getRuleJSON() external view returns (string memory);
    function ruleJSON() external view returns (string memory);
    function encrypted() external view returns (bytes32 rid, string memory suite);
}

contract MyRule is IXRC137 {
    string  private _rule;              // plaintext JSON or XGR1.<…> blob
    bytes32 private _rid;               // 0x0 = plaintext; else encrypted
    string  private _suite;             // e.g. "AESGCM"

    constructor(string memory ruleJSONOrXGR1, bytes32 rid, string memory suite) {
        _rule  = ruleJSONOrXGR1;
        _rid   = rid;
        _suite = suite;
    }

    function getRule() external view returns (string memory) { return _rule; }
    function rule() external view returns (string memory) { return _rule; }
    function getRuleJSON() external view returns (string memory) { return _rule; }
    function ruleJSON() external view returns (string memory) { return _rule; }
    function encrypted() external view returns (bytes32 rid, string memory suite) { return (_rid, _suite); }

    // Optional admin helpers
    function _setPlaintext(string memory json) internal { _rule = json; _rid = bytes32(0); _suite = ""; }
    function _setEncrypted(string memory xgr1, bytes32 rid, string memory suite) internal { _rule = xgr1; _rid = rid; _suite = suite; }
}
```

---

## 3. JSON rule format (developer reference)

The following consolidates the JSON schema, keeping existing content intact while clarifying runtime semantics. The engine consumes this JSON after loading (and decrypting if needed).

### 3.1 Structure at a glance

- `payload`: input fields (type, optional, validation hints).
- `contractReads`: on‑chain reads that merge into inputs.
- `apiCalls`: off‑chain reads that merge into inputs.
- `rules`: boolean expressions over the inputs (all must be true).
- `onValid` / `onInvalid`:
  - `payload`: output mapping (copy/template/expression).
  - `execution`: optional call spec (to/function/args/gas/value/extras).
  - `encryptLogs`, `logExpireDays`: branch‑level log policy.
  - `waitMs`, `waitUntilMs`: timing hints.

> **Requiredness:** `optional:false` enforces **existence and non‑emptiness**. Missing required keys mark the step **invalid** and set `missingRequired` meta.  
> **Evaluation order:** `contractReads` → `apiCalls` → `rules` → outcome build.  
> **Outcome mapping:** exact `"[Key]"` → value copy; template w/o operators → substitution; otherwise **expression evaluation (CEL)**.

### 3.2 Full specification (verbatim content preserved)

> The **entire previous JSON spec** is kept below verbatim to ensure no information is lost; it has been placed here so the developer can read it in flow before moving on to engine semantics.

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

## 4. Engine runtime semantics (how the JSON is executed)

1. **Rule loading.** Engine calls the contract getters in the order above. If a value starts with `XGR1.`, the engine **decrypts** via the session owner’s grants and parses JSON. If the JSON lacks `address`, the engine injects the contract’s address.
2. **Merging inputs.** `contractReads` and `apiCalls` values are merged into the inbound payload. These merged keys are available to templates and expressions.
3. **Rule evaluation.** All `rules` must evaluate to `true`. Missing keys → affected expression evaluates to `false` (no hard exception).
4. **Outcome selection.** `onValid` if all rules are true, else `onInvalid`.
5. **Payload mapping.** Copy/template/expression mapping applied as described. The final output payload is attached to the step result.
6. **Execution spec.** If the selected outcome has `execution` with a non‑empty `to`, the engine returns a call spec. If omitted/empty, this is a **meta‑only** step (still can log data).
7. **Persistence & logs.** The engine persists `PayloadAll`, `APISaves`, `ContractSaves` into the receipt. Logs may be **encrypted**:
   - **Default**: derived from the contract’s `encrypted()` (`rid != 0x0` ⇒ encrypt).
   - **Override**: per‑branch `encryptLogs` and `logExpireDays` override the default.
   - **Fail‑closed**: missing owner/read key ⇒ no plaintext logs; step marked error path.
8. **Validation gas (heuristic).** Additive estimate over pipeline (payload/rules/reads/APIs/outcome/execution), plus a **split** for _common_, _onValid_, _onInvalid_ used by precompiles for budgeting. The heuristic is structure‑driven and unclamped (complex rules may exceed 300k).

---

## 5. Developer workflow & examples

1. **Author the rule** as JSON (section 3).  
2. **Publish** via XRC‑137:
   - plaintext: set the JSON string
   - encrypted: set `XGR1.<suite>.<rid>.<blob>`, and ensure `encrypted().rid` reflects non‑zero
3. **Integrate in the engine**:
   - supply payload
   - (optional) enable contract/API reads
   - evaluate and consume the resulting payload/execution spec
4. **Observe** events (`RuleUpdated`, `EncryptedSet`, `EncryptedCleared`) in your indexer/UI.

### 5.1 Minimal JSON example (valid path with payload transform)

```json
{
  "payload": {
    "AmountA": { "type": "number", "optional": false }
  },
  "rules": [
    "[AmountA] > 0"
  ],
  "onValid": {
    "payload": {
      "memo": "valid-path",
      "AmountA": "[AmountA]-10"
    }
  },
  "onInvalid": {}
}
```

---

## 6. ABI quick reference

| Signature | Purpose | Returns |
|---|---|---|
| `getRule()` | Primary getter (string: JSON or XGR1 envelope) | `string` |
| `rule()` | Alias getter | `string` |
| `getRuleJSON()` | Alias getter | `string` |
| `ruleJSON()` | Alias getter | `string` |
| `encrypted()` | Encryption state (non‑zero `rid` ⇒ encrypted) | `(bytes32 rid, string suite)` |

**Typical events:** `RuleUpdated(string)`, `EncryptedSet(bytes32,string)`, `EncryptedCleared()`.

---

## 7. Compatibility & notes

- Engines only require the **read surface**; admin/storage is up to the implementor.
- If you already expose `string public ruleJson;` and `EncInfo public encrypted;`, you automatically get `ruleJson()` and `encrypted()`.
- For maximum compatibility, expose all four getters (order above).

---

## Appendix — Original JSON spec (verbatim, unchanged)

To guarantee that **no information is lost**, the previous JSON specification is included here verbatim.

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

