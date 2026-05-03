# XGR Chain — Node Operator RPC & Internals

**Document ID:** XGRCHAIN-NODE-OPERATOR-RPC  
**Last updated:** 2026-05-03  
**Audience:** Node operators, infrastructure engineers, validator operators, internal tooling developers  
**Implementation status:** Mixed  
**Source of truth:** `xgrchain/jsonrpc`, `xgrchain/txpool`, `xgrchain/docs/docs/design/*`

---

## 1. Scope

This document describes **operator-only JSON-RPC surfaces and node internals** that are useful for diagnostics, tracing, txpool understanding and infrastructure operation.

It covers:

- the role of JSON-RPC inside the node
- `debug_*` tracing endpoints
- tracer configuration
- txpool / mempool internals
- txpool validation rules
- operational security recommendations
- what should not be exposed publicly

This document does **not** define the public wallet/explorer API.

Public RPC documentation lives in:

- `XGRCHAIN_Ethereum_JSON_RPC_Reference.md`

XDaLa Engine endpoints live in:

- `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md`

---

## 2. Public vs operator RPC

XGR Chain has different RPC categories.

| Category | Examples | Intended audience | Public exposure |
|---|---|---|---|
| Standard Ethereum RPC | `eth_*`, `net_*`, `web3_*` | wallets, explorers, dApps | can be public with rate limits |
| XDaLa Engine RPC | `xgr_*` | XDaLa clients, orchestration tools | depends on endpoint and deployment policy |
| Debug RPC | `debug_*` | operators, auditors, internal diagnostics | **do not expose publicly** |
| TxPool internals | txpool module / gRPC operator hooks / metrics | operators, validators, internal tooling | **do not expose publicly unless explicitly controlled** |

The old Polygon Edge documentation kept `debug_*` and `txpool_*` beside public RPC docs. XGR should not do that. Debug and txpool surfaces are operational tools, not public application APIs.

---

## 3. JSON-RPC server role

The JSON-RPC layer receives requests, decodes JSON-RPC 2.0 messages, dispatches them to endpoint namespaces and serializes responses.

At a high level:

1. client sends JSON-RPC request
2. node decodes method and params
3. dispatcher maps the request to an endpoint implementation
4. endpoint reads chain/txpool/state/Engine data as needed
5. response or error is encoded as JSON-RPC 2.0

Relevant endpoint groups:

| Namespace | Purpose |
|---|---|
| `eth_*` | Ethereum-compatible chain interaction |
| `net_*` | network metadata |
| `web3_*` | client/version/hash helpers |
| `debug_*` | tracing and execution diagnostics |
| `xgr_*` | XDaLa Engine-specific methods |

---

## 4. Debug RPC overview

The `debug_*` endpoint group is intended for tracing and diagnostics.

It is implemented by the `Debug` endpoint in `jsonrpc/debug_endpoint.go`.

Supported debug methods include:

| Method | Purpose |
|---|---|
| `debug_traceBlockByNumber` | Trace all transactions in a block selected by block number |
| `debug_traceBlockByHash` | Trace all transactions in a block selected by block hash |
| `debug_traceBlock` | Trace an RLP-encoded block |
| `debug_traceTransaction` | Trace a mined transaction by transaction hash |
| `debug_traceCall` | Simulate and trace a call against a selected block |

These methods can be expensive. They may execute EVM tracing over full blocks or transactions and should be treated as operator-only.

---

## 5. `debug_traceBlockByNumber`

Traces all transactions in a block selected by block number.

### Request shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "debug_traceBlockByNumber",
  "params": [
    "latest",
    {
      "tracer": "callTracer",
      "timeout": "5s"
    }
  ]
}
```

### Notes

- The selected block must exist.
- Genesis block tracing is rejected.
- The trace is subject to throttling and timeout behavior.

---

## 6. `debug_traceBlockByHash`

Traces all transactions in a block selected by block hash.

### Request shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "debug_traceBlockByHash",
  "params": [
    "0x<blockHash>",
    {
      "tracer": "callTracer",
      "timeout": "5s"
    }
  ]
}
```

### Notes

- Returns an error if the block is not found.
- Genesis block tracing is rejected.

---

## 7. `debug_traceBlock`

Traces an RLP-encoded block.

### Request shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "debug_traceBlock",
  "params": [
    "0x<rlpEncodedBlock>",
    {
      "tracer": "callTracer",
      "timeout": "5s"
    }
  ]
}
```

### Notes

- The input is decoded as a full RLP block.
- Invalid encoding returns an error.
- Genesis block tracing is rejected.

---

## 8. `debug_traceTransaction`

Traces a transaction by transaction hash.

### Request shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "debug_traceTransaction",
  "params": [
    "0x<transactionHash>",
    {
      "tracer": "callTracer",
      "timeout": "5s"
    }
  ]
}
```

### Notes

- The transaction must already be mined.
- The node resolves the block through transaction lookup.
- Genesis transactions are not traceable.
- Unknown transactions return an error.

