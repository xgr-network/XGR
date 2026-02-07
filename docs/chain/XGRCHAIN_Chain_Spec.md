# XGR Chain — Chain Specification

**Document ID:** XGRCHAIN-SPEC  
**Status:** Draft  
**Last updated:** 2026-02-07  
**Audience:** Protocol integrators, node operators, auditors

---

## 1. Scope

This document defines the **chain-level specification** for **XGR Chain** (`xgrchain`), including:

- Network identity
- Consensus configuration (**IBFT PoA with BLS validators**)
- Execution and fork configuration (EVM hardforks enabled from genesis)
- Genesis-defined parameters (bootnodes, allocations)
- Fee model references

This spec is intended to be **public** and can include small code excerpts where it improves precision.

---

## 2. Network identity

| Field | Value |
|---|---|
| `name` | `xgrchain` |
| `chainID` | `1643` |

**Normative behavior**
- Transactions **MUST** be signed with EIP-155 using `chainID = 1643` to prevent replay across networks.
- Client implementations **MUST** reject transactions whose signature chain ID does not match.

---

## 3. Client basis and compatibility

XGR Chain is built on **Polygon Edge** and provides:

- **EVM compatibility** (smart contracts, logs, receipts)
- Standard Ethereum transaction types (**legacy** and **EIP-1559 / type-2**)
- JSON-RPC compatibility for common endpoints (e.g., `eth_sendRawTransaction`, `eth_call`, `eth_getLogs`, etc.)

---

## 4. Execution hardfork configuration

XGR Chain enables the following EVM forks from **block 0** (genesis):

- `homestead`
- `byzantium`
- `constantinople`
- `petersburg`
- `istanbul`
- `london`
- `londonfix`
- `EIP150`, `EIP155`, `EIP158`
- `quorumcalcalignment`
- `txHashWithType`

**Implication:** the network behaves as a “modern” EVM chain from genesis, including EIP-1559-style transaction fields.

---

## 5. Consensus: IBFT (PoA, BLS validators)

### 5.1 Consensus engine selection

From `genesis.json`:

- `params.engine.ibft.type = "PoA"`
- `params.engine.ibft.validator_type = "bls"`

Meaning:

- **PoA:** validator identities are permissioned and form a fixed or governance-managed set.
- **BLS validator type:** each validator has:
  - an **ECDSA address** (20 bytes) used as identity, and
  - a **BLS public key** (48 bytes) used for aggregated commit signatures.

### 5.2 Timing and epochs

| Parameter | Value |
|---|---|
| `blockTime` | `2000000000` ns (~2.0 seconds) |
| `epochSize` | `500` blocks |

Operationally, an epoch is ~`500 * 2.0s ≈ 16.7` minutes.

### 5.3 Initial validator set

The initial validator set is encoded in the genesis block `extraData` using the Istanbul extra-data structure.

| # | Validator address (ECDSA) | BLS public key (48 bytes) |
|---|---|---|
| 1 | 0x7913fdae82c678f42b98ca8076fe7d13b3edff15 | 0xb56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88 |
| 2 | 0x7e8f8fd2a198f77df298041b48d79b0df4c8b1fa | 0xa32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71 |
| 3 | 0x82f0b6f1efbb3fc9bcde0ee5a08e01e76cc29e13 | 0x8b94120a8ae2a89a0f7deb09f266d90bf5d5152a6ee559977d7f3361a0ce1cc65b012f3a820c7f1c18a01cef9ba8ae90 |
| 4 | 0xc5cc7b4ee5b0f6524ecac177ed37b2b567180707 | 0x91bf571d3f5563976e560c5f7d9898f75a0829804ce5e212370834303c23953388f01e06d0a9da2615c5e7f1aaf10da7 |
| 5 | 0x98f8bc086454b8386788244eee9a43d5d0b4e63e | 0xa65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1 |

> **Note:** the validator list above was decoded from the genesis `extraData` RLP payload (vanity + IstanbulExtra).

---

## 6. Genesis block parameters

| Field | Value |
|---|---|
| `genesis.gasLimit` | `0x3938700` (60,000,000) |
| `genesis.difficulty` | `0x1` |
| `genesis.mixHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `genesis.parentHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `genesis.timestamp` | `0x0` |

---

## 7. Bootnodes

The network bootnodes are defined in genesis as libp2p multiaddrs:

| # | Multiaddr |
|---|---|
| 1 | /ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck |

---

## 8. Genesis allocations

Genesis `alloc` defines pre-funded accounts (balances in **wei**, i.e., 10^-18 of the native token).

| Address | Balance (wei) | Balance (native units, 18 decimals) |
|---|---|---|
| 0x0000000000000000000000000000000000000000 | 0 | 0 |
| 0x00000000000000000000000000000000000000e1 | 1 | 1.00000000000000007e-18 |
| 0x2A021a1B25DA25e14C4046e5BAc9375Ec3bebf8c | 2103833846420000000000000000 | 2,103,833,846.42000008 |
| 0x4675EdCa3c4637E68Ed1C1776a11EB5c9828F056 | 3141592653580000000000000000 | 3,141,592,653.57999992 |
| 0x7818A59b2D279Fe3444B75dcE1A443C1b124c161 | 1380649000000000000000000000 | 1,380,649,000 |

---

## 9. Fee model overview

XGR Chain uses a **modified EIP-1559** fee policy optimized for **stable, predictable base fees** under normal load:

- A governance-controlled **minimum base fee** (`minBaseFee`) is stored in an on-chain registry contract (*EngineRegistry*).
- Below a utilization threshold (**80%** of the block gas limit), the base fee is clamped to `minBaseFee`.
- Above the threshold, “emergency pricing” ramps base fee up (max ~**+25% / block**).

The full behavior is specified in:

- **`XRC-GAS_Gas_Price_Behavior.md`**

---

## 10. On-chain configuration registry (EngineRegistry)

The genesis includes:

- `params.engineRegistryAddress = 0x72cbbb5c95662510da052b98add933ff99ec820f`
- `params.bootstrapEngineEOA = 0x0000000000000000000000000000000000000000`

The chain client reads governance parameters from `engineRegistryAddress` when deployed; otherwise it falls back to safe defaults.

---

## 11. Non-goals

This spec does not define application-layer protocols (XDaLa, orchestration, etc.) and does not document closed-source Engine internals.
