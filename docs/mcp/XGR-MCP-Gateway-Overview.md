# XGR MCP Gateway — Overview

**Document ID:** XGR-MCP-OVERVIEW  
**Last updated:** 2026-06-07  
**Audience:** Developers, integrators, agent builders, auditors  
**Implementation status:** Phase 1 (read-only) live; handoff preparation live  
**Source of truth:** `xgr-mcp-gateway`

> **One-liner**  
> The **XGR MCP Gateway** is the AI-native access layer to the XGR stack. It exposes XGRChain, XDaLa sessions, Explorer data, XRC standards and authoring knowledge as semantic [Model Context Protocol](https://modelcontextprotocol.io) tools — and prepares human-in-the-loop write operations without ever holding keys or signing.

---

## What it is

The gateway is a standalone MCP server (TypeScript, `@modelcontextprotocol/sdk`) that any MCP-compatible client — Claude, ChatGPT, IDE agents, custom hosts — can connect to. It turns the XGR stack into a set of well-described, parameterized tools so an agent can answer questions like *"what happened in this session?"*, *"which workflows can I start?"*, or *"draft and validate a process bundle"* without bespoke integration code.

It sits as a **fourth surface** alongside the UI, xDaLa and the Chain:

| Surface | Answers the question |
|---|---|
| **Chain** | What is the protocol and how do nodes run it? |
| **xDaLa** | What are sessions, rules and orchestration semantics? |
| **UI** | How does a human build and operate this in the browser? |
| **MCP** | How do AI agents read, reason over, and prepare actions on all of the above? |

## Design principles

1. **Read-first.** Phase 1 is strictly read-only. The gateway exposes semantic tools over existing JSON-RPC and Explorer APIs and over the Explorer read-only Postgres mirror (`PGRO_*`). It does not sign, submit, or mutate XDaLa state.
2. **Never custodial.** The gateway never receives, stores, or derives private keys. Write intents are prepared as **handoffs** (see [Operation Handoff](./XGR-MCP-Operation-Handoff.md)) and executed by the user locally in the browser with their own wallet/signer. The gateway stores only operation metadata, status, and transaction hashes — never secrets or signing material.
3. **Semantic over raw.** Tools are named and described for agent reasoning, not for thin RPC mirroring. Each tool description tells the agent *when* to use it and what it does and does not return, which keeps tool selection deterministic.
4. **Single source of truth for knowledge.** Authoring rules, XRC schemas and examples are served from the gateway's knowledge base so that the agent drafting an artifact and the validator checking it share the same definitions. See [Authoring & Knowledge](./XGR-MCP-Authoring-and-Knowledge.md).

## Architecture

```
  MCP client (Claude / ChatGPT / IDE agent / custom host)
        │  JSON-RPC over stdio or HTTP (/mcp)
        ▼
  ┌──────────────────────────── XGR MCP Gateway ────────────────────────────┐
  │  tools/        semantic MCP tools (chain, session, tx, xrc, knowledge…)  │
  │  operations/   handoff stores + browser handoff routes                   │
  │  knowledge/    XRC-137 / XRC-729 / xDaLa authoring rules & schemas        │
  │  adapters/     rpcClient · explorerClient · *DbClient (PGRO read-only)    │
  └───────┬───────────────────┬───────────────────────┬─────────────────────┘
          │                   │                        │
          ▼                   ▼                        ▼
   XGRChain JSON-RPC    Explorer API +           xDaLa Workbench
   (rpc.xgr.network)    PGRO read-only DB        (handoff import + local signing)
```

The gateway runs in two modes from the same codebase:

- **stdio** (`npm run dev` / `npm start`) — for local MCP hosts that spawn the server as a child process.
- **HTTP** (`npm run dev:http` / `npm run start:http`) — exposes `POST /mcp`, plus the browser-facing operation/handoff routes under `/operations/*` and `/api/operations/*`. Health is at `GET /health`.

## Tool domains at a glance

The gateway registers roughly seventy tools across these domains:

- **Chain** — live RPC status, blocks, account state.
- **XGR protocol** — core addresses, circulating supply, rule gas estimation.
- **Session evidence & resolver** — find, list, detail, and statistics for indexed XDaLa sessions, including payload/step analytics.
- **Receipts** — decoded engine receipt data for a session step.
- **Transactions** — chain-wide indexed transaction search, value transfers, account/block transactions, stats.
- **XRC** — XRC-137/XRC-729 contract inspection, OSTC/rule JSON reads, process-graph resolution, reuse and failure analytics.
- **Knowledge** — standards references, schemas, examples, and validators for XRC-137, XRC-729, MultiBundle and Session Start.
- **Diagram** — Mermaid rendering of an XRC-729 process graph.
- **Operations / Handoff** — prepare and track operation, bundle-deploy and session-start handoffs.

The full catalog is in the [Tool Reference](./XGR-MCP-Tool-Reference.md).

## Related documents

- [Tool Reference](./XGR-MCP-Tool-Reference.md)
- [Operation Handoff](./XGR-MCP-Operation-Handoff.md)
- [Authoring & Knowledge](./XGR-MCP-Authoring-and-Knowledge.md)
- [Setup & Configuration](./XGR-MCP-Setup-and-Configuration.md)
- [general-overview.md](../general-overview.md) — XGR & xDaLa context
- [XDaLa_XGR_Endpoint_Reference.md](../XDaLa_XGR_Endpoint_Reference.md)
