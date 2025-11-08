# XRC‑137 Specification — Full, Corrected & Expanded (v0.2)
**Date:** 2025-11-08 06:39:14 UTC

**Status:** Normative; backwards‑compatible with legacy `rules` arrays; includes an optional typed‑rules extension.  
**Scope:** End‑to‑end definition for authoring, storing, loading, decrypting, evaluating and executing XRC‑137 rules.

---

## 0. Editor’s note (nothing removed)
This document **integrates all prior content** while fixing inconsistencies and expanding details.  
To satisfy “nothing omitted,” the **entire original document** is preserved at the end as **Appendix A (verbatim)**.

---

## 1. Purpose & Roles
XRC‑137 defines a **single‑step validation+execution contract format** that can be published on‑chain and consumed by the XDaLa engine:
- **Publisher (contract):** Stores the canonical rule string (plaintext JSON or encrypted XGR1 envelope) and exposes minimal getters + encryption metadata.
- **Consumer (engine):** Loads, decrypts (if needed), merges declared reads (on‑chain & HTTP), evaluates rules over an input payload, selects `onValid`/`onInvalid`, optionally builds an `execution`, and persists encrypted/unencrypted logs per policy.

The spec is **deterministic** by construction and avoids implicit retries or manager heuristics.

---

## 2. Top‑level JSON (normative schema)
The canonical rule **JSON** has the following top‑level shape (informative inline types; see §3 for the normative JSON Schema):

```jsonc
{
  "payload":       { "<Key>": { "type": "string|number|bool|array|object", "optional": false } },
  "contractReads": [ /* ContractRead */ ],
  "apiCalls":      [ /* APICall    */ ],
  "rules":         [
    // Legacy: strings (all treated as "validate")
    "<CEL boolean>",
    // Optional extension: typed entries (see §7)
    { "expression": "<CEL boolean>", "type": "validate|abortStep|cancelSession" }
  ],
  "onValid":       /* Outcome */,
  "onInvalid":     /* Outcome */,
  "address":       "0x...",    // injected by engine if missing
  "version":       "0.2"       // optional, informative
}
```

### 2.1 Defaults
Unless stated otherwise:
- Missing optional fields imply **sane safe defaults** (no waits, no execution, no encryption override).
- Unknown fields must be **ignored** by engines (forward compatibility).

### 2.2 Determinism rules
- No implicit retries in engine (HTTP or reads).  
- Failure handling for reads/APIs is decided by **completeness of defaults** (§5, §6).  
- `rules` evaluate against the **merged inbound** inputs (original inputs + reads + APIs + defaults used).

---

