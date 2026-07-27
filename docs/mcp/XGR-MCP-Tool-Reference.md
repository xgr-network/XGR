# XGR MCP Gateway — Tool Reference

**Document ID:** XGR-MCP-TOOL-REFERENCE  
**Last updated:** 2026-07-26  
**Audience:** Developers, integrators, agent builders  
**Implementation status:** Live  
**Source of truth:** [`xgr-network/xgr-mcp/src/tools`](https://github.com/xgr-network/xgr-mcp/tree/main/src/tools)

This document lists the semantic tools exposed by the XGR MCP Gateway.

The public implementation is maintained in:

```text
https://github.com/xgr-network/xgr-mcp
```

Read tools inspect chain, Explorer, contract or knowledge data.

Handoff tools store validated offchain requests for human review and local wallet signing.

Purchase tools create offchain purchase reservations but do not send payments.

Starter-gas tools may send a fixed native XGR grant from a dedicated service wallet.

The gateway never requests, accepts or controls user or third-party private keys.

> **Session identity**
>
> An XDaLa session is identified by `owner + sessionId`. A session ID is not globally unique by itself.

> **Native transfers**
>
> Native value means `transaction.value`, not gas fees.

> **Mutation warning**
>
> Purchase order creation and starter-gas requests may create real external effects. Do not retry them blindly.

---

## Network and chain

| Tool | Purpose |
|---|---|
| `get_xgr_network_info` | Canonical XGR.Network, XGRChain, XDaLa, endpoint, Faucet, documentation and repository metadata. |
| `get_chain_status` | Live chain ID, latest block and gas price. |
| `get_latest_block` | Full latest EVM block. |
| `get_account_live_state` | Live balance, nonce, code and contract status for an address. |

Use `get_xgr_network_info` for official discovery.

Use `get_chain_status` for live connected-chain state.

## XGR protocol

| Tool | Purpose |
|---|---|
| `get_xgr_core_addresses` | Read protocol addresses through `xgr_getCoreAddrs`. |
| `get_xgr_circulating_supply` | Read circulating supply through `xgr_getCirculatingSupply`. |
| `estimate_xdala_rule_gas` | Estimate validation, branch, grant and worst-case XDaLa rule gas. |

## Native XGR starter gas

Starter-gas tools solve the first-transaction problem for an eligible low-balance address.

They are:

- disabled unless explicitly enabled,
- configured for one XGR network and chain ID,
- backed by a dedicated service wallet,
- fixed to one `1 XGR` grant,
- limited by recipient balance,
- limited to one confirmed grant per address,
- protected by global and per-IP caps,
- persisted in SQLite.

### `get_xgr_starter_gas_options`

Purpose:

```text
Read the active starter-gas policy before requesting a grant.
```

Input:

```json
{}
```

Example result:

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

The values are deployment-specific.

The live response is authoritative.

### `request_xgr_starter_gas`

Purpose:

```text
Send one fixed 1 XGR grant to an eligible low-balance EVM address.
```

Input:

```json
{
  "address": "0x...",
  "purpose": "Optional short description"
}
```

Required:

| Field | Meaning |
|---|---|
| `address` | EVM wallet, Safe or contract address that will receive the grant. |

Optional:

| Field | Meaning |
|---|---|
| `purpose` | Short audit and context description. Maximum 120 characters. |

The tool does not accept:

```text
private key
seed phrase
mnemonic
signature
wallet password
```

### Successful result

```json
{
  "network": "mainnet",
  "chain_id": 1643,
  "grant_created": true,
  "grant_status": "confirmed",
  "recipient": "0x...",
  "previous_balance_xgr": "0.0",
  "amount_xgr": 1,
  "transaction_hash": "0x...",
  "block_number": 8174127,
  "next_action": "starter_gas_ready",
  "repeat_allowed": false
}
```

A successful result means the transaction received one confirmation.

### Eligibility checks

Before sending, the tool verifies:

1. the configured RPC reports the expected chain ID,
2. the recipient balance does not exceed the configured threshold,
3. the service wallet has enough XGR for the grant and fee,
4. the address has no confirmed previous grant,
5. the address has no unresolved broadcast grant,
6. the address has not reached its attempt limit,
7. the global hourly limit is not exceeded,
8. the global daily limit is not exceeded,
9. the client-IP request limits are not exceeded.

### Persistent grant states

```text
reserved
broadcast
confirmed
failed
```

| State | Meaning |
|---|---|
| `reserved` | Policy checks passed and a send attempt is being prepared. |
| `broadcast` | A transaction hash exists and confirmation is pending or unresolved. |
| `confirmed` | The grant transaction succeeded on-chain. |
| `failed` | An eligible failed attempt was recorded. |

### Broadcast safety

When an existing record is in `broadcast` state, the gateway checks its transaction receipt.

If the transaction is still pending:

```json
{
  "grant_created": false,
  "grant_status": "broadcast",
  "retry_allowed": false
}
```

Do not repeat the request.

If the transaction later confirms successfully, the address becomes permanently ineligible for another grant.

### Failure result

A failure returns `isError=true` at the MCP level and structured content similar to:

```json
{
  "grant_created": false,
  "grant_status": "not_reserved",
  "amount_xgr": 1,
  "retry_allowed": false,
  "error": {
    "message": "Recipient balance exceeds the configured eligibility limit."
  }
}
```

The exact status and retry flag depend on the lifecycle stage.

### Retry rules

A retry may be allowed only after:

- a pre-broadcast failure,
- a transaction confirmed with failure status,
- a stale reservation that expired before broadcast.

A retry is not allowed after:

- a confirmed successful grant,
- an unresolved broadcast transaction,
- the maximum number of address attempts,
- an active rate-limit rejection.

### IP limits

Only `request_xgr_starter_gas` consumes starter-gas client-IP quota.

The IP request is persisted before later chain and balance checks. Failed requests can therefore consume IP quota.

Limit failures are returned as MCP errors rather than HTTP `429`.

### Custody and signing model

The server signs only:

```text
fixed native XGR transfers
from the dedicated starter-gas service wallet
```

It cannot sign on behalf of the recipient or any other wallet.

No repayment is required.

### Known limitations

The current service does not require:

- address ownership proof,
- proof of work,
- CAPTCHA,
- identity verification.

The policy limits financial exposure but is not strong Sybil protection.

## Mainnet XGR purchase

Purchase tools are:

- mainnet-only,
- disabled unless explicitly enabled,
- dependent on the configured XGR purchase API,
- limited by the autonomous EUR policy,
- external-payment only.

### Purchase tools

| Tool | Purpose |
|---|---|
| `get_xgr_purchase_options` | Read live price, stock, policy and payment assets. Always call first. |
| `quote_xgr_purchase` | Non-binding budget estimate. Creates no order. |
| `create_xgr_purchase_order` | Create one live order for an exact integer XGR amount. |
| `create_xgr_purchase_order_by_budget` | Create one live order from a maximum USDC or USDT budget. |

### Mandatory sequence

```text
1. Call get_xgr_purchase_options.
2. Select payment_assets[].key exactly.
3. Inspect requires_sender_wallet.
4. Determine fixed-XGR or maximum-budget mode.
5. Collect all required user-supplied fields.
6. Require explicit terms acceptance.
7. Create exactly one order.
8. Inspect payment_approved and next_action.
9. Pay only from payment_instruction.
```

### Required purchase inputs

| Field | Meaning |
|---|---|
| `payment_asset` | Exact key from `payment_assets[].key`. |
| `name` | Purchaser name supplied by the user. |
| `email` | Valid purchaser email supplied by the user. |
| `country_code` | Two-letter uppercase country code. |
| `xgr_wallet` | User-controlled XGR delivery wallet. |
| `terms_accepted` | Must be `true` after explicit acceptance. |
| `sender_wallet` | Required when the selected payment asset requires it. |

An agent must not invent any of these fields.

### Budget quote

`quote_xgr_purchase` is planning only.

It:

- creates no order,
- reserves no inventory,
- returns no executable payment instruction,
- must not be paid.

### Fixed-XGR order

Use:

```text
create_xgr_purchase_order
```

when the user specifies:

```text
amount_xgr
```

### Budget order

Use:

```text
create_xgr_purchase_order_by_budget
```

when the user specifies:

```text
max_payment_amount
```

Approval requires:

```text
exact_payment_amount <= max_payment_amount
```

A blocked result may still represent an existing inventory reservation.

Do not pay and do not immediately repeat it.

### Approved purchase result

```json
{
  "order_created": true,
  "payment_approved": true,
  "payment_execution": "external",
  "next_action": "external_crypto_payment",
  "payment_instruction_exact": true
}
```

### Uncertain post-order result

```json
{
  "order_created": "unknown",
  "post_completed": true,
  "payment_approved": false,
  "payment_execution": "blocked",
  "next_action": "do_not_pay"
}
```

Do not automatically retry.

## XDaLa session evidence

| Tool | Purpose |
|---|---|
| `get_session_transactions` | Indexed transaction timeline for owner + sessionId. |
| `get_session_status_live` | Live `xgr_sessionAlive` result. |
| `get_sessions_overview` | High-level indexed session analytics. |
| `get_session_receipt_logs` | Decoded engine receipt data, payloads, saves, validity and gas. |
| `list_wakeup_targets_by_address` | Waiting steps an address may wake. |
| `resolve_wakeup_payload_schema` | Required, optional, default and missing wake-up payload fields. |

Encrypted XRC-137 bodies are not decrypted by the gateway.

## Session discovery and analytics

| Tool | Purpose |
|---|---|
| `find_latest_xdala_session` | Resolve the newest indexed session. |
| `get_latest_session_payload` | Return final payload data for the latest session. |
| `get_recent_xdala_sessions` | Recent sessions with optional payload enrichment. |
| `list_xdala_session_owners` | Distinct session owners. |
| `list_xdala_sessions` | Concrete owner + sessionId pairs. |
| `list_xdala_session_ids` | Session IDs grouped by owner. |
| `get_xdala_session_detail` | Full detail for one session. |
| `get_xdala_session_stats` | Session counts, outcomes, duration and errors. |
| `get_xdala_session_timeseries` | Sessions and outcomes over time. |
| `get_xdala_step_stats` | Step validity, failure and gas aggregates. |
| `get_xdala_payload_key_stats` | Payload-key frequency. |
| `get_xdala_payload_term_stats` | Aggregated payload terms. |
| `get_xdala_payload_field_value_stats` | Frequent values for a selected field. |
| `get_xdala_active_sessions_timeseries` | Active or concurrent session counts. |

## Transactions

| Tool | Purpose |
|---|---|
| `get_transaction_evidence` | Combined indexed and live evidence for one hash. |
| `get_transaction_receipt` | Receipt data for one transaction. |
| `search_transactions` | Search by address, hash, value, input, session, block or time. |
| `get_recent_value_transfers` | Recent native XGR transfers. |
| `get_account_transactions` | Incoming, outgoing or all account transactions. |
| `get_block_transactions` | Transactions for a selected block. |
| `get_transaction_stats` | Aggregate transaction statistics. |

## XRC authority and workflow discovery

| Tool | Purpose |
|---|---|
| `get_xrc729_authority` | Read XRC-729 owner and executor start-authority roles. |
| `find_startable_xdala_workflows` | Discover workflows an address may start. |
| `list_xrc729_contracts_by_executor` | Indexed active executor relationships. |

Authority to start a workflow is not proof of the owner of a session that has not yet started.

## XRC contracts and runtime state

| Tool | Purpose |
|---|---|
| `list_xrc_contracts` | List indexed XRC-137 or XRC-729 contracts. |
| `get_xrc_contract` | Read one indexed XRC contract. |
| `list_xrc_events` | Search XRC events. |
| `get_xrc_contract_events` | Event history for one contract. |
| `get_xrc729_ostc_state` | Indexed OSTC state and versions. |
| `get_xrc_owner_summary` | Compact owner XRC summary. |
| `read_xrc729_ostc_json` | Runtime `getOSTC` JSON through `eth_call`. |
| `read_xrc137_rule_json` | Runtime `getRule` JSON through `eth_call`. |
| `resolve_xrc729_process_graph` | Resolve OSTC structure and linked XRC-137 rules. |

## XRC usage, reuse and failures

| Tool | Purpose |
|---|---|
| `get_xrc_usage` | Observed usage for a rule or process. |
| `list_xrc_process_sessions` | Sessions associated with an OSTC ID or hash. |
| `find_reusable_xrc137_rules` | Search for reusable existing rules. |
| `get_unused_xrc137_rules` | Rules with no observed engine usage. |
| `get_xrc_failure_stats` | Invalid and failure statistics. |

Reuse candidates are advisory. Always inspect the runtime rule.

## Documentation and knowledge

| Tool | Purpose |
|---|---|
| `list_xgr_standards` | List supported standards. |
| `list_xgr_docs` | List canonical documentation topics. |
| `get_xgr_doc` | Retrieve one Markdown topic. |
| `get_xdala_authoring_rules` | Retrieve active authoring rules. |
| `get_xgr_standard_reference` | Retrieve a prose standard reference. |
| `get_xgr_standard_schema` | Retrieve a machine-readable schema. |
| `list_xgr_standard_examples` | List example names. |
| `get_xgr_standard_example` | Retrieve one example. |
| `get_xgr_multibundle_reference` | Retrieve MultiBundle documentation. |
| `get_xgr_multibundle_schema` | Retrieve the MultiBundle schema. |
| `get_xgr_session_start_schema` | Retrieve the Session Start schema. |

## Validation

| Tool | Purpose |
|---|---|
| `validate_xgr_multibundle` | Validate canonical `xgr-multi-bundle@1`. |
| `validate_xdala_bundle` | Alias for `validate_xgr_multibundle`. |
| `validate_xgr_session_start_handoff` | Validate canonical `xgr-session-start@1`. |
| `validate_xgr_session_start` | Validate the legacy low-level format. |
| `validate_xrc137_authoring` | Validate an XRC-137 authoring object. |
| `validate_xdala_rules` | Validate expressions against available fields. |
| `validate_xdala_blueprint` | Validate orchestration and cross-step payload flow. |

## Process diagrams

| Tool | Purpose |
|---|---|
| `get_xdala_process_mermaid` | Render Mermaid flowchart text from runtime, bundle or bundle handoff data. |

Supported sources:

```text
runtime
bundle
bundle_handoff
```

## Generic operation handoff

| Tool | Purpose |
|---|---|
| `create_operation_handoff` | Prepare a generic browser-wallet operation. |
| `get_operation_status` | Read operation status. |
| `cancel_operation_handoff` | Cancel pending offchain metadata. |
| `list_recent_operations` | List recent operations without secrets. |

Do not use this family for:

- XDaLa Session Start,
- XGR purchase orders,
- starter-gas grants.

## XDaLa bundle-deploy handoff

| Tool | Purpose |
|---|---|
| `create_xdala_bundle_deploy_handoff` | Store a validated MultiBundle and return a Workbench URL. |
| `get_xdala_bundle_deploy_handoff` | Read bundle and handoff metadata. |
| `get_xdala_bundle_deploy_result` | Read deployed artifact and audit events. |
| `cancel_xdala_bundle_deploy_handoff` | Cancel pending offchain metadata. |

## XDaLa session-start handoff

| Tool | Purpose |
|---|---|
| `create_xdala_session_start_handoff` | Prepare `xgr-session-start@1` and return a Workbench URL. |
| `get_xdala_session_start_handoff` | Read request, authority, ownership summary and result. |
| `get_xdala_session_start_result` | Read terminal result and evidence identifiers. |
| `cancel_xdala_session_start_handoff` | Cancel pending offchain metadata. |

Canonical fields:

```text
sessions[].orchestration
sessions[].ostcId
sessions[].stepId
sessions[].payload
sessions[].maxTotalGas
```

Do not use `entryStepId` as a Workbench Session Start field.

## MCP result metadata

The gateway augments tool registrations with:

- input descriptions,
- output schemas,
- MCP annotations,
- structured result content.

When a tool returns JSON as text, the parsed value is also exposed under:

```json
{
  "structuredContent": {
    "data": {}
  }
}
```

Programmatic integrations should prefer:

```text
result.structuredContent.data
```

over manually parsing text content.
