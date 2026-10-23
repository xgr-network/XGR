# XRC-GAS — Gas Price & Fee Behavior

**Document ID:** XRC-GAS-BEHAVIOR  
**Last updated:** 2026-10-03  
**Audience:** Wallet developers, dApp developers, explorer developers, node operators, auditors  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Public XGRChain gas pricing, transaction fees, fee accounting and PoS FeePool behavior

---

## 1. Purpose

This document specifies gas-price and transaction-fee behavior on XGRChain.

It covers:

- supported public transaction types,
- gas-price units,
- XGRChain base-fee policy,
- dynamic minimum base fee,
- emergency congestion pricing,
- `eth_gasPrice`,
- `eth_maxPriorityFeePerGas`,
- `eth_feeHistory`,
- simulation defaults,
- transaction fee validation,
- TxPool admission,
- actual transaction cost,
- XGR-specific fee splitting,
- PoS FeePool behavior,
- receipt fee-accounting logs,
- wallet integration,
- dApp integration,
- explorer accounting,
- operator configuration.

XGRChain is EVM-compatible but its fee policy is not identical to Ethereum mainnet.

Applications must use XGRChain's actual RPC and receipt behavior rather than assuming Ethereum-mainnet economics.

---

## 2. Current mainnet fee baseline

Current node baseline:

```text
xgr-node v3.1.1
```

Mainnet:

| Field | Value |
| --- | --- |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Native token | XGR |
| Native decimals | `18` |
| London | Active from block `0` |
| LondonFix | Active from block `0` |
| `txHashWithType` | Active from block `0` |
| EIP-2930 | Active from block `1208500` |
| EIP-2929 | Active from block `1208500` |
| EIP-3860 | Active from block `1208500` |
| EIP-3651 | Active from block `1208500` |
| PoS activation | `5446500` |
| FeePoolSplit effective block | `5446500` |
| Genesis gas limit | `60,000,000` |
| Genesis `baseFee` | `0` |
| Static fallback minimum base fee | `100,000,000,000 wei` |
| Static fallback minimum base fee | `100 gwei` |

---

## 3. Native units

Gas prices are denominated in wei per gas.

```text
1 XGR  = 10^18 wei
1 gwei = 10^9 wei
```

Therefore:

```text
100 gwei
=
100,000,000,000 wei
```

and:

```text
1,000 gwei
=
1,000,000,000,000 wei
```

---

# Transaction types

## 4. Supported public transaction types

XGRChain supports:

| Transaction | Type | Fee fields |
| --- | ---: | --- |
| Legacy | `0x00` | `gasPrice` |
| EIP-155 protected Legacy | `0x00` | `gasPrice` |
| Access List | `0x01` | `gasPrice` |
| Dynamic Fee | `0x02` | `maxFeePerGas`, `maxPriorityFeePerGas` |

Contract creation and normal contract calls use the same fee model as their enclosing transaction type.

The node also defines:

```text
StateTx = 0x7f
```

This is an internal system-transaction type.

It is not a normal wallet transaction and is not accepted as an ordinary user transaction through the TxPool.

---

# Base fee policy

## 5. XGRChain base fee

Block headers contain:

```text
BaseFee
```

which is exposed through Ethereum-compatible RPC as:

```text
baseFeePerGas
```

XGRChain uses a custom base-fee policy designed to provide:

- predictable pricing during normal utilization,
- a configurable minimum fee,
- aggressive but bounded congestion response above a critical utilization level.

---

## 6. Static fallback parameters

`v3.1.1` defines:

| Constant | Value |
| --- | ---: |
| `MinBaseFee` | `100,000,000,000 wei` |
| `CriticalGasThresholdPct` | `80` |
| `EmergencyBaseFeeChangeDenom` | `4` |

Equivalent:

```text
fallback floor = 100 gwei
critical utilization = 80%
maximum emergency increase at 100% utilization = +25% per block
```

The `100 gwei` value is a fallback.

It is not necessarily a permanently hard-coded network floor because the EngineRegistry can provide a different `minBaseFee`.

---

## 7. Dynamic minimum base fee

The node resolves the effective minimum base fee from chain state.

Default:

```text
minBaseFee = 100 gwei
```

The node then checks the configured EngineRegistry.

Conceptually:

```text
EngineRegistry address absent
        ↓
100 gwei fallback

EngineRegistry state unavailable
        ↓
100 gwei fallback

EngineRegistry not deployed
        ↓
100 gwei fallback

EngineRegistry deployed
        ↓
read minBaseFee storage slot
```

