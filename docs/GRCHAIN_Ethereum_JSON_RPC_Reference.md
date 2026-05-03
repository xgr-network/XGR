# XGR Chain — Ethereum JSON-RPC Reference

**Document ID:** XGRCHAIN-ETH-RPC  
**Last updated:** 2026-05-03  
**Audience:** Wallet developers, explorer developers, node operators, integrators

---

## 1. Scope

This document describes the **standard Ethereum-compatible JSON-RPC surface** exposed by **XGR Chain**.

It covers the public compatibility layer used by wallets, explorers, scripts and infrastructure tools for:

- chain identity
- block and transaction lookup
- account and contract state reads
- raw transaction submission
- gas estimation and fee discovery
- logs, filters and WebSocket subscriptions
- basic `net_*` and `web3_*` compatibility methods

This document does **not** define XDaLa / Engine endpoints. Those are documented separately in:

- `../XDaLa_Engine_JSON_RPC_Endpoint_Reference.md`

This document also does **not** define PoS/staking-specific monitoring endpoints. Those should be documented separately under the chain documentation.

---

## 2. JSON-RPC envelope

All methods use JSON-RPC 2.0:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_chainId",
  "params": []
}
```

Unless noted otherwise:

- quantities are hex strings with `0x` prefix
- byte arrays are hex strings with `0x` prefix
- addresses are 20-byte hex strings
- hashes are 32-byte hex strings
- missing objects are returned as `null`

---

## 3. Compatibility notes

XGR Chain is EVM-compatible and supports standard Ethereum wallet flows:

- EIP-155 chain-id protected transactions
- legacy transactions
- EIP-1559 / type-2 transactions
- contract deployment and contract calls
- event logs and receipts
- `eth_sendRawTransaction` based submission

Important XGR-specific notes:

1. `eth_sendTransaction` is **not supported**. XGR nodes do not manage private keys. Clients must sign locally and submit via `eth_sendRawTransaction`.
2. `eth_gasPrice` returns the node's current effective gas price. XGR Chain uses its own modified EIP-1559 fee policy, including chain-level minimum base-fee behavior.
3. Priority fee behavior may differ from public Ethereum mainnet markets. Clients should not assume a non-zero tip is required unless the active node/network policy says so.
4. This reference intentionally documents the public compatibility surface, not internal debug, txpool or bridge namespaces.

---

## 4. Endpoint index

### 4.1 `eth_*`

| Method | Purpose |
|---|---|
| `eth_chainId` | Returns the active chain ID. |
| `eth_syncing` | Returns sync status or `false`. |
| `eth_blockNumber` | Returns the latest block number. |
| `eth_getBlockByNumber` | Returns a block by block number or tag. |
| `eth_getBlockByHash` | Returns a block by hash. |
| `eth_getBlockTransactionCountByNumber` | Returns the transaction count for a block number or tag. |
| `eth_getBalance` | Returns account balance at a block. |
| `eth_getTransactionCount` | Returns account nonce at a block. |
| `eth_getCode` | Returns contract bytecode at a block. |
| `eth_getStorageAt` | Returns storage slot value at a block. |
| `eth_sendRawTransaction` | Submits a signed raw transaction. |
| `eth_sendTransaction` | Unsupported; node-side wallet management is disabled. |
| `eth_getTransactionByHash` | Returns a transaction by hash. |
| `eth_getTransactionReceipt` | Returns a transaction receipt by hash. |
| `eth_call` | Executes a read-only simulation. |
| `eth_estimateGas` | Estimates gas for a transaction call object. |
| `eth_gasPrice` | Returns current effective gas price. |
| `eth_getLogs` | Returns logs matching a filter query. |
| `eth_newFilter` | Creates a log filter. |
| `eth_newBlockFilter` | Creates a block filter. |
| `eth_getFilterLogs` | Returns all logs for a filter. |
| `eth_getFilterChanges` | Returns filter changes since last poll. |
| `eth_uninstallFilter` | Removes a filter. |
| `eth_subscribe` | WebSocket subscription method. |
| `eth_unsubscribe` | Cancels a WebSocket subscription. |

### 4.2 `net_*`

| Method | Purpose |
|---|---|
| `net_version` | Returns the network ID as a decimal string. |
| `net_listening` | Returns whether the node is listening. |
| `net_peerCount` | Returns the number of connected peers. |

### 4.3 `web3_*`

| Method | Purpose |
|---|---|
| `web3_clientVersion` | Returns client/version string. |
| `web3_sha3` | Returns Keccak-256 hash of input data. |

---

## 5. Chain identity

## `eth_chainId`

Returns the active EIP-155 chain ID.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}
```

### Response

```json
"0x66b"
```

For XGR Chain main network configuration, `0x66b` equals decimal `1643`.

