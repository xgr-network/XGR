# XGR / XDaLa Expression Evaluation – Developer Guide

This document specifies how *expressions* and *templates* are evaluated in XRC‑137/XDaLa, including
placeholder handling, CEL integration, deterministic hard caps, type coercion, and error semantics.

The goal is that **the same input always produces the same result and the same cost**, without relying on
wall‑clock timeouts or scheduler‑dependent behavior.

---

## 1. Scope and where expressions appear

Expressions and templates can appear in multiple places:

- **Rule conditions** (`rules[]`): Boolean CEL expressions that decide whether a step is valid.
- **API extraction** (`apiCalls[].extractMap`): CEL expressions that compute values from `resp` (the decoded API response).
- **Outcome payload mapping** (`onValid.payload`, `onInvalid.payload`): values can be templates or expressions.
- **Execution parameters** (`onValid.execution`, `onInvalid.execution`): `to`, `args[].value`, `value.value` may be templates or expressions.

A single central entry point is used for non-rule values:

- **`EvalOrRender`** (engine/xdala): evaluates a *string* either as an **Expression** (CEL) or as a **Template** (placeholder rendering).

Rule evaluation uses:

- **`EvalAllBool`** (engine/expr): evaluates rule expressions (logical AND).

---

## 2. Terminology

### Placeholder
A **placeholder** references a value in the current evaluation environment.

- **Syntax:** `[Identifier]`
- **Identifier grammar:** `[A-Za-z_][A-Za-z0-9_]*`

Only this form is considered a placeholder. The following are **not placeholders** and are left untouched:

- `[0]` (list index)
- `["key"]` / `['key']` (map index)
- `[x + 1]` (arbitrary expression inside brackets)

This strict definition prevents collisions between placeholder syntax and normal CEL indexing.

### Template
A **template** is a string where placeholders are replaced *as text*.

- Evaluation result: **string**
- CEL is **not** executed.

Example:
- Input: `"Hello [Name], amount=[Amount]"`
- Result: `"Hello Alice, amount=12"`

### Expression
An **expression** is a CEL expression (or a bare literal) that is executed via CEL.

- Evaluation result: **typed value** (bool, int64, uint64, float64, string, …)
- Placeholders are allowed, but they are first rewritten to CEL identifiers.

Examples:
- `"[Amount] + 15"`
- `"[A_out] >= 60"`
- `true`
- `"some literal string"` (quoted literal)

### Default
A **default** is a fallback value attached to a **specific key** (payload input field, contract-read save key, or API extract alias).
It does **not** mean “the expression has a default”. It means:

> “This key will have a value available for downstream evaluation even if it cannot be produced from the primary source.”

Defaults and their exact application points differ slightly between payload inputs, contract reads, and API `extractMap` aliases.
See **Section 5.5 (Defaults and when they apply)** for the full, normative behavior.


### Soft-Invalid vs Hard Error
The engine distinguishes between *data incompleteness* and *configuration errors*:

- **Soft-Invalid:** missing required keys/values needed to evaluate a branch payload/execution.
  - Treated as “invalid” (i.e., control flow can downgrade from valid → invalid).
  - Represented by `ErrSoftInvalid`.

- **Hard Error (Abort):** invalid CEL expression, schema violation, type error that prevents evaluation.
  - Treated as a configuration error and aborts the step/session.

Rule evaluation is slightly different: missing keys in rule expressions results in **false** (invalid), not an abort.

---

## 3. Placeholder rewriting and quoting

Before CEL compilation, placeholders are rewritten:

- `[AmountA]` → `AmountA`

Additionally, single-quoted strings are normalized:

- `'hello'` → `"hello"`

This keeps the user‑facing syntax consistent while using standard CEL compilation internally.

---

## 4. Template vs Expression classification

For every string value, the engine must decide:

- **Template** → render placeholders
- **Expression** → evaluate via CEL

The classification rules are:

1. **Bare placeholder**: if the entire trimmed string is exactly `[Key]`, it is an **Expression**
   (typed passthrough).
