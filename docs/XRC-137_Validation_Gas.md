# XRC‑137 Validation Gas — Developer Guide (Engine Heuristic v0.2)

> **Scope:** This document describes the **Validation Gas** heuristic for **XDaLa’s** processing of **XRC‑137** rule JSON. It estimates the CPU/I‑O work performed by the **engine** while validating and preparing an action: payload checks, contract reads, HTTP API calls, rule evaluation (CEL), outcome mapping, and optional execution preparation.
>
> **Out of scope:** **EVM gas** for on‑chain transactions is **not affected** by Validation Gas. The actual on‑chain costs of a transaction (e.g., function call, storage, logs) are dictated by the EVM and your `gas.limit`/`maxFee` settings on chain.

---

## 1) Pipeline & Where Validation Gas Fits

The engine processes an XRC‑137 rule set as a pipeline:

1. **Validate payload** (presence/type of required and optional inputs)
2. **Contract reads** (optional) → ABI call, normalize result, apply defaults/saveAs
3. **HTTP API calls** (optional) → fetch/parse JSON, compute extracts (CEL over `resp`)
4. **Evaluate rules** (CEL) → must yield boolean(s) that decide the branch
5. **Choose outcome** (`onValid` or `onInvalid`) → map output payload (templates or expressions)
6. **Optional execution preparation** (encode args/value; *actual* EVM call happens on-chain)
7. **Persist/logs** (optionally with encrypted logs)

**Validation Gas** is a *single number* that summarizes how heavy this pipeline is expected to be **off‑chain / in the engine**. It is computed on the parsed representation (`ParsedXRC137`) by `CalculateGas(...)`.

---

## 2) Design Philosophy

- **Predictive, not exact.** We do *not* run a heavy AST to count instruction cycles. Instead, we use **lightweight token counters** that correlate well with CPU work.
- **Structure‑driven.** Each stage (payload, reads, APIs, rules, outcomes, optional execution) contributes an **additive** amount.
- **Separation of concerns.** This has **no coupling to EVM gas**. Think of it as a cost hint for the *validation/prepare* path in the engine.

---

## 3) Tokenization Heuristics (No AST)

We use resilient regular expressions to identify complexity indicators:

- **Operators** in expressions: `&&`, `||`, `!=`, `==`, `<`, `<=`, `>`, `>=`, `%`, `*`, `/`, `+`, `-`
  Counted anywhere **outside** of `[...]` placeholder blocks.
- **Function calls:** any token that looks like `Name(` (also catches method style like `"abc".startsWith(` ⇒ `startsWith(`).
- **Placeholders:** every `[...]` is counted (simple string scan for `[`).
- **Regex hint:** if an expression contains **`matches(`** (CEL/RE2) it gets a regex surcharge.
  *Current build note:* the heuristic also recognizes the literal token **`regex(`** so that custom helpers, if introduced by the CEL environment, are naturally covered. If you only want CEL’s `matches(...)`, narrow the detector accordingly.

> **Why this works:** CEL expression compilation & evaluation are heavier when there are more operators, function calls, and regexes. Placeholders add small overhead due to key lookups and templating.

---
## 4) Weights (Constants)

The following constants are used by the heuristic in *v0.2* (tunable in code):

