# XRC-GAS — Gas Price & Fee Behavior

**Document ID:** XRC-GAS-BEHAVIOR  
**Last updated:** 2026-05-24  
**Audience:** Wallet developers, dApp developers, explorer developers, node operators, auditors  
**Release baseline:** `xgr-node` release tag `v2.0.5`  
**Mainnet genesis source:** `xgr-network/XGR` branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Public XGR Chain gas pricing, fee accounting and fee-split behavior

---

## 1. Purpose

This document specifies gas price and fee behavior on XGR Chain.

It explains:

- supported public transaction fee types
- native fee units
- base fee behavior
- minimum base fee behavior
- RPC fee suggestion behavior
- dynamic-fee transaction defaults
- transaction cost calculation
- txpool price admission
- XGR fee split behavior
- FeePool behavior after PoS activation
- fee-related receipt logs
- wallet, dApp and explorer guidance

XGR Chain is EVM-compatible, but its gas and fee policy is XGR-specific.

Wallets, explorers and dApps must not assume that XGR fee behavior is identical to Ethereum mainnet.

---

## 2. Mainnet fee baseline

The current public baseline is:

```text
xgr-node v2.0.5
```

The published mainnet genesis is:

```text
xgr-network/XGR
main
genesis/mainnet/genesis.json
```

Mainnet fee-relevant facts:

| Field | Value |
|---|---|
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| London fork | Active from block `0` |
| LondonFix fork | Active from block `0` |
| `txHashWithType` | Active from block `0` |
| EIP-2930 | Active from block `1208500` |
| EIP-2929 | Active from block `1208500` |
| EIP-3860 | Active from block `1208500` |
| EIP-3651 | Active from block `1208500` |
| PoS activation block | `5446500` |
| FeePoolSplit effective block | `5446500` |
| Genesis gas limit | `60,000,000` |
| Genesis base fee | `0x0` |
| Static fallback minimum base fee | `100000000000 wei` |

`100000000000 wei` equals:

```text
100 gwei
```

---

## 3. High-level model

XGR Chain supports Ethereum-style gas fields and Ethereum-compatible transaction types while applying XGR-specific fee accounting.

Key properties:

| Area | Behavior |
|---|---|
| `LegacyTx` | Supported |
| EIP-155 protected `LegacyTx` | Supported |
| `AccessListTx` | Supported when EIP-2930 is active |
| `DynamicFeeTx` | Supported under London-style rules |
| `gasPrice` | Used by `LegacyTx` and `AccessListTx` |
| `maxFeePerGas` | Used by `DynamicFeeTx` |
| `maxPriorityFeePerGas` | Used by `DynamicFeeTx` |
| `baseFeePerGas` | Present in block headers |
| Minimum base fee | XGR-specific floor |
| Priority fee suggestion | Current node suggestion is `0` |
| Fee split | XGR-specific burned/donation/validator accounting |
| FeePool split | Active from first PoS block, `5446500` on mainnet |
| Fee split log | `XGRFeeSplit(uint256,uint256,uint256)` |
| Fee accounting log | `XGRFeeAccounting(uint256,uint256,uint256,uint256)` when FeePoolSplit is active |

Normal developer integration flow:

1. read `eth_chainId`
2. estimate gas through `eth_estimateGas`
3. read current fee suggestion through `eth_gasPrice` or latest block `baseFeePerGas`
4. build transaction with explicit fee fields
5. submit signed transaction through `eth_sendRawTransaction`
6. read receipt through `eth_getTransactionReceipt`
7. parse XGR fee logs if fee accounting is needed

---

## 4. Native units

Gas prices are denominated in wei per gas.

Native unit model:

```text
1 XGR = 10^18 wei
1 gwei = 10^9 wei
```

The static fallback minimum base fee is:

```text
100000000000 wei = 100 gwei
```

This is the fallback floor when no valid on-chain registry value is available.

---

## 5. Supported public transaction fee types

XGR Chain supports these public transaction categories:

| Transaction type | Code-level type | Fee fields |
|---|---|---|
| Legacy transaction | `LegacyTx` / `0x00` | `gasPrice` |
| EIP-155 protected legacy transaction | `LegacyTx` / `0x00` | `gasPrice` plus chain ID in signature |
| Access-list transaction | `AccessListTx` / `0x01` | `gasPrice` plus access list |
| Dynamic-fee transaction | `DynamicFeeTx` / `0x02` | `maxFeePerGas`, `maxPriorityFeePerGas` |
| Contract creation | transaction with `to == nil` | Same fee rules as its transaction type |
| Contract call | transaction with `to != nil` | Same fee rules as its transaction type |

The node also defines internal `StateTx` / `0x7f`.

`StateTx` is not a normal wallet transaction.

The txpool rejects `StateTx` from normal transaction submission.

---

## 6. Base fee field

XGR Chain stores the base fee in the block header as:

```text
baseFeePerGas
```

The code-level field is:

```text
Header.BaseFee
```

Public RPC surfaces expose the header base fee through normal Ethereum-compatible block responses.

The current fee suggestion logic uses the current chain head:

```text
baseFee = latestHeader.BaseFee
```

---

## 7. Minimum base fee

The node defines these fee-policy constants:

| Constant | Value | Meaning |
|---|---:|---|
| `MinBaseFee` | `100000000000` | Static fallback minimum base fee |
| `CriticalGasThresholdPct` | `80` | Utilization threshold for normal mode |
| `EmergencyBaseFeeChangeDenom` | `4` | Emergency increase denominator |

The minimum base fee resolver works as follows:

1. start with static `MinBaseFee`
2. if `EngineRegistryAddress` is not configured, use static `MinBaseFee`
3. if EngineRegistry state is unavailable, use static `MinBaseFee`
4. if EngineRegistry is not deployed yet, use static `MinBaseFee`
5. otherwise read `minBaseFee` from the EngineRegistry storage slot
6. if the registry value does not fit into `uint64`, use static `MinBaseFee`
7. a registry value of `0` is allowed by the code path

Practical integration rule:

```text
Use live RPC values. Do not hardcode permanent gas prices in applications.
```

---

## 8. Base fee calculation

The next base fee is calculated from the parent header.

High-level behavior:

| Parent state | Behavior |
|---|---|
| `parent.BaseFee == 0` | Start from configured genesis base fee if non-zero, otherwise default genesis base fee, then apply minimum-base-fee guard |
| `parent.GasLimit == 0` | Use minimum base fee |
| `parent.GasUsed <= 80% of parent.GasLimit` | Clamp to minimum base fee |
| `parent.GasUsed > 80% of parent.GasLimit` | Increase above floor according to excess utilization |
| Calculated fee below minimum | Return minimum base fee |

Emergency increase formula:

```text
threshold = parent.GasLimit * 80 / 100

headroom = parent.GasLimit - threshold

excess = parent.GasUsed - threshold

parentBF = max(parent.BaseFee, minBaseFee)

delta = parentBF * excess / headroom / 4

delta = max(delta, 1)

nextBaseFee = parentBF + delta
```

The addition is saturation-safe.

The returned base fee is never below the resolved minimum base fee.

---

## 9. RPC fee suggestions

### 9.1 `eth_gasPrice`

`eth_gasPrice` returns the node's current suggested gas price for `LegacyTx` style pricing.

Current behavior:

```text
eth_gasPrice = latestHeader.BaseFee
```

Example request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_gasPrice",
  "params": []
}
```

If the current base fee is `100 gwei`, example response:

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

### 9.2 `eth_maxPriorityFeePerGas`

Current node behavior:

```text
eth_maxPriorityFeePerGas = 0
```

Example request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_maxPriorityFeePerGas",
  "params": []
}
```