---

## 9. `debug_traceCall`

Simulates and traces a call at a selected block.

### Request shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "debug_traceCall",
  "params": [
    {
      "from": "0x<sender>",
      "to": "0x<target>",
      "gas": "0x5208",
      "gasPrice": "0x0",
      "value": "0x0",
      "data": "0x"
    },
    "latest",
    {
      "tracer": "callTracer",
      "timeout": "5s"
    }
  ]
}
```

### Notes

- If gas is omitted, the implementation can default to the selected block gas limit.
- The call is traced against the selected header/state.
- This is diagnostic simulation, not transaction submission.

---

## 10. Trace configuration

Debug tracing accepts a configuration object.

Supported fields:

| Field | Type | Meaning |
|---|---|---|
| `tracer` | string | `callTracer` for call tracing; otherwise struct tracer is used |
| `timeout` | string | Go duration string, e.g. `5s`, `30s` |
| `enableMemory` | bool | Include memory in struct logs unless struct logs are disabled |
| `disableStack` | bool | Disable stack capture |
| `disableStorage` | bool | Disable storage capture |
| `enableReturnData` | bool | Include return data |
| `disableStructLogs` | bool | Disable detailed struct logs |

Default timeout:

```text
5 seconds
```

If timeout is reached, tracing is cancelled with an execution-timeout error.

---

## 11. Debug endpoint throttling

The debug endpoint uses request throttling.

Operator flag:

```text
--concurrent-requests-debug
```

Purpose:

```text
Limit the number of concurrent debug requests.
```

Operational recommendation:

- keep this low on shared infrastructure
- do not expose debug tracing on public RPC
- use dedicated internal nodes for heavy tracing
- isolate tracing from validator nodes where possible

---

## 12. TxPool / mempool terminology

In this documentation, **TxPool** and **mempool** refer to the same operational area:

```text
pending transactions stored by a node before they are included in a block
```

The code uses the `txpool` module name.

The old docs separated `txpool.md` and `mempool.md`. For XGR, those should be consolidated into one operator/internal explanation.

---

## 13. TxPool purpose

The TxPool manages incoming transactions before block inclusion.

It handles:

- local transactions submitted by JSON-RPC/gRPC
- gossiped transactions received from peers
- transaction validation before pool admission
- nonce ordering per sender account
- replacement handling
- promotion from enqueued to executable transactions
- pruning under pressure
- transaction selection for block building
- txpool metrics

The TxPool is not the consensus layer. It prepares candidate transactions, but validators still verify executed blocks through IBFT.

---

## 14. TxPool data model

The TxPool maintains transactions per sender account.

Conceptually each account has two queues:

| Queue | Meaning |
|---|---|
| Enqueued | Transactions known but not yet executable because of nonce gaps or ordering |
| Promoted | Transactions ready for execution if selected for a block |

The pool also maintains:

| Structure | Purpose |
|---|---|
| account map | all accounts with txpool transactions |
| lookup index | fast lookup for known transactions |
| priced executable queue | executable transactions sorted by effective gas price |
| slot gauge | tracks pool capacity usage |
| event manager | emits txpool transaction events |
| pending counter | tracks ready/pending count for metrics |

---

## 15. TxPool transaction sources

Transactions can enter the pool from two sources:

| Origin | Meaning |
|---|---|
| `local` | submitted through local node interfaces such as JSON-RPC/gRPC |
| `gossip` | received through the p2p transaction gossip topic |

The p2p topic name is:

```text
txpool/0.1
```

Local transactions can be broadcast to peers when the txpool topic is available.

---

## 16. TxPool validation rules

Before entering the pool, a transaction is validated.

Important checks include:

| Check | Purpose |
|---|---|
| Reject state transactions | State transactions are not accepted into the public txpool |
| Max transaction size | DoS protection; max encoded tx size is 128 KB |
| Non-negative value | Negative-value transactions are rejected |
| Signature recovery | Invalid signatures are rejected |
| Sender consistency | Explicit `from` must match recovered sender |
| Contract initcode limit | EIP-3860 contract creation size limit when active |
| Access-list fork availability | Access-list txs require EIP-2930 and typed tx support |
| Dynamic-fee fork availability | Dynamic-fee txs require London and typed tx support |
| Fee cap / tip cap sanity | Fee cap and tip cap must be present and valid |
| Fee cap above base fee | Dynamic tx `maxFeePerGas` must be at least current base fee |
| Legacy gas price above base fee | Legacy tx gas price must satisfy base fee when London is active |
| Price limit | Effective gas price must satisfy node `priceLimit` |
| Nonce ordering | Too-low nonces are rejected |
| Account balance | Sender must have enough funds for gas and value |
| Intrinsic gas | Transaction gas must cover intrinsic gas |
| Block gas limit | Transaction gas must not exceed current block gas limit |

TxPool admission is therefore stricter than simply accepting any signed transaction.

---

## 17. TxPool sizing and pressure handling

Important constants:

| Constant | Value | Meaning |
|---|---:|---|
| `txSlotSize` | 32 KB | slot accounting unit |
| `txMaxSize` | 128 KB | max encoded transaction size |
| `maxAccountDemotions` | 10 | max recoverable demotions before dropping account txs |
| `maxAccountSkips` | 10 | max consecutive blocks account txs can be skipped |
| `pruningCooldown` | 5 seconds | cooldown between pruning attempts |

Relevant server flags:

| Flag | Meaning |
|---|---|
| `--max-slots` | maximum txpool slots |
| `--max-enqueued` | maximum enqueued transactions per account |
| `--price-limit` | minimum effective gas price accepted into txpool |

When the pool is under high pressure, future-nonce transactions can be rejected to preserve capacity for executable transactions.

---

## 18. Transaction replacement

The TxPool handles same-sender / same-nonce replacement.

A replacement transaction must offer a better effective gas price than the existing transaction for the same nonce.

Otherwise it is rejected as underpriced replacement.

This protects the pool from cheap replacement spam.

---

## 19. TxPool and base fee

The TxPool tracks the current base fee from the chain head.

Base fee is used for:

- sorting executable transactions
- computing effective gas price
- rejecting underpriced dynamic-fee transactions
- rejecting underpriced legacy transactions when London rules are active
- enforcing node-level `priceLimit`

The canonical gas rules are documented in:

- `XRC-GAS_Gas_Price_Behavior.md`

---

## 20. TxPool metrics

The txpool module emits metrics under the txpool prefix.

Important metric themes:

- pending transaction count
- invalid transaction categories
- underpriced transactions
- oversized transactions
- nonce-too-low transactions
- invalid signatures
- insufficient funds
- block gas limit exceeded
- dynamic-fee validation errors

Operators should alert on unusual spikes in invalid or underpriced transaction metrics, as these can indicate client bugs, spam, mispriced traffic or RPC abuse.

---

## 21. TxPool JSON-RPC status

As of the checked `PoS_3` state:

- old `docs/docs/api/json-rpc-txpool.md` is not present on the branch
- no current `txpool_*` JSON-RPC endpoint was identified in the active branch search
- txpool behavior is still implemented internally in the `txpool` module

Therefore:

```text
Do not document txpool_* as a public JSON-RPC namespace unless the endpoint is intentionally reintroduced.
```

If future versions add `txpool_*` endpoints, they should be documented here as operator-only, not in the public Ethereum RPC reference.

---

## 22. Security guidance for debug and txpool tooling

Do not expose debug or txpool internals on public RPC infrastructure.

Recommended policy:

| Surface | Public exposure |
|---|---|
| `eth_*` | allowed with rate limits |
| `net_*` | allowed with rate limits |
| `web3_*` | allowed with rate limits |
| `xgr_*` | depends on endpoint policy |
| `debug_*` | internal only |
| `txpool_*` if reintroduced | internal only |
| gRPC operator services | internal only |

Minimum controls:

- firewall debug endpoints
- run public RPC on non-validator nodes
- isolate heavy tracing from validators
- apply JSON-RPC batch/range limits
- cap concurrent debug requests
- rate-limit public HTTP/WebSocket access
- monitor CPU, memory and disk during tracing
- do not expose debug endpoints through public reverse proxies

---

## 23. Operational troubleshooting

### Block production stalls

Check:

- peer count
- validator connectivity
- IBFT round changes
- signer errors
- block proposal logs
- txpool pressure
- disk and CPU saturation

### Transactions not included

Check:

- account nonce
- sender balance
- gas limit
- effective gas price
- txpool `priceLimit`
- base fee
- replacement pricing
- max enqueued/account limits
- whether the transaction is future-nonce

### RPC latency high

Check:

- debug tracing load
- large `eth_getLogs` ranges
- batch request size
- WebSocket subscription pressure
- txpool spam
- CPU/memory saturation
- disk I/O

---

## 24. Explicit legacy exclusions

The following old documentation topics should not be kept as current XGR operator documentation:

| Old topic | Decision |
|---|---|
| Generic Edge JSON-RPC overview | replaced by XGR-specific RPC documents |
| Separate mempool and txpool pages | consolidated here |
| Public `txpool_*` docs from old API tree | not active / not public |
| Public `debug_*` docs from old API tree | operator-only here |
| Bridge/rootchain RPC | removed / legacy |
| State sync relayer operator docs | removed / legacy |
| PolyBFT checkpoint/bridge internals | removed / legacy |

---

## 25. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Node_Operation.md` | General node operation and runtime flags |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Public Ethereum-compatible RPC |
| `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md` | XDaLa Engine RPC |
| `XRC-GAS_Gas_Price_Behavior.md` | Gas and fee behavior |
| `XGRCHAIN_Consensus_IBFT.md` | IBFT consensus |
