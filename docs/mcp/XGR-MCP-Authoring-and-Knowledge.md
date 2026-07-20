# XGR MCP Gateway — Authoring & Knowledge

**Document ID:** XGR-MCP-AUTHORING-KNOWLEDGE  
**Last updated:** 2026-07-20  
**Audience:** Agent builders, integrators, developers, auditors  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/knowledge`, `xgr-mcp-gateway/src/tools/knowledgeTools.ts`

The gateway contains an agent-readable knowledge and validation layer for XGRChain and XDaLa.

Its purpose is to make sure that an agent drafting an artifact uses the same references, schemas and validation rules as the gateway that checks the result.

Natural-language intent is not considered a deployable artifact until it has been converted into a canonical structure and validated.

---

## Knowledge layers

The gateway exposes four related knowledge layers.

### 1. Canonical documentation

Bundled Markdown documentation can be discovered and retrieved through:

```text
list_xgr_docs
get_xgr_doc
```

This is intended for agent context and explanations.

### 2. Standard references

Supported standards include:

```text
xrc-137
xrc-729
xdala-authoring
xgr-multibundle
```

Use:

```text
list_xgr_standards
get_xgr_standard_reference
get_xgr_standard_schema
list_xgr_standard_examples
get_xgr_standard_example
```

### 3. Authoring rules

Use:

```text
get_xdala_authoring_rules
```

before creating, changing or reviewing:

- XRC-137 rules,
- XRC-729 OSTC structures,
- payload schemas,
- branching rules,
- API calls,
- process bundles,
- Workbench handoffs.

### 4. Validators

Validators convert an agent-generated proposal into a checked artifact or a concrete list of errors and warnings.

## Recommended authoring workflow

### Step 1: Discover the target environment

Use:

```text
get_xgr_network_info
```

to resolve official network, RPC, Explorer, MCP and Faucet information.

### Step 2: Load authoring guidance

Use:

```text
get_xdala_authoring_rules
```

and the relevant standard reference.

### Step 3: Load schemas and examples

Use:

```text
get_xgr_standard_schema
list_xgr_standard_examples
get_xgr_standard_example
```

Examples are guidance, not validation.

### Step 4: Draft the individual rules and orchestration

Draft:

- XRC-137 rule objects per process step,
- XRC-729 OSTC structure,
- explicit valid and invalid branches,
- consistent payload fields across steps.

### Step 5: Validate rule semantics

Use:

```text
validate_xrc137_authoring
validate_xdala_rules
validate_xdala_blueprint
```

before assembling a deployable bundle.

### Step 6: Assemble and validate the MultiBundle

Use:

```text
get_xgr_multibundle_reference
get_xgr_multibundle_schema
validate_xgr_multibundle
```

or the alias:

```text
validate_xdala_bundle
```

### Step 7: Prepare deployment

Only after successful validation, use:

```text
create_xdala_bundle_deploy_handoff
```

### Step 8: Prepare session start separately

A deployed workflow is started through a distinct artifact:

```text
xgr-session-start@1
```

Use:

```text
get_xgr_session_start_schema
validate_xgr_session_start_handoff
create_xdala_session_start_handoff
```

## Knowledge tools

| Tool | Purpose |
|---|---|
| `list_xgr_standards` | List supported knowledge standards. |
| `list_xgr_docs` | List bundled canonical documentation topics. |
| `get_xgr_doc` | Retrieve one canonical Markdown topic. |
| `get_xdala_authoring_rules` | Retrieve the active authoring rules. |
| `get_xgr_standard_reference` | Retrieve a prose standard reference. |
| `get_xgr_standard_schema` | Retrieve a machine-readable standard schema. |
| `list_xgr_standard_examples` | List example names. |
| `get_xgr_standard_example` | Retrieve one concrete example. |
| `get_xgr_multibundle_reference` | Retrieve canonical MultiBundle documentation. |
| `get_xgr_multibundle_schema` | Retrieve the MultiBundle JSON schema. |
| `get_xgr_session_start_schema` | Retrieve the canonical Session Start schema. |

## Validators

### `validate_xrc137_authoring`

Validates a drafted XRC-137 authoring object before it is placed in a process bundle.

Use it to detect malformed:

- payload declarations,
- API calls,
- rule expressions,
- validation structures,
- execution metadata.

### `validate_xdala_rules`

Validates rule expressions against the available placeholder and payload fields.

Use it to detect references to fields that cannot exist at the point where a rule executes.

### `validate_xdala_blueprint`

Validates the process as a connected system:

- XRC-729 entry step,
- referenced XRC-137 rules,
- payload fields produced and consumed between steps,
- valid and invalid branch flow,
- per-step payload consistency.

This validator operates on the authoring blueprint. Its `entryStepId` input identifies the blueprint entry point; it is not a Workbench Session Start field.

### `validate_xgr_multibundle`

Validates canonical:

```text
xgr-multi-bundle@1
```

Use this before creating a bundle-deploy handoff.

### `validate_xdala_bundle`

Alias for:

```text
validate_xgr_multibundle
```

### `validate_xgr_session_start_handoff`

Validates canonical:

```text
xgr-session-start@1
```

including:

```text
type
version
handle
mode
sessions[].orchestration
sessions[].ostcId
sessions[].stepId
sessions[].payload
sessions[].maxTotalGas
chain
execution
signing
security
```

### `validate_xgr_session_start`

Validates the legacy low-level Session Start representation.

Do not use it as a replacement for the canonical Workbench handoff validator.

## Canonical artifact boundaries

### Deployable process

```text
xgr-multi-bundle@1
```

Contains the process definition to deploy:

- XRC-729 orchestration,
- XRC-137 rules,
- deployment relationships and metadata.

It is passed to:

```text
create_xdala_bundle_deploy_handoff
```

### Session start request

```text
xgr-session-start@1
```

Contains the request to start an already deployed process:

- orchestration address,
- OSTC ID,
- start step,
- payload,
- gas limit,
- optional starter and expiry information.

It is passed to:

```text
create_xdala_session_start_handoff
```

Do not embed a Session Start request inside a MultiBundle.

## `entryStepId` versus `stepId`

These concepts occur at different layers.

### Blueprint validation

```text
validate_xdala_blueprint.entryStepId
```

identifies the entry step while validating an undeployed authoring blueprint.

### Workbench Session Start

```text
sessions[].stepId
```

identifies the actual deployed step to start.

A Workbench Session Start request must not use `entryStepId`.

## Runtime inspection before reuse or start

Authoring knowledge alone does not prove that a deployed contract matches an intended artifact.

For deployed workflows, combine knowledge tools with:

```text
get_xrc_contract
read_xrc137_rule_json
read_xrc729_ostc_json
resolve_xrc729_process_graph
get_xrc729_authority
find_startable_xdala_workflows
```

Encrypted runtime rules are not decrypted by the gateway. The user must perform decryption locally when access is available.

## Single source of truth

Runtime knowledge is defined in the gateway code and bundled canonical documentation.

Human-readable pages explain the model, but tool-served schemas, references and validator behavior are authoritative for artifact generation.

Whenever authoring rules or schemas change:

1. update the runtime knowledge source,
2. update examples,
3. update validators,
4. regenerate or review bundled documentation,
5. update this page,
6. run validation tests.
