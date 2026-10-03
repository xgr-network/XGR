# XGR Chain — Genesis & Network Configuration

**Document ID:** XGRCHAIN-GENESIS-CONFIG  
**Last updated:** 2026-10-03  
**Audience:** Node operators, protocol developers, auditors, infrastructure engineers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Genesis and network-defining XGRChain configuration

---

## 1. Purpose

This document describes the genesis and network-defining configuration of XGRChain.

The genesis configuration defines the initial chain state and the protocol parameters from which the network originates.

It covers:

- canonical genesis location,
- genesis structure,
- chain identity,
- genesis block fields,
- initial state,
- consensus configuration,
- initial validator set,
- PoA-to-PoS transition,
- PoS validator limits,
- epoch configuration,
- fork activation,
- gas and fee-related genesis fields,
- EngineRegistry configuration,
- bootnodes,
- runtime versus network-defining configuration,
- local/test-network boundaries,
- operator validation.

This document does not define:

- node service management,
- trie-pruning operations,
- validator onboarding procedures,
- XDaLa application semantics,
- XRC standards,
- interchain relayer configuration,
- Hyperlane routing or security modules,
- UI behavior.

Those topics are documented separately.

---

## 2. Canonical mainnet genesis

The canonical XGRChain mainnet genesis is maintained in:

```text
Repository: xgr-network/XGR
Branch:     main
Path:       genesis/mainnet/genesis.json
```

Raw path:

```text
https://raw.githubusercontent.com/xgr-network/XGR/main/genesis/mainnet/genesis.json
```

A node joining XGRChain mainnet must use the canonical network configuration.

The genesis file is not a local operator preference file.

It defines the network.

Changing consensus-critical genesis values creates a different chain or an incompatible node configuration.

---

## 3. Release version versus genesis version

The current public node release is:

```text
xgr-node v3.1.1
```

This does **not** mean that XGRChain uses a new mainnet genesis.

The canonical mainnet genesis remains the published:

```text
genesis/mainnet/genesis.json
```

The distinction is:

```text
xgr-node v3.1.1
    = software implementation baseline

genesis/mainnet/genesis.json
    = canonical XGRChain mainnet network configuration
```

A software upgrade does not automatically imply:

- a new chain ID,
- a new genesis hash,
- a new initial allocation,
- a new validator genesis,
- a new PoS activation block.

---

## 4. Chain-configuration schema

The public node chain configuration uses the high-level structure:

```json
{
  "name": "xgrchain",
  "genesis": {},
  "params": {},
  "bootnodes": []
}
```

Main sections:

| Section | Purpose |
| --- | --- |
| `name` | Human-readable chain name |
| `genesis` | Genesis block and initial state |
| `genesis.alloc` | Runtime genesis account allocation |
| `params` | Chain ID, forks, consensus and protocol parameters |
| `params.engine` | Consensus-engine configuration |
| `bootnodes` | Initial P2P discovery peers |

The published file additionally contains a top-level:

```text
alloc
```

object mirroring:

```text
genesis.alloc
```

For runtime genesis-state construction, `genesis.alloc` is the relevant allocation source.

---

## 5. Published mainnet structure

The current mainnet genesis has the following high-level form:

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
    "engine": {
      "ibft": {}
    },
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

The concrete contents of these objects are network-defining.

---

## 6. Chain identity

Published mainnet identity:

| Field | Value |
| --- | --- |
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Native asset | XGR |
| Native decimals | `18` |
| Execution environment | EVM-compatible |
| Transaction replay protection | EIP-155 |
| Consensus | IBFT |
| Current validator phase | Delegated PoS |

Transactions must use:

```text
chainId = 1643
```

Changing the chain ID changes the transaction signing domain and defines an incompatible network.

---

## 7. Network-defining versus operational configuration

Not every node setting belongs in genesis.

### Network-defining configuration

Examples:

- chain ID,
- genesis header,
- initial allocation,
- IBFT configuration,
- validator type schedule,
- PoS activation,
- validator limits,
- fork activation,
- EngineRegistry address.