## 3. Normative JSON Schema (Draft 2020‑12)
> Engines may validate more strictly at load time, but must at least satisfy these constraints.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://xgr.network/schemas/xrc-137/v0.2.json",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "payload": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["type","optional"],
        "properties": {
          "type":      { "type":"string" },
          "optional":  { "type":"boolean" }
        }
      }
    },
    "contractReads": {
      "type": "array",
      "items": { "$ref": "#/$defs/ContractRead" }
    },
    "apiCalls": {
      "type": "array",
      "items": { "$ref": "#/$defs/APICall" }
    },
    "rules": {
      "type": "array",
      "items": {
        "oneOf": [
          { "type": "string" },
          { "$ref": "#/$defs/RuleItem" }
        ]
      }
    },
    "onValid":   { "$ref": "#/$defs/Outcome" },
    "onInvalid": { "$ref": "#/$defs/Outcome" },
    "address":   { "type": "string", "pattern": "^0x[0-9a-fA-F]{40}$" },
    "version":   { "type": "string" }
  },
  "required": ["payload","rules"],
  "$defs": {
    "Outcome": {
      "type": "object",
      "additionalProperties": true,
      "properties": {
        "waitMs":        { "type":"integer", "minimum":0 },
        "waitUntilMs":   { "type":"integer", "minimum":0 },
        "payload":       { "type":"object" },
        "execution":     { "$ref": "#/$defs/Execution" },
        "encryptLogs":   { "type":"boolean" },
        "logExpireDays": { "type":"integer", "minimum":1 }
      }
    },
    "Execution": {
      "type": "object",
      "properties": {
        "to":       { "type":"string" },
        "function": { "type":"string" },
        "args":     { "type":"array", "items": { "type":["string","number","boolean","object","array"] } },
        "value":    { "type":["string","number"] },
        "gas":      {
          "type":"object",
          "properties": { "limit": { "type":"integer", "minimum": 21000 } }
        },
        "extras":   { "type":"object" }
      },
      "additionalProperties": true
    },
    "ContractRead": {
      "type":"object",
      "required":["to","function"],
      "properties": {
        "to":       { "type":"string", "pattern": "^0x[0-9a-fA-F]{40}$" },
        "function": { "type":"string" },
        "args":     { "type":"array", "items": { "type":["string","number","boolean","object","array"] } },
        "saveAs":   {
          "oneOf": [
            { "type":"string" },
            {
              "type":"object",
              "additionalProperties": { "type":"string" }
            }
          ]
        },
        "defaults": {
          "oneOf": [
            { "type":["string","number","boolean","null"] },
            {
              "type":"object",
              "additionalProperties": true
            }
          ]
        },
        "rpc": { "type":"string" }
      }
    },
    "APICall": {
      "type":"object",
      "required":["name","urlTemplate","contentType"],
      "properties": {
        "name":         { "type":"string" },
        "method":       { "type":"string", "enum":["GET","POST","PUT","PATCH"] },
        "urlTemplate":  { "type":"string" },
        "headers":      { "type":"object", "additionalProperties": { "type":"string" } },
        "bodyTemplate": { "type":"string" },
        "contentType":  { "type":"string", "const":"json" },
        "extractMap":   { "type":"object", "additionalProperties": { "type":"string" } },
        "defaults":     { "type":"object", "additionalProperties": true }
      }
    },
    "RuleItem": {
      "type":"object",
      "required":["expression"],
      "properties": {
        "expression": { "type":"string" },
        "type":       { "type":"string", "enum":["validate","abortStep","cancelSession"] }
      }
    }
  }
}
```

---

## 4. Engine loader & contract interface
### 4.1 Getter probing order
Engines MUST try, in order, the following selectors and use the first non‑empty string:
1. `getRule()` → `rule()` → `getRuleJSON()` → `ruleJSON()` → `ruleJson()` (public var autogetter).  
2. If the selected string starts with `XGR1.`, interpret as encrypted envelope (see §9).  
3. If the parsed JSON has no `address`, inject the contract address for traceability.

### 4.2 Mutator (reference)
`setRule(string jsonOrXgr1, bytes32 rid, string suite)` with events `RuleUpdated`, `EncryptedSet`, `EncryptedCleared`.

---

## 5. Contract reads — semantics & defaults
- Runs **before** `apiCalls` so API templates/rules can depend on results.
- Return is treated as a **tuple**; `saveAs` maps indices to keys (or `"Alias"` for index 0).

**Deterministic fallback**
- If read **fails** (RPC/eth_call error or revert):
  - If **all** indices/keys used in `saveAs` have defaults ⇒ **write defaults** and continue.
  - If **any** mapped index/key lacks a default ⇒ **terminal fail of the step**.
- If read succeeds but a referenced index is out of range ⇒ use default if present, else fail.

**Scalar default rule**
- Scalar `defaults` are valid **only when** `saveAs` is a single string (index 0).

**Argument evaluation**
- Each `args[i]` allows placeholder/expression; final value MUST cast cleanly to ABI type.

---

## 6. HTTP API calls — semantics & defaults
- Timeout per call **8s**; redirects ≤3; response size ≤1 MiB; TLS ≥1.2; HTTP/1.1; IPv4 only; no env proxy.
- `contentType` **must** be `"json"`; array‑root is allowed.
- `extractMap` values are **CEL expressions** over `resp` (parsed JSON). Results are persisted **only if scalar**.

**Deterministic fallback**
- If **transport/status/JSON/decode** fails:
  - If **every alias** in `extractMap` is present in `defaults` ⇒ **write defaults** and continue.
  - If **any alias** lacks a default ⇒ **terminal fail**.
- On extract expression error for alias `A`: use `defaults[A]` if present, else fail.

**Alias constraints**
- `^[A-Za-z][A-Za-z0-9._-]{0,63}$`, not starting with `_` or `sys.`, and **unique** across all calls.

**Placeholder rules**
- URL templates auto‑escape inserted values; body templates use raw JSON serialization.  
- `[[` ⇒ literal `[`; `]]` ⇒ literal `]`. Missing keys ⇒ error.

---

## 7. Rules — legacy and typed extension
### 7.1 Legacy form
```
"rules": ["<CEL boolean>", ...]
```
- All entries are **validate** rules.  
- The combined validate result is **AND‑ed** (all must be true).

### 7.2 Typed extension (optional, engine‑safe)
```
"rules": [
  "<CEL boolean>",    // treated as validate
  { "expression": "<CEL boolean>", "type": "validate|abortStep|cancelSession" }
]
```
- Engines that don’t implement typed actions MUST treat unknown/unsupported `type` as **validate** (safe default).

**Semantics (when supported by engine/runtime):**
- `validate`: contributes to the AND‑aggregate.
- `abortStep`: if **any** evaluates to true ⇒ **stop the step immediately**, do not execute `execution`, do not create `continue/spawn`.
- `cancelSession`: if **any** evaluates to true ⇒ **terminate entire session** (manager kills root).  
- Precedence: `cancelSession` > `abortStep` > validate outcome. The last valid/invalid boolean is still recorded for observability.

**Evaluation base**
- Rules evaluate against **merged inbound inputs** (orig payload + reads + APIs + defaults used). Missing keys inside a rule evaluate to **false** (no exception).

---

## 8. Outcomes (`onValid`/`onInvalid`) & mapping
- `waitUntilMs` overrides `waitMs` (both optional; default 0).
- `payload` mapping supports:
  - Exact `"[Key]"`: copy from inbound.  
  - Template with placeholders only: literal substitution.  
  - Otherwise: full expression over inbound + `pid`.

- If `execution` is omitted or `execution.to==""`: **meta‑only** (no inner call).

---

## 9. Encryption model (XGR1) & grants
### 9.1 Envelope ABNF
```
XGR1 = "XGR1." SUITE "." RID "." BASE64
SUITE = 1*VCHAR
RID   = 64HEXDIG
BASE64= *( ALPHA / DIGIT / "+" / "/" / "=" )
```
- JSON is encrypted with **AES‑GCM‑256** using a random DEK; envelope carries suite, rid, ciphertext.
- `encrypted.rid != 0` on contract signals storage is encrypted; engines use owner/read grants to read logs.

### 9.2 Logs encryption policy
- Default: encrypt logs iff `encrypted.rid != 0` (rule was stored encrypted).  
- Branch overrides: `onValid.encryptLogs` / `onInvalid.encryptLogs`.  
- `logExpireDays` default 365; when set, MUST be ≥1.  
- Fail‑closed: missing owner/read‑key ⇒ no plaintext leakage (reduce receipt metadata; record error).

---

## 10. Execution
- `to` may be empty ⇒ meta‑only.  
- `function` uses Solidity signature; `args` evaluated then cast to ABI; `value` non‑negative Wei (default 0).  
- `gas.limit` (optional) is respected when present.

Errors: invalid `to`, ABI mismatch, cast failures, negative value.

---

## 11. Validation gas (structure heuristic)
- Decrypt: 30k  
- Required‑check: 1k each  
- Math ops: 1k each  
- Comparisons: 1k each  
- String helpers: 1.5k–3k  
- Regex: 4k–5k  
- `saveData`: 1k per field  
Totals are additive; branch split (common/onValid/onInvalid) available; estimates are not clamped.

---

## 12. Error catalogue (normative, non‑exhaustive)
- **Placeholders**: invalid key syntax; missing key; unclosed brackets.  
- **HTTP**: non‑2xx; non‑JSON; decode error; timeout; redirect overflow; size overflow.  
- **Extracts**: empty expression; eval error without default; non‑scalar with `save:true`.  
- **Reads**: invalid `to`; `saveAs` format; out‑of‑range; arg eval/cast; missing defaults after failure.  
- **Rules**: syntax error; non‑boolean; timeout; unknown `type` (treated as `validate`).  
- **Execution**: invalid `to`; ABI mismatch; cast errors; negative value.  
- **Outputs**: missing referenced keys; invalid template; eval error.

---

## 13. Conformance tests (authoring)
Below is a **non‑optional** authoring suite; engines SHOULD provide a runner. YAML outline:

```yaml
- name: "api-defaults-all-covered"
  rule: |
    {{ JSON for APICall with extractMap {A,B} and defaults {A,B} }}
  input: {}
  expect:
    valid: false            # e.g., rules check A!='ERROR'
    apiSaves:
      A: { eq: "ERROR" }    # defaults applied
      B: { eq: 0 }
