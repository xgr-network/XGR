# XDaLa Hard Limits Specification (XRC-137, XRC-729, CEL)

## 1. Scope and Rationale

This document specifies the **deterministic hard limits (“caps”)** enforced by the **XDaLa Engine** for:

- **XRC-137** (Rule / Validation Documents)
- **XRC-729** (Orchestration / Process Graphs)
- **CEL / Expression Evaluation** (runtime evaluator safety)

These caps are **hard protocol constraints**. They are enforced **before execution** (parsing/preflight) or **during evaluator preparation** (checked AST), to ensure:

- bounded CPU/memory usage
- bounded fan-out and join cardinality
- bounded log/receipt/database growth
- deterministic worst-case behavior

Any cap violation results in a **hard abort**.

---

## 2. Abort Semantics

### 2.1 XRC-729 (Orchestration)
Caps are enforced **before session start**. Violations cause an **early abort**:
- the JSON-RPC call fails immediately
- **no process is enqueued**
- **no session state is created**

### 2.2 XRC-137 (Rule Documents)
Caps are enforced **when the rule document is read and parsed** during session execution.  
Violations result in a **hard abort** (ErrTx semantics), not a soft validation outcome.

### 2.3 CEL / Expression Evaluation
Evaluator caps are enforced:
- on raw expression length (pre-check)
- on checked AST size (node count)
- on input list/array sizes (deep traversal)

Violations abort rule evaluation deterministically. :contentReference[oaicite:1]{index=1}

---

## 3. XRC-137 Limits (Rule Documents)

### 3.1 Document & Schema Caps

| Key | Description | Limit |
|---|---|---:|
| `MaxXRC137Bytes` | Maximum size of the decrypted XRC-137 JSON blob | 131072 bytes (128 KB) |
| `MaxPayloadFields` | Maximum declared payload input fields | 64 |
| `MaxFieldNameLen` | Maximum payload/output field name length (ASCII identifier) | 64 chars |
| `MaxRules` | Maximum number of rules in `rules[]` | 64 |
| `MaxExprLen` | Maximum length of any rule expression string | 2048 chars |

Field names must be ASCII identifiers: `[A-Za-z0-9_-]`.

---

### 3.2 API Caps

| Key | Description | Limit |
|---|---|---:|
| `MaxAPICalls` | Maximum number of `apiCalls[]` | 16 |
| `MaxURLTemplateLen` | Maximum `urlTemplate` length | 2048 chars |
| `MaxBodyTemplateLen` | Maximum `bodyTemplate` length | 8192 chars (8 KB) |
| `MaxExtractMapEntries` | Maximum extract entries per `apiCalls[i].extractMap` | 64 |
| `MaxStringValueLen` | Maximum length of any string literal/default in API extract context | 8192 chars (8 KB) |

Notes:
- Each `extractMap` key is subject to `MaxFieldNameLen` and ASCII identifier rules.
- Expression-like strings inside extract specs are subject to `MaxExprLen`.

---

### 3.3 Contract Reads Caps

| Key | Description | Limit |
|---|---|---:|
| `MaxContractReads` | Maximum number of `contractReads[]` | 16 |
| `MaxContractReadSaveAs` | Maximum number of `saveAs` targets per contract read | 64 |
| `MaxStringValueLen` | Maximum length of any string default in `saveAs` | 8192 chars (8 KB) |

---

### 3.4 Branch Outcome Caps (`onValid` / `onInvalid`)

| Key | Description | Limit |
|---|---|---:|
| `MaxOutcomeKeys` | Maximum number of keys in `onValid.payload` / `onInvalid.payload` | 64 |
| `MaxGrants` | Maximum number of grants per branch | 16 |
| `MaxExecArgs` | Maximum number of `execution.args[]` per branch | 16 |
| `MaxStringValueLen` | Maximum length of any string payload value in branches | 8192 chars (8 KB) |

---

## 4. XRC-729 Limits (Orchestration)

### 4.1 Document Caps

| Key | Description | Limit |
|---|---|---:|
| `MaxOSTCBytes` | Maximum size of raw OSTC JSON returned by XRC-729 | 262144 bytes (256 KB) |

---

### 4.2 Graph Caps

| Key | Description | Limit |
|---|---|---:|
| `MaxSteps` | Maximum number of steps in `structure` | 128 |
| `MaxStepIdLen` | Maximum step id length (ASCII identifier) | 64 chars |
| `MaxSpawnsPerBranch` | Maximum spawn edges per branch (`onValid.spawns`, `onInvalid.spawns`) | 32 |
| `MaxJoinInputs` | Maximum join inputs per join (`join.from[]`) | 32 |

Notes:
- Step ids, spawn targets, join ids and join `from.node` MUST be ASCII identifiers.
- Caps are applied during orchestration parsing; violations early-abort the RPC call.

---

## 5. CEL / Expression Limits (Evaluator Safety)

These limits are enforced in the CEL evaluation layer and are independent from XRC schema parsing. :contentReference[oaicite:2]{index=2}

| Key | Description | Limit |
|---|---|---:|
| `MaxExprLen` | Maximum raw CEL source length (bytes) | 1024 |
| `MaxAstNodes` | Maximum checked AST node count | 4096 |
| `MaxListCap` | Maximum list/array size anywhere in input values (deep traversal) | 64 |

---

## 6. Error Semantics

Limit violations return deterministic errors (hard abort):

- `ErrLimitsExceeded` (parser/preflight caps)
- CEL layer errors (e.g. `ErrExprTooComplex`, `ErrListCapExceeded`) for evaluator caps :contentReference[oaicite:3]{index=3}

Error messages include:
- which cap was violated
- observed value
- maximum allowed value

Example:
