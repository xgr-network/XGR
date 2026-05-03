# XRC-GAS — Gas Price Behavior

**Document ID:** XRC-GAS-BEHAVIOR  
**Last updated:** 2026-05-03  
**Audience:** Wallet developers, dApp developers, explorer developers, node operators, auditors  
**Implementation status:** Current public baseline for gas pricing and fee split; FeePool split is development / preview until activated by an official release  
**Source of truth:** Public `xgr-network/xgr-node` releases, published XGR Chain configuration, active XGR node behavior, and official XGR Network operator announcements

---

## 1. Purpose

This document specifies gas price behavior on XGR Chain.

It explains:

- supported transaction fee types
- base fee behavior
- minimum base fee behavior
- EIP-1559 compatibility
- legacy transaction compatibility
- `eth_gasPrice`
- `eth_maxPriorityFeePerGas`
- `eth_feeHistory`
- transaction cost calculation
- txpool price admission
- fee split behavior
- `XGRFeeSplit` event behavior
- current public baseline behavior
- development / preview FeePool behavior

XGR Chain is EVM-compatible, but its gas and fee policy is XGR-specific.

Wallets, explorers and dApps should not assume that XGR fee behavior is identical to Ethereum mainnet.

---

## 2. High-level model

XGR Chain supports Ethereum-style gas fields and Ethereum-compatible transaction types, while applying XGR-specific fee policy.

Key properties:

| Area | Behavior |
|---|---|
| Legacy transactions | Supported |
| EIP-155 protected transactions | Supported |
| Dynamic fee / type-2 transactions | Supported where London-style rules are active |
| `gasPrice` | Used by legacy transactions |
| `maxFeePerGas` | Used by dynamic fee transactions |
| `maxPriorityFeePerGas` | Used by dynamic fee transactions |
| `baseFeePerGas` | Present in block headers |
| Minimum base fee | XGR-specific floor |
| Priority fee suggestion | Current code suggests `0` |
| Fee split | XGR-specific burn / donation / validator split |
| Fee split event | `XGRFeeSplit(uint256,uint256,uint256)` |

The normal developer integration path is:

1. read `eth_chainId`
2. estimate gas through `eth_estimateGas`
3. read current fee suggestion through `eth_gasPrice` or EIP-1559 fields
4. submit signed transaction through `eth_sendRawTransaction`
5. read receipt through `eth_getTransactionReceipt`
6. inspect `XGRFeeSplit` logs if fee-split accounting is needed

---

## 3. Supported fee transaction types

XGR Chain supports the following public transaction categories.

| Transaction type | Fee fields | Notes |
|---|---|---|
| Legacy transaction | `gasPrice` | Effective gas price equals `gasPrice` |
| EIP-155 protected legacy transaction | `gasPrice` + chain ID in signature | Replay-protected legacy transaction |
| Access-list transaction | `gasPrice`, access list | Requires active access-list fork support |
| Dynamic fee transaction | `maxFeePerGas`, `maxPriorityFeePerGas` | EIP-1559-style type-2 transaction |
| Contract creation | Same fee rules as transaction type | `to` is empty / nil |
| Contract call | Same fee rules as transaction type | `to` is set |

The node also contains internal transaction types that are not normal wallet transaction types.

Wallets and dApps should use legacy or dynamic-fee transactions.

---

## 4. Native units

Gas prices are denominated in wei per gas.

Native unit model:

```text
1 XGR = 10^18 wei
1 gwei = 10^9 wei
```

The current static fallback minimum base fee constant is:

```text
100000000000 wei = 100 gwei
```

This value is the fallback floor when no dynamic registry-provided value is available.

---

## 5. Base fee

XGR Chain uses a base fee field in block headers.

The current gas suggestion logic reads the current head:

```text
baseFee = latestHeader.BaseFee
```

The base fee is then used for:

- `eth_gasPrice`
- dynamic-fee defaults
- fee cap validation
- transaction effective gas price
- fee history reporting
- txpool sorting and admission behavior

Under the current public baseline RPC logic:

```text
eth_gasPrice = current header baseFee
```

For dynamic-fee defaults:

```text
maxPriorityFeePerGas = 0
maxFeePerGas = 2 × baseFee
```

The base fee is therefore the central public fee reference for wallets and dApps.

---

## 6. Minimum base fee

XGR Chain defines a minimum base fee concept.

Relevant baseline constants:

| Constant | Value | Meaning |
|---|---:|---|
| `MinBaseFee` | `100000000000` | Static fallback minimum base fee |
| `CriticalGasThresholdPct` | `80` | Utilization threshold for normal vs emergency behavior |
| `EmergencyBaseFeeChangeDenom` | `4` | Emergency increase denominator; denominator `4` corresponds to max `+25%` per block |

The EngineRegistry can provide a configured minimum base fee where supported by the active release stack and deployed registry state.

Fallback behavior:

| Condition | Behavior |
|---|---|
| EngineRegistry unavailable | Use static fallback minimum base fee |
| EngineRegistry deployed and readable | Use registry-provided configured value where supported |
| Invalid/unavailable dynamic value | Fall back to deterministic baseline behavior |

Operators and integrators should treat `eth_gasPrice` and block `baseFeePerGas` as the practical source for current transaction pricing.

Do not hardcode a permanent gas price in applications.

---

## 7. Normal and high-load behavior

XGR Chain is designed for predictable transaction costs under normal load.

The intended behavior is:

| Network load | Base fee behavior |
|---|---|
| At or below the critical threshold | Base fee remains at the minimum floor |
| Above the critical threshold | Base fee can increase to protect the network from congestion/spam |
| After load drops below threshold | Base fee returns to the minimum floor according to active release behavior |

The critical threshold constant is:

```text
80%
```

The emergency increase denominator is:

```text
4
```

This means the maximum emergency increase rate is:

```text
baseFee / 4 = 25% per block
```

Integrators should not rely on a hand-coded gas curve.

Use RPC values from the node.

---

## 8. Effective gas price

The effective gas price is the price actually used for cost accounting.

### 8.1 Legacy transactions

For legacy transactions:

```text
effectiveGasPrice = gasPrice
```

### 8.2 Dynamic fee transactions

For dynamic fee transactions:

```text
effectiveGasPrice = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

If the current code-suggested defaults are used:

```text
maxPriorityFeePerGas = 0
maxFeePerGas = 2 × baseFee
```

then under normal conditions:

```text
effectiveGasPrice = baseFee
```

### 8.3 Fee cap validation

A dynamic-fee transaction must satisfy:

```text
maxFeePerGas >= baseFee
```

It must also satisfy:

```text
maxPriorityFeePerGas <= maxFeePerGas
```

If `maxFeePerGas` is below the current block base fee, the transaction is invalid for that block.

---

## 9. Transaction cost

Transaction cost is based on gas used and effective gas price.

```text
transactionCost = gasUsed × effectiveGasPrice
```

The sender initially reserves gas according to the transaction gas limit and effective fee rules.

Unused gas is refunded.

Only actually used gas contributes to the final fee.

Example:

```text
gasUsed = 21,000
effectiveGasPrice = 100 gwei

transactionCost = 21,000 × 100 gwei
transactionCost = 2,100,000 gwei
transactionCost = 0.0021 XGR
```

---

## 10. RPC fee endpoints

### 10.1 `eth_gasPrice`

Returns the current suggested gas price for legacy-style pricing.

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

Example response:

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

### 10.2 `eth_maxPriorityFeePerGas`

Returns the node's suggested priority fee.

Current behavior:

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

Important:

```text
The current code does not suggest 1 gwei. It suggests 0.
```

Wallets may still apply their own UI defaults or buffers.

### 10.3 `eth_feeHistory`

Returns historical base fee, gas used ratio and optional reward percentile data.

Example request:

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
|---|---|
| `oldestBlock` | Oldest returned block |
| `baseFeePerGas` | Base fee values for the sampled range plus next/current reference value |
| `gasUsedRatio` | Gas used / gas limit per block |
| `reward` | Effective priority-fee percentiles where requested |

`eth_feeHistory` is useful for wallets and monitoring tools, but under normal XGR conditions `eth_gasPrice` is usually the simpler source for current pricing.

---

## 11. Transaction defaults used by RPC simulation

When transaction fee fields are missing in simulation contexts such as `eth_call` or `eth_estimateGas`, the node fills them.

### 11.1 Dynamic fee transaction defaults

For dynamic-fee transactions:

```text
GasTipCap = 0
GasFeeCap = 2 × baseFee
```

Only missing fields are filled.

If both fields are already provided, the node keeps the provided values.

### 11.2 Legacy transaction defaults

For legacy transactions:

```text
GasPrice = baseFee
```

Only missing or zero gas price is filled.

If a positive gas price is already provided, the node keeps the provided value.

---

## 12. Recommended wallet behavior

Wallets should support both legacy and dynamic-fee transactions.

Recommended defaults:

| Transaction style | Recommended value |
|---|---|
| Legacy `gasPrice` | Use `eth_gasPrice` |
| Dynamic `maxPriorityFeePerGas` | Use `eth_maxPriorityFeePerGas` or explicit wallet policy |
| Dynamic `maxFeePerGas` | At least `baseFee`; conservative default `2 × baseFee` is compatible |
| Gas limit | Use `eth_estimateGas` plus application-specific buffer |

The current node default for dynamic transactions is:

```text
maxPriorityFeePerGas = 0
maxFeePerGas = 2 × baseFee
```

A wallet may choose to show a non-zero tip as an optional user setting, but XGR's current node suggestion does not require it.

---

## 13. Recommended dApp behavior

dApps should not hardcode gas prices.

Recommended flow:

1. call `eth_chainId`
2. call `eth_estimateGas`
3. call `eth_gasPrice` or read latest block `baseFeePerGas`
4. build transaction with explicit fee fields
5. submit via wallet or `eth_sendRawTransaction`
6. track receipt
7. parse `XGRFeeSplit` log if fee transparency is needed

For cost forecasting:

```text
estimatedCost = estimatedGas × currentBaseFee
```

For conservative dynamic-fee signing:

```text
maxFeePerGas = 2 × currentBaseFee
maxPriorityFeePerGas = 0
```

or use wallet policy if different.

---

## 14. Transaction pool admission

A transaction can be validly signed but still rejected by a node's local txpool.

Txpool admission depends on:

- signature validity
- sender recovery
- chain ID
- nonce
- account balance
- intrinsic gas
- block gas limit
- transaction type support
- fork activation
- effective gas price
- current base fee
- node-level price limit
- replacement pricing
- txpool capacity
- per-account queue limits

Important fee-related rejection causes:

| Condition | Result |
|---|---|
| `maxFeePerGas < baseFee` | Rejected / invalid for current base fee |
| `maxPriorityFeePerGas > maxFeePerGas` | Rejected |
| legacy `gasPrice < baseFee` under London-style rules | Rejected |
| effective gas price below node price limit | Rejected |
| replacement does not increase effective price enough | Rejected |

For public dApps, a txpool rejection should be treated as a local node response.

A transaction rejected by one node may need fee correction or may need submission to a synced, correctly configured node.

---

## 15. Fee split overview

XGR Chain applies an XGR-specific fee split after transaction execution.

The current baseline formula is:

```text
totalFeeRaw = gasUsed × effectiveGasPrice

burnedApplied = min(totalFeeRaw, 1000 gwei)

remainingAfterBurn = totalFeeRaw - burnedApplied

donation = remainingAfterBurn × donationPercent / 100

validator = remainingAfterBurn - donation
```

Then:

```text
burnedApplied -> burned address
donation      -> donation address
validator     -> block coinbase / proposer address
```

The fixed burn amount is:

```text
1000 gwei per transaction
```

If the total fee is smaller than 1000 gwei:

```text
burnedApplied = totalFeeRaw
remainingAfterBurn = 0
donation = 0
validator = 0
```

The burn is clamped.

It never creates negative fees.

---

## 16. Default fee split addresses and percent

Default values:

| Parameter | Value |
|---|---|
| Default burned address | `0x0000000000000000000000000000000000000666` |
| Default donation address | same as default burned address unless registry overrides it |
| Default donation percent | `15` |
| Fee split event address | `0x000000000000000000000000000000000000fEE1` |

The EngineRegistry can override donation address and donation percent where deployed and readable.

If the registry donation address is zero:

```text
donationPercent = 0
```

If the registry is unavailable:

```text
default donation address and percent are used
```

---

## 17. Fee split event

Each processed transaction appends an `XGRFeeSplit` log.

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

The event is intended for:

- explorers
- dashboards
- auditors
- fee transparency
- donation accounting
- validator fee visibility

Explorer implementations should not treat the whole transaction fee as burned.

They should parse the `XGRFeeSplit` log.

---

## 18. Public baseline fee distribution

In the current public baseline, after burn and donation calculation:

```text
validator -> coinbase / block creator
```

The validator portion is paid directly to the block coinbase.

There is no active public-baseline FeePool split unless an official release and published configuration activate it.

Current public baseline summary:

| Component | Behavior |
|---|---|
| Fixed burn | 1000 gwei per transaction, clamped by total fee |
| Donation | Percent of post-burn remaining fee |
| Validator fee | Remaining post-burn fee after donation |
| Validator payout target | Block coinbase |
| Fee event | `XGRFeeSplit` at `0x...fEE1` |

---

## 19. Development / preview FeePool split

A staking-oriented FeePool split exists in the development track.

It is not part of the current published `xgr-node` v1.1.1 baseline.

When the `FeePoolSplit` fork is active in a compatible release, the validator portion is split as:

```text
immediate = validatorFee / 2
pooled    = validatorFee - immediate
```

Then:

```text
immediate -> block coinbase
pooled    -> FeePool address
```

Development FeePool address:

```text
0x000000000000000000000000000000000000fEE2
```

This behavior must be treated as development / preview until all of the following are true:

1. it is included in an official public release
2. the fork is part of the published configuration
3. the activation block or condition is reached
4. operator documentation announces it as active

Until then, explorers should not display FeePool split as active network behavior.

---

## 20. Fee split examples

### 20.1 Baseline example

Assumptions:

```text
gasUsed = 21,000
effectiveGasPrice = 100 gwei
donationPercent = 15
fixedBurn = 1000 gwei
```

Calculation:

```text
totalFeeRaw = 21,000 × 100 gwei
totalFeeRaw = 2,100,000 gwei

