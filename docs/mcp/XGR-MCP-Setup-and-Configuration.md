# XGR MCP Gateway — Setup & Configuration

**Document ID:** XGR-MCP-SETUP  
**Last updated:** 2026-07-20  
**Audience:** Operators self-hosting the gateway  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/config/env.ts`, `.env.example`, `package.json`

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

The gateway can still expose RPC- or API-backed tools when a database-backed tool is unavailable, but full transaction, XRC and session analytics require the corresponding indexed data sources.

## Install

```bash
git clone <private-gateway-repository>
cd xgr-mcp-gateway

npm install
cp .env.example .env
npm run typecheck
npm test
npm run build
```

## Build-time documentation sync

The build command is:

```text
node scripts/sync-xgr-docs.mjs && tsc
```

The sync script downloads canonical Markdown from the private repository:

```text
xgr-network/XGR
```

Set one of:

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
| `404` | Token does not have access to the private repository |

The process environment takes precedence over `.env`. After replacing an expired token, clear old exported values before rebuilding:

```bash
unset GITHUB_TOKEN GH_TOKEN
npm run build
```

## Run modes

### Local stdio

```bash
npm run dev
```

Production build:

```bash
npm start
```

### HTTP

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

`GET /mcp` and `DELETE /mcp` are not supported. Hosted MCP requests are stateless POST requests.

## Core configuration

| Variable | Purpose | Mainnet example |
|---|---|---|
| `XGR_RPC_URL` | Connected XGRChain RPC | `https://rpc.xgr.network` |
| `XGR_EXPLORER_API_URL` | Explorer API base | `https://explorer.xgr.network/api` |
| `MCP_SERVER_NAME` | MCP server name | `xgr-mcp-gateway` |
| `MCP_READONLY` | Read-only runtime flag | `true` |
| `MCP_HTTP_HOST` | HTTP bind address | `127.0.0.1` |
| `MCP_HTTP_PORT` | HTTP bind port | `3100` |

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

## Generic operation handoffs

| Variable | Purpose | Example |
|---|---|---|
| `MCP_OPERATION_STORE_DIR` | Root handoff storage directory | `./data/operations` |
| `MCP_PUBLIC_BASE_URL` | Public gateway base used in returned fetch URLs | `https://mcp.xgr.network` |
| `MCP_OPERATION_PUBLIC_BASE_URL` | Legacy-compatible alias for public base | `https://mcp.xgr.network` |
| `MCP_OPERATION_DEFAULT_TTL_SECONDS` | Default generic-operation TTL | `3600` |
| `MCP_OPERATION_MAX_TTL_SECONDS` | Maximum generic-operation TTL | `86400` |

`MCP_PUBLIC_BASE_URL` takes precedence over `MCP_OPERATION_PUBLIC_BASE_URL`.

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

They must not contain wallet secrets.

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
```

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
