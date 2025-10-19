# XGR Contract Reads (UI Guide)

This guide explains how to configure **on‑chain Contract Reads** in the **XRC‑137 Builder** UI in a way that exactly matches the engine (parser + reads executor). It covers **function signatures**, **args**, **saveAs**, **defaults**, optional **rpc**, and **validation**. Screenshot placeholders like `![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-modal.png)` are included for your `docs.html` replacement step.

---

## 1) What a Contract Read is

A Contract Read calls a **view/pure function** on an EVM‑compatible chain and maps the returned tuple into your rule inputs via **`saveAs`**. Reads run **before** API Calls, so their outputs are available as placeholders in APIs.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-panel-main.png) — the Contract Reads panel with one configured row and “Add Read” button.

---

## 2) Fields in the UI (engine‑aligned)

| Field          | Type                   | Required | Notes                                                                                             |
|----------------|------------------------|----------|---------------------------------------------------------------------------------------------------|
| **To**         | address (0x…40 hex)    | yes      | Contract address.                                                                                 |
| **Function**   | signature string       | yes      | `name(type1,type2,…) returns (ret1,ret2,…)`                                                       |
| **Args**       | array of literals/`[key]` | yes  | One value per input type; `[key]` placeholders allowed.                                           |
| **saveAs**     | string \| map          | yes      | **String** ⇒ index `0`; **Map** ⇒ `{ "0": "Key0", "1": "Key1" }`                                  |
| **Defaults**   | scalar \| map          | no       | Used when the call or specific output fails; map keys may be **indices** or **alias names**.      |
| **RPC**        | string (HTTPS)         | no       | **Per‑read** RPC override; must target an **EVM‑compatible** chain endpoint.                      |

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-modal.png) — the “Edit Contract Read” modal with all fields and validation hints.

---

## 3) Function signature & args

- Signature form: `myFn(address,bytes32) returns (string,uint64)`
- **Args** count must match the number of input types.
- Placeholders `[key]` are allowed (from payload, prior reads, or prior APIs).

- **No inputs?** Leave the **Input types** empty in the Signature Helper. The preview will show `myFn() returns (...)`. In JSON, provide `"args": []`.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-signature-helper-no-inputs.png) — helper modal with empty inputs and correct preview.
- Literals must match ABI types. The UI validates strictly:

**Integer** (`uint*`/`int*`)  
- Decimal strings only, within the type range (validated with big‑int range logic).  
- When exporting, small integers are converted to JSON numbers; very big integers stay as strings to preserve precision.

**Address** (`address`)  
- `0x` + 40 hex chars.

**Bytes32** (`bytes32`)  
- `0x` + 64 hex chars.  
- Quick insert: use a zero value like `0x` + 64×`0` if needed.

**String / Bytes** (`string`/`bytes`)  
- Any string literal.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-args-validators.png) — input fields with green/red statuses by type.

---

## 4) Mapping results with `saveAs`

- **Single** return value: set `saveAs` to a **string** (alias). This maps **index 0**.  
- **Multiple** return values: use a **map** of **index → alias**, e.g. `{ "0": "price", "1": "ts" }`.
- Aliases must match: `^[A-Za-z][A-Za-z0-9._-]{0,63}$` and be unique within the rule.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-saveas.png) — table mapping tuple indices to aliases with “add target” button.

---

## 5) Defaults (fallbacks)

- Optional. Used **only** when a call fails or a specific output is missing/out‑of‑range.
- Forms:
  - **Scalar** (only when `saveAs` is a string for index `0`)
  - **Map** with keys as **indices** (`"0"`, `"1"`, …) **or alias names** (`"price"`, …)
- The UI normalizes defaults to correct JSON types on export:
  - Integer outputs → numbers when safe; otherwise keep as strings
  - Bool outputs → `true`/`false`
  - Address/bytes32 → hex strings
  - String/bytes → strings

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-defaults.png) — examples showing scalar vs. map defaults and type‑aware normalization.

---

## 6) RPC (optional, EVM‑compatible)

- You can override the RPC endpoint **per read**.  
- Must be **HTTPS** and point to an **EVM‑compatible** chain.  
- If omitted, the engine’s default RPC is used.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-rpc-field.png) — the RPC input with a small info tooltip “EVM‑compatible only”.

---

## 7) Placeholders `[key]` in args

Where do placeholders get their values? From the merged inputs available at that point:

1) Payload keys supplied at run time  
2) Previously saved read outputs (`saveAs`)  
3) Previously extracted API values (if any API calls precede this read — uncommon; usually reads come first)

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-placeholders-help.png) — tooltip showing the three sources of inputs.

---

## 8) Validation (what the UI enforces)

- **To** is a valid `0x` address (40 hex).  
- **Function** has `name(…) returns (…)`.  
- **Args** count matches ABI inputs; each literal matches its ABI type; placeholders are always allowed.  
- **saveAs** present: string (index 0) or map of index→alias; alias regex enforced; no duplicate indices/aliases.  
- **Defaults** optional; shape checked (scalar or map).  
- **RPC** optional string; HTTPS required in enterprise environments.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-validation-errors.png) — errors for out‑of‑range integer, invalid bytes32, and duplicate alias.

---

## 9) Examples

### 9.1 Single return (string), `saveAs` as string + scalar default
```json
{
  "to": "0x1111111111111111111111111111111111111111",
  "function": "symbol() returns (string)",
  "args": [],
  "saveAs": "sym",
  "defaults": ""
}
```

### 9.2 Multiple returns (string, uint64), `saveAs` map + typed defaults
```json
{
  "to": "0x2222222222222222222222222222222222222222",
  "function": "getData(string,bytes32) returns (string,uint64)",
  "args": ["[user.input]", "0x0000000000000000000000000000000000000000000000000000000000000000"],
  "saveAs": { "0": "name", "1": "version" },
  "defaults": { "0": "", "1": 0 },
  "rpc": "https://rpc.example.org"
}
```

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-examples-cards.png) — two cards with the JSON examples and a “validated” badge.

---

## 10) Tips & Troubleshooting

- If args don’t validate, first check the **function signature** and ABI types.  
- Use placeholders to reduce hard‑coded literals.  
- For large integers (beyond `Number.MAX_SAFE_INTEGER`), keep defaults as **strings**; the engine can parse them.  
- If a read fails but you have defaults, only the **missing** outputs will take defaults.

**PNG proposal**
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-troubleshooting.png) — typical validation hints for signatures and args.


---

## 11) Common Errors & Quick Fixes

> The UI validates most issues early; this checklist helps when a read still fails at runtime.

1) **`Function signature required` / bad format**  
   **Cause:** Missing `name(…) returns ( … )`.  
   **To fix:** Use full signature, e.g. `getData(address,bytes32) returns (string,uint64)`.

2) **`Args length mismatch`**  
   **Cause:** Provided args don’t match ABI input arity.  
   **To fix:** Add/remove args to match exactly.

3) **Type mismatch (uint*/int*)**  
   **Cause:** Non-decimal or out-of-range integer.  
   **To fix:** Enter decimal digits only; for very large integers, keep as string and let the engine parse.

4) **Type mismatch (bytes32/address)**  
   **Cause:** Wrong hex length or missing `0x`.  
   **To fix:** Use `0x` + **64** hex for bytes32 or **40** hex for address. Use the “insert zero bytes32” helper.

5) **`saveAs missing / duplicate index / invalid alias`**  
   **Cause:** No targets defined, same index twice, or alias fails regex.  
   **To fix:** Define at least one target; ensure indices are unique and aliases match `^[A-Za-z][A-Za-z0-9._-]{0,63}$`.

6) **Defaults shape/type issues**  
   **Cause:** Scalar default with multi-output, or wrong literal type.  
   **To fix:** Use **scalar** default only when `saveAs` is a **string** (index 0). For integers, provide numbers (UI exports safely).

7) **`RPC invalid / not EVM-compatible`**  
   **Cause:** Non-HTTPS or non-EVM RPC.  
   **To fix:** Provide an **HTTPS** endpoint for an **EVM-compatible** chain; leave empty to use engine default.

8) **On-chain revert / execution failed**  
   **Cause:** Contract rejected the call (bad args/state).  
   **To fix:** Verify contract state, args, and network. Use defaults to keep the pipeline resilient.

9) **`Return index out of range`**  
   **Cause:** `saveAs` references an index beyond the function’s outputs.  
   **To fix:** Adjust `saveAs` indices to `0..(arity-1)`.

10) **Placeholders in args resolve to empty**  
    **Cause:** `[key]` not set at that point in execution.  
    **To fix:** Ensure the producing read/API precedes this read, or provide a payload value.

---

## How to reference screenshots in this guide

Place a single line with the pattern below. Your `docs.html` will replace it with an actual image:

```
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-panel-main.png)
```

You can use different names per section, for example:

```
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-modal.png)
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-args-validators.png)
```