2. **Pure literal**: `true`, `false`, number literals, and quoted strings are **Expressions**.
3. **Operators / function tokens outside placeholders**: if the string contains strong operator tokens
   (e.g. `* / % ( ) < > ! = | &`) outside placeholders, it is an **Expression**.
4. Otherwise it is a **Template**.

Implications:

- `"memo: [A]"` is a Template (text + placeholder).
- `"[A] >= 60"` is an Expression (operator `>=` outside placeholder).
- `"[A]"` is an Expression and returns the typed value of `A`.

### Why this matters
Templates do **not** execute CEL. If you expect arithmetic, comparisons, list operations, or casts, the value
must be classified as an **Expression**.

### Note on `+` and `-` in mixed text
To avoid treating hyphens in prose as arithmetic, `+` and `-` are only treated as “expression tokens” when they
appear in an obvious arithmetic context. If you write an expression that contains only `+`/`-` as operators,
make it unambiguous by adding parentheses:

- Prefer: `([A_out] + 15)`
- Avoid ambiguous forms inside larger prose strings.

This ensures the value is classified as an **Expression** (CEL) rather than a **Template**.

---

## 5. Evaluation semantics by component

## 5.1 Rule expressions (`rules[]`)
Rules are evaluated with `EvalAllBool`:

- Each rule expression is rewritten (`[Key]` → `Key`).
- **Missing keys** required by the expression: the expression result is treated as **false**.
- CEL parse/check/eval errors: **hard error**.
- The expression must evaluate to `bool`, otherwise it is a hard error.

This yields deterministic behavior: rules never “half succeed”; they are either valid, invalid, or abort.

## 5.2 Outcome payload values (`onValid.payload`, `onInvalid.payload`)
Outcome payload values are evaluated via `EvalOrRender`:

- **Template:** placeholder rendering only → returns string.
- **Expression:** CEL evaluation → returns typed value.
- **Missing keys:** returns `ErrSoftInvalid`, so the step can downgrade to the invalid branch (or become meta‑only).
- CEL errors: **hard error**.

## 5.3 Execution fields (`execution.to`, `args[].value`, `value.value`)
Execution fields are resolved in the same single path:

- Each string is evaluated via `EvalOrRender`.
- `execution.to` must resolve to a valid address string (schema violation otherwise).
- Arguments are cast:
  1. expression/template result → XRC type (`CastToXRCType`)
  2. XRC type → ABI type (for encoding)

Missing keys cause `ErrSoftInvalid` (no abort); CEL errors are hard errors.

## 5.4 API extraction (`resp` expressions)
API extraction expressions are CEL expressions evaluated against the special variable:

- `resp`: decoded response (dynamic type)

No placeholder rewriting is required unless your extraction expression uses `[Key]` (typically it should not).

---

## 5.5 Defaults and when they apply

A default value is always attached to the **key being produced** (the “left-hand key”), never to individual sub-expressions.
The goal is deterministic behavior: downstream evaluation (rules, outcomes, execution) should see either a typed value or a soft-invalid,
but never ambiguous partial results.

### 5.5.1 Payload inputs (caller-provided)
Defaults for payload inputs are applied when constructing the inbound input map:

- If the caller provides the field → that value is used (after type casting).
- If the caller omits the field and a default exists → the default is cast to the declared type and used.
- If the caller omits the field and no default exists → the key is **missing** and can lead to **soft-invalid** if referenced by an expression.

### 5.5.2 Contract reads
Defaults for contract-read save targets apply when the read is materialized into the same input map:

- If the read succeeds → the saved key is written from the read result (after type casting).
- If the read fails and a default exists → the saved key is written from the default (typed).
- If the read fails and no default exists → the saved key is missing and may cause **soft-invalid** downstream.

### 5.5.3 API calls and `extractMap` aliases (important)
For API calls, defaults belong to **extract aliases** (the left-hand keys in `extractMap`).
Because an alias is produced by the extraction pipeline, the default is applied when the alias is **materialized into the inputs map**
(i.e., before rules/outcomes/execution consume it), not “before extraction begins”.

For each alias `AliasX` in `extractMap`:

- If the HTTP request/response processing fails (timeout, non-2xx, decode error, etc.) → **each alias is defaulted independently**
  (if it has a default). If an alias has no default, the step becomes **soft-invalid** (because the key is missing).
- If placeholder substitution inside the extract expression fails due to **missing input keys** → the **alias default** is used
  (if present), otherwise **soft-invalid**.
- If evaluating the extract expression fails (missing `resp.*` path, function/type error, etc.) → the **alias default** is used
  (if present), otherwise **soft-invalid**.
- If casting the extracted value to the declared alias type fails → the **alias default** is used (if present), otherwise **soft-invalid**.

**Crucial:** the default is always for the **alias result as a whole**, not for individual `resp.*` fragments.
So if an extract expression references multiple `resp.*` values and *any* part prevents producing a value, the alias falls back to its default.

Example:

```json
"extractMap": {
  "Ok":    { "type": "bool",   "expr": "bool(resp.ok)",        "default": false },
  "notOk": { "type": "string", "expr": "string(resp.notok)",   "default": "not existing" }
}
```

- If `resp.ok` cannot be evaluated → `Ok` becomes `false`.
- If `resp.notok` cannot be evaluated → `notOk` becomes `"not existing"`.
- If the entire HTTP call fails → both aliases are defaulted (if defaults exist).

### 5.5.4 What defaults do NOT cover (hard errors)
Defaults must not hide authoring/configuration errors. Therefore, defaults do **not** apply to:

- CEL parse/check errors (invalid syntax, invalid expression)
- deterministic hard-cap violations (expression too long, AST too complex, list cap exceeded)
- malformed placeholders (invalid placeholder syntax)

These cases are treated as **hard errors** (abort), not soft-invalid.

---

## 6. Type normalization before CEL evaluation

Before CEL evaluation, the engine normalizes inbound values so CEL sees stable, deterministic scalar types.
The normalization logic is intentionally conservative: it **does not guess schema** and it **does not coerce numeric strings**.

### 6.1 Normative normalization rules

The normalization step (`CoerceMapForCEL`) applies `normalizeScalar` recursively to the full input map:

- **Maps** (`map[string]any`): each value is normalized recursively.
- **Lists** (`[]any`): each element is normalized recursively.
- **`json.Number`**: converted to **`float64`** (CEL `double`).
  - Rationale: schema-level casting should already have produced `int64/uint64` where required.
- **`float32`**: converted to `float64`.
- **`float64`**: kept.
- **Strings**: kept as strings.
  - No numeric string coercion (e.g., `"123"` remains a string).

### 6.2 Implications for authors

- If an API returns numeric strings, you must cast explicitly in CEL: `double(resp.data.amount)`.
- If a payload key is declared as `double/int64/...` in the schema, prefer feeding it typed already.
- Avoid relying on implicit CEL conversions; use explicit casts (`double(x)`, `int64(x)`, etc.) when consuming dynamic inputs.

This approach reduces accidental misinterpretation of strings and makes “no such overload” errors easier to reason about.

---

## 7. CEL environment and supported helper functions

The CEL environment is created via `CreateEnv()` / `CreateEnvWithVars()` and includes:

### 7.1 Variables

- `resp` (API extraction contexts only): dynamic type (`dyn`)
- Rule/outcome/execution variables: injected as `dyn` identifiers (after placeholder rewriting)

### 7.2 Design principles for helper functions

Helper functions are designed with strict protocol constraints:

- **Determinism:** no time, randomness, or host-dependent behavior.
- **Hard-cap friendliness:** list algorithms must be safe under `MaxListCap`.
- **Typed clarity:** prefer returning predictable types; where a `dyn` may return different concrete types,
  it is documented explicitly.
- **Fail-fast on authoring errors:** wrong arity or wrong argument types yield CEL errors (hard error).

### 7.3 Function reference

Below is the normative reference. `dyn` means “CEL dynamic”; `list<dyn>` is a CEL list whose elements are dynamic.

#### 7.3.1 Numeric scalar helpers

##### `abs(x) -> dyn`

- **Purpose:** absolute value.
- **Input:** numeric `dyn` (int/uint/double).
- **Output:** `double`.
- **Errors:**
  - non-numeric input
  - NaN / Infinity

Examples:

```cel
abs(-5)              // 5.0
abs(double(-3.2))    // 3.2
```

##### `pow(a, b) -> dyn`

- **Purpose:** power function (`a^b`).
- **Input:** numeric `dyn`.
- **Output:** `double`.
- **Notes:** if either argument is non-numeric, the function returns `0.0` (not an error). Prefer explicit casts if you want strictness.

Examples:

```cel
pow(2, 10)                 // 1024.0
pow(double([X]), 2)        // square
```

##### `relDiff(a, b) -> dyn`

- **Purpose:** symmetric relative difference between two numeric scalars.
- **Definition:**

  `relDiff(a,b) = abs(a-b) / abs((a+b)/2)`

- **Input:** numeric `dyn`.
- **Output:** `double`.
- **Edge cases:**
  - If `abs((a+b)/2) == 0`:
    - returns `0.0` if `a == b`
    - returns `1e18` otherwise (deterministic “very far”)
- **Errors:** non-numeric input.

Examples:

```cel
relDiff(100.0, 101.0)      // ~0.00995
relDiff(0.0, 0.0)          // 0.0
relDiff(0.0, 1.0)          // 1e18
```

##### `safeDiv(num, den, fallback) -> dyn`

- **Purpose:** safe division that never divides by zero.
- **Behavior:**
  - If `num` or `den` is non-numeric, returns `fallback`.
  - If `den == 0`, returns `fallback`.
  - Else returns `double(num / den)`.
- **Output type:** `dyn`.
  - If division succeeds: `double`.
  - If fallback is returned: the type of `fallback`.
- **Recommendation:** pass a `double` fallback (e.g., `0.0`) if downstream expects numeric results.

Examples:

```cel
safeDiv(10.0, 2.0, 0.0)     // 5.0
safeDiv(10.0, 0.0, 0.0)     // 0.0
safeDiv([X], [Y], 0.0)      // numeric if possible; else 0.0
```

##### `clamp(x, lo, hi) -> dyn`

- **Purpose:** clamp a numeric scalar into a closed interval.
- **Behavior:**
  - Swaps bounds if `lo > hi`.
  - If `x` is non-numeric, returns `x` unchanged.
  - If `lo/hi` are non-numeric, returns `x` unchanged.
  - Else returns `double(x)` clamped to `[lo, hi]`.

Examples:

```cel
clamp(5.0, 0.0, 10.0)      // 5.0
clamp(-1.0, 0.0, 10.0)     // 0.0
clamp(99.0, 0.0, 10.0)     // 10.0
```

#### 7.3.2 Distance and proximity helpers

These helpers make quorum/consensus expressions short and reusable.

##### `dist(metric, a, b) -> dyn`

- **Purpose:** compute a distance between two scalar values under a selected metric.
- **Output:** `double`.
- **Errors:** wrong metric type, unsupported metric, incompatible value types.

Supported `metric` values (case-insensitive):

**Numeric metrics**

- `""` or `"rel"` / `"relative"` / `"reldiff"`
  - symmetric relative difference, identical to `relDiff(a,b)`
- `"abs"` / `"absolute"`
  - `abs(a-b)`

**Equality / string metrics**

- `"eq"` / `"equal"`
  - distance is `0.0` if values are equal, otherwise `1.0` (works for any scalar types that CEL can compare)
- `"hamming"` / `"ham"`
  - normalized Hamming distance (strings only): `diffChars / len`
  - if lengths differ: returns `1e18` (deterministic “very far”)
