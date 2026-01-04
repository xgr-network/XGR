# XRC-137 Rule Document Specification (xDaLa)

Version: 1.0 (pre-launch)
Last updated: 2026-01-03

This document specifies the **JSON rule document format** consumed by the **xDaLa Engine** when executing an XRC-137 step.
It is written for **rule authors**, **integrators**, and **SDK implementers** who need to produce interoperable rule documents.

---

## Table of contents

1. Concepts and terminology  
2. Execution model and evaluation order  
3. Document schema (top-level)  
4. Input payload specification (`payload`)  
5. API calls (`apiCalls`)  
6. Contract reads (`contractReads`)  
7. Rules (`rules`)  
8. Branches (`onValid`, `onInvalid`)  
9. Grants (`grants`)  
10. Type system and casting rules  
11. Complete examples  

---

## 1. Concepts and terminology

- **Rule document**: A single JSON document describing inputs, optional data acquisition (API/contract reads), validation rules, and the two outcome branches.
- **Input payload**: The caller-provided key/value inputs to the step, constrained by `payload`.
- **Extracted value**: A value produced by an API call (`extractMap`) or contract read (`saveAs`) and stored under a key. Extracted values are persisted in the step context and are available to subsequent rules/branches/steps; they also appear in receipts/log bundles.
- **Outcome (branch) payload**: The branch’s `payload` object. This is **not** an input schema; it is the **step’s output log payload** and an overlay for execution resolution.
- **Template**: A string that contains placeholders like `[Key]` and is rendered by substituting keys with their values.
- **Expression (CEL)**: A string that contains placeholders like `[Key]` and is evaluated as a CEL expression after placeholder rewriting.
- **Soft-invalid**: A recoverable evaluation failure caused by **missing placeholder keys** (e.g., `resp.ok` absent) where a declared `default` exists. Soft-invalid does **not** abort execution; it produces a deterministic fallback value (or forces the invalid branch if no deterministic value can be produced).
- **Hard error**: Any schema violation, type error without a valid conversion path, invalid ABI/function signatures, or CEL compilation/runtime errors not attributable to missing placeholder keys with defaults.

---

## 2. Execution model and evaluation order

For a single step, xDaLa executes the following pipeline:

1. **Parse rule document** and validate schema.
2. **Load and normalize input payload**:
   - Enforce `payload` types and apply input defaults.
   - If a required input is missing and has no default, the step is forced **invalid** (rules are skipped).
3. **Execute `apiCalls`** in array order:
   - Each call is performed, response decoded, and `extractMap` evaluated.
   - Extracted values are cast to their declared XRC type and placed into the step environment.
4. **Execute `contractReads`** in array order:
   - Each call is encoded via ABI, executed against the selected RPC, decoded, then mapped through `saveAs`.
   - Saved outputs are cast and placed into the step environment.
5. **Evaluate `rules`**:
   - Rules are evaluated as **AND**: all `validate` rules must be true for the step to be valid.
   - Typed rules (`abortStep`, `cancelSession`) can add meta-actions (see §7.3).
6. **Select outcome branch** (`onValid` or `onInvalid`).
7. **Compute outcome payload** (branch payload):
   - Values are resolved using template or CEL evaluation (see §8.2).
8. **Resolve execution** (branch execution):
   - `execution.to`, `execution.args[*].value`, and `execution.value.value` are resolved using template or CEL evaluation.
9. **Apply branch grants** (optional).
10. **Apply branch wait** (optional, `waitSec`) and finish step.

Important:
- The **outcome payload is not an input schema**. It does not define required/optional inputs.
- The xDaLa environment for rules/execution consists of:
  - input payload values
  - contract read outputs (`saveAs`)

---

## 3. Document schema (top-level)

A rule document is a JSON object with the following top-level fields.

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `payload` | object | Yes | Input payload schema (keys and types). |
| `apiCalls` | array | No | HTTP calls executed before rules. |
| `contractReads` | array | No | EVM contract reads executed before rules. |
| `rules` | array | Yes | Validation rules and optional typed actions. |
| `onValid` | object | No | Branch executed when the step is valid. |
| `onInvalid` | object | No | Branch executed when the step is invalid. |

Notes:
- If `onValid` or `onInvalid` is omitted, it is treated as an empty branch (no output payload, no execution, no grants).
- If `rules` is empty, the step is valid unless forced invalid by missing required inputs.

---

## 4. Input payload specification (`payload`)

### 4.1 Structure

`payload` is a map of **input key** → **field specification**:

```json
"payload": {
  "Amount": { "type": "int64" },
  "Memo":   { "type": "string", "default": "" }
}
```

