# XGR Chain — Ethereum JSON-RPC Reference

**Document ID:** XGRCHAIN-ETH-RPC  
**Last updated:** 2026-05-03  
**Audience:** Wallet developers, explorer developers, dApp developers, node operators, infrastructure integrators  
**Implementation status:** Current public baseline  
**Source of truth:** Public `xgr-network/xgr-node` releases, active node JSON-RPC behavior, published XGR Chain configuration, and official XGR Network operator announcements

---

## 1. Purpose

This document describes the standard Ethereum-compatible JSON-RPC surface exposed by XGR Chain.

It covers the compatibility layer used by:

- wallets
- explorers
- indexers
- dApps
- scripts
- infrastructure tools
- monitoring systems

The scope is the standard `eth_*`, `net_*` and `web3_*` interface.

XGR-specific extension RPC methods use separate endpoint documentation and should not be mixed into this Ethereum JSON-RPC reference.

---

## 2. JSON-RPC envelope

All methods use JSON-RPC 2.0.

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_chainId",
  "params": []
}
```

Normal response shape:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x66b"
}
```

Error response shape:

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

---

## 3. Encoding rules

Unless noted otherwise:

| Type | Encoding |
|---|---|
| Quantity | Hex string with `0x` prefix |
| Byte array | Hex string with `0x` prefix |
| Address | 20-byte hex string with `0x` prefix |
| Hash | 32-byte hex string with `0x` prefix |
| Missing object | `null` |
| Boolean | JSON boolean |
| Array | JSON array |

Examples:

```text
0         -> "0x0"
1643      -> "0x66b"
100 gwei  -> "0x174876e800"
```

Do not encode quantities as decimal strings in `eth_*` responses.

---

## 4. Block selectors

Several methods accept a block selector.

Supported selector forms include:

```text
"latest"
"pending"
"earliest"
"0x<blockNumber>"
```

Meaning:

| Selector | Meaning |
|---|---|
| `latest` | Current canonical head known by the node |
| `pending` | Current pending/latest context where supported |
| `earliest` | Genesis block |
| `0x...` | Explicit block number |

For methods accepting block number or block hash, the request can use a block-number object or a block-hash object according to the method parameter type.

If a block/header cannot be found, the method may return `null` or an error depending on the endpoint.

---

## 5. Compatibility notes

XGR Chain is EVM-compatible and supports standard wallet flows.

Supported areas include:

- EIP-155 chain ID protected transactions
- legacy transactions
- access-list transactions where active by fork configuration
- dynamic fee / type-2 transactions
- contract deployment
- contract calls
- event logs
- receipts
- raw transaction submission
- gas estimation
- block and transaction lookup
- WebSocket subscriptions where WebSocket RPC is enabled

Important behavior:

1. `eth_sendTransaction` is intentionally unsupported.
2. XGR nodes do not manage private keys through JSON-RPC.
3. Clients must sign locally and submit with `eth_sendRawTransaction`.
4. `eth_gasPrice` currently returns the latest header base fee.
5. `eth_maxPriorityFeePerGas` currently returns `0`.
6. Dynamic-fee defaults use `maxPriorityFeePerGas = 0` and `maxFeePerGas = 2 × baseFee`.
7. XGR fee splitting is XGR-specific and should not be interpreted using Ethereum mainnet assumptions.

---

## 6. Endpoint index

### 6.1 `eth_*`