| Component | Symbol | Value |
|---|---:|---:|
| Base overhead | `gBase` | **10,000** |
| Required input (payload) | `gPerRequiredInput` | **1,000** |
| Optional input (payload) | `gPerOptionalInput` | **200** |
| Rule base | `gPerRuleBase` | **1,200** |
| Per operator | `gPerOp` | **600** |
| Per function | `gPerFunc` | **800** |
| Per placeholder `[...]` | `gPerPlaceholder` | **250** |
| Regex surcharge (rules/outcomes) | `gRegexSurcharge` | **4,000** |
| Contract read base | `gPerReadBase` | **6,000** |
| Per read arg (count) | `gPerReadArg` | **600** |
| Per `saveAs` slot | `gPerReadSave` | **400** |
| Per `defaults` entry | `gPerReadDefault` | **250** |
| API call base | `gPerAPICallBase` | **8,000** |
| Per placeholder in URL/Body | `gPerAPIPlaceholder` | **200** |
| Extract base (per alias) | `gPerAPIExtract` | **600** |
| Extract per function | `gPerAPIExtractFunc` | **400** |
| Extract per operator | `gPerAPIExtractOp` | **500** |
| Extract regex surcharge | `gAPIMatchesSurcharge` | **4,000** |
| Outcome per key | `gPerOutcomeKey` | **400** |
| Outcome expression surcharge | `gPerOutcomeExpr` | **600** |
| Execution base (prep only) | `gPerExecBase` | **1,200** |
| Execution per arg (count) | `gPerExecArg` | **700** |
| Execution value (if present) | `gPerExecValue` | **800** |
| Encrypted logs (branch) | `gPerEncryptLogs` | **2,000** |

> **Reminder:** This is **engine work only**. **EVM gas** for the on‑chain transaction is accounted for separately by the chain and is unaffected by Validation Gas.

---

## 5) Payload Costs

Each payload input adds a small, fixed cost:

- **Required:** presence & basic checks → `gPerRequiredInput`
- **Optional:** presence/merge overhead → `gPerOptionalInput`

**Example**

```json
"payload": {
  "User":    {"type":"address", "optional": false},
  "AmountA": {"type":"number",  "optional": false},
  "Memo":    {"type":"string",  "optional": true}
}
```

Cost = `2 × 1,000 + 1 × 200 = 2,200`

---

## 6) Rules (CEL): Operators, Functions, Placeholders, Regex

For each rule string:

- Start with **`gPerRuleBase`**
- Add **`ops × gPerOp`**
- Add **`funcs × gPerFunc`**
- Add **`placeholders × gPerPlaceholder`**
- If the expression uses **regex** (detected by `matches(` and, in the current build, also `regex(`), add **`gRegexSurcharge`**

**Examples**

1) **`[AmountA] > 0`**  
   - ops: 1 (`>`), funcs: 0, placeholders: 1, no regex  
   - Cost: `1,200 + 1×600 + 1×250 = **2,050**`

2) **`[BalanceA] >= [AmountA]`**  
   - ops: 1 (`>=`), funcs: 0, placeholders: 2  
   - Cost: `1,200 + 600 + 2×250 = **2,300**`

3) **`string([Memo]).matches("^INV-[0-9]+$")`**  
   - funcs: 2 (`string(` and `matches(`), placeholders: 1, regex: **yes**  
   - Cost: `1,200 + 2×800 + 1×250 + 4,000 = **7,050**`

4) **`startsWith([Code], "XG") && length([Code]) == 10`**  
   - ops: 3 (`&&`, `==`, *implicit*), funcs: 2 (`startsWith(`, `length(`), placeholders: 1  
   - Cost: `1,200 + 3×600 + 2×800 + 1×250 = **5,050**`

> The engine compiles and evaluates these with CEL. The heuristic merely anticipates work based on token counts.

---
## 7) Contract Reads

Per read entry:

- **Base:** `gPerReadBase`
- **Args (count):** `#args × gPerReadArg`
- **Arg complexity:** for each arg string, count operators/functions/placeholders as above and add `ops × gPerOp + funcs × gPerFunc + placeholders × gPerPlaceholder`
- **Saves:** `#saveAs × gPerReadSave`
- **Defaults:** `#defaults × gPerReadDefault`

**Example**

```json
"contractReads": [{
  "to": "0x...0001",
  "function": "balanceOf(address) returns (uint256)",
  "args": ["[User]"],
  "saveAs": "BalanceA",
  "defaults": 0
}]
```

- Base: `6,000`
- Args (count): `1 × 600 = 600`
- Arg complexity: `"[User]"` → placeholders: 1 ⇒ `+250`
- Saves: `1 × 400 = 400`
- Defaults: `1 × 250 = 250`

