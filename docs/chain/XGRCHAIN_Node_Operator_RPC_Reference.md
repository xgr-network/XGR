# XGR Chain — Node Operator RPC & Internals

**Document ID:** XGRCHAIN-NODE-OPERATOR-RPC  
**Last updated:** 2026-05-03  
**Audience:** Node operators, validator operators, infrastructure engineers, internal tooling developers  
**Implementation status:** Current public baseline for standard debug/txpool/operator surfaces; XGR-specific extension methods are release-dependent  
**Source of truth:** Public `xgr-network/xgr-node` releases, active node binary behavior, and official XGR Network operator announcements

---

## 1. Scope

This document describes operator-facing RPC surfaces and node internals that are useful for diagnostics, tracing, transaction pool inspection and infrastructure operation.

It covers:

- RPC surface categories
- JSON-RPC dispatcher behavior
- `debug_*` tracing endpoints
- trace configuration
- debug request throttling
- `txpool_*` JSON-RPC endpoints
- txpool / mempool internals
- txpool validation rules
- txpool sizing and pressure handling
- transaction replacement behavior
- base-fee interaction in the txpool
- gRPC operator services
- operational security guidance
- troubleshooting workflows

This document is for node operation and diagnostics.

It is not an application API guide.

---

## 2. RPC surface categories

XGR Chain nodes expose different RPC surfaces for different audiences.

| Surface | Examples | Intended use | Exposure policy |
|---|---|---|---|
| Standard Ethereum JSON-RPC | `eth_*`, `net_*`, `web3_*` | Wallets, explorers, applications, scripts | Can be public with rate limits |
| TxPool JSON-RPC | `txpool_*` | Transaction pool inspection | Operator / controlled infrastructure |
| Debug JSON-RPC | `debug_*` | Tracing and execution diagnostics | Internal only |
| XGR extension RPC | `xgr_*` | XGR-specific validation/orchestration flows | Release- and endpoint-dependent |
| gRPC operator services | System, txpool and consensus operator services | Node operation and internal tooling | Internal only |

The public RPC endpoint used by wallets and applications should normally expose only the standard Ethereum-compatible surface and explicitly approved XGR extension methods.

Debug, txpool and gRPC operator surfaces should be restricted to trusted networks.

---

## 3. JSON-RPC dispatcher model

The JSON-RPC dispatcher receives JSON-RPC 2.0 requests and maps method names to registered endpoint services.

Method names follow this pattern:

```text
<namespace>_<method>
```

Examples:

```text
eth_blockNumber
net_peerCount
web3_clientVersion
txpool_status
debug_traceTransaction
xgr_<method>
```

The dispatcher splits the request method name at the first underscore and dispatches the call to the corresponding endpoint service.

Registered endpoint categories in the current public baseline include:

| Namespace | Endpoint role |
|---|---|
| `eth` | Ethereum-compatible chain interaction |
| `net` | Network metadata |
| `web3` | Client/version/hash helpers |
| `txpool` | Transaction pool inspection |
| `debug` | Execution tracing and diagnostics |
| `xgr` | XGR-specific extension endpoint surface, behavior depends on active release stack |

JSON-RPC batch requests are supported, but can be limited by runtime configuration.

Relevant runtime controls:

| Runtime option | Purpose |
|---|---|
| `--json-rpc-batch-request-limit` | Maximum number of JSON-RPC requests in one batch; `0` disables the limit |
| `--json-rpc-block-range-limit` | Maximum block range for range-based RPC queries |
| `--concurrent-requests-debug` | Debug tracing request throttling |
| `--websocket-read-limit` | Maximum WebSocket message size |

---

## 4. Standard Ethereum-compatible RPC

Standard Ethereum-compatible RPC is the normal application and infrastructure surface.

Typical namespaces:

```text
eth_*
net_*
web3_*
```

Used by:

- wallets
- explorers
- indexers
- scripts
- dApps
- infrastructure tools
- monitoring systems

Typical public-safe examples, when rate-limited and configured properly:

```text
eth_blockNumber
eth_chainId
eth_getBalance
eth_getTransactionByHash
eth_getTransactionReceipt
eth_call
eth_estimateGas
eth_sendRawTransaction
net_version
net_peerCount
web3_clientVersion
```

