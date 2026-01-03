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


## 6. Type coercion before CEL evaluation

Before CEL evaluation, the engine normalizes scalar values so CEL sees stable types:

- `json.Number` is converted to `int64`, `uint64`, or `float64` when possible.
- numeric strings like `"123"` are converted to `int64/uint64/float64` where lossless.
- nested maps/slices are recursively normalized.

This reduces accidental “string math” and decreases the likelihood of CEL overload errors.

---

## 7. CEL environment and supported helper functions

The CEL environment includes:

### Variables
- `resp` (only used for API extraction contexts): dynamic type (`dyn`)

### Helper functions (XGR extensions)
- `pow(a, b)` → power function (dynamic numeric)
- `max(list<dyn>)`, `min(list<dyn>)`, `sum(list<dyn>)`, `avg(list<dyn>)`
- `join(list<dyn>, sep)` → string join (items are converted to string)
- `unique(list<dyn>)` → de-duplicate (stable order)
- `u256(x)` → parses/constructs an unsigned 256-bit integer (returns dynamic big-int compatible value)
- `int64(x)`, `uint64(x)`, `uint256(x)` → strict casts with overflow checks

CEL built-ins remain available (e.g., `string(x)`, `double(x)`, `bool(x)`), including regex matching via `matches`.

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
- Normalize inputs (avoid numeric strings; rely on defaults or proper typing).
- Use explicit casts in expressions, e.g.:
  - `int64([A]) >= 60`
  - `double(resp.x) > 0.0`

### 9.2 Missing keys
- In **rules**: missing keys → expression evaluates as false (invalid).
- In **outcome/execution**: missing keys → `ErrSoftInvalid` (branch downgrade or meta-only).

Mitigation: ensure the value is produced earlier (payload, contract read, API extract, previous outcome) or
provide a default at the input level.

### 9.3 Placeholder vs index confusion
- `[0]` is **not** a placeholder.
- To index, use CEL indexing on an identifier, e.g. `Names[0]` or `resp.items[0]`.

---

## 10. Best practices

- Keep expressions short and readable; prefer saved intermediate values over deeply nested comprehensions.
- Use explicit casts when consuming API data (`double()`, `int64()`) to avoid overload ambiguity.
- Do not rely on runtime timing; design with hard caps in mind (lists are capped at 64).
- If a value is meant to be computed (arithmetic/comparison), write it as an **Expression**, not a template.

---

## 11. Compatibility notes

This specification assumes:
- deterministic evaluation without timeouts
- strict placeholder grammar (`[Identifier]` only)
- deterministic hard caps applied uniformly

If the caps or helper functions are changed, the protocol documentation must be updated accordingly.