If the registry value exceeds `uint64`:

```text
fallback to 100 gwei
```

A valid registry value of:

```text
0
```

is explicitly permitted by the current implementation.

Therefore integrations should not assume the effective minimum is permanently `100 gwei`.

---

## 8. EngineRegistry configuration boundary

The canonical chain configuration contains an EngineRegistry address.

The node reads fee-policy values directly from its canonical state when the configured registry is deployed.

Relevant dynamic values include:

```text
minBaseFee
donationAddress
donationPercent
```

This means fee policy can have both:

```text
node implementation defaults
```

and:

```text
canonical on-chain registry values
```

Applications should use live chain/RPC behavior rather than embedding the fallback constants as permanent network parameters.

---

## 9. First non-zero base fee

The mainnet genesis header contains:

```text
BaseFee = 0
```

When calculating the next base fee from a parent whose base fee is zero, the implementation first selects:

```text
configured genesis base fee
```

or, if that is zero:

```text
chain.GenesisBaseFee = 1 gwei
```

The final minimum-base-fee guard is then applied.

With the normal static fallback:

```text
1 gwei
    ↓
minimum guard
    ↓
100 gwei
```

Therefore the zero genesis header does not mean normal post-genesis transactions use a zero base fee.

---

## 10. Normal pricing mode

For a non-zero parent base fee:

```text
threshold =
    parent.GasLimit
    × 80
    / 100
```

If:

```text
parent.GasUsed <= threshold
```

then:

```text
nextBaseFee = minBaseFee
```

XGRChain therefore does not continuously lower and raise base fee around a 50% target as Ethereum mainnet does.

Up to 80% utilization, the XGRChain policy hard-clamps pricing to the current configured minimum.

---

## 11. Emergency congestion mode

When:

```text
parent.GasUsed > 80% of parent.GasLimit
```

the emergency ramp activates.

Define:

```text
headroom =
    parent.GasLimit - threshold

excess =
    parent.GasUsed - threshold
```

Starting point:

```text
parentBF =
    max(
        parent.BaseFee,
        minBaseFee
    )
```

Increase:

```text
delta =
    floor(
        parentBF
        × excess
        /
        headroom
        /
        4
    )
```

with:

```text
delta >= 1 wei
```

Then:

```text
nextBaseFee =
    parentBF + delta
```

using saturation-safe arithmetic.

---

## 12. Emergency ramp examples

At exactly:

```text
80%
```

normal mode still applies.

Above 80%, the increase scales linearly through the remaining 20% utilization headroom.

Ignoring integer rounding:

| Parent utilization | Approx. increase |
| ---: | ---: |
| `80%` | `0%` |
| `85%` | `+6.25%` |
| `90%` | `+12.5%` |
| `95%` | `+18.75%` |
| `100%` | `+25%` |

Once utilization falls back to:

```text
<= 80%
```

the next calculated base fee returns directly to the configured minimum.

---

## 13. Zero gas limit safety

If:

```text
parent.GasLimit = 0
```

the base-fee calculation falls back to:

```text
minBaseFee
```

This avoids division by zero.

---

# RPC fee suggestions

## 14. `eth_gasPrice`

Current `v3.1.1` behavior:

```text
eth_gasPrice =
    latestHeader.BaseFee
```

The RPC does not:

- calculate the next-block base fee,
- add a default priority fee,
- apply `--price-limit`,
- average recent transaction prices.

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_gasPrice",
  "params": []
}
```

At a 100-gwei current base fee:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x174876e800"
}
```

---

## 15. Important `eth_gasPrice` next-block nuance

The TxPool does not validate new transactions against exactly the same value returned by:

```text
eth_gasPrice
```

The TxPool stores:

```text
CalculateBaseFee(currentHeader)
```

as its current admission base fee.

Its code explicitly treats this as:

```text
base fee calculated for the next block
```

Therefore:

```text
eth_gasPrice
    = current block BaseFee

TxPool baseFee
    = calculated next-block BaseFee
```

During normal utilization:

```text
<= 80%
```

these will normally converge to the current minimum.

During emergency utilization:

```text
> 80%
```

the next-block base fee can be higher.

---

## 16. Legacy transaction congestion edge case

Suppose:

```text
current block baseFee = 100 gwei
current block utilization = 100%
```

Then approximately:

```text
next block baseFee = 125 gwei
```

But:

```text
eth_gasPrice = 100 gwei
```

A new Legacy transaction constructed with exactly:

```text
gasPrice = eth_gasPrice
```

can therefore be rejected by the local TxPool as:

```text
transaction underpriced
```

because the TxPool is already validating against the next-block base fee.

This is an important XGRChain integration detail.

---

## 17. Legacy transaction recommendation

During uncongested operation:

```text
gasPrice = eth_gasPrice
```

is normally sufficient.

For congestion-aware software, prefer:

```text
DynamicFeeTx
```

or provide explicit Legacy headroom.

Applications that use Legacy transactions should be prepared to:

1. receive an underpriced error,
2. refresh the current block/base fee,
3. resubmit with a higher `gasPrice`.

---

## 18. `eth_maxPriorityFeePerGas`

Current node behavior:

```text
eth_maxPriorityFeePerGas = 0
```

Request:

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

A non-zero priority fee is not required by the current node suggestion policy.

---

## 19. Internal fee suggestion

Current `suggestFees()` returns:

```text
baseFee = latestHeader.BaseFee
tip     = 0
gasPrice = baseFee
feeCap   = 2 × baseFee
```

The multiplication for:

```text
2 × baseFee
```

is saturation-safe.

---

## 20. Dynamic-fee recommendation

A practical default for `DynamicFeeTx` is:

```text
baseFee =
    latest block baseFeePerGas

maxPriorityFeePerGas =
    0

maxFeePerGas =
    2 × baseFee
```

Because the emergency base-fee increase is bounded to at most approximately 25% per block, the `2 × baseFee` cap gives substantially more headroom than a Legacy transaction priced at exactly the current base fee.

The actual paid price is still determined by effective gas price, not by the full cap.

---

# Simulation defaults

## 21. `eth_call` and `eth_estimateGas`

When fee fields are missing during simulation, the node fills them automatically.

These defaults affect simulation only.

They do not automatically rewrite an already signed raw transaction submitted through:

```text
eth_sendRawTransaction
```

---

## 22. Dynamic-fee simulation defaults

For `DynamicFeeTx`:

If missing:

```text
GasTipCap = 0
```

If missing:

```text
GasFeeCap = 2 × latestHeader.BaseFee
```

Existing explicit values are preserved.

---

## 23. Legacy / Access List simulation defaults

If:

```text
GasPrice == nil
```

or:

```text
GasPrice <= 0
```

simulation fills:

```text
GasPrice = latestHeader.BaseFee
```

Explicit positive values are retained.

---

# Effective gas price

## 24. Legacy transaction

```text
effectiveGasPrice =
    gasPrice
```

---

## 25. Access-list transaction

```text
effectiveGasPrice =
    gasPrice
```

---

## 26. Dynamic-fee transaction

```text
effectiveGasPrice =
    min(
        maxFeePerGas,
        baseFee + maxPriorityFeePerGas
    )
```

With the normal node suggestion:

```text
maxPriorityFeePerGas = 0
```

this normally becomes:

```text
effectiveGasPrice = baseFee
```

provided:

```text
maxFeePerGas >= baseFee
```

---

# Transaction validation

## 27. DynamicFeeTx validation

The TxPool verifies:

- London is active,
- typed transactions are active,
- chain ID is correct,
- `GasFeeCap` is present,
- `GasTipCap` is present,
- both caps fit within 256 bits,
- `GasTipCap <= GasFeeCap`,
- `GasFeeCap >= next-block TxPool base fee`,
- effective gas price satisfies local `--price-limit`.

If either cap is nil:

```text
ErrUnderpriced
```

is returned.

---

## 28. Execution-layer fee-cap validation

Execution also verifies:

```text
maxFeePerGas >= block.BaseFee
```

Failure produces:

```text
max fee per gas less than block base fee
```

This is a consensus execution rule, distinct from TxPool admission.

---

## 29. Legacy and AccessList validation

When London rules are active:

```text
gasPrice >= TxPool next-block baseFee
```

is required for admission.

Access-list transactions additionally require EIP-2930 and typed-transaction support to be active.

---

## 30. Local `--price-limit`

Node operators can configure:

```text
--price-limit
```

The TxPool additionally requires:

```text
effectiveGasPrice >= priceLimit
```

This is a node-local admission policy.

It is not a network-wide consensus gas-price parameter.

---

