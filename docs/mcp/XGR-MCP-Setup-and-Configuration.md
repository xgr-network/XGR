# XGR MCP Gateway — Setup & Configuration

**Document ID:** XGR-MCP-SETUP  
**Last updated:** 2026-08-15  
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

---

# Prerequisites

A complete self-hosted deployment requires:

- Node.js with ESM support,
- npm,
- an XGRChain JSON-RPC endpoint,
- an XGR Explorer API,
- read-only access to the Explorer PostgreSQL database for DB-backed analytics,
- persistent storage for operation handoffs,
- access to `xgr-network/XGR` during documentation synchronization,
- correctly configured xDaLa Workbench URLs.

The current public implementation additionally exposes Explorer-backed:

- native-XGR relation graphs,
- graph-edge transaction lookup,
- transaction relation tracing,
- native-XGR value-flow analysis,
- XDaLa Session Start payload history.

The connected Explorer installation must therefore support the corresponding API and indexed database structures.

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

Never reuse the starter-gas key from:

- a treasury wallet,
- a validator,
- an exchange wallet,
- a user wallet,
- a deployment wallet,
- an operational hot wallet with significant funds.

---

# Install

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

---

# Build-time documentation synchronization

The build command synchronizes canonical documentation from:

```text
xgr-network/XGR
```

The generated local `XGR/` directory is build output and must not be maintained independently.

When anonymous GitHub access is unavailable, set either:

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

Typical GitHub failures:

| Status | Meaning |
|---|---|
| `401` | Token invalid, expired or revoked |
| `403` | Token recognized but unauthorized |
| `404` | Repository or requested content unavailable |

The process environment takes precedence over `.env`.

---

# Run modes

## Local stdio

Development:

```bash
npm run dev
```

Production:

```bash
npm start
```

## HTTP

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

---

# Raw HTTP and SSE framing

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

---

# Core configuration

| Variable | Purpose | Mainnet example |
|---|---|---|
| `XGR_RPC_URL` | Connected XGRChain RPC | `https://rpc.xgr.network` |
| `XGR_EXPLORER_API_URL` | Explorer API base | `https://explorer.xgr.network/api` |
| `MCP_SERVER_NAME` | MCP server name | `xgr-mcp-gateway-mainnet` |
| `MCP_READONLY` | Normal user-operation mode | `true` |
| `MCP_HTTP_HOST` | HTTP bind address | `127.0.0.1` |
| `MCP_HTTP_PORT` | HTTP bind port | `3100` |

Optional state-changing feature registration is controlled independently through:

```text
XGR_PURCHASE_*
XGR_STARTER_GAS_*
```

`MCP_READONLY=true` describes ordinary user operations.

It does not automatically enable or disable purchase or starter-gas functionality.

Read-only relation-graph, value-flow and payload-history tools do not require a separate feature gate in the current implementation.

---

# Explorer API requirements

The configured:

```text
XGR_EXPLORER_API_URL
```

is used for Explorer-backed transaction, session and graph evidence.

The current relation and value-flow implementation requires Explorer routes equivalent to:

```text
/v2/addresses/:address/graph
/v2/addresses/:address/graph/neighbors
/v2/graph/edge-transactions
/v2/value-flow/transactions/:txHash
```

With:

```env
XGR_EXPLORER_API_URL=https://explorer.xgr.network/api
```

the gateway therefore calls endpoints below:

```text
https://explorer.xgr.network/api/v2/...
```

Operators must ensure the connected Explorer version supports these routes.

The affected MCP tools are:

```text
get_address_relation_graph
expand_address_relation_graph
trace_xgr_transaction
trace_xgr_value_flow
get_relation_edge_transactions
```

These tools are read-only.

No private key is required.

---

# Explorer database configuration

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

The PostgreSQL credentials used by the MCP should not have mutation permissions.

---

# XDaLa start-payload-history requirements

The tool:

```text
get_xdala_start_payload_history
```

reads indexed XDaLa execution evidence directly through the read-only Explorer database adapter.