Public RPC nodes should still apply:

- request rate limits
- JSON-RPC batch limits
- block-range limits
- WebSocket limits
- abuse monitoring
- resource monitoring
- namespace filtering where available

---

## 5. Debug RPC overview

The `debug_*` endpoint group is intended for tracing and execution diagnostics.

Supported debug methods in the current public baseline include:

| Method | Purpose |
|---|---|
| `debug_traceBlockByNumber` | Trace all transactions in a block selected by block number |
| `debug_traceBlockByHash` | Trace all transactions in a block selected by block hash |
| `debug_traceBlock` | Trace an RLP-encoded block |
| `debug_traceTransaction` | Trace a mined transaction by transaction hash |
| `debug_traceCall` | Simulate and trace a call against a selected block |

Debug tracing can be CPU- and memory-intensive.

It should be treated as an operator-only diagnostic surface.

Recommended deployment model:

```text
Public RPC node:
  expose eth/net/web3 as needed
  do not expose debug

Internal tracing node:
  expose debug only to trusted operator networks
  isolate from validators where possible
```

---

## 6. `debug_traceBlockByNumber`

Traces all transactions in a block selected by block number.

### Request

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
- Genesis block tracing returns an error.
- Tracing is subject to timeout behavior.
- Tracing is subject to debug request throttling.
- Large blocks can be expensive to trace.

Supported block selector examples:

```text
latest
earliest
pending
0x<number>
```

Actual selector support follows the active JSON-RPC implementation.

---

## 7. `debug_traceBlockByHash`

Traces all transactions in a block selected by block hash.

### Request

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
- Genesis block tracing returns an error.
- Tracing all transactions in a block may be expensive.
- Use only on trusted/internal infrastructure.

---

## 8. `debug_traceBlock`

Traces an RLP-encoded block.

### Request

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

- The first parameter must be an RLP-encoded full block.
- Invalid hex or invalid RLP returns an error.
- Genesis block tracing returns an error.
- This method is intended for diagnostics and block-level analysis.

---

## 9. `debug_traceTransaction`

Traces a mined transaction by transaction hash.

### Request

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
- The node resolves the block through the transaction lookup index.
- Unknown transactions return an error.
- Transactions in genesis are not traceable.
- Pending transactions are not traced by this method.

For pending or hypothetical execution, use `debug_traceCall`.

---

## 10. `debug_traceCall`

Simulates and traces a call at a selected block.

### Request

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

- The call is simulated against the selected block/header state.
- It does not submit a transaction.
- It does not modify chain state.
- If gas is omitted, the implementation can default to the selected block gas limit.
- The trace result depends on the selected block and current state at that block.

---

## 11. Trace configuration

Debug tracing accepts a configuration object.

Supported fields:

| Field | Type | Meaning |
|---|---|---|
| `tracer` | string | `callTracer` selects call tracing; any other value uses the struct tracer |
| `timeout` | string | Go duration string, for example `5s` or `30s` |
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

A config object is required by the current implementation. Missing trace config returns an error.

### 11.1 Call tracer

Use:

```json
{
  "tracer": "callTracer",
  "timeout": "5s"
}
```

The call tracer is useful for:

- high-level call trees
- internal calls
- value movement
- revert analysis
- contract interaction debugging

### 11.2 Struct tracer

Any tracer value other than `callTracer` falls back to the struct tracer.

Example:

```json
{
  "disableStack": false,
  "disableStorage": true,
  "enableMemory": false,
  "enableReturnData": true,
  "timeout": "5s"
}
```

The struct tracer is useful for lower-level EVM execution analysis.

It can be significantly heavier than call tracing.

---

## 12. Debug endpoint throttling

Debug tracing uses request throttling.

Relevant runtime flag:

```text
--concurrent-requests-debug
```

Purpose:

```text
Limit the number of concurrent debug requests.
```

Default in the current public baseline:

```text
32
```

Operational recommendations:

- keep the value low on shared infrastructure
- use dedicated tracing nodes for heavy debug workloads
- do not run heavy tracing on validator nodes during critical operation
- do not expose debug endpoints publicly
- monitor CPU, memory, disk I/O and request latency
- use short timeouts for normal debugging
- use longer timeouts only on isolated internal nodes

