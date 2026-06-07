# XGR MCP Gateway — Tool Reference

**Document ID:** XGR-MCP-TOOL-REFERENCE  
**Last updated:** 2026-06-07  
**Audience:** Developers, integrators, agent builders  
**Implementation status:** Phase 1 read tools live; handoff tools live  
**Source of truth:** `xgr-mcp-gateway/src/tools`

This catalog lists the tools the gateway registers, grouped by domain. All read tools are read-only. Handoff tools prepare offchain operations only — they never sign, submit, or mutate state (see [Operation Handoff](./XGR-MCP-Operation-Handoff.md)).

> **Conventions.** XDaLa sessions are identified by **owner + sessionId** together; a `sessionId` is not unique on its own. Time windows are passed in hours (e.g. `windowHours=504` for "last 3 weeks"). Native value transfer means `transactions.value > 0`, not gas fees.

---

## Chain

| Tool | Purpose |
|---|---|
| `get_chain_status` | Live chain id, latest block number, gas price. |
| `get_latest_block` | Full latest EVM block. |
| `get_account_live_state` | Balance, nonce, and contract code for an address. |

## XGR protocol

| Tool | Purpose |
|---|---|
| `get_xgr_core_addresses` | XGR core protocol addresses (`xgr_getCoreAddrs`). |
| `get_xgr_circulating_supply` | Circulating supply (`xgr_getCirculatingSupply`). |
| `estimate_xdala_rule_gas` | Validation/branch/grant gas and worst-case totals for an XDaLa/XRC-137 rule (`xgr_estimateRuleGas`). |

## Session evidence

| Tool | Purpose |
|---|---|
| `get_session_transactions` | Transaction timeline (hashes, blocks, fees, iteration steps) for a session. Not full engine payloads. |
| `get_session_status_live` | Live `xgr_sessionAlive` status for owner + sessionId. |
| `get_sessions_overview` | High-level indexed session analytics over a time window. |
| `get_session_receipt_logs` | Decoded engine receipt data for a session step: input payload, API saves, contract saves, execution/rule contract, valid flag, inner gas. |

## Session resolver & analytics

For when the user does not already have owner + sessionId, or wants aggregates.

| Tool | Purpose |
|---|---|
| `find_latest_xdala_session` | Resolve the newest indexed session, optional final receipt payload. |
| `get_latest_xdala_session_payload` | Payload, apiSaves, contractSaves, extras of the latest session. |
| `get_recent_xdala_sessions` | List recent indexed sessions, optional owner filter and payload enrichment. |
| `list_xdala_sessions` | Concrete owner + sessionId pairs, keyset pagination. |
| `list_xdala_session_owners` | Distinct owners that ran sessions. |
| `list_xdala_session_ids_grouped_by_owner` | Session IDs grouped by owner. |
| `get_xdala_session_detail` | Details, timeline, steps, payloads, evidence for owner + sessionId. |
| `get_xdala_session_statistics` | Success/failure counts, average duration, average steps, top errors. |
| `get_xdala_session_timeseries` | Sessions over time (day/week/month buckets). |
| `get_xdala_step_statistics` | Valid/invalid/failed step counts and step gas totals. |
| `get_xdala_payload_key_statistics` | Which payload fields occurred and how often. |
| `get_xdala_payload_term_statistics` | Statistics over all payload terms in a range. |
| `get_xdala_payload_field_value_statistics` | Top values for a specific payload field. |

## Transactions

Chain-wide indexed transaction tools backed by the Explorer read-only Postgres mirror. Use these — not session tools — for global questions about `tx.value`, native transfers, from/to, or block ranges.

| Tool | Purpose |
|---|---|
| `get_transaction_evidence` | What a given transaction hash did. |
| `get_transaction_receipt` | Raw transaction receipt. |
| `search_transactions` | Search by hash, from/to, value predicates, input presence, contract creation, session id, validity/execution flags, block range, or timestamp window. |
| `get_recent_value_transfers` | Recent native transfers where `value > minValueWei`, with count/total summaries. |
| `get_account_transactions` | Inbound/outbound/bidirectional transactions for an account, optionally value-only. |
| `get_block_transactions` | Transactions for a concrete or latest block. |
| `get_transaction_stats` | Compact transaction/value/zero-value/contract-creation/total-value stats. |