## 31. `eth_gasPrice` does not include `--price-limit`

Current `v3.1.1` `eth_gasPrice` logic does not incorporate the local TxPool:

```text
--price-limit
```

Therefore a node configured with:

```text
priceLimit > latestHeader.BaseFee
```

can return:

```text
eth_gasPrice = latestHeader.BaseFee
```

while rejecting a transaction priced at that exact value.

Public RPC operators should account for this when using a non-zero local price limit.

---

## 32. Replacement transactions

For an existing sender/nonce combination, the TxPool compares effective gas prices.

A replacement is rejected if the existing transaction has:

```text
same or higher effective gas price
```

than the proposed replacement.

Therefore:

```text
same nonce
+
same price
```

does not constitute a valid fee bump.

---

# Transaction cost

## 33. Actual transaction fee

Final transaction fee:

```text
totalFeeRaw =
    gasUsed
    × effectiveGasPrice
```

Unused gas is refunded.

The sender does not pay:

```text
gasLimit × feeCap
```

unless all that gas is actually consumed at that effective price.

---

## 34. Simple example

```text
gasUsed = 21,000
effectiveGasPrice = 100 gwei
```

Then:

```text
totalFeeRaw =
    21,000 × 100 gwei

= 2,100,000 gwei

= 0.0021 XGR
```

---

# XGR-specific fee accounting

## 35. Fixed burn component

For every normal paid transaction, XGRChain first calculates:

```text
totalFeeRaw =
    gasUsed × effectiveGasPrice
```

Fixed burn amount:

```text
1,000 gwei
```

Applied burn:

```text
burnedApplied =
    min(
        totalFeeRaw,
        1,000 gwei
    )
```

Remaining amount:

```text
remaining =
    totalFeeRaw - burnedApplied
```

The implementation therefore never allows the fixed burn component to create a negative remainder.

---

## 36. Burn address

Default:

```text
0x0000000000000000000000000000000000000666
```

The executor credits the burn component to this address.

The term:

```text
burn
```

in this document refers to the XGRChain protocol accounting destination.

---

## 37. Donation component

Default donation address:

```text
0x0000000000000000000000000000000000000666
```

Default donation percentage:

```text
15%
```

After the fixed burn:

```text
donation =
    remaining
    × donationPercent
    / 100
```

Validator component:

```text
validator =
    remaining - donation
```

---

## 38. Dynamic donation configuration

If the configured EngineRegistry is deployed, the node reads:

```text
donationAddress
donationPercent
```

from canonical registry storage.

Valid percentage range:

```text
0..100
```

If the registry donation address is zero:

```text
donationPercent = 0
```

which disables donation.

If the registry is absent, unavailable or not deployed, the node uses the defaults.

---

## 39. Complete pre-PoS fee formula

Before FeePoolSplit:

```text
totalFeeRaw =
    gasUsed × effectiveGasPrice

burned =
    min(totalFeeRaw, 1,000 gwei)

remaining =
    totalFeeRaw - burned

donation =
    remaining × donationPercent / 100

validator =
    remaining - donation
```

Distribution:

```text
burned
    → burn address

donation
    → donation address

validator
    → block coinbase
```

---

# PoS FeePoolSplit

## 40. Activation

`FeePoolSplit` must align with the first configured PoS IBFT phase.

Mainnet:

```text
first PoS block =
    5,446,500
```

Therefore:

```text
FeePoolSplit =
    5,446,500
```

If an explicit `feePoolSplit` fork exists at a different block, node initialization fails.

If PoS exists but `feePoolSplit` is absent, the node inserts an effective fork at the first PoS block internally.

---

## 41. FeePool address

```text
0x000000000000000000000000000000000000fEE2
```

This address collects the pooled PoS validator share.

---

## 42. Validator split after PoS activation

With FeePoolSplit active:

```text
validatorImmediate =
    floor(validator / 2)

validatorPooled =
    validator - validatorImmediate
```

Distribution:

```text
validatorImmediate
    → block coinbase

validatorPooled
    → FeePool
```

Because integer division rounds down, an odd final wei goes to:

```text
validatorPooled
```

rather than the immediate coinbase component.

---

## 43. Why the FeePool exists

The immediate component compensates the current block creator.

The pooled component feeds PoS epoch reward accounting.

At epoch finalization, FeePool distribution uses the PoS reward model, including:

- epoch validator snapshots,
- effective stake,
- proposer-duty performance,
- delegation,
- validator commission,
- reward eligibility.

