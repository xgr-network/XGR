# XGR Rules (UI Guide)

This guide explains how to build **Rules** in the XRC-137 Builder so they match the engine 1:1. It shows the row editor, the advanced textarea editor, the **Rule Assistant** (snippets & helpers), placeholder usage, operators, validation, examples, and quick fixes.

---

## 1) What Rules do

Rules are **boolean CEL expressions** evaluated after Contract Reads and API Calls. **All rules must be `true`** for the workflow to continue into the **onValid** branch; otherwise the **onInvalid** branch is taken.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-panel-main.png) — The Rules panel with at least two rows and the “+ Rule” button visible. Example rows: `[country] == "DE"`, `[amount] >= 100`.

---

## 2) Two ways to author a rule

### 2.1 Row editor (guided)
Use the three inputs in a row:
1) **Left**: a placeholder or a literal (e.g. `[country]` or `42`)
2) **Operator**: `==`, `!=`, `>`, `>=`, `<`, `<=`, `contains`, `startsWith`, `endsWith`, `matches`, `in`
3) **Right**: a placeholder or a literal (e.g. `"DE"` or `[minAge]`)

The row editor composes a valid CEL expression for you.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-row-editor.png) — Close-up of a single rule row (left input, operator dropdown, right input). Example: left `[country]`, operator `==`, right `"DE"`.

### 2.2 Advanced editor (free text)
Click the **pencil** icon to open a textarea and type a **full CEL expression** directly, e.g.
```
[amount] >= 100 && ([country] == "DE" || [country] == "AT")
```
Click **OK** to apply.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-advanced-editor.png) — The textarea modal for free-form CEL entry with **OK** and **Cancel** visible.

---

## 3) Rule Assistant (snippets & helpers)

Open the advanced editor and click **Assist** to launch the **Rule Assistant**. The assistant:
- is **draggable** (grab the header and move),
- inserts **snippets at the caret** into the textarea,
- documents available **operators**, **helpers**, and **ready-made patterns**,
- reminds you to use `[[` and `]]` inside string literals to render `[` and `]`.

**String operators**
- `contains()`, `startsWith()`, `endsWith()`, `matches()`, `in [list]`

**List & math helpers**
- `max()`, `min()`, `sum()`, `avg()`, `join()`, `unique()`

**Common patterns (one-click snippets)**
- **Threshold** → e.g. `[amount] >= 100`
- **Country in list** → e.g. `[country] in ["DE","AT","CH"]`
- **API + price** → e.g. `[q.price] > 0` and `[q.symbol] == "XGR"`
- **VIP tag** → e.g. `[tags].contains("vip")`

**Keyboard tips**
- Start typing `[` in the textarea to trigger **placeholder suggestions**; picking one replaces only the **current token** (from the last `[` to the caret).
- Use **Enter** to confirm a suggestion, **Esc** to close.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-assistant-modal.png) — The assistant modal (operators, helpers, patterns) with footer **Close** button.  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-assistant-snippet-insert.png) — Caret in the textarea → click `contains()` → snippet inserted at the caret.

---

## 4) Placeholders `[key]`

You can reference any input produced earlier in the pipeline:

1) **Payload** supplied at runtime  
2) **Contract Reads** via their `saveAs` aliases  
3) **API Calls** via their extract aliases

**Escapes:** use `[[` for `[` and `]]` for `]` inside string literals.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-placeholder-help.png) — Info popover explaining the three placeholder sources (2–3 example keys).

---

## 5) Operators & examples

| Operator      | Meaning                         | Example                                  |
|---------------|----------------------------------|-------------------------------------------|
| `==`, `!=`    | equal / not equal               | `[country] == "DE"`                       |
| `>`, `>=`     | greater / greater or equal      | `[amount] >= 100`                         |
| `<`, `<=`     | less / less or equal            | `[age] < 65`                              |
| `contains`    | substring check                  | `[iban].contains("DE")`                   |
| `startsWith`  | string prefix                    | `[iban].startsWith("DE")`                 |
| `endsWith`    | string suffix                    | `[iban].endsWith("00")`                   |
| `matches`     | RE2 regex match                  | `[iban].matches("^DE\\d{2}.*$")`      |
| `in`          | membership in list               | `[country] in ["DE","AT","CH"]`           |
| logical `&&` / `||` | AND / OR                   | `[country] == "DE" && [amount] >= 100`    |
| negation `!`  | NOT                              | `!([blocked] == true)`                    |

> The advanced editor accepts **any valid CEL** the engine supports.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-examples-cards.png) — Four example cards with small “validated” badges.

---

## 6) Validation (what the UI enforces)

- Every rule must evaluate to a **boolean**.  
- Unknown placeholders cause an error.  
- Strings quoted `"..."`; numbers plain.  
- Row editor prevents empty operator; advanced editor validates on close.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-validation-errors.png) — Example messages for “unknown placeholder” and “not boolean”.

---

## 7) Examples

- `[country] == "DE"`  
- `[amount] >= 100`  
- `[amount] >= 100 && ([country] == "DE" || [country] == "AT")`  
- `[q.price] > 0 && [token.symbol] == "XGR"`

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-examples-cards.png) — Same image as above is fine.

---

## 8) Common Errors & Quick Fixes

- **Unknown placeholder** → ensure producer step precedes rules.  
- **Expression not boolean** → compare explicitly or wrap with boolean op.  
- **Missing quotes** → write `"DE"`, not `DE`.  
- **Type mismatch** → numbers vs strings; convert or compare correctly.  
- **Invalid operator for type** → use string helpers for strings, numeric ops for numbers.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-troubleshooting.png) — Two-column list: *Error* → *Quick fix* (3–5 rows).

---

## 9) Outcome & Next Steps

- All `true` → **onValid** branch runs; otherwise **onInvalid**.  
- Both branches may build an output `payload` and optionally schedule an execution.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/rules-outcome-branches.png) — Minimal flow diagram “Rules → onValid / onInvalid”.
