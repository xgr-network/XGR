# XRC‑137 ValidationGas Specification (Off‑Chain Cost Model)

This document specifies how **ValidationGas** is computed for an XRC‑137 rule and how list comprehensions
(e.g., `map`, `filter`, `exists`, `all`) are priced deterministically using **n·m + overhead**.

ValidationGas is a **billing and resource model for XDaLa off‑chain processing**. It is **not** EVM gas and
does not affect on-chain transaction execution.

---

## 1. What ValidationGas represents

ValidationGas approximates the off‑chain work performed by the engine:

- parsing and evaluating rule expressions (CEL)
- contract reads and save handling
- API calls and response extraction (CEL on `resp`)
- building outcome payloads
- resolving execution parameters (address, args, value)
- optional encryption/log logging overhead
- wait-time related overhead for spawned workflows (join/wait semantics)

The objective is:
- **predictable customer pricing**
- **deterministic, explainable computation**
- alignment with **hard caps** (so estimated work ≈ permitted work)

---

## 2. Key terms

### Common gas vs branch gas
ValidationGas is split into:

- **Common**: paid regardless of branch outcome (payload + rules + reads + API calls + base).
- **Branch extras**:
  - **onValid extra**
  - **onInvalid extra**

Branch extras cover outcome payload mapping, execution resolution, encryption/logs, and wait-time cost.

### Operators, functions, placeholders
Expressions are scored into counts:

- **Operators (ops):** CEL operator functions (e.g., `>=`, `&&`, `+`).
- **Functions (funcs):** CEL function calls (including helper functions and comprehension/macros).
- **Placeholders (ph):** occurrences of `[Identifier]` (only true placeholders; not `[0]`, `["k"]`, …).
- **Regex usage:** detected via `matches(...)` and surcharged.

These counts are multiplied by fixed constants (documented below).

### Comprehension
A **comprehension** is CEL’s internal representation of `map`, `filter`, `exists`, `all` and similar list macros.
Comprehensions can execute work proportional to list length; therefore we price them explicitly as **n·m + overhead**.

---

## 3. Fixed constants (protocol values)

All constants below are **fixed protocol parameters** used by the estimator.

### 3.1 Base and payload inputs

| Constant | Value | Meaning |
|---|---:|---|
| `gBase` | 10,000 | Fixed base cost per rule evaluation (framework overhead). |
| `gPerRequiredInput` | 1,000 | Cost per payload field **without** a default (must be provided). |
| `gPerOptionalInput` | 200 | Cost per payload field **with** a default (engine can proceed without caller value). |

Note: The term “optional” here means “defaulted input”. There is no separate `optional: true/false` flag.

### 3.2 Rule expressions (`rules[]`)

| Constant | Value | Meaning |
|---|---:|---|
| `gPerRuleBase` | 1,200 | Base cost per rule expression entry. |
| `gPerOp` | 600 | Cost per operator occurrence. |
| `gPerFunc` | 800 | Cost per function call occurrence. |
| `gPerPlaceholder` | 250 | Cost per placeholder `[Key]` occurrence. |
| `gRegexSurcharge` | 4,000 | Additional cost if `matches(...)` is used (regex). |

### 3.3 Contract reads

| Constant | Value | Meaning |
|---|---:|---|
| `gPerReadBase` | 6,000 | Base cost per contract read. |
| `gPerReadArg` | 600 | Cost per read argument. |
| `gPerReadSave` | 400 | Cost per saved output field. |
| `gPerReadDefault` | 250 | Extra cost when a saved field defines a default (fallback value handling). |

### 3.4 API calls and extraction

| Constant | Value | Meaning |
|---|---:|---|
| `gPerAPICallBase` | 8,000 | Base cost per API call. |
| `gPerAPIPlaceholder` | 200 | Cost per placeholder occurrence in API templates (URL/body), if used. |
| `gPerAPIExtract` | 600 | Base cost per extract-map entry. |
| `gPerAPIExtractOp` | 500 | Cost per operator occurrence inside an extract expression. |
| `gPerAPIExtractFunc` | 400 | Cost per function call inside an extract expression. |
| `gAPIMatchesSurcharge` | 4,000 | Additional cost if `matches(...)` is used inside extraction. |

### 3.5 Outcomes and execution resolution (branch extras)

| Constant | Value | Meaning |
|---|---:|---|
| `gPerOutcomeKey` | 400 | Base cost per outcome payload key. |
| `gPerOutcomeExpr` | 600 | Extra cost if the value is an expression (not a pure template). |
| `gPerExecBase` | 1,200 | Base cost when an execution block exists (address/ABI setup). |
| `gPerExecArg` | 700 | Base cost per execution argument (regardless of expression complexity). |
| `gPerExecValue` | 800 | Base cost for evaluating and converting `execution.value`. |
| `gPerEncryptLogs` | 2,000 | Extra cost if encrypt/logging is enabled for the branch. |

### 3.6 Wait-time surcharge for spawns

| Constant | Value | Meaning |
|---|---:|---|
| `gWaitGasPerHourPerSpawn` | 100 | Cost per started hour of wait time, per spawned child. |

Wait-time cost uses the formula:

- **WaitGas = ceil(waitSeconds / 3600) · gWaitGasPerHourPerSpawn · spawnCount**

