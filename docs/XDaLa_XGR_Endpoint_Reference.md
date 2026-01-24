# XDaLa JSON-RPC Extension: XGR Endpoint Reference

## 1. Scope and Audience

This document specifies the **public JSON-RPC endpoints** exposed by the **XDaLa Engine** under the **XGR namespace**. It is intended for client developers building wallets, orchestrators, dashboards, and integrations that need to:

- submit validation calls for XDaLa sessions
- estimate validation/branch gas
- manage and query grants
- control (pause/resume/kill/wake) sessions

This is a **public interface specification**. It describes semantics and request/response formats independent of internal implementation details.

## 2. Conventions

### 2.1 JSON-RPC Envelope

All methods are called via standard JSON-RPC 2.0:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "xgr_<methodName>",
  "params": [ <object> ]
}
```

Unless noted otherwise, parameters are passed as a single JSON object in `params[0]`.

### 2.2 Address and Hash Formats

- `address`: `"0x"` + 40 hex chars (20 bytes), lowercase recommended
- `bytes32`: `"0x"` + 64 hex chars (32 bytes)
- `txHash`: `"0x"` + 64 hex chars
- `uint256 as string`: decimal string (e.g., `"123"`) unless explicitly noted as hex

### 2.3 Permit Overview (Authorization)

Several endpoints require an **EIP-712 permit** signed by an EOA. Permits are described in the companion document **“XDaLa Permit Catalog”**. Each endpoint section below references which permit is required and what it authorizes.

---

## 3. Endpoint Index

> Note: Method names below are shown in the recommended external form `xgr_<lowerCamel>`. If your JSON-RPC dispatcher exposes different names, adjust the strings accordingly.

| Method | Purpose | Permit Required |
|---|---|---|
| `xgr_getPublicSale` | Returns configured public sale address (optional) | No |
| `xgr_getCoreAddrs` | Returns core addresses needed by clients | No |
| `xgr_getNextProcessId` | Returns next expected root session id for a sender | No |
| `xgr_validateDataTransfer` | Submits a step validation request for a session | **SessionPermit** |
| `xgr_estimateRuleGas` | Estimates validation gas + branch totals for an XRC-137 rule JSON | No |
| `xgr_getEncryptedLogInfo` | Extracts encryption metadata from a transaction log | No |
| `xgr_getXRC137Meta` | Returns encrypted rule document blob + encrypted DEK for a given owner | No (encrypted-to-owner data) |
| `xgr_encryptXRC137` | Produces encrypted XRC-137 blob suitable for on-chain storage | Optional (depends on request mode) |
| `xgr_control` | Session control (**kill**; pause/resume not implemented) | **ControlPermit** / **ControlPermitV2** |
| `xgr_wakeUpProcess` | Wakes WAITING processes (PID-mode or Step-mode) with optional payload merge (supports AllowList) | **ControlPermit** / **ControlPermitV2** |
| `xgr_listSessions` | Lists sessions (DB-backed), including allowlisted WAITING steps (“ToDo list” mode) | **xdalaPermit** or **ControlPermit(V2)** |
| `xgr_manageGrants` | Creates/updates grants for a RID/scope | **xdalaPermit (owner-auth)** |
| `xgr_listGrants` | Lists grants visible to the caller | **xdalaPermit (caller-auth)** |
| `xgr_getGrantFeePerYear` | Returns annual grant fee in Wei | No |

---

## 4. `xgr_getPublicSale`

### Purpose
Returns a configured “public sale” address if the chain is running with a sale component enabled. Otherwise returns an empty string.

### Request
No parameters.

### Response
```json
{
  "publicSale": "0x...."
}
```

- `publicSale`: address string or `""`

---

## 5. `xgr_getCoreAddrs`

### Purpose
Returns core addresses that clients need in order to compose transactions and verify domain contracts.

### Request
No parameters.

### Response
```json
{
  "grants": "0x...",
  "engineEOA": "0x...",
  "precompile": "0x...",
  "chainId": "12345"
}
```

Field definitions:
- `grants`: address of the on-chain Grants component
- `engineEOA`: EOA used by the engine where signatures/transactions are required
- `precompile`: address of the engine execution precompile
- `chainId`: chain id as decimal string

---

## 6. `xgr_getNextProcessId`

### Purpose
Returns the next expected **root session id** (root PID) for a given sender address.  
Clients typically use this to construct a **nonce-guarded SessionPermit** (see Permit Catalog).

### Request
```json
{
  "from": "0x..."
}
```

### Response
```json
{
  "nextProcessId": "1"
}
```

- `nextProcessId`: decimal string

---

## 7. `xgr_validateDataTransfer`

### Purpose
Submits a step validation request to the XDaLa Engine. This is the primary entry point for executing an orchestration session.

### Authorization
Requires a valid **SessionPermit**. The permit signer must match the **XRC-729 orchestration owner** (auditability and authority).

### Request
```json
{
  "stepId": "E1",
  "payload": {
    "A_out": 30,
    "B_in": 10
  },
  "permit": { "..." : "SessionPermit object" },
  "orchestration": "0x<address of XRC-729 contract>"
}
```

Field definitions:
- `stepId` (required): identifier of the step to run
- `payload` (optional): user-provided input payload for this step
- `permit` (required): SessionPermit (EIP-712 typed data + signature) binding session authority
- `orchestration` (required): XRC-729 contract address which **fully defines orchestration structure**

### Response
Returns a `ValidateResult`:

```json
{
  "processId": "123:1",
  "finalResult": false,
  "executedSteps": [ "... step receipts ..." ],
  "ruleAction": "",
  "payload": { "... sanitized payload ..." },
  "outputPayload": { "... outcome payload ..." }
}
```

Key semantics:
- `processId`: process identifier (`rootPid:iterationStep`)
- `finalResult`: whether the step evaluated valid/invalid at rule level
- `payload`: sanitized payload (declared keys, defaults already applied)
- `outputPayload`: evaluated outcome payload without overwriting inputs

---

## 8. `xgr_estimateRuleGas`

### Purpose
Estimates validation gas and branch totals for an XRC-137 **rule document JSON**. This supports client-side quoting before submitting sessions.

### Request
```json
{
  "json": "{ ... XRC-137 rule document ... }",
  "encrypted": true,
  "validSpawns": 1,
  "invalidSpawns": 2
}
```

Field definitions:
- `json` (required): complete rule document JSON string
- `encrypted` (optional): default value for branch encryption flags if omitted in JSON
- `validSpawns` / `invalidSpawns` (optional): spawn-count hints used for wait-time related costing

### Response
```json
{
  "validationGas": 1234,
  "onValid": {
    "validationGas": 1500,
    "evmTxCalldata": 21000,
    "logGas": 0,
    "innerCalls": { "execution": 50000 },
    "total": 72500
  },
  "onInvalid": { "...": "..." },
  "totalValid": 72500,
  "totalInvalid": 81234,
  "totalWorstCase": 81234
}
```

---

## 9. `xgr_getEncryptedLogInfo`

### Purpose
Extracts encryption-related metadata from a transaction hash. This supports reproducing permit-domain parameters precisely for UI signing workflows.

### Request
```json
{
  "txHash": "0x..."
}
```

### Response
```json
{
  "found": true,
  "ruleContract": "0x...",
  "suite": "XGR1.P256.HKDF",
  "rid": "0x...",
  "peVerifying": "0x...",
  "peScope": 1,
  "peRef": "0x...",
  "peExp": 1700000000,
  "peNonce": 7,
  "peDomainName": "XDaLa SessionPermit",
  "peDomainVer": "1",
  "hkdfSeedHash": "0x..."
}
```

---

## 10. `xgr_getXRC137Meta`

### Purpose
Returns the encrypted rule document blob and an encrypted DEK for a given owner and XRC-137 contract.

### Request
```json
{
  "address": "0x<ruleContract>",
  "owner": "0x<ownerEOA>",
  "scope": 1
}
```

### Response
```json
{
  "rid": "0x...",
  "blob": "XGR1....base64....",
  "encDEK": "0x...",
  "exp": 1700000000
}
```

---

## 11. `xgr_control`

### Purpose
Administrative control over an entire session tree. **Current implementation supports only `kill`** (no pause/resume yet).  
The `sessionId` signed in the permit is always interpreted as the **root session id** (root PID).

### Authorization
Requires a valid **ControlPermit** or **ControlPermitV2** with:
- `message.action = "kill"`
- `message.sessionId = <rootPid>`

### Request
```json
{
  "action": "kill",
  "permit": { "..." : "ControlPermit / ControlPermitV2 object" }
}
```

Notes:
- `action` is optional in the request body; if provided, it must match the signed `message.action`.

### Response
```json
{
  "ok": true,
  "owner": "0x...",
  "processId": 123,
  "action": "kill",
  "status": "killed",
  "affected": 7
}
```

--- 

## 12. `xgr_wakeUpProcess`

### Purpose
Wakes WAITING processes (sets `NextWakeAt = now`) using one of two mutually exclusive modes:

- **PID-mode**: wake exactly one waiting process by `processId` (e.g. `"123:2"`).
- **Step-mode**: wake *all* waiting children under the signed root session that are currently waiting on the signed `stepId`.

Optionally merges a provided `payload` into each target’s stored resume payload (`ResumePlain`).

### Authorization
Requires **ControlPermit** / **ControlPermitV2** with `message.action = "wake"`.

Permit message types:
- **ControlPermit**: `{ from, sessionId, action, stepId, expiry }` (runner is implicitly `from`)
- **ControlPermitV2**: `{ from, runner, sessionId, action, stepId, expiry }` (required for AllowList-delegation)

### Request
```json
{
  "processId": "123:2",
  "payload": { "X": 1 },
  "permit": { "..." : "ControlPermit / ControlPermitV2 object" }
}
```

Mode rules:
- **PID-mode**: `processId` is set, and `permit.message.stepId` **must be empty**.
- **Step-mode**: `processId` is omitted, and `permit.message.stepId` **must be set**.

Payload merge rules:
- Shallow merge into `ResumePlain` (request keys overwrite stored keys).
- Keys starting with `_` are ignored (engine-reserved / meta keys).

### AllowList (delegated wake-ups)
By default, the permit signer must be the session owner/runner (`from == runner`).  
In **Step-mode only**, `ControlPermitV2` allows **delegation**: `from` may wake on behalf of `runner` *only if* the WAITING process’ `ResumePlain` contains an AllowList that includes `from`.

AllowList location and format (stored under reserved payload key `__wakeUp`):

```json
{
  "__wakeUp": {
    "steps": {
      "E1": {
        "rpc": ["0xallowedCaller1...", "0xallowedCaller2..."],
        "internal": ["*"]
      }
    },
    "default": {
      "rpc": ["0xallowedCallerDefault..."]
    }
  }
}
```

Semantics:
- Per-step entry (`steps[stepId]`) overrides `default`.
- Missing `__wakeUp`, missing entry, or missing scope list => **deny**.
- Scope `"rpc"` is used for `xgr_wakeUpProcess` delegation.
- Scope `"internal"` is used for engine-internal wake-ups triggered via XRC-137 `wakeUp` specs.
  - `"internal"` additionally supports wildcards (`"*"` or the zero address) to allow any internal caller.

### Response
```json
{
  "ok": true,
  "owner": "0x...",
  "sessionId": 123,
  "rootPid": "123",
  "mode": "pid",
  "woken": 1
}
```

--- 

## 13. `xgr_listSessions`

### Purpose
Lists sessions in two modes:

1) **Owner-mode (default)**: DB-backed session listing for an owner (signed via `xdalaPermit`).  
2) **Allow-mode (“ToDo list”)**: lists only **WAITING** steps that a caller is allowed to wake for a given `runner` (signed via `ControlPermitV2`).

### Mode 1: Owner-mode (DB-backed)

#### Authorization
Requires **xdalaPermit** (`primaryType = "xdalaPermit"`) signed by the owner (`message.from`).

#### Request
```json
{
  "view": "raw",
  "parentPid": "optional",
  "rootId": "optional",
  "last": 100,
  "permit": { "..." : "xdalaPermit object" }
}
```

- `rootId` (optional): if set, returns only this root session (including its threads).
- `last` (optional): maximum number of sessions returned (default `100`).
- `parentPid` (optional): client-side filter on the returned set.
- `view`: currently only `"raw"` (or omitted) is supported.

#### Response
```json
{
  "sessions": [
    {
      "owner": "0x...",
      "sessionId": "123",
      "pid": "123:2",
      "parentPid": "123",
      "step": "E1",
      "status": "waiting",
      "updated": 1700000000,
      "iterationStep": 2,
      "paused": false,
      "xrc729": "0x...",
      "ostcId": "0x...",
      "joinGroupId": "",
      "joinFromGroupId": ""
    }
  ]
}
```

### Mode 2: Allow-mode (WAITING-only, allowlisted)

#### Authorization
Requires:
- `runner` (string address), and
- `controlPermit` (**must be ControlPermitV2**) signed with:
  - `message.action = "wake"`
  - `message.runner = <runner>`
  - `message.sessionId = <rootPid>` (scope binding)

Notes:
- If `controlPermit.message.stepId` is set, listing is restricted to that step only (least privilege).
- If the signer is not the runner, only steps allowlisted under `ResumePlain.__wakeUp` (scope `"rpc"`) are returned.

#### Request
```json
{
  "view": "raw",
  "runner": "0x<targetRunner>",
  "rootId": "123",
  "last": 100,
  "controlPermit": { "..." : "ControlPermitV2 object with action=wake" }
}
```

Constraints:
- `rootId` is optional, but if provided it must equal the signed `controlPermit.message.sessionId`.
- In allow-mode, `parentPid` is intentionally not exposed (the result is a “steps I can wake” list).

#### Response
Same shape as owner-mode, but with:
- `status` always `"waiting"`,
- `parentPid` omitted,
- and only allowlisted steps returned.

--- 

## 14. `xgr_manageGrants`

### Purpose
Creates or updates grants for a specific `(RID, scope)`.

### Authorization
Requires a valid **xdalaPermit** whose signer is the **grant owner**.

### Request
```json
{
  "rid": "0x...",
  "scope": 1,
  "owner": "0x...",
  "entries": [
    {
      "grantee": "0x...",
      "rights": 7,
      "expireAt": 1700000000,
      "encDEK": "0x...",
      "isOwner": false
    }
  ],
  "permit": { "..." : "xdalaPermit object" },

  "refAddr": "0x<optional rule contract for scope=1>",
  "sessionId": "123"
}
```

### Response
```json
{
  "upserted": 1
}
```

---

## 15. `xgr_listGrants`

### Purpose
Lists grants visible to the caller.

### Authorization
Requires **xdalaPermit** signed by the caller.

### Request (subset)
```json
{
  "scope": 1,
  "rid": "0x...",
  "refAddr": "0x...",
  "validAt": 1700000000,
  "expireFrom": 1700000000,
  "expireTo": 1800000000,
  "limit": 100,
  "permit": { "..." : "xdalaPermit object" }
}
```

### Response
```json
{
  "items": [
    {
      "id": 1,
      "rid": "0x...",
      "scope": 1,
      "grantee": "0x...",
      "owner": "0x...",
      "rights": 7,
      "encDEK": "0x...",
      "expiresAt": 1700000000,
      "isOwner": false,
      "txHash": "0x...",
      "refAddr": "0x...",
      "sessionId": "123"
    }
  ],
  "nextCursor": 0
}
```

---

## 16. `xgr_getGrantFeePerYear`

### Purpose
Returns the current annual grant fee in Wei.

### Request
No parameters.

### Response
```json
{
  "wei": "0x0de0b6b3a7640000"
}
```
