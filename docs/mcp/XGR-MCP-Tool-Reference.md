# XGR MCP Gateway — Tool Reference

**Document ID:** XGR-MCP-TOOL-REFERENCE  
**Last updated:** 2026-08-15  
**Audience:** Developers, integrators, agent builders  
**Implementation status:** Live  
**Source of truth:** [`xgr-network/xgr-mcp/src/tools`](https://github.com/xgr-network/xgr-mcp/tree/main/src/tools)

This document lists the semantic tools exposed by the XGR MCP Gateway and the rules required to use them correctly.

The public implementation is maintained in:

```text
https://github.com/xgr-network/xgr-mcp
```

Read tools inspect XGRChain, Explorer, indexed databases, deployed contracts or bundled knowledge.

Handoff tools prepare validated offchain requests for human review and local wallet signing.

Purchase tools may create live offchain purchase reservations but do not send payment.

Starter-gas tools may send a fixed native XGR grant from a dedicated service wallet.

The gateway never requests, accepts or controls user or third-party private keys.

> **Session identity**
>
> An XDaLa session is identified by `owner + sessionId`. A session ID is not globally unique by itself.

> **Native transfers**
>
> Native value means `transaction.value`, not gas fees.

> **Graph interpretation**
>
> A transaction relation proves that indexed transfers occurred between addresses. It does not prove common ownership, identity or common control.

> **Value-flow interpretation**
>
> Native XGR has no per-coin identity. Value-flow results are attribution models, not proof that a specific unit of XGR moved through later transactions.

> **Mutation warning**
>
> Purchase-order creation and starter-gas requests may create real external effects. Do not retry them blindly.

---

## Network and chain

| Tool | Purpose |
|---|---|
| `get_xgr_network_info` | Canonical XGR.Network, XGRChain, XDaLa, endpoint, Faucet, documentation and repository metadata. |
| `get_chain_status` | Live connected-chain status including chain ID, latest block and gas price. |
| `get_latest_block` | Read the full latest EVM block. |
| `get_account_live_state` | Read live native balance, nonce, code and contract status for an address. |

Use:

```text
get_xgr_network_info
```

for official XGR discovery and:

```text
get_chain_status
```

for current connected-chain state.

---

## XGR protocol

| Tool | Purpose |
|---|---|
| `get_xgr_core_addresses` | Read protocol addresses through `xgr_getCoreAddrs`. |
| `get_xgr_circulating_supply` | Read circulating supply through `xgr_getCirculatingSupply`. |
| `estimate_xdala_rule_gas` | Estimate validation, branch, grant and worst-case XDaLa rule gas. |

---

## Transactions

| Tool | Purpose |
|---|---|
| `get_transaction_evidence` | Combined indexed and live evidence for one transaction hash. |
| `get_transaction_receipt` | Read receipt data for one transaction. |
| `search_transactions` | Search indexed transactions by address, hash, value, input, session, block or time. |
| `get_recent_value_transfers` | Read recent native XGR transfers. |
| `get_account_transactions` | Read incoming, outgoing or all indexed transactions for an account. |
| `get_block_transactions` | Read indexed transactions for a selected block. |
| `get_transaction_stats` | Aggregate transaction statistics. |

---

# Native XGR relation graphs

The relation-graph tools operate on indexed **native XGR transfers**.

They are read-only.

A relation between two addresses means transactions occurred between them. It does not establish ownership, identity, affiliation or intent.

## Tool summary

| Tool | Purpose |
|---|---|
| `get_address_relation_graph` | Read a bounded native-XGR transfer graph around an address. |
| `expand_address_relation_graph` | Expand one address by exactly one graph level. |
| `trace_xgr_transaction` | Start a relation-graph investigation from one indexed transaction. |
| `get_relation_edge_transactions` | Read the transactions represented by one directed graph edge. |
| `trace_xgr_value_flow` | Model native-XGR value provenance beginning from one transaction. |

---

## `get_address_relation_graph`

Returns an Explorer-backed bounded graph of indexed native XGR transfers around one address.

### Required input

```text
address
```

### Optional input

```text
direction
depth
minValueWei
fromTimestamp
toTimestamp
aggregate
maxNodes
maxEdges
```

### `direction`

Supported values:

```text
in
out
both
```

Default:

```text
both
```

### `depth`

Allowed range:

```text
1..4
```

Default:

```text
1
```

### Value filter

`minValueWei` is a decimal-string native-XGR value in wei.

Default:

```text
0
```

### Default graph bounds

```text
aggregate = true
maxNodes = 100
maxEdges = 150
```

Input limits:

```text
maxNodes <= 300
maxEdges <= 500
```

Returned graph metadata may indicate that the result was truncated.

Consumers must preserve and respect truncation metadata.

---

## `expand_address_relation_graph`

Progressively expands exactly one address by one graph level.

Use this for interactive graph exploration instead of repeatedly requesting a large multi-depth graph.

### Required input

```text
address
```

### Optional input

```text
direction
minValueWei
fromTimestamp
toTimestamp
aggregate
maxNodes
maxEdges
```

Internally the graph depth is fixed to:

```text
1
```

for each expansion request.

---

## `trace_xgr_transaction`

Starts an address-relation investigation from one indexed transaction.

### Required input

```text
txHash
```

### Optional input

```text
direction
depth
minValueWei
fromTimestamp
toTimestamp
maxNodes
maxEdges
```

The tool loads the indexed transaction and resolves its sender and recipient.

The result contains:

```text
transaction
root
transactionRoots
highlightEdge
graph
```

The sender is used as the graph root when available.

`transactionRoots` contains the available sender and recipient addresses.

`highlightEdge` identifies the original sender-to-recipient edge when both addresses exist.

This tool traces **relations**.

It does not prove that later outgoing transfers contain the same specific XGR value received by the seed transaction.

For provenance analysis use:

```text
trace_xgr_value_flow
```

---

## `get_relation_edge_transactions`

Returns the indexed native XGR transactions represented by one directed graph edge.

### Required input

```text
source
target
```

The direction is:

```text
source → target
```

### Optional input

```text
minValueWei
fromTimestamp
toTimestamp
page
limit
```

Defaults:

```text
minValueWei = "0"
page = 1
limit = 50
```

Maximum:

```text
limit = 100
```

When investigating a graph edge, use the same value and time filters that were used to construct the original graph.

---

# Native XGR value-flow analysis

## `trace_xgr_value_flow`

Performs Explorer-backed native-XGR provenance analysis beginning from one transaction.

### Required input

```text
txHash
```

### Optional input

```text
amountWei
model
maxTransfers
maxHops
minAttributedWei
```

### `amountWei`

Optional amount of the seed transaction value to trace.

If omitted, the full native-XGR value of the seed transaction is used.

### Models

Supported values:

```text
possible
proportional
```

Default:

```text
possible
```

### `possible`

Returns conservative possible-attribution ranges.

This model answers questions of the form:

> How much of the seed value could potentially have propagated through these later transfers?

### `proportional`

Applies a proportional haircut/share model to propagated value.

This is an analytical attribution model.

### Default limits

```text
maxTransfers = 100
maxHops = 5
minAttributedWei = "1"
```

`maxTransfers` and `maxHops` may be either:

```text
positive integer
```

or:

```text
all
```

`all` does not mean unlimited execution.

Explorer safety caps still apply and the result may be truncated.

### Critical interpretation rule

Native XGR is an account-based asset.

Individual XGR units have no persistent coin identity.

Therefore value-flow output is:

```text
provenance / attribution analysis
```

and not:

```text
proof that a specific coin moved
```

---

# XDaLa session evidence

| Tool | Purpose |
|---|---|
| `get_session_transactions` | Indexed transaction timeline for `owner + sessionId`. |
| `get_session_status_live` | Live `xgr_sessionAlive` result. |
| `get_sessions_overview` | High-level indexed session analytics. |
| `get_session_receipt_logs` | Decoded engine receipt data, payloads, saves, validity and gas. |
| `list_wakeup_targets_by_address` | Waiting steps an address may wake. |
| `resolve_wakeup_payload_schema` | Required, optional, default and missing wake-up payload fields. |

Encrypted XRC-137 bodies are not decrypted by the gateway.

---

# Session discovery and analytics

| Tool | Purpose |
|---|---|
| `find_latest_xdala_session` | Resolve the newest indexed XDaLa session. |
| `get_latest_session_payload` | Return final payload data for the latest session. |
| `get_recent_xdala_sessions` | Return recent sessions with optional payload enrichment. |
| `list_xdala_session_owners` | List distinct session owners. |
| `list_xdala_sessions` | List concrete `owner + sessionId` pairs. |
| `list_xdala_session_ids` | List session IDs grouped by owner. |
| `get_xdala_session_detail` | Return full indexed detail for one session. |
| `get_xdala_session_stats` | Aggregate session counts, outcomes, duration and errors. |
| `get_xdala_session_timeseries` | Aggregate sessions and outcomes over time. |
| `get_xdala_step_stats` | Aggregate step validity, failure and gas data. |
| `get_xdala_payload_key_stats` | Aggregate payload-key frequency. |
| `get_xdala_payload_term_stats` | Aggregate payload terms. |
| `get_xdala_payload_field_value_stats` | Return frequent values for one selected payload field. |
| `get_xdala_active_sessions_timeseries` | Return active or concurrent session counts over time. |
| `get_xdala_start_payload_history` | Return historical scalar values used to start a specific XRC-729 OSTC entry step. |

---

# XDaLa Session Start payload history

## `get_xdala_start_payload_history`

Reads indexed historical payload values used when starting a specific deployed XRC-729 workflow entry step.

The tool reads the Explorer database through the gateway.

### Required input

| Field | Meaning |
|---|---|
| `xrc729Address` | Deployed XRC-729 orchestration address. |
| `ostcId` | OSTC identifier. |
| `stepId` | Entry-step identifier. |

### Optional input

| Field | Meaning |
|---|---|
| `owner` | Restrict results to one session owner. |
| `windowHours` | Restrict evidence to a recent time window. `0` means no time filter. |
| `limit` | Maximum number of sampled sessions. |

Constraints:

```text
windowHours: 0..8760
limit: 1..100
```

Defaults:

```text
windowHours = 0
limit = 25
```

The implementation selects the first matching entry-step receipt per:

```text
owner + sessionId
```

and aggregates scalar payload values.

Supported scalar value types:

```text
string
number
boolean
```

Objects and arrays are not included in the compact field-value statistics.

Payload keys beginning with:

```text
__
```

are ignored.

### Result shape

The result contains:

```text
source
xrc729Address
ostcId
stepId
owner
sampledSessions
valuesByField
```

Example:

```json
{
  "source": "explorer_db",
  "xrc729Address": "0x...",
  "ostcId": "order-process",
  "stepId": "start",
  "owner": null,
  "sampledSessions": 25,
  "valuesByField": {
    "currency": [
      {
        "value": "EUR",
        "uses": 14,
        "lastSeenAt": "2026-08-15T00:00:00.000Z"
      }
    ]
  }
}
```

### Interpretation

Historical payload evidence may be useful for:

- UI value pickers,
- agent suggestions,
- operator context,
- discovering commonly used historical values.

It is not:

- the current XRC-137 schema,
- a schema default,
- a required-value definition,
- user authorization,
- workflow authority,
- validation.

Always inspect the current runtime rule before preparing a Session Start.

Never silently fill a required business field from historical values.

---

# XRC authority and workflow discovery

| Tool | Purpose |
|---|---|
| `get_xrc729_authority` | Read XRC-729 owner and executor start-authority roles. |
| `find_startable_xdala_workflows` | Discover workflows an address may start. |
| `list_xrc729_contracts_by_executor` | Read indexed active executor-to-XRC-729 relationships. |

Workflow start authority does not establish the owner of a session that has not yet started.

The XRC-729 contract owner and executors describe who is allowed to start the workflow.

Actual session identity exists only after Session Start execution.

---

# XRC contracts and runtime state

| Tool | Purpose |
|---|---|
| `list_xrc_contracts` | List indexed XRC-137 or XRC-729 contracts. |
| `get_xrc_contract` | Read one indexed XRC contract. |
| `list_xrc_events` | Search indexed XRC events. |
| `get_xrc_contract_events` | Read event history for one XRC contract. |
| `get_xrc729_ostc_state` | Read indexed OSTC state and versions. |
| `get_xrc_owner_summary` | Return a compact XRC summary for one owner. |
| `read_xrc729_ostc_json` | Read runtime `getOSTC` JSON through `eth_call`. |
| `read_xrc137_rule_json` | Read runtime `getRule` JSON through `eth_call`. |
| `resolve_xrc729_process_graph` | Resolve OSTC structure and linked XRC-137 rules. |

Runtime contract reads are authoritative for the deployed contract state.

---

# XRC usage, reuse and failure analysis

| Tool | Purpose |
|---|---|
| `get_xrc_usage` | Return observed usage for a rule or process. |
| `list_xrc_process_sessions` | List sessions associated with an OSTC ID or OSTC hash. |
| `find_reusable_xrc137_rules` | Search indexed XRC-137 rules for possible reuse. |
| `get_unused_xrc137_rules` | Find rules with no observed engine usage. |
| `get_xrc_failure_stats` | Return invalid and failure statistics. |

Reuse results are advisory.

Always inspect the deployed runtime rule before relying on a reused rule.

---

# Documentation and knowledge

| Tool | Purpose |
|---|---|
| `list_xgr_standards` | List supported standards. |
| `list_xgr_docs` | List bundled canonical documentation topics. |
| `get_xgr_doc` | Retrieve one bundled Markdown topic. |
| `get_xdala_authoring_rules` | Retrieve current XDaLa authoring rules. |
| `get_xgr_standard_reference` | Retrieve a prose standard reference. |
| `get_xgr_standard_schema` | Retrieve a machine-readable standard schema. |
| `list_xgr_standard_examples` | List examples for a standard. |
| `get_xgr_standard_example` | Retrieve one standard example. |
| `get_xgr_multibundle_reference` | Retrieve MultiBundle documentation. |
| `get_xgr_multibundle_schema` | Retrieve the canonical MultiBundle schema. |
| `get_xgr_session_start_schema` | Retrieve the canonical Session Start schema. |

---

# Validation tools

| Tool | Purpose |
|---|---|
| `validate_xgr_multibundle` | Validate canonical `xgr-multi-bundle@1`. |
| `validate_xdala_bundle` | Alias for `validate_xgr_multibundle`. |
| `validate_xgr_session_start_handoff` | Validate canonical `xgr-session-start@1`. |
| `validate_xgr_session_start` | Validate the legacy low-level Session Start representation. |
| `validate_xrc137_authoring` | Validate an XRC-137 authoring object. |
| `validate_xdala_rules` | Validate expressions against available fields. |
| `validate_xdala_blueprint` | Validate orchestration structure and cross-step payload flow. |

`validate_xdala_blueprint.entryStepId` refers to an undeployed authoring blueprint entry point.

It is not a canonical Workbench Session Start field.

Canonical Session Start uses:

```text
sessions[].stepId
```

---

# Process diagrams

| Tool | Purpose |
|---|---|
| `get_xdala_process_mermaid` | Render Mermaid flowchart text from runtime, bundle or bundle-handoff data. |

Supported sources include:

```text
runtime
bundle
bundle_handoff
```

---

# Generic operation handoff

| Tool | Purpose |
|---|---|
| `create_operation_handoff` | Prepare a generic browser-wallet operation. |
| `get_operation_status` | Read operation status. |
| `cancel_operation_handoff` | Cancel pending offchain handoff metadata. |
| `list_recent_operations` | List recent operations without exposing secrets. |

Do not use the generic operation family for:

- XDaLa Session Start,
- XGR purchase orders,
- starter-gas grants.

Cancellation affects only pending offchain metadata.

It cannot cancel a transaction already signed or submitted.

---

# XDaLa bundle-deploy handoff

| Tool | Purpose |
|---|---|
| `create_xdala_bundle_deploy_handoff` | Store a validated MultiBundle and return a Workbench URL. |
| `get_xdala_bundle_deploy_handoff` | Read bundle and handoff metadata. |
| `get_xdala_bundle_deploy_result` | Read the normalized deployment result and audit events. |
| `cancel_xdala_bundle_deploy_handoff` | Cancel pending bundle-deploy metadata. |

The gateway does not sign the deployment transaction.

The user reviews and signs locally in xDaLa Workbench or their configured signer environment.

---

# XDaLa Session Start handoff

| Tool | Purpose |
|---|---|
| `create_xdala_session_start_handoff` | Prepare canonical `xgr-session-start@1` and return a Workbench URL. |
| `get_xdala_session_start_handoff` | Read request, authority, ownership summary, validation and result metadata. |
| `get_xdala_session_start_result` | Read terminal Session Start result and audit evidence. |
| `cancel_xdala_session_start_handoff` | Cancel pending Session Start metadata. |

Use this family whenever the user wants to:

- start a deployed workflow,
- run an XDaLa process,
- launch a session,
- execute an XDaLa workflow,
- prepare multiple Session Starts.

Canonical fields include:

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
sessions[].expiry
sessions[].starterAddress
```

Do not use:

```text
entryStepId
```

as a Workbench Session Start field.

Before creating a runtime Session Start handoff:

1. resolve the XRC-729 orchestration,
2. resolve the OSTC ID,
3. inspect start authority,
4. determine the entry step,
5. inspect the linked XRC-137 rule,
6. derive required, optional and default payload fields,
7. optionally inspect historical values with `get_xdala_start_payload_history`,
8. ask for unresolved required business values,
9. validate the canonical request,
10. create the handoff.

Historical payload values must never replace missing required user input automatically.

---

# Mainnet XGR purchase

Purchase tools are:

- mainnet-only,
- disabled unless explicitly enabled,
- connected to the configured XGR purchase API,
- constrained by an autonomous EUR policy,
- external-payment only.

## Purchase tool summary

| Tool | Purpose |
|---|---|
| `get_xgr_purchase_options` | Read live price, availability, policy, agent guidance and payment assets. |
| `quote_xgr_purchase` | Create a non-binding USDC/USDT budget estimate. |
| `create_xgr_purchase_order` | Create one live purchase reservation for an exact integer XGR amount. |
| `create_xgr_purchase_order_by_budget` | Create one live reservation from a maximum USDC or USDT payment budget. |

---

## Mandatory purchase sequence

```text
1. Call get_xgr_purchase_options.
2. Select payment_assets[].key exactly.
3. Inspect requires_sender_wallet.
4. Determine fixed-XGR or budget mode.
5. Collect all required user-supplied fields.
6. Require explicit terms acceptance.
7. Optionally calculate a budget quote.
8. Create exactly one live order.
9. Inspect payment_approved and next_action.
10. Pay only from payment_instruction.
```

---

## `get_xgr_purchase_options`

Always call this tool first.

The result includes:

```text
network
chain_id
autonomous_max_eur
billing_address_threshold_eur
minimum_order_eur
agent_guidance
price
availability
payment_assets
```

The current MCP explicitly instructs agents to use:

```text
payment_assets[].key
```

as `payment_asset`.

Do not use only the display symbol when a concrete asset key is required.

The result also identifies whether the selected payment asset requires:

```text
sender_wallet
```

### Agent guidance

The implementation returns machine-readable guidance including:

```text
first_tool
payment_asset_field
fixed_xgr_tool
budget_tool
do_not_invent
order_creation_effect
payment_rule
payment_source
```

The following values must not be invented by an agent:

```text
name
email
country_code
xgr_wallet
sender_wallet
terms_accepted
```

---

## Required purchase inputs

| Field | Meaning |
|---|---|
| `payment_asset` | Exact key returned in `payment_assets[].key`. |
| `name` | Purchaser name supplied by the user. |
| `email` | Purchaser email supplied by the user. |
| `country_code` | Two-letter uppercase country code. |
| `xgr_wallet` | User-controlled XGRChain wallet receiving the purchased XGR. |
| `terms_accepted` | Must be `true` after explicit user acceptance. |
| `sender_wallet` | Required when the selected payment asset declares `requires_sender_wallet=true`. |

An agent must not infer terms acceptance.

---

## `quote_xgr_purchase`

Use only when the user specifies a maximum USDC or USDT payment budget.

### Input

```text
max_payment_amount
payment_asset
safety_margin_bps
```

`max_payment_amount` is denominated in the selected payment asset.

It is not EUR.

`safety_margin_bps` is optional.

Default:

```text
100
```

Allowed range:

```text
0..1000
```

The quote:

- creates no order,
- reserves no inventory,
- is non-binding,
- is not a payment instruction.

Successful quote metadata includes:

```text
estimate_only = true
order_created = false
payment_amount_is_final = false
next_action = create_order_after_required_user_inputs_are_confirmed
```

Never send payment based on a quote.

---

## `create_xgr_purchase_order`

Use when the user specifies an exact XGR quantity.

Required additional field:

```text
amount_xgr
```

`amount_xgr` must be a positive integer.

The MCP:

1. loads live price, inventory and payment-asset data,
2. checks the estimated EUR policy,
3. checks XGR availability,
4. checks `sender_wallet` requirements,
5. creates one live backend reservation,
6. validates the returned order,
7. constructs the external payment instruction.

A successful order returns:

```text
network = mainnet
autonomous = true
order_created = true
payment_approved = true
payment_execution = external
next_action = external_crypto_payment
payment_instruction_exact = true
```

---

## `create_xgr_purchase_order_by_budget`

Use when the user specifies a maximum payment amount instead of an XGR quantity.

Required budget input:

```text
max_payment_amount
```

Budget calculation currently supports payment assets whose symbol is:

```text
USDC
USDT
```

The planning calculation uses a conservative price margin to derive an integer XGR order amount.

The live backend response determines the exact binding payment amount.

Payment approval requires:

```text
exact_payment_amount <= max_payment_amount
```

If true:

```text
payment_approved = true
payment_execution = external
next_action = external_crypto_payment
```

If false:

```text
payment_approved = false
payment_execution = blocked
next_action = do_not_pay
```

A blocked budget result may still represent an already-created backend reservation.

Do not pay it.

Do not immediately create a replacement order without understanding the previous result.

---

## Structured payment instruction

Approved purchase orders include:

```text
payment_instruction
```

with fields equivalent to:

```json
{
  "type": "crypto_transfer",
  "chain": "...",
  "asset_key": "...",
  "symbol": "USDC",
  "decimals": 6,
  "amount": 1.23,
  "recipient": "0x...",
  "sender_wallet": "0x...",
  "reference": "...",
  "expires_at": "...",
  "xgr_delivery": {
    "chain_id": 1643,
    "wallet": "0x...",
    "amount_xgr": 100
  }
}
```

`sender_wallet` may be absent when the selected asset does not require it.

The payment instruction is the authoritative object for external payment execution.

Do not reconstruct payment details from:

- a quote,
- a previous response,
- prose,
- estimated values.

---

## Purchase backend response validation

Before payment is approved, the MCP checks the backend order response for:

- `ok=true`,
- valid `order_uid`,
- valid `payment_reference`,
- exact expected `amount_xgr`,
- positive `amount_crypto`,
- `payment_method=crypto`,
- exact requested `payment_asset`,
- valid EVM `custody_wallet`,
- valid `reserved_until`,
- expected XGR purchase chain ID.

If a live POST may already have created an order but the returned response cannot be safely validated, payment is blocked.

---

## Purchase failure classes

### Pre-order failure

When no order was successfully created:

```text
order_created = false
post_completed = false
next_action = fix_input_or_retry
```

The error may be:

```text
validation_error
purchase_api_error
```

### Post-order validation failure

If an order POST occurred but the result is unsafe or invalid:

```text
post_completed = true
payment_approved = false
payment_execution = blocked
next_action = do_not_pay
```

`order_created` may be:

```text
true
```

or:

```text
unknown
```

depending on what can be established from the raw backend response.

The result may include:

```text
raw_order_response
```

Do not automatically retry a post-order failure.

---

# Native XGR starter gas

Starter-gas tools solve the first-transaction gas problem for an eligible low-balance address.

The feature is disabled unless explicitly configured.

## Tool summary

| Tool | Purpose |
|---|---|
| `get_xgr_starter_gas_options` | Read the active network, grant amount and eligibility policy. |
| `request_xgr_starter_gas` | Send one fixed native-XGR grant from the dedicated service wallet. |

---

## `get_xgr_starter_gas_options`

Call this before requesting a grant.

Input:

```json
{}
```

The live result exposes:

```text
network
chain_id
grant_amount_xgr
maximum_recipient_balance_xgr
one_grant_per_address
max_hourly_grants
max_daily_grants
max_requests_per_client_ip_hour
max_requests_per_client_ip_day
maximum_attempts_per_address
execution
custody_model
repayment_required
next_action
```

Example:

```json
{
  "network": "mainnet",
  "chain_id": 1643,
  "grant_amount_xgr": 1,
  "maximum_recipient_balance_xgr": 0.5,
  "one_grant_per_address": true,
  "max_hourly_grants": 20,
  "max_daily_grants": 100,
  "max_requests_per_client_ip_hour": 5,
  "max_requests_per_client_ip_day": 20,
  "maximum_attempts_per_address": 2,
  "execution": "direct_onchain_transfer_from_dedicated_service_wallet",
  "custody_model": "no_user_or_third_party_private_keys",
  "repayment_required": false,
  "next_action": "request_xgr_starter_gas"
}
```

Policy values are deployment-specific.

Always use the live response instead of assuming configured thresholds.

---

## `request_xgr_starter_gas`

Sends one fixed:

```text
1 XGR
```

grant to an eligible low-balance EVM address.

### Input

```json
{
  "address": "0x...",
  "purpose": "Optional short description"
}
```

Required:

| Field | Meaning |
|---|---|
| `address` | EVM wallet, Safe or contract address receiving the grant. |

Optional:

| Field | Meaning |
|---|---|
| `purpose` | Descriptive context of up to 120 characters. |

The tool never accepts:

```text
private key
seed phrase
mnemonic
signature
wallet password
```

### Eligibility checks

Before sending, the service verifies:

1. the connected RPC reports the configured chain ID,
2. the recipient native-XGR balance is within the configured threshold,
3. the service wallet can fund the grant and transaction fee,
4. no previous successful grant exists for the address,
5. no unresolved grant broadcast exists for the address,
6. the per-address attempt limit is not exceeded,
7. the global hourly grant limit is not exceeded,
8. the global daily grant limit is not exceeded,
9. the client-IP request limits are not exceeded.

### Successful result

A successful confirmed grant includes:

```text
network
chain_id
grant_created
grant_status
recipient
previous_balance_xgr
amount_xgr
transaction_hash
block_number
next_action
repeat_allowed
```

Expected state:

```text
grant_created = true
grant_status = confirmed
amount_xgr = 1
next_action = starter_gas_ready
repeat_allowed = false
```

### Persistent states

```text
reserved
broadcast
confirmed
failed
```

| State | Meaning |
|---|---|
| `reserved` | Policy checks passed and a grant attempt has been reserved. |
| `broadcast` | A transaction hash exists and confirmation is unresolved. |
| `confirmed` | The grant succeeded on-chain. |
| `failed` | An eligible failed attempt was recorded. |

### Broadcast safety

If a previous request is already in:

```text
broadcast
```

state, the gateway checks the transaction receipt.

If the transaction is still unresolved:

```text
grant_created = false
grant_status = broadcast
retry_allowed = false
```

Do not send another request.

### Retry rules

A retry may be available after an eligible:

- pre-broadcast failure,
- confirmed failed transaction,
- stale reservation.

A retry is not allowed after:

- a confirmed successful grant,
- an unresolved broadcast,
- reaching the maximum attempt count,
- an active request-limit rejection.

### IP request accounting

Only:

```text
request_xgr_starter_gas
```

consumes starter-gas IP quota.

The IP request is persisted before later chain and balance checks.

Therefore failed requests may still consume client-IP quota.

### Signing boundary

The server may sign only:

```text
fixed native XGR transfers
from the dedicated starter-gas service wallet
```

It cannot sign on behalf of:

- the recipient,
- the Session Start wallet,
- a deployment wallet,
- a purchase wallet,
- any user or third-party wallet.

No repayment is required.

### Current anti-abuse limitation

The service currently does not require:

- proof of address ownership,
- proof of work,
- CAPTCHA,
- identity verification.

The configured limits bound financial exposure but do not provide strong Sybil resistance.

---

# MCP result metadata

The gateway enriches tool registrations with:

- parameter descriptions,
- output schemas,
- MCP annotations,
- structured result content.

For tools that return JSON through text content, the parsed result is additionally exposed under:

```json
{
  "structuredContent": {
    "data": {}
  }
}
```

Programmatic clients should prefer:

```text
result.structuredContent.data
```

instead of manually parsing JSON from text whenever structured content is available.

---

# Mutation and retry summary

| Operation | External effect | Blind retry allowed |
|---|---:|---:|
| Chain / Explorer read | No | Yes |
| Relation graph read | No | Yes |
| Value-flow analysis | No | Yes |
| Payload-history read | No | Yes |
| Validation | No | Yes |
| Diagram generation | No | Yes |
| Generic handoff creation | Offchain handoff record | No |
| Bundle-deploy handoff creation | Offchain handoff record | No |
| Session-start handoff creation | Offchain handoff record | No |
| Purchase quote | No order | Yes |
| Purchase order creation | Live purchase reservation | No |
| Starter-gas request | Native XGR transfer may be broadcast | No |

For any state-changing tool, inspect the returned state before deciding what to do next.
