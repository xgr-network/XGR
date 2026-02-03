# XRC-GAS: Gas Price Behavior

Version: 1.1  
Last updated: 2026-02-03

This document specifies the **gas price behavior** on the XGR Network for developers integrating applications.  
It explains how gas pricing works, how to estimate transaction costs, and what to expect compared to standard Ethereum-compatible networks.

---

## Table of contents

1. Overview  
2. Key differences from standard EIP-1559  
3. Gas price behavior  
4. Transaction cost estimation  
5. RPC endpoint behavior  
6. Fee structure  
7. Best practices for integration  
8. FAQ  

---

## 1. Overview

The XGR Network uses a modified EIP-1559 gas model optimized for **predictable transaction costs**.

**Key characteristics:**

- Base fee remains **stable** under normal network conditions (minBaseFee floor)
- A network-governed **minimum base fee** ensures price predictability
- Standard EIP-1559 transactions and tooling work without modification
- During high load, pricing increases to provide spam protection

For most integrations, XGR behaves like any EIP-1559-compatible chain. This document explains the specific behaviors that differ from Ethereum mainnet.

---

## 2. Key differences from standard EIP-1559

### 2.1 Compatibility

| Feature | Support |
|---------|---------|
| Transaction types | Legacy (Type 0) and EIP-1559 (Type 2) |
| Transaction fields | `gasPrice`, `maxFeePerGas`, `maxPriorityFeePerGas` |
| RPC endpoints | `eth_gasPrice`, `eth_maxPriorityFeePerGas`, `eth_feeHistory` |
| Tooling | All standard Ethereum tooling (wallets, libraries, frameworks) |
| Gas estimation | `eth_estimateGas` works as expected |
| Effective price calculation | `min(maxFeePerGas, baseFee + maxPriorityFeePerGas)` |

### 2.2 Behavioral differences

| Aspect | Standard EIP-1559 | XGR Enterprise Model |
|--------|-------------------|----------------------|
| Base fee at low load | Decreases toward zero | **Fixed at minimum** |
| Base fee at normal load | Fluctuates around target | **Fixed at minimum** |
| Price floor | None | **Network-governed minimum** |
| Priority fee (tip) | Often used for inclusion priority | **Optional; may be 0 by default** |
| Price increase trigger | Above 50% block utilization | Above **80%** block utilization |
| Maximum increase rate | +12.5% per block | **+25% per block** (above 80% only) |
| Price decrease behavior | Gradual (-12.5% per block) | **Immediate** return to minimum |
| Minimum adjustment | Governed by protocol | **Governed on-chain** (no hard fork required) |

**Important clarification:**  
On XGR, **transaction ordering and replacement follow the effective gas price** (EIP-1559-compatible).  
The network’s **fee distribution** is independent from the “tip-to-validator” mechanic used on Ethereum.

---

## 3. Gas price behavior

### 3.1 On-chain governance

The minimum base fee (`minBaseFee`) is stored in the **EngineRegistry** smart contract and can be adjusted through governance without a hard fork.

| Parameter | Source | Adjustable |
|-----------|--------|------------|
| `minBaseFee` | EngineRegistry contract | Yes (governance) |
| Congestion threshold | Protocol | Fixed at 80% |
| Maximum increase rate | Protocol | Fixed at 25%/block |

### 3.2 Normal operation (≤ 80% network utilization)

Under normal conditions:

baseFee = max(protocolBaseFee, minBaseFee)


In practice, this means baseFee is typically pinned to `minBaseFee`.

### 3.3 High load operation (> 80% network utilization)

When utilization exceeds 80%, the base fee increases progressively up to 25% per block.  
When utilization drops below 80%, baseFee returns immediately to `minBaseFee`.

---

## 4. Transaction cost estimation

### 4.1 Cost formula

Transaction Cost = Gas Used × Effective Gas Price

Effective Gas Price = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)

### 4.2 Practical note for “speed-up / cancel”

If baseFee is stable and you set `maxPriorityFeePerGas = 0`, then increasing only `maxFeePerGas` does **not** increase the effective gas price.  
To increase priority, increase `maxPriorityFeePerGas` (and ensure `maxFeePerGas ≥ baseFee + maxPriorityFeePerGas`).

---

## 5. RPC endpoint behavior

### 5.1 Gas price endpoints

| Endpoint | Returns | Description |
|----------|---------|-------------|
| `eth_gasPrice` | `baseFee + suggestedTip` | Suggested effective price for legacy-style transactions |
| `eth_maxPriorityFeePerGas` | `suggestedTip` | Suggested priority fee (may be 0 by default) |
| `eth_feeHistory` | Historical data | Base fees, gas ratios, and reward percentiles |

### 5.2 Expected values under normal load

| Field | Typical Value | Notes |
|-------|---------------|-------|
| `baseFeePerGas` (block header) | `minBaseFee` | Governed on-chain |
| `eth_gasPrice` response | `minBaseFee (+ tip)` | Tip may be 0 |
| `eth_maxPriorityFeePerGas` response | `0 (default)` | Tip is optional |
| Suggested `maxFeePerGas` | ~2× baseFee (+ tip) | Buffer for compatibility |

### 5.3 The `maxFeePerGas` buffer

Setting a higher `maxFeePerGas` does not increase cost unless it changes the effective gas price.  
Users only pay the effective price:

effective = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)


---

## 6. Fee structure

### 6.1 Fee distribution

Transaction fees are distributed using a **fixed formula**, independent of Ethereum’s “tip paid directly to validator” mechanic:


Total Fee = Gas Used × Effective Gas Price

Burn (fixed): 1000 Gwei per transaction

Remaining: Total Fee − Burn

Treasury: Remaining × donationPercent%

Validator: Remaining − Treasury


**Important:**  
`maxPriorityFeePerGas` still affects the **effective gas price** (and therefore the total fee) when it changes `baseFee + tip`.  
However, XGR does not use a separate “tip payout” channel—distribution follows the fixed formula above.

### 6.4 Fee transparency

Each transaction emits an event documenting the fee split:

| Event | Contract | Data |
|-------|----------|------|
| `XGRFeeSplit` | `0x...fEE1` | `(donationFee, validatorFee, burnedFee)` |

---

## 7. Best practices for integration

### For wallets / Safe-style UX
- For normal operation, `maxPriorityFeePerGas = 0` is acceptable.
- For fast confirmation under load, increase `maxPriorityFeePerGas` and keep `maxFeePerGas ≥ baseFee + tip`.

---

## 8. FAQ

**Q: Do priority fees (tips) affect ordering?**  
A: Yes. Ordering/replacement follows effective gas price (EIP-1559-compatible). Tips are optional but can be used to increase priority.

**Q: Does the tip go directly to validators?**  
A: Not as a separate channel. Fee distribution is handled by XGR’s fixed split mechanism.
