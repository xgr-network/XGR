# XGR MCP Gateway — Overview

**Document ID:** XGR-MCP-OVERVIEW  
**Last updated:** 2026-07-21  
**Audience:** Developers, integrators, agent builders, auditors  
**Implementation status:** Public mainnet and testnet gateways live; read, validation, diagram, handoff and deployment-controlled mainnet purchase tools implemented  
**Source of truth:** `xgr-mcp-gateway`

> **One-liner**
>
> The **XGR MCP Gateway** is the AI-native access layer to XGRChain and XDaLa. It exposes live chain state, indexed Explorer evidence, XDaLa sessions, XRC standards, workflow discovery, authoring knowledge, validated human-in-the-loop handoffs and optional mainnet XGR purchase ordering as semantic Model Context Protocol tools.

---

## What it is

The XGR MCP Gateway is a standalone Model Context Protocol server implemented in TypeScript with `@modelcontextprotocol/sdk`.

It allows MCP-compatible agents and applications to work with:

- XGRChain live JSON-RPC state,
- chain-wide indexed transaction data,
- XDaLa sessions, steps, payloads and receipts,
- XRC-137 rules and XRC-729 orchestrations,
- workflow authority and executor relationships,
- schemas, examples and authoring rules,
- process diagrams,
- bundle-deploy and session-start handoffs,
- optional mainnet XGR purchase discovery, quotation and order creation.

The gateway is not a wallet, signer or custody service.

It gives an agent enough structured context to answer or execute requests such as:

- What happened in this transaction?
- What did this XDaLa session execute?
- Which workflows may this address start?
- Which payload fields are required to wake this waiting step?
- Which XRC-137 rules already exist for this owner?
- Can this process bundle be deployed?
- Prepare this validated workflow for local deployment.
- Prepare this deployed workflow for local session start.
- Which payment assets can currently be used to purchase XGR?
- How much XGR can be ordered within a defined USDC or USDT budget?
- Create a live XGR purchase reservation and return the exact external payment instruction.

## XGR surfaces

| Surface | Primary responsibility |
|---|---|
| **XGRChain** | Consensus, transactions, contracts, XGR JSON-RPC and protocol state |
| **XDaLa** | Validation, orchestration and deterministic process execution |
| **Explorer** | Indexed chain evidence, session evidence and analytics |
| **xDaLa Workbench** | Human review, wallet connection, local signing and execution |
| **XGR purchase API** | Mainnet XGR price, inventory, payment assets, order creation and reservation |
| **MCP Gateway** | Semantic discovery, inspection, validation, reasoning, handoff preparation and controlled purchase orchestration |

## Operational classes

The gateway supports four operational classes.

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
- example artifacts,
- MultiBundle and Session Start validation,
- XRC-137 and payload-flow validation,
- Mermaid process diagrams.

They operate locally in the gateway and do not submit transactions.

### 3. Human-in-the-loop handoff tools

Handoff tools prepare and store validated offchain requests and return an environment-specific browser or Workbench URL.

The user must:

1. open the returned URL,
2. review the prepared request,
3. connect their own wallet or signer,
4. authorize and sign locally.

The gateway itself never holds private keys and never signs transactions.

See [Operation Handoff](./XGR-MCP-Operation-Handoff.md).

### 4. Mainnet XGR purchase tools

Optional purchase tools connect to the configured XGR purchase API.

They can:

- read current payment options,
- read live XGR price and availability,
- calculate a non-binding budget quote,
- create one real mainnet purchase order for an exact XGR quantity,
- create one real mainnet purchase order from a maximum USDC or USDT budget,
- return an exact structured external payment instruction.

Creating an order is not a read-only action. It creates a live offchain reservation in the purchase backend.

The gateway itself:

- does not hold payment private keys,
- does not send USDC or USDT,
- does not transfer XGR,
- does not automatically retry an uncertain or blocked order.

Payment is performed outside the gateway by a human wallet, custody system or explicitly authorized external wallet agent.

## Design principles

1. **Read-first with explicit mutation boundaries.**  
   Most tools read or validate data. Mutable effects are limited to explicit offchain actions such as temporary handoff records or purchase reservations.

2. **Never custodial.**  
   Private keys, seed phrases, wallet secrets and signing material must never be supplied to the gateway.

3. **Semantic over raw.**  
   Tools are described around user intent instead of exposing only low-level RPC or HTTP calls.

4. **Evidence over inference.**  
   Transaction, receipt, session and XRC tools distinguish live RPC data, Explorer API data and indexed database data.

5. **Canonical schemas before execution.**  
   Deploy and session-start requests must pass the validators that define the corresponding Workbench formats.

6. **Explicit authorization before purchase ordering.**  
   Purchase identity, wallets and terms acceptance must come from the user or an authorized upstream system. An agent must not invent them.

