# XDaLa Hard Limits Specification (XRC-137, XRC-729, CEL)

**Document ID:** XDALA-LIMITS  
**Last updated:** 2026-10-04  
**Audience:** Developers, rule authors, orchestrator developers, auditors  
**Implementation status:** Mainnet  
**Source of truth:** `xgr-network/xgrEngine` — `xdala/limits.go`, XRC parsers and `expr/limits.go`

---

## 1. Scope and rationale

This document specifies the deterministic hard limits ("caps") enforced by the XDaLa Engine for:

- **XRC-137** — rule and validation documents,
- **XRC-729** — orchestration and process graphs,
- **CEL / expression evaluation** — runtime evaluator safety.

These caps are mainnet execution constraints.

They are enforced before execution, during parsing/preflight or during evaluator preparation to ensure:

- bounded CPU and memory usage,
- bounded fan-out and join cardinality,
- bounded log, receipt and database growth,
- deterministic worst-case behavior,
- protection against resource amplification.

A cap violation results in a hard abort.

Limits are deliberately not feature flags.

They define deterministic safety boundaries of the deployed XDaLa runtime.

---

## 2. Implementation source

The canonical XDaLa parser limits are defined in:

```text
xgr-network/xgrEngine
xdala/limits.go
```

The canonical CEL evaluator limits are defined in:

```text
xgr-network/xgrEngine
expr/limits.go
```

The runtime parsers and evaluator enforce these values.

Documentation must not override the active implementation.

---

## 3. Abort semantics

### 3.1 XRC-729 orchestration

XRC-729 caps are enforced during orchestration parsing and Session Start preflight.

A violation causes an early hard abort:

- the JSON-RPC request fails,
- no process is enqueued,
- no valid session is created,
- process execution does not begin.

The limit failure is therefore different from a normal XDaLa business result such as:

```text
onInvalid
```

---

### 3.2 XRC-137 rule documents

XRC-137 caps are enforced when the rule document is loaded and parsed during session execution.

A limit violation produces a hard execution error.

It is not converted into:

```text
onInvalid
```

`onInvalid` represents a valid deterministic business branch.

A hard-limit violation represents an invalid runtime artifact or an execution-safety violation.

---

### 3.3 CEL / expression evaluation

Evaluator caps are enforced:

- on raw expression source length,
- on checked AST node count,
- on list and array sizes in input values.

List limits are applied recursively through nested input structures.

Violations abort expression evaluation deterministically.

---

# XRC-137 limits

## 4. XRC-137 document and schema caps

| Key | Description | Mainnet limit |
| --- | --- | ---: |
| `MaxXRC137Bytes` | Maximum size of the decrypted XRC-137 JSON document | `131072` bytes / 128 KiB |
| `MaxPayloadFields` | Maximum declared payload input fields | `64` |
| `MaxFieldNameLen` | Maximum payload/output field-name length | `64` characters |
| `MaxRules` | Maximum number of entries in `rules[]` | `64` |
| `MaxExprLen` | Maximum XRC parser expression-string length | `2048` characters |

Field names use the deterministic identifier character set:

```text
[A-Za-z0-9_-]
```

Empty identifiers are handled according to the corresponding schema/parser context.

---

## 5. XRC-137 API caps

| Key | Description | Mainnet limit |
| --- | --- | ---: |
| `MaxAPICalls` | Maximum number of entries in `apiCalls[]` | `16` |
| `MaxURLTemplateLen` | Maximum `urlTemplate` length | `2048` characters |
| `MaxBodyTemplateLen` | Maximum `bodyTemplate` length | `8192` characters |
| `MaxExtractMapEntries` | Maximum extract entries per `apiCalls[i].extractMap` | `64` |
| `MaxStringValueLen` | Maximum governed string value/default length | `8192` characters |

Each governed `extractMap` identifier remains subject to the field-name limits and deterministic ASCII identifier rules.

Expression strings validated through the XRC parser remain subject to:

```text
MaxExprLen = 2048
```

---

## 6. XRC-137 contract-read caps

