# XRC-GAS: Gas Price Behavior

Version: 1.0  
Last updated: 2025-01-06

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

- Gas price remains **stable** under normal network conditions
- A network-governed **minimum base fee** ensures price predictability
- Standard EIP-1559 transactions and tooling work without modification
- Spam protection activates automatically during high network load

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
| Priority fee (tip) | Required (>0) for inclusion | **Zero by default** |
| Price increase trigger | Above 50% block utilization | Above **80%** block utilization |
| Maximum increase rate | +12.5% per block | **+25% per block** (above 80% only) |
| Price decrease behavior | Gradual (-12.5% per block) | **Immediate** return to minimum |
| Minimum adjustment | Governed by protocol | **Governed on-chain** (no hard fork required) |

### 2.3 Visual comparison

```
        Standard EIP-1559                        XGR Enterprise Model

baseFee                                 baseFee
   ↑                                       ↑
   │       ╱╲    price                     │                   ╱ emergency
   │      ╱  ╲   fluctuates                │                 ╱  pricing
   │     ╱    ╲  continuously              │               ╱
   │    ╱      ╲                           │             ╱
   │   ╱        ╲                          │           ╱
   │  ╱          ╲                         │         ●  
   │ ╱            ╲  can                   │  stable  │ minBaseFee
   │╱              ╲ approach zero         │  pricing │ (on-chain)
   └─────────────────────→ load            └─────────────────────→ load
                                                     80%
```

**Key insight:** On XGR, gas price equals the on-chain minimum under normal conditions, enabling reliable cost forecasting.

---

## 3. Gas price behavior

### 3.1 On-chain governance

The minimum base fee (`minBaseFee`) is stored in the **EngineRegistry** smart contract and can be adjusted through network governance without requiring a hard fork.

| Parameter | Source | Adjustable |
|-----------|--------|------------|
| `minBaseFee` | EngineRegistry contract | Yes (governance) |
| Congestion threshold | Protocol | Fixed at 80% |
| Maximum increase rate | Protocol | Fixed at 25%/block |

Developers should query the current `minBaseFee` via RPC rather than hardcoding values.

### 3.2 Normal operation (≤ 80% network utilization)

Under normal conditions:

```
baseFee = minBaseFee (from EngineRegistry)
```

The base fee remains constant regardless of whether utilization is 10%, 50%, or 80%.

### 3.3 High load operation (> 80% network utilization)

When network utilization exceeds 80%, the base fee increases progressively:

| Network Utilization | Base Fee Behavior |
|---------------------|-------------------|
| ≤ 80% | Stable at `minBaseFee` |
| 85% | Increases ~6.25% per block |
| 90% | Increases ~12.5% per block |
| 95% | Increases ~18.75% per block |
| 100% | Increases ~25% per block (maximum) |

### 3.4 Recovery behavior

When utilization drops below 80%, the base fee **immediately** returns to `minBaseFee`. There is no gradual decay period.

---

## 4. Transaction cost estimation

### 4.1 Cost formula

```
Transaction Cost = Gas Used × Effective Gas Price

Effective Gas Price = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
```

Under normal network conditions:

```
Effective Gas Price = minBaseFee
```

**Note:** XGR suggests `maxPriorityFeePerGas = 0` by default. Users pay exactly `baseFee` per gas unit.

### 4.2 Calculation examples

The following examples use **hypothetical values** for illustration. Actual network parameters are governed on-chain.

**Assumption for examples:** `minBaseFee = 100 Gwei`

| Operation | Typical Gas | Calculation | Example Cost |
|-----------|-------------|-------------|--------------|
| Native transfer | 21,000 | 21,000 × 100 Gwei | 2,100,000 Gwei |
| ERC-20 transfer | ~65,000 | 65,000 × 100 Gwei | 6,500,000 Gwei |
| ERC-20 approve | ~46,000 | 46,000 × 100 Gwei | 4,600,000 Gwei |
| NFT transfer | ~85,000 | 85,000 × 100 Gwei | 8,500,000 Gwei |
| Simple swap | ~150,000 | 150,000 × 100 Gwei | 15,000,000 Gwei |
| Complex DeFi operation | ~300,000 | 300,000 × 100 Gwei | 30,000,000 Gwei |

**Note:** Gas consumption varies by contract implementation. Use `eth_estimateGas` for accurate estimates.

### 4.3 Cost estimation approach

| Scenario | Recommended Approach |
|----------|---------------------|
| Real-time transactions | Query `eth_gasPrice` for current effective price |
| Budget forecasting | Query current `minBaseFee` + small buffer |
| Worst-case planning | Add 25-50% buffer for potential congestion periods |

### 4.4 Comparison: Cost predictability

| Network Type | Price Variability | Budget Reliability |
|--------------|-------------------|-------------------|
| Ethereum Mainnet | High (10x+ swings common) | Low |
| L2 Rollups | Medium | Medium |
| **XGR Network** | **Low** (stable at minimum) | **High** |

---

## 5. RPC endpoint behavior

### 5.1 Gas price endpoints

| Endpoint | Returns | Description |
|----------|---------|-------------|
| `eth_gasPrice` | `baseFee` | Suggested price for legacy transactions |
| `eth_maxPriorityFeePerGas` | `0` | Priority fee (zero on XGR) |
| `eth_feeHistory` | Historical data | Base fees, gas ratios, and reward percentiles |

### 5.2 Expected values under normal load

| Field | Typical Value | Notes |
|-------|---------------|-------|
| `baseFeePerGas` (block header) | `minBaseFee` | Governed on-chain |
| `eth_gasPrice` response | `minBaseFee` | Ready-to-use for legacy TX |
| `eth_maxPriorityFeePerGas` response | `0` | No tip required |
| Suggested `maxFeePerGas` | ~2× baseFee | Buffer for compatibility |

### 5.3 The `maxFeePerGas` buffer

Standard tooling typically suggests `maxFeePerGas = 2 × baseFee` as a safety buffer. On XGR this buffer is often unnecessary due to price stability, but **does not cost extra**—users only pay the effective price.

| You specify | Network baseFee | You pay |
|-------------|-----------------|---------|
| `maxFeePerGas = 200 Gwei` | 100 Gwei | 100 Gwei (effective) |
| `maxFeePerGas = 150 Gwei` | 100 Gwei | 100 Gwei (effective) |
| `maxFeePerGas = 110 Gwei` | 100 Gwei | 100 Gwei (effective) |

---

## 6. Fee structure

### 6.1 Fee distribution

Transaction fees are distributed using a **fixed formula**, independent of EIP-1559 tip mechanics:

```
Total Fee = Gas Used × Gas Price

1. Burn (fixed):     1000 Gwei per transaction
2. Remaining:        Total Fee − 1000 Gwei
3. Treasury:         Remaining × donationPercent%
4. Validator:        Remaining − Treasury
```

**Important:** The EIP-1559 `maxPriorityFeePerGas` field does **not** determine validator rewards on XGR. Fee distribution follows the fixed formula above regardless of tip values specified in transactions.

### 6.2 Distribution parameters

| Parameter | Default | Source | Adjustable |
|-----------|---------|--------|------------|
| Burn amount | 1000 Gwei | Protocol | No |
| Donation percent | 15% | EngineRegistry | Yes (governance) |
| Donation address | On-chain | EngineRegistry | Yes (governance) |

### 6.3 Example distribution

**Assumption:** `gasUsed = 21,000`, `gasPrice = 100 Gwei`, `donationPercent = 15%`

| Step | Calculation | Amount |
|------|-------------|--------|
| Total fee | 21,000 × 100 Gwei | 2,100,000 Gwei |
| Burn (fixed) | — | 1,000 Gwei |
| Remaining | 2,100,000 − 1,000 | 2,099,000 Gwei |
| Treasury (15%) | 2,099,000 × 0.15 | 314,850 Gwei |
| Validator | 2,099,000 − 314,850 | 1,784,150 Gwei |

### 6.4 Fee transparency

Each transaction emits an event documenting the fee split:

| Event | Contract | Data |
|-------|----------|------|
| `XGRFeeSplit` | `0x...fEE1` | `(donationFee, validatorFee, burnedFee)` |

This enables transparent tracking of fee distribution for auditing and analytics.

---

## 7. Best practices for integration

### 7.1 General recommendations

| Area | Recommendation |
|------|----------------|
| Fee estimation | Use RPC endpoints; avoid hardcoding gas prices |
| Transaction type | EIP-1559 (Type 2) preferred for better UX |
| Buffer strategy | 10-20% buffer typically sufficient (vs. 100%+ on volatile networks) |
| Retry logic | Standard retry patterns; fee bumping rarely needed |

### 7.2 For wallet integrations

| Aspect | Recommendation |
|--------|----------------|
| Fee display | Show expected cost (effective price), not maximum |
| User messaging | Emphasize price stability as a feature |
| Advanced settings | Allow users to reduce `maxFeePerGas` buffer if desired |
| Stuck transactions | Rare under normal conditions; standard replacement works |

### 7.3 For dApp backends

| Aspect | Recommendation |
|--------|----------------|
| Cost budgeting | Query current `minBaseFee` + 10% buffer |
| Batch operations | Combine operations where possible to reduce per-TX overhead |
| Monitoring | Alert if `baseFeePerGas > 1.5× minBaseFee` (indicates congestion) |
| SLA planning | Use `minBaseFee` as baseline for cost guarantees |

### 7.4 For smart contract developers

| Aspect | Recommendation |
|--------|----------------|
| Gas optimization | Still valuable—reduces costs proportionally |
| Refund mechanisms | Work normally; unused gas refunded at effective price |
| Gas stipends | Standard 2300 gas stipend for `.transfer()` applies |
| Cost estimation | Stable pricing simplifies gas cost documentation |

---

## 8. FAQ

### Pricing

**Q: What is the minimum gas price?**  
A: Transactions must pay at least the current `baseFee`, which equals `minBaseFee` under normal conditions. This value is governed on-chain via the EngineRegistry contract.

**Q: Can gas prices go to zero?**  
A: No. The network enforces a minimum base fee that is always greater than zero.

**Q: Why does my wallet suggest a high `maxFeePerGas`?**  
A: Standard tooling uses a 2× buffer for volatile networks. On XGR this is usually unnecessary, but setting a high maximum does not increase actual costs.

**Q: How do I get the current minimum base fee?**  
A: Query `eth_gasPrice` for a ready-to-use value, or read `baseFeePerGas` from the latest block header.

### Network behavior

**Q: What happens during high network load?**  
A: Above 80% utilization, base fee increases up to 25% per block. This is a spam protection mechanism and typically temporary.

**Q: How quickly do prices recover after congestion?**  
A: Immediately. When utilization drops below 80%, base fee returns to `minBaseFee` in the next block.

**Q: Is the 80% threshold configurable?**  
A: No, this is a protocol parameter. Only `minBaseFee` and fee distribution parameters are adjustable via on-chain governance.

### Compatibility

**Q: Do standard Ethereum tools work?**  
A: Yes. All EIP-1559-compatible tooling works without modification.

**Q: Are there any breaking differences from Ethereum?**  
A: No breaking differences. The model is a superset of EIP-1559 with additional stability guarantees.

**Q: How do priority fees (tips) work?**  
A: XGR returns `maxPriorityFeePerGas = 0` by default. Unlike Ethereum mainnet, tips are not required for transaction inclusion. All transactions pay exactly `baseFee` per gas unit. If a non-zero tip is specified, it is accepted but does not affect transaction ordering.

---

## Appendix: Quick reference

### Model parameters

| Parameter | Value | Governance |
|-----------|-------|------------|
| Minimum base fee | On-chain (EngineRegistry) | Adjustable |
| Congestion threshold | 80% block utilization | Fixed |
| Maximum price increase | 25% per block | Fixed |
| Price decrease | Immediate to minimum | Fixed |

### Calculation reference

```
Effective Gas Price = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
Transaction Cost = Gas Used × Effective Gas Price

Under normal load (tip = 0):
  baseFee = minBaseFee (from EngineRegistry)
  Effective Gas Price = minBaseFee
```

### Fee distribution reference

```
Total Fee = Gas Used × Gas Price

Distribution (fixed formula):
  → Burn:      1000 Gwei (fixed per transaction)
  → Remaining: Total Fee − 1000 Gwei
  → Treasury:  Remaining × donationPercent%
  → Validator: Remaining − Treasury

Note: EIP-1559 tip values do NOT affect this distribution.
```
