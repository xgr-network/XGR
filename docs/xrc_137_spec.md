# XRC-137 — Technical Specification
> **Scope:** This document defines the XRC-137 JSON rule format and its runtime semantics for a **single validation step** with optional execution. **Expression language details are out of scope** and are covered in the companion document **“XRC-137 Expression Evaluation — Developer Guide.”**

---

## 1) Purpose & Design Goals

- Deterministic, fetch-only rule execution for a single step.
- Uniform authoring across payload, HTTP extracts, branching, and execution metadata.
- JSON-first, engine-agnostic; contracts return rules via `getRule()`/`rule()` and variants.

**Processing pipeline**: `Validate payload → Execute apiCalls (fetch) → Evaluate rules → Pick Outcome (onValid/onInvalid) → Optional execution → Receipt persistence`

---

## 2) Top-Level JSON Schema

```json
{
  "payload": { "<Key>": {"type":"string|number|bool|array|object", "optional": false } },
  "apiCalls": [ APICall, ... ],
  "contractReads": [ ContractRead, ... ],
  "rules": [ "<CEL>", ... ],
  "onValid":  Outcome,
  "onInvalid": Outcome,
  "address": "0x..."
}
```

**Notes**

- `payload` declares plain inputs and their requiredness.
- `apiCalls` fetch JSON and write extracted aliases into the inputs map.
- `contractReads` provide deterministic on-chain reads (engine-specific execution mechanism), see §8.
- `rules` are boolean expressions; **see companion Expression document** for language and functions.
- Outcomes define optional waits, **output payload mapping (flat)**, and an optional execution.

### 2.1 Top-level fields — parameter reference

| Field           | Type             | Required             | Description                                                                                                            |
| --------------- | ---------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `payload`       | object           | yes                  | Declares input keys available to expressions. Each entry defines `type` (doc hint) and `optional` (requiredness).      |
| `apiCalls`      | array of APICall | no                   | HTTP JSON fetches whose extracted aliases are merged into inputs. Order matters when aliases depend on prior extracts. |
| `contractReads` | array            | no                   | Declarative on-chain reads. ABI-aware (`to`/`function`/`args`) with optional `saveAs` to persist single/multi returns. |
| `rules`         | array of string  | no (recommended)     | Boolean expressions; if omitted, validation succeeds when required inputs are present.                                 |
| `onValid`       | Outcome          | no                   | Outcome executed when **all** rules evaluate to `true`.                                                                |
| `onInvalid`     | Outcome          | no                   | Outcome executed when **any** rule is `false` or a required key is missing.                                            |
| `address`       | string (0x…)     | no                   | Authoring aid; target EVM address for UI/display. Engines may ignore at runtime and use `execution.to` instead.        |

---

## 3) Payload (Inputs)

- `type` is descriptive (documentation aid), not strictly enforced at parse time.
- `optional:false` means the key **must exist and be non-empty** before rule evaluation. Empty string/array/map are treated as missing.
- Duplicate input keys from different sources are rejected during merge.

### 3.1 Payload fields — parameter reference

| Property         | Type    | Required | Notes                                                                                     |        |      |       |                                                                    |
| ---------------- | ------- | -------- | ----------------------------------------------------------------------------------------- | ------ | ---- | ----- | ------------------------------------------------------------------ |
| `<Key>`          | object  | yes      | Declares one input. The map key is the input name (used as `[Key]` in templates).         |        |      |       |                                                                    |
| `<Key>.type`     | string  | no       | Doc hint: `string \| number \| bool \| array \| object`. Engines may use for UI only.     |        |      |       |                                                                    |
| `<Key>.optional` | boolean | yes      | When `false`, missing/empty values send the flow to `onInvalid` without evaluating rules. |        |      |       |                                                                    |

**Requiredness check (summary)**

- Missing or empty required keys → immediate invalid path (rules are not evaluated), unless a `ContinueInvalid` is provided by the orchestrator layer.

