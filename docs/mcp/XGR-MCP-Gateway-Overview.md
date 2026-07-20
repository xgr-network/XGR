# XGR MCP Gateway — Overview

**Document ID:** XGR-MCP-OVERVIEW  
**Last updated:** 2026-07-20  
**Audience:** Developers, integrators, agent builders, auditors  
**Implementation status:** Public mainnet and testnet gateways live; read, validation, diagram and human-in-the-loop handoff tools live  
**Source of truth:** `xgr-mcp-gateway`

> **One-liner**
>
> The **XGR MCP Gateway** is the AI-native access layer to XGRChain and XDaLa. It exposes live chain state, indexed Explorer evidence, XDaLa sessions, XRC standards, workflow discovery, authoring knowledge and validated human-in-the-loop handoffs as semantic Model Context Protocol tools.

---

## What it is

The XGR MCP Gateway is a standalone Model Context Protocol server implemented in TypeScript with `@modelcontextprotocol/sdk`.

It allows MCP-compatible agents and applications to work with:

- XGRChain live JSON-RPC state
- chain-wide indexed transaction data
- XDaLa sessions, steps, payloads and receipts
- XRC-137 rules and XRC-729 orchestrations
- workflow authority and executor relationships
- schemas, examples and authoring rules
- process diagrams
- bundle-deploy and session-start handoffs

The gateway is not a wallet, signer or custody service.

It gives an agent enough structured context to answer questions such as:

- What happened in this transaction?
- What did this XDaLa session execute?
- Which workflows may this address start?
- Which payload fields are required to wake this waiting step?
- Which XRC-137 rules already exist for this owner?
- Can this process bundle be deployed?
- Prepare this validated workflow for local deployment.
- Prepare this deployed workflow for local session start.

## XGR surfaces

| Surface | Primary responsibility |
|---|---|
| **XGRChain** | Consensus, transactions, contracts, XGR JSON-RPC and protocol state |
| **XDaLa** | Validation, orchestration and deterministic process execution |
| **Explorer** | Indexed chain evidence, session evidence and analytics |
| **xDaLa Workbench** | Human review, wallet connection, local signing and execution |
| **MCP Gateway** | Semantic discovery, inspection, validation, reasoning and handoff preparation |

## Implementation model

The gateway supports three operational classes.

### 1. Read and evidence tools

These tools read live RPC state, Explorer APIs, indexed databases or deployed contracts.

Examples:

- live chain and account state
- transaction evidence
- XDaLa session timelines
- decoded engine receipts
- XRC contract and event indexes
- workflow authority
- payload and failure analytics

They do not mutate chain state.

### 2. Knowledge, validation and diagram tools

These tools provide:

- canonical XRC references
- JSON schemas
- authoring rules
- example artifacts
- MultiBundle and Session Start validation
- XRC-137 and payload-flow validation
- Mermaid process diagrams

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

## Design principles

1. **Read-first, not read-only-only.**  
   Most tools read or validate data. Write intent is represented only as an offchain handoff for human review and local execution.

2. **Never custodial.**  
   Private keys, seed phrases, wallet secrets and signing material must never be supplied to the gateway.

3. **Semantic over raw.**  
   Tools are described around user intent instead of exposing only low-level RPC calls.

4. **Evidence over inference.**  
   Transaction, receipt, session and XRC tools distinguish live RPC data, Explorer API data and indexed database data.

5. **Canonical schemas before execution.**  
   Deploy and session-start requests must pass the same validators that define the corresponding Workbench formats.

6. **Human approval at the trust boundary.**  
   The agent may inspect, draft and prepare. The human wallet remains responsible for authorization and signing.

7. **No environment leakage.**  
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
 │    knowledge · validation · diagram · handoff                   │
 │                                                                 │
 │  adapters/                                                      │
 │    XGR JSON-RPC · Explorer API · indexed read databases          │
 │                                                                 │
 │  knowledge/                                                     │
 │    XRC-137 · XRC-729 · authoring rules · schemas · validators    │
 │                                                                 │
 │  operations/                                                    │
 │    protected offchain handoff stores · result callbacks          │
 │                                                                 │
 └──────────────┬────────────────┬──────────────────┬───────────────┘
                │                │                  │
                ▼                ▼                  ▼
          XGRChain RPC      XGR Explorer       xDaLa Workbench
          live state        indexed evidence   review + local signing
```

## Public MCP endpoints

The hosted gateways use stateless Streamable HTTP requests through `POST /mcp`.

### Mainnet

```text
https://mcp.xgr.network/mcp
```

Use mainnet for production chain state, deployed contracts, real XDaLa sessions and production evidence.

### Testnet

```text
https://mcp.testnet.xgr.network/mcp
```

Use testnet for development, workflow validation and controlled testing.

### Testnet Faucet

```text
https://faucet.xgr.network
```

The faucet provides testnet XGR. It is not a mainnet service.

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

- official XGR.Network information
- XGRChain metadata
- the mainnet chain ID
- RPC, Explorer or MCP endpoints
- the testnet faucet
- XRC standard context
- official documentation or repositories

The response is versioned as:

```text
xgr-network-info@1
```

It includes only the supported public mainnet and testnet environments.

`get_chain_status` is separate. It reads the connected RPC live and returns the current chain ID, block number and gas price together with compact official entry points.

## Tool result model

Tool results remain compatible with MCP text content and also expose parsed JSON through `structuredContent` when the tool returned valid JSON.

Tool registrations include MCP annotations such as:

- `readOnlyHint`
- `destructiveHint`
- `idempotentHint`
- `openWorldHint`

This helps MCP hosts distinguish read tools from handoff preparation tools.

## Tool domains

The current gateway includes these domains:

- **Network and chain discovery**
- **XGR protocol**
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
- does not silently start sessions,
- does not silently deploy contracts,
- does not expose bearer handles through list tools,
- rejects sensitive fields in public handoff payloads,
- validates supported handoff result structures,
- applies configurable public-route origin, size and rate-limit controls.

A returned handoff URL is still sensitive. Treat it as a temporary bearer URL and do not publish it.

## Related documents

- [Tool Reference](./XGR-MCP-Tool-Reference.md)
- [Operation Handoff](./XGR-MCP-Operation-Handoff.md)
- [Authoring & Knowledge](./XGR-MCP-Authoring-and-Knowledge.md)
- [Setup & Configuration](./XGR-MCP-Setup-and-Configuration.md)
- [XGR and XDaLa General Overview](../general-overview.md)
- [XDaLa XGR Endpoint Reference](../XDaLa_XGR_Endpoint_Reference.md)