Detailed PoS reward rules are documented in:

```text
XGRCHAIN_Staking_PoS_Model.md
```

---

## 44. FeePool is not a permanent sink

The FeePool is not simply a burn address.

Funds placed at:

```text
0x000000000000000000000000000000000000fEE2
```

are consumed by deterministic PoS epoch reward distribution.

Current pending FeePool balance is exposed through:

```text
eth_getPosValidatorsOverview
```

as:

```text
currentEpochPendingRewards
```

---

# Receipt fee logs

## 45. Fee log address

XGRChain appends protocol fee logs at:

```text
0x000000000000000000000000000000000000fEE1
```

These logs are attached to the normal transaction receipt.

---

## 46. `XGRFeeSplit`

Every processed normal transaction receives:

```solidity
XGRFeeSplit(
    uint256 donationFee,
    uint256 validatorFee,
    uint256 burnedFee
)
```

Topic:

```text
keccak256(
    "XGRFeeSplit(uint256,uint256,uint256)"
)
```

Data order:

| Word | Field |
| ---: | --- |
| `0` | `donationFee` |
| `1` | `validatorFee` |
| `2` | `burnedFee` |

`validatorFee` here is the total validator component before its optional immediate/pooled subdivision.

---

## 47. `XGRFeeAccounting`

When FeePoolSplit is active, an additional log is emitted:

```solidity
XGRFeeAccounting(
    uint256 donationFee,
    uint256 validatorImmediateFee,
    uint256 validatorPooledFee,
    uint256 burnedFee
)
```

Data order:

| Word | Field |
| ---: | --- |
| `0` | `donationFee` |
| `1` | `validatorImmediateFee` |
| `2` | `validatorPooledFee` |
| `3` | `burnedFee` |

For post-PoS accounting, explorers should use this event when they need to distinguish immediate and pooled validator fees.

---

## 48. Fee logs are protocol-generated

These logs are appended by native execution logic.

They are not emitted by an application smart contract.

Explorer/indexer software should therefore recognize:

```text
0x000000000000000000000000000000000000fEE1
```

as a protocol accounting address.

---

# Fee examples

## 49. Normal post-PoS example

Assumptions:

```text
gasUsed = 21,000
effectiveGasPrice = 100 gwei

donationPercent = 15%
fixedBurn = 1,000 gwei
```

Total:

```text
totalFeeRaw =
    21,000 × 100 gwei

= 2,100,000 gwei
```

Fixed burn:

```text
burnedApplied =
    1,000 gwei
```

Remainder:

```text
remaining =
    2,099,000 gwei
```

Donation:

```text
donation =
    2,099,000 × 15 / 100

= 314,850 gwei
```

Validator component:

```text
validator =
    2,099,000 - 314,850

= 1,784,150 gwei
```

PoS split:

```text
validatorImmediate =
    892,075 gwei

validatorPooled =
    892,075 gwei
```

Final accounting:

| Destination | Amount |
| --- | ---: |
| Burn address | `1,000 gwei` |
| Donation address | `314,850 gwei` |
| Block coinbase | `892,075 gwei` |
| FeePool | `892,075 gwei` |

Total:

```text
2,100,000 gwei
```

---

## 50. Fee below fixed burn

If:

```text
totalFeeRaw = 500 gwei
```

then:

```text
burnedApplied = 500 gwei
remaining = 0
donation = 0
validator = 0
```

Distribution:

| Destination | Amount |
| --- | ---: |
| Burn address | `500 gwei` |
| Donation | `0` |
| Coinbase | `0` |
| FeePool | `0` |

---

# `eth_feeHistory`

## 51. Method behavior

`eth_feeHistory` returns:

- `oldestBlock`,
- `baseFeePerGas`,
- `gasUsedRatio`,
- optional reward percentiles.

Current implementation behavior:

| Condition | Behavior |
| --- | --- |
| `blockCount < 1` | Error |
| `blockCount > 1024` | Clamp to `1024` |
| newest block above head | Clamp to local head |
| percentile outside `0..100` | Error |
| percentiles not ascending | Error |
| empty block | Requested rewards are zero |

---

## 52. `gasUsedRatio`

For a sampled block:

```text
gasUsedRatio =
    GasUsed / GasLimit
```

This can be used to detect whether the chain is approaching or exceeding the XGR emergency threshold:

```text
0.80
```

---

## 53. Reward percentile semantics

