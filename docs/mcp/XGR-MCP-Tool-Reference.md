# XGR MCP Gateway — Tool Reference

**Document ID:** XGR-MCP-TOOL-REFERENCE  
**Last updated:** 2026-07-20  
**Audience:** Developers, integrators, agent builders  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/tools`

This document lists the tools currently registered by the XGR MCP Gateway.

Read tools inspect chain, Explorer, contract or knowledge data. Handoff tools store validated offchain requests for later human review and local signing. No MCP tool receives private keys or signs transactions.

> **Session identity**
>
> An XDaLa session is identified by **owner + sessionId**. A session ID is not globally unique on its own.

> **Time windows**
>
> Analytics tools generally use `windowHours`. For example, three weeks is `504`.

> **Native transfers**
>
> Native value refers to `transaction.value`, not gas fees.

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
| `create_operation_handoff` | Prepare a generic browser-wallet operation. Not for XDaLa session starts. |
| `get_operation_status` | Read current generic-operation status. |
| `cancel_operation_handoff` | Cancel pending offchain operation metadata. |
| `list_recent_operations` | List recent operation handoffs without secrets or execution tokens. |

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