The current implementation queries:

```text
tx_receipts
```

and depends on indexed fields equivalent to:

```text
receipt_from_address
engine_session_id
engine_ostc_id
engine_step_id
engine_orchestration
engine_payload
tx_hash
block_number
updated_at
```

The database account remains read-only.

The tool performs no database mutation.

For each matching:

```text
owner + sessionId
```

it selects the first matching entry-step receipt and aggregates scalar payload values in gateway memory.

If the connected Explorer schema does not provide the required indexed fields, this tool cannot return valid history even if it is registered by the MCP server.

---

# Operation storage

| Variable | Purpose | Example |
|---|---|---|
| `MCP_OPERATION_STORE_DIR` | Root handoff storage directory | `/var/lib/xgr-mcp/operations` |
| `MCP_PUBLIC_BASE_URL` | Public gateway base | `https://mcp.xgr.network` |
| `MCP_OPERATION_PUBLIC_BASE_URL` | Legacy-compatible alias | `https://mcp.xgr.network` |
| `MCP_OPERATION_DEFAULT_TTL_SECONDS` | Default operation TTL | `3600` |
| `MCP_OPERATION_MAX_TTL_SECONDS` | Maximum operation TTL | `86400` |

`MCP_PUBLIC_BASE_URL` takes precedence over:

```text
MCP_OPERATION_PUBLIC_BASE_URL
```

---

# Bundle-deploy handoffs

| Variable | Purpose | Mainnet example |
|---|---|---|
| `MCP_BUNDLE_DEPLOY_STORE_DIR` | Optional store override | `/var/lib/xgr-mcp/operations/bundle-deploy` |
| `MCP_XDALA_BUNDLE_DEPLOY_BASE_URL` | Workbench import base | `https://xdala.xgr.network/api/bundle-deploy` |
| `MCP_BUNDLE_DEPLOY_DEFAULT_TTL_SECONDS` | Default TTL | `3600` |
| `MCP_BUNDLE_DEPLOY_MAX_TTL_SECONDS` | Maximum TTL | `86400` |

If no bundle-deploy storage override is configured, the implementation may derive its storage path from the main operation store.

---

# Session-start handoffs

| Variable | Purpose | Mainnet example |
|---|---|---|
| `MCP_SESSION_START_STORE_DIR` | Optional store override | `/var/lib/xgr-mcp/operations/session-start` |
| `MCP_XDALA_SESSION_START_BASE_URL` | Workbench Session Start base | `https://xdala.xgr.network/session-start` |
| `MCP_SESSION_START_DEFAULT_TTL_SECONDS` | Default TTL | `3600` |
| `MCP_SESSION_START_MAX_TTL_SECONDS` | Maximum TTL | `86400` |

Configure Workbench URLs for the same network as the connected RPC and Explorer.

---

# Mainnet XGR purchase tools

Purchase tools are disabled by default.

Example:

```env
XGR_PURCHASE_TOOLS_ENABLED=true
XGR_PURCHASE_NETWORK=mainnet
XGR_PURCHASE_API_BASE_URL=https://xgr.network
XGR_PURCHASE_MAX_EUR=249.99
```

## Purchase variables

| Variable | Purpose | Required behavior |
|---|---|---|
| `XGR_PURCHASE_TOOLS_ENABLED` | Feature gate | Must be exactly `true`. |
| `XGR_PURCHASE_NETWORK` | Purchase environment | Must be exactly `mainnet`. |
| `XGR_PURCHASE_API_BASE_URL` | Purchase API base | HTTPS outside localhost. |
| `XGR_PURCHASE_MAX_EUR` | Autonomous estimated EUR policy | Positive and no greater than `249.99`. |

When enabled, the gateway registers:

```text
get_xgr_purchase_options
quote_xgr_purchase
create_xgr_purchase_order
create_xgr_purchase_order_by_budget
```

Purchase tools create live backend orders where applicable.

They do not send the stablecoin payment.