Reward samples are based on:

```text
EffectiveGasTip(baseFee)
```

For the current normal XGR pricing model, priority-fee suggestions are zero, so these values may frequently be zero unless users explicitly submit transactions with a positive effective tip.

---

## 54. Final `baseFeePerGas` element

The implementation allocates:

```text
blockCount + 1
```

base-fee entries.

The final element is set to:

```text
current local header BaseFee
```

It should not be documented as a separately calculated prediction of the next XGRChain base fee.

This differs from assumptions some Ethereum tooling may make about the final `feeHistory` base-fee element.

---

# Wallet guidance

## 55. Preferred transaction type

For new integrations, prefer:

```text
DynamicFeeTx / 0x02
```

because its fee cap naturally provides headroom during the XGRChain emergency base-fee ramp.

---

## 56. Recommended DynamicFeeTx defaults

```text
baseFee =
    latest baseFeePerGas

maxPriorityFeePerGas =
    eth_maxPriorityFeePerGas
    = currently 0

maxFeePerGas =
    2 × baseFee
```

A wallet may choose a different policy, but should clearly distinguish:

```text
maximum fee cap
```

from:

```text
expected effective gas price
```

---

## 57. Legacy wallet guidance

Using:

```text
gasPrice = eth_gasPrice
```

is adequate in normal, uncongested operation.

During emergency pricing, the current-header value can lag the TxPool's calculated next-block requirement.

Legacy clients should therefore:

- refresh fees before submission,
- handle underpriced rejection,
- add headroom under congestion,
- or prefer `DynamicFeeTx`.

---

## 58. Expected versus maximum cost

For DynamicFeeTx:

```text
expectedGasPrice =
    min(
        maxFeePerGas,
        baseFee + maxPriorityFeePerGas
    )
```

Expected fee:

```text
gasUsed × expectedGasPrice
```

Maximum theoretical gas reservation should not be presented to users as if it were the final fee paid.

---

# dApp guidance

## 59. Recommended submission flow

```text
eth_chainId
        ↓
latest block / baseFeePerGas
        ↓
eth_estimateGas
        ↓
construct explicit fee fields
        ↓
sign transaction
        ↓
eth_sendRawTransaction
        ↓
eth_getTransactionReceipt
```

For accounting applications:

```text
receipt
    ↓
parse XGRFeeSplit
    ↓
parse XGRFeeAccounting if present
```

---

## 60. Handle fee errors explicitly

Applications should handle:

```text
transaction underpriced
max fee per gas less than block base fee
max priority fee per gas higher than max fee per gas
replacement transaction underpriced
```

A stale fee quote should not automatically be interpreted as:

- node failure,
- wallet failure,
- consensus failure.

---

## 61. Do not hard-code `100 gwei`

The static fallback is currently:

```text
100 gwei
```

but EngineRegistry can provide a different `minBaseFee`.

Applications should query live chain information.

---

## 62. Do not hard-code `15%` donation

Likewise:

```text
15%
```

is the implementation fallback.

When EngineRegistry is active, canonical chain state can provide another valid percentage.

For historical accounting, use the transaction's actual protocol-generated fee logs.

---

# Explorer guidance

## 63. Recommended accounting sources

| Display | Source |
| --- | --- |
| Gas used | Receipt |
| Effective gas price | Transaction/block RPC representation |
| Total fee | `gasUsed × effectiveGasPrice` |
| Burn component | `XGRFeeSplit` |
| Donation component | `XGRFeeSplit` |
| Total validator component | `XGRFeeSplit` |
| Immediate validator component | `XGRFeeAccounting` |
| Pooled validator component | `XGRFeeAccounting` |
| FeePool balance | PoS monitoring RPC |

---

## 64. Do not use Ethereum burn assumptions

XGRChain does not simply apply:

```text
baseFee × gasUsed
    → burn
```

as an Ethereum-mainnet-style accounting rule.

Instead:

```text
total transaction fee
        ↓
fixed XGR burn component
        ↓
donation component
        ↓
validator component
        ↓
PoS immediate / pooled split
```

Explorers must use XGRChain protocol semantics.

---

## 65. Failed transactions

A normal transaction that is included in a block but whose EVM execution fails still consumes gas.

Its fee accounting follows the actual:

```text
gasUsed
×
effectiveGasPrice
```

for that included transaction.

The receipt status and fee accounting are separate concepts.

---

# Node operator guidance

