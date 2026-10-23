# XGR Chain — Ethereum JSON-RPC Reference

**Document ID:** XGRCHAIN-ETH-RPC  
**Last updated:** 2026-10-03  
**Audience:** Wallet developers, explorer developers, dApp developers, node operators, infrastructure integrators  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Standard Ethereum-compatible JSON-RPC exposed by XGRChain

---

## 1. Purpose

This document describes the standard Ethereum-compatible JSON-RPC surface exposed by XGRChain.

It covers the compatibility layer used by:

- wallets,
- explorers,
- indexers,
- dApps,
- scripts,
- infrastructure tools,
- monitoring systems.

The primary namespaces covered are:

```text
eth_*
net_*
web3_*
```

XGR-specific extension methods, including PoS/operator endpoints, are documented separately and should not be treated as part of the generic Ethereum compatibility surface.

---

## 2. JSON-RPC protocol

XGRChain uses JSON-RPC 2.0.

Example request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_chainId",
  "params": []
}
```

Example response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x66b"
}
```

Error response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "..."
  }
}
```

Applications must not assume every error uses the same code. Individual RPC methods may return implementation-specific validation or execution errors.

---

## 3. Encoding rules

Unless stated otherwise:

| Type | Encoding |
| --- | --- |
| Quantity | Hex string with `0x` prefix |
| Byte array | Hex string with `0x` prefix |
| Address | 20-byte hexadecimal value |
| Hash | 32-byte hexadecimal value |
| Missing object | `null` |
| Boolean | JSON boolean |
| Array | JSON array |

Examples:

```text
0              -> "0x0"
1643           -> "0x66b"
100 gwei       -> "0x174876e800"
```

Ethereum quantity values must not be returned as decimal strings unless the method explicitly specifies a decimal-string representation, as `net_version` does.

---

## 4. Chain identity

XGRChain mainnet uses:

```text
chainId = 1643
```

Hexadecimal:

```text
0x66b
```

The chain ID is part of the transaction signing domain.

Clients must verify the chain ID before signing transactions.

---

## 5. Block selectors

Several `eth_*` methods accept a block selector.

Supported forms include:

```text
"latest"
"pending"
"earliest"
"0x<blockNumber>"
```

Depending on the method, block-hash selectors are also supported.

| Selector | Meaning |
| --- | --- |
| `latest` | Current canonical head known by the node |
| `pending` | Pending/latest context where supported |
| `earliest` | Genesis |
| `0x...` | Explicit block number |

A request for an unknown block may return either `null` or an RPC error depending on the method.

---

## 6. Ethereum compatibility notes

XGRChain supports normal EVM wallet and tooling workflows.

Supported areas include:

- EIP-155 chain-ID protection,
- legacy transactions,
- access-list transactions,
- dynamic-fee transactions,
- contract creation,
- contract calls,
- native XGR transfers,
- event logs,
- transaction receipts,
- raw signed transaction submission,
- gas estimation,
- block and transaction lookup,
- state queries,
- WebSocket subscriptions when WebSocket RPC is enabled.

Important `v3.1.1` behavior:

1. `eth_sendTransaction` is intentionally unsupported.
2. The node does not manage user private keys through JSON-RPC.
3. Transactions must normally be signed client-side and submitted through `eth_sendRawTransaction`.
4. `eth_gasPrice` returns the latest block header base fee.
5. `eth_maxPriorityFeePerGas` returns `0`.
6. For RPC simulation, missing dynamic-fee fields are filled with:
   - `maxPriorityFeePerGas = 0`
   - `maxFeePerGas = 2 × baseFee`
7. Missing legacy `gasPrice` is filled with the current base fee.
8. XGR-specific fee distribution must not be inferred from Ethereum mainnet fee-distribution assumptions.

---

## 7. Endpoint index

### 7.1 `eth_*`

| Method | Purpose |
| --- | --- |
| `eth_chainId` | Return chain ID |
| `eth_syncing` | Return synchronization state |
| `eth_blockNumber` | Return local canonical head number |
| `eth_getBlockByNumber` | Return block by block number/tag |
| `eth_getBlockByHash` | Return block by hash |
| `eth_getBlockTransactionCountByNumber` | Return transaction count for selected block |
| `eth_getBalance` | Return account balance |
| `eth_getTransactionCount` | Return account nonce |
| `eth_getCode` | Return contract bytecode |
| `eth_getStorageAt` | Return storage-slot value |
| `eth_sendRawTransaction` | Submit signed transaction |
| `eth_sendTransaction` | Unsupported |
| `eth_getTransactionByHash` | Return transaction by hash |
| `eth_getTransactionReceipt` | Return transaction receipt |
| `eth_call` | Execute read-only local call |
| `eth_estimateGas` | Estimate transaction gas |
| `eth_gasPrice` | Return current legacy gas-price suggestion |
| `eth_maxPriorityFeePerGas` | Return priority-fee suggestion |
| `eth_feeHistory` | Return fee-history data |
| `eth_getLogs` | Query event logs |
| `eth_newFilter` | Create log filter |
| `eth_newBlockFilter` | Create block filter |
| `eth_getFilterLogs` | Return logs for filter |
| `eth_getFilterChanges` | Return filter changes |
| `eth_uninstallFilter` | Delete filter |
| `eth_subscribe` | Create WebSocket subscription |
| `eth_unsubscribe` | Cancel WebSocket subscription |

XGR-specific PoS methods under the `eth_*` namespace are documented separately.

---

### 7.2 `net_*`

| Method | Purpose |
| --- | --- |
| `net_version` | Return chain/network ID as decimal string |
| `net_listening` | Report listening state |
| `net_peerCount` | Return connected peer count |

---

### 7.3 `web3_*`

| Method | Purpose |
| --- | --- |
| `web3_clientVersion` | Return node client/version string |
| `web3_sha3` | Return Keccak-256 hash |

---

## 8. `eth_chainId`

Returns the configured EIP-155 chain ID.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_chainId",
  "params": []
}
```

### XGRChain mainnet response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x66b"
}
```

Equivalent decimal value:

```text
1643
```

Wallets must use this chain ID when signing XGRChain transactions.

---

## 9. `net_version`

Returns the configured network/chain identifier as a decimal string.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "net_version",
  "params": []
}
```

### Mainnet response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "1643"
}
```

---

## 10. Synchronization and head state

### `eth_syncing`

Returns node synchronization state.

When synchronized:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": false
}
```

While bulk synchronization is active, the response can contain:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "type": "bulk",
    "startingBlock": "0x1",
    "currentBlock": "0x100",
    "highestBlock": "0x200"
  }
}
```

Fields:

| Field | Meaning |
| --- | --- |
| `type` | Active sync mode |
| `startingBlock` | Starting block of the current sync |
| `currentBlock` | Current synchronized height |
| `highestBlock` | Highest known synchronization target |

---

### `eth_blockNumber`

Returns the local node's latest canonical block number.

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x1234"
}
```

This is local node state.

A stale or partitioned node can therefore return a block number below the actual network head.

For operational health checks, combine:

```text
eth_blockNumber
net_peerCount
```

with external head comparison where appropriate.

---

## 11. Block lookup

### `eth_getBlockByNumber`

Parameters:

```json
[
  "latest",
  false
]
```

| Position | Type | Meaning |
| ---: | --- | --- |
| `0` | block selector | Block number or tag |
| `1` | boolean | Return full transaction objects if `true` |

Returns a block object or `null`.

Important fields include:

- `number`
- `hash`
- `parentHash`
- `sha3Uncles`
- `miner`
- `stateRoot`
- `transactionsRoot`
- `receiptsRoot`
- `logsBloom`
- `difficulty`
- `totalDifficulty`
- `size`
- `gasLimit`
- `gasUsed`
- `timestamp`
- `extraData`
- `mixHash`
- `nonce`
- `baseFeePerGas`
- `transactions`
- `uncles`