---

## 4. Overall calculation (high level)

ValidationGas is computed as:

**Common**
- `gBase`
- payload fields (required/defaulted)
- rule expressions
- contract reads
- API calls + extraction

**Branch extras (onValid / onInvalid)**
- outcome payload mapping (keys + placeholders + expression costs + regex surcharge)
- execution resolution (base + args + arg expressions + value expression)
- encryption/log overhead (if enabled)
- wait-time surcharge (if configured and spawns exist)

The final per-branch cost is typically reported as:
- `common`
- `common + onValidExtra`
- `common + onInvalidExtra`

---

## 5. Expression scoring and comprehension pricing

### 5.1 Placeholder count
Placeholders are counted strictly as occurrences of `[Identifier]`.

- `[A_out]` counts as 1 placeholder.
- `[0]` counts as 0 placeholders (indexing).
- `["key"]` counts as 0 placeholders.

### 5.2 Operator/function counting
For valid CEL, the estimator parses + type-checks and then counts:
- operator calls (internal CEL operator functions)
- function calls (including helpers)

If parsing/checking fails, the estimator falls back to a conservative token heuristic so the estimator can still
return a number. **Runtime evaluation may still abort** for invalid expressions; therefore valid CEL is required
for production use.

### 5.3 Comprehension pricing: n·m + overhead
Comprehensions are priced as:

- **n**: the list size
  - if the iterated range is a **list literal**, `n = literal length`
  - otherwise (unknown/dynamic), `n = MaxListCap = 64`
- **m**: the cost of the comprehension body
  - cost of `loopCondition + loopStep` (operators + functions) inside the loop
- **overhead**: a fixed surcharge for the comprehension itself

In the estimator, the overhead is modeled as **one additional function call**.

Therefore, the comprehension contributes:

- `cost(iterRange) + overhead + n · cost(loopCondition + loopStep) + cost(result)`

This implements the required **n·m + overhead** rule.

---

## 6. Worked examples for comprehension pricing

The following examples use the constants:

- Rule ops cost: `gPerOp = 600`
- Rule funcs cost: `gPerFunc = 800`
- MaxListCap: `64`

### Example A: fixed list literal
Expression (rule context):
```cel
[1, 2, 3].map(x, x + 1)
```

- iterRange is a list literal of length 3 → `n = 3`
- body contains one operator `+` → `m_ops = 1`, `m_funcs = 0`
- overhead = 1 function call (the comprehension itself)

Loop contribution:
- per-iteration: `1·gPerOp = 600`
- total loop: `n·600 = 3·600 = 1,800`
- overhead: `1·gPerFunc = 800`

So the comprehension contributes at least:
- `1,800 (loop) + 800 (overhead)` plus any additional costs from surrounding calls.

### Example B: dynamic list (capped)
Expression (API extract context):
```cel
resp.items.filter(i, bool(i.active))
```

- iterRange is `resp.items` (dynamic) → `n = MaxListCap = 64`
- body includes one cast `bool(...)` → counted as a function
- overhead = 1 function call

Body cost:
- `m_funcs = 1` → `m = 1·gPerAPIExtractFunc`

Total loop cost scales as:
- `64 · (1·gPerAPIExtractFunc)` plus overhead.

This is intentionally conservative: even if `resp.items` has only 5 entries, the estimator assumes the capped
maximum for billing and DoS safety unless the list size is statically known.

### Example C: nested comprehensions
Expression:
```cel
resp.items.filter(i, i.tags.exists(t, t == "x"))
```

- outer loop: `n_outer = 64`
- inner `exists(...)` is itself a comprehension inside the outer body
- the inner comprehension is priced using the same rule, so the body cost `m` already includes a scaled
  component if the inner iterRange is dynamic

This yields multiplicative growth in the estimate, as intended: nested list processing is expensive.

---

## 7. Regex surcharges

Regex matching via `matches(...)` is surcharged because it is significantly more expensive than simple operators:

- Rule contexts: `+ gRegexSurcharge`
- API extract contexts: `+ gAPIMatchesSurcharge`

Surcharges apply once per expression where regex is detected.

---

## 8. Wait-time surcharge examples

If a branch specifies:
- `waitSec = 4,500` seconds (1.25 hours)
- `spawnCount = 3`

Then:
- `ceil(4500 / 3600) = 2`
- WaitGas = `2 · 100 · 3 = 600`

This surcharge is added to the corresponding branch extra (valid/invalid) depending on where the wait is defined.

---

## 9. Alignment with deterministic hard caps

The runtime evaluator enforces hard caps:
- MaxExprLen = 1024
- MaxAstNodes = 4096
- MaxListCap = 64

The ValidationGas estimator uses the **same list cap value** for comprehension pricing in the worst case.
This keeps estimation and enforcement aligned: customers do not get priced for work that the engine would refuse.

---

## 10. Practical guidance

- Prefer producing intermediate values (payload/API/reads) and use simple rule comparisons.
- Avoid nested comprehensions unless absolutely necessary.
- Use explicit casts (`int64`, `double`, `bool`) in API extracts to avoid overload errors.
- Treat ValidationGas as a customer-visible contract: keep expressions stable and explainable.
