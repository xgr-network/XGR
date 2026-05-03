# XGR Chain — Genesis & Network Configuration

**Document ID:** XGRCHAIN-GENESIS-CONFIG  
**Last updated:** 2026-05-03  
**Audience:** Node operators, protocol developers, auditors  
**Implementation status:** Mainnet  
**Source of truth:** `genesis/mainnet/genesis.json`, `xgrchain` chain configuration

---

## 1. Purpose

This document explains the **mainnet genesis and network-defining configuration** of XGR Chain.

It covers:

- genesis file structure
- chain identity
- genesis block fields
- consensus configuration
- fork activation configuration
- bootnodes
- genesis allocations
- EngineRegistry configuration
- configuration fields that define a different chain if changed

This document does **not** define the future PoS/staking model. PoS-specific validator activation, delegation, weighted voting power, rewards and slashing belong in:

- `XGRCHAIN_Staking_PoS_Model.md`

---

## 2. Source of truth

The canonical mainnet genesis file is:

```text
genesis/mainnet/genesis.json
```

The genesis file is network-defining. Any node joining XGR Chain mainnet must use the same genesis configuration. Changing genesis fields creates a different chain.

---

## 3. Genesis file structure

The genesis file has this high-level structure:

```json
{
  "name": "xgrchain",
  "genesis": {
    "nonce": "0x0000000000000000",
    "timestamp": "0x0",
    "extraData": "0x...",
    "gasLimit": "0x3938700",
    "difficulty": "0x1",
    "mixHash": "0x0000...",
    "coinbase": "0x0000000000000000000000000000000000000000",
    "alloc": {},
    "number": "0x0",
    "gasUsed": "0x00000",
    "parentHash": "0x0000...",
    "baseFee": "0x0",
    "baseFeeEM": "0x0",
    "baseFeeChangeDenom": "0x0"
  },
  "params": {
    "forks": {},
    "chainID": 1643,
    "engine": {},
    "engineRegistryAddress": "0x72cbbb5c95662510da052b98add933ff99ec820f"
  },
  "bootnodes": [],
  "alloc": {}
}
```

The file is logically split into:

| Section | Purpose |
|---|---|
| `name` | Human-readable chain name |
| `genesis` | Genesis block header fields and initial state |
| `params` | Chain parameters, forks, chain ID, consensus engine and registry addresses |
| `bootnodes` | Initial libp2p discovery peers |
| top-level `alloc` | Compatibility mirror of `genesis.alloc` |

---

## 4. Chain identity

| Field | Value |
|---|---|
| `name` | `xgrchain` |
| `params.chainID` | `1643` |
| Transaction replay protection | EIP-155 |
| Native token decimals | 18 |
| EVM compatibility | Yes |

Changing `params.chainID` breaks wallet/tooling compatibility and creates a distinct signing domain.

Mainnet transactions must be signed for:

```text
chainId = 1643
```

---

## 5. Network-defining fields

The following fields are network-defining.

Changing any of them changes the genesis hash or the protocol configuration and therefore defines a different chain:

| Field group | Examples | Effect of change |
|---|---|---|
| Chain identity | `name`, `params.chainID` | Different network identity / signing domain |
| Genesis block header | `nonce`, `timestamp`, `extraData`, `gasLimit`, `difficulty`, `mixHash`, `coinbase`, `number`, `gasUsed`, `parentHash`, `baseFee` | Different genesis block |
| Initial state | `genesis.alloc` | Different initial balances/state |
| Consensus engine | `params.engine.ibft.*` | Different consensus rules |
| Fork schedule | `params.forks.*` | Different EVM execution rules |
| Bootnodes | `bootnodes` | Does not change consensus rules, but affects default peer discovery |
| Registry addresses | `params.engineRegistryAddress`, `params.bootstrapEngineEOA` | Changes governance/config lookup behavior |

Bootnodes are operational configuration, not consensus authority. However, they are part of the distributed genesis configuration and should remain consistent across released mainnet genesis files.

---

## 6. Genesis block header fields

Mainnet genesis block fields:

| Field | Value |
|---|---|
| `genesis.nonce` | `0x0000000000000000` |
| `genesis.timestamp` | `0x0` |
| `genesis.gasLimit` | `0x3938700` |
| `genesis.gasLimit` decimal | `60,000,000` |
| `genesis.difficulty` | `0x1` |
| `genesis.mixHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `genesis.coinbase` | `0x0000000000000000000000000000000000000000` |
| `genesis.number` | `0x0` |
| `genesis.gasUsed` | `0x00000` |
| `genesis.parentHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `genesis.baseFee` | `0x0` |
| `genesis.baseFeeEM` | `0x0` |
| `genesis.baseFeeChangeDenom` | `0x0` |