## 66. `--price-limit`

This controls local TxPool admission.

Increasing it can cause the node to reject transactions that other nodes may accept.

It does not modify:

- chain-wide BaseFee,
- EngineRegistry minBaseFee,
- block validity.

---

## 67. Public RPC operator warning

Because:

```text
eth_gasPrice
```

does not incorporate:

```text
--price-limit
```

public RPC operators should avoid configuring a high price limit without understanding the client impact.

Otherwise the same endpoint can:

```text
suggest one gas price
```

and:

```text
reject that price locally
```

---

## 68. Sync status

Fee suggestions should not be treated as authoritative when a node is stale.

A public RPC should verify:

```text
eth_syncing
```

and normal head progression.

---

# Common mistakes

## 69. Assuming Ethereum's 50% target model

Wrong:

```text
XGR base fee continuously adjusts around 50% utilization
```

Correct:

```text
<=80%:
    clamp to configured minimum

>80%:
    emergency ramp
```

---

## 70. Assuming `100 gwei` can never change

Wrong.

It is the current implementation fallback.

EngineRegistry can supply another value.

---

## 71. Treating `eth_gasPrice` as a guaranteed TxPool minimum

Wrong during emergency congestion.

`eth_gasPrice` returns current-header BaseFee.

TxPool admission uses calculated next-block BaseFee.

---

## 72. Assuming a priority fee is required

Current recommendation:

```text
0
```

A user may choose a non-zero value, but it is not required by the current node fee suggestion.

---

## 73. Treating `maxFeePerGas` as actual paid price

Wrong:

```text
fee =
    gasUsed × maxFeePerGas
```

Correct:

```text
fee =
    gasUsed × effectiveGasPrice
```

---

## 74. Treating the entire fee as burned

Wrong.

Use:

```text
XGRFeeSplit
```

and, after PoS activation:

```text
XGRFeeAccounting
```

---

## 75. Treating FeePool as a burn address

Wrong.

FeePool funds participate in PoS epoch reward distribution.

---

## 76. Ignoring local `--price-limit`

A transaction can satisfy chain fee rules but still be rejected by one particular node's TxPool because of its local operator price limit.

---

# Quick reference

## 77. Fee suggestions

```text
eth_gasPrice
    = latestHeader.BaseFee

eth_maxPriorityFeePerGas
    = 0

simulation DynamicFee fee cap
    = 2 × latestHeader.BaseFee
```

---

## 78. Base-fee policy

```text
effective min fee
    = EngineRegistry minBaseFee
      if valid and deployed
      else 100 gwei
```

Normal:

```text
GasUsed <= 80% GasLimit
    → next BaseFee = minBaseFee
```

Emergency:

```text
GasUsed > 80%
    → BaseFee increases proportionally

100% utilization
    → maximum approximately +25% per block
```

---

## 79. Transaction cost

```text
Legacy / AccessList:
effectiveGasPrice = gasPrice

DynamicFee:
effectiveGasPrice =
    min(
        maxFeePerGas,
        baseFee + maxPriorityFeePerGas
    )

totalFeeRaw =
    gasUsed × effectiveGasPrice
```

---

## 80. XGR fee split

```text
burned =
    min(
        totalFeeRaw,
        1,000 gwei
    )

remaining =
    totalFeeRaw - burned

donation =
    remaining × donationPercent / 100

validator =
    remaining - donation
```

---

## 81. PoS FeePool split

From mainnet block:

```text
5,446,500
```

the validator component is divided as:

```text
validatorImmediate =
    floor(validator / 2)

validatorPooled =
    validator - validatorImmediate
```

Then:

```text
validatorImmediate
    → block coinbase

validatorPooled
    → FeePool
```

FeePool:

```text
0x000000000000000000000000000000000000fEE2
```

Fee-accounting log address:

```text
0x000000000000000000000000000000000000fEE1
```

---

## 82. Integration principle

XGRChain deliberately separates:

```text
minimum network pricing
        ↓
congestion response
        ↓
transaction fee cap
        ↓
actual effective gas price
        ↓
protocol fee accounting
        ↓
PoS reward distribution
```

For correct integration:

- use live fee data,
- prefer DynamicFeeTx for congestion tolerance,
- distinguish current-header BaseFee from next-block TxPool admission pricing,
- distinguish maximum caps from actual cost,
- use receipt logs for historical fee distribution,
- do not assume Ethereum-mainnet burn semantics.