---

## 4) HTTP API Calls (fetch-only, JSON)

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

- Timeout per call **8 s**; **≤3 redirects**; **response ≤1 MB**; **TLS ≥1.2**; HTTP/1.1 enforced; IPv4 dial only; no proxy from env.
- `contentType` must be `json`; array-root allowed.
- Each `extractMap` entry is a short **CEL** expression over variable `resp`.
- Extract results are **persisted automatically** if they are **scalar** (`string|number|bool|int`); reduce lists/objects in the expression when needed.
- On evaluation failure, engine uses `defaults[alias]` if present; otherwise the call fails.

**Alias rules**

- Regex: `^[A-Za-z][A-Za-z0-9._-]{0,63}$`; must not start with `_` or `sys.`; must be unique across all apiCalls in the rule.

### 4.1 Placeholders in `urlTemplate` / `bodyTemplate`

- Syntax: `[key]` references `inputs[key]`.
- URL templates URL-encode placeholder values; body templates use raw serialization.
- Escapes: `[[` → `[` and `]]` → `]`.
- Missing placeholder key ⇒ error.
- Complex/non-string values are JSON-serialized for body usage.

### 4.2 APICall fields — parameter reference

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

### 4.3 Example extracts

```json
{
  "extractMap": {
    "q.symbol": "resp.quote.symbol",
    "q.best_px": "max(resp.quote.venues.map(v, double(v.price.value)))"
  },
  "defaults": {"q.best_px": 0}
}
```

### 4.1 Placeholders in `urlTemplate` / `bodyTemplate`

- Syntax: `[key]` references `inputs[key]`.
- URL templates URL-encode placeholder values; body templates use raw serialization.
- Escapes: `[[` → `[` and `]]` → `]`.
- Missing placeholder key ⇒ error.
- Complex/non-string values are JSON-serialized for body usage.

---

## 5) Rules (Boolean)

- `rules` is an array of boolean expressions. **All must evaluate to `true`.**
- Missing referenced keys make the individual expression evaluate to `false` (no exception).
- **Expression details (operators, helpers, timeouts, length limits) are documented in “XRC-137 Expression Evaluation — Developer Guide.”**

### 5.1 Rule behavior — parameter reference

| Aspect             | Specification                                                                                                           |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Evaluation order   | Rules are evaluated in listed order; the outcome requires all to be `true`. Engines may short-circuit on first `false`. |
| Missing input keys | Any reference to a missing key yields `false` for that rule.                                                            |
| Return type        | Each rule must return a boolean; non-boolean results are an error.                                                      |
| Length limit       | See Expression guide (authoring limit and timeout).                                                                     |

---

## 6) Outcomes (`onValid` / `onInvalid`)

```json
Outcome = {
  "waitMs": 0,
  "waitUntilMs": 0,
  "payload": { "<outKey>": "<TemplateOrExpr>" },
  "execution": Execution
}
```

**Waiting**

- `waitUntilMs` (epoch ms) takes precedence; else `waitMs` (relative).
- Non-negative integers only. `0` means “no wait”.

**Output payload mapping**

- Exactly `"[Key]"` → direct copy from inputs.
- Plain strings containing **only** placeholders and text (no operators) → literal placeholder substitution (no expression engine).
- Otherwise → full expression evaluation (same environment as rules). **See companion Expression document** for semantics.

**Meta-only outcomes**

- If `execution` is omitted or has an empty `to`, no inner call is performed; outcome remains metadata-only (receipt still records payload and saves).

### 6.1 Outcome fields — parameter reference

