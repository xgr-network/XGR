# XGR MCP Gateway — Tool Reference

**Document ID:** XGR-MCP-TOOL-REFERENCE  
**Last updated:** 2026-07-21  
**Audience:** Developers, integrators, agent builders  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/tools`

This document lists the tools currently registered by the XGR MCP Gateway.

Read tools inspect chain, Explorer, contract, knowledge or purchase-option data.

Handoff tools store validated offchain requests for later human review and local signing.

Purchase order tools are separate from handoff tools. When explicitly enabled on mainnet, they create real offchain purchase reservations and return exact external payment instructions.

No MCP tool receives private keys or signs transactions.

> **Session identity**
>
> An XDaLa session is identified by **owner + sessionId**. A session ID is not globally unique on its own.

> **Time windows**
>
> Analytics tools generally use `windowHours`. For example, three weeks is `504`.

> **Native transfers**
>
> Native value refers to `transaction.value`, not gas fees.

> **Purchase order effect**
>
> `create_xgr_purchase_order` and `create_xgr_purchase_order_by_budget` are non-idempotent. Each successful call creates a live order and inventory reservation.

---

## Network and chain

| Tool | Purpose |
|---|---|
| `get_xgr_network_info` | Canonical XGR.Network, XGRChain, XDaLa, mainnet, testnet, Faucet, documentation and ecosystem metadata. |
| `get_chain_status` | Live chain ID, block number and gas price from the configured RPC, plus compact official links. |
| `get_latest_block` | Full latest EVM block including transactions. |
| `get_account_live_state` | Live balance, nonce, code and contract status for an EVM address. |

`get_xgr_network_info` is the preferred discovery tool for official URLs and network configuration.

## XGR protocol

| Tool | Purpose |
|---|---|
| `get_xgr_core_addresses` | Read XGR protocol addresses through `xgr_getCoreAddrs`. |
| `get_xgr_circulating_supply` | Read circulating-supply information through `xgr_getCirculatingSupply`. |
| `estimate_xdala_rule_gas` | Estimate validation, branch, grant and worst-case gas for an XDaLa/XRC-137 rule. |

## Mainnet XGR purchase

Purchase tools are:

- mainnet-only,
- disabled unless explicitly enabled by the gateway operator,
- non-custodial,
- limited by the configured autonomous EUR policy,
- dependent on the configured XGR purchase API.

They create purchase orders only. They do not execute the returned stablecoin payment.

### Purchase tools

| Tool | Purpose |
|---|---|
| `get_xgr_purchase_options` | Read live mainnet price, stock, policy limits and supported payment assets. Always call this first. |
| `quote_xgr_purchase` | Non-binding USDC/USDT budget planning. Creates no order and returns no executable payment instruction. |
| `create_xgr_purchase_order` | Create one live mainnet order for an exact integer XGR quantity. |
| `create_xgr_purchase_order_by_budget` | Create one live mainnet order from a maximum USDC or USDT payment budget. |

### Mandatory agent sequence

For every purchase request:

```text
1. Call get_xgr_purchase_options.
2. Select one entry from payment_assets[].
3. Pass payment_assets[].key exactly as payment_asset.
4. Inspect requires_sender_wallet.
5. Determine whether the user specified:
   a. an XGR quantity, or
   b. a maximum stablecoin budget.
6. Collect all required user-supplied fields.
7. Require explicit terms acceptance.
8. Create exactly one order.
9. Read payment_approved and next_action.
10. Pay only from payment_instruction.
```

Do not use the asset display symbol as `payment_asset`.

Correct:

```text
payment_asset = "usdc_eth"
```

Incorrect:

```text
payment_asset = "USDC"
```

The actual keys are live backend data and must be read from the options result.

### `get_xgr_purchase_options`

Input:

```json
{}
```

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
payment_assets[]
```

Important payment asset fields include:

```text
payment_assets[].key
payment_assets[].symbol
payment_assets[].chain
payment_assets[].decimals
payment_assets[].requires_sender_wallet
```

The machine-readable `agent_guidance` identifies:

```text
first_tool
payment_asset_field
fixed_xgr_tool
budget_tool
do_not_invent[]
order_creation_effect
payment_rule
payment_source
```

### Required purchase inputs

Both order-creation tools require:

| Field | Meaning |
|---|---|
| `payment_asset` | Exact key returned by `payment_assets[].key`. |
| `name` | Purchaser name supplied by the user or an authorized upstream system. |
| `email` | Valid purchaser email supplied by the user or an authorized upstream system. |
| `country_code` | Two-letter uppercase country code such as `DE`. |
| `xgr_wallet` | User-controlled XGRChain wallet that will receive XGR. |
| `terms_accepted` | Must be exactly `true` after explicit acceptance. |

Depending on the selected payment asset:

| Field | Meaning |
|---|---|
| `sender_wallet` | User-controlled wallet that will send the stablecoin payment. Required when `requires_sender_wallet=true`. |

An agent must not invent:

```text
name
email
country_code
xgr_wallet
sender_wallet
terms_accepted
```

Syntactically valid dummy values are not valid production purchase data.

### `quote_xgr_purchase`

Use this tool only when the user specifies a maximum USDC or USDT budget.

Required inputs:

```text
payment_asset
max_payment_amount
```

Optional input:

```text
safety_margin_bps
```

Default:

```text
safety_margin_bps = 100
```

Maximum:

```text
safety_margin_bps = 1000
```

The planning formula is:

```text
conservative_price =
  discounted_usdc_per_xgr ×
  (1 + safety_margin_bps / 10000)
```

The estimated XGR quantity is:

```text
floor(max_payment_amount / conservative_price)
```

A quote returns:

```json
{
  "estimate_only": true,
  "order_created": false,
  "payment_amount_is_final": false,
  "next_action": "create_order_after_required_user_inputs_are_confirmed"
}
```

The quote:

- does not reserve XGR,
- does not create an order,
- is not binding,
- must not be paid.

### `create_xgr_purchase_order`

Use this tool when the user specifies an exact integer:

```text
amount_xgr
```

The tool:

1. reads live price, inventory and payment-asset data,
2. validates the estimated EUR policy value,
3. validates stock,
4. validates sender-wallet requirements,
5. creates one backend order,
6. validates the backend response,
7. returns the exact external payment instruction.

A validated success returns:

```json
{
  "network": "mainnet",
  "autonomous": true,
  "order_created": true,
  "payment_approved": true,
  "payment_execution": "external",
  "next_action": "external_crypto_payment",
  "payment_instruction_exact": true
}
```

The final crypto payment amount comes from the backend order result, not from a local estimate.

### `create_xgr_purchase_order_by_budget`

Use this tool when the user specifies a maximum USDC or USDT payment amount rather than an XGR quantity.

Required budget input:

```text
max_payment_amount
```

The gateway:

1. computes a conservative XGR quantity,
2. creates one normal backend order for that XGR quantity,
3. reads the exact backend `amount_crypto`,
4. compares the exact amount to the requested budget.

Approval condition:

```text
exact_payment_amount <= max_payment_amount
```

Approved result:

```json
{
  "order_created": true,
  "payment_within_limit": true,
  "payment_approved": true,
  "payment_execution": "external",
  "next_action": "external_crypto_payment"
}
```

Blocked result:

```json
{
  "order_created": true,
  "payment_within_limit": false,
  "payment_approved": false,
  "payment_execution": "blocked",
  "next_action": "do_not_pay",
  "reason": "Exact order payment amount exceeds the requested payment limit."
}
```

A blocked budget order may already have reserved inventory.

Do not:

- pay it,
- immediately repeat the same order,
- assume that `payment_approved=false` means no order exists.

The reservation expires according to the returned order data.

### Exact payment instruction

Approved fixed and budget orders return:

```json
{
  "payment_instruction": {
    "type": "crypto_transfer",
    "chain": "ethereum",
    "asset_key": "usdc_eth",
    "symbol": "USDC",
    "decimals": 6,
    "amount": 2.967373,
    "recipient": "0x...",
    "sender_wallet": "0x...",
    "reference": "XGR-...",
    "expires_at": "2026-07-21T10:26:43Z",
    "xgr_delivery": {
      "chain_id": 1643,
      "wallet": "0x...",
      "amount_xgr": 23200
    }
  }
}
```

