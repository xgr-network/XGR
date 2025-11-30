# XRC-137 Expression Evaluation — Developer Guide

## 1) What Expression Evaluation Is Used For
Expression evaluation in **XRC-137** powers decisioning and data transformation inside a single XRC-137 flow. You use the same concise expression language in these places:

- **Rules**: Gate logic for XRC-137 flows. Each rule must evaluate to `true` to follow the valid branch.  
- **API response extraction (`extractMap`)**: Build scalar values from JSON HTTP responses.  
- **Execution parameters**: Compute `args`, `gas.limitExpr`, and `valueExpr` right before contract calls.  
- **Output payload mapping**: Fill outgoing payload fields either by direct placeholders or with expressions.

**Scope:** This guide applies exclusively to **XRC-137**. Other standards such as XRC-729 (orchestrations) are out of scope and documented separately.

This uniformity keeps authoring simple while allowing rich logic everywhere.

---

## 2) Language Overview
**Base syntax** (CEL):
- Operators: `+ - * / %`, comparisons `== != < <= > >=`, logical `&& || !`, ternary `cond ? a : b`.
- Access: `obj.field`, `map["key"]`, `list[0]`.
- Casts: `double(x)`, `int(x)`, `string(x)`, `bool(x)`.

**Collection macros** (on lists):
- `list.map(x, expr)`, `list.filter(x, predicate)`
- `list.exists(x, predicate)`, `list.exists_one(x, predicate)`, `list.all(x, predicate)`

**XGR helper functions**:
- `max(list)`, `min(list)`, `sum(list)`, `avg(list)`, `join(list, sep)`, `unique(list)`

**Variables by context**:
- In `extractMap`: single variable `resp` (parsed JSON).  
- In rules, args, gas/value expressions, and output mappings: your declared payload keys (without brackets) plus any extracted aliases (e.g., `q.*`).

---

## 3) Placeholder Syntax and Rewriting
Author rules and mappings using **square-bracket placeholders** for inputs:

- `[Amount] > 1000`
- `[RecipientIBAN].startsWith('GH') == true`

At evaluation time, the engine rewrites placeholders to CEL identifiers and normalizes string quotes (`'…'` → `"…"`). You may combine placeholders with normal CEL calls and operators.

**Template-only strings**: In output payloads, a string that contains **only placeholders and literal text** (no operators) is treated as simple placeholder substitution. Any arithmetic or function call turns it into a real expression.

---

## 4) Evaluation Semantics
### 4.1 Rule evaluation (boolean)
- Each rule is compiled and cached.  
- Missing required input keys cause that rule to yield `false` (no exception), so the invalid branch is taken.  
- Each rule must return a boolean; non-boolean results are rejected.  
- Expression length limit: **1024 chars**; per-expression timeout is tight (tens of ms) to keep flows deterministic.

### 4.2 Extracting from HTTP JSON (`extractMap`)
- `resp` exposes the parsed JSON body (array root allowed).  
- Extract expressions **must produce scalars** (`string|number|bool|int`). Reduce arrays/objects first (e.g., with `max`, `map/filter`, indexing).  
- On evaluation error of an individual extract, the engine uses the configured `defaults[alias]` if present.

### 4.3 Execution-time expressions
- **Arguments**: Each entry in `args` is evaluated, then cast to the destination ABI type.  
- **Gas**: `gas.limitExpr` (if present) overrides `gas.limit`; then the result is capped by `gas.cap`.  
- **Value**: `valueExpr` yields the transaction value (Wei, integer ≥ 0).

### 4.4 Output payload mapping
- `"[Key]"` → direct copy.  
- Plain string with placeholders only → simple substitution.  
- Otherwise → full expression (same environment as rules).

---

## 5) Evaluation Environment (Built‑ins)
Expressions execute in a CEL environment with:

- **Dynamic variables** for your inputs (`rules/args/gas/value/output`).  
- A single **`resp`** variable for API extraction.  
- Helper functions (numeric reducers & list utilities) purposely **only on `list<dyn>`** to avoid type-overload ambiguity: `max`, `min`, `sum`, `avg`, `join`, `unique`.

Numeric coercions are permissive: numbers and numeric strings are accepted by reducers after conversion; non-numeric elements cause the reducer to return default values or errors depending on context. Keep extracts tight to avoid surprises.

---

## 6) Limits, Determinism & Performance
- **Length**: 1024 characters per expression.  
- **Timeouts**: Sub-100 ms evaluation windows; API calls have their own network timeouts (seconds) but **expressions themselves are quick**.  
- **Caching**: Compiled programs are cached by normalized expression text to avoid repeated compilation costs.  
- **Determinism**: No time- or network-dependent functions are available inside expressions; only provided inputs/`resp` are visible.

---

## 7) Error Handling
Typical failures and how they surface:

- **Too long** → authoring error (reject at preflight).  
- **Missing keys (rules)** → rule evaluates to `false` (no exception).  
- **Non-boolean rule result** → hard error.  
- **Extract result not scalar** → error; reduce first.  
- **No defaults when an extract fails** → error.  
- **ABI cast failures / bad function signature / zero gas with `to`** → execution error.  

---

## 8) Examples
### 8.1 Rule basics
```cel
[SenderCountry] == 'DE'               // true when input has SenderCountry: "DE"
[Amount] > 1000                       // numeric comparison
[RecipientIBAN].startsWith('GH') == true
[AmountA] + [AmountB] > [AmountC] - [AmountD]
```

### 8.2 API extract basics
```json
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
    "q.ask":    "double(resp.quote.ask.value)",
    "q.ts":     "int(resp.quote.meta.ts)",
    "q.venue_best_px":   "max(resp.quote.venues.map(v, double(v.price.value)))",
    "q.venue_best_name": "resp.quote.venues.filter(v, double(v.price.value) == max(resp.quote.venues.map(x, double(x.price.value)))).map(v, v.name)[0]"
  },
  "defaults": {"q.price":0, "q.bid":0, "q.ask":0}
}
```

### 8.3 Full mini‑flow snippet
```json
{
  "payload": {
    "AmountA": {"type":"number","optional":false},
    "AmountB": {"type":"number","optional":false}
  },
  "apiCalls": [ { /* see 8.2 */ } ],
  "rules": [
    "[AmountA] > 0",
    "[AmountB] > 0",
    "[q.price] > 0"
  ],
  "onValid": {
    "params": {"payload": {
      "AmountA": "[AmountA]-[AmountB]",
      "AmountB": "[AmountB]",
      "fromApi": "[q.symbol]"
    }},
    "execution": {
      "to": "0x7863b2E0Cb04102bc3758C8A70aC88512B46477C",
      "function": "setMessage(string)",
      "args": ["string([AmountA])"],
      "gas": {"limitExpr":"220000 + 50000", "cap":220000}
    }
  }
}
```

---

## 9) Authoring Guidelines
- Keep expressions short; precompute in API or payload when possible.  
- Reduce arrays/objects to scalars in extraction using `map`/`filter` + `max`/`min` or explicit indexing.  
- Prefer safe defaults for extracts that can fail (`defaults`).  
- Keep alias names stable and descriptive (e.g., `quote.price`, `fx.rate`).  
- For deterministic delays, prefer using absolute epoch values where supported (e.g., `waitUntilMs`).

---

## 10) Quick Reference
- **Placeholders**: `[Key]` → input key.  
- **String quoting**: use `'...'` or `"..."` in authoring; engine normalizes to proper string literals.  
- **Numbers**: `double()`, `int()` casts; reducers accept numeric-like strings.  
- **Lists**: `map`, `filter`, `exists`, `all`, `unique`, plus reducers.

---

*End of guide.*