XGRChain consensus-specific header information is represented through the normal block object where applicable, but applications should not rely on undocumented IBFT extra-data offsets.

---

### `eth_getBlockByHash`

Parameters:

```json
[
  "0x<blockHash>",
  false
]
```

Returns a block object or `null`.

---

### `eth_getBlockTransactionCountByNumber`

Returns the transaction count of a selected block.

Example request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getBlockTransactionCountByNumber",
  "params": ["latest"]
}
```

Example response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x5"
}
```

If the block cannot be found, the result is `null`.

---

## 12. Account and contract state

### `eth_getBalance`

Returns account balance at the selected state root.

Parameters:

```json
[
  "0x<address>",
  "latest"
]
```

Result is returned as a hexadecimal quantity in wei.

If the account does not exist, the result is:

```text
0x0
```

---

### `eth_getTransactionCount`

Returns the nonce for the account.

Parameters:

```json
[
  "0x<address>",
  "latest"
]
```

For `pending`, the result can use txpool-aware nonce state.

If the account does not exist, the result is:

```text
0x0
```

---

### `eth_getCode`

Returns EVM bytecode stored for an address.

Parameters:

```json
[
  "0x<address>",
  "latest"
]
```

For an EOA or empty account:

```text
0x
```

Note that native protocol precompiles do not require deployed EVM bytecode.

For example, absence of bytecode at a precompile address does not imply that the protocol functionality is unavailable.

---

### `eth_getStorageAt`

Returns a raw storage slot.

Parameters:

```json
[
  "0x<contractAddress>",
  "0x0",
  "latest"
]
```

Missing storage returns the zero hash:

```text
0x0000000000000000000000000000000000000000000000000000000000000000
```

---

## 13. Historical-state availability and trie pruning

Historical block availability and historical EVM-state availability are separate concepts on XGRChain.

When the Online State Trie Sweeper is enabled, old trie state beyond the configured retention window may be reclaimed.

