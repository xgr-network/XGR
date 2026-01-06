# XDaLa Hard Limits Specification (XRC-137 & XRC-729)

## 1. Scope and Rationale

This document specifies the **deterministic hard limits (“caps”)** enforced by the **XDaLa Engine** for:

- **XRC-137** (Rule / Validation Documents)
- **XRC-729** (Orchestration / Process Graphs)

These limits are **not configuration knobs** and **not rate limits**.  
They are **hard, deterministic safety caps** enforced during parsing and preflight validation to ensure:

- bounded CPU and memory usage
- bounded database growth and log size
- prevention of fan-out and graph explosion
- predictable worst-case execution behavior

Any violation of these limits results in a **hard abort**.

---

## 2. Abort Semantics

### 2.1 XRC-729 (Orchestration)

- Limits are enforced **before session start**
- Violations cause an **early abort**
- The JSON-RPC call (`xgr_validateDataTransfer`) fails immediately
- **No process is enqueued**
- **No session state is created**

### 2.2 XRC-137 (Rule Documents)

- Limits are enforced **when the rule is loaded and parsed**
- Violations result in a **hard transaction abort**
- The session fails deterministically with an error
- This maps to an **ErrTx / hard failure**, not a soft validation result

---

## 3. Design Principles

The limits follow four strict principles:

1. **Deterministic**  
   No dependence on runtime scheduling, node load, or timing.

2. **Schema-Level Enforcement**  
   Applied during parsing / preflight, not during execution.

3. **Fail-Fast**  
   Abort as early as possible to avoid partial state or side effects.

4. **Economically Neutral**  
   Limits are independent of gas price or sender balance.

---

## 4. XRC-137 Limits (Rule Documents)

### 4.1 Document Size

| Limit | Description |
|---|---|
| `MaxXRC137Bytes` | Maximum size of the decrypted rule JSON |

**Default:** `128 KB`

Applies:
- before JSON parsing
- after decryption (if encrypted)

---

### 4.2 Payload Definition

| Limit | Description |
|---|---|
| `MaxPayloadFields` | Maximum number of declared payload input fields |
| `MaxFieldNameLen` | Maximum length of a payload field name |

**Defaults:**  
- Fields: `64`  
- Field name length: `64` characters

Field names must be **ASCII identifiers**:  
`[A-Z a-z 0-9 _ -]`

---

### 4.3 Rules and Expressions

| Limit | Description |
|---|---|
| `MaxRules` | Maximum number of rule entries |
| `MaxExprLen` | Maximum length of a single expression string |

**Defaults:**  
- Rules: `64`  
- Expression length: `2048` characters

Applies to:
- string rules
- object rules (`{ expression, type }`)
- validation and decision rules

---

### 4.4 API Calls

| Limit | Description |
|---|---|
| `MaxAPICalls` | Maximum number of API calls |
| `MaxURLTemplateLen` | Maximum URL template length |
| `MaxBodyTemplateLen` | Maximum body template length |
| `MaxExtractMapEntries` | Maximum extract map entries per call |

**Defaults:**  
- API calls: `16`  
- URL template: `2048` chars  
- Body template: `8 KB`  
- Extract entries: `64`

Each extract key:
- must be an ASCII identifier
- counts toward extract fan-out limits

---

### 4.5 Contract Reads

| Limit | Description |
|---|---|
| `MaxContractReads` | Maximum number of contract reads |
| `MaxContractReadSaveAs` | Maximum number of `saveAs` targets |

**Defaults:**  
- Reads: `16`  
- Save targets: `64`

Each `saveAs` key:
- must be a valid ASCII identifier
- is subject to payload and log caps downstream

---

### 4.6 Branch Outcomes (`onValid` / `onInvalid`)

| Limit | Description |
|---|---|
| `MaxOutcomeKeys` | Maximum number of output payload keys |
| `MaxGrants` | Maximum grants per branch |
| `MaxExecArgs` | Maximum execution arguments |
| `MaxStringValueLen` | Maximum length of any string value |

**Defaults:**  
- Outcome keys: `64`  
- Grants: `16`  
- Execution args: `16`  
- String value length: `8 KB`

Applies to:
- outcome payload values
- defaults
- execution argument values

---

## 5. XRC-729 Limits (Orchestration)

### 5.1 Document Size

| Limit | Description |
|---|---|
| `MaxOSTCBytes` | Maximum size of orchestration JSON |

**Default:** `256 KB`

Enforced before graph parsing.

---

### 5.2 Steps and Graph Size

| Limit | Description |
|---|---|
| `MaxSteps` | Maximum number of steps in the orchestration |
| `MaxStepIdLen` | Maximum length of a step identifier |

**Defaults:**  
- Steps: `128`  
- Step ID length: `64` characters

All step IDs must be ASCII identifiers.

---

### 5.3 Spawns and Joins

| Limit | Description |
|---|---|
| `MaxSpawnsPerBranch` | Maximum spawns per branch |
| `MaxJoinInputs` | Maximum inputs into a join |

**Defaults:**  
- Spawns per branch: `32`  
- Join inputs: `32`

These caps prevent:
- fan-out explosions
- unbounded join cardinality
- exponential process growth

---

## 6. Error Semantics

All limit violations return a deterministic error:
