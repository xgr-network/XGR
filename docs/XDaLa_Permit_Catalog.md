# XDaLa Permit Catalog

## 1. What is a “Permit”?

A **permit** is an **EIP-712 typed-data signature** that authorizes specific XDaLa actions without requiring an on-chain authorization transaction.

Key properties:
- **Deterministic**: field order and type definitions are fixed.
- **Replay protected**: at minimum by `chainId` and expiry. Session control and session execution additionally bind to session identity.
- **Auditable**: permit signer must match protocol-defined authority rules (e.g. orchestration owner).

Permits are submitted as JSON objects containing:
- `domain`
- `types`
- `primaryType`
- `message`
- `signature`

Clients typically generate them via `eth_signTypedData_v4`.

---

## 2. Permit Types

### 2.1 SessionPermit (for `xgr_validateDataTransfer`)

**Primary use**: authorizes starting/continuing a specific session under a specific orchestration.

#### Domain
- `name`: `"XDaLa SessionPermit"`
- `version`: `"1"`
- `chainId`: `uint256`

#### Message fields
- `from` (`address`): signer and authority holder.
- `ostcId` (`string`): orchestration identifier (semantic id).
- `ostcHash` (`bytes32`): content hash of orchestration structure.
- `sessionId` (`uint256`): root session id the signer claims to start/operate.
- `maxTotalGas` (`uint256`): hard cap for total gas budget across the session.
- `expiry` (`uint256`): unix seconds.

#### Signature checks (high level)
- typed data must match domain name/version.
- `chainId` must equal the network chain id.
- recovered signer must equal `message.from`.
- the engine enforces that signer equals the on-chain **XRC-729 owner** for the orchestration contract.

---

### 2.2 xdalaPermit (for grant management & listing)

**Primary use**: authenticates the caller for endpoints that operate on or reveal grant data.

#### Domain
- `name`: non-empty string.
- `version`: non-empty string.
- `chainId`: `uint256` (must match chain).

#### Message fields
- `from` (`address`): signer/caller identity.
- `expiry` (`uint256`): unix seconds; if expired → invalid.

#### PrimaryType
- `"xdalaPermit"`

This permit is intentionally minimal: it provides caller identity and expiry without binding to a specific contract, because the action scope is defined by the endpoint request parameters (RID/scope filters, etc.).

---

### 2.3 ControlPermit (for session control: pause/resume/kill/wake)

**Primary use**: authorizes operations that change session scheduling state.

#### Domain
- `name`: non-empty string.
- `version`: non-empty string.
- `chainId`: must match chain.
- `verifyingContract`: must match the engine’s expected control-domain verifying contract (typically the engine precompile address).

#### Message fields
- `from` (`address`): signer identity.
- `sessionId` (`uint256`): root session id.
- `action` (`string`): one of:
  - `"pause"`
  - `"resume"`
  - `"kill"`
  - `"wake"`
- `expiry` (`uint256`): unix seconds.

#### PrimaryType
- `"ControlPermit"`

---

## 3. Signature Encoding Rules

- Signature is hex: `"0x" + 130 hex chars` (65 bytes).
- `v` may be produced as `{27,28}` or `{0,1}` depending on wallet; engines typically normalize internally.

---

## 4. Minimal Example: xdalaPermit

```json
{
  "domain": {
    "name": "XDaLa Permit",
    "version": "1",
    "chainId": 12345
  },
  "primaryType": "xdalaPermit",
  "types": {
    "EIP712Domain": [
      { "name": "name", "type": "string" },
      { "name": "version", "type": "string" },
      { "name": "chainId", "type": "uint256" }
    ],
    "xdalaPermit": [
      { "name": "from", "type": "address" },
      { "name": "expiry", "type": "uint256" }
    ]
  },
  "message": {
    "from": "0xabc...",
    "expiry": 1700000000
  },
  "signature": "0x..."
}
```
