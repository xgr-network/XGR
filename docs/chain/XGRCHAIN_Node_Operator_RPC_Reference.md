# XGR Chain — Node Operator RPC & Internals

**Document ID:** XGRCHAIN-NODE-OPERATOR-RPC  
**Last updated:** 2026-10-03  
**Audience:** Node operators, validator operators, infrastructure engineers, tracing operators, internal tooling developers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Operator-facing JSON-RPC, tracing, txpool, XGR-specific diagnostic endpoints and gRPC services

---

## 1. Scope

This document describes operator-facing node interfaces in `xgr-node v3.1.1`.

It covers:

- registered JSON-RPC namespaces,
- dispatcher behavior,
- `debug_*` tracing,
- trace configuration,
- debug request throttling,
- `txpool_*` inspection,
- txpool internals,
- `bridge_*` compatibility endpoints,
- `xgr_*` public-node behavior,
- native interchain-attestation RPC,
- public-build engine stub behavior,
- gRPC operator services,
- historical-state requirements for tracing,
- operational security,
- troubleshooting.

This is not the primary application JSON-RPC reference.

Standard Ethereum-compatible methods are documented in:

```text
XGRCHAIN_Ethereum_JSON_RPC_Reference.md
```

PoS-specific public RPC is documented in:

```text
XGRCHAIN_Staking_PoS_Endpoint_Reference.md
```

---

## 2. Current dispatcher namespaces

The `v3.1.1` JSON-RPC dispatcher registers:

```text
eth
net
web3
txpool
bridge
xgr
debug
```

Corresponding method naming follows:

```text
<namespace>_<lowerCamelCaseMethod>
```

Examples:

```text
eth_blockNumber
txpool_status
debug_traceTransaction
bridge_generateExitProof
xgr_getNextProcessId
xgr_getInterchainAttestation
```

The dispatcher converts exported Go endpoint method names by lowercasing the first character.

---

## 3. RPC surface classification

| Namespace | Primary purpose | Recommended exposure |
| --- | --- | --- |
| `eth_*` | Ethereum-compatible application/chain RPC | Public with controls |
| `net_*` | Network metadata | Public with controls |
| `web3_*` | Client/hash helpers | Public with controls |
| `txpool_*` | Local transaction-pool inspection | Internal / controlled |
| `debug_*` | EVM tracing | Internal only |
| `bridge_*` | Legacy/compatibility bridge proof helpers | Internal / use-case-specific |
| `xgr_*` | XGR-specific methods | Method-specific |
| gRPC | Node/peer/consensus operator control | Internal only |

Namespace registration does not mean every method should be publicly exposed.

---

## 4. JSON-RPC dispatcher behavior

A JSON-RPC method name is split at the first underscore:

```text
debug_traceTransaction
```

becomes:

```text
service = debug
method  = traceTransaction
```

Unknown services or methods return method-not-found errors.

The dispatcher supports:

- single JSON-RPC 2.0 requests,
- batch requests,
- HTTP RPC,
- WebSocket RPC,
- WebSocket subscriptions.

Relevant runtime limits:

| Setting | `v3.1.1` default |
| --- | ---: |
| Batch request limit | `20` |
| Block-range limit | `1000` |
| Concurrent debug requests | `32` |
| WebSocket read limit | `8192` bytes |

Runtime flags:

```text
--json-rpc-batch-request-limit
--json-rpc-block-range-limit
--concurrent-requests-debug
--websocket-read-limit
```

A value of `0` for the batch-request limit disables that specific limit.

---

# Debug / Tracing RPC

## 5. Debug RPC overview

`v3.1.1` exposes:

```text
debug_traceBlockByNumber
debug_traceBlockByHash
debug_traceBlock
debug_traceTransaction
debug_traceCall
```

Debug tracing can be expensive in:

- CPU,
- memory,
- state reads,
- disk I/O.

It should not be exposed as an unrestricted public service.

Recommended topology:

```text
public RPC
    → no public debug

internal tracing node
    → debug enabled for trusted users
```