| Key | Description | Mainnet limit |
| --- | --- | ---: |
| `MaxContractReads` | Maximum number of entries in `contractReads[]` | `16` |
| `MaxContractReadSaveAs` | Maximum number of `saveAs` targets per contract read | `64` |
| `MaxStringValueLen` | Maximum governed string default/value length | `8192` characters |

Contract-read limits bound both the number of external EVM reads and the amount of data projected into the XDaLa process context.

---

## 7. XRC-137 branch outcome caps

The same deterministic limits apply to the corresponding governed structures in:

```text
onValid
```

and:

```text
onInvalid
```

| Key | Description | Mainnet limit |
| --- | --- | ---: |
| `MaxOutcomeKeys` | Maximum number of governed output payload keys per branch | `64` |
| `MaxGrants` | Maximum number of grants per branch | `16` |
| `MaxExecArgs` | Maximum number of `execution.args[]` entries per branch | `16` |
| `MaxStringValueLen` | Maximum governed string payload value length | `8192` characters |

These limits bound the size of branch output, authorization metadata and optional execution construction.

---

## 8. Complete XRC-137 default limit set

The active default parser limit set is:

```text
DefaultMaxXRC137Bytes        = 128 * 1024
DefaultMaxPayloadFields      = 64
DefaultMaxFieldNameLen       = 64
DefaultMaxAPICalls           = 16
DefaultMaxContractReads      = 16
DefaultMaxRules              = 64
DefaultMaxExprLen            = 2048
DefaultMaxURLTemplateLen     = 2048
DefaultMaxBodyTemplateLen    = 8 * 1024
DefaultMaxExtractMapEntries  = 64
DefaultMaxContractReadSaveAs = 64
DefaultMaxOutcomeKeys        = 64
DefaultMaxGrants             = 16
DefaultMaxExecArgs           = 16
DefaultMaxStringValueLen     = 8 * 1024
```

These values are returned by the XDaLa engine's default limit configuration.

---

# XRC-729 limits

## 9. XRC-729 document cap

| Key | Description | Mainnet limit |
| --- | --- | ---: |
| `MaxOSTCBytes` | Maximum size of raw OSTC JSON | `262144` bytes / 256 KiB |

The document-size limit is checked before an oversized orchestration can become an active process graph.

---

## 10. XRC-729 graph caps

| Key | Description | Mainnet limit |
| --- | --- | ---: |
| `MaxSteps` | Maximum number of steps in `structure` | `128` |
| `MaxStepIdLen` | Maximum step-ID length | `64` characters |
| `MaxSpawnsPerBranch` | Maximum spawn edges per branch | `32` |
| `MaxJoinInputs` | Maximum `join.from[]` inputs per join | `32` |

The spawn limit applies independently to governed:

```text
onValid.spawns
```

and:

```text
onInvalid.spawns
```

Step IDs, spawn targets, join IDs and governed `join.from[].node` identifiers use deterministic ASCII identifier rules.

The limits are applied during orchestration parsing/preflight.

A violation prevents the process graph from being accepted for execution.

---

## 11. Complete XRC-729 default limit set

The active default orchestration limit set is:

```text
DefaultMaxOSTCBytes       = 256 * 1024
DefaultMaxSteps           = 128
DefaultMaxStepIdLen       = 64
DefaultMaxSpawnsPerBranch = 32
DefaultMaxJoinInputs      = 32
```

---

# Expression evaluator limits

## 12. CEL / expression safety caps

The expression evaluator has an independent limit layer.

Canonical implementation:

```text
xgr-network/xgrEngine
expr/limits.go
```

Current mainnet defaults:

| Key | Description | Mainnet limit |
| --- | --- | ---: |
| `MaxExprLen` | Maximum raw CEL source length | `1024` bytes |
| `MaxAstNodes` | Maximum checked AST node count | `4096` |
| `MaxListCap` | Maximum list/array size anywhere in evaluator inputs | `64` |

---

## 13. XRC parser expression limit versus CEL evaluator limit

Two different expression-length limits exist at different layers.