This can affect historical requests such as:

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
eth_estimateGas
```

when they reference sufficiently old blocks.

For example, a node may still successfully return:

```text
eth_getBlockByNumber
eth_getBlockByHash
eth_getTransactionReceipt
eth_getLogs
```

for an older canonical block while no longer retaining the complete historical EVM state root required for an old `eth_call`.

Therefore:

> A normal pruned/full node must not be treated as an unrestricted archive-state RPC endpoint.

Applications requiring arbitrary historical-state access should use a node operated with an appropriate archive-style retention policy.

State-retention behavior is documented in:

```text
docs/chain/XGRCHAIN_State_Storage_and_Retention.md
```

---

## 14. Transaction submission

### `eth_sendRawTransaction`

Submits a locally signed transaction.

Parameters:

```json
[
  "0x<signedRawTransaction>"
]
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x<transactionHash>"
}
```

The node still performs txpool admission checks.

A submitted transaction can be rejected for reasons including:

- invalid signature,
- wrong chain ID,
- invalid nonce,
- insufficient balance,
- insufficient intrinsic gas,
- unsupported transaction type,
- insufficient fee,
- replacement rules,
- txpool limits.

Submission to one node does not itself mean that the transaction has been finalized.

---

### `eth_sendTransaction`

Unsupported.

XGRChain does not expose node-managed user wallets through JSON-RPC.

The endpoint returns an error directing the caller to:

```text
eth_sendRawTransaction
```

Applications should:

1. construct the transaction,
2. sign it using the user's wallet or signer,
3. submit the signed bytes.

---

## 15. Transaction lookup

### `eth_getTransactionByHash`

The node checks:

1. canonical transaction lookup,
2. local pending txpool state.

A pending transaction can therefore be returned before it has a canonical block association.

Important fields include:

- `hash`
- `nonce`
- `blockHash`
- `blockNumber`
- `transactionIndex`
- `from`
- `to`
- `value`
- `gas`
- `gasPrice`
- `maxPriorityFeePerGas`
- `maxFeePerGas`
- `input`
- `accessList`
- `chainId`
- `type`
- `v`
- `r`
- `s`

For pending transactions:

```text
blockHash
blockNumber
transactionIndex
```

may be `null`.

---

### `eth_getTransactionReceipt`

Returns a receipt for a mined transaction.

Important fields:

| Field | Meaning |
| --- | --- |
| `transactionHash` | Transaction hash |
| `transactionIndex` | Position in block |
| `blockHash` | Containing block |
| `blockNumber` | Containing block number |
| `from` | Sender |
| `to` | Recipient |
| `contractAddress` | Created contract, if applicable |
| `cumulativeGasUsed` | Cumulative block gas through this transaction |
| `gasUsed` | Gas used by transaction |
| `logs` | Event logs |
| `logsBloom` | Receipt bloom |
| `status` | Execution status |
| `type` | Transaction type |

Unknown or pending transactions return:

```text
null
```

---

## 16. Transaction types

XGRChain supports:

| Transaction | Code |
| --- | --- |
| Legacy | `0x00` |
| Access-list | `0x01` |
| Dynamic fee | `0x02` |

The node also uses an internal:

```text
StateTx = 0x7f
```

for protocol-level system execution.

`StateTx` is not intended as a normal wallet-submitted transaction type.

---

## 17. `eth_call`

`eth_call` executes an EVM call locally without modifying canonical chain state.

Typical parameters:

```json
[
  {
    "from": "0x<sender>",
    "to": "0x<target>",
    "value": "0x0",
    "data": "0x<calldata>"
  },
  "latest"
]
```

An optional state-override object is supported.

State overrides can modify simulation context including:

- balance,
- nonce,
- code,
- storage,
- storage differences.

A revert returns an RPC error together with revert data where available.

### Simulation nonce behavior

For simulation calls, `v3.1.1` aligns a default/zero transaction nonce with the referenced state when required.

This avoids failures caused by differences between txpool nonce state and the selected canonical state during simulation.

---

## 18. `eth_estimateGas`

Estimates the minimum gas required for a transaction-like call.

Example:

```json
[
  {
    "from": "0x<sender>",
    "to": "0x<target>",
    "value": "0x0",
    "data": "0x<calldata>"
  }
]
```

If no block number is provided:

```text
latest
```

is used.

Important `v3.1.1` behavior:

- simple EOA value transfers can use intrinsic gas directly,
- transfers to contract recipients are executed because `receive`/fallback code may consume additional gas,
- contract execution uses binary search to determine the gas requirement,
- a supplied `gas` value may act as the upper bound,
- otherwise the referenced block gas limit is used,
- available sender balance can reduce the usable gas ceiling,
- EVM reverts are returned as errors,
- insufficient funds can prevent estimation.

Therefore:

```text
21000
```

must not be assumed for every empty-calldata value transfer.

A contract recipient can execute code even when transaction calldata is empty.

---

## 19. Gas-price suggestion model in `v3.1.1`

The standard RPC-facing fee suggestion path is intentionally simple.

For the current block header:

```text
baseFee = latestHeader.BaseFee
```

The RPC suggestion function derives:

```text
tip      = 0
gasPrice = baseFee
feeCap   = 2 × baseFee
```

with saturated arithmetic for the multiplication.

This behavior is distinct from internal gas-price helper capabilities that may analyze historical transaction tips.

The public RPC endpoints described here use the deterministic suggestion path above.

---

## 20. `eth_gasPrice`

Current `v3.1.1` behavior:

```text
eth_gasPrice = latestHeader.BaseFee
```

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_gasPrice",
  "params": []
}
```