- name: "api-defaults-missing-one"    # hard fail
  rule: |
    {{ JSON for APICall with extractMap {A,B} and defaults {A} only }}
  input: {}
  expect:
    hardFail: true
```

(Provide many more covering reads success/fail, placeholders, outcomes, encryption overrides, typed rules, etc.)

---

## 14. Migration guide 0.1 → 0.2
- **Top‑level** stays the same; `version` optional.  
- **Rules**: legacy string array remains valid; the typed extension is opt‑in.  
- **API/read defaults**: clarified to be **deterministic** and **complete‑coverage required**.  
- **Encryption policy**: clarified default/override precedence and fail‑closed behavior.

---

## 15. Glossary
*(Keep original glossary in Appendix A; additional terms below.)*
- **RID**: Random identifier computed at encryption time to bind grants & log scopes.
- **Meta‑only**: Outcome branch without inner EVM execution (no on‑chain TX).

---

## 16. Full Examples
(Provide extended JSON examples for typical scenarios; see Appendix A and add more as needed.)

---

## 17. Versioning
This file is **v0.2**. Future versions may add fields; engines should ignore unknown props and treat missing props as defaults.

---

# Appendix A — Original document (verbatim)

# XRC‑137 Developer Guide

**Audience:** engineers building on **XDaLa / XGRChain**  
**Goal:** implementation‑ready reference for the **XRC‑137 rule contract** and the **XRC‑137 JSON rule format**, aligned with the **XGR Encryption & Grants** model (XRC‑563).

---

## 01. Overview

**XRC‑137** publishes a single canonical **rule** on‑chain (as a string). The **engine** loads the rule, decrypts it when needed, evaluates it deterministically against an input payload plus on‑chain/off‑chain reads, selects an outcome (valid/invalid), and returns a transformed payload and an optional execution specification. Logs can be persisted plaintext or encrypted.

- **Contract (publisher & policy):** stores the rule string (plaintext JSON or encrypted XGR1 envelope) and exposes minimal getters; it also signals encryption defaults.
- **Engine (consumer & executor):** loads, decrypts, merges reads, evaluates rules, prepares execution, and writes logs according to policy.


## 02. Contract data layout (reference)

```solidity
pragma solidity ^0.8.21;

