# XGR Chain — Genesis & Network Configuration

**Document ID:** XGRCHAIN-GENESIS-CONFIG  
**Last updated:** 2026-05-03  
**Audience:** Node operators, protocol developers, auditors, infrastructure engineers  
**Implementation status:** Published mainnet configuration for the current public baseline; staking/PoS configuration is development/preview until activated by an official release  
**Source of truth:** Published XGR Chain genesis file, public `xgr-network/xgr-node` releases, and official XGR Network operator announcements

---

## 1. Purpose

This document explains the genesis and network-defining configuration of XGR Chain.

The genesis configuration defines the initial state and protocol parameters of the network.

It covers:

- genesis file location
- genesis file structure
- chain identity
- network-defining fields
- genesis block header fields
- consensus configuration
- initial validator set
- genesis allocations
- fork activation configuration
- gas and base-fee genesis fields
- EngineRegistry and bootstrap fields
- bootnodes
- runtime configuration boundaries
- staking/PoS configuration status

---

## 2. Canonical genesis file

The canonical published mainnet genesis file is:

```text
genesis/mainnet/genesis.json
```

A node joining the published XGR Chain network must use the same genesis configuration.

Changing network-defining genesis fields creates a different network identity and prevents the node from joining the same chain.

The genesis file is not a local operator preference file. It defines the network.

---

## 3. Genesis file structure

The published genesis file has this high-level structure:

```json
{
  "name": "xgrchain",
  "genesis": {
    "nonce": "0x0000000000000000",
    "timestamp": "0x0",
    "extraData": "0x...",
    "gasLimit": "0x3938700",
    "difficulty": "0x1",
    "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "coinbase": "0x0000000000000000000000000000000000000000",
    "alloc": {},
    "number": "0x0",
    "gasUsed": "0x00000",
    "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "baseFee": "0x0",
    "baseFeeEM": "0x0",
    "baseFeeChangeDenom": "0x0"
  },
  "params": {
    "forks": {},
    "chainID": 1643,
    "engine": {},
    "blockGasTarget": 0,
    "engineRegistryAddress": "0x72cbbb5c95662510da052b98add933ff99ec820f",
    "bootstrapEngineEOA": "0x0000000000000000000000000000000000000000",
    "burnContract": null,
    "burnContractDestinationAddress": "0x0000000000000000000000000000000000000000"
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
| `genesis.alloc` | Initial account allocation used for genesis state |
| `params` | Chain parameters, forks, chain ID, consensus engine and configured protocol addresses |
| `bootnodes` | Initial peer-discovery entries |
| top-level `alloc` | Published mirror of the initial allocation; runtime genesis state is defined by `genesis.alloc` |

The node imports the chain configuration from the JSON file and expects exactly one configured consensus engine.

---

## 4. Chain identity

| Field | Value |
|---|---|
| `name` | `xgrchain` |
| `params.chainID` | `1643` |
| Transaction replay protection | EIP-155 chain ID |
| Native token decimals | 18 |
| Execution model | EVM-compatible |
| Standard RPC model | Ethereum-compatible JSON-RPC |

Mainnet transactions must be signed for:

```text
chainId = 1643
```

Changing `params.chainID` changes the signing domain and defines a different network.

---

## 5. Network-defining fields

The following field groups define the network.

Changing them changes either the genesis block, protocol behavior, validator configuration, or network identity.

| Field group | Examples | Effect of change |
|---|---|---|
| Chain identity | `name`, `params.chainID` | Different network identity / signing domain |
| Genesis block header | `nonce`, `timestamp`, `extraData`, `gasLimit`, `difficulty`, `mixHash`, `coinbase`, `number`, `gasUsed`, `parentHash`, `baseFee` | Different genesis block |
| Initial state | `genesis.alloc` | Different initial balances/state |
| Consensus engine | `params.engine.ibft.*` | Different consensus behavior |
| Fork schedule | `params.forks.*` | Different EVM execution rules |
| Registry fields | `params.engineRegistryAddress`, `params.bootstrapEngineEOA` | Different configured registry/bootstrap behavior |
| Fee-related genesis fields | `params.blockGasTarget`, `burnContract`, `burnContractDestinationAddress` | Different fee/gas policy baseline |
| Bootnodes | `bootnodes` | Different default peer discovery configuration |

Bootnodes support initial peer discovery. They do not grant validator authority.

---

## 6. Genesis block header fields

Published mainnet genesis block fields:

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

The genesis header is the root of the chain. A node with different genesis header values will not be on the same network.

---

## 7. Consensus configuration

Consensus configuration is stored under:

```text
params.engine.ibft
```

Published mainnet values:

| Field | Value | Meaning |
|---|---:|---|
| `blockTime` | `2000000000` | Nanoseconds; approximately 2 seconds |
| `epochSize` | `500` | IBFT epoch interval |
| `type` | `PoA` | Current published validator-set mode |
| `validator_type` | `bls` | BLS-based consensus sealing |

Operational estimate:

```text
500 blocks * 2 seconds ≈ 1000 seconds ≈ 16.7 minutes
```

The current published genesis configures IBFT with BLS validators and a PoA-style validator set.

Staking/PoS validator participation is a separate development/preview track until activated by an official release and corresponding published configuration.

---

## 8. Initial validator set

IBFT requires an initial validator set.

In the published XGR Chain genesis, the initial validator set is encoded in:

```text
genesis.extraData
```

The structure follows Istanbul-style extra data:

```text
32 bytes vanity || RLP(IstanbulExtra)
```

`IstanbulExtra` contains:

- initial validator addresses
- BLS public keys
- empty genesis seal fields

Decoded published mainnet genesis validator set:

| # | Validator address | BLS public key |
|---:|---|---|
| 1 | `0x7913fdae82c678f42b98ca8076fe7d13b3edff15` | `0xb56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88` |
| 2 | `0x7e8f8fd2a198f77df298041b48d79b0df4c8b1fa` | `0xa32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71` |
| 3 | `0x82f0b6f1efbb3fc9bcde0ee5a08e01e76cc29e13` | `0x8b94120a8ae2a89a0f7deb09f266d90bf5d5152a6ee559977d7f3361a0ce1cc65b012f3a820c7f1c18a01cef9ba8ae90` |
| 4 | `0xc5cc7b4ee5b0f6524ecac177ed37b2b567180707` | `0x91bf571d3f5563976e560c5f7d9898f75a0829804ce5e212370834303c23953388f01e06d0a9da2615c5e7f1aaf10da7` |
| 5 | `0x98f8bc086454b8386788244eee9a43d5d0b4e63e` | `0xa65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1` |

These values are part of the published network genesis.

Validator operation after genesis depends on the active consensus and validator-set rules of the running network.

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

Published mainnet genesis allocations:

| Address | Balance in wei | Balance in native units |
|---|---:|---:|
| `0x0000000000000000000000000000000000000000` | `0` | `0` |
| `0x00000000000000000000000000000000000000e1` | `1` | `0.000000000000000001` |
| `0x2A021a1B25DA25e14C4046e5BAc9375Ec3bebf8c` | `2103833846420000000000000000` | `2,103,833,846.42` |
| `0x4675EdCa3c4637E68Ed1C1776a11EB5c9828F056` | `3141592653580000000000000000` | `3,141,592,653.58` |
| `0x7818A59b2D279Fe3444B75dcE1A443C1b124c161` | `1380649000000000000000000000` | `1,380,649,000` |

The published file also contains a top-level `alloc` object with the same balances.

For runtime genesis state, use:

```text
genesis.alloc
```

The top-level `alloc` should remain consistent with `genesis.alloc` in the published file.

---

## 10. Fork configuration

Fork activation is defined under:

```text
params.forks
```

A fork is active for a block when the current block number is greater than or equal to the configured activation block.

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

This means XGR Chain starts with a modern EVM baseline and EIP-155 transaction replay protection from genesis.

### 10.2 Active from block `1208500`

The following features activate at block `1208500`:

| Fork / EIP | Block | Purpose |
|---|---:|---|
| `EIP2930` | `1208500` | Access-list transactions |
| `EIP2929` | `1208500` | Gas repricing for state access opcodes |
| `EIP3860` | `1208500` | Initcode metering / limit |
| `EIP3651` | `1208500` | Warm `COINBASE` |

The activation block is part of the published network configuration.

Nodes using a different fork schedule will execute transactions under different rules.

---

## 11. Gas and base-fee genesis fields

The published genesis contains the following gas and fee-related fields:

| Field | Value |
|---|---|
| `genesis.gasLimit` | `0x3938700` |
| `genesis.gasLimit` decimal | `60,000,000` |
| `genesis.baseFee` | `0x0` |
| `genesis.baseFeeEM` | `0x0` |
| `genesis.baseFeeChangeDenom` | `0x0` |
| `params.blockGasTarget` | `0` |
| `params.burnContract` | `null` |
| `params.burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

The genesis values define the starting configuration.

Runtime gas and fee behavior may also depend on:

- active fork configuration
- transaction type
- minimum fee logic
- transaction pool admission rules
- fee distribution logic
- configured registry values where supported

The effective fee behavior must be interpreted together with the active node release and the published gas policy.

---

## 12. EngineRegistry and bootstrap fields

The published genesis contains:

| Field | Value |
|---|---|
| `params.engineRegistryAddress` | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| `params.bootstrapEngineEOA` | `0x0000000000000000000000000000000000000000` |

These fields are part of XGR Chain configuration.

The public baseline node type includes these fields in the chain parameters, and the node import path applies genesis-driven registry configuration when those fields are present.

The registry address is used as a configured on-chain source for XGR-specific runtime parameters where supported by the active release stack.

A zero bootstrap EOA means no non-zero bootstrap EOA is configured in the published genesis.

---

## 13. Bootnodes

Published mainnet bootnodes:

| # | Multiaddr |
|---:|---|
| 1 | `/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck` |

Bootnodes provide initial peer discovery.

They are not validator keys and do not define consensus authority.

Operational meaning:

- new nodes can use bootnodes to discover peers
- validators still require valid validator configuration and active validator-set membership
- RPC nodes can use bootnodes to join and follow the network
- changing bootnodes affects default connectivity, not transaction validity

---

## 14. Runtime configuration boundary

The genesis file defines the network.

Runtime flags define how a local node process runs.

Examples of runtime settings:

| Runtime setting | Meaning |
|---|---|
| `--data-dir` | Local node database path |
| `--jsonrpc` | Local JSON-RPC bind address |
| `--grpc-address` | Local gRPC bind address |
| `--libp2p` | Local P2P bind address |
| `--nat` | Public IP advertised to peers |
| `--dns` | DNS address advertised to peers |
| `--max-peers` | Local peer limit |
| `--log-level` | Local logging verbosity |
| `--log-to` | Local log file path |
| `--prometheus` | Local metrics bind address |
| `--seal` | Whether this node attempts block sealing |

Changing runtime flags can change local node behavior.

Changing genesis fields changes network identity or protocol behavior.

Operators must not treat runtime flags as a substitute for published genesis configuration.

---

## 15. Validator and staking configuration status

The published mainnet genesis currently configures:

```text
params.engine.ibft.type = PoA
params.engine.ibft.validator_type = bls
```

This is the current published baseline for the genesis validator set.

Staking / PoS functionality is a development or preview component unless activated through:

- an official XGR Network release
- a published network configuration update
- explicit operator instructions

A staking-enabled release may introduce additional concepts such as:

- validator staking state
- delegated stake
- stake-weighted voting power
- validator join rules
- validator activation/deactivation rules
- epoch-based staking transitions
- staking-related RPC endpoints

Those semantics must be interpreted according to the release that activates them.

They are not inferred from the current published mainnet genesis shown in this document.

---

## 16. Local and test network configuration

Local and test networks may intentionally use different values.

Examples:

- different `name`
- different `params.chainID`
- different `genesis.alloc`
- different `genesis.extraData`
- different validator set
- different bootnodes
- different fork activation heights
- different block time
- different epoch size
- different registry address
- different fee configuration

A local or test genesis defines a separate network.

Do not use a local/test genesis for a public network node.

Do not use the public mainnet genesis as an editable template unless the goal is to create a separate network.

---

## 17. Operator validation checklist

Before starting a node on the published XGR Chain network, verify:

- the genesis file path is correct
- the genesis file is the published file for the target network
- `name` is `xgrchain`
- `params.chainID` is `1643`
- `params.engine.ibft` exists
- `params.engine.ibft.blockTime` is `2000000000`
- `params.engine.ibft.epochSize` is `500`
- `params.engine.ibft.validator_type` is `bls`
- `genesis.gasLimit` is `0x3938700`
- `bootnodes` contain the published peer-discovery entry
- fork activation values match the published configuration
- node runtime flags point to this genesis file through `--chain`
- validator nodes use the correct validator key material
- non-validator nodes do not use validator signing material

Example server reference:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node
```

Node role, RPC exposure, sealing behavior, metrics and logging are runtime-operation topics and must be configured according to the intended node role.

---

## 18. Summary

The published XGR Chain genesis defines:

| Category | Published value / behavior |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Execution model | EVM-compatible |
| Consensus engine | IBFT |
| Current validator mode | `PoA` in published genesis |
| Validator type | `bls` |
| Block time | `2000000000` ns |
| Epoch size | `500` blocks |
| Genesis gas limit | `60,000,000` |
| Forks from block 0 | London, EIP-150, EIP-155, EIP-158, Byzantium, Constantinople, Homestead, Istanbul, LondonFix, Petersburg, QuorumCalcAlignment, txHashWithType |
| Forks from block 1208500 | EIP-2930, EIP-2929, EIP-3860, EIP-3651 |
| EngineRegistry address | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| Bootnode count | `1` |
| Genesis allocation source | `genesis.alloc` |

This file defines the published network baseline.

Any future staking/PoS activation requires a matching official release and published configuration update.