Avoid sustained tracing load on validator nodes.

---

## 6. `debug_traceBlockByNumber`

Traces all transactions in a selected canonical block.

Example:

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

The node:

1. resolves the block selector,
2. loads the full block,
3. constructs the requested tracer,
4. replays the block execution.

Genesis cannot be traced.

The implementation returns:

```text
genesis is not traceable
```

for block `0`.

---

## 7. `debug_traceBlockByHash`

Example:

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

The block must exist locally.

Unknown hashes return an error.

---

## 8. `debug_traceBlock`

This endpoint accepts an RLP-encoded block.

Example:

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

Invalid:

- hexadecimal encoding,
- RLP,
- block structure,

returns an error.

This is primarily an internal diagnostic method.

---

## 9. `debug_traceTransaction`

Traces a mined transaction.

Example:

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

The node:

1. resolves the transaction through the transaction lookup,
2. locates its block,
3. reconstructs the execution context,
4. traces the transaction.

Pending transactions are not supported by this method.

Unknown transactions return an error.

---

## 10. `debug_traceCall`

Simulates and traces a call without changing canonical state.

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "debug_traceCall",
  "params": [
    {
      "from": "0x<sender>",
      "to": "0x<target>",
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

If gas is omitted:

```text
gas = selected block gas limit
```

is used by the tracing path.

`debug_traceCall` does not broadcast a transaction.

---

## 11. Trace configuration

The trace configuration contains:

| Field | Type | Meaning |
| --- | --- | --- |
| `tracer` | string | Select tracing implementation |
| `timeout` | string | Go duration such as `5s` |
| `enableMemory` | bool | Capture EVM memory |
| `disableStack` | bool | Disable stack capture |
| `disableStorage` | bool | Disable storage capture |
| `enableReturnData` | bool | Capture return data |
| `disableStructLogs` | bool | Disable opcode-level struct logs |

A trace config object is required.

If it is omitted:

```text
missing config object
```

is returned.

Default timeout:

```text
5 seconds
```

---

## 12. Call tracer

Use:

```json
{
  "tracer": "callTracer",
  "timeout": "5s"
}
```

The call tracer is useful for:

- contract call trees,
- nested calls,
- internal value movements,
- revert analysis,
- protocol interaction analysis.

It is usually preferable when opcode-level tracing is unnecessary.

---

## 13. Struct tracer

Any tracer value other than:

```text
callTracer
```

selects the struct tracer.

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

Struct tracing is substantially more detailed and can be considerably more expensive.

---

## 14. Debug request throttling

Runtime flag:

```text
--concurrent-requests-debug
```

Default:

```text
32
```

The implementation uses a weighted semaphore.

At most the configured number of debug calls may execute concurrently.

A request waits for a slot for up to:

```text
1 second
```

If a slot is not available:

```text
request limit exceeded
```

is returned.

This is **concurrency throttling**, not a requests-per-second quota.

---

## 15. Trie pruning and historical tracing

Tracing historical execution requires historical EVM state.

When the Online State Trie Sweeper is enabled, sufficiently old state may have been reclaimed.

Therefore a pruned node may still have:

```text
block
transaction
receipt
logs
```

while no longer having the complete state required to replay that old block.

Historical:

```text
debug_traceBlockByNumber
debug_traceBlockByHash
debug_traceTransaction
debug_traceCall
```

can therefore fail for old state on a pruned node.

For unrestricted historical tracing:

```text
use an archive-style node
```

or a node with a retention window covering the requested block.

This is not a consensus error.

It is a local state-retention limitation.

---

# TxPool RPC

## 16. TxPool methods

The `txpool` namespace exposes:

```text
txpool_content
txpool_inspect
txpool_status
```

Txpool contents are local node state.

Two healthy nodes can temporarily expose different txpool contents.

Consensus finalizes blocks, not mempool state.

---

## 17. `txpool_status`

Request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "txpool_status",
  "params": []
}
```

Response:

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

Fields:

| Field | Meaning |
| --- | --- |
| `pending` | Promoted/executable transaction count |
| `queued` | Enqueued/non-currently-executable transaction count |

The fields are plain JSON numbers in this operator endpoint.

---

## 18. `txpool_content`

Request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "txpool_content",
  "params": []
}
```

Response structure:

```json
{
  "pending": {
    "0x<sender>": {
      "0": {
        "hash": "0x...",
        "nonce": "0x0",
        "from": "0x...",
        "to": "0x..."
      }
    }
  },
  "queued": {}
}
```

Transactions are grouped by:

```text
sender
    ↓
nonce
```

This endpoint can become large on busy nodes.

Keep it internal or tightly controlled.

---

## 19. `txpool_inspect`

Example structure:

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

The summary format is:

```text
<value> wei + <gas> gas x <effective gas price> wei
```

The effective gas price is calculated using the node's current base fee.

---

## 20. TxPool defaults

Current `v3.1.1` defaults:

| Setting | Default |
| --- | ---: |
| `--max-slots` | `4096` |
| `--max-enqueued` | `128` |
| `--price-limit` | `0` |

Internal constants include:

| Constant | Value |
| --- | ---: |
| Transaction slot size | `32 KB` |
| Maximum encoded transaction size | `128 KB` |
| TxPool gossip topic | `txpool/0.1` |

These are node implementation values rather than chain-consensus parameters.

---

## 21. TxPool transaction sources

Transactions can originate from:

```text
local RPC submission
```

or:

```text
P2P gossip
```

Typical path:

```text
eth_sendRawTransaction
        ↓
local validation
        ↓
txpool
        ↓
txpool/0.1 gossip
        ↓
peer txpool validation
```

Every receiving peer independently validates the transaction.

---

## 22. TxPool validation

Admission checks include:

- transaction encoding,
- maximum transaction size,
- transaction type,
- chain ID,
- sender recovery,
- signature validity,
- sender consistency,
- nonce,
- account balance,
- intrinsic gas,
- block gas limit,
- contract-initcode rules,
- access-list activation,
- dynamic-fee activation,
- fee-cap/tip-cap consistency,
- base fee,
- local price limit.

Internal:

```text
StateTx / 0x7f
```

transactions are not ordinary user txpool transactions.

---

## 23. Chain ID

Typed transactions must use:

```text
1643
```

for XGRChain mainnet.

Incorrect transaction-chain IDs are rejected.

This is distinct from RPC endpoint reachability.

A transaction sent to an XGR node is not valid merely because the node accepted the JSON-RPC request itself.

---

## 24. TxPool and base fee

The pool tracks the current chain base fee.

Effective pricing:

```text
Legacy:
effectiveGasPrice = gasPrice
```

Dynamic fee:

```text
effectiveGasPrice =
    min(
        maxFeePerGas,
        maxPriorityFeePerGas + baseFee
    )
```

The effective price is used for txpool admission and ordering behavior.

---

## 25. Transaction replacement

Same-sender / same-nonce replacement requires an economically better replacement.

An underpriced replacement is rejected.

Operationally:

```text
same sender
+
same nonce
+
higher effective fee
```

is the normal replacement pattern.

Clients should not repeatedly resubmit the same nonce at the same or lower effective price.

---

# Bridge Compatibility RPC

## 26. `bridge_*` namespace

`v3.1.1` registers a `bridge` namespace.

Implemented methods:

```text
bridge_generateExitProof
bridge_getStateSyncProof
```

These endpoints belong to the node's bridge/state-sync compatibility surface.

They must not be confused with the current native XGR Hyperlane-based interchain route.

---

## 27. `bridge_generateExitProof`

Go endpoint:

```text
GenerateExitProof(exitID)
```

JSON-RPC name:

```text
bridge_generateExitProof
```

Parameter:

```text
exit event ID
```

The node delegates proof creation to the underlying bridge store.

Availability depends on the relevant bridge/state-sync implementation and local data.

---

## 28. `bridge_getStateSyncProof`

Go endpoint:

```text
GetStateSyncProof(stateSyncID)
```

JSON-RPC name:

```text
bridge_getStateSyncProof
```

Parameter:

```text
state sync ID
```

This endpoint retrieves a state-sync proof from the bridge store.

---

## 29. `bridge_*` versus XGR Interchain

Do not equate:

```text
bridge_*
```

with:

```text
XGRChain ↔ Base native Interchain
```

The current native XGR Interchain stack uses separate:

- router contracts,
- Hyperlane-compatible messaging,
- BLS attestations,
- Merkle checkpoints,
- Interchain Security Modules,
- relayer infrastructure.

The `bridge_*` namespace remains a separate compatibility surface inherited from the node architecture.

---

# XGR-specific RPC

## 30. `xgr_*` namespace

The node registers an `xgr` endpoint in both:

```text
stub mode
```

and:

```text
embedded-engine mode
```

Default public node behavior is stub mode unless an embedded engine build and configuration are explicitly used.

Environment mode selection is based on:

```text
XGR_ENGINE_MODE
```

with backwards compatibility for:

```text
XGR_ENGINE=on/off
```

A standard public build does not require an embedded private engine.

---

## 31. Public stub methods

The normal public build provides methods including:

```text
xgr_getPublicSale
xgr_getCoreAddrs
xgr_getNextProcessId
```

as lightweight public/stub functionality.

It also registers engine-backed method names such as:

```text
xgr_validateDataTransfer
xgr_getCirculatingSupply
xgr_estimateRuleGas
xgr_wakeUpProcess
xgr_control
xgr_listSessions
xgr_stepExecuted
xgr_sessionAlive
xgr_manageGrants
xgr_listGrants
xgr_getGrantFeePerYear
xgr_getXRC137Meta
xgr_getEncryptedLogInfo
xgr_encryptXRC137
```

In a normal non-embedded public build, those engine-dependent calls return:

```text
xgr engine is disabled (stub mode)
```

Therefore:

> Method registration does not imply active embedded-engine functionality.

---

## 32. `xgr_getNextProcessId`

The public stub exposes:

```text
xgr_getNextProcessId
```

Request object:

```json
{
  "owner": "0x<address>"
}
```

Response shape:

```json
{
  "owner": "0x<normalized-address>",
  "next": "0x1"
}
```

In public stub mode this is intentionally lightweight fallback behavior.

Applications that depend on actual engine process orchestration must use the corresponding active XGR service architecture rather than interpreting stub behavior as a full process engine.

---

## 33. `xgr_getCoreAddrs`

The public stub returns configured XGR core-address information including:

```text
grants
publicSale
precompile
chainId
```

The values can depend on:

- environment configuration,
- build mode,
- active deployment.

Do not hard-code optional service addresses based solely on one node instance's result.

---

# Native Interchain Attestation RPC

## 34. `xgr_getInterchainAttestation`

`v3.1.1` adds a native XGR interchain operator/read interface.

Method:

```text
xgr_getInterchainAttestation
```

Purpose:

> Return the latest completed native XGR interchain checkpoint attestation for one configured route.

The method is explicitly read-only.

It does **not** trigger BLS signing.

Conceptual request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "xgr_getInterchainAttestation",
  "params": ["base"]
}
```

The route name is normalized to lowercase.

Allowed route-name characters are:

```text
letters
digits
-
_
```

---

## 35. Latest attestation storage

For a route such as:

```text
base
```

the node reads:

```text
<data-dir>/interchain/attestations/base/latest.json
```

Maximum accepted attestation file size:

```text
1 MiB
```

The RPC does not generate a new attestation based on the request.

It only exposes an already completed locally stored attestation.

---

## 36. Interchain attestation response

Current response fields include:

| Field | Meaning |
| --- | --- |
| `version` | Attestation format version |
| `chain` | Configured route |
| `destination` | Destination identifier where present |
| `originChainId` | Origin EVM chain ID |
| `originDomain` | Origin messaging domain |
| `destinationDomain` | Destination messaging domain |
| `setId` | Interchain validator-set ID |
| `mailbox` | Mailbox address |
| `merkleTreeHook` | Merkle Tree Hook address |
| `root` | Checkpoint Merkle root |
| `index` | Checkpoint index |
| `payload` | Signed attestation payload |
| `signerBitmap` | Participating validator bitmap |
| `aggregateSignature` | Aggregate BLS signature |
| `aggregateSignatureCompressed` | Compressed aggregate signature |

The attestation must contain at least:

```text
chain
root
payload
aggregateSignature
```

or it is considered incomplete.

---

## 37. `xgr_getInterchainAttestationByCheckpoint`

Method:

```text
xgr_getInterchainAttestationByCheckpoint
```

Parameters:

```text
chain
setID
index
root
```

Conceptual request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "xgr_getInterchainAttestationByCheckpoint",
  "params": [
    "base",
    3,
    12,
    "0x<32-byte-root>"
  ]
}
```