| Method | Purpose |
|---|---|
| `eth_chainId` | Returns the configured chain ID as a hex quantity |
| `eth_syncing` | Returns sync progress or `false` |
| `eth_blockNumber` | Returns the latest known block number |
| `eth_getBlockByNumber` | Returns block data by block number or tag |
| `eth_getBlockByHash` | Returns block data by block hash |
| `eth_getBlockTransactionCountByNumber` | Returns transaction count for a block number/tag |
| `eth_getBalance` | Returns account balance at a block |
| `eth_getTransactionCount` | Returns account nonce at a block |
| `eth_getCode` | Returns contract bytecode at a block |
| `eth_getStorageAt` | Returns storage slot value at a block |
| `eth_sendRawTransaction` | Submits a signed raw transaction |
| `eth_sendTransaction` | Unsupported; node-side wallet management is disabled |
| `eth_getTransactionByHash` | Returns a mined or pending transaction by hash |
| `eth_getTransactionReceipt` | Returns a mined transaction receipt |
| `eth_call` | Executes a local read-only simulation |
| `eth_estimateGas` | Estimates required gas for a transaction call object |
| `eth_gasPrice` | Returns current suggested legacy gas price |
| `eth_maxPriorityFeePerGas` | Returns current suggested priority fee |
| `eth_feeHistory` | Returns historical fee data |
| `eth_getLogs` | Returns logs matching a query |
| `eth_newFilter` | Creates a log filter |
| `eth_newBlockFilter` | Creates a block filter |
| `eth_getFilterLogs` | Returns all logs for an existing filter |
| `eth_getFilterChanges` | Returns changes since last filter poll |
| `eth_uninstallFilter` | Removes a filter |
| `eth_subscribe` | Creates a WebSocket subscription |
| `eth_unsubscribe` | Cancels a WebSocket subscription/filter |

### 6.2 `net_*`

| Method | Purpose |
|---|---|
| `net_version` | Returns the configured chain ID as a decimal string |
| `net_listening` | Returns whether the node reports itself as listening |
| `net_peerCount` | Returns connected peer count as a hex quantity |

### 6.3 `web3_*`

| Method | Purpose |
|---|---|
| `web3_clientVersion` | Returns client/version string |
| `web3_sha3` | Returns Keccak-256 hash of input data |

---

## 7. Chain identity

## `eth_chainId`

Returns the active EIP-155 chain ID as a hex quantity.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_chainId",
  "params": []
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x66b"
}
```

For the published XGR Chain mainnet configuration:

```text
0x66b = 1643
```

Clients must use this chain ID when signing transactions.

---

## `net_version`

Returns the configured chain ID as a decimal string.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "net_version",
  "params": []
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "1643"
}
```

For XGR Chain mainnet, `net_version` follows the configured chain ID.

---

## 8. Sync and head state

## `eth_syncing`

Returns node sync status.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_syncing",
  "params": []
}
```

### Response when not syncing

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": false
}
```

### Response when syncing

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

Field meaning:

| Field | Meaning |
|---|---|
| `type` | Sync mode/type |
| `startingBlock` | Start block of current sync progression |
| `currentBlock` | Current block reached by sync |
| `highestBlock` | Highest known target block |

---

## `eth_blockNumber`

Returns the latest block number known by the node.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_blockNumber",
  "params": []
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x1234"
}
```

This value is local to the node.

A node with poor peer connectivity or sync problems can return a stale block number.

---

## 9. Blocks

## `eth_getBlockByNumber`

Returns block data by block number or block tag.

### Parameters

```json
[
  "latest",
  false
]
```

| Position | Type | Required | Meaning |
|---:|---|---:|---|
| `0` | quantity or tag | yes | Block number, `latest`, `pending` or `earliest` |
| `1` | boolean | yes | If `true`, return full transaction objects; if `false`, return transaction hashes |

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getBlockByNumber",
  "params": ["latest", false]
}
```

### Response

Returns a block object or `null`.

Important block fields:

| Field | Meaning |
|---|---|
| `number` | Block number |
| `hash` | Block hash |
| `parentHash` | Parent block hash |
| `sha3Uncles` | Uncle hash field |
| `miner` | Block creator / coinbase field |
| `stateRoot` | State root |
| `transactionsRoot` | Transaction root |
| `receiptsRoot` | Receipts root |
| `logsBloom` | Logs bloom |
| `difficulty` | Difficulty field |
| `totalDifficulty` | Total difficulty compatibility field |
| `size` | Encoded block size |
| `gasLimit` | Block gas limit |
| `gasUsed` | Gas used by block |
| `timestamp` | Block timestamp |
| `extraData` | Filtered extra data |
| `mixHash` | Mix hash |
| `nonce` | Nonce field |
| `baseFeePerGas` | Header base fee |
| `transactions` | Transaction hashes or full transaction objects |
| `uncles` | Uncle hashes |

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