---

## 13. TxPool JSON-RPC overview

The current public baseline registers a `txpool` JSON-RPC namespace.

Supported txpool JSON-RPC methods include:

| Method | Purpose |
|---|---|
| `txpool_content` | Returns pending and queued transactions grouped by sender and nonce |
| `txpool_inspect` | Returns a compact text summary of pending/queued transactions and pool capacity |
| `txpool_status` | Returns pending and queued transaction counts |

The txpool namespace is useful for operators and infrastructure diagnostics.

It should not be treated as a normal public application API.

---

## 14. `txpool_status`

Returns the number of pending and queued transactions.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "txpool_status",
  "params": []
}
```

### Response shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "pending": 12,
    "queued": 3
  }
}
```

### Meaning

| Field | Meaning |
|---|---|
| `pending` | Number of promoted / executable transactions currently ready for inclusion |
| `queued` | Number of enqueued transactions not yet executable, usually due to nonce gaps or ordering |

Use this endpoint for lightweight pool health checks.

---

## 15. `txpool_content`

Returns pending and queued transactions grouped by sender address and nonce.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "txpool_content",
  "params": []
}
```

### Response shape

```json
{
  "pending": {
    "0x<sender>": {
      "0": {
        "hash": "0x...",
        "nonce": "0x0",
        "from": "0x...",
        "to": "0x...",
        "value": "0x...",
        "gas": "0x...",
        "gasPrice": "0x..."
      }
    }
  },
  "queued": {
    "0x<sender>": {
      "1": {
        "hash": "0x...",
        "nonce": "0x1"
      }
    }
  }
}
```

Exact transaction object fields follow the node's transaction serialization.

### Notes

- Can return large responses.
- Should not be exposed publicly without strict controls.
- Useful for diagnosing stuck nonces and queue pressure.
- Useful for identifying senders producing excessive future-nonce transactions.

---

## 16. `txpool_inspect`

Returns compact txpool information.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "txpool_inspect",
  "params": []
}
```

### Response shape

```json
{
  "pending": {
    "0x<sender>": {
      "0": "0 wei + 21000 gas x 100000000000 wei"
    }
  },
  "queued": {},
  "currentCapacity": 10,
  "maxCapacity": 4096
}
```

### Meaning

| Field | Meaning |
|---|---|
| `pending` | Compact summary of executable transactions |
| `queued` | Compact summary of queued transactions |
| `currentCapacity` | Currently used txpool capacity in slots |
| `maxCapacity` | Configured maximum txpool capacity in slots |

The displayed gas price uses the node's current base-fee-aware gas price calculation.

---

## 17. TxPool / mempool terminology

In this document, **TxPool** and **mempool** refer to the same operational area:

```text
pending transactions stored by a node before they are included in a block
```

The code uses the module name:

```text
txpool
```

The pool is local to a node.

Different nodes may temporarily have different txpool contents.

Consensus finalizes blocks, not txpool state.

---

## 18. TxPool purpose

The TxPool manages incoming transactions before block inclusion.

It handles:

- local transactions submitted through node interfaces
- gossiped transactions received from peers
- transaction validation before pool admission
- sender recovery
- nonce ordering per sender account
- replacement handling
- promotion from enqueued to executable transactions
- pruning under pressure
- transaction selection support for block building
- txpool events
- txpool metrics

The TxPool is not the consensus layer.

It prepares candidate transactions, but validators still verify executed blocks through IBFT.

---

## 19. TxPool data model

The TxPool maintains transactions per sender account.

Conceptually each account has two queues:

| Queue | Meaning |
|---|---|
| Enqueued | Transactions known but not currently executable, usually due to nonce gaps or future nonce order |
| Promoted | Transactions ready for execution if selected for a block |

The pool also maintains:

| Structure | Purpose |
|---|---|
| account map | Tracks all accounts with txpool transactions |
| lookup index | Fast lookup for known transactions |
| priced executable queue | Executable transactions sorted by effective price |
| slot gauge | Tracks pool capacity usage |
| event manager | Emits txpool transaction events |
| pending counter | Tracks ready/pending count for metrics |
| base fee value | Used for effective gas price computation and sorting |

