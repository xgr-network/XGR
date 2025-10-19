# XGR Rules (UI Guide)

This guide explains how to build **Rules** in the XRC‑137 Builder so they match the engine 1:1. It shows the row editor, the advanced textarea editor, placeholder usage, operators, validation, examples, and quick fixes. Screenshot placeholders like `![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-panel-main.png)` are included for your `docs.html` to replace later.

---

## 1) What Rules do

Rules are **boolean CEL expressions** evaluated after Contract Reads and API Calls. **All rules must be `true`** for the workflow to continue into the **onValid** branch; otherwise the **onInvalid** branch is taken.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-panel-main.png)
**What to show:** The Rules panel with at least two rows and the “+ Rule” button visible.
  - Example rows:
    • `[country] == "DE"`
    • `[amount] >= 100`
  - Size: ~1400×280 px (wide, low height).

---

## 2) Two ways to author a rule

### 2.1 Row editor (guided)
Use the three inputs in a row:
1) **Left**: a placeholder or a literal (e.g. `[country]` or `42`)
2) **Operator**: `==`, `!=`, `>`, `>=`, `<`, `<=`, `contains`, `startsWith`, `endsWith`
3) **Right**: a placeholder or a literal (e.g. `"DE"` or `[minAge]`)

The row editor composes a valid CEL expression for you.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-row-editor.png)
**What to show:** Close-up of a single rule row (left input, operator dropdown, right input).
  - Example: left `[country]`, operator `==`, right `"DE"`.
  - Size: ~1200×160 px.

### 2.2 Advanced editor (free text)
Click the **pencil** icon to open a textarea and type a **full CEL expression** directly, e.g.
```
[amount] >= 100 && ([country] == "DE" || [country] == "AT")
```
Click **OK** to apply.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-advanced-editor.png)
**What to show:** The textarea modal for free-form CEL entry with **OK** and **Cancel** visible.
  - Example text inside: `[amount] >= 100 && ([country] == "DE" || [country] == "AT")`
  - Size: ~900×500 px.

---

## 3) Placeholders `[key]`

You can reference any input produced earlier in the pipeline:

1) **Payload** supplied at runtime  
2) **Contract Reads** via their `saveAs` aliases  
3) **API Calls** via their extract aliases

**Escapes:** use `[[` for `[` and `]]` for `]` inside string literals.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-placeholder-help.png)
**What to show:** A small info popover explaining the three placeholder sources:
  1) Payload at runtime
  2) Contract Reads (saveAs)
  3) API extracts
  - Optionally list 2–3 example keys.
  - Size: ~700×380 px.

---

## 4) Operators & examples

| Operator      | Meaning                         | Example                                  |
|---------------|----------------------------------|-------------------------------------------|
| `==`, `!=`    | equal / not equal               | `[country] == "DE"`                       |
| `>`, `>=`     | greater / greater or equal      | `[amount] >= 100`                         |
| `<`, `<=`     | less / less or equal            | `[age] < 65`                              |
| `contains`    | substring check                  | `[iban].contains("DE")`                   |
| `startsWith`  | string prefix                    | `[iban].startsWith("DE")`                 |
| `endsWith`    | string suffix                    | `[iban].endsWith("00")`                   |
| logical `&&` / `||` | AND / OR                   | `[country] == "DE" && [amount] >= 100`    |
| negation `!`  | NOT                              | `!([blocked] == true)`                    |

> The advanced editor accepts **any valid CEL** the engine supports (e.g. `in` on lists, numeric math, ternary `cond ? a : b`, etc.).

---

## 5) Validation (what the UI enforces)

- Every rule must evaluate to a **boolean** (the UI flags non-boolean expressions).
- Unknown placeholders cause an error: `[key]` must exist in payload / reads / APIs.
- String literals must be quoted `"..."`; numbers are plain (no quotes).  
- The row editor prevents obvious mistakes (e.g. empty operator).  
- The advanced editor still validates on close; errors are shown inline.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-validation-errors.png)
**What to show:** Typical validation problems inside the editor.
  - Example 1: “Unknown placeholder” — left field contains `[unknownKey]`, with an inline error message below.
  - Example 2: “Non-boolean result” — expression missing a comparator (e.g., `[amount]` alone), with error shown.
  - Size: ~1200×260 px.

---

## 6) Examples

### 6.1 Simple equality
```
[country] == "DE"
```

### 6.2 Numeric threshold
```
[amount] >= 100
```

### 6.3 Combined conditions
```
[amount] >= 100 && ([country] == "DE" || [country] == "AT")
```

### 6.4 Using API extracts and read outputs
```
[q.price] > 0 && [token.symbol] == "XGR"
```

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-examples-cards.png)
**What to show:** 3–4 compact example “cards” of valid rules in one screenshot.
  - Layout: a single image showing multiple small cards (side-by-side or stacked).
  - Each card shows a short title and one-line rule:
    1) *Simple equality* — `[country] == "DE"`
    2) *Numeric threshold* — `[amount] >= 100`
    3) *Combined conditions* — `[amount] >= 100 && ([country] == "DE" || [country] == "AT")`
    4) *Using API & reads* — `[q.price] > 0 && [token.symbol] == "XGR"`
  - Optional: a tiny checkmark icon in the corner of each card to indicate “valid” (purely for the doc image).
  - Size: ~1200×500 px; dark theme background.

---

## 7) Common Errors & Quick Fixes

1) **`Unknown placeholder [key]`**  
   **Cause:** The key doesn’t exist at rule time.  
   **Fix:** Ensure the producing read/API precedes rules, or pass it in payload.

2) **`Expression is not boolean`**  
   **Cause:** The expression returns number/string.  
   **Fix:** Compare explicitly (e.g. `[amount] >= 0`) or wrap with a boolean operator.

3) **`String literal missing quotes`**  
   **Cause:** Wrote `DE` instead of `"DE"`.  
   **Fix:** Quote string literals.

4) **Type mismatch in numeric compare**  
   **Cause:** Comparing string to number.  
   **Fix:** Ensure both sides are numeric or cast accordingly.

5) **Invalid operator for type**  
   **Cause:** Using `contains` on a number.  
   **Fix:** Use numeric operators or convert to string first.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-troubleshooting.png)
**What to show:** A two-column list: *Error* → *Quick fix*.
  - Column 1 (Error): e.g. `Unknown placeholder [key]`, `Expression is not boolean`, `String literal missing quotes`.
  - Column 2 (Fix): 1-line actionable tip (e.g. “ensure producing step precedes the rule”, “compare explicitly”, “quote strings with \"…\"”).
  - Styling: lightly separated rows; **no** special green UI hint required (informational only).
  - Size: ~1200×600 px.

---

## 8) Outcome & Next Steps

- If **all rules** evaluate to `true` → **onValid** branch runs.  
- Otherwise → **onInvalid** branch runs.  
- In both branches, you can map a **payload** (top-level `payload`) and optionally schedule an **execution**.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-outcome-branches.png)
**What to show:** A minimal flow diagram “Rules → onValid/onInvalid”.
  - Boxes (left→right):
    • *Inputs available* (Payload, Contract Reads, API extracts) →
    • *Rules (all must be true)* → two arrows:
      – green arrow to *onValid* (bullets under the box: `payload mapping`, `execution (optional)`, `encryptLogs`, `logExpireDays`)
      – neutral/gray arrow to *onInvalid* (same bullets)
  - Footer note in the image: “Rules run after Reads & APIs”.
  - Size: ~1200×450 px.

---

## How to reference screenshots in this guide

Put a single line with the pattern below. Your `docs.html` will replace it with an image:
```
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-panel-main.png)
```
