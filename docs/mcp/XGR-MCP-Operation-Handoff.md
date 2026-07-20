# XGR MCP Gateway — Operation Handoff

**Document ID:** XGR-MCP-OPERATION-HANDOFF  
**Last updated:** 2026-07-20  
**Audience:** Developers, integrators, agent builders, auditors  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/operations`

The XGR MCP Gateway prepares human-reviewed actions without becoming a wallet, signer or custody service.

A handoff connects:

```text
agent intent
    ↓
validated offchain request
    ↓
temporary bearer handle and browser URL
    ↓
human review
    ↓
local wallet signing
    ↓
XGRChain result
```

---

## Core trust boundary

The gateway may:

- validate an intended operation,
- derive canonical request structures,
- inspect deployed XRC runtime data,
- resolve required payload fields,
- verify owner or executor start authority when a signer address is supplied,
- store temporary offchain handoff metadata,
- return a browser or Workbench URL,
- receive validated result callbacks,
- expose status and audit evidence.

The gateway does not:

- receive or store private keys,
- receive seed phrases or mnemonics,
- derive wallet secrets,
- sign transactions,
- silently start sessions,
- silently deploy contracts,
- bypass local wallet approval.

The browser or xDaLa Workbench performs wallet interaction. The user remains the authorizing party.

## Handoff lifecycle

1. The agent gathers the required chain, workflow and payload information.
2. The agent validates the intended artifact or request.
3. The agent calls the correct `create_*_handoff` tool.
4. The gateway stores a temporary protected record under an unguessable handle.
5. The gateway returns a browser URL or `xdalaUrl`.
6. The agent shows the exact returned URL to the user.
7. The user opens the page and reviews the request.
8. The user connects their own wallet or signer.
9. The browser or Workbench submits locally authorized transactions.
10. The corresponding result endpoint records the normalized outcome.
11. Read tools expose the status, artifact, session identifiers and audit events.

A handoff URL acts as a temporary bearer URL. It must not be published.

## Handoff families

### 1. Generic operation handoff

Use:

```text
create_operation_handoff
```

for general browser-wallet transaction sequences that are not XDaLa bundle deployments or session starts.

The result contains an operation URL under:

```text
/operations/:id
```

Tracking tools:

```text
get_operation_status
cancel_operation_handoff
list_recent_operations
```

Do not use the generic operation handoff to start an XDaLa session.

### 2. XDaLa bundle-deploy handoff

Use:

```text
create_xdala_bundle_deploy_handoff
```

to store a validated:

```text
xgr-multi-bundle@1
```

and obtain an xDaLa Workbench import URL.

The gateway stores:

- network and chain ID,
- validation result,
- bundle JSON,
- summary metadata,
- creation and expiry timestamps,
- status events,
- normalized deployment result,
- deployed artifact when returned by Workbench.

Tracking tools:

```text
get_xdala_bundle_deploy_handoff
get_xdala_bundle_deploy_result
cancel_xdala_bundle_deploy_handoff
```

The diagram tool can render the stored process before deployment:

```text
get_xdala_process_mermaid
source = "bundle_handoff"
handle = "bd_..."
```

### 3. XDaLa session-start handoff

Use:

```text
create_xdala_session_start_handoff
```

for every request to:

- start a session,
- run a deployed workflow,
- launch a process,
- execute an XDaLa workflow,
- queue multiple session starts,
- start from a bundle-deploy result.

The gateway returns the environment-specific `xdalaUrl` generated from its configuration.

Typical bases are:

```text
Mainnet: https://xdala.xgr.network/session-start
Testnet: https://xdala.testnet.xgr.network/session-start
```

The returned URL, not a hard-coded example, is authoritative.

Always show the exact `xdalaUrl` returned by the tool. Do not replace it with a generic `/operations/...` URL.

## Canonical Session Start fields

A canonical request uses:

```text
type = "xdala_session_start"
version = "xgr-session-start@1"
sessions[].orchestration
sessions[].ostcId
sessions[].stepId
sessions[].payload
sessions[].maxTotalGas
```

Optional per-session fields may include:

```text
sessions[].ostcHash
sessions[].expiry
sessions[].starterAddress
```

`entryStepId` is not the Workbench Session Start field. Use:

```text
sessions[].stepId
```

## Required workflow inspection

Before creating a runtime session-start handoff, the agent should:

1. identify the XRC-729 orchestration,
2. resolve the relevant OSTC ID,
3. inspect owner and executor authority,
4. determine the likely entry step,
5. resolve the entry step's XRC-137 rule,
6. derive required and optional payload fields,
7. distinguish fields with defaults from required fields,
8. present unresolved required fields to the user,
9. validate the final request,
10. create the handoff.

Relevant tools include:

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

Demo values may be used only after the user explicitly requests or accepts them.

## Authority versus session ownership

XRC-729 methods such as:

```text
owner()
getOwner()
getExecutorList()
```

describe who may start the workflow.

They do not determine the owner of a session that has not yet been started.

Before completion:

- `authority.owner` means XRC-729 contract owner.
- `authority.executors` means permitted start executors.
- `starterAddress` means intended starter when explicitly supplied.

After Workbench returns a terminal result, actual session identity should be taken from:

```text
result.results[].owner
result.results[].sessionId
```

The handoff exposes a `sessionOwnership` summary to keep these roles separate.

## Result and evidence model

### Bundle deployment

A successful deployment result may include:

- deployed contract addresses,
- transaction hashes,
- normalized deployed artifact,
- per-item deployment results,
- audit events.

### Session start

A terminal session-start result may include:

- success or failure per requested session,
- actual owner,
- session ID,
- starter,
- original canonical request,
- terminal status,
- audit events.

After a successful session start, use session and receipt tools for on-chain evidence.

## Expiry and cancellation

Handoffs have configurable TTL values.

Possible terminal states include:

- completed or deployed,
- partial,
- failed,
- cancelled,
- expired.

Cancellation affects only pending offchain handoff metadata. It does not reverse or cancel transactions already signed or submitted by the user.

## Public HTTP routes

### Generic operations

| Route | Purpose |
|---|---|
| `GET /operations/:id` | Human-facing generic operation page |
| `GET /api/operations/:id` | Read protected operation state |
| `POST /api/operations/:id/status` | Record browser-wallet progress and results |

### Bundle deployment

| Route | Purpose |
|---|---|
| `GET /api/bundle-deploy/:handle` | Fetch a protected bundle-deploy handoff |
| `POST /api/bundle-deploy/:handle/status` | Record normalized deployment status |
| `POST /api/bundle-deploy/:handle/result` | Record the terminal deployment result |

### Session start

| Route | Purpose |
|---|---|
| `GET /api/session-start/:handle` | Fetch a protected Session Start handoff |
| `POST /api/session-start/:handle/result` | Record the terminal Session Start result |

### Gateway

| Route | Purpose |
|---|---|
| `GET /health` | Liveness and server mode |
| `POST /mcp` | Stateless MCP JSON-RPC endpoint |

Public handoff endpoints enforce configurable:

- request-size limits,
- content-type checks,
- handle validation,
- origin restrictions,
- per-IP rate limits,
- per-handle rate limits,
- sensitive-field rejection,
- audit logging.

## Security requirements

Never place any of the following in a handoff request:

- private key,
- mnemonic,
- seed or seed phrase,
- raw wallet secret,
- signature,
- permit secret,
- bearer credentials unrelated to the generated handle.

Public list tools do not return browser execution secrets.