XRC parser:

```text
MaxExprLen = 2048 characters
```

CEL evaluator:

```text
MaxExprLen = 1024 bytes
```

These values are not interchangeable.

The XRC parser limit bounds expression-bearing document fields at the XDaLa schema/parser layer.

The CEL evaluator independently applies its stricter raw-source limit before evaluation.

Therefore a rule can satisfy the XRC document parser's expression-length boundary while still being rejected by the expression evaluator.

The effective executable expression must satisfy both layers.

Conceptually:

```text
XRC document parsing
        │
        │ MaxExprLen = 2048 characters
        ▼
expression evaluator
        │
        │ MaxExprLen = 1024 bytes
        │ MaxAstNodes = 4096
        │ MaxListCap = 64
        ▼
evaluation
```

---

## 14. Checked AST limit

After CEL parsing/checking, the evaluator counts nodes in the checked expression tree.

Maximum:

```text
4096 nodes
```

The count includes supported expression structures such as:

- constants,
- identifiers,
- selects,
- calls,
- lists,
- structs/maps,
- comprehensions,
- nested operands and arguments.

An expression exceeding the AST limit is rejected before normal evaluation proceeds.

This prevents a short textual expression from bypassing complexity controls through an excessively large parsed structure.

---

## 15. Recursive list and array cap

The evaluator enforces:

```text
MaxListCap = 64
```

for lists and arrays found anywhere in evaluator input values.

Enforcement recursively traverses:

- slices,
- arrays,
- maps,
- exported struct fields,
- pointer/interface wrappers.

For example, this is governed even when the oversized list is deeply nested:

```text
payload
  └── object
       └── values[]
```

The limit is therefore not restricted to top-level payload arrays.

---

# Error semantics

## 16. XDaLa parser limit errors

XRC parser and preflight limit violations use:

```text
ErrLimitsExceeded
```

The canonical error identity is:

```text
xdala limits exceeded
```

Limit errors include:

- the violated cap/context,
- the observed value,
- the maximum value.

The implementation uses deterministic formats equivalent to:

```text
xdala limits exceeded: <cap>=<observed> max=<maximum>
```

or for governed string lengths:

```text
xdala limits exceeded: <cap> len=<observed> max=<maximum>
```

Example:

```text
xdala limits exceeded: xrc137_bytes=131073 max=131072
```

Such an error is a hard limit failure.

It must not be interpreted as an XRC-137 `onInvalid` business result.

---

## 17. Expression-layer limit errors

The expression layer uses dedicated deterministic errors for evaluator safety limits.

Examples include:

```text
ErrExprTooComplex
```

and:

```text
ErrListCapExceeded
```

For an oversized checked AST, the error includes:

```text
ast nodes=<observed> max=4096
```

For an oversized list/array, the error includes:

```text
len=<observed> max=64
```

These are evaluator failures, not boolean rule outcomes.

---

# Determinism and security

## 18. Why limits are deterministic

The hard caps are based on deterministic properties such as:

- byte size,
- character count,
- element count,
- graph cardinality,
- checked AST node count,
- nested list size.

They do not depend on:

- host CPU speed,
- wall-clock timeout,
- scheduler behavior,
- current server load.

This makes limit enforcement predictable across equivalent engine executions.

---

## 19. Resource-amplification protection

The limits constrain several forms of potential resource amplification.

### Document amplification

Bounded by:

```text
MaxXRC137Bytes
MaxOSTCBytes
MaxStringValueLen
```

### Process graph amplification

Bounded by:

```text
MaxSteps
MaxSpawnsPerBranch
MaxJoinInputs
```

### External-read amplification

Bounded by:

```text
MaxAPICalls
MaxContractReads
MaxExtractMapEntries
MaxContractReadSaveAs
```

### Expression amplification

Bounded by:

```text
CEL MaxExprLen
MaxAstNodes
MaxListCap
```

### Outcome/execution amplification

Bounded by:

```text
MaxOutcomeKeys
MaxGrants
MaxExecArgs
```

---

## 20. Hard limits versus ValidationGas