| Field         | Type               | Required | Notes                                                                     |
| ------------- | ------------------ | -------- | ------------------------------------------------------------------------- |
| `waitMs`      | integer ≥ 0        | no       | Relative delay before applying the outcome. Ignored if `waitUntilMs` > 0. |
| `waitUntilMs` | integer (epoch ms) | no       | Absolute timestamp to apply the outcome. Overrides `waitMs`.              |
| `payload`     | object             | no       | Output keys to persist. Values can be template strings or expressions.    |
| `execution`   | object             | no       | See §7. When omitted or `to==""`, the outcome is metadata-only.           |

---

## 7) Execution

```json
Execution = {
  "to": "0x... or ${addr:Alias}",   // optional; empty ⇒ meta-only
  "function": "setMessage(string)",
  "args": ["<ExprOrLiteral>", ...],
  "value": "<ExprOrLiteral>",       // optional; Wei
  "gas": { "limit": 150000 }        // optional
}
```

**Semantics**

- `args[i]` are evaluated then cast to the ABI type of the declared `function` signature.
- `value` is evaluated to a non-negative integer (Wei). If omitted ⇒ 0.
- `gas.limit` (if present) is used as provided.
- When `to` is empty, the engine **must not** send an inner call.

**Error conditions (non-exhaustive)**

- Invalid target address/placeholer; argument count/type mismatch; casting failures; negative `value`.

### 7.1 Execution fields — parameter reference

| Field       | Type                | Required        | Notes                                                                                     |
| ----------- | ------------------- | --------------- | ----------------------------------------------------------------------------------------- |
| `to`        | string              | no              | EVM target or placeholder `${addr:...}`. If empty ⇒ no inner call.                        |
| `function`  | string              | yes if `to` set | Solidity signature (e.g., `transfer(address,uint256)`). Determines ABI casting of `args`. |
| `args`      | array               | yes if `to` set | Each entry may be a literal or expression. Evaluated at runtime, then ABI-encoded.        |
| `value`     | string              | no              | Expression/literal yielding Wei (uint256). If omitted ⇒ 0.                                |
| `gas.limit` | integer             | no              | Base gas limit used if provided.                                                          |

---

## 8) Contract Reads

Declarative, ABI-aware reads whose results become inputs and can be persisted.

```json
ContractRead = {
  "to": "0x... or ${addr:Alias}",
  "function": "balanceOf(address) returns (uint256)",
  "args": ["<ExprOrLiteral>", ...],
  "gas": { "limit": 150000 },
  "saveAs": "Alias" | { "0": "Key0", "1": "Key1", "...": "..." }
}
```

### 8.1 Semantics

- `to`: EVM address or engine-resolved placeholder like `${addr:TokenA}`.
- `function`: Solidity signature; determines ABI for args and return tuple.
- `args[i]`: evaluated first, then cast to ABI type.
- Return value is treated as a Solidity **tuple** (even for single return).
  - `saveAs: "Alias"` → persist index **0** under `"Alias"`.
  - `saveAs: { "0": "A", "1": "B", ... }` → persist **multiple indices** under provided keys.
- If `saveAs` is omitted, the engine may still execute the read for evaluation, but **no keys are added/persisted**.

### 8.2 SaveAs for multi-return — details

- Object keys are **stringified non-negative integers** (`"0"`, `"1"`, …).
- Values are non-empty strings naming the keys to write into the inputs map.
- Indices must be within the function’s return arity; otherwise error.

### 8.3 Validation & errors

- `to` must be a valid 0x address **or** a placeholder `${addr:...}`.
- `saveAs`:
  - String → non-empty; maps to index `0`.
  - Object → keys: `"0".."N"`, values: non-empty strings; indices `>=0`.
- Index out of range for the function’s return tuple → error.
- Arg evaluation/casting errors propagate as rule errors (engine handling).

### 8.4 Example (reads only)

```json
{
  "contractReads": [
    {
      "to": "${addr:TokenA}",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA"
    },
    {
      "to": "${addr:Pair}",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" }
    }
  ]
}
```

---

## 9) Persistence (Receipt)

