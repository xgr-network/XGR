# XGR MCP Gateway — Setup & Configuration

**Document ID:** XGR-MCP-SETUP  
**Last updated:** 2026-07-26  
**Audience:** Operators self-hosting the gateway  
**Implementation status:** Live  
**Source of truth:** [`xgr-network/xgr-mcp`](https://github.com/xgr-network/xgr-mcp)

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
- npm,
- an XGRChain JSON-RPC endpoint,
- an XGR Explorer API,
- read-only access to Explorer databases for DB-backed analytics,
- persistent storage for operation handoffs,
- access to `xgr-network/XGR` during documentation synchronization,
- correctly configured xDaLa Workbench URLs.

When purchase tools are enabled, the deployment additionally requires:

- access to the XGR purchase API,
- HTTPS connectivity outside localhost,
- a mainnet-only purchase configuration,
- an autonomous EUR policy no greater than `249.99`.

When starter gas is enabled, the deployment additionally requires:

- a dedicated low-balance XGR service wallet,
- a service-only private key supplied through the process environment,
- a persistent writable SQLite path,
- matching Node.js ABI versions during installation and runtime,
- correct reverse-proxy topology for client-IP enforcement,
- explicit hourly, daily, address and balance policies.

Never reuse:

- a treasury key,
- a validator key,
- an exchange key,
- a user wallet,
- a deployment wallet,
- an operational hot wallet with significant funds.

## Install

```bash
git clone https://github.com/xgr-network/xgr-mcp.git
cd xgr-mcp

npm install
cp .env.example .env

npm run typecheck
npm test
npm run build
```

A production deployment should normally use:

```bash
npm ci
```

when a committed lock file is available.

## Build-time documentation synchronization

The build command synchronizes canonical documentation from:

```text
xgr-network/XGR
```

The generated local `XGR/` directory is build output and must not be treated as an independently maintained source.

When anonymous GitHub access is unavailable, set:

```env
GITHUB_TOKEN=github_pat_...
```

or:

```env
GH_TOKEN=github_pat_...
```

The minimum fine-grained repository permission is:

```text
Contents: Read-only
```

Typical failures:

| Status | Meaning |
|---|---|
| `401` | Token invalid, expired or revoked |
| `403` | Token recognized but unauthorized |
| `404` | Repository or requested content unavailable |

The process environment takes precedence over `.env`.

## Run modes

### Local stdio

Development:

```bash
npm run dev
```

Production:

```bash
npm start
```

### HTTP

Development:

```bash
npm run dev:http
```

Production:

```bash
npm run start:http
```

The HTTP server exposes:

```text
POST /mcp
GET /health
```

`GET /mcp` and `DELETE /mcp` are not supported.

## Raw HTTP and SSE framing

MCP HTTP responses may use Server-Sent Events framing.

Example tool listing:

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

Normal MCP clients handle framing automatically.

## Core configuration

| Variable | Purpose | Mainnet example |
|---|---|---|
| `XGR_RPC_URL` | Connected XGRChain RPC | `https://rpc.xgr.network` |
| `XGR_EXPLORER_API_URL` | Explorer API base | `https://explorer.xgr.network/api` |
| `MCP_SERVER_NAME` | MCP server name | `xgr-mcp-gateway-mainnet` |
| `MCP_READONLY` | Normal user-operation mode | `true` |
| `MCP_HTTP_HOST` | HTTP bind address | `127.0.0.1` |
| `MCP_HTTP_PORT` | HTTP bind port | `3100` |

Feature registration is controlled independently through:

```text
XGR_PURCHASE_*
XGR_STARTER_GAS_*
```

`MCP_READONLY=true` does not automatically enable or disable either feature.

It means that ordinary user operations remain read-only or handoff-based.

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

## Operation storage

| Variable | Purpose | Example |
|---|---|---|
| `MCP_OPERATION_STORE_DIR` | Root handoff storage directory | `/var/lib/xgr-mcp/operations` |
| `MCP_PUBLIC_BASE_URL` | Public gateway base | `https://mcp.xgr.network` |
| `MCP_OPERATION_PUBLIC_BASE_URL` | Legacy-compatible alias | `https://mcp.xgr.network` |
| `MCP_OPERATION_DEFAULT_TTL_SECONDS` | Default operation TTL | `3600` |
| `MCP_OPERATION_MAX_TTL_SECONDS` | Maximum operation TTL | `86400` |

`MCP_PUBLIC_BASE_URL` takes precedence over `MCP_OPERATION_PUBLIC_BASE_URL`.

## Bundle-deploy handoffs

| Variable | Purpose | Mainnet example |
|---|---|---|
| `MCP_BUNDLE_DEPLOY_STORE_DIR` | Optional store override | `/var/lib/xgr-mcp/operations/bundle-deploy` |
| `MCP_XDALA_BUNDLE_DEPLOY_BASE_URL` | Workbench import base | `https://xdala.xgr.network/api/bundle-deploy` |
| `MCP_BUNDLE_DEPLOY_DEFAULT_TTL_SECONDS` | Default TTL | `3600` |
| `MCP_BUNDLE_DEPLOY_MAX_TTL_SECONDS` | Maximum TTL | `86400` |

## Session-start handoffs

| Variable | Purpose | Mainnet example |
|---|---|---|
| `MCP_SESSION_START_STORE_DIR` | Optional store override | `/var/lib/xgr-mcp/operations/session-start` |
| `MCP_XDALA_SESSION_START_BASE_URL` | Workbench Session Start base | `https://xdala.xgr.network/session-start` |
| `MCP_SESSION_START_DEFAULT_TTL_SECONDS` | Default TTL | `3600` |
| `MCP_SESSION_START_MAX_TTL_SECONDS` | Maximum TTL | `86400` |

## Mainnet XGR purchase tools

Purchase tools are disabled by default.

Example:

```env
XGR_PURCHASE_TOOLS_ENABLED=true
XGR_PURCHASE_NETWORK=mainnet
XGR_PURCHASE_API_BASE_URL=https://xgr.network
XGR_PURCHASE_MAX_EUR=249.99
```

### Purchase variables

| Variable | Purpose | Required behavior |
|---|---|---|
| `XGR_PURCHASE_TOOLS_ENABLED` | Feature gate | Must be exactly `true`. |
| `XGR_PURCHASE_NETWORK` | Environment | Must be exactly `mainnet`. |
| `XGR_PURCHASE_API_BASE_URL` | Purchase API base | HTTPS outside localhost. |
| `XGR_PURCHASE_MAX_EUR` | Autonomous estimated EUR policy | Positive and no greater than `249.99`. |

When enabled, the following tools are registered:

```text
get_xgr_purchase_options
quote_xgr_purchase
create_xgr_purchase_order
create_xgr_purchase_order_by_budget
```

Purchase tools create orders but do not send stablecoin payments.

## Native XGR starter-gas service

Starter gas is disabled by default.

Example:

```env
XGR_STARTER_GAS_ENABLED=true
XGR_STARTER_GAS_NETWORK=mainnet
XGR_STARTER_GAS_CHAIN_ID=1643
XGR_STARTER_GAS_PRIVATE_KEY=0x...

XGR_STARTER_GAS_MAX_RECIPIENT_BALANCE_XGR=0.1
XGR_STARTER_GAS_MAX_HOURLY_GRANTS=20
XGR_STARTER_GAS_MAX_DAILY_GRANTS=100
XGR_STARTER_GAS_MAX_REQUESTS_PER_IP_HOUR=5
XGR_STARTER_GAS_MAX_REQUESTS_PER_IP_DAY=20
XGR_STARTER_GAS_MAX_ATTEMPTS_PER_ADDRESS=2
XGR_STARTER_GAS_RESERVATION_TIMEOUT_SECONDS=600

XGR_STARTER_GAS_DB_PATH=/var/lib/xgr-mcp/starter-gas-grants-mainnet.sqlite
```

The values above are configuration examples.

Hosted deployments may use different live policy values.

Agents must read the active policy through:

```text
get_xgr_starter_gas_options
```

### Starter-gas variables

| Variable | Purpose |
|---|---|
| `XGR_STARTER_GAS_ENABLED` | Explicit service gate. Must be `true`. |
| `XGR_STARTER_GAS_NETWORK` | `mainnet`, `testnet` or `devnet`. |
| `XGR_STARTER_GAS_CHAIN_ID` | Expected connected chain ID. |
| `XGR_STARTER_GAS_PRIVATE_KEY` | Dedicated service-wallet private key. |
| `XGR_STARTER_GAS_MAX_RECIPIENT_BALANCE_XGR` | Maximum eligible recipient balance. |
| `XGR_STARTER_GAS_MAX_HOURLY_GRANTS` | Global grant cap over a rolling hour. |
| `XGR_STARTER_GAS_MAX_DAILY_GRANTS` | Global grant cap for the UTC day. |
| `XGR_STARTER_GAS_MAX_REQUESTS_PER_IP_HOUR` | Per-client-IP request cap over a rolling hour. |
| `XGR_STARTER_GAS_MAX_REQUESTS_PER_IP_DAY` | Per-client-IP request cap for the UTC day. |
| `XGR_STARTER_GAS_MAX_ATTEMPTS_PER_ADDRESS` | Maximum bounded attempts after eligible failures. |
| `XGR_STARTER_GAS_RESERVATION_TIMEOUT_SECONDS` | Expiry for stale pre-broadcast reservations. |
| `XGR_STARTER_GAS_DB_PATH` | Persistent SQLite database path. |
| `XGR_STARTER_GAS_STORE_PATH` | Legacy JSON import path only. |

### Chain defaults

| Network | Default chain ID |
|---|---:|
| Mainnet | `1643` |
| Testnet | `1879` |
| Devnet | `1887` |

The RPC chain ID is checked before a grant is sent.

### Registered starter-gas tools

When enabled:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

### Financial behavior

The grant amount is fixed:

```text
1 XGR
```

It is not configurable through the tool input.

The tool accepts:

```text
address
purpose
```

`purpose` is optional descriptive metadata.

The tool never accepts:

```text
privateKey
seed
mnemonic
signature
wallet password
```

### Persistent state

SQLite records:

```text
reserved
broadcast
confirmed
failed
```

The database also stores per-IP request timestamps.

SQLite is configured with:

```text
journal_mode = WAL
busy_timeout = 5000
```

Reservation and rate-limit operations use immediate transactions.

### Storage permissions

The service user needs:

- read and write access to the SQLite file,
- create access in its parent directory,
- read access to application files,
- access to the configured environment file.

Example:

```bash
sudo mkdir -p /var/lib/xgr-mcp
sudo chown -R <service-user>:<service-group> /var/lib/xgr-mcp
sudo chmod 750 /var/lib/xgr-mcp
```

### SQLite deployment constraint

Use one active MCP process per SQLite database.

Do not mount the same SQLite file concurrently across multiple hosts.

A horizontally scaled deployment requires a shared transactional limiter and grant store rather than one SQLite file.

### Legacy JSON migration

When `XGR_STARTER_GAS_STORE_PATH` points to a JSON file and no SQLite database exists, confirmed legacy records may be imported once into a sibling `.sqlite` file.

Do not reuse a Devnet starter-gas database on Mainnet.

## Reverse proxy and client-IP limits

The gateway trusts forwarded IP headers only when the direct socket peer is loopback.

Recommended topology:

```text
Internet
   ↓
reverse proxy
   ↓ 127.0.0.1
XGR MCP process
```

Supported headers:

```text
X-Forwarded-For
X-Real-IP
```

The first valid address in `X-Forwarded-For` is used.

When the direct peer is not loopback, the socket address is used and forwarding headers are ignored.

A reverse proxy connected through a Docker bridge or other non-loopback address will not provide individual forwarded client IPs under the current trust policy.

Only:

```text
request_xgr_starter_gas
```

consumes starter-gas per-IP quota.

Limit failures are returned as MCP tool errors rather than HTTP `429`.

## Native dependency and Node.js ABI

`better-sqlite3` is a native Node.js dependency.

It must be installed or rebuilt with the same Node.js major version used by the runtime service.

A mismatch may produce:

```text
NODE_MODULE_VERSION mismatch
```

Clean rebuild:

```bash
rm -rf node_modules
npm ci
npm rebuild better-sqlite3

npm run typecheck
npm test
npm run build
```

## Health check

```bash
curl -sS http://127.0.0.1:3100/health | jq
```

Expected starter-gas-enabled shape:

```json
{
  "ok": true,
  "name": "xgr-mcp-gateway-mainnet",
  "readOnly": true,
  "userOperationsReadOnly": true,
  "starterGasEnabled": true,
  "serverSigningScope": "dedicated_starter_gas_service_wallet_only",
  "userOrThirdPartyPrivateKeysAccepted": false
}
```

## Verify tool registration

```bash
curl -sS -X POST http://127.0.0.1:3100/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"tools/list",
    "params":{}
  }' \
| sed -n 's/^data:[[:space:]]*//p' \
| jq -r '.result.tools[]?.name' \
| grep -E 'starter_gas|purchase'
```

Expected starter-gas tools:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

## Validation before restart

```bash
npm install
npm run typecheck
npm test
npm run build
```

Do not restart the service after a failed typecheck, test or build.

## Controlled Mainnet grant test

A Mainnet grant test is a real financial and on-chain operation.

Use:

- one controlled address,
- an address below the configured balance threshold,
- exactly one grant request,
- a clear test purpose.

Expected success fields:

```text
network = mainnet
chain_id = 1643
grant_created = true
grant_status = confirmed
amount_xgr = 1
transaction_hash = 0x...
repeat_allowed = false
```

Do not repeat the request for the same confirmed address.

## Mainnet example

```env
XGR_RPC_URL=https://rpc.xgr.network
XGR_EXPLORER_API_URL=https://explorer.xgr.network/api

MCP_SERVER_NAME=xgr-mcp-gateway-mainnet
MCP_READONLY=true
MCP_HTTP_HOST=127.0.0.1
MCP_HTTP_PORT=3100

MCP_OPERATION_STORE_DIR=/var/lib/xgr-mcp/operations
MCP_PUBLIC_BASE_URL=https://mcp.xgr.network
MCP_XDALA_BUNDLE_DEPLOY_BASE_URL=https://xdala.xgr.network/api/bundle-deploy
MCP_XDALA_SESSION_START_BASE_URL=https://xdala.xgr.network/session-start
MCP_PUBLIC_HANDOFF_ALLOWED_ORIGINS=https://xdala.xgr.network

XGR_PURCHASE_TOOLS_ENABLED=true
XGR_PURCHASE_NETWORK=mainnet
XGR_PURCHASE_API_BASE_URL=https://xgr.network
XGR_PURCHASE_MAX_EUR=249.99

XGR_STARTER_GAS_ENABLED=true
XGR_STARTER_GAS_NETWORK=mainnet
XGR_STARTER_GAS_CHAIN_ID=1643
XGR_STARTER_GAS_PRIVATE_KEY=0x...
XGR_STARTER_GAS_MAX_RECIPIENT_BALANCE_XGR=0.1
XGR_STARTER_GAS_MAX_HOURLY_GRANTS=20
XGR_STARTER_GAS_MAX_DAILY_GRANTS=100
XGR_STARTER_GAS_MAX_REQUESTS_PER_IP_HOUR=5
XGR_STARTER_GAS_MAX_REQUESTS_PER_IP_DAY=20
XGR_STARTER_GAS_MAX_ATTEMPTS_PER_ADDRESS=2
XGR_STARTER_GAS_RESERVATION_TIMEOUT_SECONDS=600
XGR_STARTER_GAS_DB_PATH=/var/lib/xgr-mcp/starter-gas-grants-mainnet.sqlite
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

XGR_PURCHASE_TOOLS_ENABLED=false
XGR_STARTER_GAS_ENABLED=false
```

## Public HTTP routes

| Route | Method | Purpose |
|---|---|---|
| `/health` | `GET` | Health, runtime and signing-scope metadata |
| `/mcp` | `POST` | Stateless MCP endpoint |
| `/operations/:id` | `GET` | Generic operation page |
| `/api/operations/:id` | `GET` | Generic operation state |
| `/api/operations/:id/status` | `POST` | Generic operation callback |
| `/api/bundle-deploy/:handle` | `GET` | Fetch bundle-deploy handoff |
| `/api/bundle-deploy/:handle/status` | `POST` | Record deployment status |
| `/api/bundle-deploy/:handle/result` | `POST` | Record terminal deployment result |
| `/api/session-start/:handle` | `GET` | Fetch Session Start handoff |
| `/api/session-start/:handle/result` | `POST` | Record terminal Session Start result |

Purchase and starter-gas tools do not add separate public HTTP routes.

They are invoked through the MCP endpoint.

## Deployment checklist

Before exposing an instance publicly:

- verify the RPC chain ID,
- verify the Explorer API environment,
- confirm Explorer database credentials are read-only,
- set the correct public MCP URL,
- set environment-matching Workbench URLs,
- configure allowed Workbench origins,
- verify handoff rate limits,
- verify audit-log permissions,
- verify handoff storage permissions,
- verify TTL values,
- call `get_xgr_network_info`,
- call `get_chain_status`,
- create and cancel a test handoff,
- verify that no secret appears in public responses.

When purchase tools are enabled:

- confirm `XGR_PURCHASE_NETWORK=mainnet`,
- confirm `XGR_PURCHASE_MAX_EUR <= 249.99`,
- call `get_xgr_purchase_options`,
- inspect payment assets and chains,
- create only a controlled low-value test order,
- verify blocked orders return `do_not_pay`,
- verify the gateway does not send the payment.

When starter gas is enabled:

- confirm the service wallet is dedicated and low balance,
- confirm the private key belongs only to that wallet,
- confirm the RPC chain ID,
- confirm the SQLite path is persistent,
- confirm the service user can write to the SQLite directory,
- confirm the database is not shared across hosts,
- confirm the Node.js ABI matches `better-sqlite3`,
- confirm forwarded IPs are trusted only through loopback,
- call `get_xgr_starter_gas_options`,
- verify all live caps,
- perform one controlled grant,
- verify the transaction is confirmed,
- verify the same address cannot receive another grant,
- monitor service-wallet balance,
- monitor failed, broadcast and confirmed records,
- monitor hourly and daily usage.