Approved order responses return a structured:

```text
payment_instruction
```

External payment is permitted only when:

```text
payment_approved = true
next_action = external_crypto_payment
```

A blocked or uncertain order uses:

```text
next_action = do_not_pay
```

---

# Purchase policy notes

The autonomous MCP purchase policy is limited by:

```env
XGR_PURCHASE_MAX_EUR
```

The public configuration maximum is:

```text
249.99 EUR
```

This is an MCP policy limit.

It must not be confused with backend billing-address rules.

The purchase backend may independently require additional billing information at higher order values.

A purchase error after an order POST must not be handled by blindly repeating the order.

---

# Native XGR starter-gas service

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

These values are configuration examples.

Hosted deployments may use different policy values.

Clients must read the active deployment policy through:

```text
get_xgr_starter_gas_options
```

instead of assuming the `.env.example` defaults.

---

## Starter-gas variables

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
| `XGR_STARTER_GAS_MAX_ATTEMPTS_PER_ADDRESS` | Maximum bounded attempts for an address. |
| `XGR_STARTER_GAS_RESERVATION_TIMEOUT_SECONDS` | Expiry for stale pre-broadcast reservations. |
| `XGR_STARTER_GAS_DB_PATH` | Persistent SQLite database path. |
| `XGR_STARTER_GAS_STORE_PATH` | Legacy JSON import path only. |

---

## Chain defaults

| Network | Default chain ID |
|---|---:|
| Mainnet | `1643` |
| Testnet | `1879` |
| Devnet | `1887` |

The connected RPC chain ID is verified before a starter-gas grant is sent.

---

## Registered starter-gas tools

When enabled:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

---

## Financial behavior

The grant amount is fixed:

```text
1 XGR
```

It is not configurable by the tool caller.

The request accepts:

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

---

# Starter-gas persistent state

The SQLite grant lifecycle uses:

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

Reservation and rate-limit operations use transactional locking.

A grant already recorded as `broadcast` must not simply be sent again.

The service first reconciles its transaction receipt.

---

# Starter-gas storage permissions

The service user requires:

- read and write access to the SQLite file,
- create access in the database parent directory,
- read access to application files,
- access to the configured environment.

Example:

```bash
sudo mkdir -p /var/lib/xgr-mcp
sudo chown -R <service-user>:<service-group> /var/lib/xgr-mcp
sudo chmod 750 /var/lib/xgr-mcp
```

The environment file containing:

```text
XGR_STARTER_GAS_PRIVATE_KEY
```

must not be readable by unrelated users.

---

# SQLite deployment constraint

Use one active MCP process per starter-gas SQLite database.

Do not mount the same SQLite file concurrently across multiple hosts.

For horizontally scaled gateway deployments, starter-gas accounting requires a shared transactional grant and rate-limit backend instead of independent access to one SQLite file.

---

# Legacy starter-gas JSON migration

`XGR_STARTER_GAS_STORE_PATH` exists only for legacy migration.

When it points to a legacy JSON file and no SQLite database exists, confirmed legacy records may be imported once into a sibling SQLite database.

Do not reuse a starter-gas database between networks.

In particular, do not reuse a Devnet or Testnet database on Mainnet.

---

# Reverse proxy and client-IP limits

The gateway trusts forwarded IP headers only when the direct socket peer is loopback.

Recommended topology:

```text
Internet
   ↓
reverse proxy
   ↓ 127.0.0.1
XGR MCP process
```

Supported forwarding headers:

```text
X-Forwarded-For
X-Real-IP
```

The first valid address in:

```text
X-Forwarded-For
```

is used.

When the direct peer is not loopback, the direct socket address is used and forwarded headers are ignored.

This prevents arbitrary public clients from supplying trusted forwarding headers.

A reverse proxy connected through a Docker bridge or another non-loopback interface will not provide individual forwarded client IPs under the current trust policy.

Only:

```text
request_xgr_starter_gas
```

consumes starter-gas per-IP quota.