The runtime base-fee behavior is not inferred only from genesis `baseFee`. The effective XGR gas behavior is defined in:

- `XRC-GAS_Gas_Price_Behavior.md`

---

## 7. Consensus configuration

Consensus configuration lives under:

```text
params.engine.ibft
```

Current mainnet values:

| Field | Value | Meaning |
|---|---:|---|
| `blockTime` | `2000000000` | nanoseconds, approximately 2 seconds |
| `epochSize` | `500` | IBFT epoch interval |
| `type` | `PoA` | current mainnet validator-set mode |
| `validator_type` | `bls` | BLS-based consensus sealing |

The consensus protocol itself is documented in:

- `XGRCHAIN_Consensus_IBFT.md`

### Important separation

The current mainnet genesis describes the existing IBFT validator setup.

The upcoming PoS/staking model must not be inferred from this genesis section. It is documented separately because it introduces different concepts:

- staking contract state
- permissionless validator join
- delegation
- weighted voting power
- micro/macro epochs
- reward and slashing logic

---

## 8. Initial validator set

IBFT requires an initial validator set. On XGR Chain mainnet this set is encoded in:

```text
genesis.extraData
```

The encoding follows Istanbul-style extra data:

```text
32 bytes vanity || RLP(IstanbulExtra)
```

`IstanbulExtra` contains the validator set and empty genesis seals.

Decoded mainnet genesis validator set:

| # | Validator address | BLS public key |
|---|---|---|
| 1 | `0x7913fdae82c678f42b98ca8076fe7d13b3edff15` | `0xb56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88` |
| 2 | `0x7e8f8fd2a198f77df298041b48d79b0df4c8b1fa` | `0xa32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71` |
| 3 | `0x82f0b6f1efbb3fc9bcde0ee5a08e01e76cc29e13` | `0x8b94120a8ae2a89a0f7deb09f266d90bf5d5152a6ee559977d7f3361a0ce1cc65b012f3a820c7f1c18a01cef9ba8ae90` |
| 4 | `0xc5cc7b4ee5b0f6524ecac177ed37b2b567180707` | `0x91bf571d3f5563976e560c5f7d9898f75a0829804ce5e212370834303c23953388f01e06d0a9da2615c5e7f1aaf10da7` |
| 5 | `0x98f8bc086454b8386788244eee9a43d5d0b4e63e` | `0xa65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1` |

These values are mainnet genesis facts. They should not be reused as examples for unrelated local networks unless intentionally cloning the mainnet genesis.

---

## 9. Genesis allocations

Initial balances are defined in:

```text
genesis.alloc
```

Balances are denominated in wei.

```text
1 native XGR unit = 10^18 wei
```

Mainnet genesis allocations:

| Address | Balance (wei) | Balance (native units) |
|---|---:|---:|
| `0x0000000000000000000000000000000000000000` | `0` | `0` |
| `0x00000000000000000000000000000000000000e1` | `1` | `0.000000000000000001` |
| `0x2A021a1B25DA25e14C4046e5BAc9375Ec3bebf8c` | `2103833846420000000000000000` | `2,103,833,846.42` |
| `0x4675EdCa3c4637E68Ed1C1776a11EB5c9828F056` | `3141592653580000000000000000` | `3,141,592,653.58` |
| `0x7818A59b2D279Fe3444B75dcE1A443C1b124c161` | `1380649000000000000000000000` | `1,380,649,000` |

### Top-level `alloc`

The mainnet genesis file also contains a top-level `alloc` object mirroring `genesis.alloc`.

For chain-state purposes, the canonical allocation is:

```text
genesis.alloc
```

The top-level `alloc` should be treated as compatibility/redundancy unless the client configuration explicitly defines otherwise.

---

## 10. Fork configuration

Fork activation lives under:

```text
params.forks
```

### 10.1 Active from genesis

The following fork features are active from block `0`:

| Fork / feature | Block |
|---|---:|
| `london` | `0` |
| `EIP150` | `0` |
| `EIP155` | `0` |
| `EIP158` | `0` |
| `byzantium` | `0` |
| `constantinople` | `0` |
| `homestead` | `0` |
| `istanbul` | `0` |
| `londonfix` | `0` |
| `petersburg` | `0` |
| `quorumcalcalignment` | `0` |
| `txHashWithType` | `0` |

This means XGR Chain starts with a modern EVM baseline and supports EIP-1559-style transaction handling from genesis.

### 10.2 Active from block `1208500`

