# XGR MCP Gateway — Operation Handoff

**Document ID:** XGR-MCP-OPERATION-HANDOFF  
**Last updated:** 2026-06-07  
**Audience:** Developers, integrators, agent builders, auditors  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/operations`

This document describes how the gateway prepares write actions without ever holding keys or signing. It is the bridge between an agent's natural-language intent and a locally-signed, owner-controlled action on XGRChain.

---

## The core idea

The MCP gateway never signs and never custodies keys. Instead it **prepares** an action offchain and hands it off to the user's browser:

1. The agent calls a `create_*_handoff` tool with a validated request.
2. The gateway stores the request offchain under an unguessable bearer **handle** and returns a **browser URL**.
3. The user opens the URL, reviews the action in plain language, connects their own browser wallet/signer, and **signs locally**.
4. The gateway records only **status** and **transaction hashes** as the action progresses. It stores no private keys, signs nothing, and submits no unsigned transactions.

This keeps the trust boundary clean: the agent describes intent, the human verifies and authorizes, the chain records the result.

```
agent ──create_*_handoff──▶ gateway ──stores request, returns URL──▶ agent shows URL to user
                                                                          │
                              user opens URL, reviews, connects wallet ◀──┘
                                          │ signs locally
                                          ▼
                              XGRChain   (gateway records status + tx hashes only)
```

## Three handoff families

### 1. Generic operation handoff
`create_operation_handoff` prepares an arbitrary offchain operation and returns a browser URL under `/operations/:id`. Use it for general local-wallet transactions. **Do not** use it to start, run, or queue XDaLa sessions — route those to the session-start handoff below.

Tracking: `get_operation_status`, `cancel_operation_handoff`, `list_recent_operations`.

### 2. Bundle deploy handoff
`create_xdala_bundle_deploy_handoff` stores a validated `xgr-multi-bundle@1` bundle under a bearer handle and returns an **xDaLa Workbench import URL**. This is the deploy path for a complete XRC-729/XRC-137 process bundle.

Tracking: `get_xdala_bundle_deploy_handoff` (metadata + bundle JSON + any recorded result), `get_xdala_bundle_deploy_result` (deployed artifact + audit events), `cancel_xdala_bundle_deploy_handoff`.

The diagram tool can render a stored handoff directly: `get_xdala_process_mermaid` with `source="bundle_handoff"` and the handle.

### 3. Session start handoff
`create_xdala_session_start_handoff` prepares a canonical `xgr-session-start@1` request and returns a **Workbench Session Start URL** (e.g. `https://xdala.devnet.xgr.network/session-start/ss_...`). This is the path for any *start / run / launch / execute / queue* of a session — whether from a deployed XRC-729 workflow, a runtime orchestration, or a bundle-deploy result.

Canonical request terminology: `sessions[].orchestration`, `sessions[].ostcId`, `sessions[].stepId`, `sessions[].payload`, `sessions[].maxTotalGas`. Do **not** use `entryStepId` — it is not the Workbench Session Start field.

xDaLa Workbench performs the local signing and calls `xgr_validateDataTransfer`. The gateway only prepares and reads.

Tracking: `get_xdala_session_start_handoff` (canonical request, authority, `sessionOwnership` role summary, validation, terminal result), `get_xdala_session_start_result`, `cancel_xdala_session_start_handoff`.

> **Agent guidance.** Before creating a session-start handoff for a deployed XRC-729 workflow: inspect the runtime, identify `ostcId` and the likely entry step, resolve that step's XRC-137 rule, derive required payload fields from the XRC-137 payload schema (fields with defaults are optional), and present required + optional fields to the user. Do not call the tool with guessed payload values; ask for values or explicit permission to use demo values first. Always show the returned `xdalaUrl` to the user — never replace it with a generic `/operations/op_...` link.

## What the gateway never does

- Never receives, stores, or derives private keys.
- Never signs transactions.
- Never submits unsigned transactions.
- Never returns secrets or browser execution tokens from list/read tools.

## Browser-facing routes (HTTP mode)

| Route | Purpose |
|---|---|
| `GET /operations/:id` | Human-facing operation page. |
| `GET /api/operations/:id` | Operation state for the page. |
| `POST /api/operations/:id/status` | Status callback as the user signs/cancels locally. |
| `GET /health` | Liveness. |
| `POST /mcp` | MCP JSON-RPC endpoint. |

## Lifecycle & TTL

Handoffs expire. Defaults and caps are configurable (see [Setup & Configuration](./XGR-MCP-Setup-and-Configuration.md)): operations default to a 1-hour TTL (cap 24h), bundle-deploy handoffs the same. Expired handoffs are reported as expired and are not usable for rendering or execution.