Normal MCP reads are not affected by the starter-gas IP limits.

Starter-gas limit failures are returned as MCP tool errors rather than HTTP `429`.

---

# Native dependency and Node.js ABI

The project uses:

```text
better-sqlite3
```

for starter-gas persistence.

`better-sqlite3` is a native Node.js dependency.

It must be installed or rebuilt with the same Node.js ABI used by the runtime service.

An ABI mismatch may produce errors such as:

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

---

# Health check

```bash
curl -sS http://127.0.0.1:3100/health | jq
```

A starter-gas-enabled deployment may expose metadata similar to:

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

`readOnly` or `userOperationsReadOnly` describes normal user-controlled operations.

An explicitly enabled starter-gas service is the narrow service-wallet signing exception.

---

# Verify tool registration

List all registered tools:

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
| jq -r '.result.tools[]?.name'
```

---

## Verify graph and value-flow tools

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
| grep -E 'relation_graph|trace_xgr|relation_edge'
```

Expected:

```text
get_address_relation_graph
expand_address_relation_graph
trace_xgr_transaction
trace_xgr_value_flow
get_relation_edge_transactions
```

---

## Verify payload-history tool

Expected:

```text
get_xdala_start_payload_history
```

---

## Verify purchase tools

When purchase tooling is enabled:

```text
get_xgr_purchase_options
quote_xgr_purchase
create_xgr_purchase_order
create_xgr_purchase_order_by_budget
```

---

## Verify starter-gas tools

When starter gas is enabled:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

---

# Validation before restart

Before deploying a changed MCP version:

```bash
npm install
npm run typecheck
npm test
npm run build
```

For reproducible production installs prefer:

```bash
npm ci
npm run typecheck
npm test
npm run build
```

Do not restart the production service after a failed:

- typecheck,
- test,
- build.

---

# Graph-tool smoke test

Use a known public XGRChain address.

Verify:

```text
get_address_relation_graph
```

with a small graph first.

Then verify:

```text
expand_address_relation_graph
```

and:

```text
get_relation_edge_transactions
```

for a returned edge.

For a known native-XGR transaction, verify:

```text
trace_xgr_transaction
trace_xgr_value_flow
```

Confirm that:

- the connected Explorer environment is correct,
- graph bounds are respected,
- truncation metadata is preserved,
- relation data is not presented as identity evidence,
- value-flow output is presented as attribution rather than per-coin proof.

---

# XDaLa payload-history smoke test

Use a known deployed XRC-729 workflow with historical sessions.

Call:

```text
get_xdala_start_payload_history
```

with the correct:

```text
xrc729Address
ostcId
stepId
```

Confirm:

```text
source = explorer_db
```

and inspect:

```text
sampledSessions
valuesByField
```

Verify that:

- historical sessions are returned,
- scalar values are aggregated,
- `__*` internal payload keys are excluded,
- the data is treated as historical evidence rather than current schema defaults.

---

# Controlled Mainnet starter-gas test

A Mainnet starter-gas test is a real financial and on-chain operation.

Use:

- one controlled address,
- an address below the configured live balance threshold,
- exactly one grant request,
- a clear test purpose.

First call:

```text
get_xgr_starter_gas_options
```

and verify the live policy.

Expected successful grant fields include:

```text
network = mainnet
chain_id = 1643
grant_created = true
grant_status = confirmed
amount_xgr = 1
transaction_hash = 0x...
repeat_allowed = false
```

Do not repeat the request for a confirmed address.

---

# Mainnet example