Each field spec:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `type` | string | Yes | One of the supported XRC types (see §10). |
| `default` | any | No | If present, makes the input key optional for the caller; value is cast to `type`. |

### 4.2 Required vs optional inputs

- An input is **required** if and only if it has **no `default`**.
- Defaults are applied **before** any rules, API calls, contract reads, or execution resolution.

---

## 5. API calls (`apiCalls`)

### 5.1 Structure

`apiCalls` is an array of HTTP call objects executed sequentially.

```json
"apiCalls": [
  {
    "name": "q",
    "method": "GET",
    "urlTemplate": "https://api.example.net/quote/[Ticker]",
    "contentType": "json",
    "headers": { "Accept": "application/json" },
    "timeoutMs": 3000,
    "extractMap": {
      "Ok":    { "type": "bool",   "expr": "bool(resp.ok)",     "default": false },
      "Price": { "type": "double", "expr": "double(resp.last)" }
    }
  }
]
```

API call fields:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `name` | string | Yes | Short identifier used for error reporting. Must be unique within `apiCalls`. |
| `method` | string | Yes | `GET`, `POST`, `PUT`, etc. |
| `urlTemplate` | string | Yes | URL template rendered via placeholders (see §8.2). |
| `contentType` | string | Yes | Currently: `json`. Determines how the response is decoded into `resp`. |
| `bodyTemplate` | string | No | Request body template rendered via placeholders. Usually used with `POST`/`PUT`. |
| `headers` | object | No | Map of header name → header value (string). |
| `timeoutMs` | integer | No | Per-call timeout. If omitted, engine default applies. |
| `extractMap` | object | Yes | Map of output key → extraction spec. |

### 5.2 Extraction map (`extractMap`)

`extractMap` defines which keys the API call produces and how.

Each extract entry:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `type` | string | Yes | Target XRC type for the extracted value. |
| `expr` | string | Yes | CEL expression evaluated with `resp` bound to the decoded response. |
| `default` | any | No | Default value used if `expr` cannot be evaluated due to missing response fields (soft-invalid). |

### 5.3 Default semantics for API extracts (critical)

The **default belongs to the extracted key** (the left-hand side of `extractMap`), not to any particular `resp.*` field.

Example:

```json
"extractMap": {
  "Ok":    { "type":"bool",   "expr":"bool(resp.ok)",       "default": false },
  "notOk": { "type":"string", "expr":"string(resp.notok)",  "default":"not existing" }
}
```

- If `resp.ok` is missing (or `resp` is missing that path), `Ok` becomes `false`.
- If `resp.notok` is missing, `notOk` becomes `"not existing"`.

This is the only model that remains deterministic when an expression references **multiple** response fields.

If no `default` is declared and the expression cannot be evaluated due to missing response fields, the step becomes **soft-invalid** and will:
- downgrade from valid → invalid branch (if it was valid), or
- remain invalid (if already invalid).

---

## 6. Contract reads

Contract reads are optional `eth_call`-style reads that fetch on-chain state **before** API calls and **before** rule evaluation.

### 6.1 Execution order and environment

When a rule document is evaluated, xDaLa processes data sources in this order:

1. **Payload inputs** (including defaults)
2. **Contract reads** (this section)
3. **API calls** (HTTP)
4. **Rules** (boolean expressions)
5. **Branch selection** (`onValid` / `onInvalid`)
6. **Branch payload + execution evaluation**
7. **Grants** (if present)

Each contract read can use values that already exist in the evaluation environment at that point (payload inputs, and outputs from earlier contract reads in the same rule document).

### 6.2 Contract read object schema

`contractReads` is an array of contract read objects:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `to` | string | yes | Target contract address. Must evaluate to an EVM address (`0x…`). Expressions are allowed (e.g., `"[Token]"`), but the final result must be a plain address string. |
| `function` | string | yes | Solidity-style function signature **without return types**, e.g. `"balanceOf(address)"`, `"getReserves()"`, `"allowance(address,address)"`. |
| `args` | array | no | Ordered list of arguments for the function. Each element is a **TypedValue** (see 6.3). Defaults to `[]`. |
| `saveAs` | object | yes (recommended) | Mapping from **output index** (`"0"`, `"1"`, …) to a target key + type (see 6.4). Determines how the returned values are decoded and stored. |
| `rpc` | string | no | Optional backend selector for multi-chain deployments. If omitted, the default backend/environment is used. |

Notes:

- `to` and all argument fields are processed through the **Expression vs Template** logic (see the Expression Evaluation Guide). In practice, `to` must end up as a pure address string; template output like `"Token=[Token]"` will fail address validation.
- If `saveAs` is omitted or empty, the read may still be executed, but its outputs are not stored for later steps. In interoperable rule documents, you should always provide `saveAs`.

