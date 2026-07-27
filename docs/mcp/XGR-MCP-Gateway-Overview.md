# XGR MCP Gateway — Overview

**Document ID:** XGR-MCP-OVERVIEW  
**Last updated:** 2026-07-26  
**Audience:** Developers, integrators, agent builders, operators, auditors  
**Implementation status:** Public mainnet and testnet gateways live  
**Source of truth:** [`xgr-network/xgr-mcp`](https://github.com/xgr-network/xgr-mcp)

> **One-liner**
>
> The XGR MCP Gateway is the AI-native access layer to XGRChain and XDaLa. It exposes live chain state, indexed evidence, XDaLa workflows, XRC standards, validated execution handoffs, XGR purchase tools and optional native XGR starter gas through the Model Context Protocol.

---

## What it is

The XGR MCP Gateway is a public Model Context Protocol server implemented in TypeScript with `@modelcontextprotocol/sdk`.

It allows MCP-compatible agents and applications to work with:

- XGRChain live JSON-RPC state,
- indexed Explorer transactions and receipts,
- XDaLa sessions, steps, payloads and execution evidence,
- XRC-137 rules and XRC-729 orchestrations,
- workflow authority and executor relationships,
- canonical schemas, examples and authoring rules,
- process diagrams,
- bundle-deploy and session-start handoffs,
- optional mainnet XGR purchase ordering,
- optional native XGR starter-gas grants.

The public implementation is maintained in:

```text
https://github.com/xgr-network/xgr-mcp
```

## Public MCP endpoints

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

## Typical agent requests

The gateway gives an agent enough structured context to handle requests such as:

- What happened in this transaction?
- What did this XDaLa session execute?
- Which workflows may this address start?
- Which payload fields are required to wake this waiting step?
- Which XRC-137 rules already exist for this owner?
- Can this process bundle be deployed?
- Prepare this validated workflow for local deployment.
- Prepare this deployed workflow for local session start.
- Does this wallet have enough native XGR for gas?
- Request starter gas for this eligible low-balance wallet.
- Which payment assets can currently be used to purchase XGR?
- Create a live XGR purchase reservation and return the exact external payment instruction.

## XGR surfaces

| Surface | Primary responsibility |
|---|---|
| **XGRChain** | Consensus, transactions, contracts, native XGR and protocol state |
| **XDaLa** | Validation, orchestration and deterministic process execution |
| **Explorer** | Indexed chain evidence, session evidence and analytics |
| **xDaLa Workbench** | Human review, wallet connection, local signing and execution |
| **XGR purchase API** | Mainnet XGR price, inventory, payment assets and reservations |
| **Starter-gas service** | Fixed native XGR grants from a dedicated service wallet |
| **MCP Gateway** | Semantic discovery, inspection, validation and controlled execution boundaries |

## Operational classes

The gateway exposes five operational classes.

### 1. Read and evidence tools

These tools read live RPC state, Explorer APIs, indexed databases or deployed contracts.

Examples:

- live chain and account state,
- transaction evidence,
- XDaLa session timelines,
- decoded engine receipts,
- XRC contract and event indexes,
- workflow authority,
- payload and failure analytics.

They do not mutate chain state.

### 2. Knowledge, validation and diagram tools

These tools provide:

- canonical XRC references,
- JSON schemas,
- authoring rules,
- examples,
- MultiBundle validation,
- Session Start validation,
- XRC-137 validation,
- payload-flow validation,
- Mermaid process diagrams.

They operate locally in the gateway and do not submit transactions.

### 3. Human-in-the-loop handoff tools

Handoff tools prepare and store validated offchain requests and return an environment-specific browser or Workbench URL.

The user must:

1. open the returned URL,
2. review the prepared request,
3. connect their own wallet or signer,
4. authorize and sign locally.

The gateway never receives or controls the user's private key.

See [Operation Handoff](./XGR-MCP-Operation-Handoff.md).

### 4. Mainnet XGR purchase tools

Optional purchase tools connect to the configured XGR purchase API.

They can:

- read current payment options,
- read live XGR price and availability,
- calculate a non-binding budget quote,
- create one real purchase order for an exact XGR amount,
- create one real purchase order from a maximum USDC or USDT budget,
- return an exact external payment instruction.

Creating an order is not read-only. It creates a live offchain reservation in the purchase backend.

The gateway does not:

- hold payment private keys,
- send stablecoin payments,
- sign on behalf of the purchaser,
- automatically retry uncertain purchase orders.

### 5. Native XGR starter gas

The optional starter-gas service solves the first-transaction problem for an eligible low-balance address.

It exposes:

```text
get_xgr_starter_gas_options
request_xgr_starter_gas
```

The service:

- sends exactly `1 XGR`,
- sends from a dedicated server-controlled service wallet,
- checks the configured network and chain ID,
- checks the recipient's live native XGR balance,
- permits only one confirmed grant per address,
- applies global hourly and daily grant limits,
- applies persistent per-client-IP request limits,
- limits failed attempts per address,
- records grant state in SQLite,
- waits for on-chain confirmation,
- never requests the recipient's private key,
- requires no repayment.

The active policy must be read from:

```text
get_xgr_starter_gas_options
```

Deployment-specific thresholds must not be assumed.

## Starter-gas lifecycle

The persistent lifecycle is:

```text
reserved
   ↓
broadcast
   ↓
confirmed
```

An eligible failed attempt may enter:

```text
failed
```

Retry eligibility is bounded by the configured attempt limit.

A transaction already in `broadcast` state is not blindly repeated. The gateway first checks its receipt.

## Starter-gas trust boundary

The starter-gas service is a narrow exception to the gateway's normal no-signing model.

It may sign only:

```text
fixed native XGR transfers
from the dedicated starter-gas service wallet
```

It cannot sign for:

- the recipient,
- a user wallet,
- a deployment wallet,
- an XDaLa session starter,
- a purchase payment wallet,
- a third-party wallet.

The gateway never accepts user or third-party private keys.

The service wallet must be:

- dedicated,
- low balance,
- operationally isolated,
- separate from treasury and validator keys,
- limited by explicit grant policies.

## Abuse controls

The implementation applies:

- recipient-balance eligibility,
- one confirmed grant per address,
- maximum attempts per address,
- hourly global grant limits,
- daily global grant limits,
- hourly per-IP request limits,
- daily per-IP request limits,
- persistent SQLite accounting,
- atomic reservation transactions,
- a low-balance funding wallet.

The implementation does not currently require:

- proof of address ownership,
- proof of work,
- CAPTCHA,
- identity verification.

These controls limit financial exposure but do not provide strong Sybil resistance.

## Client-IP handling

For HTTP MCP calls, the gateway derives the client IP from the direct socket connection.

Forwarded headers are trusted only when the direct peer is loopback.

Supported trusted headers:

```text
X-Forwarded-For
X-Real-IP
```

A public client cannot make the gateway trust an arbitrary forwarding header when connecting directly.

Reverse proxies should therefore connect to the MCP process through loopback.

## Design principles

1. **Read-first with explicit mutation boundaries**  
   Most tools read or validate data. Mutable effects are limited to handoff storage, purchase reservations and starter-gas grants.

2. **No user custody**  
   The gateway never requests, receives, stores or controls user or third-party private keys.

3. **Narrow service-wallet authority**  
   Starter gas may use only a dedicated service key for fixed native XGR grants.

4. **Semantic over raw**  
   Tools are described around user intent instead of exposing only low-level RPC or HTTP methods.

5. **Evidence over inference**  
   Transaction, receipt, session and XRC tools distinguish live RPC data, Explorer data and indexed evidence.

6. **Canonical schemas before execution**  
   Deploy and Session Start requests must pass the corresponding validators.

7. **Explicit authorization before purchase ordering**  
   Purchase identity, wallet data and terms acceptance must come from the user or an authorized upstream system.

8. **No automatic retry after uncertain mutation**  
   Purchase orders and broadcast starter-gas transactions must not be repeated merely because a client response was interrupted.

9. **Human approval at workflow execution boundaries**  
   The agent may inspect, draft and prepare XDaLa actions. The user remains responsible for local wallet authorization.

## Architecture

```text
 MCP client
 ChatGPT / Claude / IDE / custom agent host
          │
          │ Model Context Protocol
          ▼
 ┌──────────────────────── XGR MCP Gateway ────────────────────────┐
 │                                                                 │
 │  tools/                                                         │
 │    chain · transactions · sessions · receipts · XRC             │
 │    knowledge · validation · diagrams · handoffs                 │
 │    purchase · starter gas                                       │
 │                                                                 │
 │  adapters/                                                      │
 │    XGR JSON-RPC · Explorer API · indexed read databases          │
 │    XGR purchase API                                              │
 │                                                                 │
 │  knowledge/                                                     │
 │    XRC-137 · XRC-729 · schemas · examples · validators           │
 │                                                                 │
 │  operations/                                                    │
 │    protected handoff stores · result callbacks                  │
 │                                                                 │
 │  starter-gas state                                              │
 │    SQLite/WAL · grant lifecycle · client-IP counters             │
 │                                                                 │
 └──────────────┬────────────────┬────────────────┬────────────────┘
                │                │                │
                ▼                ▼                ▼
          XGRChain RPC      XGR Explorer    XGR purchase API
                │
                ├── native XGR grant
                │
                ▼
          xDaLa Workbench
          review + local signing
```

## MCP transport

Hosted gateways use stateless Streamable HTTP through:

```text
POST /mcp
```

Example client configuration:

```json
{
  "mcpServers": {
    "xgr-mainnet": {
      "type": "http",
      "url": "https://mcp.xgr.network/mcp"
    },
    "xgr-testnet": {
      "type": "http",
      "url": "https://mcp.testnet.xgr.network/mcp"
    }
  }
}
```

## Official network discovery

Agents should call:

```text
get_xgr_network_info
```

when users ask for:

- official XGR.Network information,
- XGRChain metadata,
- chain IDs,
- RPC endpoints,
- Explorer endpoints,
- MCP endpoints,
- Faucet information,
- XRC standards,
- official documentation,
- source repositories.

Use:

```text
get_chain_status
```

for live connected-chain state.

## Recommended starter-gas workflow

```text
1. Inspect the address with get_account_live_state.
2. If it already has sufficient XGR, continue normally.
3. Call get_xgr_starter_gas_options.
4. Read the live network, chain ID, grant amount and policy.
5. Confirm the intended recipient address.
6. Call request_xgr_starter_gas exactly once.
7. Inspect grant_created, grant_status and transaction_hash.
8. Continue only after grant_status = confirmed.
```

Do not call the grant tool speculatively.

Do not repeat a request after a broadcast or confirmed result.

## Recommended purchase workflow

```text
1. Call get_xgr_purchase_options.
2. Select payment_assets[].key exactly.
3. Determine fixed-XGR or maximum-budget mode.
4. Collect user-supplied identity and wallet fields.
5. Require explicit terms acceptance.
6. Optionally call quote_xgr_purchase.
7. Create exactly one live order.
8. Inspect payment_approved and next_action.
9. Pay externally only from payment_instruction.
```

## Recommended XDaLa workflow

```text
1. Load authoring rules and standard references.
2. Draft XRC-137 rules and the XRC-729 orchestration.
3. Validate rule semantics and payload flow.
4. Assemble and validate xgr-multi-bundle@1.
5. Prepare a bundle-deploy handoff.
6. Review and sign in xDaLa Workbench.
7. Resolve the deployed runtime and start authority.
8. Prepare xgr-session-start@1.
9. Review and sign the Session Start request locally.
10. Inspect the resulting session and receipt evidence.
```

## Health metadata

A starter-gas-enabled deployment exposes a response similar to:

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

`MCP_READONLY=true` describes normal user operations.

It does not disable an explicitly enabled, narrowly scoped starter-gas service.

## Security summary

| Operation | User private key accepted | Server signs | External approval |
|---|---:|---:|---:|
| Read and evidence tools | No | No | No |
| Validation and diagrams | No | No | No |
| Bundle-deploy handoff | No | No | Yes |
| Session-start handoff | No | No | Yes |
| Purchase order creation | No | No payment signing | Explicit user data and terms |
| Starter-gas grant | No | Yes, service wallet only | Explicit recipient request |

## Repositories

Public MCP implementation:

```text
https://github.com/xgr-network/xgr-mcp
```

Canonical XGR and XDaLa documentation:

```text
https://github.com/xgr-network/XGR
```