- `"lev"` / `"levenshtein"`
  - normalized Levenshtein distance (strings only)
  - if max string length > 256: returns `1e18` (hard cap to avoid pathological runtime)

Notes on return range:

- `rel`: `[0, +inf)`
- `abs`: `[0, +inf)`
- `eq`: `{0, 1}`
- `hamming` / `lev`: `[0, 1]` (except the sentinel `1e18` for unsupported cases)

Examples:

```cel
// Numeric
"rel".dist(100.0, 101.0)   // not valid: dist is a function, not a method

dist("rel", 100.0, 101.0)  // ~0.00995

dist("abs", 100.0, 101.0)  // 1.0

// Strings
within("hamming", "ABC", "ABD", 0.0) // false
within("hamming", "ABC", "ABD", 0.34) // true (1/3)
```

##### `within(metric, a, b, tol) -> bool`

- **Purpose:** boolean proximity check: `dist(metric, a, b) <= tol`.
- **Inputs:**
  - `metric`: string
  - `tol`: numeric, must be `>= 0`
- **Errors:** invalid metric, invalid tol, incompatible types.

Examples:

```cel
within("rel", 100.0, 101.0, 0.01)        // true
within("rel", 100.0, 102.0, 0.01)        // false
within("eq", "CB", "CB", 0.0)           // true
within("eq", "CB", "CG", 0.0)           // false
```

#### 7.3.3 List numeric helpers

All list numeric helpers accept `list<dyn>` and are intended for **lists of numeric scalars**.

If the list is empty, contains non-numeric values, or cannot be converted to a numeric slice, these helpers return `0.0`.
This is a deterministic “neutral” value; if you need strict failure, enforce type/shape at the schema level.

##### `max(list)`, `min(list)`, `sum(list)`, `avg(list) -> dyn`

- **Output:** `double`.
- **Notes:** these helpers do not sort unless necessary.

Examples:

```cel
max([1.0, 5.0, 2.0])       // 5.0
avg([1.0, 5.0, 2.0])       // 2.666...
```

##### `median(list) -> dyn`

- **Output:** `double`.
- **Definition:** median of the sorted values.
  - odd N: middle element
  - even N: average of the two middle elements
- **Complexity:** `O(n log n)` but `n <= MaxListCap`.

Examples:

```cel
median([1.0, 9.0, 3.0])          // 3.0
median([1.0, 9.0, 3.0, 7.0])     // (3.0+7.0)/2 = 5.0
```

##### `stdev(list) -> dyn`

- **Output:** `double`.
- **Definition:** population standard deviation.
  - Uses Welford’s algorithm (numerically stable).
  - `stdev([x]) == 0.0`.

Examples:

```cel
stdev([10.0, 10.0, 10.0])     // 0.0
stdev([10.0, 12.0, 8.0])      // > 0
```

##### `cv(list) -> dyn`

- **Output:** `double`.
- **Definition:** coefficient of variation: `stdev(list) / abs(mean(list))`.
- **Edge case:** if mean is `0`, returns `0.0`.

Examples:

```cel
cv([100.0, 101.0, 99.5])      // small number
```

##### `mad(list) -> dyn`

- **Output:** `double`.
- **Definition:** median absolute deviation (unscaled):

  `mad(x) = median( abs(x_i - median(x)) )`

- **Notes:** `mad` is robust to outliers and often preferred for guardrails.

Examples:

```cel
mad([100.0, 101.0, 99.5, 500.0])    // robust vs outlier
```

#### 7.3.4 Quorum and consensus helpers

These helpers implement a **generic quorum / consensus** concept for *scalar values*, parameterized by:

- **k**: minimum size of an agreement set
- **metric**: distance function (`dist`)
- **tol**: tolerance threshold
- **mode**: how the agreement set is selected
- **agg**: how the final representative value is chosen

They are designed for deterministic protocol evaluation (not for research-grade distributed consensus).