contract XRC137Storage {
    /// Canonical rule string: plaintext JSON or XGR1 envelope ("XGR1.<suite>.<rid>.<base64>")
    string public ruleJson;

    /// Encryption metadata: non‑zero rid ⇒ the stored rule is encrypted
    struct EncInfo { bytes32 rid; string suite; }
    EncInfo public encrypted;

    /// Minimal ownership for admin updates (implementations may differ)
    address public owner;
}
```

**Invariants**
- `encrypted.rid == 0x0…0` ⇒ `ruleJson` is **plaintext JSON**.
- `encrypted.rid != 0x0…0` ⇒ `ruleJson` is an **XGR1** envelope produced with the suite in `encrypted.suite`.


## 03. View getters (engines probe in this order)

```solidity
function getRule() external view returns (string memory);
function rule() external view returns (string memory);
function getRuleJSON() external view returns (string memory);
function ruleJSON() external view returns (string memory);
// Auto‑getter if `string public ruleJson;` is present
function ruleJson() external view returns (string memory);
// Encryption metadata (tuple)
function encrypted() external view returns (bytes32 rid, string memory suite);
// Optional
function owner() external view returns (address);
```

**Engine loader behavior**
- Call the string getters **in order** and use the first non‑empty result.
- If the returned string starts with `XGR1.`, **decrypt** (see §07) before parsing JSON.
- If the JSON lacks an `address`, **inject** the contract address (traceability).


**Reference (loader snippet):**
```go
sigs := []string{
		"getRule()",
		"rule()",
		"getRuleJSON()",
		"ruleJSON()",
```


## 04. Admin/mutating surface (reference shape)

```solidity
/// Store plaintext JSON (rid=0) or an encrypted XGR1 blob (rid!=0).
function setRule(string calldata jsonOrXgr1, bytes32 rid, string calldata suite) external;
```

**Required behavior**
- If `rid == 0x0…0`: store `ruleJson=jsonOrXgr1` and **clear** `encrypted`.
- If `rid != 0x0…0`: require `jsonOrXgr1` to start with `XGR1.`; store it and set `encrypted={rid, suite}`.
- Enforce access control (e.g., `onlyOwner`).

**Events**
```solidity
event RuleUpdated(string newRule);
event EncryptedSet(bytes32 rid, string suite);
event EncryptedCleared();
```


## 05. JSON rule data model (selected struct anchors)

```go
type InputField struct {
	Name     string
	Type     string
	Optional bool
```

```go
OnValid struct {
			WaitMs        int64                  `json:"waitMs,omitempty"`
			WaitUntilMs   int64                  `json:"waitUntilMs,omitempty"`
			Payload       map[string]interface{} `json:"payload,omitempty"`
			EncryptLogs   *bool                  `json:"encryptLogs,omitempty"`
			LogExpireDays *int                   `json:"logExpireDays,omitempty"`
			Execution     *struct {
				To       string                 `json:"to,omitempty"`
				Function string                 `json:"function,omitempty"`
				Args     []string               `json:"args,omitempty"`
				Gas      *GasSpec               `json:"gas,omitempty"`
				Value    string                 `json:"value,omitempty"`
				Extras   map[string]interface{} `json:"extras,omitempty"`
			} `json:"execution,omitempty"`
		} `json:"onValid"`
		OnInvalid struct {
			WaitMs        int64                  `json:"waitMs,omitempty"`
			WaitUntilMs   int64                  `json:"waitUntilMs,omitempty"`
			Payload       map[string]interface{} `json:"payload,omitempty"`
			EncryptLogs   *bool                  `json:"encryptLogs,omitempty"`
			LogExpireDays *int                   `json:"logExpireDays,omitempty"`
			Execution     *struct {
				To       string                 `json:"to,omitempty"`
				Function string                 `json:"function,omitempty"`
				Args     []string               `json:"args,omitempty"`
				Gas      *GasSpec               `json:"gas,omitempty"`
				Value    string                 `json:"value,omitempty"`
				Extras   map[string]interface{} `json:"extras,omitempty"`
			} `json:"execution,omitempty"`
		} `json:"onInvalid"`
		Address string `json:"address"`
```

```go
type ParsedXRC137 struct {
	Payload       []InputField
	APICalls      []APICall
	ContractReads []ContractRead
	Expressions   []string
	OnValid       *BranchSpec
	OnInvalid     *BranchSpec
	Address       types.Address
```


## 06. Engine: load, decrypt, and merge

1) Load via getters (§03) → 2) If `XGR1.`, decrypt → 3) Inject `address` if missing → 4) Merge `contractReads` then `apiCalls` into inbound payload.


## 07. Encryption model (XGR1 envelope)

- Generate random **DEK** (32 bytes) → encrypt JSON with **AES‑GCM‑256** → textual envelope `XGR1.<suite>.<rid>.<base64>`.
- `encrypted.rid == 0x0…0` ⇒ plaintext; `encrypted.rid != 0x0…0` ⇒ encrypted (XGR1). `encrypted.suite` names the cipher suite.
- RID identifies the encrypted instance for grants and log scopes.


## 08. Grants & scopes (XRC‑563 alignment)

- **Scope 1 (OWNER)**: protects **rule** content (XRC‑137).
- **Scope 2 (RID)**: protects **engine log bundles** for that RID.
- Owners register a **Read‑Public‑Key** (SEC1 P‑256). Grants map `(RID, recipient)` → `EncDEK + rights + expiry`.
- **Permissionless first grant** for a new RID is allowed (RID unpredictable prior to ciphertext).


## 09. Rules evaluation semantics

- All rule expressions must evaluate to **true**.
- Missing keys make the affected expression **false** (no hard exception).
- Order: `contractReads` → `apiCalls` → `rules` → outcome build.


## 10. Outcome mapping & execution

- Mapping:
  - exact `"[Key]"` → copy value
  - template without operators → substitution
  - otherwise **CEL evaluation** over inputs (+ `pid`)
- If `execution.to` missing/empty → **meta‑only** step (no inner call).


## 11. Log persistence & encryption policy

- Persist `PayloadAll`, `APISaves`, `ContractSaves` into receipt.
- **Default**: encrypt if `encrypted().rid != 0x0…0`.
- **Overrides**: `onValid.encryptLogs` / `onInvalid.encryptLogs`, `logExpireDays` per branch.
- Fail‑closed: if owner/read key missing, no clear‑text emission.

**Reference (ResolveEncryptLogs):**
```go
func ResolveEncryptLogs(rule *ParsedXRC137, isValid bool, encDefault bool) bool {
	// (1) JSON-Override (hat Vorrang)
	if b, ok := tryExtractBool(rule, isValid, "encryptLogs"); ok {
		return b
```

**Reference (ResolveLogExpireDays):**
```go
func ResolveLogExpireDays(rule *ParsedXRC137, isValid bool, defaultDays int) int {
	// (1) JSON-Override (hat Vorrang)
	if n, ok := tryExtractInt(rule, isValid, "logExpireDays"); ok && n > 0 {
		return n
```

**Engine default (excerpt):**
```go
// --- Scope 2 (Logs): Engine verschlüsselt (oder nicht) und schreibt Owner-Grant ---
		// Default: encryptLogs folgt dem Status des XRC-137 (encrypted() != 0).
		// Override: via ResolveEncryptLogs(rule, isValid) → nur Rule-JSON, kein ENV.
		if x.ethRPCURL != "" {
			ruleAddr := meta.RuleContract
			// Bereits geparste/entschlüsselte Regel nutzen, falls vorhanden;
			// fehlt sie, greifen deterministisch die Defaults (kein Nachladen).
			var parsed137 *ParsedXRC137
			if rule != nil {
				parsed137 = rule
			}
			// encrypted()-Fehler blockieren Override nicht; encDefault=false bei Fehler
			encDefault, _ := x.isRuleEncrypted(ruleAddr)
			decEncrypt := ResolveEncryptLogs(parsed137, isValid, encDefault)
			if decEncrypt {
				if extras == nil {
					extras = map[string]any{}
				}
				extras["engineEncryptedRequired"] = true
				// 1) Log-Bundle erzeugen
				logBundle := map[string]any{
					"payload":       spec.PayloadAll,
					"apiSaves":      spec.APISaves,
					"contractSaves": spec.ContractSaves,
				}
				bundleJSON, _ := json.Marshal(logBundle)

				// FAIL-CLOSED BASIS: Sobald die Regel Verschlüsselung verlangt, werden Klartextfelder im Meta entfernt.
				// (Kein Leak von Kundendaten – selbst bei Fehlern nur ErrorTX ohne Nutzdaten.)
				meta.Payload = []byte{}
				meta.APISaves = []byte{}
				meta.ContractSaves = []byte{}

				// 2) Owner-Address bestimmen (für Grants) und Read-Pub (P-256 unkomprimiert, 65B) – BEIDES erforderlich
				ownerStr := strings.ToLower(stri
```


## 12. Validation gas (structure‑driven heuristic)

- Decryption: **30,000 gas**
- Required‑field checks: **1,000** each
- Math ops `+ - * /`: **1,000** each
- Comparisons `== < > …`: **1,000** each
- String helpers: **1,500–3,000**
- Regex checks: **4,000–5,000**
- `saveData` logging: **1,000** per field
- Total is additive; branch split (_common_, _onValid_, _onInvalid_) for budgeting; estimates are **unclamped**.


## 13. JSON rule format — developer concepts

- `payload`: input field declarations (`type`, `optional`, hints)
- `contractReads` / `apiCalls`: augment inputs prior to rules
- `rules`: all must be `true`
- `onValid` / `onInvalid`: payload mapping, optional `execution`, log hints
- Requiredness: `optional:false` ⇒ must exist and be non‑empty


## 14. Full JSON specification (verbatim; unchanged)

# XRC-137 — Technical Specification

> **Scope:** This document defines the XRC-137 JSON rule format and its runtime semantics for a **single validation step** with optional execution. **Expression language details are out of scope** and are covered in the companion document **“XRC-137 Expression Evaluation — Developer Guide.”**

---

## 1) Purpose & Design Goals

* Deterministic, fetch-only rule execution for a single step.
* Uniform authoring across payload, HTTP extracts, branching, and execution metadata.
* JSON-first, engine-agnostic; contracts return rules via `getRule()`/`rule()` and variants.

**Processing pipeline**: `Validate payload → Execute contractReads (on-chain) → Execute apiCalls (fetch) → Evaluate rules → Pick Outcome (onValid/onInvalid) → Optional execution → Receipt persistence`

---

## 2) Top-Level JSON Schema

```json
{
  "payload": { "<Key>": {"type":"string|number|bool|array|object", "optional": false } },
  "contractReads": [ ContractRead, ... ],
  "apiCalls": [ APICall, ... ],
  "rules": [ "<CEL>", ... ],
  "onValid":  Outcome,
  "onInvalid": Outcome,
  "address": "0x..."
}
```

**Notes**

* `payload` declares plain inputs and their requiredness.
* `contractReads` run **before** `apiCalls`; their results merge into inputs and are available to `apiCalls` templates and `rules` (see §4).
* `apiCalls` fetch JSON and write extracted aliases into the inputs map.
* `rules` are boolean expressions; **see companion Expression document** for language and functions.
* Outcomes define optional waits, **output payload mapping (flat)**, an optional execution, **and optional log-policy overrides** (see §7.2).

### 2.1 Top-level fields — parameter reference

| Field           | Type             | Required         | Description                                                                                                                  |
| --------------- | ---------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `payload`       | object           | yes              | Declares input keys available to expressions. Each entry defines `type` (doc hint) and `optional` (requiredness).            |
| `contractReads` | array            | no               | Declarative on-chain reads. ABI-aware (`to`/`function`/`args`) with optional `saveAs` + `defaults` for single/multi returns. |
| `apiCalls`      | array of APICall | no               | HTTP JSON fetches whose extracted aliases are merged into inputs. Executed **after** `contractReads`.                        |
| `rules`         | array of string  | no (recommended) | Boolean expressions; if omitted, validation succeeds when required inputs are present.                                       |
| `onValid`       | Outcome          | no               | Outcome executed when **all** rules evaluate to `true`. Supports **log policy overrides**.                                   |
| `onInvalid`     | Outcome          | no               | Outcome executed when **any** rule is `false` or a required key is missing. Supports **log policy overrides**.               |
| `address`       | string (0x…)     | no               | Authoring aid; target EVM address for UI/display. Engines may ignore at runtime and use `execution.to` instead.              |

---

## 3) Payload (Inputs)

* `type` is descriptive (documentation aid), not strictly enforced at parse time.
* `optional:false` means the key **must exist and be non-empty** before rule evaluation. Empty string/array/map are treated as missing.
* Duplicate input keys from different sources are rejected during merge.

### 3.1 Payload fields — parameter reference

| Property         | Type    | Required | Notes                                                                                     |
| ---------------- | ------- | -------- | ----------------------------------------------------------------------------------------- |
| `<Key>`          | object  | yes      | Declares one input. The map key is the input name (used as `[Key]` in templates).         |
| `<Key>.type`     | string  | no       | Doc hint: `string \| number \| bool \| array \| object`. Engines may use for UI only.     |
| `<Key>.optional` | boolean | yes      | When `false`, missing/empty values send the flow to `onInvalid` without evaluating rules. |

**Requiredness check (summary)**

* Missing or empty required keys → immediate invalid path (rules are not evaluated), unless a `ContinueInvalid` is provided by the orchestrator layer.

---

## 4) Contract Reads

Declarative, ABI-aware reads whose results become inputs and can be persisted. Executed **before** `apiCalls` so their keys are available to API templates and rules.

```json
ContractRead = {
  "to": "0x...",
  "function": "balanceOf(address) returns (uint256)",
  "args": ["<ExprOrLiteral>", ...],
  "saveAs": "Alias" | { "0": "Key0", "1": "Key1", "...": "..." ,
  "rpc": "https://…", // optional; EVM-compatible RPC endpoint override for this read
},
  "defaults": <scalar> | { "0": <fallback0>, "1": <fallback1>, "Key0": <fallbackForKey0>, ... ,
  "rpc": "https://…", // optional; EVM-compatible RPC endpoint override for this read
}
,
  "rpc": "https://…", // optional; EVM-compatible RPC endpoint override for this read
}
```

### 4.1 Semantics

* `to`: **direct EVM address (0x…)**.
* `function`: Solidity signature; determines ABI for args and return tuple.
* `args[i]`: evaluated first, then cast to ABI type.
* Return value is treated as a Solidity **tuple** (even for single return).

  * `saveAs: "Alias"` → persist index **0** under `"Alias"`.
  * `saveAs: { "0": "A", "1": "B", ... }` → persist **multiple indices** under provided keys.
* If `saveAs` is omitted, the engine may still execute the read for evaluation, but **no keys are added/persisted**.

### 4.2 SaveAs for multi-return — details

* Object keys are **stringified non-negative integers** (`"0"`, `"1"`, …).
* Values are non-empty strings naming the keys to write into the inputs map.
* Indices must be within the function’s return arity; otherwise error.

### 4.3 Defaults & errors

* `defaults` provides fallbacks when the read fails (RPC error/revert) **or** when a referenced return index is missing.

  * **Scalar form**: allowed only if `saveAs` is a single string (index `0`). Used as fallback for index `0`.
  * **Object form**: keys may be **tuple indices** ("0", "1", …) **or** the **names** used in `saveAs`. Values are the fallback literals.
  * All indices referenced by `saveAs` **must** be covered by `defaults` to proceed after a read failure; otherwise the engine aborts the step.
  * If the read succeeds but a specific index is out of range, the engine uses the corresponding default (if present) or fails.
* `to` must be a valid 0x address.
* `saveAs` string maps to index `0`; object form must use non-negative integer keys and non-empty string values.
* Arg evaluation/casting errors propagate as rule errors.

### 4.4 Example (reads only)

```

> **Note:** `rpc` must point to an **EVM-compatible** chain endpoint (HTTPS). If omitted, the engine default RPC is used.
json
{
  "contractReads": [
    {
      "to": "0x0000000000000000000000000000000000000001",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA",
      "defaults": 0
    },
    {
      "to": "0x0000000000000000000000000000000000000002",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" },
      "defaults": { "0": 0, "1": 0, "2": 0 }
    }
  ]
}
```

---
## 5) HTTP API Calls (fetch-only, JSON)

```json
APICall = {
  "name": "<id>",
  "method": "GET|POST|PUT|PATCH",
  "urlTemplate": "https://.../path?x=[key]",
  "headers": {"K": "V"},
  "bodyTemplate": "...",
  "contentType": "json",
  "extractMap": {"alias": "<CEL on resp>", ...},
  "defaults": {"alias": <fallback>}
}
```

**Determinism & limits**

* Timeout per call **8 s**; **≤3 redirects**; **response ≤1 MB**; **TLS ≥1.2**; HTTP/1.1 enforced; IPv4 dial only; no proxy from env.
* `contentType` must be **`json`**; array-root **allowed**.
* Each `extractMap` entry is a short **CEL** expression over variable `resp` (the parsed JSON response).
* Extract results are **persisted automatically** if they are **scalar** (`string | number | bool | int`); reduce lists/objects in the expression when needed.
* On evaluation failure, engine uses `defaults[alias]` if present; otherwise the call **fails**.

**Alias rules**

* Regex: `^[A-Za-z][A-Za-z0-9._-]{0,63}$`; must not start with `_` or `sys.`; must be **unique across all `apiCalls`** in the rule.

### 5.1 Placeholders in `urlTemplate` / `bodyTemplate`

* Syntax: `[key]` references `inputs[key]` (payload ∪ contractReads ∪ prior API extracts).
* URL templates **URL-encode** placeholder values; body templates use **raw serialization**.
* Escapes: `[[` → `[` and `]]` → `]`.
* Missing placeholder key ⇒ **error**.
* Complex / non-string values are JSON-serialized for body usage.
* **Important:** `bodyTemplate` is always a **string** (template). If you author JSON, store it as a compact JSON string (e.g., `"{\"id\":\"[User]\"}"`).

### 5.2 APICall fields — parameter reference

| Field          | Type   | Required | Constraints / Notes                                                                                          |
| -------------- | ------ | -------- | ------------------------------------------------------------------------------------------------------------ |
| `name`         | string | yes      | Identifier for logs and alias scoping. Unique per rule. 1–64 chars, regex above.                             |
| `method`       | string | yes      | One of `GET`, `POST`, `PUT`, `PATCH`. Use `GET` for idempotent reads.                                        |
| `urlTemplate`  | string | yes      | Absolute HTTPS URL recommended. May contain `[key]` placeholders. URL-escaped automatically.                 |
| `headers`      | object | no       | String→string map. Avoid auth headers that change per run; prefer static headers.                            |
| `bodyTemplate` | string | no       | For non-GET methods. **String template**; may include placeholders. Serialized as given (no URL-encoding).   |
| `contentType`  | string | yes      | Must be **`json`**. Response body is parsed as JSON (object or array root).                                  |
| `extractMap`   | object | yes      | **Map** of `alias` → CEL expression over `resp`. Result must be **scalar** to be persisted.                  |
| `defaults`     | object | no       | Fallback values per alias when the corresponding extract expression errors.                                  |

### 5.3 Example extracts

```json
{
  "extractMap": {
    "q.symbol": "resp.quote.symbol",
    "q.best_px": "max(resp.quote.venues.map(v, double(v.price.value)))"
  },
  "defaults": {"q.best_px": 0}
}
```
## 6) Rules (Boolean)

* `rules` is an array of boolean expressions. All must evaluate to `true`.
* Missing referenced keys make the individual expression evaluate to `false` (no exception).
* **Expression details (operators, helpers, timeouts, length limits) are documented in “XRC-137 Expression Evaluation — Developer Guide.”**

### 6.1 Rule behavior — parameter reference

| Aspect             | Specification                                                                                                           |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Evaluation order   | Rules are evaluated in listed order; the outcome requires all to be `true`. Engines may short-circuit on first `false`. |
| Missing input keys | Any reference to a missing key yields `false` for that rule.                                                            |
| Return type        | Each rule must return a boolean; non-boolean results are an error.                                                      |
| Length limit       | See Expression guide (authoring limit and timeout).                                                                     |

---

## 7) Outcomes (`onValid` / `onInvalid`)

```json
Outcome = {
  "waitMs": 0,
  "waitUntilMs": 0,
  "payload": { "<outKey>": "<TemplateOrExpr>" },
  "execution": Execution,
  "encryptLogs": true,
  "logExpireDays": 365
}
```

**Waiting**

* `waitUntilMs` (epoch ms) takes precedence; else `waitMs` (relative).
* Non-negative integers only. `0` means “no wait”.

**Output payload mapping**

* Exactly `"[Key]"` → direct copy from inputs.
* Plain strings containing **only** placeholders and text (no operators) → literal placeholder substitution (no expression engine).
* Otherwise → full expression evaluation (same environment as rules). **See companion Expression document** for semantics.

**Meta-only outcomes**

* If `execution` is omitted or has an empty `to`, no inner call is performed; outcome remains metadata-only (receipt still records payload and saves).

### 7.1 Outcome fields — parameter reference

| Field           | Type               | Required | Notes                                                                              |
| --------------- | ------------------ | -------- | ---------------------------------------------------------------------------------- |
| `waitMs`        | integer ≥ 0        | no       | Relative delay before applying the outcome. Ignored if `waitUntilMs` > 0.          |
| `waitUntilMs`   | integer (epoch ms) | no       | Absolute timestamp to apply the outcome. Overrides `waitMs`.                       |
| `payload`       | object             | no       | Output keys to persist. Values can be template strings or expressions.             |
| `execution`     | object             | no       | See §8. When omitted or `to==""`, the outcome is metadata-only.                    |
| `encryptLogs`   | boolean            | no       | **Override** for log encryption in this branch. See §9.2 for defaults & semantics. |
| `logExpireDays` | integer ≥ 1        | no       | **Override** for log grant expiry in days for this branch. Default **365**.        |

### 7.2 Log policy overrides — precedence & defaults

* Overrides are **per branch** (valid vs invalid) and **independent**.
* **Precedence**: If `encryptLogs` is provided in the branch → it **wins**.
  Otherwise the engine uses the **default** derived from the contract’s `encrypted()` status.
  If `encrypted()` is not available or fails, the default is treated as **false**.
* `logExpireDays` (if provided in the branch) must be ≥1. If omitted → **365**.
* Overrides have **no effect** on the rule’s encryption-at-rest; sie betreffen nur die **Log-Persistenz** (siehe §9.2).

---

## 8) Execution

```json
Execution = {
  "to": "0x...",                // optional; empty ⇒ meta-only
  "function": "setMessage(string)",
  "args": ["<ExprOrLiteral>", ...],
  "value": "<ExprOrLiteral>",   // optional; Wei
  "gas": { "limit": 150000 }    // optional
}
```

**Semantics**

* `args[i]` are evaluated then cast to the ABI type of the declared `function` signature.
* `value` is evaluated to a non-negative integer (Wei). If omitted ⇒ 0.
* `gas.limit` (if present) is used as provided.
* When `to` is empty, the engine **must not** send an inner call.

**Error conditions (non-exhaustive)**

* Invalid target address; argument count/type mismatch; casting failures; negative `value`.

### 8.1 Execution fields — parameter reference

| Field       | Type    | Required        | Notes                                                                                     |
| ----------- | ------- | --------------- | ----------------------------------------------------------------------------------------- |
| `to`        | string  | no              | **Direct EVM address**. If empty ⇒ no inner call.                                         |
| `function`  | string  | yes if `to` set | Solidity signature (e.g., `transfer(address,uint256)`). Determines ABI casting of `args`. |
| `args`      | array   | yes if `to` set | Each entry may be a literal or expression. Evaluated at runtime, then ABI-encoded.        |
| `value`     | string  | no              | Expression/literal yielding Wei (uint256). If omitted ⇒ 0.                                |
| `gas.limit` | integer | no              | Base gas limit used if provided.                                                          |

---

## 9) Persistence (Receipt)

* **APISaves**: every `extractMap` alias that evaluates to a **scalar**.
* **ContractSaves**: every key produced via `contractReads.saveAs` (string or map entries).
* **PayloadAll**: final plain payload (non-API, non-contract) after outcome mapping.
* Optional log encryption may be applied by the engine when supported.

### 9.1 Persistence fields — parameter reference

| Bucket          | Source                          | Contains                                       |
| --------------- | ------------------------------- | ---------------------------------------------- |
| `APISaves`      | `apiCalls.extractMap` (scalars) | Scalar extracted values only.                  |
| `ContractSaves` | `contractReads.saveAs`          | Deterministic chain values.                    |
| `PayloadAll`    | Outcome `payload`               | Final authored payload (non-API/non-contract). |

### 9.2 Log encryption & grants (engine behavior)

When a branch dictates encrypted logs (either by override or by default):

* The engine aggregates **`payload` + `APISaves` + `ContractSaves`** to a log bundle and encrypts it (XGR v2):
  **ECDH P-256 + HKDF-SHA256 → AES-GCM**. HKDF `info` binds `version|scope|rid|alg`.
* The engine writes a **log-grant** (scope `2`) for the session **owner** in the `XgrGrants` registry so the owner can decrypt:
  **rights** typically `READ|WRITE` (implementation choice), **expireAt** = `now + logExpireDays * 24h` (default **365**).
* Requirements & failure mode:

  * The **owner** must have a **P-256 Read-Public-Key** registered (uncompressed 65-byte key starting with `0x04`).
    Missing keys or invalid owner addresses lead to a **fail-closed** log path (no plaintext leakage; engine records an error).
  * The engine may reduce metadata in the receipt when encrypting to avoid plaintext exposure.

---

## 10) Limits & Security

* Recommended `apiCalls` per rule ≤ 50.
* HTTP client: IPv4 only, TLS ≥1.2, HTTP/1.1 enforced, no environment proxy.
* Redirects ≤3; response size ≤1 MB.
* Alias collisions across apiCalls are rejected.
* Host allow-listing is engine policy (default open, configurable).

---

## 11) Error Handling (selected)

* **Placeholders**: invalid key syntax, missing keys, unclosed brackets.
* **HTTP**: non-2xx, non-JSON bodies, size/timeout/redirect limits.
* **Extracts**: empty expression, evaluation failure with no `defaults`, non-scalar results.
* **Rules**: syntax error, non-boolean result, timeout, expression length over limit.
* **Execution**: invalid `to`, ABI mismatch, cast errors, negative `value`.
* **Outputs**: missing referenced keys, invalid template substitution, evaluation errors.
* **Contract Reads**: invalid `to`, `saveAs` format, index out of range, arg evaluation/cast failures, missing required `defaults` after read failure.

---

## 12) Engine Integration (Rule Loading)

* Contracts may expose one of: `getRule()`, `rule()`, `getRuleJSON()`, `ruleJSON()` returning the JSON rule.
* Engines should attempt these in order and fall back to the next if empty.
* When a contract returns an `XGR1...` encrypted blob, engines may auto-decrypt via a configured crypto backend using the session owner’s permit.
* After load/decrypt, the engine parses the JSON into a structured `ParsedXRC137` model.

---

## 13) Validation Gas (informative)

* Engines may compute a simple validation-gas estimate (e.g., proportional to the number of rule expressions) for budgeting and logging.

---

## 14) Example (abridged)

```json
{
  "payload": {
    "User":    {"type":"address","optional":false},
    "AmountA": {"type":"number","optional":false},
    "AmountB": {"type":"number","optional":false}
  },
  "contractReads": [
    {
      "to": "0x0000000000000000000000000000000000000001",
      "function": "balanceOf(address) returns (uint256)",
      "args": ["[User]"],
      "saveAs": "BalanceA",
      "defaults": 0
    },
    {
      "to": "0x0000000000000000000000000000000000000002",
      "function": "getReserves() returns (uint112,uint112,uint32)",
      "args": [],
      "saveAs": { "0": "Reserve0", "1": "Reserve1", "2": "ReservesTs" },
      "defaults": { "0": 0, "1": 0, "2": 0 }
    }
  ],
  "apiCalls": [
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
        "q.ask":    "double(resp.quote.ask.value)"
      },
      "defaults": {"q.price":0, "q.bid":0, "q.ask":0}
    }
  ],
  "rules": [
    "[AmountA] > 0",
    "[AmountB] > 0",
    "[q.price] > 0",
    "[BalanceA] >= [AmountA]"
  ],
  "onValid": {
    "waitMs": 50000,
    "encryptLogs": true,
    "logExpireDays": 30,
    "payload": {
      "AmountA": "[AmountA]-[AmountB]",
      "AmountB": "[AmountB]",
      "fromApi": "[q.symbol]",
      "reserves": "{'r0': [Reserve0], 'r1': [Reserve1], 'ts': [ReservesTs]}"
    },
    "execution": {
      "to": "0x0000000000000000000000000000000000000003",
      "function": "setMessage(string)",
      "args": ["'Balance: ' + string([BalanceA])"],
      "value": "0",
      "gas": { "limit": 150000 }
    }
  },
  "onInvalid": {
    "waitMs": 1000,
    "encryptLogs": false,
    "payload": {"memo":"invalid-path","error":"Amount"}
  },
  "address": "0x7863b2E0Cb04102bc3758C8A70aC88512B46477C"
}
```

---

## 15) Versioning & Compatibility

* This document describes XRC-137 **v0.2**. Future versions may add fields while preserving existing ones. Engines should ignore unknown fields and treat missing new fields as defaults to maintain forward compatibility.

---

### Companion document

For the expression language (operators, helpers, placeholder rewriting, timeouts, limits, scalar persistence rules, etc.), read **“XRC-137 Expression Evaluation — Developer Guide.”**




## 15. ABI reference (for `eth_call` & tooling)

| Signature | Returns | Purpose |
|---|---|---|
| `getRule()` | `string` | Primary rule getter (JSON or XGR1) |
| `rule()` | `string` | Alias getter |
| `getRuleJSON()` | `string` | Alias getter |
| `ruleJSON()` | `string` | Alias getter |
| `ruleJson()` | `string` | Auto‑getter if `string public ruleJson;` |
| `encrypted()` | `(bytes32 rid, string suite)` | Encryption metadata (non‑zero rid ⇒ encrypted) |
| `owner()` | `address` | Ownership getter (optional) |


**Selectors**: first 4 bytes of `keccak256("<signature>")`.


## 16. Contract compliance checklist

- [ ] Expose at least one string getter (`getRule`/`rule`/`getRuleJSON`/`ruleJSON` or auto `ruleJson()`).
- [ ] Expose `encrypted()`; keep `{ rid, suite }` accurate.
- [ ] `rid==0` ⇒ plaintext; `rid!=0` ⇒ XGR1 and `ruleJson` starts with `XGR1.`.
- [ ] Fire events on update (`RuleUpdated`, `EncryptedSet`, `EncryptedCleared`).
- [ ] Honor branch overrides for log policy in JSON.
- [ ] Quote grant cost and attach `value` for XRC‑563 writes when needed.


## 17. End‑to‑end example (plaintext rule)

**Contract state**: `encrypted.rid = 0x0…0`, `ruleJson = <JSON>`

**Rule JSON**
```json
{
  "payload": { "AmountA": { "type": "number", "optional": false } },
  "rules":   [ "[AmountA] > 0" ],
  "onValid": { "payload": { "memo": "valid-path", "AmountA": "[AmountA] - 10" } },
  "onInvalid": {}
}
```
**Engine (AmountA=42)** → valid; payload `{ "memo": "valid-path", "AmountA": 32 }`; no execution; logs per default/overrides.


## 18. End‑to‑end example (encrypted rule)

**Contract state**: `encrypted.rid = 0xAB…CD`, `encrypted.suite="AESGCM256"`, `ruleJson= XGR1.AESGCM256.<rid>.<base64>`

**Engine**: discovers XGR1 → decrypts via owner grant (scope‑1) → parses JSON → proceeds as in §06–§11. Logs encrypted by default unless branch overrides.


## 19. Engine code anchors (for auditors)

**Encrypted default logic (excerpt)**
```go
// --- Scope 2 (Logs): Engine verschlüsselt (oder nicht) und schreibt Owner-Grant ---
		// Default: encryptLogs folgt dem Status des XRC-137 (encrypted() != 0).
		// Override: via ResolveEncryptLogs(rule, isValid) → nur Rule-JSON, kein ENV.
		if x.ethRPCURL != "" {
			ruleAddr := meta.RuleContract
			// Bereits geparste/entschlüsselte Regel nutzen, falls vorhanden;
			// fehlt sie, greifen deterministisch die Defaults (kein Nachladen).
			var parsed137 *ParsedXRC137
			if rule != nil {
				parsed137 = rule
			}
			// encrypted()-Fehler blockieren Override nicht; encDefault=false bei Fehler
			encDefault, _ := x.isRuleEncrypted(ruleAddr)
			decEncrypt := ResolveEncryptLogs(parsed137, isValid, encDefault)
			if decEncrypt {
				if extras == nil {
					extras = map[string]any{}
				}
				extras["engineEncryptedRequired"] = true
				// 1) Log-Bundle erzeugen
				logBundle := map[string]any{
					"payload":       spec.PayloadAll,
					"apiSaves":      spec.APISaves,
					"contractSaves": spec.ContractSaves,
				}
				bundleJSON, _ := json.Marshal(logBundle)

				// FAIL-CLOSED BASIS: Sobald die Regel Verschlüsselung verlangt, werden Klartextfelder im Meta entfernt.
				// (Kein Leak von Kundendaten – selbst bei Fehlern nur ErrorTX ohne Nutzdaten.)
				meta.Payload = []byte{}
				meta.APISaves = []byte{}
				meta.ContractSaves = []byte{}

				// 2) Owner-Address bestimmen (für Grants) und Read-Pub (P-256 unkomprimiert, 65B) – BEIDES erforderlich
				ownerStr := strings.ToLower(stri
```


## 20. Alignment with XGR Encryption & Grants (XRC‑563)

- RID determines plaintext vs encrypted; **this document follows that rule**.
- Scopes 1/2 and owner read‑key registry are reflected in the log policy and default behavior.
- RPC helper flows (`xgr_encryptXRC137`, `xgr_getEncryptedLogInfo`) are consistent with the encryption guide.


## 21. Doc change log (editorial)

- Unified structure with fixed, monotonic section numbering (01–21) to avoid list resets.
- Integrated full original JSON spec verbatim in §14; no original information removed.
- Added code anchors from loader/parser/core to ground semantics.