| Position | Type | Required | Meaning |
|---:|---|---:|---|
| `0` | hash | yes | Block hash |
| `1` | boolean | yes | If `true`, return full transaction objects; if `false`, return transaction hashes |

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getBlockByHash",
  "params": ["0x<blockHash>", false]
}
```

### Response

Returns a block object or `null`.

---

## `eth_getBlockTransactionCountByNumber`

Returns the number of transactions in a block selected by block number or tag.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getBlockTransactionCountByNumber",
  "params": ["latest"]
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x0"
}
```

If the block cannot be found, the method returns `null`.

---

## 10. Account and contract state

## `eth_getBalance`

Returns the balance of an address at a selected block.

### Parameters

```json
[
  "0x<address>",
  "latest"
]
```

| Position | Type | Required | Meaning |
|---:|---|---:|---|
| `0` | address | yes | Account or contract address |
| `1` | block selector | yes | Block number/tag or block hash selector |

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x0"
}
```

If the account does not exist, the result is `0x0`.

---

## `eth_getTransactionCount`

Returns the account nonce at a selected block.

### Parameters

```json
[
  "0x<address>",
  "latest"
]
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x1"
}
```

When the block selector is `pending`, the nonce can be read from the txpool-aware pending context.

If the account does not exist, the result is `0x0`.

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

### Response for a contract

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x60806040..."
}
```

### Response for an EOA or empty account

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x"
}
```

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

| Position | Type | Required | Meaning |
|---:|---|---:|---|
| `0` | address | yes | Contract address |
| `1` | hash / slot | yes | Storage slot index |
| `2` | block selector | yes | Block number/tag or block hash selector |

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
```

If the state entry is missing, the method returns the zero hash value.

---

## 11. Transactions

## `eth_sendRawTransaction`

Submits a locally signed raw transaction.

### Parameters

```json
[
  "0x<signedRawTransaction>"
]
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_sendRawTransaction",
  "params": ["0x<signedRawTransaction>"]
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x<transactionHash>"
}
```

Notes:

- the transaction must be RLP encoded
- the transaction must be signed locally
- the transaction chain ID must match XGR Chain
- the node adds the transaction to the local txpool
- txpool admission can still fail for fee, nonce, balance, gas or validation reasons

---

## `eth_sendTransaction`

Unsupported.

XGR nodes do not expose node-side wallet management through JSON-RPC.

Use:

```text
eth_sendRawTransaction
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_sendTransaction",
  "params": [
    {
      "from": "0x<sender>",
      "to": "0x<recipient>",
      "value": "0x0"
    }
  ]
}
```