The following features activate at block `1208500`:

| Fork / EIP | Block | Purpose |
|---|---:|---|
| `EIP2930` | `1208500` | Access-list transactions |
| `EIP2929` | `1208500` | Gas repricing for state access opcodes |
| `EIP3860` | `1208500` | Initcode metering / limit |
| `EIP3651` | `1208500` | Warm `COINBASE` |

Operationally, XGR Chain activates Berlin-style access/gas semantics and selected Shanghai execution semantics from block `1208500`.

### 10.3 Not active

| Feature | Status |
|---|---|
| `EIP4895` withdrawals | Not active |
| Ethereum beacon withdrawals | Not part of XGR Chain execution |
| Polygon bridge/rootchain forks | Not part of current XGR Chain configuration |
| PolyBFT-specific bridge/checkpoint flow | Not part of current XGR Chain configuration |

---

## 11. Gas and base-fee genesis fields

The genesis contains:

| Field | Value |
|---|---|
| `genesis.baseFee` | `0x0` |
| `genesis.baseFeeEM` | `0x0` |
| `genesis.baseFeeChangeDenom` | `0x0` |
| `params.blockGasTarget` | `0` |
| `params.burnContract` | `null` |
| `params.burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

These fields must not be interpreted as the complete fee specification.

The canonical gas and fee model is:

- `XRC-GAS_Gas_Price_Behavior.md`

---

## 12. EngineRegistry and Engine bootstrap fields

Mainnet genesis contains:

| Field | Value |
|---|---|
| `params.engineRegistryAddress` | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| `params.bootstrapEngineEOA` | `0x0000000000000000000000000000000000000000` |

The EngineRegistry is used as an on-chain source for governance-controlled parameters where supported by the client implementation.

If a registry value is unavailable or the registry is not deployed, the client must use the corresponding safe default behavior defined by the relevant module.

Do not document Engine internals here. Engine RPC behavior belongs in:

- `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md`

---

## 13. Bootnodes

Mainnet bootnodes:

| # | Multiaddr |
|---|---|
| 1 | `/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck` |

Bootnodes provide peer discovery only.

They do not grant validator rights and do not define consensus authority.

Operational recommendations:

- keep bootnodes stable
- run multiple bootnodes where possible
- separate peer discovery from validator key management
- do not rely on bootnodes for consensus safety

---

## 14. Local and test networks

Local or test networks may use different values for:

- chain ID
- bootnodes
- validator set
- premine/alloc
- block gas limit
- block time
- fork activation heights
- engine registry address

A local/test genesis must not be confused with XGR Chain mainnet genesis.

For local operation and command examples, use:

- `XGRCHAIN_Node_Operation.md`

---

## 15. Configuration and runtime flags

The old Polygon Edge parameter reference contained many flags that are either generic, operator-local, or legacy bridge/rootchain related.

The public genesis/configuration document should only define network-level fields.

Operator-local flags belong in:

- `XGRCHAIN_Node_Operation.md`

Examples:

| Flag category | Belongs here? | Target document |
|---|---:|---|
| `--chain-id` / genesis chain identity | Yes | This document |
| `--block-time` / `--epoch-size` | Yes, if part of genesis | This document |
| `--jsonrpc`, `--grpc-address` | No | Node Operation |
| `--data-dir`, `--secrets-config` | No | Node Operation |
| `--max-peers`, `--nat`, `--dns` | No | Node Operation |
| `--price-limit`, txpool flags | No | Node Operation / Operator RPC |
| Bridge/rootchain flags | No | Legacy / not part of current XGR docs |

---

## 16. Do not migrate legacy rootchain/Supernet genesis flows

The following old Polygon Edge concepts are not part of the XGR mainnet genesis specification:

- `CustomSupernetManager`
- rootchain validator allowlisting
- rootchain `StakeManager`
- WMATIC staking
- rootchain finalization of genesis validator set
- rootchain/childchain bridge deployment
- predicate contract deployment
- Polygon state sender / state receiver setup

These are legacy for XGR Chain documentation and should not be copied into this document.

---

## 17. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Introduction.md` | High-level XGR Chain overview |
| `XGRCHAIN_Chain_Spec.md` | Chain-level specification |
| `XGRCHAIN_Consensus_IBFT.md` | IBFT consensus and finality |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Standard Ethereum-compatible RPC |
| `XRC-GAS_Gas_Price_Behavior.md` | Gas and fee behavior |
| `XGRCHAIN_Node_Operation.md` | Node operation, local setup and runtime flags |
| `XGRCHAIN_Staking_PoS_Model.md` | Upcoming staking / PoS model |