The values above are illustrative. The live returned values are authoritative.

Field meanings:

| Field | Meaning |
|---|---|
| `type` | Payment operation type. |
| `chain` | Chain on which the stablecoin payment must be sent. |
| `asset_key` | Exact backend payment-asset key. |
| `symbol` | Stablecoin symbol. |
| `decimals` | Stablecoin decimal precision. |
| `amount` | Exact payment amount. |
| `recipient` | Exact custody wallet returned by the backend. |
| `sender_wallet` | Expected sender wallet when present. |
| `reference` | Order reference for accounting and reconciliation. |
| `expires_at` | Reservation expiry. |
| `xgr_delivery.chain_id` | XGRChain mainnet chain ID. |
| `xgr_delivery.wallet` | XGR recipient wallet. |
| `xgr_delivery.amount_xgr` | Reserved XGR quantity. |

A payment executor must pay only when:

```text
payment_approved = true
next_action = external_crypto_payment
```

The payment executor must use:

```text
payment_instruction.amount
payment_instruction.recipient
payment_instruction.asset_key
payment_instruction.chain
```

It must not recalculate the amount from market prices.

### Purchase failure states

#### Input or pre-order failure

```json
{
  "order_created": false,
  "post_completed": false,
  "next_action": "fix_input_or_retry"
}
```

This means no successful order POST was completed according to the gateway.

Correct the stated input or connectivity problem before trying again.

#### Uncertain or invalid post-order response

```json
{
  "order_created": "unknown",
  "post_completed": true,
  "payment_approved": false,
  "payment_execution": "blocked",
  "next_action": "do_not_pay"
}
```

The backend may have received or created an order even though the response could not be validated.

Do not automatically retry. Investigate the backend or wait for the possible reservation to expire.

#### Valid backend order with unsafe mismatch

If the backend response contains an unexpected XGR amount, payment asset, chain ID, custody wallet or other required field, the gateway returns:

```text
payment_execution = blocked
next_action = do_not_pay
```

The raw order response may be included for investigation.

### Purchase policy

The gateway enforces:

```text
minimum estimated order value = 2 EUR
maximum configured MCP policy = 249.99 EUR
```

The purchase backend separately applies its billing-address threshold at:

```text
250 EUR
```

The MCP autonomous policy and the backend billing threshold are separate controls.

The backend remains authoritative after repricing. The gateway does not automatically retry a backend repricing or address error.

## XDaLa session evidence

| Tool | Purpose |
|---|---|
| `get_session_transactions` | Indexed transaction timeline for owner + sessionId. |
| `get_session_status_live` | Live `xgr_sessionAlive` result from the configured RPC. |
| `get_sessions_overview` | High-level indexed session analytics for a selected window. |
| `get_session_receipt_logs` | Decoded engine receipt data including payload, saves, rule/execution contracts, validity and inner gas. |
| `list_wakeup_targets_by_address` | Waiting XDaLa steps that an address may wake. |
| `resolve_wakeup_payload_schema` | Required, optional, default and missing payload fields for a waiting wake-up target. |

Encrypted XRC-137 rule bodies are not decrypted by the gateway. Typed payload resolution for encrypted rules requires user-side decryption.

## Session resolver and analytics

Use these tools when the user does not already know the concrete owner + sessionId pair, or requests aggregate results.

| Tool | Purpose |
|---|---|
| `find_latest_xdala_session` | Resolve the newest indexed XDaLa session. |
| `get_latest_session_payload` | Resolve the latest session and return final payload, API saves, contract saves and extras. |
| `get_recent_xdala_sessions` | Recent indexed sessions with optional owner, window and payload enrichment. |
| `list_xdala_session_owners` | Distinct session owner addresses. |
| `list_xdala_sessions` | Concrete owner + sessionId pairs with keyset pagination. |
| `list_xdala_session_ids` | Session IDs grouped by owner. |
| `get_xdala_session_detail` | Timeline, steps, payloads and evidence for one concrete session. |
| `get_xdala_session_stats` | Counts, outcomes, duration, steps and error aggregates. |
| `get_xdala_session_timeseries` | Session counts and outcomes over time. |
| `get_xdala_step_stats` | Step validity, failure and gas aggregates. |
| `get_xdala_payload_key_stats` | Frequency and presence statistics for payload keys. |
| `get_xdala_payload_term_stats` | Aggregated terms from payload keys and/or values. |
| `get_xdala_payload_field_value_stats` | Most frequent values for a selected payload field. |
| `get_xdala_active_sessions_timeseries` | Active or concurrent session counts over time. |

## Transactions

Use transaction tools for chain-wide questions. Do not sample XDaLa sessions when the question concerns all transactions or native transfers.

| Tool | Purpose |
|---|---|
| `get_transaction_evidence` | Combined Explorer transaction, decoded receipt and live RPC evidence for one hash. |
| `get_transaction_receipt` | Explorer receipt data for one transaction. |
| `search_transactions` | Search by sender, recipient, hash, value, input, contract creation, session, validity, execution, blocks or time. |
| `get_recent_value_transfers` | Recent native XGR transfers with count and total-value summaries. |
| `get_account_transactions` | Incoming, outgoing or all indexed transactions for one address. |
| `get_block_transactions` | Indexed transactions for a selected or latest block. |
| `get_transaction_stats` | Chain transaction, transfer, zero-value, creation and total-value aggregates. |

## XRC authority and workflow discovery

| Tool | Purpose |
|---|---|
| `get_xrc729_authority` | Read XRC-729 owner and executor start-authority roles. |
| `find_startable_xdala_workflows` | Discover deployed workflows an address may start as owner, executor or wildcard executor. |
| `list_xrc729_contracts_by_executor` | Indexed active XRC-729 executor relationships with pagination metadata. |

Contract owner and executor roles describe authority to start a workflow. They do not establish the owner of a session that has not yet been started.

## XRC contracts, events and runtime state

| Tool | Purpose |
|---|---|
| `list_xrc_contracts` | List indexed XRC-137 or XRC-729 contracts. |
| `get_xrc_contract` | Read indexed metadata for one XRC contract. |
| `list_xrc_events` | Search indexed XRC events globally or by owner, contract, action, transaction or block range. |
| `get_xrc_contract_events` | Indexed event history for one XRC contract. |
| `get_xrc729_ostc_state` | Indexed OSTC versions and state for an XRC-729 contract. |
| `get_xrc_owner_summary` | Compact XRC-137, XRC-729 and recent-event summary for an owner. |
| `read_xrc729_ostc_json` | Runtime `XRC729.getOSTC(ostcId)` JSON through `eth_call`. |
| `read_xrc137_rule_json` | Runtime `XRC137.getRule()` JSON through `eth_call`. |
| `resolve_xrc729_process_graph` | Resolve XRC-729 OSTC structure and linked XRC-137 contracts. |

## XRC usage, reuse and failures

| Tool | Purpose |
|---|---|
| `get_xrc_usage` | Observed session usage for an XRC-137 rule or XRC-729 OSTC. |
| `list_xrc_process_sessions` | Sessions associated with an OSTC ID or OSTC hash. |
| `find_reusable_xrc137_rules` | Metadata-assisted search for an existing rule that could be reused. |
| `get_unused_xrc137_rules` | Owner rules with no observed engine-rule usage. |
| `get_xrc_failure_stats` | Invalid and failure statistics for XRC rules or processes. |

Reuse candidates are advisory. Read and validate the runtime rule before relying on semantic equivalence.

## Documentation and knowledge