**Total read = 6,000 + 600 + 250 + 400 + 250 = 7,500`

*(If you also write the arg as an arithmetic expression, that arg complexity grows accordingly.)*

---

## 8) HTTP API Calls (JSON)

Per API call:

- **Base:** `gPerAPICallBase`
- **Placeholders in URL/Body templates:** count `[` in `urlTemplate` and `bodyTemplate` → `#placeholders × gPerAPIPlaceholder`
- **Extracts:** for each alias in `extractMap`  
  - Add `gPerAPIExtract`  
  - Add expression complexity: `ops × gPerAPIExtractOp + funcs × gPerAPIExtractFunc`  
  - If the extract uses regex (`matches(` and, in the current build, `regex(`), add `gAPIMatchesSurcharge`

**Example**

```json
"apiCalls": [{
  "name": "q",
  "method": "GET",
  "urlTemplate": "https://api/x?u=[User]&q=[Query]",
  "contentType": "json",
  "extractMap": {
    "q.symbol": "resp.quote.symbol",
    "q.price":  "double(resp.quote.price.value)",
    "q.ok":     "resp.message.matches('^OK$')"
  },
  "defaults": {"q.price":0}
}]
```

- Base: `8,000`
- URL placeholders: 2 ⇒ `2 × 200 = 400` → **8,400**
- Extracts:  
  - `q.symbol`: no ops/funcs ⇒ `600`  
  - `q.price`: one function `double(` ⇒ `600 + 1×400 = 1,000`  
  - `q.ok`: one function `matches(` with regex ⇒ `600 + 1×400 + 4,000 = 5,000`  
- **Total extracts = 600 + 1,000 + 5,000 = 6,600**  
- **Total API call = 8,400 + 6,600 = 15,000**

---

## 9) Outcomes: Templates vs Expressions

Outcome payload values can be either **templates** or **expressions**.

- **Template (no expression surcharge):** only placeholders and static text.  
  Example: `"memo": "ID-[OrderId]"` → counts key + placeholders only.

- **Expression (adds expression surcharge):** arithmetic or function calls found **outside** of `[...]`.  
  Example: `"amount": "[AmountA] - [AmountB]"` → key + placeholders + expression surcharge + operator cost.

The heuristic matches the engine’s rule: **pure templates** are substituted directly, **expressions** are rewritten to CEL and evaluated.

**Outcome cost per key**

```
gPerOutcomeKey
+ placeholders × gPerPlaceholder
+ (isExpr ? (gPerOutcomeExpr + ops × gPerOp + funcs × gPerFunc
            + (hasRegex ? gRegexSurcharge : 0)) : 0)
```

**Examples**

- `{"to": "[Recipient]"}` → `400 + 1×250 = 650`
- `{"net": "[AmountA] - [AmountB]"}` → `400 + 2×250 + 600 + 1×600 = 2,100`
- `{"memo": "upper([Text])"}` → function call outside `[...]` ⇒ expression path

**Subtlety about `+`/`-`:** The heuristic treats `+`/`-` as arithmetic **only when** they appear between operands (e.g., digits, `]`, `)` on the left and digits, `[`, `(` on the right).  
So `"ID-[A]-[B]"` remains a **template**, whereas `"[A] - [B]"` is an **expression**.

---
## 10) Optional Execution Preparation (EVM gas is separate)

When an outcome includes an `execution` object, Validation Gas only prices the **preparation** work:

- **Base:** `gPerExecBase`
- **Args (count):** `#args × gPerExecArg`
- **Arg complexity:** count ops/funcs/placeholders per arg string
- **Value (if present):** `gPerExecValue + value complexity`

This **does not** include the **on‑chain** cost of calling the EVM. Once the transaction is sent, the chain will consume **EVM gas** independently of Validation Gas.

**Example**

```json
"execution": {
  "to": "0x...0003",
  "function": "transfer(address,uint256)",
  "args": ["[User]", "[AmountA]"],
  "value": "0",
  "gas": {"limit": 150000}
}
```

- Base: `1,200`
- Args (count): `2 × 700 = 1,400`
- Arg complexity: `"[User]"` + `"[AmountA]"` ⇒ `2 × 250 = 500`
- Value present: `+800`

**Execution prep total = 1,200 + 1,400 + 500 + 800 = 3,900**

> The subsequent **on‑chain** `transfer(...)` consumes **EVM gas** which is **outside** of Validation Gas.

---

## 11) Encrypted Logs (optional)

If a branch sets `encryptLogs: true`, we add a small CPU surcharge `gPerEncryptLogs`. This reflects extra engine work for encrypting persisted data (keys are handled by the engine; this cost is independent of EVM log costs).

---

## 12) Full Worked Examples

### A) Minimal

```json
"payload": { "AmountA": {"optional": false}, "AmountB": {"optional": false} },
"rules":   [ "[AmountA] > 0" ],
"onValid": { "payload": {"amount": "[AmountA]"} }
```

- Base: `10,000`
- Payload: `2 × 1,000 = 2,000` → **12,000**
- Rules: `[AmountA] > 0` → `1,200 + 600 + 250 = 2,050` → **14,050**
- Outcome: `"amount": "[AmountA]"` → `400 + 250 = 650` → **14,700**

### B) Mid (with one contract read)

```json
"payload": { "User": {"optional": false},
             "AmountA": {"optional": false},
             "AmountB": {"optional": false} },
"contractReads": [{
  "to": "0x…0001",
  "function": "balanceOf(address) returns (uint256)",
  "args": ["[User]"],
  "saveAs": "BalanceA",
  "defaults": 0
}],
"rules": [ "[AmountA] > 0", "[BalanceA] >= [AmountA]" ],
"onValid": { "payload": {"net": "[AmountA] - [AmountB]"} }
```

- Base: `10,000`
- Payload: `3 × 1,000 = 3,000` → **13,000**
- Rules: `2,050 + 2,300 = 4,350` → **17,350**
- Read total: `6,000 + 600 + 250 + 400 + 250 = 7,500` → **24,850**
- Outcome expr `"net"`: `400 + 2×250 + 600 + 600 = 2,100` → **26,950**

### C) Advanced (API + regex + execution + encryptLogs)

```json
"payload": { "User": {"optional": false},
             "AmountA": {"optional": false},
             "Memo": {"optional": true} },
"apiCalls": [{
  "name": "q",
  "method": "GET",
  "urlTemplate": "https://api/x?u=[User]&q=[Query]",
  "contentType": "json",
  "extractMap": {
    "q.symbol": "resp.quote.symbol",
    "q.price":  "double(resp.quote.price.value)",
    "q.ok":     "resp.message.matches('^OK$')"
  },
  "defaults": {"q.price": 0}
}],
"rules": [
  "[q.price] > 0",
  "string([Memo]).matches('^INV-\d+$')",
  "[q.symbol] == 'AAPL'"
],
"onValid": {
  "encryptLogs": true,
  "payload": {
    "note": "ID-[User]",
    "net":  "[AmountA] - [q.price]"
  },
  "execution": {
    "to": "0x…0003",
    "function": "transfer(address,uint256)",
    "args": ["[User]", "[AmountA]"],
    "value": "0",
    "gas": {"limit": 150000}
  }
}
```

- Base: `10,000`
- Payload: `2 × 1,000 + 1 × 200 = 2,200` → **12,200**
- Rules:  
  - `[q.price] > 0` → `1,200 + 600 + 250 = 2,050`  
  - `string([Memo]).matches('^INV-\d+$')` → `1,200 + 2×800 + 250 + 4,000 = 7,050`  
  - `[q.symbol] == 'AAPL'` → `1,200 + 600 + 250 = 2,050`  
  ⇒ **11,150** → **23,350**
- API call total: **15,000** → **38,350**
- Outcome payload:  
  - `"note": "ID-[User]"` → `400 + 250 = 650`  
  - `"net": "[AmountA] - [q.price]"` → `400 + 2×250 + 600 + 600 = 2,100`  
  ⇒ **2,750** → **41,100**
- Execution prep: `1,200 + (2×700) + (2×250) + 800 = 3,900` → **45,000**
- Encrypted logs: `+2,000` → **47,000**

> The on‑chain `transfer(...)` then consumes **EVM gas** independently from the 47,000 Validation Gas above.

---

## 13) What We Do **Not** Price

- Sleep/delays (`waitMs`, `waitUntilMs`)
- Purely presentational fields
- The on‑chain EVM cost of any transaction executed later (that is EVM gas, priced by the chain)
- Anything not directly exercised by the engine during validation/preparation

---

## 14) Errors & Edge Cases (Shortlist)

- Rule parsing/evaluation errors (CEL) → surfaced by the engine
- Contract read ABI mismatches, missing defaults, invalid addresses
- API timeouts/HTTP errors/size limits, invalid JSON or extracts
- Execution target invalid, ABI mismatch, negative/invalid `value`

Validation Gas is **best‑effort**. Engine errors still prevail and abort as per the spec.

---

## 15) Implementation Notes

- **Template vs Expression** in outcomes mirrors engine logic:  
  - *Only placeholders* → direct substitution (no CEL)  
  - *Operators/functions outside `[...]`* → rewrite to CEL and evaluate
- **Expressions everywhere** (read args, API extracts, execution args/value) are rewritten to CEL and evaluated over the current variable context.
- **Regex detector**: by default this guide assumes both `matches(` (CEL/RE2) **and** `regex(` (custom helper) trigger the surcharge; tune if your environment only supports `matches(`.

---

## 16) FAQ

**Does Validation Gas affect on‑chain gas?**  
No. It’s an **engine‑side** heuristic only. The EVM charges gas for the actual transaction independently.

**Are string helpers like `startsWith`, `endsWith`, `contains`, `length` priced?**  
Yes, **generically** as function calls. The heuristic doesn’t hard‑code function names; it simply counts `Name(` tokens (also in method form).

**Why a regex surcharge?**  
Regex evaluation (CEL/RE2) is more expensive than simple arithmetic or comparisons, so expressions with `matches(` (and, in the current build, `regex(`) carry an extra cost.

---

## 17) One‑Line Formula (Simplified)

```
ValidationGas =
  gBase
+ Σ(required) × gPerRequiredInput
+ Σ(optional) × gPerOptionalInput
+ Σ_rules [ gPerRuleBase + ops×gPerOp + funcs×gPerFunc + placeholders×gPerPlaceholder
            + (hasRegex ? gRegexSurcharge : 0) ]
+ Σ_reads [ gPerReadBase + #args×gPerReadArg
           + Σ_argComplexity(ops,funcs,placeholders)
           + #save×gPerReadSave + #defaults×gPerReadDefault ]
+ Σ_api   [ gPerAPICallBase + #url/bodyPlaceholders×gPerAPIPlaceholder
           + Σ_extracts ( gPerAPIExtract + ops×gPerAPIExtractOp + funcs×gPerAPIExtractFunc
                          + (hasRegex ? gAPIMatchesSurcharge : 0) ) ]
+ Σ_outcomeKeys [ gPerOutcomeKey + placeholders×gPerPlaceholder
                  + (isExpr ? (gPerOutcomeExpr + ops×gPerOp + funcs×gPerFunc
                               + (hasRegex ? gRegexSurcharge : 0)) : 0) ]
+ (hasExecution ? gPerExecBase + #args×gPerExecArg + Σ_argComplexity + (hasValue ? gPerExecValue + valueComplexity : 0) : 0)
+ (encryptLogs ? gPerEncryptLogs : 0)

```

---

**Version:** v0.2 (heuristic) · **Status:** production‑lean, adjustable via constants · **Ownership:** XDaLa Engine Team