Example response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x0"
}
```

A wallet may apply its own UI policy, but the node suggestion is `0`.

### 9.3 Dynamic-fee suggestion values

The internal suggestion function returns:

```text
baseFee = latestHeader.BaseFee
tip = 0
gasPrice = baseFee
feeCap = 2 * baseFee
```

`feeCap` uses saturation-safe multiplication.

---

## 10. Transaction fee defaults in RPC simulation

When transaction fee fields are missing in simulation contexts such as `eth_call` or `eth_estimateGas`, the node fills them.

### 10.1 `DynamicFeeTx`

If `GasTipCap` is missing:

```text
GasTipCap = 0
```

If `GasFeeCap` is missing:

```text
GasFeeCap = 2 * baseFee
```

If both fields are already provided, the node keeps the provided values.

### 10.2 `LegacyTx` and `AccessListTx`

If `GasPrice` is missing or zero:

```text
GasPrice = baseFee
```

If a positive gas price is already provided, the node keeps it.

---

## 11. Effective gas price

The effective gas price is the price actually used for cost accounting.

### 11.1 `LegacyTx`

For `LegacyTx`:

```text
effectiveGasPrice = gasPrice
```

### 11.2 `AccessListTx`

For `AccessListTx`:

```text
effectiveGasPrice = gasPrice
```

### 11.3 `DynamicFeeTx`

For `DynamicFeeTx`:

```text
effectiveGasPrice = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

With the current node default:

```text
maxPriorityFeePerGas = 0
maxFeePerGas = 2 * baseFee
```

effective price normally becomes:

```text
effectiveGasPrice = baseFee
```

---

## 12. Dynamic-fee validation

For `DynamicFeeTx`, the txpool and execution layer validate fee fields.

Important validation rules:

| Condition | Result |
|---|---|
| London not active | `DynamicFeeTx` not supported |
| `txHashWithType` not active | `DynamicFeeTx` not supported |
| `GasFeeCap` missing | underpriced |
| `GasTipCap` missing | underpriced |
| `GasFeeCap` bit length > 256 | rejected |
| `GasTipCap` bit length > 256 | rejected |
| `GasTipCap > GasFeeCap` | rejected |
| `GasFeeCap < baseFee` | rejected / underpriced |
| effective gas price below node `priceLimit` | rejected / underpriced |

Execution-layer error text for fee cap below base fee:

```text
max fee per gas less than block base fee
```

---

## 13. Txpool price admission

A transaction can be validly signed but still rejected by a local txpool.

Txpool admission checks include:

- transaction type
- signature
- sender recovery
- chain ID
- nonce
- account balance
- intrinsic gas
- block gas limit
- fork activation
- base fee
- effective gas price
- node-level `priceLimit`
- replacement pricing
- txpool capacity
- per-account queue limits

Important fee-related rejection causes:

| Condition | Result |
|---|---|
| `DynamicFeeTx.GasFeeCap < baseFee` | underpriced |
| `DynamicFeeTx.GasTipCap > GasFeeCap` | rejected |
| `LegacyTx` / `AccessListTx` gas price below base fee while London is active | underpriced |
| effective gas price below `--price-limit` | underpriced |
| replacement transaction does not increase effective gas price | replacement underpriced |

For public dApps, a txpool rejection should be treated as a local node response.

A transaction rejected by one node may need fee correction or submission to a synced, correctly configured node.

---

## 14. Transaction cost

Transaction cost is based on gas used and effective gas price.

```text
transactionCost = gasUsed * effectiveGasPrice
```

The sender initially reserves gas according to the transaction gas limit and fee rules.

Unused gas is refunded.

Only actually used gas contributes to the final fee.

Example:

```text
gasUsed = 21,000
effectiveGasPrice = 100 gwei

transactionCost = 21,000 * 100 gwei
transactionCost = 2,100,000 gwei
transactionCost = 0.0021 XGR
```

---

## 15. XGR fee split

After transaction execution, XGR Chain computes an XGR-specific fee split.

Code-level calculation:

```text
totalFeeRaw = gasUsed * effectiveGasPrice

burnedApplied = min(totalFeeRaw, 1000 gwei)

remainingAfterBurn = totalFeeRaw - burnedApplied

donation = remainingAfterBurn * donationPercent / 100

validator = remainingAfterBurn - donation
```

The fixed burned-accounting amount is:

```text
1000 gwei per transaction
```

It is clamped to the total fee.

If the total fee is smaller than `1000 gwei`:

```text
burnedApplied = totalFeeRaw
remainingAfterBurn = 0
donation = 0
validator = 0
```

The code credits `burnedApplied` to the configured burned address.

It does not create negative fee values.

---

## 16. Default fee split addresses and percent

Default values in the public node:

| Parameter | Value |
|---|---|
| Default burned address | `0x0000000000000000000000000000000000000666` |
| Default donation address | same as default burned address |
| Default donation percent | `15` |
| Fee split log address | `0x000000000000000000000000000000000000fEE1` |
| FeePool address | `0x000000000000000000000000000000000000fEE2` |

EngineRegistry can override donation address and donation percent when the registry is configured, deployed and readable.

If the registry donation address is zero:

```text
donationPercent = 0
```

If the registry is unavailable or not deployed:

```text
default donation address and default donation percent are used
```

---

## 17. FeePoolSplit behavior

`feePoolSplit` is active from the first PoS IBFT fork.

For mainnet:

```text
first PoS block = 5446500
feePoolSplit effective block = 5446500
```

The node enforces alignment:

- if `feePoolSplit` exists and does not equal the first PoS block, initialization fails
- if `feePoolSplit` is absent and a PoS fork exists, the node sets it internally to the first PoS block

### 17.1 Before FeePoolSplit

When `FeePoolSplit` is not active, validator fee distribution is:

```text
validator -> block coinbase
```

### 17.2 With FeePoolSplit active

When `FeePoolSplit` is active:

```text
validatorImmediate = validator / 2

validatorPooled = validator - validatorImmediate
```

Distribution:

```text
validatorImmediate -> block coinbase

validatorPooled -> 0x000000000000000000000000000000000000fEE2
```

The pooled portion is later handled by PoS epoch/reward logic.

---

## 18. Fee split logs

### 18.1 `XGRFeeSplit`

Every processed normal transaction appends an `XGRFeeSplit` log.

Event signature:

```solidity
XGRFeeSplit(uint256,uint256,uint256)
```

Topic:

```text
keccak256("XGRFeeSplit(uint256,uint256,uint256)")
```

Log address:

```text
0x000000000000000000000000000000000000fEE1
```

Data fields:

| Position | Field |
|---:|---|
| 1 | `donationFee` |
| 2 | `validatorFee` |
| 3 | `burnedFee` |

Explorer implementations should parse this log.

They must not display the entire transaction fee as burned.

### 18.2 `XGRFeeAccounting`

When `FeePoolSplit` is active, the node additionally appends an `XGRFeeAccounting` log.

Event signature:

```solidity
XGRFeeAccounting(uint256,uint256,uint256,uint256)
```

Topic:

```text
keccak256("XGRFeeAccounting(uint256,uint256,uint256,uint256)")
```

Log address:

```text
0x000000000000000000000000000000000000fEE1
```

Data fields:

| Position | Field |
|---:|---|
| 1 | `donationFee` |
| 2 | `validatorImmediateFee` |
| 3 | `validatorPooledFee` |
| 4 | `burnedFee` |

For post-PoS blocks, explorers should prefer `XGRFeeAccounting` when they need to distinguish immediate validator payout from pooled validator fee.

---

## 19. Fee split examples

### 19.1 Normal example

Assumptions:

```text
gasUsed = 21,000
effectiveGasPrice = 100 gwei
donationPercent = 15
fixedBurn = 1000 gwei
```

Calculation:

```text
totalFeeRaw = 21,000 * 100 gwei
totalFeeRaw = 2,100,000 gwei

burnedApplied = 1,000 gwei
remainingAfterBurn = 2,099,000 gwei

donation = 2,099,000 * 15 / 100
donation = 314,850 gwei

validator = 2,099,000 - 314,850
validator = 1,784,150 gwei
```

Distribution before FeePoolSplit:

| Component | Amount |
|---|---:|
| Burned address | `1,000 gwei` |
| Donation address | `314,850 gwei` |
| Coinbase | `1,784,150 gwei` |
| FeePool | `0` |

Distribution with FeePoolSplit active:

```text
validatorImmediate = 1,784,150 / 2
validatorImmediate = 892,075 gwei

validatorPooled = 1,784,150 - 892,075
validatorPooled = 892,075 gwei
```

| Component | Amount |
|---|---:|
| Burned address | `1,000 gwei` |
| Donation address | `314,850 gwei` |
| Coinbase | `892,075 gwei` |
| FeePool | `892,075 gwei` |

### 19.2 Low-fee clamp example

Assumptions:

```text
totalFeeRaw = 500 gwei
fixedBurn = 1000 gwei
```

Calculation:

```text
burnedApplied = 500 gwei
remainingAfterBurn = 0
donation = 0
validator = 0
```

Distribution:

| Component | Amount |
|---|---:|
| Burned address | `500 gwei` |
| Donation address | `0` |
| Coinbase | `0` |
| FeePool | `0` |

The burned amount is clamped to the total fee.

---

## 20. `eth_feeHistory`

`eth_feeHistory` returns:

- oldest block
- base fee per gas array
- gas used ratio array
- optional reward percentile arrays

Implementation behavior:

| Behavior | Meaning |
|---|---|
| `blockCount < 1` | returns `blockCount must be greater than 0` |
| `blockCount > 1024` | clamped to `1024` |
| newest block above current head | clamped to current head |
| invalid percentile `< 0` or `> 100` | returns `invalid percentile` |
| percentile list not sorted ascending | returns `invalid percentile` |
| empty blocks | reward values are zero for requested percentiles |
| `gasUsedRatio` | `block.Header.GasUsed / block.Header.GasLimit` |
| reward values | derived from effective gas tip |

`baseFeePerGas` contains the sampled block base fees plus one additional current-head base fee value.

---

## 21. Wallet guidance

Wallets should support:

- `LegacyTx`
- `AccessListTx`
- `DynamicFeeTx`

Recommended defaults:

| Transaction style | Recommended value |
|---|---|
| `LegacyTx.gasPrice` | `eth_gasPrice` |
| `DynamicFeeTx.maxPriorityFeePerGas` | `eth_maxPriorityFeePerGas`, currently `0` |
| `DynamicFeeTx.maxFeePerGas` | at least `baseFee`; default `2 * baseFee` is compatible |
| Gas limit | `eth_estimateGas` plus application-specific buffer |

Wallets should show expected effective fee, not only maximum fee cap.

For `DynamicFeeTx`:

```text
displayedExpectedPrice = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

The maximum fee is a cap.

It is not necessarily the price paid.

---

## 22. dApp backend guidance

Backends should:

- avoid hardcoded gas prices
- use `eth_estimateGas`
- use `eth_gasPrice` for `LegacyTx`
- use latest block `baseFeePerGas` for `DynamicFeeTx`
- set `maxFeePerGas >= baseFee`
- handle `max fee per gas less than block base fee`
- handle `transaction underpriced`
- handle nonce errors
- parse XGR fee logs if reporting fee distribution
- not assume Ethereum-mainnet priority-fee payout semantics

Recommended default `DynamicFeeTx` strategy:

```text
baseFee = latest.baseFeePerGas
maxPriorityFeePerGas = 0
maxFeePerGas = 2 * baseFee
```

For congestion-sensitive applications, use a larger cap only if needed.

The cap does not define the paid price unless the effective price reaches it.

---

## 23. Node operator guidance

Relevant runtime flags:

| Flag | Meaning |
|---|---|
| `--price-limit` | Minimum effective gas price accepted into the local txpool |
| `--block-gas-target` | Local configured target for gas limit adjustment where used |
| `--json-rpc-block-range-limit` | Limits block-range-heavy RPC calls |
| `--json-rpc-batch-request-limit` | Limits batch RPC requests |

Operator warnings:

- setting `--price-limit` too high can reject otherwise valid user transactions from the local txpool
- public RPC nodes should expose fee endpoints reliably
- public RPC nodes should be synced before serving fee suggestions
- validators should not be overloaded with public fee-estimation traffic
- explorers should parse XGR fee logs instead of assuming Ethereum fee semantics

---

## 24. Explorer guidance

Explorers should show fee accounting from actual receipt/log data.

Recommended display:

| Display field | Source |
|---|---|
| Total fee | `receipt.gasUsed * effectiveGasPrice` |
| Burned/accounting fee | `XGRFeeSplit.burnedFee` |
| Donation fee | `XGRFeeSplit.donationFee` |
| Validator fee total | `XGRFeeSplit.validatorFee` |
| Validator immediate fee | `XGRFeeAccounting.validatorImmediateFee` where present |
| Validator pooled fee | `XGRFeeAccounting.validatorPooledFee` where present |
| Fee split log | log at `0x000000000000000000000000000000000000fEE1` |
| FeePool address | `0x000000000000000000000000000000000000fEE2` |

Do not display the entire fee as burned.

Do not infer donation, validator or FeePool portions from Ethereum mainnet assumptions.

For post-PoS mainnet blocks, FeePoolSplit is active.

---

## 25. Common integration mistakes

### 25.1 Assuming a priority fee is required

Current node suggestion:

```text
maxPriorityFeePerGas = 0
```

A non-zero priority fee is optional.

### 25.2 Showing max fee as actual fee

Wrong:

```text
actualCost = gasUsed * maxFeePerGas
```

Correct:

```text
actualCost = gasUsed * effectiveGasPrice
```

### 25.3 Treating all fees as burned

Wrong:

```text
burned = totalFee
```

Correct:

```text
burned, donation, validator = XGRFeeSplit log fields
```

### 25.4 Ignoring FeePoolSplit after PoS activation

Wrong for post-PoS mainnet blocks:

```text
validatorFee always goes completely to coinbase
```

Correct for FeePoolSplit-active blocks:

```text
validatorImmediateFee -> coinbase
validatorPooledFee    -> FeePool
```

### 25.5 Hardcoding `1 gwei` priority fee

The current node suggests:

```text
0
```

Wallets may choose their own UI policy, but should not document `1 gwei` as node behavior.

---

## 26. FAQ

### Q: What should I use for `LegacyTx.gasPrice`?

Use:

```text
eth_gasPrice
```

Current behavior:

```text
eth_gasPrice = latestHeader.BaseFee
```

### Q: What should I use for `maxPriorityFeePerGas`?

Use:

```text
eth_maxPriorityFeePerGas
```

Current node behavior:

```text
0
```

### Q: What should I use for `maxFeePerGas`?

A compatible default is:

```text
2 * baseFee
```

This is also the current node default when a dynamic-fee transaction is missing `GasFeeCap`.

### Q: Does setting a high `maxFeePerGas` mean I pay that amount?

No.

For `DynamicFeeTx`, the paid price is:

```text
min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