| Tool | Purpose |
|---|---|
| `list_xgr_standards` | List standards available in the gateway knowledge base. |
| `list_xgr_docs` | List bundled canonical XGR documentation topics. |
| `get_xgr_doc` | Retrieve one bundled Markdown documentation topic. |
| `get_xdala_authoring_rules` | Canonical rules for drafting and reviewing XDaLa artifacts. |
| `get_xgr_standard_reference` | Prose reference for a supported standard. |
| `get_xgr_standard_schema` | Machine-readable schema for a supported standard. |
| `list_xgr_standard_examples` | List example names for a standard. |
| `get_xgr_standard_example` | Retrieve a concrete standard example. |
| `get_xgr_multibundle_reference` | Canonical `xgr-multi-bundle@1` documentation. |
| `get_xgr_multibundle_schema` | Canonical MultiBundle schema. |
| `get_xgr_session_start_schema` | Canonical Workbench `xgr-session-start@1` schema. |

Supported knowledge standards currently include:

- `xrc-137`
- `xrc-729`
- `xdala-authoring`
- `xgr-multibundle`

## Validation

| Tool | Purpose |
|---|---|
| `validate_xgr_multibundle` | Validate canonical deployable `xgr-multi-bundle@1`. |
| `validate_xdala_bundle` | Alias for `validate_xgr_multibundle`. |
| `validate_xgr_session_start_handoff` | Validate canonical Workbench `xgr-session-start@1`. |
| `validate_xgr_session_start` | Validate the legacy low-level session-start representation. |
| `validate_xrc137_authoring` | Validate a drafted XRC-137 authoring object. |
| `validate_xdala_rules` | Validate rule expressions against available placeholder fields. |
| `validate_xdala_blueprint` | Validate XRC-729 structure and cross-step XRC-137 payload flow. |

The legacy session-start validator is not a substitute for `validate_xgr_session_start_handoff`.

## Process diagrams

| Tool | Purpose |
|---|---|
| `get_xdala_process_mermaid` | Render Mermaid flowchart text from deployed runtime data, a bundle or a bundle-deploy handoff. |

Supported sources:

- `runtime`
- `bundle`
- `bundle_handoff`

## Generic operation handoff

| Tool | Purpose |
|---|---|
| `create_operation_handoff` | Prepare a generic browser-wallet operation. Not for XDaLa session starts or XGR purchase orders. |
| `get_operation_status` | Read current generic-operation status. |
| `cancel_operation_handoff` | Cancel pending offchain operation metadata. |
| `list_recent_operations` | List recent operation handoffs without secrets or execution tokens. |

Do not use generic operation handoffs for mainnet XGR purchase orders.

## XDaLa bundle-deploy handoff

| Tool | Purpose |
|---|---|
| `create_xdala_bundle_deploy_handoff` | Store a validated MultiBundle and return a Workbench import URL. |
| `get_xdala_bundle_deploy_handoff` | Read handoff metadata, validation, bundle and recorded result. |
| `get_xdala_bundle_deploy_result` | Read deployed artifact and audit events. |
| `cancel_xdala_bundle_deploy_handoff` | Cancel pending offchain bundle-deploy metadata. |

## XDaLa session-start handoff

| Tool | Purpose |
|---|---|
| `create_xdala_session_start_handoff` | Prepare canonical `xgr-session-start@1` and return a Workbench Session Start URL. |
| `get_xdala_session_start_handoff` | Read request, authority, validation, ownership summary and result. |
| `get_xdala_session_start_result` | Read the terminal result summary and evidence identifiers. |
| `cancel_xdala_session_start_handoff` | Cancel pending offchain session-start metadata. |

Use `create_xdala_session_start_handoff` for every request to start, run, launch, execute or queue an XDaLa session.

Canonical session fields are:

```text
sessions[].orchestration
sessions[].ostcId
sessions[].stepId
sessions[].payload
sessions[].maxTotalGas
```

Do not use `entryStepId` as a Workbench Session Start field.

## MCP result metadata

The gateway augments tool registrations with input descriptions, an output schema and MCP annotations.

When a tool returns JSON as text, the gateway also exposes the parsed result under:

```json
{
  "structuredContent": {
    "data": {}
  }
}
```

Clients may continue to consume standard MCP text content.

For programmatic agent integrations, prefer:

```text
result.structuredContent.data
```

over manually parsing the text representation.
