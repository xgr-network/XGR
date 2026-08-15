# XGR MCP Gateway — Overview

**Document ID:** XGR-MCP-OVERVIEW  
**Last updated:** 2026-08-15  
**Audience:** Developers, integrators, agent builders, operators, auditors  
**Implementation status:** Public mainnet and testnet gateways live  
**Source of truth:** [`xgr-network/xgr-mcp`](https://github.com/xgr-network/xgr-mcp)

> **One-liner**
>
> The XGR MCP Gateway is the AI-native access layer to XGRChain and XDaLa. It exposes live chain state, indexed evidence, XDaLa workflows, XRC standards, native-XGR relation graphs and value-flow analysis, validated execution handoffs, XGR purchase tools and optional native XGR starter gas through the Model Context Protocol.

---

## What it is

The XGR MCP Gateway is a public Model Context Protocol server implemented in TypeScript with `@modelcontextprotocol/sdk`.

It allows MCP-compatible agents and applications to work with:

- XGRChain live JSON-RPC state,
- indexed Explorer transactions and receipts,
- native-XGR address relation graphs,
- transaction relation tracing,
- native-XGR value-flow provenance analysis,
- XDaLa sessions, steps, payloads and execution evidence,
- historical XDaLa Session Start payload values,
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

---

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

---

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
- Which addresses exchanged native XGR with this address?
- Expand this address relation graph by one level.
- Which transactions are represented by this relation-graph edge?
- Trace the relation graph around this transaction.
- Model where native XGR value from this transaction may have flowed.
- Which payload values have historically been used to start this XDaLa workflow step?

---

## XGR surfaces

| Surface | Primary responsibility |
|---|---|
| **XGRChain** | Consensus, transactions, contracts, native XGR and protocol state |
| **XDaLa** | Validation, orchestration and deterministic process execution |
| **Explorer** | Indexed chain evidence, session evidence, analytics, relation graphs and value-flow data |
| **xDaLa Workbench** | Human review, wallet connection, local signing and execution |
| **XGR purchase API** | Mainnet XGR price, inventory, payment assets and reservations |
| **Starter-gas service** | Fixed native XGR grants from a dedicated service wallet |
| **MCP Gateway** | Semantic discovery, inspection, validation and controlled execution boundaries |

---

## Operational classes

The gateway exposes five operational classes.

### 1. Read and evidence tools

These tools read live RPC state, Explorer APIs, indexed databases or deployed contracts.

Examples:

- live chain and account state,
- transaction evidence,
- native-XGR relation graphs,
- transaction relation tracing,
- native-XGR value-flow provenance,
- relation-edge transaction evidence,
- XDaLa session timelines,
- decoded engine receipts,
- historical Session Start payload values,
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
- return an exact structured external payment instruction.

Creating an order is not read-only.

It creates a live offchain reservation in the purchase backend.

The gateway does not:

- hold payment private keys,
- send stablecoin payments,
- sign on behalf of the purchaser,
- automatically retry uncertain purchase orders.

For approved orders, the MCP returns:

```text
payment_approved = true
payment_execution = external
next_action = external_crypto_payment
```

Payment must be executed only from the returned structured:

```text
payment_instruction
```

If an already-posted order cannot be safely validated, payment is blocked:

```text
payment_approved = false
payment_execution = blocked
next_action = do_not_pay
```

Pre-order validation or API failures may return:

```text
order_created = false
post_completed = false
next_action = fix_input_or_retry
```

An agent must not treat `fix_input_or_retry` as permission to blindly repeat a potentially state-changing operation.

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

---

## Native XGR relation graphs

The gateway exposes Explorer-backed relation-graph tools for indexed native XGR transfers.

The core tools are:

```text
get_address_relation_graph
expand_address_relation_graph
trace_xgr_transaction
get_relation_edge_transactions
```

### Address relation graph

Use:

```text
get_address_relation_graph
```

to retrieve a bounded graph around an EVM address.

The graph can be filtered by:

- direction,
- graph depth,
- minimum native XGR transfer value,
- time range,
- aggregation mode,
- maximum nodes,
- maximum edges.

Supported directions are:

```text
in
out
both
```

Graph depth is bounded.

The gateway implementation currently accepts depths from:

```text
1
```

through:

```text
4
```

The graph is native-XGR specific.

A relation means indexed native XGR transfers occurred between addresses.

It does **not** prove:

- common ownership,
- common control,
- identity,
- beneficial ownership,
- affiliation,
- intent.

### Progressive graph expansion

Use:

```text
expand_address_relation_graph
```

to expand an address by exactly one additional graph level.

For interactive exploration this is preferable to immediately requesting the largest possible graph.

### Transaction relation tracing

Use:

```text
trace_xgr_transaction
```

when the investigation starts from a transaction hash.

The tool loads the indexed transaction, resolves its sender and recipient and returns:

- the indexed transaction,
- a graph root,
- sender and recipient transaction roots where available,
- an explicit edge representing the original transaction,
- the surrounding relation graph.

The relation graph does not imply that later balances or later transfers contain the same specific XGR units.

---

## Native XGR value-flow provenance

Use:

```text
trace_xgr_value_flow
```

for native-XGR provenance analysis beginning with one transaction.

The tool supports two models:

```text
possible
proportional
```

### `possible`

The `possible` model provides conservative attribution ranges.

Use it when the question is whether some amount **could** have flowed through later transfers given the account history.

### `proportional`

The `proportional` model applies a proportional haircut/share model to outgoing value.

Use it only when proportional attribution is appropriate for the analysis.

### Important limitation

Native XGR is account-based.

There is no unique per-coin identity.

Therefore:

> A value-flow result is an attribution or provenance model. It is not proof that one particular unit of XGR moved through a later transaction.

The tool can bound processing using:

```text
maxTransfers
maxHops
minAttributedWei
```

`maxTransfers` and `maxHops` may also use:

```text
all
```

`all` does not disable safety limits.

Explorer server-side safety caps remain authoritative and the result may report truncation.

---

## Relation-edge transaction evidence

Use:

```text
get_relation_edge_transactions
```

to retrieve the indexed native-XGR transactions represented by one directed graph edge.

The edge is defined as:

```text
source → target
```

The tool supports the same kinds of minimum-value and time filtering used by the graph tools.

This allows an agent to move from:

```text
aggregated relationship
```

to:

```text
underlying transaction evidence
```

without treating the graph edge itself as sufficient evidence.

---

## Historical XDaLa Session Start payload evidence

Use:

```text
get_xdala_start_payload_history
```

to inspect indexed historical payload values used when starting a specific XRC-729 OSTC entry step.

The request identifies:

```text
xrc729Address
ostcId
stepId
```

and may optionally restrict results by:

```text
owner
windowHours
limit
```

The tool reads Explorer database evidence and selects the first matching entry-step receipt per:

```text
owner + sessionId
```

It then aggregates scalar values by field.

Scalar values include:

- strings,
- numbers,
- booleans.

Payload keys beginning with:

```text
__
```

are ignored.

The result is intended for:

- UI value pickers,
- agent context,
- discovering commonly used business values,
- helping an operator recognize previously used values.

Historical values are **not**:

- current schema defaults,
- current required values,
- authorization,
- workflow authority,
- validation results,
- permission to reuse sensitive or business-specific data.

Before preparing a Session Start, the agent must still resolve the current deployed XRC-137 rule and current payload schema.

Missing required values must not be silently populated from historical data.

---

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

A transaction already in `broadcast` state is not blindly repeated.

The gateway first checks its receipt.

---

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

---

## Abuse controls

The starter-gas implementation applies:

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

---

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

---

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
   Transaction, receipt, session, XRC and relation-graph tools distinguish live RPC data, Explorer data and indexed evidence.

6. **Canonical schemas before execution**  
   Deploy and Session Start requests must pass the corresponding validators.

7. **Explicit authorization before purchase ordering**  
   Purchase identity, wallet data and terms acceptance must come from the user or an authorized upstream system.

8. **No automatic retry after uncertain mutation**  
   Purchase orders and broadcast starter-gas transactions must not be repeated merely because a client response was interrupted.

9. **Human approval at workflow execution boundaries**  
   The agent may inspect, draft and prepare XDaLa actions. The user remains responsible for local wallet authorization.

10. **Relationship is not identity**  
    A transaction relation between addresses does not establish ownership, identity or affiliation.

11. **Native value flow is modeled, not individually traceable**  
    Native XGR has no unique per-unit identity. Provenance analysis must therefore be presented as an attribution model.

12. **History is evidence, not configuration**  
    Historical payload values may assist users and agents but do not replace the current runtime rule, schema, defaults or explicit user input.

---

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
 │    chain · transactions · relation graphs · value flow           │
 │    sessions · payload history · receipts · XRC                   │
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
                                 ▼
                         read-only Explorer DB
                │
                ├── native XGR grant
                │
                ▼
          xDaLa Workbench
          review + local signing
```

---

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

Clients that expose `streamable-http` as an explicit transport may use that transport with the same endpoint.

---

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

---

## Recommended relation-graph workflow

```text
1. Identify the address or transaction that anchors the investigation.
2. Call get_address_relation_graph for a bounded initial view.
3. Inspect depth, node, edge and truncation metadata.
4. Use expand_address_relation_graph for progressive exploration.
5. Use get_relation_edge_transactions for the transactions behind an edge.
6. Use trace_xgr_transaction when starting from a transaction hash.
7. Do not infer identity or common ownership from an address relation alone.
```

---

## Recommended native-XGR value-flow workflow

```text
1. Identify the seed transaction hash.
2. Call trace_xgr_value_flow.
3. Use model=possible for conservative possible-attribution analysis.
4. Use model=proportional only when proportional attribution is intended.
5. Inspect transfer, hop and truncation limits.
6. Treat the result as a provenance model rather than proof of per-coin movement.
```

---

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

---

## Recommended purchase workflow

```text
1. Call get_xgr_purchase_options.
2. Select payment_assets[].key exactly.
3. Inspect requires_sender_wallet.
4. Determine fixed-XGR or maximum-budget mode.
5. Collect user-supplied identity and wallet fields.
6. Require explicit terms acceptance.
7. Optionally call quote_xgr_purchase for planning.
8. Create exactly one live order.
9. Inspect payment_approved and next_action.
10. Pay only when payment_approved=true and next_action=external_crypto_payment.
11. Execute the payment only from payment_instruction.
```

The agent must not invent:

```text
name
email
country_code
xgr_wallet
sender_wallet
terms_accepted
```

Do not pay a quote.

Do not pay a blocked or uncertain order.

Do not automatically retry a potentially created order.

---

## Recommended XDaLa workflow

```text
1. Load authoring rules and standard references.
2. Draft XRC-137 rules and the XRC-729 orchestration.
3. Validate rule semantics and payload flow.
4. Assemble and validate xgr-multi-bundle@1.
5. Prepare a bundle-deploy handoff.
6. Review and sign in xDaLa Workbench.
7. Resolve the deployed runtime and start authority.
8. Resolve the current entry-step XRC-137 rule and payload schema.
9. Optionally inspect get_xdala_start_payload_history for historical scalar value evidence.
10. Present unresolved required payload fields to the user.
11. Prepare xgr-session-start@1.
12. Review and sign the Session Start request locally.
13. Inspect the resulting session and receipt evidence.
```

Historical payload values must not be silently substituted for missing required inputs.

---

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

---

## Security summary

| Operation | User private key accepted | Server signs | External approval |
|---|---:|---:|---:|
| Read and evidence tools | No | No | No |
| Relation graph tools | No | No | No |
| Native-XGR value-flow analysis | No | No | No |
| Historical start-payload evidence | No | No | No |
| Validation and diagrams | No | No | No |
| Bundle-deploy handoff | No | No | Yes |
| Session-start handoff | No | No | Yes |
| Purchase order creation | No | No payment signing | Explicit user data and terms |
| Starter-gas grant | No | Yes, service wallet only | Explicit recipient request |

---

## Repositories

Public MCP implementation:

```text
https://github.com/xgr-network/xgr-mcp
```

Canonical XGR and XDaLa documentation:

```text
https://github.com/xgr-network/XGR
```