A result of:

```text
0x174876e800
```

equals:

```text
100000000000 wei
100 gwei
```

The actual value depends on the current XGRChain base fee.

---

## 21. `eth_maxPriorityFeePerGas`

Current `v3.1.1` RPC suggestion:

```text
0
```

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_maxPriorityFeePerGas",
  "params": []
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x0"
}
```

This is valid XGRChain behavior.

Wallet integrations must not reject XGRChain merely because the node suggests a zero priority fee.

---

## 22. Simulation fee defaults

When RPC simulation needs fee fields and the caller has omitted them, `v3.1.1` fills them deterministically.

### Dynamic-fee transaction

```text
maxPriorityFeePerGas = 0
maxFeePerGas         = 2 × baseFee
```

### Legacy transaction

```text
gasPrice = baseFee
```

Explicit client-supplied fields are preserved where valid.

These defaults primarily affect local simulation such as:

```text
eth_call
eth_estimateGas
```

They do not sign or broadcast a transaction for the user.

---

## 23. `eth_feeHistory`

Returns historical block fee information.

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_feeHistory",
  "params": [
    "0x5",
    "latest",
    [10, 50, 90]
  ]
}
```

Response fields:

| Field | Meaning |
| --- | --- |
| `oldestBlock` | Oldest returned block |
| `baseFeePerGas` | Base-fee sequence |
| `gasUsedRatio` | `gasUsed / gasLimit` |
| `reward` | Effective tip percentiles |

`v3.1.1` behavior includes:

- `blockCount` must be greater than zero,
- maximum processed block count is `1024`,
- a requested newest block above the local head is clamped to the current head,
- reward percentiles must be in `[0,100]`,
- percentiles must be non-decreasing,
- empty blocks return zero rewards for requested percentiles.

The implementation returns:

```text
blockCount + 1
```

entries in `baseFeePerGas`.

The final entry is populated from the node's current header base fee.

---

## 24. XGR-specific fee semantics

Ethereum-compatible RPC field names do not imply Ethereum mainnet economics.

XGRChain has its own:

- base-fee behavior,
- minimum-base-fee logic,
- PoS fee distribution,
- validator allocation,
- protocol fee handling.

For accounting or protocol integration, use the dedicated XGR gas and fee specification rather than assuming Ethereum's burn/tip distribution model.

---

## 25. Logs

### `eth_getLogs`

Queries canonical event logs.

Typical request:

```json
[
  {
    "fromBlock": "0x1",
    "toBlock": "latest",
    "address": "0x<contractAddress>",
    "topics": ["0x<topic0>"]
  }
]
```

Returned logs contain fields including:

- `address`
- `topics`
- `data`
- `blockNumber`
- `transactionHash`
- `transactionIndex`
- `blockHash`
- `logIndex`
- `removed`

Log queries can be constrained by the node's configured JSON-RPC block-range limit.

---

## 26. Filters

Supported filter operations include:

```text
eth_newFilter
eth_newBlockFilter
eth_getFilterLogs
eth_getFilterChanges
eth_uninstallFilter
```

Filters are node-local runtime objects.

A filter created on one RPC node should not be assumed to exist on another RPC node.

This matters when RPC traffic is load-balanced across multiple backends.

Infrastructure using polling filters should ensure session affinity or use an indexing architecture that does not rely on node-local filter IDs.

---

## 27. WebSocket subscriptions

When WebSocket RPC is enabled, the dispatcher supports:

```text
newHeads
logs
newPendingTransactions
```

through:

```text
eth_subscribe
```

Examples:

### New heads

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_subscribe",
  "params": ["newHeads"]
}
```

### Logs

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_subscribe",
  "params": [
    "logs",
    {
      "address": "0x<contractAddress>",
      "topics": []
    }
  ]
}
```

