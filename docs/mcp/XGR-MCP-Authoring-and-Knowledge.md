# XGR MCP Gateway — Authoring & Knowledge

**Document ID:** XGR-MCP-AUTHORING-KNOWLEDGE  
**Last updated:** 2026-08-15  
**Audience:** Agent builders, integrators, developers, auditors  
**Implementation status:** Live  
**Source of truth:** [`xgr-network/xgr-mcp/src/knowledge`](https://github.com/xgr-network/xgr-mcp/tree/main/src/knowledge)

The XGR MCP Gateway contains an agent-readable knowledge and validation layer for XGRChain and XDaLa.

Its purpose is to ensure that an agent drafting XRC artifacts or XDaLa workflows uses the same references, schemas and validation rules as the gateway that validates the resulting structures.

Natural-language intent is not deployable until it has been converted into a canonical artifact and validated.

---

## Knowledge layers

The gateway exposes four related knowledge layers.

### 1. Canonical documentation

```text
list_xgr_docs
get_xgr_doc
```

These tools expose bundled canonical Markdown documentation for agent context and explanations.

---

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

References explain semantics.

Schemas define machine-readable structure.

Examples demonstrate valid patterns but are not themselves validation.

---

### 3. Authoring rules

Use:

```text
get_xdala_authoring_rules
```

before creating, changing or reviewing:

- XRC-137 rules,
- XRC-729 OSTC structures,
- payload schemas,
- branch rules,
- API calls,
- contract reads,
- process bundles,
- Workbench handoffs.

The authoring rules are intended to prevent structurally valid but semantically invalid workflows.

---

### 4. Validators

Validators convert an agent-generated proposal into:

- a checked canonical artifact,
- warnings,
- concrete validation errors.

The main validators are:

```text
validate_xrc137_authoring
validate_xdala_rules
validate_xdala_blueprint
validate_xgr_multibundle
validate_xgr_session_start_handoff
```

Validation must occur before execution handoff.

---

# Recommended authoring workflow

## Step 1 — Discover the target environment

Call:

```text
get_xgr_network_info
get_chain_status
```

Resolve:

- network,
- chain ID,
- RPC,
- Explorer,
- MCP endpoint,
- Workbench environment.

Do not assume that Mainnet, Testnet and Devnet use the same addresses or deployment state.

---

## Step 2 — Load authoring guidance

Call:

```text
get_xdala_authoring_rules
get_xgr_standard_reference
```

Load the relevant standard before drafting the artifact.

For example:

```text
xrc-137
xrc-729
xgr-multibundle
```

---

## Step 3 — Load schemas and examples

Use:

```text
get_xgr_standard_schema
list_xgr_standard_examples
get_xgr_standard_example
```

Schemas define the canonical structure.

Examples are guidance only.

An example that resembles the intended process must still pass the active validators.

---

## Step 4 — Draft XRC-137 rules

A process step normally references an XRC-137 rule describing its validation and execution behavior.

Draft explicit definitions for:

- payload fields,
- optional fields,
- defaults,
- rule expressions,
- API calls,
- contract reads,
- save operations,
- valid execution branches,
- invalid execution branches.

Avoid relying on undeclared payload fields.

---

## Step 5 — Draft XRC-729 orchestration

The XRC-729 OSTC defines the process structure.

It should identify:

- entry step,
- step relationships,
- valid branches,
- invalid branches,
- referenced XRC-137 rules,
- process transitions.

The orchestration and its XRC-137 rules must be treated as one connected process model.

---

## Step 6 — Validate rule semantics

Call:

```text
validate_xrc137_authoring
validate_xdala_rules
validate_xdala_blueprint
```

These validators address different layers.

### `validate_xrc137_authoring`

Checks a drafted XRC-137 authoring object.

It detects malformed or inconsistent:

- payload declarations,
- API calls,
- contract reads,
- rule expressions,
- validation structures,
- execution metadata.

### `validate_xdala_rules`

Validates expressions against the fields that can actually exist at execution time.

It detects references to unavailable payload or placeholder values.

### `validate_xdala_blueprint`

Validates the process as a connected workflow.

It checks:

- XRC-729 entry step,
- referenced XRC-137 rules,
- produced payload fields,
- consumed payload fields,
- valid branch flow,
- invalid branch flow,
- per-step payload consistency.

Its:

```text
entryStepId
```

input describes the entry point of an undeployed authoring blueprint.

It is not a Workbench Session Start field.

---

## Step 7 — Assemble the MultiBundle

The canonical deployable process artifact is:

```text
xgr-multi-bundle@1
```

Use:

```text
get_xgr_multibundle_reference
get_xgr_multibundle_schema
validate_xgr_multibundle
```

Alias:

```text
validate_xdala_bundle
```

The MultiBundle contains the deployable relationship between:

- XRC-729 orchestration,
- XRC-137 rules,
- deployment metadata,
- process metadata.

Do not embed a Session Start request inside a MultiBundle.

Deployment and Session Start are separate lifecycle stages.

---

## Step 8 — Check deployment-wallet state

Before preparing deployment, inspect the intended signer:

```text
get_account_live_state
```

This determines whether the address:

- exists,
- has native XGR,
- has deployed code,
- has a usable nonce state.

If an eligible low-balance address requires gas and the starter-gas service is enabled, the separate starter-gas tools may be used.

Starter gas only provides native XGR.

It does not authorize or execute deployment.

---

## Step 9 — Prepare deployment handoff

After the MultiBundle passes validation:

```text
create_xdala_bundle_deploy_handoff
```

The gateway prepares the validated deployment artifact.

The user reviews and signs through xDaLa Workbench or the configured local signer.

The MCP does not sign the deployment transaction.

---

# Runtime inspection after deployment

Once a workflow has been deployed, authoring artifacts alone are no longer sufficient proof of the active runtime configuration.

Inspect the deployed contracts using:

```text
get_xrc_contract
read_xrc137_rule_json
read_xrc729_ostc_json
resolve_xrc729_process_graph
```

Use:

```text
get_xrc729_authority
find_startable_xdala_workflows
list_xrc729_contracts_by_executor
```

to determine who is authorized to start the deployed workflow.

The deployed runtime state is authoritative.

A local draft or historical bundle must not be assumed to match the current deployed contract.

---

# Preparing Session Start

A deployed workflow is started using the canonical format:

```text
xgr-session-start@1
```

Use:

```text
get_xgr_session_start_schema
validate_xgr_session_start_handoff
create_xdala_session_start_handoff
```

The main canonical session fields are:

```text
sessions[].orchestration
sessions[].ostcId
sessions[].stepId
sessions[].payload
sessions[].maxTotalGas
```

Optional fields may include:

```text
sessions[].ostcHash
sessions[].starterAddress
sessions[].expiry
```

---

## `entryStepId` versus `stepId`

These fields belong to different contexts.

### Authoring blueprint

```text
validate_xdala_blueprint.entryStepId
```

identifies the entry point of an undeployed process blueprint.

### Runtime Session Start

```text
sessions[].stepId
```

identifies the deployed step that will be started.

Do not use:

```text
entryStepId
```

as a Workbench Session Start field.

---

# Resolving Session Start payloads

Before creating a Session Start request:

1. resolve the deployed XRC-729 contract,
2. resolve the OSTC,
3. identify the entry step,
4. inspect the linked XRC-137 runtime rule,
5. derive required payload fields,
6. derive optional payload fields,
7. identify defaults,
8. ask the user for unresolved required business values,
9. validate the resulting Session Start request.

Relevant tools include:

```text
read_xrc729_ostc_json
read_xrc137_rule_json
resolve_xrc729_process_graph
validate_xgr_session_start_handoff
```

Do not invent business payload values.

---

# Historical Session Start payload evidence

The current MCP additionally exposes:

```text
get_xdala_start_payload_history
```

This tool provides read-only indexed evidence of scalar payload values previously observed when starting a specific XRC-729 OSTC entry step.

It may be used after the following have been resolved:

```text
xrc729Address
ostcId
stepId
```

Optional filters include:

```text
owner
windowHours
limit
```

The tool can help with:

- UI value suggestions,
- recognizing frequently used values,
- assisting an operator with repetitive workflows,
- comparing a proposed value with historical usage.

It does not change the canonical authoring or validation model.

Historical values are not:

- current schema defaults,
- required field definitions,
- authorization,
- validation,
- proof that the same value should be used again.

The correct precedence is:

```text
current deployed runtime
        ↓
current XRC-137 payload schema
        ↓
explicit schema defaults
        ↓
explicit user or authorized system input
        ↓
historical evidence as optional context
```

Historical evidence must never silently override a current schema or user input.

---

# Wake-up payloads

A running XDaLa process may stop at a waiting step.

Use:

```text
list_wakeup_targets_by_address
resolve_wakeup_payload_schema
```

to determine:

- which waiting steps an address may wake,
- required wake-up fields,
- optional wake-up fields,
- defaults,
- unresolved required values.

A wake-up payload must be derived from the active waiting step.

Do not reuse Session Start payload assumptions automatically for later wake-up steps.

---

# Canonical artifact boundaries

## XRC-137 rule

Defines one process rule or step behavior.

It may contain:

- payload declarations,
- validations,
- API calls,
- contract reads,
- expressions,
- save operations,
- execution behavior.

---

## XRC-729 orchestration

Defines the workflow structure and step relationships.

It references process steps and controls orchestration flow.

---

## MultiBundle

Canonical format:

```text
xgr-multi-bundle@1
```

Purpose:

```text
deployment
```

Passed to:

```text
create_xdala_bundle_deploy_handoff
```

---

## Session Start

Canonical format:

```text
xgr-session-start@1
```

Purpose:

```text
start an already deployed workflow
```

Passed to:

```text
create_xdala_session_start_handoff
```

---

## Starter-gas request

A starter-gas request is not:

- an XRC artifact,
- a MultiBundle,
- a Session Start request,
- a deployment handoff.

It only funds an eligible address with native XGR.

It does not authorize any later action.

---

## Historical payload query

A historical payload query is not:

- an authoring artifact,
- a deployment artifact,
- a Session Start request,
- a validator.

It is read-only indexed evidence.

---

# Reuse of deployed rules

The MCP can help identify existing XRC-137 rules through:

```text
find_reusable_xrc137_rules
get_unused_xrc137_rules
get_xrc_usage
```

Reuse candidates are advisory.

Before reusing a deployed rule:

1. inspect the actual deployed contract,
2. read the active rule,
3. verify its payload schema,
4. verify its rule semantics,
5. verify that it matches the new process requirements.

Use:

```text
read_xrc137_rule_json
```

for runtime inspection.

A similar name or historical usage is not sufficient proof of compatibility.

---

# Encrypted runtime rules

Encrypted runtime XRC-137 content is not decrypted by the MCP Gateway.

The gateway must not request or receive the user's private decryption key.

User-authorized decryption remains local to the user's wallet or client environment.

Therefore an encrypted runtime rule may limit what an agent can independently inspect.

---

# Gas versus authority

Native XGR balance and workflow authority are separate properties.

An address may:

- have authority but insufficient gas,
- have gas but no authority,
- have both,
- have neither.

Use:

```text
get_account_live_state
```

for native XGR balance.

Use:

```text
get_xrc729_authority
find_startable_xdala_workflows
```

for workflow-start authority.

A successful starter-gas grant does not provide:

- contract ownership,
- executor status,
- Session Start authority,
- signing authority,
- payload authorization.

---

# Evidence versus authoring

The MCP combines several information classes.

They must not be confused.

### Knowledge

Examples:

```text
standard references
schemas
authoring rules
examples
```

Purpose:

```text
define how artifacts should be constructed
```

### Runtime state

Examples:

```text
deployed XRC-137 rule
deployed XRC-729 OSTC
authority state
```

Purpose:

```text
describe the active deployed system
```

### Indexed evidence

Examples:

```text
session history
receipts
payload history
transaction history
```

Purpose:

```text
describe observed historical activity
```

### Validation

Examples:

```text
validate_xrc137_authoring
validate_xdala_blueprint
validate_xgr_multibundle
validate_xgr_session_start_handoff
```

Purpose:

```text
determine whether a proposed artifact satisfies the active structural and semantic rules
```

Historical evidence does not replace validation.

Examples do not replace validation.

A local draft does not replace runtime inspection.

---

# Knowledge tool summary

| Tool | Purpose |
|---|---|
| `list_xgr_standards` | List supported standards. |
| `list_xgr_docs` | List canonical documentation topics. |
| `get_xgr_doc` | Retrieve one canonical Markdown topic. |
| `get_xdala_authoring_rules` | Retrieve active XDaLa authoring rules. |
| `get_xgr_standard_reference` | Retrieve a prose standard reference. |
| `get_xgr_standard_schema` | Retrieve a machine-readable schema. |
| `list_xgr_standard_examples` | List examples for a standard. |
| `get_xgr_standard_example` | Retrieve one example. |
| `get_xgr_multibundle_reference` | Retrieve MultiBundle documentation. |
| `get_xgr_multibundle_schema` | Retrieve the MultiBundle schema. |
| `get_xgr_session_start_schema` | Retrieve the Session Start schema. |

---

# Validator summary

| Tool | Purpose |
|---|---|
| `validate_xrc137_authoring` | Validate an XRC-137 authoring object. |
| `validate_xdala_rules` | Validate rule expressions against available fields. |
| `validate_xdala_blueprint` | Validate orchestration and cross-step payload flow. |
| `validate_xgr_multibundle` | Validate canonical `xgr-multi-bundle@1`. |
| `validate_xdala_bundle` | Alias for MultiBundle validation. |
| `validate_xgr_session_start_handoff` | Validate canonical `xgr-session-start@1`. |
| `validate_xgr_session_start` | Validate the legacy low-level Session Start representation. |

---

# Single source of truth

The public MCP implementation is maintained in:

```text
https://github.com/xgr-network/xgr-mcp
```

Canonical XGR and XDaLa specifications and documentation are maintained in:

```text
https://github.com/xgr-network/XGR
```

The implementation repository defines what the currently deployed MCP tools actually do.

The XGR documentation repository defines the public specifications and reference material.

Both should be kept synchronized whenever MCP tool contracts or semantics change.