---

## 20. TxPool transaction sources

Transactions can enter the pool from two sources:

| Origin | Meaning |
|---|---|
| `local` | Submitted through local node interfaces |
| `gossip` | Received through p2p transaction gossip |

The p2p transaction gossip topic is:

```text
txpool/0.1
```

Local transactions can be broadcast to peers when the txpool topic is available.

---

## 21. TxPool validation rules

Before entering the pool, a transaction is validated.

Important checks include:

| Check | Purpose |
|---|---|
| State transaction rejection | Internal state transactions are not accepted into the normal txpool |
| Max transaction size | Rejects oversized encoded transactions |
| Non-negative value | Rejects negative-value transactions |
| Signature recovery | Rejects transactions whose sender cannot be recovered |
| Sender consistency | Explicit `from` must match recovered sender |
| Contract initcode limit | Enforces EIP-3860 initcode size limit when active |
| Access-list fork availability | Access-list transactions require EIP-2930 and typed transaction support |
| Dynamic-fee fork availability | Dynamic-fee transactions require London and typed transaction support |
| Fee cap / tip cap sanity | Ensures dynamic-fee fields are present and valid |
| Fee cap above base fee | Dynamic-fee `maxFeePerGas` must cover current base fee |
| Legacy gas price above base fee | Legacy `gasPrice` must satisfy base fee when London rules apply |
| Node price limit | Effective gas price must satisfy `priceLimit` |
| Nonce ordering | Too-low nonces are rejected |
| Account balance | Sender must have enough funds for gas and value |
| Intrinsic gas | Transaction gas must cover intrinsic gas |
| Block gas limit | Transaction gas must not exceed the current block gas limit |
| Chain ID for typed tx | Typed transaction chain ID must match node txpool chain ID |

TxPool admission is stricter than accepting any signed transaction.

---

## 22. Chain ID handling in TxPool

Typed transactions must carry the correct chain ID.

For XGR Chain mainnet:

```text
chainId = 1643
```

For typed transactions:

- `AccessListTx`
- `DynamicFeeTx`

the txpool checks that the transaction chain ID matches the configured node chain ID.

If the transaction does not carry a chain ID, the node can populate it from its configured chain ID before validation.

If the transaction carries a different chain ID, it is rejected.

This protects the txpool from cross-chain replay or misconfigured client submissions.

---

## 23. TxPool sizing and pressure handling

Important constants:

| Constant | Value | Meaning |
|---|---:|---|
| `txSlotSize` | 32 KB | Slot accounting unit |
| `txMaxSize` | 128 KB | Max encoded transaction size |
| `maxAccountDemotions` | 10 | Max recoverable demotions before dropping account transactions |
| `maxAccountSkips` | 10 | Max consecutive blocks account transactions can be skipped |
| `pruningCooldown` | 5 seconds | Cooldown between pruning attempts |

Relevant server flags:

| Flag | Meaning |
|---|---|
| `--max-slots` | Maximum txpool slots |
| `--max-enqueued` | Maximum enqueued transactions per account |
| `--price-limit` | Minimum effective gas price accepted into txpool |

Default values in the current public baseline:

| Setting | Default |
|---|---:|
| `--max-slots` | `4096` |
| `--max-enqueued` | `128` |
| `--price-limit` | `0` |

When the pool is under high pressure, future-nonce transactions can be rejected to preserve capacity for executable transactions.

---

## 24. Transaction replacement

The TxPool handles same-sender / same-nonce replacement.

A replacement transaction must offer a better effective gas price than the existing transaction for the same sender and nonce.

If the existing transaction has the same or better effective gas price, the replacement is rejected as underpriced.

This protects the pool from cheap replacement spam.

Operational implications:

- resend stuck transactions with the same nonce only if the new effective gas price is higher
- dynamic-fee replacements must increase the effective price enough to be accepted
- clients should track nonce and fee state carefully
- repeated underpriced replacement attempts can indicate wallet misconfiguration or spam

---

## 25. TxPool and base fee

The TxPool tracks the current base fee from the chain head.

Base fee is used for:

- sorting executable transactions
- computing effective gas price
- rejecting underpriced dynamic-fee transactions
- rejecting underpriced legacy transactions when London rules are active
- enforcing node-level `priceLimit`

