# XGR Contract Reads (UI Guide)

This guide explains how to configure **on-chain Contract Reads** in the **XRC-137 Builder** UI so they match the engine (parser + reads executor).

---

## 1) What a Contract Read is

Calls a **view/pure** function on an **EVM-compatible** chain and maps the returned tuple via **`saveAs`**. Reads typically run before API Calls.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-panel-main.png) — Contract Reads panel with one configured row and “Add Read” button.

---

## 2) Fields in the UI (engine-aligned)

| Field        | Required | Notes                                                                                             |
|--------------|----------|---------------------------------------------------------------------------------------------------|
| **To**       | yes      | **Dev/Test:** address **or** placeholder/expression (e.g. `[MyPayloadKey]` or `'some-literal'`). **Production:** must be a valid `0x` + 40-hex address. |
| **Function** | yes      | `name(type1,type2,…) returns (ret1,ret2,…)`.                                                      |
| **Args**     | yes      | Array; one value per input type; placeholders allowed.                                            |
| **saveAs**   | yes      | String for index `0` **or** map `{ "0": "A", "1": "B" }`.                                         |
| **Defaults** | no       | Scalar or map by indices/aliases.                                                                 |
| **RPC**      | no       | HTTPS endpoint; **EVM-compatible only**.                                                          |

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-modal.png) — “Edit Contract Read” modal with all fields and validation hints.

---

## 3) Function signature & args

- Signature example: `myFn(address,bytes32) returns (string,uint64)`  
- Args count must match inputs; placeholders `[key]` allowed.  
- **No inputs?** Leave Input types empty in Signature Helper; JSON uses `"args": []`.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-signature-helper-no-inputs.png) — Helper modal with empty inputs and `fn() returns (...)` preview.

---

## 4) Mapping results with `saveAs`

- Single return: `saveAs` string (alias) for index `0`.  
- Multiple returns: map of index→alias.  
- **Alias regex (UI & engine):** `^[A-Za-z][A-Za-z0-9]*$` (letters & digits only; must be unique within the rule).

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-saveas.png) — Table mapping tuple indices to aliases.

---

## 5) Defaults (fallbacks)

- Optional. Scalar (when `saveAs` is string for index `0`) or map by indices/aliases.  
- UI normalizes JSON types: ints as numbers when safe, else strings; bool, hex, etc.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-defaults.png) — Examples of scalar vs map defaults with type-aware hints.

---

## 6) RPC (optional)

- HTTPS endpoint; **EVM-compatible** only.  
- Omit to use engine default RPC.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-rpc-field.png) — RPC input with info “EVM-compatible only”.

---

## 7) Placeholders `[key]` in args

Sources: runtime payload, earlier reads (`saveAs`), earlier APIs.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-placeholders-help.png) — Tooltip with the three sources and examples.

---

## 8) Validation (what the UI enforces)

- Full function signature; args length matches ABI.  
- `saveAs` present; alias regex; no duplicate indices/aliases.  
- Defaults optional; shape checked.  
- RPC optional; HTTPS + EVM-compatible in enterprise.  
- **To field:** The UI intentionally remains free-form to support Dev/Test placeholders. At **execution time**, the engine enforces: in **Production** the resolved `to` must be a valid `0x` + 40-hex address; in **Dev/Test** a placeholder/expression is accepted.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-validation-errors.png) — Example errors for duplicate alias, etc.

---

## 9) Examples

**Single return (string), saveAs string + scalar default**
```json
{
  "to": "0x1111111111111111111111111111111111111111",
  "function": "symbol() returns (string)",
  "args": [],
  "saveAs": "sym",
  "defaults": ""
}
```
**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-examples-cards-1.png) — One example card with a “validated” badge.

**Multiple returns (string, uint64), saveAs map + typed defaults**
```json
{
  "to": "0x1111111111111111111111111111111111111111",
  "function": "getData(string,bytes32) returns (string,uint64)",
  "args": ["[user.input]", "0x0000000000000000000000000000000000000000000000000000000000000000"],
  "saveAs": { "0": "name", "1": "version" },
  "defaults": { "0": "", "1": 0 },
  "rpc": "https://rpc.example.org"
}
```

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-examples-cards-2.png) — One example card with a “validated” badge.

---

## 10) Tips & Troubleshooting

- If args fail, re-check signature & ABI types.  
- Use placeholders to avoid hard-coded literals.  
- Very large ints: keep defaults as strings (engine can parse).  
- With defaults, only missing outputs fall back.