---

## `net_version`

Returns the network ID as a decimal string. On XGR Chain this follows the configured chain ID.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"net_version","params":[]}
```

### Response

```json
"1643"
```

---

## 6. Sync and head state

## `eth_syncing`

Returns node sync status.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_syncing","params":[]}
```

### Response

If the node is not syncing:

```json
false
```

If the node is syncing:

```json
{
  "type": "bulk",
  "startingBlock": "0x1",
  "currentBlock": "0x100",
  "highestBlock": "0x200"
}
```

---

## `eth_blockNumber`

Returns the latest block number known by the node.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}
```

### Response

```json
"0x1234"
```

---

## 7. Blocks

## `eth_getBlockByNumber`

Returns block data by block number or tag.

### Parameters

```json
[
  "latest",
  true
]
```

| Position | Type | Description |
|---|---|---|
| `0` | quantity or tag | Block number, `latest`, or supported block tag. |
| `1` | boolean | If `true`, returns full transaction objects; if `false`, only transaction hashes. |

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest",false]}
```

### Response

Returns a block object or `null`.

Important fields include:

- `number`
- `hash`
- `parentHash`
- `stateRoot`
- `transactionsRoot`
- `receiptsRoot`
- `miner`
- `gasLimit`
- `gasUsed`
- `timestamp`
- `baseFeePerGas` where applicable
- `transactions`

---

## `eth_getBlockByHash`

Returns block data by block hash.

### Parameters

```json
[
  "0x<blockHash>",
  false
]
```

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByHash","params":["0x<blockHash>",false]}
```

### Response

Returns a block object or `null`.

---

## `eth_getBlockTransactionCountByNumber`

Returns the number of transactions in a block selected by number or tag.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_getBlockTransactionCountByNumber","params":["latest"]}
```

### Response

```json
"0x0"
```

---

## 8. Account and contract state

## `eth_getBalance`

Returns account balance at a given block.

### Parameters

```json
[
  "0x<address>",
  "latest"
]
```

### Response

```json
"0x0"
```

---

## `eth_getTransactionCount`

Returns the account nonce at a given block.

### Parameters

```json
[
  "0x<address>",
  "latest"
]
```

### Response

```json
"0x1"
```

---

## `eth_getCode`

Returns contract bytecode at an address and block.

### Parameters

```json
[
  "0x<address>",
  "latest"
]
```

### Response

```json
"0x60806040..."
```

For externally owned accounts or empty addresses, the result is usually `"0x"`.

---

## `eth_getStorageAt`

Returns the raw value of a contract storage slot.

### Parameters

```json
[
  "0x<contractAddress>",
  "0x0",
  "latest"
]
```

### Response

```json
"0x0000000000000000000000000000000000000000000000000000000000000000"
```

---

## 9. Transactions

## `eth_sendRawTransaction`

Submits a locally signed raw transaction.

### Parameters

```json
[
  "0x<signedRawTransaction>"
]
```

### Response

```json
"0x<transactionHash>"
```

### Notes

- Clients must sign transactions locally.
- The transaction chain ID must match XGR Chain's configured chain ID.
- Both legacy and EIP-1559 / type-2 transaction formats are supported by the EVM compatibility layer.

---

## `eth_sendTransaction`

Unsupported.

XGR nodes do not expose wallet management through JSON-RPC. Use `eth_sendRawTransaction` instead.

### Response

A call to this method returns an error similar to:

```json
{
  "code": -32600,
  "message": "request calls to eth_sendTransaction method are not supported, use eth_sendRawTransaction instead"
}
```

---

## `eth_getTransactionByHash`

Returns a transaction by transaction hash.

### Parameters

```json
[
  "0x<transactionHash>"
]
```

### Response

Returns a transaction object or `null`.

Typical fields:

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
- `input`
- `v`, `r`, `s`

---

## `eth_getTransactionReceipt`

Returns the receipt for a mined transaction.

### Parameters

```json
[
  "0x<transactionHash>"
]
```

### Response

Returns a receipt object or `null` if the transaction is unknown or not yet mined.

Typical fields:

- `transactionHash`
- `transactionIndex`
- `blockHash`
- `blockNumber`
- `from`
- `to`
- `contractAddress`
- `cumulativeGasUsed`
- `gasUsed`
- `logs`
- `logsBloom`
- `status`

---

## 10. Execution and gas

## `eth_call`

Executes a call against the selected state without submitting a transaction.

### Parameters

```json
[
  {
    "from": "0x<optionalSender>",
    "to": "0x<target>",
    "gas": "0x5208",
    "gasPrice": "0x0",
    "value": "0x0",
    "data": "0x<calldata>"
  },
  "latest"
]
```

### Response