Effective gas price logic follows:

```text
Legacy transaction:
effectiveGasPrice = gasPrice

Dynamic-fee transaction:
effectiveGasPrice = min(maxFeePerGas, maxPriorityFeePerGas + baseFee)
```

A transaction can be validly signed but still rejected by the txpool if its effective price is too low for the current node state.

---

## 26. TxPool metrics

The txpool module emits txpool-related metrics.

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
- rejected future transactions
- already-known transactions
- replacement-underpriced transactions

Operators should alert on unusual spikes in invalid or underpriced transaction metrics.

Common causes include:

- misconfigured wallets
- stale gas settings
- spam traffic
- RPC abuse
- nonce-management bugs
- chain ID mismatch
- insufficient account balance
- broken transaction replacement logic

---

## 27. gRPC operator services

The node exposes gRPC operator services for internal node operation and tooling.

The gRPC interface is controlled by:

```text
--grpc-address
```

Recommended production binding:

```text
127.0.0.1:9632
```

Do not expose gRPC publicly.

### 27.1 System service

The System service includes methods for:

| Method | Purpose |
|---|---|
| `GetStatus` | Returns client/network/current block status |
| `PeersAdd` | Adds a peer |
| `PeersList` | Lists known peers |
| `PeersStatus` | Returns information about a peer |
| `Subscribe` | Streams blockchain events |
| `BlockByNumber` | Returns block data by number |
| `Export` | Streams exported chain data |

These methods are operational interfaces.

They are useful for CLI tooling, internal automation and node diagnostics.

### 27.2 TxPool operator service

The txpool module registers a txpool operator gRPC service when a gRPC server is configured.

This service is internal tooling infrastructure and should be treated as private operator surface.

### 27.3 Consensus operator services

Consensus-related operator services may be available depending on the active release and enabled consensus engine.

These services are intended for node and validator diagnostics.

They should remain internal.

---

## 28. WebSocket behavior

The JSON-RPC layer supports WebSocket handling where enabled by node configuration.

Supported subscription patterns include:

```text
eth_subscribe
eth_unsubscribe
```

Supported subscription categories include:

| Subscription | Meaning |
|---|---|
| `newHeads` | New block headers |
| `logs` | Log events matching a filter |
| `newPendingTransactions` | Pending transaction notifications |

Relevant runtime control:

```text
--websocket-read-limit
```

Default:

```text
8192
```

Public WebSocket endpoints should be rate-limited and monitored.

Pending transaction subscriptions can be high-volume under load.

---

## 29. Security guidance

Operator and diagnostic surfaces must be protected.

Recommended exposure policy:

| Surface | Recommended exposure |
|---|---|
| `eth_*` | Public only with rate limits and monitoring |
| `net_*` | Public only with rate limits and monitoring |
| `web3_*` | Public only with rate limits and monitoring |
| `txpool_*` | Internal or controlled infrastructure only |
| `debug_*` | Internal only |
| `xgr_*` | Endpoint-specific policy |
| gRPC operator services | Internal only |
| Metrics | Internal / monitoring network only |

Minimum controls:

- do not expose debug tracing publicly
- do not expose gRPC publicly
- do not run public RPC on validator nodes
- restrict txpool inspection to trusted infrastructure
- isolate heavy tracing from validators
- apply JSON-RPC batch limits
- apply block-range limits
- cap concurrent debug requests
- rate-limit public HTTP/WebSocket traffic
- monitor CPU, memory, disk and network usage
- monitor RPC error rates
- monitor txpool pressure
- monitor peer count and block height

---

## 30. Recommended deployment patterns

### 30.1 Public RPC node

Recommended public RPC node exposure:

| Surface | Exposure |
|---|---|
| `eth_*` | Public with rate limits |
| `net_*` | Public with rate limits |
| `web3_*` | Public with rate limits |
| `txpool_*` | Usually disabled or restricted |
| `debug_*` | Not public |
| gRPC | Localhost/private only |
| Metrics | Monitoring network only |

Public RPC nodes should not hold validator signing material.

### 30.2 Internal tracing node

Recommended tracing node exposure:

| Surface | Exposure |
|---|---|
| `debug_*` | Internal only |
| `txpool_*` | Internal only |
| `eth_*` | Internal only |
| gRPC | Localhost/private only |
| Metrics | Monitoring network only |

Use tracing nodes for heavy diagnostic workloads.

### 30.3 Validator node

Recommended validator node exposure:

| Surface | Exposure |
|---|---|
| P2P | Required by network topology |
| JSON-RPC | Localhost/private only |
| gRPC | Localhost only |
| `debug_*` | Disabled or tightly restricted |
| `txpool_*` | Local/internal only |
| Metrics | Monitoring network only |

Validators should not be used as public RPC endpoints.

---

## 31. Operational troubleshooting

### 31.1 Block production stalls

Check:

- process health
- peer count
- validator connectivity
- IBFT round changes
- signer errors
- block proposal logs
- txpool pressure
- disk usage
- CPU saturation
- memory pressure
- system clock synchronization

Useful checks:

```text
eth_blockNumber
net_peerCount
web3_clientVersion
```

Use internal operator tooling for deeper node status checks.

---

### 31.2 Transactions are not included

Check:

- account nonce
- sender balance
- gas limit
- transaction type
- chain ID
- effective gas price
- base fee
- node `priceLimit`
- txpool status
- replacement pricing
- max enqueued/account limits
- whether the transaction is future-nonce
- whether the transaction exceeds block gas limit

Useful methods:

```text
eth_getTransactionByHash
eth_getTransactionReceipt
txpool_status
txpool_content
txpool_inspect
```

---

### 31.3 Transaction rejected as underpriced

Possible causes:

- `gasPrice` below current base fee
- `maxFeePerGas` below current base fee
- `maxPriorityFeePerGas` greater than `maxFeePerGas`
- effective gas price below node `priceLimit`
- replacement transaction does not improve effective gas price
- stale wallet gas estimate
- local node base fee changed since transaction construction

Actions:

- refresh fee estimate
- increase effective gas price
- verify nonce
- verify account balance
- retry through a healthy synced node

---

### 31.4 Transaction rejected due to nonce

Possible causes:

- nonce already mined
- nonce lower than account state nonce
- nonce gap
- queued future-nonce transaction
- replacement transaction underpriced
- multiple wallets using same account
- local nonce cache stale

Useful methods:

```text
eth_getTransactionCount
txpool_content
txpool_inspect
```

---

### 31.5 RPC latency high

Check:

- debug tracing load
- large `eth_getLogs` ranges
- batch request size
- WebSocket subscription pressure
- pending transaction subscriptions
- txpool spam
- CPU saturation
- memory pressure
- disk I/O
- peer churn
- reverse proxy limits

Mitigations:

- reduce public method exposure
- lower batch limit
- lower block-range limit
- isolate tracing
- rate-limit clients
- scale RPC nodes horizontally
- move indexing workloads off public RPC nodes

---

### 31.6 Debug tracing times out

Possible causes:

- trace timeout too low
- block too large
- transaction execution too complex
- struct tracer capturing too much data
- node under CPU pressure
- node under memory pressure
- tracing performed on overloaded public RPC node

Actions:

- use `callTracer` for high-level traces
- increase timeout only on internal tracing nodes
- disable memory/storage capture where possible
- isolate tracing workload
- check node resources
- avoid tracing through public RPC infrastructure

---

## 32. Operator checklist

For public RPC infrastructure:

- expose only intended namespaces
- rate-limit public traffic
- set batch request limits
- set block range limits
- restrict WebSocket abuse
- keep debug internal
- keep gRPC internal
- monitor txpool pressure
- monitor RPC latency and errors
- monitor CPU, memory and disk
- do not run validator keys on public RPC nodes

For validator infrastructure:

- keep JSON-RPC private
- keep gRPC local/private
- keep debug restricted
- monitor peer count
- monitor consensus logs
- monitor block height
- monitor signer errors
- avoid heavy tracing on validators
- isolate validator keys
- maintain backups and restart procedures

For tracing infrastructure:

- run separate internal tracing nodes
- expose debug only to trusted networks
- tune `--concurrent-requests-debug`
- use timeouts
- monitor resources
- avoid public access