### Error

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "request calls to eth_sendTransaction method are not supported, use eth_sendRawTransaction instead"
  }
}
```

---

## `eth_getTransactionByHash`

Returns a transaction by transaction hash.

The node checks:

1. sealed transaction lookup
2. pending txpool transaction lookup

### Parameters

```json
[
  "0x<transactionHash>"
]
```

### Response

Returns a transaction object or `null`.

Important transaction fields:

| Field | Meaning |
|---|---|
| `hash` | Transaction hash |
| `nonce` | Sender nonce |
| `blockHash` | Block hash if mined, otherwise `null` |
| `blockNumber` | Block number if mined, otherwise `null` |
| `transactionIndex` | Transaction index if mined, otherwise `null` |
| `from` | Sender address |
| `to` | Recipient address or `null` for contract creation |
| `value` | Native value |
| `gas` | Gas limit |
| `gasPrice` | Effective/legacy gas price where present |
| `maxPriorityFeePerGas` | Dynamic-fee priority cap where present |
| `maxFeePerGas` | Dynamic-fee fee cap where present |
| `input` | Calldata |
| `accessList` | Access list for typed transactions |
| `chainId` | Chain ID for typed transactions where present |
| `type` | Transaction type |
| `v`, `r`, `s` | Signature fields |

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

Returns a receipt object or `null`.

Important receipt fields:

| Field | Meaning |
|---|---|
| `transactionHash` | Transaction hash |
| `transactionIndex` | Transaction index in block |
| `blockHash` | Block hash |
| `blockNumber` | Block number |
| `from` | Sender address |
| `to` | Recipient address or `null` for contract creation |
| `contractAddress` | Created contract address if applicable |
| `cumulativeGasUsed` | Cumulative gas used in block up to this tx |
| `gasUsed` | Gas used by this transaction |
| `logs` | Event logs |
| `logsBloom` | Receipt logs bloom |
| `status` | Execution status |
| `type` | Transaction type |
| `root` | Root field where present |

If the transaction is unknown or not yet mined, the result is `null`.

---

## 12. Transaction object fields

XGR Chain transaction JSON objects follow Ethereum-compatible field naming.

| Field | Legacy tx | Access-list tx | Dynamic-fee tx |
|---|---:|---:|---:|
| `gasPrice` | yes | yes | may be present as effective price in returned mined contexts |
| `maxPriorityFeePerGas` | no | no | yes |
| `maxFeePerGas` | no | no | yes |
| `accessList` | no | yes | yes |
| `chainId` | optional/protected legacy | yes | yes |
| `type` | yes | yes | yes |

Typed transactions return `accessList` as an array, including an empty array when no entries exist.

---

## 13. Execution and simulation

## `eth_call`

Executes a call locally against selected state.

It does not submit a transaction and does not change chain state.

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

Optional third parameter:

```json
{
  "0x<address>": {
    "balance": "0x0",
    "nonce": "0x0",
    "code": "0x...",
    "state": {},
    "stateDiff": {}
  }
}
```

The optional third parameter is a state override object.

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x<returnData>"
}
```

If the EVM reverts, the endpoint returns revert data together with an error.

---

## `eth_estimateGas`

Estimates the gas required for a transaction call object.

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

Optional second parameter:

```json
"latest"
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x5208"
}
```

Important behavior:

- if no block number is provided, `latest` is used
- simple EOA value transfers can return intrinsic gas directly
- transfers to contracts are executed because fallback/receive logic can consume more than intrinsic gas
- estimation uses local execution and binary search
- reverting calls can return an error
- if gas is provided, it can act as the upper bound
- if no gas is provided, the selected block gas limit is used as upper bound

---

## 14. Gas and fee discovery

## `eth_gasPrice`

Returns the current suggested gas price for legacy-style transaction pricing.

Current behavior:

```text
eth_gasPrice = latestHeader.BaseFee
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_gasPrice",
  "params": []
}
```

### Example response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x174876e800"
}
```

`0x174876e800` equals:

```text
100000000000 wei = 100 gwei
```

Actual result depends on the current head base fee.

---

## `eth_maxPriorityFeePerGas`

Returns the node's suggested priority fee.

Current behavior:

```text
eth_maxPriorityFeePerGas = 0
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_maxPriorityFeePerGas",
  "params": []
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x0"
}
```

Clients may still apply their own wallet policy, but the current node suggestion is zero.

---

## `eth_feeHistory`

Returns historical fee information.

### Parameters

```json
[
  "0x5",
  "latest",
  [10, 50, 90]
]
```

| Position | Type | Required | Meaning |
|---:|---|---:|---|
| `0` | quantity | yes | Number of blocks requested |
| `1` | block selector | yes | Newest block |
| `2` | array of floats | no | Reward percentiles |

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_feeHistory",
  "params": ["0x5", "latest", [10, 50, 90]]
}
```