Validation includes:

```text
setID != 0
```

and:

```text
root = 32-byte 0x-prefixed hexadecimal hash
```

The node reads the exact archived checkpoint-attestation file.

---

## 38. Archived attestation path

The file name follows:

```text
<setID>-<index>-<root>.json
```

under:

```text
<data-dir>/interchain/attestations/<route>/
```

Example structure:

```text
/var/lib/xgr/validator/
└── interchain/
    └── attestations/
        └── base/
            ├── latest.json
            └── <setID>-<index>-<root>.json
```

These files are local operator/interchain state.

They are not canonical XGRChain consensus state.

---

## 39. Interchain RPC trust boundary

The attestation RPC is intentionally read-only.

A remote caller cannot use:

```text
xgr_getInterchainAttestation
```

to cause a validator to sign arbitrary caller-provided content.

Signing is performed by the validator worker against canonical internally derived data.

The RPC only exposes completed output.

This boundary is important:

```text
RPC input
≠ signing instruction
```

---

## 40. Interchain attestation RPC and relayers

A relayer can request:

```text
latest attestation
```

or:

```text
specific checkpoint attestation
```

and use it as input to its destination verification/submission flow.

The RPC itself:

- does not submit destination transactions,
- does not unlock XGR,
- does not mint wXGR,
- does not change validator membership,
- does not alter XGRChain consensus.

