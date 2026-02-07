# XGR Chain — Genesis & Network Configuration

**Document ID:** XGRCHAIN-GENESIS  
**Status:** Draft  
**Last updated:** 2026-02-07  
**Audience:** Node operators, network maintainers, auditors

---

## 1. Purpose

This document explains how **XGR Chain** is configured via `genesis.json`, and which fields are **network-defining** (i.e., changing them creates a different chain).

---

## 2. Genesis file structure (overview)

A typical XGR Chain genesis file is a Polygon Edge chain config of the form:

```json
{
  "name": "xgrchain",
  "genesis": {
    "gasLimit": "0x3938700",
    "extraData": "0x00..00 + RLP(IstanbulExtra)",
    "alloc": {
      "...": { "balance": "..." }
    }
  },
  "params": {
    "chainID": 1643,
    "engine": {
      "ibft": {
        "type": "PoA",
        "validator_type": "bls",
        "blockTime": 2000000000,
        "epochSize": 500
      }
    },
    "engineRegistryAddress": "0x72cbbb5c95662510da052b98add933ff99ec820f"
  },
  "bootnodes": [
    "/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck"
  ]
}
```

The file is logically split into:

- `name` — network label
- `genesis` — genesis block header fields + initial state
- `params` — chain parameters (forks, chainID, consensus engine, etc.)
- `bootnodes` — initial libp2p bootnodes for peer discovery

---

## 3. Network-defining parameters (do not change lightly)

The following parameters effectively define the network identity:

1) **`params.chainID`**  
   - Current: `1643`  
   - Changing this breaks transaction signature compatibility and defines a different network for tooling.

2) **`genesis` header fields**  
   In particular: `extraData`, `gasLimit`, `difficulty`, `mixHash`, `nonce`, `timestamp`, `parentHash`.  
   Changing these changes the genesis hash → **different chain**.

3) **`params.engine.*` (consensus engine)**  
   - Current consensus: **IBFT PoA with BLS validators**  
   - Changing consensus settings changes block production and validator rules.

4) **`params.forks.*`**  
   XGR Chain activates modern EVM hardfork behavior from block 0.

---

## 4. Consensus configuration in genesis

XGR Chain consensus configuration is stored under:

- `params.engine.ibft`

Current values:

| Field | Value | Meaning |
|---|---:|---|
| `type` | `PoA` | permissioned validator set |
| `validator_type` | `bls` | BLS signatures for committed seals |
| `blockTime` | `2000000000` | duration in **nanoseconds** (~2.0 s) |
| `epochSize` | `500` | checkpoint interval for validator snapshots |

---

## 5. Bootnodes

Bootnodes are libp2p multiaddrs used for initial peer discovery:

| # | Bootnode multiaddr |
|---|---|
| 1 | /ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck |

Operational guidance:

- Bootnodes **do not** need to be validators.
- Run at least 2 geographically and network-topology diverse bootnodes in production.

---

## 6. Initial validator set in `genesis.extraData`

IBFT requires an initial validator set. For XGR Chain this is encoded in:

- `genesis.extraData`

### 6.1 Encoding (high level)

The encoding matches Istanbul-style extra data:

- `vanity` — 32 bytes
- `RLP(IstanbulExtra)` — includes the validator list and seals

### 6.2 Decoded genesis validator set

| # | Validator address (ECDSA) | BLS public key (48 bytes) |
|---|---|---|
| 1 | 0x7913fdae82c678f42b98ca8076fe7d13b3edff15 | 0xb56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88 |
| 2 | 0x7e8f8fd2a198f77df298041b48d79b0df4c8b1fa | 0xa32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71 |
| 3 | 0x82f0b6f1efbb3fc9bcde0ee5a08e01e76cc29e13 | 0x8b94120a8ae2a89a0f7deb09f266d90bf5d5152a6ee559977d7f3361a0ce1cc65b012f3a820c7f1c18a01cef9ba8ae90 |
| 4 | 0xc5cc7b4ee5b0f6524ecac177ed37b2b567180707 | 0x91bf571d3f5563976e560c5f7d9898f75a0829804ce5e212370834303c23953388f01e06d0a9da2615c5e7f1aaf10da7 |
| 5 | 0x98f8bc086454b8386788244eee9a43d5d0b4e63e | 0xa65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1 |

---

## 7. Genesis allocations (`genesis.alloc`)

`genesis.alloc` defines the initial account balances in wei (native token base units).

| Address | Balance (wei) | Balance (native units, 18 decimals) |
|---|---|---|
| 0x0000000000000000000000000000000000000000 | 0 | 0 |
| 0x00000000000000000000000000000000000000e1 | 1 | 1.00000000000000007e-18 |
| 0x2A021a1B25DA25e14C4046e5BAc9375Ec3bebf8c | 2103833846420000000000000000 | 2,103,833,846.42000008 |
| 0x4675EdCa3c4637E68Ed1C1776a11EB5c9828F056 | 3141592653580000000000000000 | 3,141,592,653.57999992 |
| 0x7818A59b2D279Fe3444B75dcE1A443C1b124c161 | 1380649000000000000000000000 | 1,380,649,000 |

### Note on duplicated `alloc`

Some genesis files also include a **top-level** `alloc` object in addition to `genesis.alloc`.  
In the chain configuration model, the canonical allocation is `genesis.alloc`.

---

## 8. EngineRegistry (on-chain configuration)

XGR Chain can read governance-controlled configuration parameters from the on-chain **EngineRegistry** contract.

Genesis fields:

- `params.engineRegistryAddress = 0x72cbbb5c95662510da052b98add933ff99ec820f`
- `params.bootstrapEngineEOA = 0x0000000000000000000000000000000000000000`

If the registry address is unset or the contract is not deployed at that address, the chain falls back to default constants (see *gas behavior* and other chain defaults).

---

## 9. Fork configuration

XGR Chain activates all relevant hardforks at block 0.  
This enables modern EVM features immediately, including EIP-1559-compatible transactions.

---

## 10. Related documents

- **Chain Spec:** `XGRCHAIN-SPEC`
- **IBFT Consensus:** `XGRCHAIN-IBFT`
- **Gas behavior:** `XRC-GAS_Gas_Price_Behavior.md`