### 6.3 Argument format (`args`)

Each entry in `args` is a **TypedValue** object:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `type` | string | yes | XRC type of the argument (see “XRC types and casts”). |
| `value` | any | yes* | The raw value. If `value` is a string, it is resolved via **EvalOrRender** (expression or template). |
| `default` | any | no | Fallback applied when `value` is absent or cannot be resolved due to missing inputs (soft invalid conditions). |
| `expr` | string | no | Alternative to `value` for convenience. If provided, it is treated as the same as `value` (string). `value` and `expr` must not both be set. |

\* Exactly one of `value` or `expr` must be present.

**Casting flow for arguments**

1. Resolve the argument (string → EvalOrRender; non-string → used as-is).
2. Cast the resolved result to the declared XRC type (`type`).
3. Cast from XRC type into the ABI type implied by `function` parameter types.

If the argument cannot be resolved because required inputs are missing, xDaLa treats this as **soft invalid**. If a `default` is provided, it will be used for this argument and processing continues.

### 6.4 Output mapping (`saveAs`)

Contract reads can return multiple values (tuple returns). `saveAs` defines how xDaLa maps returned values into the evaluation environment.

`saveAs` is an object (map). The **property name** is the **0-based return index**, encoded as a string:

- `"0"` → first return value
- `"1"` → second return value
- …

Each entry has this structure:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `key` | string | yes | Target key name in the evaluation environment. |
| `type` | string | yes | XRC type used to cast the output. |
| `default` | any | no | Fallback value for **this output slot**. Used when the read fails, the return index is missing/out-of-range, or the value cannot be cast. |

**Per-slot semantics**

Defaults are **per output slot**, not global:

- If the call fails entirely, xDaLa will attempt to populate every `saveAs` target using its `default`. Targets without a `default` become **soft invalid**.
- If the call succeeds but returns fewer values than referenced by `saveAs`, only the out-of-range indices use defaults (or become soft invalid).
- If casting fails for a specific slot, only that slot falls back to its `default` (or becomes soft invalid). Other slots may still be stored.

### 6.5 Examples

#### Example A: Single-value return

```json
{
  "contractReads": [
    {
      "to": "[Token]",
      "function": "balanceOf(address)",
      "args": [
        { "type": "address", "value": "[User]" }
      ],
      "saveAs": {
        "0": { "key": "UserBalance", "type": "uint256", "default": "0" }
      }
    }
  ]
}
```

- `UserBalance` will always exist:
  - real decoded balance if the call succeeds
  - `"0"` if the call fails or cannot be decoded/cast

#### Example B: Multi-value return (tuple)

```json
{
  "contractReads": [
    {
      "to": "0x1f98431c8ad98523631ae4a59f267346ea31f984",
      "function": "slot0()",
      "args": [],
      "saveAs": {
        "0": { "key": "SqrtPriceX96", "type": "uint256" },
        "1": { "key": "Tick",         "type": "int64",  "default": 0 }
      }
    }
  ]
}
```

- If `slot0()` returns fewer than 2 values or `Tick` casting fails, `Tick` becomes `0` (because it has a default), while `SqrtPriceX96` becomes soft invalid if it has no default.

#### Example C: Selecting a specific RPC backend

```json
{
  "contractReads": [
    {
      "rpc": "ethereum-mainnet",
      "to": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "function": "decimals()",
      "args": [],
      "saveAs": {
        "0": { "key": "TokenDecimals", "type": "uint64", "default": 6 }
      }
    }
  ]
}
```

The meaning of the `rpc` selector depends on the deployment environment (which backends are configured). If the backend is unknown/unavailable, the read is treated as a failure and `default` handling applies.


## 7. Rules (`rules`)

### 7.1 Structure

`rules` is an array. Each entry is either:
- a **string rule** (shorthand for `type: "validate"`), or
- an **object rule** with explicit `type`.

Example:

```json
"rules": [
  "[Amount] > 0",
  { "type": "validate", "expression": "[Country] == "DE"" },
  { "type": "abortStep", "expression": "[FraudScore] > 0.9" }
]
```

### 7.2 Validation semantics

- All `validate` rules must evaluate to `true` for the step to be considered valid.
- If the step is forced invalid due to missing required inputs, `validate` rules are not evaluated.

### 7.3 Typed rule actions

Typed rules allow additional actions beyond validation.

Supported types:

| Type | Meaning |
|---|---|
| `validate` | Normal validation rule. |
| `abortStep` | Abort the current step (terminal for this step). |
| `cancelSession` | Cancel the whole session/process (terminal for the session). |

