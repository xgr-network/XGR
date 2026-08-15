# XGR MCP Gateway — Operation Handoff

**Document ID:** XGR-MCP-OPERATION-HANDOFF  
**Last updated:** 2026-08-15  
**Audience:** Developers, integrators, agent builders, auditors  
**Implementation status:** Live  
**Source of truth:** [`xgr-network/xgr-mcp/src/operations`](https://github.com/xgr-network/xgr-mcp/tree/main/src/operations)

The XGR MCP Gateway prepares human-reviewed on-chain actions without receiving or controlling the user's private key.

This document applies specifically to handoff tools.

The following MCP operations are **not** handoffs:

- read-only chain and Explorer queries,
- native XGR relation-graph and value-flow analysis,
- XDaLa start-payload-history queries,
- mainnet XGR purchase orders,
- native XGR starter-gas grants.

---

## Handoff model

A handoff connects:

```text
agent intent
    ↓
validated offchain request
    ↓
temporary protected handle and browser URL
    ↓
human review
    ↓
local wallet signing
    ↓
XGRChain result
```

The handoff boundary deliberately separates:

```text
agent preparation
```

from:

```text
user authorization and signing
```

---

## Core trust boundary

For handoff operations, the gateway may:

- validate an intended operation,
- derive canonical request structures,
- inspect deployed XRC runtime data,
- resolve payload fields,
- inspect relevant indexed evidence,
- verify owner or executor authority,
- store temporary offchain metadata,
- return a browser or Workbench URL,
- receive validated callbacks,
- expose status and audit evidence.

For handoff operations, the gateway does not:

- receive or store user private keys,
- receive seed phrases,
- derive wallet secrets,
- sign user transactions,
- silently start sessions,
- silently deploy contracts,
- bypass local wallet approval.

The browser, xDaLa Workbench or configured local signer performs wallet interaction.

---

## Gateway-wide signing clarification

The optional starter-gas service is a separate, narrowly scoped operation.

It may sign only:

```text
fixed native XGR transfers
from a dedicated starter-gas service wallet
```

This does not change the handoff trust boundary.

The starter-gas service cannot sign:

- a deployment transaction,
- an XDaLa Session Start transaction,
- a user contract call,
- a purchase payment,
- any transaction from the recipient address.

The gateway never requests, receives, stores or controls user or third-party private keys.

---

## Handoff lifecycle

1. The agent gathers the required chain, workflow and payload information.
2. The agent validates the intended artifact or request.
3. The agent calls the correct `create_*_handoff` tool.
4. The gateway stores a temporary protected record.
5. The gateway returns a browser URL or `xdalaUrl`.
6. The agent presents the exact returned URL to the user.
7. The user opens the page and reviews the request.
8. The user connects their own wallet or signer.
9. The browser or Workbench submits locally authorized transactions.
10. The result endpoint records the normalized outcome.
11. Read tools expose status, artifacts and evidence.

A handoff URL is a temporary bearer URL.

It must not be published or treated as a permanent public link.

---

# Handoff families

## Generic operation handoff

Use:

```text
create_operation_handoff
```

for browser-wallet transaction sequences that are not:

- XDaLa bundle deployments,
- XDaLa Session Start requests,
- XGR purchase orders,
- starter-gas grants.

Tracking tools:

```text
get_operation_status
cancel_operation_handoff
list_recent_operations
```

Do not use the generic handoff as a fallback for XDaLa Session Start.

If a dedicated semantic handoff exists, use the dedicated handoff.

---

## XDaLa bundle-deploy handoff

Use:

```text
create_xdala_bundle_deploy_handoff
```

to store a validated:

```text
xgr-multi-bundle@1
```

and obtain an xDaLa Workbench import URL.

The stored record may include:

- network,
- chain ID,
- validation result,
- bundle JSON,
- summary metadata,
- timestamps,
- status events,
- normalized deployment result,
- deployed artifact.

Tracking tools:

```text
get_xdala_bundle_deploy_handoff
get_xdala_bundle_deploy_result
cancel_xdala_bundle_deploy_handoff
```

The MCP prepares the deployment.

It does not sign the deployment transaction.

---

## XDaLa Session Start handoff

Use:

```text
create_xdala_session_start_handoff
```

for requests to:

- start a deployed XDaLa session,
- run a deployed workflow,
- launch a process,
- execute an XDaLa workflow,
- queue multiple Session Starts,
- start a workflow from a bundle-deploy result.

Typical Workbench bases:

```text
Mainnet: https://xdala.xgr.network/session-start
Testnet: https://xdala.testnet.xgr.network/session-start
```

The exact returned:

```text
xdalaUrl
```

is authoritative.

Always present the exact returned URL to the user.

---

# Canonical Session Start fields

The canonical Session Start format is:

```text
type = "xdala_session_start"
version = "xgr-session-start@1"
```

Core fields:

```text
sessions[].orchestration
sessions[].ostcId
sessions[].stepId
sessions[].payload
sessions[].maxTotalGas
```

Optional fields may include:

```text
sessions[].ostcHash
sessions[].expiry
sessions[].starterAddress
```

`entryStepId` is not a Workbench Session Start field.

Use:

```text
sessions[].stepId
```

for the deployed runtime step.

---

# Required runtime inspection before Session Start

Before creating a runtime Session Start handoff, the agent should:

1. identify the deployed XRC-729 orchestration,
2. resolve the relevant OSTC ID,
3. inspect owner and executor authority,
4. identify the intended start step,
5. inspect the linked deployed XRC-137 rule,
6. derive required payload fields,
7. derive optional payload fields,
8. identify explicit defaults,
9. optionally inspect historical start-payload evidence,
10. present unresolved required business values to the user,
11. validate the canonical Session Start request,
12. create the handoff.

Relevant tools include:

```text
get_xrc729_authority
find_startable_xdala_workflows
list_xrc729_contracts_by_executor
get_xrc729_ostc_state
read_xrc729_ostc_json
read_xrc137_rule_json
resolve_xrc729_process_graph
get_xdala_start_payload_history
validate_xgr_session_start_handoff
```

Do not invent business payload values.

Historical values may be used as context only.

They must not silently replace missing required input.

---

# Historical start-payload evidence

The optional read-only tool:

```text
get_xdala_start_payload_history
```

may be used during Session Start preparation after the deployed:

```text
xrc729Address
ostcId
stepId
```

have been identified.

It returns indexed historical scalar values observed for that specific entry step.

This can help with:

- UI value suggestions,
- repetitive operational workflows,
- recognizing previously used values,
- providing historical context to an agent or operator.

It does not:

- create a handoff,
- validate a Session Start,
- define current defaults,
- define required fields,
- provide authority,
- authorize reuse of a historical value.

The current deployed XRC-137 rule and its current payload schema remain authoritative.

---

# Authority versus session ownership

XRC-729 ownership and executor information describe **start authority**.

They do not establish the owner of a session that has not yet been created.

Before Session Start completion:

- `authority.owner` is the XRC-729 contract owner,
- `authority.executors` are authorized starters,
- `starterAddress` is only an intended starter when explicitly supplied.

After successful Session Start, actual session identity comes from the execution result, including fields such as:

```text
result.results[].owner
result.results[].sessionId
result.results[].pid
```

Do not infer final session ownership from XRC-729 authority alone.

---

# Result and evidence model

## Bundle deployment

A successful bundle-deploy result may include:

- deployed contract addresses,
- transaction hashes,
- normalized deployed artifacts,
- per-item deployment results,
- audit events.

After deployment, inspect the deployed runtime rather than assuming the original bundle remains the sole authority.

---

## Session Start

A terminal Session Start result may include:

- success or failure per requested session,
- actual owner,
- session ID,
- process ID,
- starter address,
- original canonical request,
- transaction or execution evidence,
- terminal status,
- audit events.

After success, use session and receipt tools for on-chain evidence.

Relevant evidence tools include:

```text
get_session_transactions
get_session_status_live
get_session_receipt_logs
get_xdala_session_detail
```

---

# Expiry and cancellation

Handoffs have configurable TTL values.

Possible handoff states may include:

- pending,
- completed,
- deployed,
- partial,
- failed,
- cancelled,
- expired.

Cancellation affects only pending offchain handoff metadata.

It cannot reverse:

- a transaction already signed,
- a transaction already submitted,
- an already executed on-chain action.

Purchase-order expiry and starter-gas state are separate from handoff expiry.

Read-only queries have no handoff lifecycle.

---

# Not a handoff: relation graphs and value flow

The following tools are read-only Explorer-backed evidence tools:

```text
get_address_relation_graph
expand_address_relation_graph
trace_xgr_transaction
trace_xgr_value_flow
get_relation_edge_transactions
```

They do not:

- create an operation record,
- create a Workbench handoff,
- return an `xdalaUrl`,
- request a signature,
- sign a transaction,
- mutate chain state.

A relation between addresses proves only that indexed transactions occurred.

It does not prove:

- common ownership,
- identity,
- common control,
- affiliation.

Native-XGR value-flow results are provenance models.

They do not establish per-coin identity.

---

# Not a handoff: mainnet XGR purchase

The purchase tools are:

```text
get_xgr_purchase_options
quote_xgr_purchase
create_xgr_purchase_order
create_xgr_purchase_order_by_budget
```

They do not create Workbench handoff URLs.

The purchase flow is:

```text
live purchase discovery
    ↓
user-supplied identity and wallet data
    ↓
explicit terms acceptance
    ↓
live backend order and reservation
    ↓
exact external payment instruction
    ↓
external stablecoin payment
```

Purchase tools do not:

- create a generic operation handoff,
- create a Workbench handoff,
- return an `xdalaUrl`,
- sign stablecoin payments,
- hold user payment keys.

An approved order returns:

```text
payment_approved = true
next_action = external_crypto_payment
```

Payment must use the returned:

```text
payment_instruction
```

A blocked or uncertain order returns:

```text
next_action = do_not_pay
```

Do not automatically retry an uncertain order because the backend may already have created a live reservation.

---

# Not a handoff: starter gas

The starter-gas tools are:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

They do not create Workbench handoff URLs.

The starter-gas flow is:

```text
read active grant policy
    ↓
supply eligible recipient address
    ↓
persistent IP and address policy checks
    ↓
live chain and balance checks
    ↓
fixed 1 XGR transfer from service wallet
    ↓
on-chain confirmation
```

The service:

- uses a dedicated server-controlled wallet,
- sends exactly `1 XGR`,
- never requests the recipient private key,
- never signs from the recipient address,
- returns the transaction hash,
- records its lifecycle in SQLite,
- does not create a Workbench URL.

A successful result returns:

```text
grant_created = true
grant_status = confirmed
repeat_allowed = false
```

An unresolved broadcast returns:

```text
grant_status = broadcast
retry_allowed = false
```

Do not route starter gas through a generic operation handoff.

---

# Public HTTP routes

## Generic operations

| Route | Purpose |
|---|---|
| `GET /operations/:id` | Human-facing operation page |
| `GET /api/operations/:id` | Read protected operation state |
| `POST /api/operations/:id/status` | Record operation progress or result |

## Bundle deployment

| Route | Purpose |
|---|---|
| `GET /api/bundle-deploy/:handle` | Fetch bundle-deploy handoff |
| `POST /api/bundle-deploy/:handle/status` | Record deployment status |
| `POST /api/bundle-deploy/:handle/result` | Record terminal deployment result |

## Session Start

| Route | Purpose |
|---|---|
| `GET /api/session-start/:handle` | Fetch Session Start handoff |
| `POST /api/session-start/:handle/result` | Record terminal Session Start result |

## Gateway

| Route | Purpose |
|---|---|
| `GET /health` | Health and signing-scope metadata |
| `POST /mcp` | Stateless MCP endpoint |

Purchase, starter-gas, relation-graph, value-flow and payload-history tools operate through:

```text
POST /mcp
```

They do not require separate MCP Gateway public routes.

---

# Security requirements

Never place any of the following in a handoff request:

- private key,
- mnemonic,
- seed phrase,
- wallet password,
- raw wallet secret,
- signing secret,
- custody credential.

No handoff tool requires the private key of:

- the deployment signer,
- the XDaLa Session Start signer,
- an executor,
- a contract owner.

Starter gas accepts only a public recipient address and optional descriptive purpose.

Purchase tools accept public wallet addresses and purchase metadata but never the user's payment private key.

Read-only relation and history tools use public identifiers and read filters only.

---

# Security summary

| Operation | Handoff | User signs locally | Gateway service signing |
|---|---:|---:|---:|
| Generic operation | Yes | Yes | No |
| Bundle deployment | Yes | Yes | No |
| Session Start | Yes | Yes | No |
| Relation graph / value flow | No | No | No |
| Start-payload history | No | No | No |
| XGR purchase order | No | External payment separately authorized | No |
| Starter-gas grant | No | No | Dedicated starter-gas wallet only |

The core rule is:

```text
Agent prepares.
User reviews.
User signs user-controlled actions.
```

The only server-signing exception is the explicitly configured dedicated starter-gas service wallet.