7. **Backend-authoritative purchase results.**  
   Budget calculations are planning estimates. The purchase backend is authoritative for the final XGR quantity, payment amount, custody wallet, reference and reservation expiry.

8. **External payment boundary.**  
   The MCP may create an order and return an exact payment instruction. Payment signing and transmission remain outside the gateway.

9. **Human approval at the on-chain workflow boundary.**  
   The agent may inspect, draft and prepare XDaLa actions. The human wallet remains responsible for authorization and signing.

10. **No environment leakage.**  
    Public metadata exposes only supported mainnet and testnet resources. Workbench URLs are generated from the configured environment.

## Architecture

```text
 MCP client
 ChatGPT / Claude / IDE / custom agent host
          │
          │ Model Context Protocol
          │ Streamable HTTP or local stdio
          ▼
 ┌──────────────────────── XGR MCP Gateway ────────────────────────┐
 │                                                                 │
 │  tools/                                                         │
 │    chain · transactions · sessions · receipts · XRC             │
 │    knowledge · validation · diagram · handoff · purchase        │
 │                                                                 │
 │  adapters/                                                      │
 │    XGR JSON-RPC · Explorer API · indexed read databases          │
 │    XGR purchase API                                              │
 │                                                                 │
 │  knowledge/                                                     │
 │    XRC-137 · XRC-729 · authoring rules · schemas · validators    │
 │                                                                 │
 │  operations/                                                    │
 │    protected offchain handoff stores · result callbacks          │
 │                                                                 │
 └──────────────┬────────────────┬────────────────┬────────────────┘
                │                │                │
                ▼                ▼                ▼
          XGRChain RPC      XGR Explorer    XGR purchase API
          live state        indexed data    price + reservation
                │
                ▼
          xDaLa Workbench
          review + local signing
```

## Public MCP endpoints

The hosted gateways use stateless Streamable HTTP requests through `POST /mcp`.

### Mainnet

```text
https://mcp.xgr.network/mcp
```

Use mainnet for:

- production chain state,
- deployed contracts,
- real XDaLa sessions,
- production evidence,
- mainnet purchase tools when enabled by the deployment.

### Testnet

```text
https://mcp.testnet.xgr.network/mcp
```

Use testnet for development, workflow validation and controlled testing.

Mainnet purchase tools are never registered by a testnet-configured gateway.

### Testnet Faucet

```text
https://faucet.xgr.network
```

The faucet provides testnet XGR. It is not a mainnet purchase service.

### Example client configuration

Client terminology differs. Some clients call the transport `http`, others `streamable-http` or `remote MCP`.

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
- the mainnet chain ID,
- RPC, Explorer or MCP endpoints,
- the testnet faucet,
- XRC standard context,
- official documentation or repositories.

The response is versioned as:

```text
xgr-network-info@1
```

It includes only the supported public mainnet and testnet environments.

`get_chain_status` is separate. It reads the connected RPC live and returns the current chain ID, block number and gas price together with compact official entry points.

## Mainnet XGR purchase workflow

Purchase tools are registered only when the operator explicitly enables them for mainnet.

The deterministic agent workflow is:

```text
1. Call get_xgr_purchase_options.
2. Inspect payment_assets[].
3. Use payment_assets[].key exactly as payment_asset.
4. Inspect requires_sender_wallet.
5. Determine whether the user supplied:
   a. an exact XGR quantity, or
   b. a maximum USDC/USDT budget.
6. Collect all required user-supplied identity and wallet fields.
7. Require explicit terms acceptance.
8. Optionally call quote_xgr_purchase for budget planning.
9. Create exactly one live order.
10. Inspect payment_approved and next_action.
11. Pay only from payment_instruction.
```

### Discover live options

Always call:

```text
get_xgr_purchase_options
```

before quoting or creating an order.

The result includes:

- live XGR price data,
- available and reserved inventory,
- policy limits,
- supported payment assets,
- chain and decimal metadata,
- whether the selected asset requires a sender wallet,
- machine-readable `agent_guidance`.

Use:

```text
payment_assets[].key
```

as the exact `payment_asset` input.

Do not substitute the display symbol.

For example, use a returned key such as:

```text
usdc_eth
```

rather than:

```text
USDC
```

### Choose the order mode

Use:

```text
create_xgr_purchase_order
```

when the user specifies an exact integer XGR quantity.

Use:

```text
create_xgr_purchase_order_by_budget
```

when the user specifies a maximum USDC or USDT payment amount.

Use:

```text
quote_xgr_purchase
```

only for non-binding budget planning. A quote creates no order and is not a payment instruction.

### Collect required data

The agent must not invent:

- purchaser name,
- purchaser email,
- country code,
- XGR delivery wallet,
- payment sender wallet,
- terms acceptance.