burnedApplied = 1,000 gwei
remainingAfterBurn = 2,099,000 gwei

donation = 2,099,000 × 15 / 100
donation = 314,850 gwei

validator = 2,099,000 - 314,850
validator = 1,784,150 gwei
```

Distribution:

| Component | Amount |
|---|---:|
| Burned | `1,000 gwei` |
| Donation | `314,850 gwei` |
| Validator | `1,784,150 gwei` |

### 20.2 Low-fee clamp example

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
| Burned | `500 gwei` |
| Donation | `0` |
| Validator | `0` |

The burn is clamped to the total fee.

---

## 21. Explorer behavior

Explorers should show fee accounting using actual receipt/log data.

Recommended display:

| Display field | Source |
|---|---|
| Total fee | `receipt.gasUsed × effectiveGasPrice` |
| Burned fee | `XGRFeeSplit.burnedFee` |
| Donation fee | `XGRFeeSplit.donationFee` |
| Validator fee | `XGRFeeSplit.validatorFee` |
| Fee split event | Log emitted at `0x000000000000000000000000000000000000fEE1` |

Do not display the entire fee as burned.

Do not infer donation and validator portions from Ethereum mainnet assumptions.

Do not display FeePool distribution unless the active release/configuration supports it.

---

## 22. FeeHistory behavior

`eth_feeHistory` returns:

- oldest block
- base fee per gas array
- gas used ratio array
- optional reward percentile arrays

Important implementation details:

| Behavior | Meaning |
|---|---|
| `blockCount < 1` | Returns error |
| `blockCount > 1024` | Clamped to `1024` |
| newest block above head | Clamped to current head |
| invalid percentile | Returns error |
| empty blocks | Reward values are zero for requested percentiles |
| reward values | Derived from effective gas tip |

`gasUsedRatio` is calculated as:

```text
blockGasUsed / blockGasLimit
```

This makes `eth_feeHistory` useful for congestion monitoring.

---

## 23. Priority fee behavior

Current node fee suggestion:

```text
maxPriorityFeePerGas = 0
```

Dynamic-fee transaction effective price remains:

```text
min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

With tip `0`:

```text
effectiveGasPrice = min(maxFeePerGas, baseFee)
```

If `maxFeePerGas >= baseFee`:

```text
effectiveGasPrice = baseFee
```

A user may set a non-zero priority fee.

If a non-zero priority fee increases the effective gas price, the increased total fee still flows through the XGR fee split.

The priority fee is not paid as a separate Ethereum-mainnet-style miner/validator tip.

---

## 24. Wallet UX guidance

Wallets should show the expected effective fee, not only the maximum fee cap.

For dynamic-fee transactions:

```text
displayedExpectedPrice = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

For default XGR node suggestions:

```text
displayedExpectedPrice = baseFee
```

Wallets may show:

| Field | Recommended display |
|---|---|
| Base fee | Current `baseFeePerGas` |
| Priority fee | Current suggestion, usually `0` |
| Max fee | User cap, often `2 × baseFee` |
| Expected price | Effective gas price |
| Max possible cost | `gasLimit × maxFeePerGas` |
| Expected cost | `estimatedGas × effectiveGasPrice` |

Users should understand that `maxFeePerGas` is a cap, not necessarily the paid price.

---

## 25. dApp backend guidance

Backends should:

- avoid hardcoded gas prices
- use `eth_estimateGas`
- use `eth_gasPrice` for legacy-style transactions
- use latest block `baseFeePerGas` for dynamic-fee pricing
- set `maxFeePerGas >= baseFee`
- handle `max fee per gas less than block base fee`
- handle txpool underpriced errors
- handle nonce errors
- parse fee split logs if reporting fee distribution
- avoid assuming Ethereum-mainnet tip payout semantics

Recommended default dynamic-fee strategy:

```text
baseFee = latest.baseFeePerGas
maxPriorityFeePerGas = 0
maxFeePerGas = 2 × baseFee
```

For congestion-sensitive applications, use a larger cap only if needed.

The cap does not define the paid price unless the effective price reaches it.

---

## 26. Node operator guidance

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
- explorers should parse `XGRFeeSplit` instead of assuming fee semantics

---

## 27. Common integration mistakes

### 27.1 Assuming priority fee is required

Current node suggestion is:

```text
maxPriorityFeePerGas = 0
```

A non-zero tip is optional.

### 27.2 Showing max fee as actual fee

Wrong:

```text
actualCost = gasUsed × maxFeePerGas
```

Correct:

```text
actualCost = gasUsed × effectiveGasPrice
```

### 27.3 Treating all fees as burned

Wrong:

```text
burned = totalFee
```

Correct:

```text
burned, donation, validator = XGRFeeSplit log fields
```

### 27.4 Treating FeePool split as active before activation

FeePool split is development / preview until officially released and activated.

### 27.5 Hardcoding 1 gwei priority fee

The current node suggests `0`.

Wallets may choose their own UI policy, but should not document 1 gwei as the node behavior.

---

## 28. FAQ

### Q: What should I use for legacy `gasPrice`?

Use:

```text
eth_gasPrice
```

Current behavior:

```text
eth_gasPrice = latest block baseFee
```

### Q: What should I use for `maxPriorityFeePerGas`?

Use:

```text
eth_maxPriorityFeePerGas
```

Current behavior:

```text
0
```

### Q: What should I use for `maxFeePerGas`?

A compatible default is:

```text
2 × baseFee
```

This is also the current node default when a dynamic-fee transaction is missing `GasFeeCap`.

### Q: Does setting a high `maxFeePerGas` mean I pay that amount?

No.

For dynamic-fee transactions, the paid price is:

```text
min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

### Q: Does XGR pay priority fee separately to validators?

No.

If a non-zero priority fee increases the effective gas price, the resulting total fee still goes through the XGR fee split.

### Q: What is the fixed burn amount?

```text
1000 gwei per transaction
```

It is clamped to the total fee if the total fee is smaller.

### Q: Where can explorers read fee split values?

From the `XGRFeeSplit(uint256,uint256,uint256)` log at:

```text
0x000000000000000000000000000000000000fEE1
```

### Q: Is FeePool split active?

Not in the current public baseline.

FeePool split is development / preview until included in an official release and activated by published configuration.

---

## 29. Quick reference

### RPC

| Method | Current behavior |
|---|---|
| `eth_gasPrice` | Returns current header `baseFee` |
| `eth_maxPriorityFeePerGas` | Returns `0` |
| `eth_feeHistory` | Returns historical base fee, gas used ratio and optional reward percentiles |
| `eth_estimateGas` | Estimates gas required for execution |
| `eth_sendRawTransaction` | Submits signed raw transaction |

### Effective gas price

```text
Legacy:
effectiveGasPrice = gasPrice

Dynamic fee:
effectiveGasPrice = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

### Current dynamic-fee defaults

```text
maxPriorityFeePerGas = 0
maxFeePerGas = 2 × baseFee
```

### Fee split

```text
totalFeeRaw = gasUsed × effectiveGasPrice

burnedApplied = min(totalFeeRaw, 1000 gwei)

remainingAfterBurn = totalFeeRaw - burnedApplied

donation = remainingAfterBurn × donationPercent / 100

validator = remainingAfterBurn - donation
```

### Current public baseline payout

```text
burnedApplied -> default/registry burned address
donation      -> default/registry donation address
validator     -> coinbase / block creator
```

### Development / preview FeePool payout

```text
validatorFee / 2 -> coinbase / block creator
remaining half   -> FeePool address
```

FeePool split requires official release and activation.