### Local operational configuration

Examples:

- data directory,
- RPC bind address,
- P2P bind address,
- log level,
- metrics endpoint,
- peer limits,
- trie sweeper,
- state-retention window,
- service management,
- reverse proxy,
- firewall.

### External-service configuration

Examples:

- interchain relayer accounts,
- Hyperlane router addresses,
- Interchain Security Modules,
- relayer submission mode,
- checkpoint state,
- external chain RPC endpoints.

These layers must not be confused.

---

## 8. Genesis block header

Published mainnet genesis-header values:

| Field | Value |
| --- | --- |
| `nonce` | `0x0000000000000000` |
| `timestamp` | `0x0` |
| `gasLimit` | `0x3938700` |
| Gas limit decimal | `60,000,000` |
| `difficulty` | `0x1` |
| `mixHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `coinbase` | `0x0000000000000000000000000000000000000000` |
| `number` | `0x0` |
| `gasUsed` | `0x00000` |
| `parentHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `baseFee` | `0x0` |
| `baseFeeEM` | `0x0` |
| `baseFeeChangeDenom` | `0x0` |

The genesis block is the root of the chain.

Changing these fields changes the genesis block and therefore the resulting network.

---

## 9. Consensus engine

Consensus configuration is stored under:

```text
params.engine.ibft
```

Published mainnet parameters:

| Field | Value |
| --- | ---: |
| `blockTime` | `2000000000` |
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

`blockTime` is expressed in nanoseconds.

Therefore:

```text
2000000000 ns = approximately 2 seconds
```

---

## 10. Consensus phase schedule

Published IBFT phase schedule:

| Phase | Type | Validator type | From | To | Deployment |
| --- | --- | --- | ---: | ---: | ---: |
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Delegated PoS | `PoS` | `bls` | `5446500` | n/a | `5446500` |

PoS activation:

```text
5446500
```

PoS deployment:

```text
5446500
```

IBFT remains the finality protocol.

The PoS transition changes validator participation and voting-power behavior.

---

## 11. PoS validator limits

The PoS entry specifies:

```text
minValidatorCount = 4
maxValidatorCount = 25
```

These limits are part of the network's PoS configuration.

They should not be changed locally by an operator attempting to join mainnet.

---

## 12. Micro and macro epochs

Published PoS epoch parameters:

```text
microEpochSize = 25
macroEpochMicroFactor = 40
```

Derived macro-epoch size:

```text
25 × 40 = 1000 blocks
```

At the nominal two-second block target:

```text
1000 blocks ≈ 2000 seconds
≈ 33 minutes 20 seconds
```

This is only an approximate wall-clock duration.

Consensus is based on block numbers, not elapsed wall-clock time.

---

## 13. Uptime parameters

Published parameters:

| Field | Value |
| --- | ---: |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

These parameters participate in deterministic PoS uptime and voting-power behavior.

They are therefore consensus-relevant network configuration.

---

## 14. `feePoolSplit` alignment

The published genesis does not explicitly contain:

```text
feePoolSplit
```

inside `params.forks`.

However, `xgr-node v3.1.1` aligns the effective `FeePoolSplit` fork with the first PoS fork.

For mainnet:

```text
first PoS block = 5446500
```

Therefore:

```text
effective FeePoolSplit activation = 5446500
```

If `feePoolSplit` is explicitly configured to a different height from the first PoS fork, node configuration validation fails.

This prevents PoS accounting and fee-pool activation from diverging.

---

## 15. Initial validator set

The genesis validator set is encoded in:

```text
genesis.extraData
```

The IBFT genesis extra data contains:

```text
32-byte vanity prefix
+
RLP-encoded Istanbul extra data
```

The published genesis contains five initial BLS validators:

| # | Validator address | BLS public key |
| ---: | --- | --- |
| 1 | `0x7913fdae82c678f42b98ca8076fe7d13b3edff15` | `0xb56b72d028aa6d063d36917f9f18a3ee4b216e22694a701814af4fd55e6cbbe99209fc1359012e4733987ebdd0123e88` |
| 2 | `0x7e8f8fd2a198f77df298041b48d79b0df4c8b1fa` | `0xa32a09397128b801da5b88319bcca6cc33d4400e12ef7e1a94141b2360abd70306aaeb5599dd0d0984bb02f88fe20b71` |
| 3 | `0x82f0b6f1efbb3fc9bcde0ee5a08e01e76cc29e13` | `0x8b94120a8ae2a89a0f7deb09f266d90bf5d5152a6ee559977d7f3361a0ce1cc65b012f3a820c7f1c18a01cef9ba8ae90` |
| 4 | `0xc5cc7b4ee5b0f6524ecac177ed37b2b567180707` | `0x91bf571d3f5563976e560c5f7d9898f75a0829804ce5e212370834303c23953388f01e06d0a9da2615c5e7f1aaf10da7` |
| 5 | `0x98f8bc086454b8386788244eee9a43d5d0b4e63e` | `0xa65579c3b300f0d8e94e77b3915ac09f309c0a109a3aa3bb66d8beb538d733026624bf9d096e2a3d52deff78a36513d1` |

These validators define the initial IBFT validator set.

After PoS activation, validator-set evolution follows the delegated-PoS protocol rules.

---

## 16. Genesis allocation

Initial balances are defined under:

```text
genesis.alloc
```

Unit conversion:

```text
1 XGR = 10^18 wei
```

Published allocations:

| Address | Balance in wei | Native XGR |
| --- | ---: | ---: |
| `0x0000000000000000000000000000000000000000` | `0` | `0` |
| `0x00000000000000000000000000000000000000e1` | `1` | `0.000000000000000001` |
| `0x2A021a1B25DA25e14C4046e5BAc9375Ec3bebf8c` | `2103833846420000000000000000` | `2,103,833,846.42` |
| `0x4675EdCa3c4637E68Ed1C1776a11EB5c9828F056` | `3141592653580000000000000000` | `3,141,592,653.58` |
| `0x7818A59b2D279Fe3444B75dcE1A443C1b124c161` | `1380649000000000000000000000` | `1,380,649,000` |

The published top-level `alloc` mirrors `genesis.alloc`.

Operators must not modify the canonical allocation when joining mainnet.

---

## 17. EVM fork schedule

Fork activation is configured under:

```text
params.forks
```

A configured fork is active when:

```text
blockNumber >= forkBlock
```

### Active from block `0`

| Fork / feature | Block |
| --- | ---: |
| `homestead` | `0` |
| `byzantium` | `0` |
| `constantinople` | `0` |
| `petersburg` | `0` |
| `istanbul` | `0` |
| `london` | `0` |
| `londonfix` | `0` |
| `EIP150` | `0` |
| `EIP155` | `0` |
| `EIP158` | `0` |
| `quorumcalcalignment` | `0` |
| `txHashWithType` | `0` |

### Active from block `1208500`

| Fork / EIP | Block |
| --- | ---: |
| `EIP2930` | `1208500` |
| `EIP2929` | `1208500` |
| `EIP3860` | `1208500` |
| `EIP3651` | `1208500` |

All consensus nodes must resolve the same fork schedule.

---

## 18. Gas and fee-related genesis fields

Published values:

| Field | Value |
| --- | --- |
| `genesis.gasLimit` | `0x3938700` |
| Gas limit decimal | `60,000,000` |
| `genesis.baseFee` | `0x0` |
| `genesis.baseFeeEM` | `0x0` |
| `genesis.baseFeeChangeDenom` | `0x0` |
| `params.blockGasTarget` | `0` |
| `params.burnContract` | `null` |
| `params.burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

These are starting/network configuration values.

Effective runtime fee behavior also depends on:

- active fork state,
- XGR-specific base-fee logic,
- fee-pool logic,
- PoS activation,
- EngineRegistry configuration where supported.

The dedicated gas/fee documentation is authoritative for fee calculations.

---

## 19. EngineRegistry configuration

Published value:

```text
0x72cbbb5c95662510da052b98add933ff99ec820f
```

Configuration field:

```text
params.engineRegistryAddress
```

The public node loads a non-zero EngineRegistry address from chain configuration.

This provides deterministic network configuration for XGR-specific runtime logic that references the registry.

---

## 20. Bootstrap Engine EOA

Published configuration:

```text
params.bootstrapEngineEOA =
0x0000000000000000000000000000000000000000
```

A zero address means that no non-zero bootstrap Engine EOA is configured through genesis.

The public node treats bootstrap authorization separately from normal account or consensus authority.

---

## 21. Native protocol precompiles

Some XGR protocol behavior is implemented as native node precompiles.

These are not necessarily represented as genesis accounts containing EVM bytecode.

For example, `v3.1.1` registers the native interchain BLS12-381 verifier at:

```text
0x0000000000000000000000000000000000002040
```

This address is an implementation-defined native precompile.

It is **not** configured through a normal genesis contract deployment.

Therefore:

```text
eth_getCode(0x...2040)
```

does not need to return deployed contract bytecode for the precompile to exist.

---

## 22. Bootnodes

Published mainnet bootnode:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes provide initial peer discovery.

They do not:

- grant consensus authority,
- grant transaction permission,
- hold validator authority merely by being bootnodes.

A bootnode can be replaced operationally without changing transaction or execution semantics, but the published bootnode list remains part of the canonical network configuration used for initial discovery.

---

## 23. Runtime server configuration

Runtime server configuration controls the local node process.

Examples:

```text
--chain
--data-dir
--jsonrpc
--grpc-address
--libp2p
--nat
--dns
--max-peers
--log-level
--log-to
--prometheus
--seal
```

These values control local operation.

They do not change the genesis chain identity unless the `--chain` file itself points to different network-defining configuration.

---

## 24. State Trie Sweeper is not genesis configuration

The Online State Trie Sweeper is configured at node-runtime level.

Configuration fields include:

```yaml
trie_sweeper: true
trie_sweeper_retain_blocks: 10000
trie_sweeper_interval: 6h
```

Equivalent CLI controls are documented in the state-storage and node-operation documentation.

These settings affect:

- local historical-state retention,
- local trie database size,
- historical-state RPC availability.

They do **not** alter:

- genesis,
- chain ID,
- canonical state roots,
- block validity,
- consensus,
- staking,
- validator membership.

Two nodes may therefore participate in the same XGRChain while using different local trie-retention policies.

---

## 25. Interchain configuration is not mainnet genesis configuration

The XGR interchain stack uses separate deployment and runtime configuration.

Examples include:

- Hyperlane Mailboxes,
- XGR native router,
- remote-chain routers,
- Interchain Security Modules,
- validator registries,
- relayer accounts,
- relayer state and checkpoints.

These values are not part of the canonical `genesis/mainnet/genesis.json` described by this document.

The exception is any chain-level primitive implemented directly by the node, such as the native interchain BLS precompile.

The existence of such a primitive still does not make a particular bridge deployment part of genesis.

---

## 26. Runtime access-control schema fields

The node chain-parameter schema supports optional fields including:

```text
contractDeployerAllowList
contractDeployerBlockList
transactionsAllowList
transactionsBlockList
bridgeAllowList
bridgeBlockList
```

The canonical published mainnet genesis does not configure these fields.

Therefore they must not be interpreted as active mainnet access-control policy merely because the node schema supports them.

---

## 27. Burn-contract configuration

Published values:

```text
burnContract = null
```

and:

```text
burnContractDestinationAddress =
0x0000000000000000000000000000000000000000
```

These values do not configure a burn-contract map through genesis.

They also do not represent the complete XGRChain fee-distribution mechanism.

---

## 28. Local and test networks

A local or test network can intentionally use different values, including:

- chain name,
- chain ID,
- initial balances,
- validator keys,
- IBFT extra data,
- bootnodes,
- block time,
- fork heights,
- PoS activation block,
- validator limits,
- epoch settings,
- EngineRegistry address,
- gas parameters.

Such a configuration defines a separate network.

Do not modify the public mainnet genesis and then expect the resulting node to participate correctly in XGRChain mainnet.

---

## 29. Mainnet node validation checklist

Before joining XGRChain mainnet, verify:

- chain file is the canonical published mainnet configuration,
- `name = xgrchain`,
- `chainID = 1643`,
- IBFT is configured,
- `blockTime = 2000000000`,
- `microEpochSize = 25`,
- `macroEpochMicroFactor = 40`,
- `microEpochInactivityDecayBps = 9000`,
- `microEpochNominalWeightUnits = 10000`,
- first consensus phase is PoA,
- PoA range ends at `5446499`,
- PoS begins at `5446500`,
- PoS deployment is `5446500`,
- PoS validator type is `bls`,
- minimum validator count is `4`,
- maximum validator count is `25`,
- genesis gas limit is `0x3938700`,
- initial allocations match the published file,
- fork schedule matches the published file,
- EngineRegistry address matches the published file,
- bootnode list matches the intended mainnet configuration.

---

## 30. Example node start

A minimal conceptual server command:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node
```

