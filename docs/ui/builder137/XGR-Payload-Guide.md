# XGR Payload (UI Guide)

This guide shows how to define **Payload fields** in the XRC‑137 Builder and how those fields are reused via **autocomplete** across Rules, API, and Contract Reads. It follows the same structure and tone as the Rules guide.

---

## 1) What Payload does

**Payload** defines the **input fields** your workflow expects at runtime. These fields are later available as **placeholders** `[key]` everywhere in the builder (Rules, API extracts/expressions, Contract Reads aliases, and outcomes).

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/payload-panel-main.png) — The Payload panel with a table of fields and a “+ Field” button.

---

## 2) Add a field

Each row has three controls:

1) **Name** — the placeholder name you will use later as `[name]`  
2) **Type** — one of `string`, `number`, `boolean`, `not set` (for better UX and operator hints)  
3) **Optional** — if off, the engine requires this field at runtime (see section 6)

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/payload-row-editor.png) — A single payload row: inputs for *Name*, *Type* (dropdown), and an *Optional* toggle.

**Tips**  
- Choose short, meaningful names: `amount`, `iban`, `country`, `age`.
- Pick the most natural **type**. It helps the editor suggest the right operators later (e.g., numeric comparisons).

---

## 3) Naming rules (case‑sensitive)

Payload keys are **case‑sensitive** and must be unique **by exact spelling**. The UI enforces a safe pattern and prevents accidental whitespace.

**Allowed pattern**  
`^[A-Za-z][A-Za-z0-9]{0,127}$`  
- must start with a letter  
- letters, digits 
- max length 128

**Duplicates**  
If you enter the **same spelling** twice (e.g., `Amount` twice), the UI shows **“duplicate key (ignored on export)”** and **only the first occurrence** is exported. Different spellings (e.g., `Amount` vs. `amount`) are considered **different keys**.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/payload-duplicate-warning.png) — A row with the red “duplicate key (ignored on export)” hint. A note below the list explains that only the first is exported.

---

## 4) How placeholders work

Anywhere the editor accepts placeholders, type `[` to open **autocomplete**. You can insert any of these, depending on what exists in your model:

- **Payload keys** (this panel)  
- **Contract Reads** saved as `saveAs` aliases  
- **API extracts** defined in the API panel

**Syntax**  
Write a placeholder as `[name]`, e.g., `[amount]`, `[country]`.  
To show a literal `[` or `]` inside a string, use escapes: `[[` and `]]`.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/payload-autocomplete.png) — Typing `[` opens a suggestion list with current payload keys and other producers; Enter to accept, Esc to close.

---

## 5) Where you will reuse Payload fields

You can (and should) reuse payload keys across the builder:

- **Rules**: compare `[amount] >= 100`, `[country] == "DE"`, etc.  
- **API panel**: build extracts and RHS expressions referencing `[amount]`.  
- **Contract Reads**: pass values or compare against aliases you saved.  
- **Outcomes**: set output fields, e.g. `{"x2": "[amount] + 5"}`.

---

## 6) Required vs. Optional (runtime behavior)

At runtime the engine checks **required** payload fields:

- If a field is **required** and **missing/empty**, the step becomes **invalid** and the workflow continues via **onInvalid**.  
- “Empty” means: `null`, empty string `""`, or empty arrays/maps. `0` is **not** empty.  
- Optional fields may be missing — they won’t block execution.

> This keeps flows robust: you can branch on missing inputs and respond accordingly.

---

## 7) Examples

**A) Minimal payload**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/payload-minimal.png)

```json
 "payload": {
    "amount": {
      "optional": true,
      "type": "number"
    },
    "name": {
      "optional": false,
      "type": "string"
    }
```

**B) Using placeholders in Rules**  
```
[amount] >= 100 && ([country] == "DE" || [country] == "AT")
```

**C) Using placeholders in outcome (computed value)**  
```json
"onValid": {
  "payload": {
    "x2": "[amount] + 5"
  }
}
```

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/payload-examples.png) — Three cards showing the examples above.

---

## 8) Common mistakes & quick fixes

- **wrong name** (exact same spelling) → remove one; only the first is exported.
For the Payload field, only the following characters are allowed: /^[A-Za-z][A-Za-z0-9]*$/; maximum length is 128.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/payload-troubleshooting.png) 

---

## 9) Next steps

With your payload defined and referenced via `[key]`, continue with:

- Authoring **Rules** (row editor or advanced CEL)  
- Configuring **API extracts** and **Contract Reads** aliases  
- Building **onValid / onInvalid** outcomes


