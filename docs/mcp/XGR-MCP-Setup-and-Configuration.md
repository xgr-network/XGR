# XGR MCP Gateway — Setup & Configuration

**Document ID:** XGR-MCP-SETUP  
**Last updated:** 2026-07-21  
**Audience:** Operators self-hosting the gateway  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/config/env.ts`, `src/shared/purchaseConfig.ts`, `.env.example`, `package.json`

> **Self-hosting only**
>
> Most users should connect directly to the hosted mainnet or testnet MCP endpoint. This page is for operators running their own gateway instance.

---

## Hosted endpoints

### Mainnet

```text
https://mcp.xgr.network/mcp
```

### Testnet

```text
https://mcp.testnet.xgr.network/mcp
```

### Testnet Faucet

```text
https://faucet.xgr.network
```

## Prerequisites

A complete self-hosted deployment requires:

- Node.js with ESM support,
- an XGRChain JSON-RPC endpoint,
- an XGR Explorer API,
- read access to the relevant Explorer databases for DB-backed analytics,
- persistent storage for handoff records,
- access to the canonical `xgr-network/XGR` documentation repository during build,
- correctly configured xDaLa Workbench base URLs.

When mainnet purchase tools are enabled, the deployment additionally requires:

- access to the XGR purchase API,
- HTTPS connectivity to the purchase API outside localhost,
- an explicit mainnet purchase configuration,
- an autonomous EUR policy no greater than `249.99`.

The gateway can still expose RPC- or API-backed tools when a database-backed tool is unavailable, but full transaction, XRC and session analytics require the corresponding indexed data sources.

## Install

```bash
git clone <gateway-repository>
cd xgr-mcp-gateway

npm install
cp .env.example .env
npm run typecheck
npm test
npm run build
```

## Build-time documentation sync

The build command includes:

```text
node scripts/sync-xgr-docs.mjs && tsc
```

The sync script downloads canonical Markdown from:

```text
xgr-network/XGR
```

When anonymous repository access is unavailable in the deployment environment, set one of:

```env
GITHUB_TOKEN=github_pat_...
```

or:

```env
GH_TOKEN=github_pat_...
```

The token requires read access to repository contents for `xgr-network/XGR`.

For a fine-grained token, the minimum repository permission is:

```text
Contents: Read-only
```

Typical failures:

| Status | Meaning |
|---|---|
| `401` | Token invalid, expired or revoked |
| `403` | Token recognized but blocked or insufficiently authorized |
| `404` | Repository or requested content is unavailable to the supplied credentials |

The process environment takes precedence over `.env`.

After replacing an expired token, clear old exported values before rebuilding:

```bash
unset GITHUB_TOKEN GH_TOKEN
npm run build
```

## Run modes

### Local stdio

Development:

```bash
npm run dev
```

Production build:

```bash
npm start
```

### HTTP

Development:

```bash
npm run dev:http
```

Production build:

```bash
npm run start:http
```

The HTTP server exposes:

```text
POST /mcp
GET /health
```

`GET /mcp` and `DELETE /mcp` are not supported.

Hosted MCP requests are stateless POST requests.

### Raw HTTP and SSE framing

MCP HTTP responses may use Server-Sent Events framing.

Raw command-line clients must remove the `data:` prefix before passing the JSON body to tools such as `jq`.

Example:

```bash
curl -sS -X POST "http://127.0.0.1:3100/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }' \
| sed -n 's/^data:[[:space:]]*//p' \
| jq
```

Normal MCP clients handle transport framing automatically.

## Core configuration

| Variable | Purpose | Mainnet example |
|---|---|---|
| `XGR_RPC_URL` | Connected XGRChain RPC | `https://rpc.xgr.network` |
| `XGR_EXPLORER_API_URL` | Explorer API base | `https://explorer.xgr.network/api` |
| `MCP_SERVER_NAME` | MCP server name | `xgr-mcp-gateway` |
| `MCP_READONLY` | General runtime mode flag | `true` |
| `MCP_HTTP_HOST` | HTTP bind address | `127.0.0.1` |
| `MCP_HTTP_PORT` | HTTP bind port | `3100` |

Purchase tool registration is controlled independently by the `XGR_PURCHASE_*` variables.