##### Definitions used in this protocol

- **Quorum (protocol):** “At least `k` elements in a set are mutually consistent under a metric within tolerance.”
- **Consensus (protocol):** “A deterministic representative value derived from a quorum-selected subset.”

This is deliberately **math-first** (set selection + aggregation), and separate from network consensus.

##### `quorum(values, metric, tol, k) -> bool`
##### `quorum(values, metric, mode, tol, k) -> bool`

- **Purpose:** decide whether a quorum of size `k` exists.
- **Inputs:**
  - `values`: `list<dyn>`
  - `metric`: string (see `dist`)
  - `tol`: numeric, must be `>= 0`
  - `k`: numeric, must be `>= 1` (cast to int)
  - `mode`: optional string
- **Return:** bool.
  - returns `true` if a quorum subset of size >= k is found
  - returns `false` otherwise
- **Hard errors:** invalid arity, invalid types for `metric/mode/tol/k`, non-list `values`.

##### `consensus(values, metric, agg, tol, k) -> dyn`
##### `consensus(values, metric, mode, agg, tol, k) -> dyn`

- **Purpose:** compute a representative value for the selected quorum subset.
- **Return value when quorum is not met:** deterministic `0.0`.
  - Recommendation: guard with `quorum(...)` if `0.0` is ambiguous in your use case.
- **Hard errors:** invalid arity, invalid `metric/mode/agg/tol/k`, non-list `values`, unknown `agg`.

###### Supported `mode` values

- `"ball"` (default)
  - Selects a *center candidate* from the list that maximizes the number of inliers within `tol`.
  - Inlier definition: `dist(metric, center, v) <= tol`.
  - Deterministic tie-break: earliest center in the original list.

- `"pairwise"` or `"clique"`
  - Attempts to find a clique-like subset where **all pairwise distances** are within `tol`.
  - This is a deterministic greedy procedure designed for small lists (`<= MaxListCap`). It is not an NP-hard maximum clique solver.

###### Supported `agg` values

- `"medoid"`
  - Returns an element from the quorum subset that minimizes total distance to the other inliers.
  - Works for numeric and string metrics.

- `"mode"`
  - Returns the most frequent element in the quorum subset.
  - Equality uses a stable string key representation. Use on scalars only.

- `"mean"` (numeric only)
  - Returns the arithmetic mean as `double`.

- `"median"` (numeric only)
  - Returns the median as `double`.

###### Examples

**1) Numeric price feed: 2-of-3 within 1% (relative difference)**

```cel
// Build a list literal. Using raw identifiers (no placeholders) is recommended.
prices = [FetchedCoinbase, FetchedBitstamp, FetchedGecko]

quorum(prices, "rel", 0.01, 2)                 // bool
consensus(prices, "rel", "medoid", 0.01, 2)   // representative price (dyn)
```

**2) Numeric guardrail: reject large jumps vs previous**

```cel
newP = consensus([FetchedCoinbase, FetchedBitstamp, FetchedGecko], "rel", "mean", 0.01, 2)

// If PrevPrice is 0, accept (bootstrapping). Else require <= 20% move.
(PrevPrice == 0.0) || (relDiff(newP, PrevPrice) <= MaxDeltaPct)
```

**3) String agreement: 2-of-3 equal**

```cel
quorum([SourceA, SourceB, SourceC], "eq", 0.0, 2)
consensus([SourceA, SourceB, SourceC], "eq", "mode", 0.0, 2)
```

**4) String similarity: hamming quorum**

```cel
// "ABC" and "ABD" are within tol=0.34, so a 2-of-3 quorum can succeed.
consensus(["ABC", "ABD", "XYZ"], "hamming", "ball", "medoid", 0.34, 2)
```

#### 7.3.5 Misc helpers

##### `join(list<dyn>, sep) -> string`

- Converts each element to string and joins with `sep`.

##### `unique(list<dyn>) -> list<dyn>`

- Stable de-duplication preserving first occurrence order.