### Response shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "oldestBlock": "0x100",
    "baseFeePerGas": ["0x174876e800"],
    "gasUsedRatio": [0.1],
    "reward": [["0x0", "0x0", "0x0"]]
  }
}
```

Field meaning:

| Field | Meaning |
|---|---|
| `oldestBlock` | Oldest block included in the response |
| `baseFeePerGas` | Base fee values for the returned block range |
| `gasUsedRatio` | `gasUsed / gasLimit` for each block |
| `reward` | Effective priority-fee percentiles if requested |

Implementation behavior:

- `blockCount < 1` returns an error
- `blockCount > 1024` is clamped to `1024`
- newest block above local head is clamped to current head
- invalid reward percentiles return an error
- empty blocks produce zero reward values

---

## 15. Transaction fee defaults in RPC simulation

When RPC simulation methods need missing fee fields, the node fills them.

For dynamic-fee transactions:

```text
maxPriorityFeePerGas = 0
maxFeePerGas = 2 × baseFee
```

For legacy transactions:

```text
gasPrice = baseFee
```

Only missing fields are filled.

If a client provides explicit positive fee fields, the node keeps the provided values.

---

## 16. Logs and filters

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

Filtering supports block ranges, address filters and topic filters according to the active filter manager behavior.

Large block ranges can be limited by node configuration.

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
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x1"
}
```

---

## `eth_newBlockFilter`

Creates a filter for new blocks.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_newBlockFilter",
  "params": []
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x2"
}
```

---

## `eth_getFilterLogs`

Returns all logs matching an existing log filter.

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

For log filters:

```json
[
  {
    "address": "0x<contractAddress>",
    "topics": [],
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

For block filters:

```json
[
  "0x<blockHash>"
]
```

If nothing changed:

```json
[]
```

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
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": true
}
```

---

## 17. WebSocket subscriptions

When WebSocket JSON-RPC is enabled, XGR Chain supports Ethereum-style subscriptions.

Supported subscription types:

| Subscription | Meaning |
|---|---|
| `newHeads` | New block headers |
| `logs` | Logs matching a log query |
| `newPendingTransactions` | Pending transaction notifications |

`eth_subscribe` is handled through the WebSocket dispatcher path.

It is not a normal HTTP polling method.

---

## `eth_subscribe`

Creates a WebSocket subscription.

### New heads request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_subscribe",
  "params": ["newHeads"]
}
```

### Logs request

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

### Pending transactions request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_subscribe",
  "params": ["newPendingTransactions"]
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x<subscriptionId>"
}
```

---

## `eth_unsubscribe`

Cancels a WebSocket subscription or removes the corresponding filter ID.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_unsubscribe",
  "params": ["0x<subscriptionId>"]
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": true
}
```

If the subscription/filter ID is unknown, the result can be `false`.

---

## 18. Network methods

## `net_listening`

Returns whether the node reports itself as listening for network connections.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "net_listening",
  "params": []
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": true
}
```

Current behavior returns `true`.

This does not prove that the node has healthy peer connectivity.

Use `net_peerCount` and node monitoring for that.

---

## `net_peerCount`

Returns the current number of connected peers.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "net_peerCount",
  "params": []
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x3"
}
```

The result is a hex quantity.

---

## 19. Web3 methods

## `web3_clientVersion`

Returns the node client/version string.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "web3_clientVersion",
  "params": []
}
```

### Response shape

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "xgrchain/v1.1.1/linux-amd64/go1.23.11"
}
```

Exact output depends on:

- configured chain name
- build version
- commit metadata
- operating system
- architecture
- Go runtime version

---

## `web3_sha3`

Returns the Keccak-256 hash of the given input data.

This is Ethereum Keccak-256, not standardized SHA3-256.

### Parameters