Do not assume that `MCP_READONLY=true` automatically enables or disables purchase tools.

## Explorer database configuration

Use a dedicated read-only database role.

| Variable | Purpose | Example |
|---|---|---|
| `PGRO_HOST` | Database host | `127.0.0.1` |
| `PGRO_PORT` | Database port | `5432` |
| `PGRO_USER` | Read-only user | `xgr_reader` |
| `PGRO_PASSWORD` | Read-only password | secret |
| `PGRO_DB` | Explorer database | `xgrscan` |
| `PGRO_POOL_MAX` | Maximum pool connections | `4` |
| `PGRO_STATEMENT_TIMEOUT_MS` | Query timeout | `5000` |

## Mainnet XGR purchase tools

Purchase tools are disabled by default.

They are registered only when the feature is explicitly enabled for mainnet.

Example:

```env
XGR_PURCHASE_TOOLS_ENABLED=true
XGR_PURCHASE_NETWORK=mainnet
XGR_PURCHASE_API_BASE_URL=https://xgr.network
XGR_PURCHASE_MAX_EUR=249.99
```

### Configuration variables

| Variable | Purpose | Required behavior |
|---|---|---|
| `XGR_PURCHASE_TOOLS_ENABLED` | Explicit feature gate | Must be exactly `true`. |
| `XGR_PURCHASE_NETWORK` | Purchase environment | Must be exactly `mainnet`. |
| `XGR_PURCHASE_API_BASE_URL` | XGR purchase API base | Required when enabled. HTTPS outside localhost. |
| `XGR_PURCHASE_MAX_EUR` | Autonomous estimated EUR policy | Positive number no greater than `249.99`. Defaults to `249.99` when omitted after the other activation requirements are met. |

### URL restrictions

The API base must use:

```text
https://
```

except for local development on:

```text
http://localhost
http://127.0.0.1
```

Other plain HTTP URLs are rejected.

### Mainnet-only behavior

The tools are not registered when:

```text
XGR_PURCHASE_NETWORK != mainnet
```

They are therefore absent from correctly configured testnet deployments.

### Registered tools

When enabled, `tools/list` includes:

```text
get_xgr_purchase_options
quote_xgr_purchase
create_xgr_purchase_order
create_xgr_purchase_order_by_budget
```

### Tool effects

| Tool | Effect |
|---|---|
| `get_xgr_purchase_options` | Read-only live price, inventory and payment-asset discovery. |
| `quote_xgr_purchase` | Read-only planning estimate. No order. |
| `create_xgr_purchase_order` | Creates one live backend order and reservation. |
| `create_xgr_purchase_order_by_budget` | Creates one live backend order and reservation, then validates the exact amount against the cap. |

The gateway does not execute stablecoin payments.

An approved order returns:

```text
payment_approved = true
next_action = external_crypto_payment
payment_instruction = { ... }
```

A blocked or uncertain order returns:

```text
next_action = do_not_pay
```

### Purchase policy limits

The hard gateway maximum is:

```text
249.99 EUR
```

The configured value may be lower but not higher.

The minimum estimated order value is:

```text
2 EUR
```

The purchase backend separately requires a complete billing address when its newly calculated order value reaches:

```text
250 EUR
```

The gateway policy and backend billing-address threshold are separate controls.

### Operational requirements

Before enabling purchase tools in production:

- verify that the API base points to the intended production backend,
- verify live price and inventory responses,
- verify the returned payment assets,
- verify chain and decimal metadata,
- confirm the stablecoin custody wallet is controlled by the intended operator,
- confirm the backend reservation TTL,
- confirm the backend does not expose unsafe payment data,
- verify that order POSTs are not automatically retried,
- verify that blocked budget orders remain unpaid,
- verify that uncertain post-order responses return `next_action=do_not_pay`,
- verify the external payment executor reads only the structured `payment_instruction`,
- verify that no private key is supplied to the MCP gateway.

## Generic operation handoffs

