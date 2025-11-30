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
- `to` must be a real `0x…` EVM address.  
- `function` must be a Solidity signature like `fn(argTypes) returns (retTypes)`.  
- `args` length must match the ABI inputs; each arg must match its type.  
- `saveAs` must define at least one target (`"alias"` for index 0, or `{ "0": "alias0", "1": "alias1" }`).  
- Each `saveAs` index must be unique, non‑negative, and **< return arity**; each alias must match `^[A-Za-z][A-Za-z0-9._-]{0,63}$`.  
- `defaults` (optional) must be an object; indices must be in range.  
- `rpc` (optional) must be a string URL.

**Typical errors**  
- `contractReads[i]: "to" must be a valid 0x… EVM address.`  
- `contractReads[i]: "function" must be a Solidity signature like "fn(args) returns (tuple)".`  
- `contractReads[i].args: length X does not match ABI inputs (Y).`  
- `contractReads[i].args[k]: must be unsigned integer (type uint256).`  
- `contractReads[i].saveAs[1]: index 2 exceeds return arity (2).`  
- `contractReads[i].saveAs["price"]: key must match /^[A-Za-z][A-Za-z0-9._-]{0,63}$/.`  
- `contractReads[i]: defaults must be an object mapping indices (or aliases) to fallback values.`

---

### B) APIs
- `name` must match `^[A-Za-z][A-Za-z0-9._-]{0,63}$` and be unique.  
- `method` must be `GET | POST | PUT | PATCH`.  
- `urlTemplate` required; `contentType` must be `"json"`.  
- `headers` must be an object.  
- `extractMap` required and non‑empty; aliases must be valid and **not duplicated** within a call; every RHS expression (e.g., `resp.user.id`) must be **globally unique across all calls**.  
- Placeholders `[...]` in `urlTemplate`/`bodyTemplate` must match `^[A-Za-z0-9._-]+$`.

**Typical errors**  
- `apiCalls[i]: name must match /^[A-Za-z][A-Za-z0-9._-]{0,63}$/.`  
- `apiCalls: duplicate name "users".`  
- `apiCalls[users]: method must be GET|POST|PUT|PATCH.`  
- `apiCalls[users]: urlTemplate is required.`  
- `apiCalls[users]: extractMap is required and must be an object.`  
- `apiCalls[users]: extractMap must not be empty.`  
- `apiCalls[users]: invalid alias "bad alias".`  
- `apiCalls: expression "resp.id" must be unique across all calls.`  
- `apiCalls[users]: urlTemplate placeholder [bad key] violates key regex /^[A-Za-z0-9._-]+$/.`  
- `apiCalls[users]: bodyTemplate placeholder [bad key] violates key regex /^[A-Za-z0-9._-]+$/.`  
- `apiCalls[users]: defaults must be an object.`

---

### C) Placeholders in rules / onValid / onInvalid

Every placeholder like `"[Name]"` must exist in one of:
- **payload** names, or  
- **Contract Read** keys (from `saveAs`), or  
- **API** RHS expressions (from `extractMap`).

**Typical errors**  
- `placeholders: unknown name(s) [test1] – allowed are payload, Contract Read keys or API extract RHS expressions (case‑sensitive).`  
- `onValid.payload: unknown placeholder "[score]" (allowed: payload, Contract Read keys or API extract RHS expressions, case‑sensitive).`

**What you see (example)**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/validation-errors-example.png) — Two common messages: a missing payload field and an unknown placeholder.

---

### D) Base model schema

Core structure checks (payload/rules/outputs) also run. Any schema issues from the XRC‑137 base are surfaced in the same list.

---

## Why Compile is blocked

Compile stays disabled while **any** validation error exists. Fix the messages until the counter reaches **0**, then the **Compile** button becomes clickable.

**What you see (Compile disabled)**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/validation-panel-blocks-compile.png) — Compile button disabled until the error list is empty.

> Tip: The flow on the right will still show the next step, but it won’t progress until you compile successfully.

---

## Quick fixes (cheat sheet)

- **Unknown placeholder** → Add it to **payload**, or produce it via **Contract Reads** (`saveAs`) / **API extractMap** (RHS).  
- **ABI mismatch** → Fix `function` signature, argument types/count, and `returns`.  
- **API issues** → Validate `name`/`method`/`urlTemplate`/`extractMap`; keep RHS expressions unique.  
- **Schema errors** → Follow the exact wording; fix the referenced path (index/name).

---

_Last updated: 2025-10-19_