```json
"0x<returnData>"
```

---

## `eth_estimateGas`

Estimates the gas required to execute a transaction call object.

### Parameters

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

### Response

```json
"0x5208"
```

### Notes

- Estimation runs transaction execution locally against the selected block state.
- Reverting calls may return an error rather than a usable estimate.
- For contract recipients, fallback/receive logic is included in the estimate path.

---

## `eth_gasPrice`

Returns the current effective gas price in wei.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_gasPrice","params":[]}
```

### Response

```json
"0x3b9aca00"
```

### XGR note

XGR Chain uses a modified EIP-1559 fee policy. `eth_gasPrice` should be treated as the node's current effective gas price, not as proof of an Ethereum-mainnet-style priority-fee market.

---

## 11. Logs and filters

## `eth_getLogs`

Returns logs matching a filter query.

### Parameters

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

### Response

```json
[
  {
    "address": "0x<contractAddress>",
    "topics": ["0x<topic0>"],
    "data": "0x...",
    "blockNumber": "0x1234",
    "transactionHash": "0x<transactionHash>",
    "transactionIndex": "0x0",
    "blockHash": "0x<blockHash>",
    "logIndex": "0x0",
    "removed": false
  }
]
```

---

## `eth_newFilter`

Creates a log filter.

### Parameters

```json
[
  {
    "fromBlock": "latest",
    "toBlock": "latest",
    "address": "0x<contractAddress>",
    "topics": []
  }
]
```

### Response

```json
"0x1"
```

---

## `eth_newBlockFilter`

Creates a filter for new blocks.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_newBlockFilter","params":[]}
```

### Response

```json
"0x2"
```

---

## `eth_getFilterLogs`

Returns all logs matching an existing filter.

### Parameters

```json
[
  "0x1"
]
```

### Response

Returns an array of log objects.

---

## `eth_getFilterChanges`

Returns changes since the last poll for a filter.

### Parameters

```json
[
  "0x1"
]
```

### Response

- For log filters: array of log objects
- For block filters: array of block hashes
- If nothing changed: empty array

---

## `eth_uninstallFilter`

Removes a filter.

### Parameters

```json
[
  "0x1"
]
```

### Response

```json
true
```

---

## 12. WebSocket subscriptions

When WebSocket JSON-RPC is enabled, XGR Chain supports:

| Subscription | Description |
|---|---|
| `newHeads` | New block headers. |
| `logs` | Logs matching a filter query. |
| `newPendingTransactions` | Pending transaction notifications. |

## `eth_subscribe`

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_subscribe","params":["newHeads"]}
```

### Response

```json
"0x<subscriptionId>"
```

## `eth_unsubscribe`

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"eth_unsubscribe","params":["0x<subscriptionId>"]}
```

### Response

```json
true
```

---

## 13. Network methods

## `net_listening`

Returns whether the node is listening for network connections.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"net_listening","params":[]}
```

### Response

```json
true
```

---

## `net_peerCount`

Returns the number of connected peers.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}
```

### Response

```json
"0x3"
```

---

## 14. Web3 methods

## `web3_clientVersion`

Returns the node client/version string.

### Request

```json
{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}
```

### Response

```json
"xgrchain/v1.0.0/linux-amd64/go1.23"
```

Exact formatting depends on build metadata.

---

## `web3_sha3`

Returns the Keccak-256 hash of the given input data.

### Parameters

```json
[
  "0x68656c6c6f"
]
```

### Response

```json
"0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8"
```

Note: This is Ethereum Keccak-256, not standardized SHA3-256.

---

## 15. Explicit non-scope

The following namespaces are not part of this public standard compatibility reference:

| Namespace | Reason |
|---|---|
| `xgr_*` | XDaLa / Engine endpoints; documented separately. |
| PoS/staking monitoring endpoints | Chain-specific extension; should be documented in a dedicated staking/PoS endpoint reference. |
| `debug_*` | Operational/debug interface; not a public application compatibility surface. |
| `txpool_*` | Node-local mempool inspection; not required for normal wallet/explorer integration. |
| `bridge_*` | Legacy/bridge-specific surface; do not treat as core XGR Chain public API without a current bridge spec. |

---

## 16. Recommended client behavior

Clients should:

1. Use `eth_chainId` before signing transactions.
2. Sign locally and submit via `eth_sendRawTransaction`.
3. Use `eth_estimateGas` before contract execution.
4. Treat `eth_gasPrice` as XGR's current effective gas price.
5. Use `eth_getTransactionReceipt` to confirm transaction finality at application level.
6. Use `eth_getLogs` or WebSocket `logs` subscriptions for event-driven indexing.
7. Keep Engine/XDaLa calls separate from normal Ethereum JSON-RPC calls in code and documentation.