```env
XGR_RPC_URL=https://rpc.xgr.network
XGR_EXPLORER_API_URL=https://explorer.xgr.network/api

MCP_SERVER_NAME=xgr-mcp-gateway-mainnet
MCP_READONLY=true
MCP_HTTP_HOST=127.0.0.1
MCP_HTTP_PORT=3100

PGRO_HOST=127.0.0.1
PGRO_PORT=5432
PGRO_USER=xgr_reader
PGRO_PASSWORD=
PGRO_DB=xgrscan
PGRO_POOL_MAX=4
PGRO_STATEMENT_TIMEOUT_MS=5000

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

The `0.1 XGR` recipient-balance value above is an example configuration matching the repository default.

It is not guaranteed to match the hosted Mainnet policy.

Use:

```text
get_xgr_starter_gas_options
```

for the active hosted value.

---

# Testnet example

```env
XGR_RPC_URL=https://rpc1.testnet.xgr.network
XGR_EXPLORER_API_URL=https://explorer.testnet.xgr.network/api

MCP_SERVER_NAME=xgr-mcp-gateway-testnet
MCP_READONLY=true
MCP_HTTP_HOST=127.0.0.1
MCP_HTTP_PORT=3100

PGRO_HOST=127.0.0.1
PGRO_PORT=5432
PGRO_USER=xgr_reader
PGRO_PASSWORD=
PGRO_DB=xgrscan
PGRO_POOL_MAX=4
PGRO_STATEMENT_TIMEOUT_MS=5000

MCP_PUBLIC_BASE_URL=https://mcp.testnet.xgr.network
MCP_XDALA_BUNDLE_DEPLOY_BASE_URL=https://xdala.testnet.xgr.network/api/bundle-deploy
MCP_XDALA_SESSION_START_BASE_URL=https://xdala.testnet.xgr.network/session-start

XGR_PURCHASE_TOOLS_ENABLED=false
XGR_STARTER_GAS_ENABLED=false
```

---

# Public HTTP routes

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

Purchase and starter-gas functionality does not add separate public HTTP routes.

Relation graph, value-flow and payload-history functionality also does not add separate MCP Gateway routes.

These capabilities are exposed as tools through:

```text
POST /mcp
```

The graph and value-flow tools internally call the configured Explorer API.

---

# Deployment checklist

Before exposing an MCP instance publicly:

- verify the RPC chain ID,
- verify the Explorer API network,
- verify the Explorer API supports the relation-graph endpoints,
- verify the Explorer API supports native-XGR value-flow analysis,
- confirm Explorer PostgreSQL credentials are read-only,
- confirm the Explorer database exposes the required XDaLa receipt fields,
- set the correct public MCP URL,
- set network-matching Workbench URLs,
- configure allowed Workbench origins,
- verify handoff rate limits,
- verify audit-log permissions,
- verify handoff storage permissions,
- verify TTL values,
- call `get_xgr_network_info`,
- call `get_chain_status`,
- test a small address relation graph,
- test one known transaction trace,
- test one known native-XGR value-flow request,
- test one known XDaLa payload-history query,
- create and cancel a test handoff,
- verify no secret appears in public responses.

When purchase tools are enabled:

- confirm `XGR_PURCHASE_NETWORK=mainnet`,
- confirm `XGR_PURCHASE_MAX_EUR <= 249.99`,
- call `get_xgr_purchase_options`,
- inspect the returned payment assets,
- inspect `requires_sender_wallet`,
- inspect machine-readable agent guidance,
- create only a controlled low-value test order,
- verify an approved order contains an exact `payment_instruction`,
- verify blocked orders return `do_not_pay`,
- verify the MCP does not send the stablecoin payment.

When starter gas is enabled:

- confirm the service wallet is dedicated,
- keep the service wallet intentionally low balance,
- confirm the private key belongs only to that service wallet,
- confirm the configured RPC chain ID,
- confirm the SQLite path is persistent,
- confirm the service user can write to the SQLite directory,
- confirm the database is not shared concurrently across hosts,
- confirm the runtime Node.js ABI matches `better-sqlite3`,
- confirm forwarded IPs are trusted only through loopback,
- call `get_xgr_starter_gas_options`,
- verify all live caps,
- perform exactly one controlled grant test,
- verify the transaction confirms,
- verify the same address cannot receive another confirmed grant,
- monitor service-wallet balance,
- monitor `failed`, `broadcast` and `confirmed` records,
- monitor hourly and daily usage.
