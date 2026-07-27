# XGR MCP Gateway — Authoring & Knowledge

**Document ID:** XGR-MCP-AUTHORING-KNOWLEDGE  
**Last updated:** 2026-07-26  
**Audience:** Agent builders, integrators, developers, auditors  
**Implementation status:** Live  
**Source of truth:** [`xgr-network/xgr-mcp/src/knowledge`](https://github.com/xgr-network/xgr-mcp/tree/main/src/knowledge)

The gateway contains an agent-readable knowledge and validation layer for XGRChain and XDaLa.

Its purpose is to ensure that an agent drafting an artifact uses the same references, schemas and validation rules as the gateway that checks the result.

Natural-language intent is not deployable until it has been converted into a canonical structure and validated.

---

## Knowledge layers

The gateway exposes four related knowledge layers.

### 1. Canonical documentation

```text
list_xgr_docs
get_xgr_doc
```

These tools expose bundled canonical Markdown for agent context and explanations.

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
- branch rules,
- API calls,
- contract reads,
- process bundles,
- Workbench handoffs.

### 4. Validators

Validators convert an agent-generated proposal into:

- a checked canonical artifact,
- warnings,
- concrete validation errors.

## Recommended authoring workflow

### Step 1: Discover the target environment

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

### Step 2: Load authoring guidance

```text
get_xdala_authoring_rules
get_xgr_standard_reference
```

### Step 3: Load schemas and examples

```text
get_xgr_standard_schema
list_xgr_standard_examples
get_xgr_standard_example
```

Examples are guidance, not validation.

### Step 4: Draft individual rules and orchestration

Draft:

- one XRC-137 rule per process step,
- the XRC-729 OSTC structure,
- explicit valid branches,
- explicit invalid branches,
- consistent payload fields.

### Step 5: Validate rule semantics

```text
validate_xrc137_authoring
validate_xdala_rules
validate_xdala_blueprint
```

### Step 6: Assemble and validate the MultiBundle

```text
get_xgr_multibundle_reference
get_xgr_multibundle_schema
validate_xgr_multibundle
```

Alias:

```text
validate_xdala_bundle
```

### Step 7: Check deployment-wallet gas

Before preparing deployment, inspect the intended signer:

```text
get_account_live_state
```

When the address lacks native XGR and starter gas is available:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

The starter-gas request is separate from the deployment artifact.

It does not sign or deploy the bundle.

### Step 8: Prepare deployment

After successful validation:

```text
create_xdala_bundle_deploy_handoff
```

The user reviews and signs in xDaLa Workbench.

### Step 9: Prepare Session Start separately

A deployed workflow is started through:

```text
xgr-session-start@1
```

Use:

```text
get_xgr_session_start_schema
validate_xgr_session_start_handoff
create_xdala_session_start_handoff
```

Before Session Start, the intended starter may again be checked with:

```text
get_account_live_state
```

Starter gas may fund an eligible address, but it never replaces the Session Start handoff or user signature.

## Knowledge tools

| Tool | Purpose |
|---|---|
| `list_xgr_standards` | List supported standards. |
| `list_xgr_docs` | List canonical documentation topics. |
| `get_xgr_doc` | Retrieve one Markdown topic. |
| `get_xdala_authoring_rules` | Retrieve active authoring rules. |
| `get_xgr_standard_reference` | Retrieve a prose reference. |
| `get_xgr_standard_schema` | Retrieve a machine-readable schema. |
| `list_xgr_standard_examples` | List examples. |
| `get_xgr_standard_example` | Retrieve one example. |
| `get_xgr_multibundle_reference` | Retrieve MultiBundle documentation. |
| `get_xgr_multibundle_schema` | Retrieve the MultiBundle schema. |
| `get_xgr_session_start_schema` | Retrieve the Session Start schema. |

## Validators

### `validate_xrc137_authoring`

Validates a drafted XRC-137 authoring object.

It detects malformed:

- payload declarations,
- API calls,
- contract reads,
- rule expressions,
- validation structures,
- execution metadata.

### `validate_xdala_rules`

Validates rule expressions against available payload and placeholder fields.

It detects references to fields that cannot exist at execution time.

### `validate_xdala_blueprint`

Validates the process as a connected system:

- XRC-729 entry step,
- referenced XRC-137 rules,
- produced and consumed payload fields,
- valid and invalid branch flow,
- per-step payload consistency.

Its `entryStepId` input identifies the undeployed blueprint entry point.

It is not a Workbench Session Start field.

### `validate_xgr_multibundle`

Validates:

```text
xgr-multi-bundle@1
```

before a bundle-deploy handoff is created.

### `validate_xdala_bundle`

Alias for:

```text
validate_xgr_multibundle
```

### `validate_xgr_session_start_handoff`

Validates:

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

It is not a substitute for the canonical Workbench validator.

## Canonical artifact boundaries

### Deployable process

```text
xgr-multi-bundle@1
```

Contains:

- XRC-729 orchestration,
- XRC-137 rules,
- deployment relationships,
- metadata.

It is passed to:

```text
create_xdala_bundle_deploy_handoff
```

### Session Start request

```text
xgr-session-start@1
```

Contains:

- orchestration address,
- OSTC ID,
- start step,
- payload,
- gas limit,
- optional starter,
- optional expiry.

It is passed to:

```text
create_xdala_session_start_handoff
```

Do not embed a Session Start request inside a MultiBundle.

### Starter-gas request

A starter-gas request is neither:

- a MultiBundle,
- a Session Start request,
- a handoff.

It contains only:

```text
address
purpose
```

It may fund the intended wallet but does not authorize any later transaction.

## `entryStepId` versus `stepId`

### Blueprint validation

```text
validate_xdala_blueprint.entryStepId
```

identifies the entry point of an undeployed authoring blueprint.

### Workbench Session Start

```text
sessions[].stepId
```

identifies the deployed step to start.

A Workbench request must not use `entryStepId`.

## Runtime inspection before reuse or start

Authoring knowledge does not prove that a deployed contract matches an intended artifact.

For deployed workflows, combine knowledge tools with:

```text
get_xrc_contract
read_xrc137_rule_json
read_xrc729_ostc_json
resolve_xrc729_process_graph
get_xrc729_authority
find_startable_xdala_workflows
```

Encrypted runtime rules are not decrypted by the gateway.

User-authorized decryption remains local.

## Gas preflight versus execution authority

Native XGR balance and workflow authority are separate questions.

An address may:

- be authorized but lack gas,
- have gas but lack authority,
- have both,
- have neither.

Use:

```text
get_account_live_state
```

for gas balance.

Use:

```text
get_xrc729_authority
find_startable_xdala_workflows
```

for start authority.

A successful starter-gas grant provides only native XGR.

It does not grant:

- contract ownership,
- executor status,
- session authority,
- signing authority,
- payload authorization.

## Single source of truth

The public MCP implementation is maintained in:

```text
https://github.com/xgr-network/xgr-mcp
```

Canonical XGR and XDaLa documentation is maintained in:

```text
https://github.com/xgr-network/XGR
```

Tool-served schemas, references and validator behavior are authoritative for artifact generation.

Whenever authoring rules or schemas change:

1. update the public runtime knowledge source,
2. update examples,
3. update validators,
4. review bundled documentation,
5. update this page,
6. run validation tests.