Typed actions are evaluated against the same environment as validation rules.

---

## 8. Branches (`onValid`, `onInvalid`)

Branches define what happens after validation.

### 8.1 Branch object structure

A branch is a JSON object with the following fields:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `payload` | object | No | Outcome payload (log output + execution overlay). |
| `execution` | object | No | Inner transaction call specification (see §8.3). |
| `grants` | array | No | Grants to apply for this step outcome (see §9). |
| `logExpireDays` | integer | No | TTL for the step’s log bundle; also default grant TTL (see §9.3). |
| `waitSec` | integer | No | Optional post-step wait time in seconds. |
| `encryptLogs` | boolean | No | Whether to encrypt the log bundle for this branch (engine-dependent). |

### 8.2 Branch payload resolution

Branch `payload` is a map of output key → value.

Values may be:
- a **literal** (number, boolean, object, array), or
- a **string** that is resolved via **template or CEL**, using the same Eval-or-Render rules as execution (see below).

Example:

```json
"onInvalid": {
  "payload": {
    "memo": "G:inc",
    "A_out": "[A_out] + 15",
    "B_in": "[B_in]"
  }
}
```

Here, `"[A_out] + 15"` is evaluated as a CEL expression and produces a numeric result if `A_out` is numeric.

### 8.3 Execution object (`execution`)

`execution` describes an inner contract call the engine should execute after validation.

```json
"execution": {
  "to": "[TargetContract]",
  "gas": { "limit": 350000 },
  "function": "transfer(address,uint256)(bool)",
  "args": [
    { "type": "address", "value": "[Recipient]" },
    { "type": "uint256", "value": "[AmountWei]" }
  ],
  "value": { "type": "int64", "value": "0" }
}
```

Execution fields:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `to` | string | Yes | Target address (template/CEL allowed). |
| `gas` | object | No | Gas limit cap: `{ "limit": <uint64> }`. |
| `function` | string | No | ABI signature for encoding `data`. If omitted, `data` is empty and only `to`/`value` transfer is possible. |
| `args` | array | No | Arguments (`TypedValue[]`). Required if `function` has inputs. |
| `value` | object | No | Native value transfer. Typed value (see `TypedValue`). |

### 8.4 Template vs CEL evaluation (Eval-or-Render)

Any **string field** that is declared as template/CEL-capable (branch payload strings, `execution.to`, `execution.args[*].value`, `execution.value.value`, `urlTemplate`, `bodyTemplate`) is resolved as follows:

1. Placeholders `[Key]` are detected and collected.
2. If the string is a **pure template** (no CEL operators/functions), it is rendered by substituting `[Key]`.
3. Otherwise it is rewritten into a CEL expression and evaluated.

Missing placeholder keys:
- If a relevant `default` exists for the target key (input field default, API extract default, contract read default), evaluation becomes soft-invalid and resolves deterministically.
- Otherwise it triggers soft-invalid handling (downgrade to invalid branch if needed).

---

## 9. Grants (`grants`)

Grants allow a rule author to declare which addresses receive access rights in the xDaLa process database for this step outcome.

### 9.1 Structure

`grants` is an array of grant entries:

```json
"grants": [
  { "address": "0xabc...def", "rights": 1, "expireDays": 30 },
  { "address": "[Auditor]",   "rights": 5 }
]
```

Grant entry fields:

| Field | Type | Required | Description |
|---|---:|:---:|---|
| `address` | string | Yes | Grantee EVM address (template/CEL may be used if it resolves to an address). |
| `rights` | integer | Yes | Bitmask of rights (see below). |
| `expireDays` | integer | No | TTL in days. If omitted/0, branch `logExpireDays` is used if present; otherwise an engine default applies. |

### 9.2 Rights bitmask

`rights` is a bitmask:

| Bit | Name | Meaning |
|---:|---|---|
| `1` | `READ` | Read access (e.g., read log bundles / process artifacts). |
| `2` | `WRITE` | Write access (engine-specific; typically limited). |
| `4` | `MANAGE` | Manage/revoke grants. |

Examples:
- `1` = READ
- `3` = READ + WRITE
- `5` = READ + MANAGE

### 9.3 Relationship to `logExpireDays`

`logExpireDays` is primarily the TTL for the log bundle produced by the step.  
If a grant does not specify `expireDays`, `logExpireDays` is used as the default TTL for that grant.

---

## 10. Type system and casting rules

### 10.1 Supported XRC types

The xDaLa Engine supports the following XRC types:

| Type | Canonical representation | Notes |
|---|---|---|
| `string` | string | UTF-8 text. |
| `bool` | boolean | `true` / `false`. |
| `int64` | signed 64-bit integer | Range: -9e18..+9e18 (int64). |
| `uint64` | unsigned 64-bit integer | Range: 0..1.8e19 (uint64). |
| `int256` | decimal string | Signed 256-bit integer represented as base-10 string. |
| `uint256` | decimal string | Unsigned 256-bit integer represented as base-10 string. |
| `double` | float64 | IEEE-754 double. |
| `decimal` | string | Decimal string (preserves representation). |
| `uuid` | string | Canonical UUID string. |
| `address` | string | `0x` + 40 hex chars. |
| `bytes` | byte array | Typically encoded/decoded as `0x` hex string in JSON contexts. |
| `bytes32` | `0x` hex string (32 bytes) | Must be exactly 32 bytes. |
| `timestamp_ms` | uint64 | Milliseconds since Unix epoch. |
| `duration_ms` | uint64 | Milliseconds duration. |

### 10.2 Casting rules (summary)

Whenever a value is written into the environment (input default, API extract, contract read, branch payload result, execution arg/value), it is cast to the declared XRC type.

Key principles:
- Numeric casts are strict about range. Overflows are hard errors.
- `int256` / `uint256` are stored as **decimal strings** to avoid platform-specific big-int arithmetic in CEL.
- `bytes` and `bytes32` accept `0x`-prefixed hex strings (and reject invalid hex).

Common accepted input forms:

- `bool`: accepts `true/false`, strings `"true"/"false"`, and numeric 0/1 (any non-zero becomes `true`).
- `int64` / `uint64`: accept integer JSON numbers and decimal strings. Floats must be integral (e.g., `42.0`).
- `double`: accepts numbers and numeric strings.
- `address`: must match `0x` + 40 hex chars (case-insensitive).
- `uuid`: must match canonical UUID format.
- `bytes`: accepts `0x` hex strings (even-length), or raw `[]byte` internally.
- `bytes32`: like `bytes` but must be exactly 32 bytes.
- `timestamp_ms` / `duration_ms`: accept integer numbers or decimal strings and are cast to `uint64`.

---

## 11. Complete examples

### 11.1 Minimal validation-only rule

```json
{
  "payload": {
    "Amount": { "type": "int64" }
  },
  "rules": [
    "[Amount] > 0"
  ]
}
```

### 11.2 API call with extract defaults and branch payload arithmetic

```json
{
  "payload": {
    "Ticker": { "type": "string" },
    "A_out":  { "type": "int64", "default": 30 },
    "B_in":   { "type": "int64", "default": 7 }
  },
  "apiCalls": [
    {
      "name": "q",
      "method": "GET",
      "urlTemplate": "https://api.example.net/quote/[Ticker]",
      "contentType": "json",
      "timeoutMs": 2500,
      "extractMap": {
        "Ok":    { "type":"bool",   "expr":"bool(resp.ok)",      "default": false },
        "notOk": { "type":"string", "expr":"string(resp.notok)", "default":"not existing" }
      }
    }
  ],
  "rules": [
    "[Ok] == true"
  ],
  "onValid": {
    "payload": {
      "memo": "G:ok",
      "A_out": "[A_out]",
      "B_in": "[B_in]"
    }
  },
  "onInvalid": {
    "payload": {
      "memo": "G:inc",
      "A_out": "[A_out] + 15",
      "B_in": "[B_in]"
    }
  }
}
```

### 11.3 Contract read + execution + grants

```json
{
  "payload": {
    "Owner": { "type": "address" },
    "Auditor": { "type": "address" }
  },
  "contractReads": [
    {
      "to": "0x1111111111111111111111111111111111111111",
      "function": "balanceOf(address)(uint256)",
      "args": [
        { "type": "address", "value": "[Owner]" }
      ],
      "saveAs": {
        "0": { "key": "Balance", "type": "uint256", "default": "0" }
      }
    }
  ],
  "rules": [
    "[Balance] != "0""
  ],
  "onValid": {
    "payload": {
      "memo": "has balance",
      "balance": "[Balance]"
    },
    "execution": {
      "to": "0x2222222222222222222222222222222222222222",
      "gas": { "limit": 250000 },
      "function": "notify(address,uint256)(bool)",
      "args": [
        { "type": "address", "value": "[Owner]" },
        { "type": "uint256", "value": "[Balance]" }
      ]
    },
    "grants": [
      { "address": "[Auditor]", "rights": 1, "expireDays": 90 }
    ],
    "logExpireDays": 90,
    "encryptLogs": true
  },
  "onInvalid": {
    "payload": { "memo": "no balance" }
  }
}
```