Those operations belong to separate interchain components.

---

# gRPC Operator Services

## 41. gRPC bind

The node exposes internal gRPC services.

Runtime control:

```text
--grpc-address
```

Recommended validator/full-node bind:

```text
127.0.0.1:9632
```

Do not expose operator gRPC unrestricted to the public internet.

---

## 42. System gRPC service

`v3.1.1` defines:

```text
service System
```

with:

```text
GetStatus
PeersAdd
PeersList
PeersStatus
Subscribe
BlockByNumber
Export
```

These methods are intended for node tooling and operations.

---

## 43. `GetStatus`

Returns information including:

```text
network
genesis
current block number
current block hash
P2P address
```

This is useful for local operator health checks.

---

## 44. Peer gRPC methods

Methods:

```text
PeersAdd
PeersList
PeersStatus
```

support:

- adding a peer,
- listing known/connected peers,
- inspecting peer protocol/address state.

Peer management does not grant validator authority.

---

## 45. `Subscribe`

The System service can stream blockchain events.

Events contain added and removed headers.

This is useful for internal tooling that needs chain-head event streams without relying on public WebSocket RPC.

---

## 46. `BlockByNumber`

Returns serialized block data by block number.

This is an operator/internal interface rather than the normal application block API.

For ordinary application integration use:

```text
eth_getBlockByNumber
```

instead.

---

## 47. `Export`

Streams blockchain export data for a requested range.

This should be treated as an operator function.

It can involve substantial I/O and should not be publicly exposed without a deliberate infrastructure design.

---

## 48. TxPool gRPC service

The txpool module also registers operator gRPC support.

This is intended for:

- CLI tooling,
- internal diagnostics,
- node operation.

Use the JSON `txpool_*` methods for simple inspection where appropriate.

Keep the gRPC operator endpoint private.

---

## 49. Consensus gRPC services

Consensus-specific services are registered by the active consensus implementation.

For example:

```text
xgrchain ibft status
```

uses gRPC to inspect local validator identity/status.

These interfaces are:

```text
operator/internal
```

rather than normal dApp APIs.

---

# WebSocket Operator Considerations

## 50. WebSocket subscriptions

Supported subscription categories include:

```text
newHeads
logs
newPendingTransactions
```

through:

```text
eth_subscribe
```

Subscription state is connection-local.

After disconnect:

```text
client must subscribe again
```

---

## 51. Pending-transaction subscription

```text
newPendingTransactions
```

can become high-volume.

Public deployment should account for:

- connection count,
- outbound bandwidth,
- client backpressure,
- memory,
- RPC abuse.