### Q: Does XGR pay priority fee separately to validators?

No.

If a non-zero priority fee increases the effective gas price, the resulting total fee still goes through the XGR fee split.

### Q: What is the fixed burned-accounting amount?

```text
1000 gwei per transaction
```

It is clamped to the total fee if the total fee is smaller.

### Q: Where can explorers read fee split values?

From the `XGRFeeSplit(uint256,uint256,uint256)` log at:

```text
0x000000000000000000000000000000000000fEE1
```

For FeePool-specific accounting, use `XGRFeeAccounting(uint256,uint256,uint256,uint256)` where present.

### Q: Is FeePoolSplit active on mainnet?

Yes for blocks from the first PoS block onward:

```text
5446500
```

---

## 27. Quick reference

### RPC

| Method | Current behavior |
|---|---|
| `eth_gasPrice` | Returns current header `BaseFee` |
| `eth_maxPriorityFeePerGas` | Returns `0` |
| `eth_feeHistory` | Returns historical base fee, gas used ratio and optional reward percentiles |
| `eth_estimateGas` | Estimates gas required for execution |
| `eth_sendRawTransaction` | Submits signed raw transaction |

### Effective gas price

```text
LegacyTx / AccessListTx:
effectiveGasPrice = gasPrice

DynamicFeeTx:
effectiveGasPrice = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

### Current dynamic-fee defaults

```text
maxPriorityFeePerGas = 0
maxFeePerGas = 2 * baseFee
```

### XGR fee split

```text
totalFeeRaw = gasUsed * effectiveGasPrice

burnedApplied = min(totalFeeRaw, 1000 gwei)

remainingAfterBurn = totalFeeRaw - burnedApplied

donation = remainingAfterBurn * donationPercent / 100

validator = remainingAfterBurn - donation
```

### FeePoolSplit-active payout

```text
burnedApplied      -> burned address
donation           -> donation address
validator / 2      -> coinbase / block creator
validator - half   -> FeePool address
```

Mainnet FeePool address:

```text
0x000000000000000000000000000000000000fEE2
```