| Variable | Purpose | Example |
|---|---|---|
| `MCP_OPERATION_STORE_DIR` | Root handoff storage directory | `./data/operations` |
| `MCP_PUBLIC_BASE_URL` | Public gateway base used in returned fetch URLs | `https://mcp.xgr.network` |
| `MCP_OPERATION_PUBLIC_BASE_URL` | Legacy-compatible alias for public base | `https://mcp.xgr.network` |
| `MCP_OPERATION_DEFAULT_TTL_SECONDS` | Default generic-operation TTL | `3600` |
| `MCP_OPERATION_MAX_TTL_SECONDS` | Maximum generic-operation TTL | `86400` |

`MCP_PUBLIC_BASE_URL` takes precedence over `MCP_OPERATION_PUBLIC_BASE_URL`.

Purchase reservations are not stored in `MCP_OPERATION_STORE_DIR`. They are created and managed by the configured purchase backend.

## Bundle-deploy handoffs

| Variable | Purpose | Mainnet example |
|---|---|---|
| `MCP_BUNDLE_DEPLOY_STORE_DIR` | Optional bundle-deploy store override | `./data/operations/bundle-deploy` |
| `MCP_XDALA_BUNDLE_DEPLOY_BASE_URL` | Workbench import base | `https://xdala.xgr.network/api/bundle-deploy` |
| `MCP_BUNDLE_DEPLOY_DEFAULT_TTL_SECONDS` | Default TTL | `3600` |
| `MCP_BUNDLE_DEPLOY_MAX_TTL_SECONDS` | Maximum TTL | `86400` |

## Session-start handoffs

| Variable | Purpose | Mainnet example |
|---|---|---|
| `MCP_SESSION_START_STORE_DIR` | Optional Session Start store override | `./data/operations/session-start` |
| `MCP_XDALA_SESSION_START_BASE_URL` | Workbench Session Start base | `https://xdala.xgr.network/session-start` |
| `MCP_SESSION_START_DEFAULT_TTL_SECONDS` | Default TTL | `3600` |
| `MCP_SESSION_START_MAX_TTL_SECONDS` | Maximum TTL | `86400` |

The gateway appends the generated `ss_...` handle to the configured base URL.

## Tool usage logging

| Variable | Purpose | Default |
|---|---|---|
| `MCP_TOOL_USAGE_ENABLED` | Enable JSONL tool-call logging | `true` |
| `MCP_TOOL_USAGE_LOG_PATH` | Tool usage log path | `${MCP_OPERATION_STORE_DIR}/audit/tool-usage.jsonl` |

Usage logs include:

- timestamp,
- tool name,
- success or failure,
- duration,
- sanitized error text.

They must not contain:

- wallet private keys,
- seed phrases,
- signing secrets,
- custody credentials.

Public wallet addresses and order metadata may appear in normal application or backend logs depending on deployment. Operators must define appropriate retention and access policies.

## Public handoff security

| Variable | Purpose | Default |
|---|---|---|
| `MCP_PUBLIC_HANDOFF_MAX_BODY_BYTES` | Maximum public request body | `10485760` |
| `MCP_PUBLIC_HANDOFF_ALLOWED_ORIGINS` | Comma-separated origin allowlist | empty |
| `MCP_PUBLIC_HANDOFF_AUDIT_ENABLED` | Enable public-route audit log | `true` |
| `MCP_PUBLIC_HANDOFF_AUDIT_LOG_PATH` | Public handoff audit path | `${MCP_OPERATION_STORE_DIR}/audit/public-handoff.jsonl` |
| `MCP_PUBLIC_HANDOFF_RATE_LIMIT_ENABLED` | Enable handoff rate limiting | `true` |
| `MCP_PUBLIC_HANDOFF_PER_IP_PER_MINUTE` | Per-IP request limit | `120` |
| `MCP_PUBLIC_HANDOFF_PER_HANDLE_PER_MINUTE` | Per-handle read/status limit | `60` |
| `MCP_PUBLIC_HANDOFF_POST_PER_HANDLE_PER_MINUTE` | Per-handle POST limit | `30` |
| `MCP_PUBLIC_HANDOFF_RESULT_PER_HANDLE_PER_MINUTE` | Per-handle terminal-result limit | `10` |

For public production instances, explicitly configure allowed Workbench origins.

These controls apply to public handoff routes.

Purchase API authentication, rate limiting and abuse protection are responsibilities of the purchase backend and its surrounding infrastructure.