A dedicated event/indexing service may be preferable for large-scale downstream consumers.

---

# Security

## 52. Recommended exposure policy

| Surface | Exposure |
| --- | --- |
| `eth_*` | Public with rate limits |
| `net_*` | Public with rate limits |
| `web3_*` | Public with rate limits |
| PoS read-only `eth_*` | Public if intentionally supported |
| `txpool_*` | Internal / restricted |
| `debug_*` | Internal only |
| `bridge_*` | Internal/use-case-specific |
| XGR read-only public methods | Method-specific |
| XGR engine-control methods | Not public in normal architecture |
| Interchain attestation read RPC | Trusted relayer/operator or deliberately controlled |
| gRPC | Internal only |
| Metrics | Monitoring network |

---

## 53. Public RPC node

A public RPC node should normally:

- run `--seal=false`,
- contain no validator keys,
- bind node RPC locally,
- use a TLS reverse proxy,
- rate-limit requests,
- limit JSON batches,
- limit log ranges,
- restrict debug,
- restrict txpool,
- keep gRPC private,
- explicitly define historical-state retention.

---

## 54. Tracing node

A dedicated internal tracing node should normally:

- retain sufficient historical state,
- keep Trie Sweeper disabled if full archive tracing is required,
- expose `debug_*` only internally,
- use request concurrency limits,
- monitor CPU/memory/I/O,
- avoid serving unrestricted public traffic.

---

## 55. Validator node

A validator should prioritize:

```text
consensus reliability
```

over:

```text
diagnostic workload
```

Recommended:

- JSON-RPC local/private,
- gRPC local/private,
- no unrestricted public debug,
- no large public txpool inspection,
- no heavy historical tracing,
- validator keys isolated,
- interchain credentials isolated appropriately,
- disk and state-retention policy monitored.

---

# Troubleshooting

## 56. RPC returns method not found

Check:

- namespace spelling,
- method spelling,
- node version,
- build mode,
- whether method belongs to a separate service,
- whether the endpoint is available in the current release.

Examples:

```text
xgr_* engine method
```

may be registered but return an engine-disabled error in stub mode.

That is different from:

```text
method not found
```

---

## 57. XGR method says engine disabled

Expected on a public stub build for engine-backed calls:

```text
xgr engine is disabled (stub mode)
```

This does not mean standard XGRChain operation is broken.

It means the requested RPC belongs to the optional embedded-engine layer.

---

## 58. Interchain attestation not found

Possible causes:

- route not configured,
- validator worker not producing attestations,
- no completed checkpoint yet,
- wrong data directory,
- wrong route name,
- requested archived checkpoint does not exist.

Expected error:

```text
interchain attestation not found
```

Check:

```text
<data-dir>/interchain/attestations/<route>/
```

---

## 59. Debug trace fails for an old transaction

Check:

- block exists,
- transaction lookup exists,
- requested state is still retained,
- Trie Sweeper policy,
- node storage health.

A pruned node may be unable to reconstruct execution even though:

```text
eth_getTransactionReceipt
```

still succeeds.

---

