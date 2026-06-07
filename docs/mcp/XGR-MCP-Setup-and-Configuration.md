# XGR MCP Gateway — Setup & Configuration

**Document ID:** XGR-MCP-SETUP  
**Last updated:** 2026-06-07  
**Audience:** Operators self-hosting the gateway  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/.env.example`, `xgr-mcp-gateway/package.json`

---

> **Advanced / self-host only.** Most users do not need this page. To connect an agent to the hosted gateway, see the [Gateway Overview](./XGR-MCP-Gateway-Overview.md) — that is a one-time connector setup with no infrastructure. This page is for operators who run their own instance of the gateway.

## Prerequisites

Self-hosting requires your own backing infrastructure. The gateway is a thin semantic layer over it and will not function without it:

- **An XGRChain JSON-RPC endpoint** (read access).
- **An Explorer instance with a read-only Postgres mirror (`PGRO_*`).** This is a hard requirement for the transaction-search and session-analytics tools — they query the mirror directly. Without it, those tools cannot run. You must stand up the Explorer and its read-only mirror yourself.

Runtime: Node.js (ESM; `"type": "module"`). Dependencies: `@modelcontextprotocol/sdk`, `express`, `pg`, `zod`, `dotenv`.

## Install & run

```bash
npm install
npm run typecheck

# stdio mode (host spawns the server)
npm run dev          # tsx src/index.ts
npm start            # node dist/index.js (after npm run build)

# HTTP mode (POST /mcp + browser handoff routes)
npm run dev:http     # tsx src/http.ts
npm run start:http   # node dist/http.js

npm test             # tsx --test tests/*.test.ts
```

Build with `npm run build` (`tsc`) before using the `start*` scripts.

## Configuration

Copy `.env.example` to `.env` and set values for the target environment.

### Core

| Variable | Purpose | Example |
|---|---|---|
| `XGR_RPC_URL` | XGRChain JSON-RPC endpoint | `https://rpc.xgr.network` |
| `XGR_EXPLORER_API_URL` | Explorer API base | `https://explorer.xgr.network/api` |
| `MCP_SERVER_NAME` | MCP server name | `xgr-mcp-gateway` |
| `MCP_READONLY` | Read-only enforcement | `true` |
| `MCP_HTTP_PORT` | HTTP mode port | `3100` |

### Explorer read-only Postgres (`PGRO_*`)

Backs the chain-wide transaction and session analytics tools. Use a dedicated read-only role.

| Variable | Purpose | Example |
|---|---|---|
| `PGRO_HOST` / `PGRO_PORT` | DB host/port | `127.0.0.1` / `5432` |
| `PGRO_USER` / `PGRO_PASSWORD` | Read-only credentials | `xgr_reader` / … |
| `PGRO_DB` | Database name | `xgrscan` |
| `PGRO_POOL_MAX` | Max pool connections | `4` |
| `PGRO_STATEMENT_TIMEOUT_MS` | Per-statement timeout | `5000` |

> For high-volume native value-transfer queries, a recommended Explorer-side partial index is `(block_number DESC, transaction_index DESC) WHERE value > 0`. The gateway does not create this index.

### Handoff / operation store

| Variable | Purpose | Example |
|---|---|---|
| `MCP_OPERATION_STORE_DIR` | Operation store directory | `./data/operations` |
| `MCP_PUBLIC_BASE_URL` / `MCP_OPERATION_PUBLIC_BASE_URL` | Public base for browser URLs | `https://mcp.xgr.network` |
| `MCP_OPERATION_DEFAULT_TTL_SECONDS` / `MCP_OPERATION_MAX_TTL_SECONDS` | Operation TTL default/cap | `3600` / `86400` |
| `MCP_XDALA_BUNDLE_DEPLOY_BASE_URL` | Workbench bundle-deploy import base | `https://xdala.xgr.network/api/bundle-deploy` |
| `MCP_BUNDLE_DEPLOY_DEFAULT_TTL_SECONDS` / `MCP_BUNDLE_DEPLOY_MAX_TTL_SECONDS` | Bundle-deploy TTL default/cap | `3600` / `86400` |
| `MCP_BUNDLE_DEPLOY_STORE_DIR` *(optional)* | Override bundle-deploy store dir | `${MCP_OPERATION_STORE_DIR}/bundle-deploy` |

## Mainnet checklist

When pointing the gateway at mainnet:

- Set `XGR_RPC_URL` / `XGR_EXPLORER_API_URL` to mainnet endpoints and set the public base URLs to the mainnet host so returned handoff URLs resolve correctly.
- Confirm `MCP_READONLY=true`.
- Ensure the `PGRO_*` role is genuinely read-only and scoped to the Explorer schema.
- Verify handoff base URLs point at the mainnet Workbench so session-start/bundle-deploy URLs land on the right environment.

## HTTP endpoints

| Route | Purpose |
|---|---|
| `GET /health` | Liveness |
| `POST /mcp` | MCP JSON-RPC |
| `GET /operations/:id` | Human-facing operation page |
| `GET /api/operations/:id` | Operation state |
| `POST /api/operations/:id/status` | Local-signing status callback |