##### `u256(x) -> dyn`, `uint256(x) -> dyn`

- Constructs/parses an unsigned 256-bit integer value.
- Use for large constants where CEL int literals would overflow.

##### `int64(x) -> int`, `uint64(x) -> uint`

- Strict casts with overflow checks (hard error if out of range).

---

## 8. Deterministic hard caps (no timeouts)

Time-based execution limits are deliberately avoided because they are nondeterministic under varying load.

Instead, deterministic **hard caps** are enforced:

### 8.1 Max expression length
- **MaxExprLen = 1024 bytes**

If a raw expression exceeds this size, evaluation fails.

### 8.2 Max AST node count
- **MaxAstNodes = 4096 nodes**

The expression is parsed and type-checked; then the checked AST is traversed.
If the node count is above the cap, evaluation fails with “too complex”.

This blocks pathological nested expressions and ensures stable compilation cost.

### 8.3 Max list size cap (deep)
- **MaxListCap = 64 elements**

Before CEL execution, the engine traverses all input values and enforces that any slice/array length does not
exceed the cap (including nested lists).

This cap protects evaluation of list comprehensions (`map`, `filter`, `exists`, `all`) from unbounded runtime work.

### 8.4 Large integer literal short‑circuit
If the expression is a **digits‑only** literal with length ≥ 16 (typical “wei” scale numbers),
it is returned directly (as a string) without CEL execution. This avoids CEL integer limits while keeping the
value convertible to `big.Int` later.

---

## 9. Common failure modes and how to fix them

### 9.1 “no such overload”
CEL reports “no such overload” when an operator/function has no type-compatible implementation.

Typical causes:
- comparing numeric types to strings (`[A] >= "60"`)
- doing arithmetic on strings (`"12" + 3`)
- mixing `int`/`uint`/`double` in a way CEL cannot implicitly reconcile

Mitigations:
- Do not rely on numeric string coercion (it is intentionally not performed).
- Use explicit casts in expressions, e.g.:
  - `int64([A]) >= 60`
  - `double(resp.x) > 0.0`
- When building lists, keep them type-homogeneous:
  - good: `[FetchedA, FetchedB, FetchedC]` (all doubles)
  - bad: `[FetchedA, "93000", FetchedC]` (mix string + double)

### 9.2 Metric / quorum errors
Common errors for distance / quorum functions:

- `metric must be string`: you passed a non-string metric.
- `tol must be >= 0`: tolerance is missing, non-numeric, or negative.
- `k must be >= 1`: quorum size invalid.
- `metric expects numeric`: you used a numeric metric (`rel`/`abs`) on non-numeric values.

Mitigation: enforce correct types at the schema layer, and keep metric selection explicit.

### 9.3 Missing keys
- In **rules**: missing keys → expression evaluates as false (invalid).
- In **outcome/execution**: missing keys → `ErrSoftInvalid` (branch downgrade or meta-only).

Mitigation: ensure the value is produced earlier (payload, contract read, API extract, previous outcome) or
provide a default at the input level.

### 9.4 Placeholder vs index confusion
- `[0]` is **not** a placeholder.
- To index, use CEL indexing on an identifier, e.g. `Names[0]` or `resp.items[0]`.

---

## 10. Best practices

- Keep expressions short and readable; prefer saved intermediate values over deeply nested ternary chains.
- Use explicit casts when consuming API data (`double()`, `int64()`) to avoid overload ambiguity.
- Prefer the quorum/consensus helpers over hand-written 2000-character expressions.
- Always design with hard caps in mind (lists are capped at 64, Levenshtein is capped to 256-char strings).
- If a value is meant to be computed (arithmetic/comparison), write it as an **Expression**, not a template.

---

## 11. Compatibility notes

This specification assumes:
- deterministic evaluation without timeouts
- strict placeholder grammar (`[Identifier]` only)
- deterministic hard caps applied uniformly

If the caps or helper functions are changed, the protocol documentation must be updated accordingly.