- **APISaves**: every `extractMap` alias that evaluates to a **scalar**.  
- **ContractSaves**: every key produced via `contractReads.saveAs` (string or map entries).
- **PayloadAll**: final plain payload (non-API, non-contract) after outcome mapping.
- Optional log encryption may be applied by the engine when supported.

### 9.1 Persistence fields — parameter reference

| Bucket          | Source                          | Contains                                       |
| --------------- | -------------------------------- | ---------------------------------------------- |
| `APISaves`      | `apiCalls.extractMap` (scalars)  | Scalar extracted values only.                  |
| `ContractSaves` | `contractReads.saveAs`           | Deterministic chain values.                    |
| `PayloadAll`    | Outcome `payload`                | Final authored payload (non-API/non-contract). |

---

## 10) Limits & Security

- Recommended `apiCalls` per rule ≤ 50.
- HTTP client: IPv4 only, TLS ≥1.2, HTTP/1.1 enforced, no environment proxy.
- Redirects ≤3; response size ≤1 MB.
- Alias collisions across apiCalls are rejected.
- Host allow-listing is engine policy (default open, configurable).

---

## 11) Error Handling (selected)

- **Placeholders**: invalid key syntax, missing keys, unclosed brackets.
- **HTTP**: non-2xx, non-JSON bodies, size/timeout/redirect limits.
- **Extracts**: empty expression, evaluation failure with no `defaults`, non-scalar results.
- **Rules**: syntax error, non-boolean result, timeout, expression length over limit.
- **Execution**: invalid `to`, ABI mismatch, cast errors, negative `value`.
- **Outputs**: missing referenced keys, invalid template substitution, evaluation errors.
- **Contract Reads**: invalid `to`/placeholder, `saveAs` format, index out of range, arg evaluation/cast failures.

---

## 12) Engine Integration (Rule Loading)

- Contracts may expose one of: `getRule()`, `rule()`, `getRuleJSON()`, `ruleJSON()` returning the JSON rule.
- Engines should attempt these in order and fall back to the next if empty.
- When a contract returns an `XGR1...` encrypted blob, engines may auto-decrypt via a configured crypto backend using the session owner’s permit.
- After load/decrypt, the engine parses the JSON into a structured `ParsedXRC137` model.

---

## 13) Validation Gas (informative)

- Engines may compute a simple validation-gas estimate (e.g., proportional to the number of rule expressions) for budgeting and logging.

---

## 14) Example (abridged)

```json
{
  "payload": {
    "User":    {"type":"address","optional":false},
    "AmountA": {"type":"number","optional":false},
    "AmountB": {"type":"number","optional":false}
  },
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
  "contractReads": [
    {
      "to": "${addr:TokenA}",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA"
    },
    {
      "to": "${addr:Pair}",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" }
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
    "payload": {
      "AmountA": "[AmountA]-[AmountB]",
      "AmountB": "[AmountB]",
      "fromApi": "[q.symbol]",
      "reserves": "{'r0': [Reserve0], 'r1': [Reserve1], 'ts': [ReservesTs]}"
    },
    "execution": {
      "to": "${addr:MessageSink}",
      "function": "setMessage(string)",
      "args": ["'Balance: ' + string([BalanceA])"],
      "value": "0",
      "gas": { "limit": 150000 }
    }
  },
  "onInvalid": {
    "waitMs": 1000,
    "payload": {"memo":"invalid-path","error":"Amount"}
  },
  "address": "0x7863b2E0Cb04102bc3758C8A70aC88512B46477C"
}
```

---

## 15) Versioning & Compatibility

- This document describes XRC-137 **v0.2**. Future versions may add fields while preserving existing ones. Engines should ignore unknown fields and treat missing new fields as defaults to maintain forward compatibility.

---

### Companion document

For the expression language (operators, helpers, placeholder rewriting, timeouts, limits, scalar persistence rules, etc.), read **“XRC-137 Expression Evaluation — Developer Guide.”**