### Pending transactions

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_subscribe",
  "params": ["newPendingTransactions"]
}
```

Subscriptions are connection-local.

A disconnected WebSocket client must create a new subscription after reconnecting.

---

## 28. `eth_unsubscribe`

Cancels an active WebSocket subscription.

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_unsubscribe",
  "params": ["0x<subscriptionId>"]
}
```

Result:

```text
true
```

when the subscription/filter existed and was removed.

Unknown identifiers may return:

```text
false
```

---

## 29. Network methods

### `net_listening`

Returns whether the node reports itself as listening.

Current behavior returns:

```text
true
```

This does not prove that healthy peers are connected.

---

### `net_peerCount`

Returns current connected peer count as a hexadecimal quantity.

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "net_peerCount",
  "params": []
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x4"
}
```

Use peer count together with block progression for node-health monitoring.

---

## 30. `web3_clientVersion`

Returns the client build identification.

Shape:

```text
<chainName>/<version>/<os>-<architecture>/<goVersion>
```

For a tagged `v3.1.1` build, output is expected to follow a form similar to:

```text
xgrchain/v3.1.1/linux-amd64/go<runtime-version>
```

Exact output depends on:

- release metadata,
- build process,
- operating system,
- architecture,
- Go runtime.

Clients should not parse protocol capability solely from the version string.

---

## 31. `web3_sha3`

Computes Ethereum Keccak-256.

This is **Keccak-256**, not standardized SHA3-256.

Example request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "web3_sha3",
  "params": ["0x68656c6c6f"]
}
```

Example result:

```text
0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8
```

---

## 32. Dispatcher model

JSON-RPC method names follow:

```text
<namespace>_<method>
```

Examples:

```text
eth_chainId
net_peerCount
web3_clientVersion
```

The dispatcher:

1. identifies the namespace,
2. resolves the endpoint method,
3. decodes parameters,
4. invokes the method,
5. encodes the JSON-RPC result.

Unknown methods return a method-not-found error.

Not every namespace exposed by a particular node deployment should be treated as part of the public Ethereum compatibility contract.

---

## 33. Batch requests

JSON-RPC batching is supported.

Example:

```json
[
  {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "eth_chainId",
    "params": []
  },
  {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "eth_blockNumber",
    "params": []
  }
]
```

Relevant runtime limit:

```text
--json-rpc-batch-request-limit
```

Default in `v3.1.1`:

```text
20
```

Operators can configure a different value.

Clients should not assume arbitrarily large JSON-RPC batches will be accepted.

---

## 34. Block-range limits

Range-based RPC requests can be limited using:

```text
--json-rpc-block-range-limit
```

Default in `v3.1.1`:

```text
1000 blocks
```

This primarily protects expensive queries such as large `eth_getLogs` ranges.

Indexers should split historical queries into bounded ranges.

Public RPC infrastructure can apply additional reverse-proxy or application-level restrictions.

---

## 35. WebSocket read limit

The node defines a WebSocket message read limit.

Default in `v3.1.1`:

```text
8192 bytes
```

Requests exceeding the configured WebSocket read limit may cause the connection to be closed.

Large batch or payload-heavy requests should therefore normally use appropriately configured HTTP RPC infrastructure.

---

## 36. Public RPC and validator separation

Public RPC is an application interface.

Validator operation is a consensus function.

Production infrastructure should normally separate:

```text
public RPC nodes
```

from:

```text
validator nodes
```

A public RPC endpoint does not need validator signing material.

Validator private keys should never be exposed merely to provide standard Ethereum RPC.

---

## 37. Recommended client behavior

Clients should:

1. verify `eth_chainId == 0x66b`,
2. sign transactions locally,
3. use `eth_sendRawTransaction`,
4. estimate contract execution through `eth_estimateGas`,
5. treat a zero priority-fee suggestion as valid,
6. use current base fee when constructing transactions,
7. use `eth_getTransactionReceipt` for canonical inclusion,
8. use bounded `eth_getLogs` queries,
9. reconnect and recreate WebSocket subscriptions after connection loss,
10. handle `null` for unknown transactions, receipts and blocks,
11. distinguish block-history access from historical-state access,
12. not assume every RPC node is an archive node,
13. keep XGR-specific extension APIs separate from generic Ethereum RPC integrations.

