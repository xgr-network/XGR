# XGR MCP Gateway — Operation Handoff

**Document ID:** XGR-MCP-OPERATION-HANDOFF  
**Last updated:** 2026-07-26  
**Audience:** Developers, integrators, agent builders, auditors  
**Implementation status:** Live  
**Source of truth:** [`xgr-network/xgr-mcp/src/operations`](https://github.com/xgr-network/xgr-mcp/tree/main/src/operations)

The XGR MCP Gateway prepares human-reviewed on-chain actions without receiving or controlling the user's private key.

This document applies specifically to handoff tools.

The following operations are not handoffs:

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

## Core trust boundary

For handoff operations, the gateway may:

- validate an intended operation,
- derive canonical request structures,
- inspect deployed XRC runtime data,
- resolve payload fields,
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

The browser or xDaLa Workbench performs wallet interaction.

## Gateway-wide signing clarification

The optional starter-gas service is a separate, narrowly scoped operation.

It may sign only fixed native XGR transfers from a dedicated service wallet.

This does not change the handoff trust boundary.

The starter-gas service cannot sign:

- a deployment transaction,
- an XDaLa session-start transaction,
- a user contract call,
- a purchase payment,
- any transaction from the recipient address.

## Handoff lifecycle

1. The agent gathers the required chain, workflow and payload information.
2. The agent validates the intended artifact or request.
3. The agent calls the correct `create_*_handoff` tool.
4. The gateway stores a temporary protected record.
5. The gateway returns a browser URL or `xdalaUrl`.
6. The agent shows the exact returned URL.
7. The user opens the page and reviews the request.
8. The user connects their own wallet or signer.
9. The browser or Workbench submits locally authorized transactions.
10. The result endpoint records the normalized outcome.
11. Read tools expose status, artifacts and evidence.

A handoff URL is a temporary bearer URL and must not be published.

## Handoff families

### Generic operation handoff

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

### XDaLa bundle-deploy handoff

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

- network and chain ID,
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

### XDaLa session-start handoff

Use:

```text
create_xdala_session_start_handoff
```

for every request to:

- start a session,
- run a deployed workflow,
- launch a process,
- execute an XDaLa workflow,
- queue multiple starts,
- start from a bundle-deploy result.

Typical Workbench bases:

```text
Mainnet: https://xdala.xgr.network/session-start
Testnet: https://xdala.testnet.xgr.network/session-start
```

The exact returned `xdalaUrl` is authoritative.

Always show it to the user.

## Not a handoff: mainnet XGR purchase

These tools do not create handoff URLs:

```text
get_xgr_purchase_options
quote_xgr_purchase
create_xgr_purchase_order
create_xgr_purchase_order_by_budget
```

The purchase workflow is:

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

- create a generic operation record,
- create a Workbench handoff,
- return an `xdalaUrl`,
- sign the stablecoin payment,
- hold payment keys.

An approved result returns:

```text
payment_approved = true
next_action = external_crypto_payment
```

A blocked or uncertain result returns:

```text
next_action = do_not_pay
```

## Not a handoff: starter-gas grant

These tools do not create handoff URLs:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

The starter-gas workflow is:

```text
read live grant policy
    ↓
supply an eligible recipient address
    ↓
persistent IP and address policy checks
    ↓
live balance and chain checks
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
- records the lifecycle in SQLite,
- does not create a Workbench URL.

A successful result returns:

```text
grant_created = true
grant_status = confirmed
repeat_allowed = false
```

A broadcast but unresolved result returns:

```text
grant_status = broadcast
retry_allowed = false
```

Do not route starter gas through a generic operation handoff.

## Canonical Session Start fields

```text
type = "xdala_session_start"
version = "xgr-session-start@1"

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

## Required runtime inspection

Before creating a runtime Session Start handoff, the agent should:

1. identify the XRC-729 orchestration,
2. resolve the relevant OSTC ID,
3. inspect owner and executor authority,
4. determine the likely start step,
5. resolve the step's XRC-137 rule,
6. derive required and optional payload fields,
7. distinguish defaults from required fields,
8. present unresolved required fields,
9. validate the final request,
10. create the handoff.

Relevant tools:

```text
get_xrc729_authority
find_startable_xdala_workflows
list_xrc729_contracts_by_executor
get_xrc729_ostc_state
read_xrc729_ostc_json
read_xrc137_rule_json
resolve_xrc729_process_graph
validate_xgr_session_start_handoff
```

Do not invent business payload values.

## Authority versus session ownership

The XRC-729 methods:

```text
owner()
getOwner()
getExecutorList()
```

describe who may start the workflow.

They do not establish the actual owner of a session that has not yet started.

Before completion:

- `authority.owner` is the XRC-729 contract owner,
- `authority.executors` are authorized starters,
- `starterAddress` is only an intended starter when explicitly supplied.

After completion, actual session identity comes from:

```text
result.results[].owner
result.results[].sessionId
result.results[].pid
```

## Result and evidence model

### Bundle deployment

A successful deployment may include:

- contract addresses,
- transaction hashes,
- normalized deployed artifact,
- per-item results,
- audit events.

### Session Start

A terminal result may include:

- success or failure per requested session,
- actual owner,
- session ID,
- process ID,
- starter,
- original canonical request,
- terminal status,
- audit events.

After success, use session and receipt tools for on-chain evidence.

## Expiry and cancellation

Handoffs have configurable TTL values.

Possible states include:

- pending,
- completed,
- deployed,
- partial,
- failed,
- cancelled,
- expired.

Cancellation affects only pending offchain metadata.

It cannot reverse a transaction already signed or submitted.

Purchase-order expiry and starter-gas state are separate from handoff expiry.

## Public HTTP routes

### Generic operations

| Route | Purpose |
|---|---|
| `GET /operations/:id` | Human-facing operation page |
| `GET /api/operations/:id` | Read protected state |
| `POST /api/operations/:id/status` | Record progress and results |

### Bundle deployment

| Route | Purpose |
|---|---|
| `GET /api/bundle-deploy/:handle` | Fetch handoff |
| `POST /api/bundle-deploy/:handle/status` | Record status |
| `POST /api/bundle-deploy/:handle/result` | Record terminal result |

### Session Start

| Route | Purpose |
|---|---|
| `GET /api/session-start/:handle` | Fetch handoff |
| `POST /api/session-start/:handle/result` | Record terminal result |

### Gateway

| Route | Purpose |
|---|---|
| `GET /health` | Health and signing-scope metadata |
| `POST /mcp` | Stateless MCP endpoint |

Purchase and starter-gas tools operate through `/mcp`.

They add no separate public route.

## Security requirements

Never place any of the following in a handoff request:

- private key,
- mnemonic,
- seed phrase,
- wallet password,
- raw wallet secret,
- signature secret,
- custody credential.

Starter gas accepts only a public recipient address and optional purpose text.

Purchase tools accept only public wallet addresses and purchase metadata.

No tool accepts the private key of:

- the XGR recipient,
- the stablecoin sender,
- the deployment signer,
- the XDaLa session starter.
