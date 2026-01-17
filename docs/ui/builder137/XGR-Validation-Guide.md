# XGR Validation — How validation works

This guide explains what the **Validation** panel checks, how to read the messages, and why **Compile** is blocked until errors are fixed. It also lists the most common messages you’ll see and how to resolve them.

---

## Where Validation fits into the flow

Validation runs continuously while you edit the model. Compile (step 2) is disabled while errors exist, so the overall flow **Wallet → Compile → Deploy → Update** only continues after Validation is green.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/validation-panel.png) — Validation panel with a header and an error counter (0 = OK).

**What you see (with errors)**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/validation-panel-with-errors.png) — Actionable messages; each line tells you exactly what to change.

---

## What is validated?

### A) Contract Reads
- `function` must be a **non-empty string**.  
- `args` (optional) must be an **array** of objects shaped like `{ type, value }`.  
  - `type` must be one of the **XRC‑137 payload types**:  
    `string`, `bool`, `int64`, `int256`, `uint64`, `uint256`, `double`, `decimal`, `timestamp_ms`, `duration_ms`, `uuid`, `address`, `bytes`, `bytes32`  
  - `value` must be a **string** (literal, placeholder, CEL, template — all fine).  
- `saveAs` is **required** and must be a **map** (legacy formats are not supported):  
  `{ "0": { key, type, default? }, "1": { key, type, default? } }`  
  - indices must be **non‑negative integers** and **unique**  
  - `key` must follow the **Contract Read key naming rule** (starts with a letter; then letters/digits plus `.` `_` `-`)  
  - `type` must be one of the **XRC‑137 payload types** (see list above)  
  - `default` (optional) must match the selected `type`  
- `rpc` (optional) must be a **string URL**.  
- `save` / `defaults` (legacy fields) are **not supported**.

**Typical errors**  
- `contractReads[i]: "function" must be a non-empty string.`  
- `contractReads[i]: "args" must be an array.`  
- `contractReads[i].args[j] must be an object { type, value }.`  
- `contractReads[i].args[j].type is unknown. Supported: ...`  
- `contractReads[i].args[j].value must be a string.`  
- `contractReads[i]: "save" is not supported anymore. Use "saveAs" map entries only.`  
- `contractReads[i]: legacy "saveAs" string format is not supported anymore. Use a map: { "0": { key, type, default? } }.`  
- `contractReads[i]: "saveAs" must define at least one target.`  
- `contractReads[i].saveAs[j]: key must match ...`  
- `contractReads[i].saveAs[j]: type "..." is unknown. Supported: ...`  
- `contractReads[i].saveAs[j]: default does not match selected type "...".`  
- `contractReads[i]: "defaults" is not supported anymore. Move it into saveAs[<idx>].default.`  
- `contractReads[i]: rpc must be a string URL when provided.`

---

---

### B) APIs
- `name` must be **1..128 characters**, match `^[A-Za-z_][A-Za-z0-9_]*$`, and be **unique** across all calls.  
- `method` must be `GET | POST | PUT | PATCH`.  
- `urlTemplate` required; `contentType` must be `"json"`.  
- `headers` must be an object (string → string).  
- `timeoutMs` (optional) must be a **positive integer** (milliseconds).  
- `extractMap` required and non‑empty.  
  - aliases must be **1..128 characters** and follow the **payload naming rule** (starts with a letter; then letters/digits)  
  - aliases must not be duplicated within the same call  
  - each entry must be either a string RHS (`"resp.user.id"`) **or** an object:  
    `{ value, type, default?, save? }`  
  - `value` must be non-empty  
  - every RHS `value` must be **globally unique across all calls**  
  - `type` must be one of the **XRC‑137 payload types**  
  - `default` (optional) must match the selected `type`  
  - `save` (optional) controls whether an alias becomes a stored output (defaults to `true`)  
- Placeholders `[...]` inside `urlTemplate`/`bodyTemplate` are checked for **key syntax** and must match `^[A-Za-z0-9._-]+$`.  
- `defaults` (optional) must be an object.

**Typical errors**  
- `apiCalls[i]: name must be 1..128 characters.`  
- `apiCalls[i]: name must match /^[A-Za-z_][A-Za-z0-9_]*$/.`  
- `apiCalls: duplicate name "users".`  
- `apiCalls[users]: method must be GET|POST|PUT|PATCH.`  
- `apiCalls[users]: urlTemplate is required.`  
- `apiCalls[users]: contentType must be "json".`  
- `apiCalls[users]: headers must be an object (string→string).`  
- `apiCalls[users]: timeoutMs must be a positive integer (milliseconds).`  
- `apiCalls[users]: extractMap must not be empty.`  
- `apiCalls[users]: invalid alias "bad alias".`  
- `apiCalls: value "resp.id" must be unique across all calls.`  
- `apiCalls[users]: alias "price" has unknown type "number". Supported: ...`  
- `apiCalls[users]: extractMap["price"].default does not match type "uint256".`  
- `apiCalls[users]: urlTemplate placeholder [bad key] violates key regex /^[A-Za-z0-9._-]+$/.`  
- `apiCalls[users]: bodyTemplate placeholder [bad key] violates key regex /^[A-Za-z0-9._-]+$/.`  
- `apiCalls[users]: defaults must be an object.`

---

---

### C) Rules / onValid / onInvalid

Validation **does not** verify that placeholders like `[Name]` exist or are resolvable at this stage.

What *is* checked here:
- In `onValid.payload` and `onInvalid.payload`, **plain output keys** (e.g. `score`) must follow the **payload naming rule** (starts with a letter; then letters/digits).  
- Keys written as placeholders (e.g. `"[score]"`) are accepted as-is (no existence check).

**Typical errors**  
- `onValid.payload: invalid key "bad key" – must match ...`  
- `onInvalid.payload: invalid key "bad-key" – must match ...`  

**What you see (example)**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/validation-errors-example.png) — Example messages from payload/schema issues.

---

---

### D) Base model schema

Core structure checks (payload/rules/outputs) also run. Any schema issues from the XRC‑137 base are surfaced in the same list.

---

## Why Compile/Deploy/Update is blocked

Compile/Deploy/Update stays disabled while **any** validation error exists. Fix the messages until the counter reaches **0**, then the **Compile/Deploy/Update** button becomes clickable.

**What you see (Deploy disabled)**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/validation-panel-blocks-deploy.png) — Deploy button disabled until the error list is empty.

> Tip: The flow on the right will still show the next step.

---

## Quick fixes (cheat sheet)

- **Contract Reads** → Use `saveAs` as a map `{ "0": { key, type, default? } }`; remove legacy `save`/`defaults`; ensure `args` entries have valid XRC‑137 `type` and a string `value`.  
- **API issues** → Validate `name`/`method`/`urlTemplate`/`extractMap`; keep RHS `value` expressions unique across all calls; ensure every alias has a supported `type`.  
- **Output keys** → In `onValid.payload` / `onInvalid.payload`, keep plain keys in the payload naming rule; placeholders as keys are allowed.  
- **Schema errors** → Follow the exact wording; fix the referenced path (index/name).  

---

_Last updated: 2026-01-17_