---

## 38. Common integration mistakes

### 38.1 Calling `eth_sendTransaction`

Incorrect:

```text
eth_sendTransaction
```

Use:

```text
eth_sendRawTransaction
```

with client-side signing.

---

### 38.2 Requiring a non-zero priority fee

Current node suggestion:

```text
eth_maxPriorityFeePerGas = 0
```

This is intentional XGRChain behavior.

---

### 38.3 Treating the fee cap as actual cost

For a dynamic-fee transaction:

```text
effectiveGasPrice =
    min(maxFeePerGas,
        baseFee + maxPriorityFeePerGas)
```

The fee cap is a maximum, not necessarily the actual price paid.

---

### 38.4 Assuming an old block implies old state is available

A pruned node may retain:

```text
block
transaction
receipt
logs
```

while having reclaimed the old state trie.

Historical state-dependent RPC calls can therefore fail even though the block itself is still queryable.

---

### 38.5 Treating `net_listening` as network health

Use:

```text
net_peerCount
eth_blockNumber
```

and external monitoring instead.

---

### 38.6 Assuming every `eth_*` method is Ethereum-standard behavior

XGR-specific methods can exist inside the `eth_*` namespace.

For example, PoS monitoring extensions are documented separately.

Namespace prefix alone does not make an extension part of the generic Ethereum JSON-RPC specification.

---

### 38.7 Assuming precompiles have EVM bytecode

Protocol precompiles are implemented by the node.

Therefore:

```text
eth_getCode(precompileAddress)
```

can return:

```text
0x
```

even though execution at that address is handled natively by the protocol.

---

## 39. Quick reference

| Task | RPC |
| --- | --- |
| Chain ID | `eth_chainId` |
| Network ID | `net_version` |
| Sync state | `eth_syncing` |
| Current block | `eth_blockNumber` |
| Block by number | `eth_getBlockByNumber` |
| Block by hash | `eth_getBlockByHash` |
| Balance | `eth_getBalance` |
| Nonce | `eth_getTransactionCount` |
| Contract code | `eth_getCode` |
| Storage | `eth_getStorageAt` |
| Submit signed transaction | `eth_sendRawTransaction` |
| Transaction lookup | `eth_getTransactionByHash` |
| Receipt | `eth_getTransactionReceipt` |
| Read-only execution | `eth_call` |
| Gas estimate | `eth_estimateGas` |
| Gas-price suggestion | `eth_gasPrice` |
| Priority-fee suggestion | `eth_maxPriorityFeePerGas` |
| Fee history | `eth_feeHistory` |
| Logs | `eth_getLogs` |
| Create log filter | `eth_newFilter` |
| Create block filter | `eth_newBlockFilter` |
| Poll filter | `eth_getFilterChanges` |
| Remove filter | `eth_uninstallFilter` |
| WebSocket subscription | `eth_subscribe` |
| Peer count | `net_peerCount` |
| Client version | `web3_clientVersion` |
| Keccak-256 | `web3_sha3` |

---

## 40. Mainnet integration baseline

For standard application integration:

```text
Chain name: XGRChain
Chain ID:   1643
Chain ID:   0x66b
Native:     XGR
Decimals:   18
RPC model:  Ethereum JSON-RPC
Signing:    client-side
```

The active public node documentation baseline is:

```text
xgr-node v3.1.1
```

Applications requiring historical-state access must additionally establish the retention policy of the RPC endpoint they use.

Standard Ethereum RPC compatibility describes the interface.

It does not imply unrestricted archival storage, validator authority, or Ethereum mainnet fee economics.