## Mainnet example

```env
XGR_RPC_URL=https://rpc.xgr.network
XGR_EXPLORER_API_URL=https://explorer.xgr.network/api

MCP_SERVER_NAME=xgr-mcp-gateway-mainnet
MCP_READONLY=true
MCP_HTTP_HOST=127.0.0.1
MCP_HTTP_PORT=3100

MCP_PUBLIC_BASE_URL=https://mcp.xgr.network
MCP_XDALA_BUNDLE_DEPLOY_BASE_URL=https://xdala.xgr.network/api/bundle-deploy
MCP_XDALA_SESSION_START_BASE_URL=https://xdala.xgr.network/session-start

MCP_PUBLIC_HANDOFF_ALLOWED_ORIGINS=https://xdala.xgr.network

XGR_PURCHASE_TOOLS_ENABLED=true
XGR_PURCHASE_NETWORK=mainnet
XGR_PURCHASE_API_BASE_URL=https://xgr.network
XGR_PURCHASE_MAX_EUR=249.99
```

## Testnet example

```env
XGR_RPC_URL=https://rpc1.testnet.xgr.network
XGR_EXPLORER_API_URL=https://explorer.testnet.xgr.network/api

MCP_SERVER_NAME=xgr-mcp-gateway-testnet
MCP_READONLY=true
MCP_HTTP_HOST=127.0.0.1
MCP_HTTP_PORT=3100

MCP_PUBLIC_BASE_URL=https://mcp.testnet.xgr.network
MCP_XDALA_BUNDLE_DEPLOY_BASE_URL=https://xdala.testnet.xgr.network/api/bundle-deploy
MCP_XDALA_SESSION_START_BASE_URL=https://xdala.testnet.xgr.network/session-start

MCP_PUBLIC_HANDOFF_ALLOWED_ORIGINS=https://xdala.testnet.xgr.network

XGR_PURCHASE_TOOLS_ENABLED=false
```

Do not enable purchase tools on testnet.

## Public HTTP routes

| Route | Method | Purpose |
|---|---|---|
| `/health` | `GET` | Health and mode |
| `/mcp` | `POST` | Stateless MCP endpoint |
| `/operations/:id` | `GET` | Generic human-facing operation page |
| `/api/operations/:id` | `GET` | Generic operation state |
| `/api/operations/:id/status` | `POST` | Generic operation callback |
| `/api/bundle-deploy/:handle` | `GET` | Fetch bundle-deploy handoff |
| `/api/bundle-deploy/:handle/status` | `POST` | Record deployment status |
| `/api/bundle-deploy/:handle/result` | `POST` | Record terminal deployment result |
| `/api/session-start/:handle` | `GET` | Fetch Session Start handoff |
| `/api/session-start/:handle/result` | `POST` | Record terminal Session Start result |

Purchase tools do not add a public purchase route to the gateway. They call `XGR_PURCHASE_API_BASE_URL` internally.

## Deployment checklist

Before exposing an instance publicly:

- verify the RPC chain ID,
- confirm the Explorer API points to the same environment,
- confirm database credentials are read-only,
- set the correct public MCP base URL,
- set environment-matching Workbench URLs,
- configure allowed Workbench origins,
- verify rate limiting,
- verify audit and usage log permissions,
- verify handoff storage permissions,
- verify TTL values,
- confirm no Devnet endpoint is present in public configuration,
- call `get_xgr_network_info`,
- call `get_chain_status`,
- create and cancel a test handoff,
- verify that no secret appears in returned list or status responses.

When purchase tools are enabled:

- confirm `XGR_PURCHASE_NETWORK=mainnet`,
- confirm `XGR_PURCHASE_MAX_EUR <= 249.99`,
- call `get_xgr_purchase_options`,
- confirm `payment_assets[].key`, chain and decimals,
- call `quote_xgr_purchase` with a small valid budget,
- create a controlled low-value test reservation,
- verify `payment_instruction`,
- verify `payment_approved`,
- verify `next_action`,
- verify a blocked budget test returns `do_not_pay`,
- verify the gateway does not send a payment itself,
- verify the order expires or is reconciled correctly,
- verify production tests use controlled wallet addresses.