```json
[
  "0x68656c6c6f"
]
```

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "web3_sha3",
  "params": ["0x68656c6c6f"]
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8"
}
```

---

## 20. RPC dispatcher behavior

The JSON-RPC dispatcher maps method names by namespace.

Method name format:

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

1. splits the method name at the first underscore
2. resolves the namespace
3. resolves the exported method on the endpoint service
4. decodes parameters
5. executes the method
6. returns JSON-RPC 2.0 response

Unknown namespaces or methods return method-not-found errors.

Registered namespaces can include operational or XGR-specific surfaces depending on node build and configuration, but this document covers only standard Ethereum-compatible application surfaces.

---

## 21. Batch requests

HTTP and WebSocket JSON-RPC batch requests are supported.

Example batch request:

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

Batch length can be limited by node configuration.

Relevant runtime control:

```text
--json-rpc-batch-request-limit
```

If the configured limit is exceeded, the node returns an invalid-request error.

---

## 22. Block range limits

Range-heavy methods such as log queries can be limited by node configuration.

Relevant runtime control:

```text
--json-rpc-block-range-limit
```

This protects public RPC infrastructure from expensive unbounded queries.

Indexers should avoid very large `eth_getLogs` ranges and should chunk requests.

---

## 23. Recommended client behavior

Clients should:

1. Call `eth_chainId` before signing.
2. Sign transactions locally.
3. Submit with `eth_sendRawTransaction`.
4. Use `eth_estimateGas` before contract execution.
5. Use `eth_gasPrice` or block `baseFeePerGas` for current pricing.
6. Treat `eth_maxPriorityFeePerGas = 0` as valid XGR node behavior.
7. For dynamic-fee transactions, set `maxFeePerGas >= baseFee`.
8. Use `eth_getTransactionReceipt` to confirm inclusion.
9. Use `eth_getLogs` or WebSocket `logs` for event indexing.
10. Avoid relying on node-side wallet methods.
11. Handle `null` for unknown blocks, transactions and receipts.
12. Handle method-not-found for non-standard methods.
13. Keep XGR extension RPC calls separate from standard Ethereum RPC code paths.

---

## 24. Common integration mistakes

### 24.1 Using `eth_sendTransaction`

Wrong:

```text
eth_sendTransaction
```

Correct:

```text
eth_sendRawTransaction
```

XGR nodes do not manage private keys through JSON-RPC.

---

### 24.2 Assuming a non-zero priority fee is required

Current node suggestion:

```text
eth_maxPriorityFeePerGas = 0
```

Wallets may use their own policy, but the node does not currently suggest a mandatory non-zero tip.

---

### 24.3 Treating `maxFeePerGas` as the actual paid price

For dynamic-fee transactions, the actual effective price is:

```text
min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

The fee cap is not necessarily the paid price.

---

### 24.4 Treating `net_listening` as peer health

`net_listening` currently returns whether the node reports itself as listening.

It does not prove healthy connectivity.

Use:

```text
net_peerCount
eth_blockNumber
node monitoring
```

---

### 24.5 Mixing standard RPC with XGR extension RPC

Standard Ethereum-compatible RPC is for wallet, explorer and EVM compatibility.

XGR extension methods are separate interfaces with separate availability, permissions and release status.

Do not assume an XGR extension method exists on every public Ethereum-compatible RPC endpoint.

---

## 25. Quick reference

| Task | Recommended method |
|---|---|
| Get chain ID | `eth_chainId` |
| Get network ID | `net_version` |
| Get latest block number | `eth_blockNumber` |
| Get block by number | `eth_getBlockByNumber` |
| Get block by hash | `eth_getBlockByHash` |
| Get balance | `eth_getBalance` |
| Get nonce | `eth_getTransactionCount` |
| Get code | `eth_getCode` |
| Get storage slot | `eth_getStorageAt` |
| Submit transaction | `eth_sendRawTransaction` |
| Lookup transaction | `eth_getTransactionByHash` |
| Get receipt | `eth_getTransactionReceipt` |
| Simulate call | `eth_call` |
| Estimate gas | `eth_estimateGas` |
| Get gas price | `eth_gasPrice` |
| Get priority fee suggestion | `eth_maxPriorityFeePerGas` |
| Get fee history | `eth_feeHistory` |
| Query logs | `eth_getLogs` |
| Create log filter | `eth_newFilter` |
| Create block filter | `eth_newBlockFilter` |
| Poll filter | `eth_getFilterChanges` |
| Remove filter | `eth_uninstallFilter` |
| Subscribe over WebSocket | `eth_subscribe` |
| Check peer count | `net_peerCount` |
| Get client version | `web3_clientVersion` |
| Hash bytes | `web3_sha3` |