Hard limits and ValidationGas are separate mechanisms.

Hard limits define absolute execution boundaries.

ValidationGas models validation and processing work.

Therefore:

```text
within ValidationGas budget
```

does not permit a document to exceed a hard cap.

Likewise:

```text
below every hard cap
```

does not imply that an operation has unlimited ValidationGas.

Both systems can independently constrain execution.

Detailed ValidationGas behavior is documented in:

```text
XRC-137_Validation_Gas.md
```

---

## 21. Hard abort versus business invalidation

This distinction is fundamental.

### Business invalidation

Example:

```text
rules[] evaluates false
```

Result:

```text
onInvalid
```

This is a normal process outcome.

### Hard-limit violation

Example:

```text
rules[] contains more than 64 entries
```

Result:

```text
hard abort
```

The process must not continue through `onInvalid`.

A safety constraint cannot be converted into a business branch.

---

# Authoring guidance

## 22. Do not design at the absolute cap

Although the listed values are valid maximums, rule and orchestration authors should normally remain comfortably below them.

This provides room for:

- future rule changes,
- additional process branches,
- payload evolution,
- execution metadata,
- easier auditing,
- simpler testing.

The caps are safety boundaries, not recommended target sizes.

---

## 23. Split oversized workflows

When an orchestration approaches:

```text
MaxSteps = 128
```

or individual branches approach:

```text
MaxSpawnsPerBranch = 32
```

consider decomposing the process into clearer logical components where the application model permits it.

The hard limit must not be bypassed by runtime tricks.

---

## 24. Validate before deployment

XRC artifacts should be validated before deployment or Session Start.

Agent-assisted integrations can use the XGR MCP validation and authoring tools.

Public MCP endpoint:

```text
https://mcp.xgr.network/mcp
```

Local or CI validation should use the same canonical schemas and limits as the deployed engine wherever possible.

---

# Mainnet status

## 25. Current implementation state

The limits in this document describe deployed XDaLa mainnet behavior.

| Area | Status |
| --- | --- |
| XRC-137 hard limits | Mainnet |
| XRC-729 hard limits | Mainnet |
| CEL raw expression cap | Mainnet |
| CEL AST complexity cap | Mainnet |
| Recursive input list cap | Mainnet |
| Deterministic hard-abort semantics | Mainnet |

The canonical implementation remains authoritative.

---

# Source-of-truth hierarchy

## 26. Canonical sources

For XRC parser limits:

```text
xgr-network/xgrEngine
xdala/limits.go
```

For expression evaluator limits:

```text
xgr-network/xgrEngine
expr/limits.go
```

Parser/preflight implementation determines where each cap is applied.

Public specification:

```text
xgr-network/XGR
docs/XDaLa_Limits.md
```

If documentation and the deployed implementation ever differ, the implementation must be investigated and the documentation corrected.

---

## 27. Update triggers

This document must be reviewed whenever any of the following changes:

- XRC-137 parser limits,
- XRC-729 parser limits,
- identifier validation,
- expression source limits,
- CEL AST complexity limits,
- recursive list limits,
- hard-abort semantics,
- ValidationGas interaction,
- Session Start preflight behavior.

Limit changes are security- and compatibility-relevant and must not be made silently.

---

## 28. Summary

### XRC-137

```text
Document size              128 KiB
Payload fields             64
Field-name length          64
API calls                  16
Contract reads             16
Rules                      64
Parser expression length   2048 characters
URL template               2048 characters
Body template              8192 characters
Extract-map entries        64
Contract-read saveAs       64
Outcome keys               64
Grants                     16
Execution arguments        16
Governed string value      8192 characters
```

### XRC-729

```text
OSTC size                  256 KiB
Steps                      128
Step-ID length             64
Spawns per branch          32
Join inputs                32
```

### CEL / expression evaluator

```text
Raw expression length      1024 bytes
Checked AST nodes          4096
List/array size            64
```

These are deterministic mainnet hard limits.

Exceeding them causes a hard abort rather than a normal business-level invalid result.