The XGR wallet must be controlled by the intended recipient.

The sender wallet must be controlled by the payment executor and is required when the selected payment asset returns:

```json
{
  "requires_sender_wallet": true
}
```

`terms_accepted` may be set to `true` only after explicit acceptance.

### Create one live reservation

Order creation is non-idempotent.

A successful order reserves XGR inventory until the returned expiry time.

Do not repeat an order call merely because:

- the client connection was interrupted,
- the response could not be parsed,
- the backend response was incomplete,
- the result was uncertain.

An uncertain response may still correspond to an existing reservation.

### Evaluate the result

An approved order returns:

```json
{
  "order_created": true,
  "payment_approved": true,
  "payment_execution": "external",
  "next_action": "external_crypto_payment",
  "payment_instruction_exact": true
}
```

The payment executor must use the structured:

```text
payment_instruction
```

rather than rebuilding payment data from estimates or raw price fields.

The instruction contains:

```text
type
chain
asset_key
symbol
decimals
amount
recipient
sender_wallet
reference
expires_at
xgr_delivery.chain_id
xgr_delivery.wallet
xgr_delivery.amount_xgr
```

Payment is permitted only when both conditions are true:

```text
payment_approved = true
next_action = external_crypto_payment
```

If the result contains:

```text
next_action = do_not_pay
```

the agent must not pay.

## Budget order behavior

Budget mode uses a conservative planning price:

```text
conservative_price =
  discounted_usdc_per_xgr ×
  (1 + safety_margin_bps / 10000)
```

The planned XGR quantity is:

```text
floor(max_payment_amount / conservative_price)
```

The default safety margin is:

```text
100 basis points
```

The quote and planning values are not binding.

The gateway submits one normal order to the backend. The backend returns the exact payment amount.

If:

```text
exact_payment_amount <= max_payment_amount
```

payment is approved.

If:

```text
exact_payment_amount > max_payment_amount
```

the order may already exist and inventory may already be reserved, but payment is blocked:

```json
{
  "order_created": true,
  "payment_approved": false,
  "payment_execution": "blocked",
  "next_action": "do_not_pay"
}
```

The existing reservation expires normally. The gateway does not automatically create a second order.

## Tool result model

Tool results remain compatible with MCP text content and also expose parsed JSON through `structuredContent` when the tool returned valid JSON.

Typical programmatic access:

```text
result.structuredContent.data
```

Tool registrations include MCP annotations such as:

- `readOnlyHint`,
- `destructiveHint`,
- `idempotentHint`,
- `openWorldHint`.

This helps MCP hosts distinguish read tools, handoff tools and live non-idempotent order-creation tools.

## Tool domains

The current gateway includes these domains:

- **Network and chain discovery**
- **XGR protocol**
- **Mainnet XGR purchase**
- **Transaction search and evidence**
- **XDaLa session evidence**
- **Session resolver and analytics**
- **Waiting-step and wake-up discovery**
- **Decoded engine receipts**
- **XRC-137 and XRC-729 inspection**
- **Authority and executor discovery**
- **XRC usage, reuse and failure analytics**
- **Knowledge and documentation retrieval**
- **Schema and authoring validation**
- **Mermaid process rendering**
- **Generic operation handoffs**
- **XDaLa bundle-deploy handoffs**
- **XDaLa session-start handoffs**

The exact catalog is in the [Tool Reference](./XGR-MCP-Tool-Reference.md).

## Security boundary

The MCP Gateway:

- does not accept private keys,
- does not derive wallet secrets,
- does not sign transactions,
- does not hold payment keys,
- does not send USDC or USDT,
- does not transfer purchased XGR,
- does not silently start sessions,
- does not silently deploy contracts,
- does not expose bearer handles through list tools,
- rejects sensitive fields in public handoff payloads,
- validates supported handoff result structures,
- requires explicit purchase terms acceptance,
- validates returned purchase instructions before permitting payment,
- blocks payment when a budget limit is exceeded,
- applies configurable public-route origin, size and rate-limit controls.

A returned handoff URL is sensitive. Treat it as a temporary bearer URL and do not publish it.

A returned purchase instruction is also sensitive operational data. Use it only for the intended order and only before its expiry.

## Related documents

- [Tool Reference](./XGR-MCP-Tool-Reference.md)
- [Operation Handoff](./XGR-MCP-Operation-Handoff.md)
- [Authoring & Knowledge](./XGR-MCP-Authoring-and-Knowledge.md)
- [Setup & Configuration](./XGR-MCP-Setup-and-Configuration.md)
- [XGR and XDaLa General Overview](../general-overview.md)
- [XDaLa XGR Endpoint Reference](../XDaLa_XGR_Endpoint_Reference.md)