## XRC contracts & standards (indexed)

| Tool | Purpose |
|---|---|
| `list_xrc_contracts` | List indexed XRC contracts. |
| `get_xrc_contract` | Get one indexed XRC contract. |
| `get_xrc729_authority` | XRC-729 owner/executor start-authority roles. |
| `get_xrc729_ostc_state` | OSTC state for an XRC-729 contract. |
| `read_xrc729_ostc_json` | Read the OSTC JSON. |
| `read_xrc137_rule_json` | Read an XRC-137 rule JSON. |
| `resolve_xrc729_process_graph` | Resolve the process graph for an XRC-729 orchestration. |
| `find_startable_xdala_workflows` | Discover deployed workflows the user could start. |
| `list_xrc_events` / `get_xrc_contract_events` | Indexed XRC events. |
| `get_xrc_owner_summary` | Owner-level XRC summary. |
| `get_xrc_usage` | XRC session usage. |
| `list_xrc_process_sessions` | Sessions per XRC process. |
| `find_reusable_xrc137_rules` | Reusable XRC-137 rules. |
| `get_unused_xrc137_rules` | XRC-137 rules with no usage. |
| `get_xrc_failure_stats` | XRC failure statistics. |

## Knowledge & validation

See [Authoring & Knowledge](./XGR-MCP-Authoring-and-Knowledge.md) for usage.

| Tool | Purpose |
|---|---|
| `list_xgr_standards` | List agent-readable standards (incl. `xdala-authoring`). |
| `get_xdala_authoring_rules` | Compact XDaLa authoring rules for drafting. |
| `get_xgr_standard_reference` | Prose reference for XRC-137 / XRC-729 / xdala-authoring. |
| `get_xgr_standard_schema` | Machine-readable JSON schema for XRC-137 / XRC-729. |
| `list_xgr_standard_examples` / `get_xgr_standard_example` | Example artifacts. |
| `get_xgr_multibundle_reference` / `get_xgr_multibundle_schema` | Canonical `xgr-multi-bundle@1`. |
| `get_xgr_session_start_schema` | Canonical `xgr-session-start@1` Workbench handoff schema. |
| `validate_xgr_multibundle` / `validate_xdala_bundle` | Validate a deployable `xgr-multi-bundle@1`. |
| `validate_xgr_session_start_handoff` | Validate a canonical `xgr-session-start@1` request. |
| `validate_legacy_session_start` | Validate the legacy low-level session-start payload only (not the Workbench handoff). |

## Diagram

| Tool | Purpose |
|---|---|
| `get_xdala_process_mermaid` | Render an XRC-729 process graph as Mermaid from `runtime`, `bundle`, or `bundle_handoff`. |

## Operations / Handoff

| Tool | Purpose |
|---|---|
| `create_operation_handoff` | Generic offchain operation → browser URL. (Not for starting sessions.) |
| `get_operation_status` / `cancel_operation_handoff` | Track/cancel a generic operation. |
| `create_xdala_bundle_deploy_handoff` | Store a validated `xgr-multi-bundle@1` under a bearer handle → Workbench import URL. |
| `get_xdala_bundle_deploy_handoff` / `get_xdala_bundle_deploy_result` / `cancel_xdala_bundle_deploy_handoff` | Read/cancel a bundle-deploy handoff. |
| `create_xdala_session_start_handoff` | Prepare a `xgr-session-start@1` handoff → Workbench Session Start URL. **Use this for any start/run/launch/queue of a session.** |
| `get_xdala_session_start_handoff` / `get_xdala_session_start_result` / `cancel_xdala_session_start_handoff` | Read/cancel a session-start handoff. |
| `list_recent_operations` | Recent handoffs. Never returns secrets or execution tokens. |

> **Start-authority note.** `owner()/getOwner()` and `getExecutorList()` identify *start-authority* roles, not the owner of a not-yet-started session. The actual session owner/starter is in terminal `result.results[].owner/sessionId/pid` after Workbench start.