## 60. TxPool transaction not visible

Possible reasons:

- rejected before admission,
- already mined,
- replaced,
- dropped under pressure,
- submitted to another RPC backend,
- future nonce,
- insufficient effective fee.

Check:

```text
txpool_status
txpool_content
eth_getTransactionByHash
eth_getTransactionCount
```

---

## 61. TxPool pressure

Check:

```text
currentCapacity
maxCapacity
pending
queued
```

Possible mitigations:

- identify abusive accounts,
- inspect future-nonce queues,
- rate-limit RPC,
- tune pool size carefully,
- ensure adequate memory,
- investigate underpriced spam.

---

## 62. Debug request limit exceeded

Error:

```text
request limit exceeded
```

means all configured debug concurrency slots remained unavailable for the throttling wait period.

Possible actions:

- reduce trace concurrency,
- use dedicated tracing infrastructure,
- increase the limit only after capacity analysis.

Do not simply raise it on validators.

---

## 63. RPC latency high

Investigate:

- debug load,
- large log ranges,
- large batches,
- txpool inspection,
- WebSocket subscriptions,
- historical-state reads,
- Trie Sweeper / LevelDB compaction,
- CPU,
- memory,
- disk I/O.

A slow RPC endpoint does not necessarily imply slow consensus.

---

## 64. Operator quick reference

| Task | Method/interface |
| --- | --- |
| Current block | `eth_blockNumber` |
| Peers | `net_peerCount` |
| Node version | `web3_clientVersion` |
| TxPool counts | `txpool_status` |
| TxPool detail | `txpool_content` |
| TxPool compact view | `txpool_inspect` |
| Trace transaction | `debug_traceTransaction` |
| Trace block | `debug_traceBlockByNumber` |
| Trace call | `debug_traceCall` |
| Legacy exit proof | `bridge_generateExitProof` |
| Legacy state-sync proof | `bridge_getStateSyncProof` |
| Next process ID stub | `xgr_getNextProcessId` |
| Latest interchain attestation | `xgr_getInterchainAttestation` |
| Exact checkpoint attestation | `xgr_getInterchainAttestationByCheckpoint` |
| Node operator status | gRPC `System.GetStatus` |
| Peer administration | gRPC `PeersAdd/List/Status` |
| Blockchain event stream | gRPC `System.Subscribe` |
| Local IBFT status | IBFT gRPC / `xgrchain ibft status` |

---

## 65. `v3.1.1` operator-interface summary

| Area | Current behavior |
| --- | --- |
| Standard JSON-RPC | Active |
| TxPool RPC | Active |
| Debug RPC | Active |
| Bridge compatibility RPC | Registered |
| XGR namespace | Registered |
| Public engine mode | Stub by default |
| `xgr_getNextProcessId` | Available in public stub |
| Engine-dependent XGR RPC | Registered but disabled in stub mode |
| Native Interchain attestation RPC | Active |
| Latest attestation lookup | `xgr_getInterchainAttestation` |
| Exact checkpoint lookup | `xgr_getInterchainAttestationByCheckpoint` |
| Attestation RPC signing side effect | None |
| gRPC System service | Active |
| Debug concurrency default | `32` |
| TxPool max slots default | `4096` |
| TxPool per-account queue default | `128` |
| Historical tracing on pruned node | Retention-dependent |

---

## 66. Design principle

Operator interfaces expose powerful node-local functionality.

They should be separated according to purpose:

```text
application RPC
       │
       ├── eth
       ├── net
       └── web3

operator diagnostics
       │
       ├── txpool
       ├── debug
       └── gRPC

XGR-specific integration
       │
       ├── public/stub xgr methods
       ├── native interchain attestation RPC
       └── optional embedded-engine methods

compatibility interfaces
       │
       └── bridge
```

A registered method is not automatically a public API.

A registered stub is not automatically an active engine.

An operator endpoint is not consensus authority.

A read-only interchain attestation request is not a signing request.

Keeping these boundaries explicit is essential for secure XGRChain infrastructure.