The appropriate additional flags depend on node role.

A validator and a public RPC node should not normally use identical runtime settings.

---

## 31. Configuration change classification

Changes can be classified as follows:

| Change | Network/consensus impact |
| --- | --- |
| Chain ID | Network-defining |
| Genesis allocation | Network-defining |
| Genesis header | Network-defining |
| IBFT type schedule | Consensus-critical |
| PoS activation | Consensus-critical |
| Validator limits | Consensus-critical |
| Epoch parameters | Consensus-critical |
| Fork activation | Consensus-critical |
| EngineRegistry address | Protocol/network configuration |
| Bootnode list | Discovery configuration |
| RPC bind address | Local only |
| Metrics | Local only |
| Log level | Local only |
| Trie sweeper | Local storage only |
| Trie retention window | Local storage only |
| Interchain relayer configuration | External service configuration |
| Public reverse proxy | Infrastructure only |

Operators must distinguish consensus changes from operational changes before deployment.

---

## 32. Current mainnet configuration summary

| Category | Current value |
| --- | --- |
| Node baseline | `xgr-node v3.1.1` |
| Release commit | `1a4844b311fb856cb8c2303a40fa8aa69b560544` |
| Network | `xgrchain` |
| Chain ID | `1643` |
| Native asset | XGR |
| Decimals | `18` |
| Consensus | IBFT |
| Consensus validator type | BLS |
| PoA range | `0–5446499` |
| PoS activation | `5446500` |
| PoS deployment | `5446500` |
| PoS validator minimum | `4` |
| PoS validator maximum | `25` |
| Block time target | approximately 2 seconds |
| Micro epoch | `25` blocks |
| Macro epoch factor | `40` |
| Macro epoch | `1000` blocks |
| Inactivity decay | `9000` bps |
| Nominal uptime weight | `10000` |
| Genesis gas limit | `60,000,000` |
| EngineRegistry | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| Bootstrap Engine EOA | zero address |
| Effective `feePoolSplit` activation | `5446500` |
| Interchain BLS precompile | `0x2040` |
| Bootnodes | `1` published mainnet entry |
| Trie pruning | Runtime-only |
| Interchain relayers | External-service configuration |

---

## 33. Design principle

The XGRChain configuration model separates:

```text
network identity
```

from:

```text
local node operation
```

and from:

```text
external services
```

Genesis determines the chain.

Consensus configuration determines how that chain reaches finality.

Runtime settings determine how one node operates.

External service configuration determines how systems such as interchain infrastructure interact with the chain.

These boundaries must remain explicit in production documentation and operations.
