# XGR Chain — Chain Specification

**Document ID:** XGRCHAIN-SPEC  
**Last updated:** 2026-05-24  
**Audience:** Protocol integrators, node operators, auditors, infrastructure engineers  
**Release baseline:** `xgr-node` release tag `v2.0.5`  
**Mainnet genesis source:** `xgr-network/XGR` branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Chain-level protocol and network specification only

---

## 1. Scope

This document defines the chain-level specification for XGR Chain.

It covers:

- network identity
- published mainnet configuration
- EVM compatibility
- account model
- transaction model
- transaction signing and replay protection
- execution model
- block model
- fork activation configuration
- consensus relationship
- delegated PoS activation boundary
- validator and delegation model at chain level
- epoch and micro-epoch model
- genesis state
- bootnodes and peer discovery
- gas and fee model at specification level
- chain parameter fields
- JSON-RPC surfaces relevant to chain operation
- integration boundary for application-layer systems

This document does not define:

- node installation commands
- validator onboarding commands
- service files
- monitoring setup
- XDaLa process semantics
- XRC standards
- UI behavior

Node operation belongs to the node-operation runbook.

Exact PoS RPC schemas belong to the staking / PoS endpoint reference.

Exact gas accounting and fee distribution details belong to the dedicated gas and fee documentation.

---

## 2. Network identity

| Field | Value |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Native execution model | EVM-compatible |
| Standard RPC namespaces | `eth_*`, `net_*`, `web3_*` |
| Native token decimals | `18` |
| Transaction replay protection | EIP-155 chain ID |
| Consensus finality | IBFT deterministic finality |
| Validator participation from block `5446500` | Delegated PoS |
| Public node release baseline | `xgr-node v2.0.5` |

Transactions must be signed for:

```text
chainId = 1643
```

A transaction signed for a different chain ID is not valid for XGR Chain mainnet.

---

## 3. Public node baseline

The public node implementation is:

```text
https://github.com/xgr-network/xgr-node
```

Current public release baseline:

```text
v2.0.5
```

The public release baseline provides:

- EVM execution
- IBFT consensus networking
- delegated PoS validator participation
- validator self-staking
- delegated staking
- staking lifecycle handling
- epoch and micro-epoch accounting
- standard Ethereum JSON-RPC
- public PoS monitoring RPC methods
- genesis/configuration loading
- transaction validation
- transaction execution
- block processing
- peer networking
- local node operation primitives

The public `v2.0.5` build is a standalone chain node.

It does not require:

```text
xgrEngine
XDaLa
engine_embedded build mode
```

XDaLa and XRC are application-layer topics and are not specified in this chain-level document.

---

## 4. Published mainnet configuration

The published mainnet genesis is maintained in:

```text
Repository: xgr-network/XGR
Branch:     main
Path:       genesis/mainnet/genesis.json
```

Raw reference path:

```text
https://raw.githubusercontent.com/xgr-network/XGR/main/genesis/mainnet/genesis.json
```

The published configuration defines:

- chain ID
- genesis block
- initial allocation
- consensus engine configuration
- initial validator data
- fork activation schedule
- PoS activation point
- epoch and micro-epoch parameters
- bootnodes
- gas and base-fee genesis fields
- configured protocol addresses where applicable

A node joins the published XGR Chain network by running a compatible node release with this published chain configuration.

A node with different network-defining configuration is not running the same chain.

---

## 5. Chain configuration schema

The public node chain schema contains:

```json
{
  "name": "xgrchain",
  "genesis": {},
  "params": {},
  "bootnodes": []
}
```

Runtime genesis allocation is defined in:

```text
genesis.alloc
```

The published mainnet genesis also contains a top-level `alloc` object that mirrors `genesis.alloc`.

The node runtime allocation source is `genesis.alloc`.

---

## 6. PoA to delegated PoS transition

The published mainnet genesis defines the IBFT type schedule as:

| Phase | Type | Validator type | From | To | Deployment |
|---|---|---|---:|---:|---:|
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Delegated PoS phase | `PoS` | `bls` | `5446500` | n/a | `5446500` |

Delegated PoS activation block:

```text
5446500
```

Delegated PoS deployment block:

```text
5446500
```

IBFT remains the deterministic-finality consensus mechanism.

Delegated PoS defines validator participation, staking, delegation and validator-set evolution from block `5446500`.

---

## 7. EVM compatibility

XGR Chain executes Ethereum-compatible smart contracts through an EVM-compatible execution pipeline.

Supported compatibility areas include:

- externally owned accounts
- smart contract accounts
- contract deployment
- contract calls
- value transfers
- calldata execution
- event logs
- receipts
- nonces
- gas accounting
- Ethereum-style transaction signatures
- Ethereum-compatible JSON-RPC for common wallet, explorer and infrastructure operations

Ordinary transfers and contract calls use standard EVM transaction envelopes.

Delegated PoS does not require a special wallet-side transaction envelope for normal user transactions.

---

## 8. Account model

XGR Chain uses the Ethereum-style account model.

Account state includes:

- address
- nonce
- balance
- contract code, if present
- contract storage, if present

Execution-level account categories:

| Account type | Description |
|---|---|
| Externally owned account | Controlled by a private key; can sign transactions |
| Contract account | Contains EVM bytecode and storage; executed by transactions or calls |

Balances are denominated in wei:

```text
1 XGR = 10^18 wei
```

---

## 9. Transaction model

XGR Chain supports the standard Ethereum transaction model used by EVM wallets and tooling.

Public transaction categories:

| Transaction category | Code-level type | Support |
|---|---|---|
| Legacy transaction | `LegacyTx` / `0x00` | Yes |
| Access-list transaction | `AccessListTx` / `0x01` | Yes when active by fork configuration |
| Dynamic-fee transaction | `DynamicFeeTx` / `0x02` | Yes |
| Contract creation | `to == nil` | Yes |
| Contract call | `to != nil` with optional calldata | Yes |
| Value transfer | `value > 0`, empty calldata, non-contract-creation | Yes |

The node also defines:

| Internal type | Code-level type | Purpose |
|---|---|---|
| State transaction | `StateTx` / `0x7f` | Internal system-level execution paths |

The deterministic PoS epoch-finalization system transaction uses internal `StateTx` shape for receipt/log indexing.

Internal state transactions are not ordinary wallet transactions.

---

## 10. Transaction signing and replay protection

XGR Chain uses EIP-155 chain ID replay protection.

Mainnet signing domain:

```text
chainId = 1643
```

For typed transactions, the transaction chain ID must match the configured chain ID.

For protected legacy transactions, the `v` value encodes the chain ID according to EIP-155.

Transactions signed for another chain ID must not be accepted as valid mainnet XGR Chain transactions.

---

## 11. Transaction fee fields

XGR Chain supports Ethereum-style fee fields according to transaction type and active fork configuration.

| Field | Used by | Meaning |
|---|---|---|
| `gasPrice` | Legacy transactions | Price per gas unit |
| `maxFeePerGas` | Dynamic-fee transactions | Maximum total fee per gas unit |
| `maxPriorityFeePerGas` | Dynamic-fee transactions | Maximum priority fee per gas unit |
| `gasLimit` | All transactions | Maximum gas the sender allows the transaction to consume |
| `value` | Value transfers / contract calls | Native amount transferred with the transaction |

For dynamic-fee transactions, the effective gas price follows the EIP-1559-style relation:

```text
effectiveGasPrice = min(maxFeePerGas, maxPriorityFeePerGas + baseFee)
```

XGR Chain has XGR-specific base-fee, minimum-fee and fee-distribution behavior.

Detailed fee behavior belongs to the dedicated gas and fee documentation.

---

## 12. Execution model

XGR Chain executes transactions through an EVM-compatible state transition pipeline.

For each valid block:

1. the proposer selects and orders transactions
2. the proposer builds a candidate block
3. transactions are executed against the parent state
4. balances, nonces, storage and contract code are updated
5. logs and receipts are produced
6. gas usage and fee accounting are applied
7. the resulting state root is committed into the block header
8. validators independently verify the same block and state transition
9. the block is finalized through IBFT once quorum is reached

The proposer does not control valid state unilaterally.

A block is only valid if validators can independently reproduce and verify the state transition.

---

## 13. Block model

A block contains:

- block number
- parent hash
- timestamp
- gas limit
- gas used
- base fee field
- state root
- transaction root
- receipts root
- logs bloom
- proposer/sealer data
- consensus-specific extra data
- transactions

Genesis is block `0`.

Published genesis header values:

| Field | Value |
|---|---|
| `number` | `0x0` |
| `timestamp` | `0x0` |
| `gasLimit` | `0x3938700` |
| gas limit decimal | `60,000,000` |
| `difficulty` | `0x1` |
| `gasUsed` | `0x00000` |
| `parentHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `mixHash` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `coinbase` | `0x0000000000000000000000000000000000000000` |
| `baseFee` | `0x0` |
| `baseFeeEM` | `0x0` |
| `baseFeeChangeDenom` | `0x0` |

Changing genesis header values defines a different network.

---

## 14. Fork activation model

XGR Chain uses block-number-based fork activation.

Forks are defined under:

```text
params.forks
```

A fork is active when:

```text
blockNumber >= configuredForkBlock
```

All nodes on the same network must use the same effective fork schedule.

---

## 15. Forks active from block `0`

The published mainnet configuration activates the following execution features from genesis:

| Fork / feature | Activation block |
|---|---:|
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

---

## 16. Forks active from block `1208500`

The published mainnet configuration activates:

| Fork / EIP | Activation block | Purpose |
|---|---:|---|
| `EIP2930` | `1208500` | Access-list transaction support |
| `EIP2929` | `1208500` | Gas repricing for state access |
| `EIP3860` | `1208500` | Initcode metering / initcode size limit |
| `EIP3651` | `1208500` | Warm `COINBASE` behavior |

---

## 17. FeePoolSplit alignment

`feePoolSplit` is a supported fork constant in the node.

For XGR2.0, the node aligns `feePoolSplit` to the first PoS IBFT fork.

For mainnet:

```text
first PoS block = 5446500
feePoolSplit effective block = 5446500
```

If `feePoolSplit` is explicitly configured to a different block than the first PoS block, node initialization must fail.

If it is absent and a PoS fork exists, the node sets it internally to the first PoS block.

---

## 18. Consensus layer

XGR Chain uses IBFT as its deterministic-finality consensus protocol.

Consensus engine path:

```text
params.engine.ibft
```

IBFT provides:

- proposer selection
- block proposal
- validator voting
- quorum-based block commitment
- deterministic finality once a block is committed

Published block time:

```text
params.engine.ibft.blockTime = 2000000000 ns
```

This is approximately:

```text
2 seconds
```

IBFT remains the finality layer after delegated PoS activation.

---

## 19. Validator model

XGR Chain uses an IBFT validator set.

From block `5446500`, validator participation is driven by delegated PoS state.

At chain-spec level, delegated PoS includes:

- validator self-stake
- validator minimum stake requirements
- validator activation state
- validator deactivation state
- delegated stake
- active delegated stake
- raw delegated stake
- epoch-boundary activation
- epoch-boundary deactivation
- validator-set updates derived from active staking state

The active validator set is consensus-critical.

Validators not in the active validator set do not have IBFT voting authority for the corresponding block range.

---

## 20. Delegation model

Delegated PoS supports delegation to validators.

At chain-spec level, delegation includes:

- delegator address
- target validator address
- delegated amount
- active/inactive delegation state
- delegation activation timing
- delegation deactivation timing
- validator delegation pool configuration
- minimum delegator stake where configured
- maximum delegated stake per validator where configured
- commission basis points where configured

Exact public RPC response schemas belong to the staking / PoS endpoint reference.

Exact operator commands belong to the node-operation runbook.

---

## 21. Epoch and micro-epoch model

XGR2.0 uses epoch-based staking semantics.

Mainnet PoS epoch configuration:

| Parameter | Value |
|---|---:|
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Derived macro epoch size | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

PoS epoch size is derived from:

```text
microEpochSize * macroEpochMicroFactor
```

For mainnet:

```text
25 * 40 = 1000 blocks
```

Validator joins, deactivations and delegation effects are interpreted through the active staking and epoch rules.

---

## 22. Timing and block parameters

| Parameter | Value |
|---|---|
| Target block time | approximately 2 seconds |
| `params.engine.ibft.blockTime` | `2000000000` ns |
| Genesis gas limit | `60,000,000` |
| Genesis difficulty | `0x1` |
| Genesis parent hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis mix hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis timestamp | `0x0` |
| Delegated PoS activation block | `5446500` |
| PoS macro epoch size | `1000` blocks |

---

## 23. Genesis state

XGR Chain starts from the published genesis state.

Genesis defines:

- chain name
- chain ID
- genesis block header
- initial account allocation
- consensus engine parameters
- initial validator data
- fork activation schedule
- bootnodes
- configured protocol addresses
- gas and fee-related starting fields

Initial balances are defined in:

```text
genesis.alloc
```

Balances are denominated in wei.

The top-level allocation in the published genesis mirrors the genesis allocation.

For runtime genesis state, `genesis.alloc` is the relevant allocation object.

Changing the allocation defines a different network.

---

## 24. Initial allocation summary

Published genesis allocation entries:

| Address | Balance in wei | Balance in native units |
|---|---:|---:|
| `0x0000000000000000000000000000000000000000` | `0` | `0` |
| `0x00000000000000000000000000000000000000e1` | `1` | `0.000000000000000001` |
| `0x2A021a1B25DA25e14C4046e5BAc9375Ec3bebf8c` | `2103833846420000000000000000` | `2,103,833,846.42` |
| `0x4675EdCa3c4637E68Ed1C1776a11EB5c9828F056` | `3141592653580000000000000000` | `3,141,592,653.58` |
| `0x7818A59b2D279Fe3444B75dcE1A443C1b124c161` | `1380649000000000000000000000` | `1,380,649,000` |

---

## 25. Bootnodes and networking

Published mainnet bootnode:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes provide initial peer discovery.

They do not grant validator authority.

Consensus participation depends on active validator-set rules.

---

## 26. Gas and fee model

XGR Chain supports Ethereum-style transaction fee fields and XGR-specific fee behavior.

High-level fee fields:

| Topic | XGR behavior |
|---|---|
| Legacy fee field | `gasPrice` |
| Dynamic-fee fields | `maxFeePerGas`, `maxPriorityFeePerGas` |
| Base fee field | Present in block/genesis model |
| Genesis base fee | `0x0` |
| Genesis gas limit | `60,000,000` |
| Transaction pool price limit | Runtime node setting |
| Fee policy | XGR-specific and release/configuration-dependent |

Published genesis fee-related fields:

| Field | Value |
|---|---|
| `genesis.baseFee` | `0x0` |
| `genesis.baseFeeEM` | `0x0` |
| `genesis.baseFeeChangeDenom` | `0x0` |
| `params.blockGasTarget` | `0` |
| `params.burnContract` | `null` |
| `params.burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

---

## 27. Minimum base fee and fee-policy constants

The public `v2.0.5` node includes these XGR-specific constants:

| Constant | Value | Meaning |
|---|---:|---|
| `MinBaseFee` | `100000000000` | Static fallback minimum base fee |
| `CriticalGasThresholdPct` | `80` | Utilization threshold below which base fee remains at minimum behavior |
| `EmergencyBaseFeeChangeDenom` | `4` | Maximum emergency base-fee ramp denominator |

Effective fee behavior can also depend on active release behavior and configured registry values where supported.

---

## 28. Chain parameter fields

The chain parameter schema includes:

| Field | Purpose |
|---|---|
| `forks` | Fork activation configuration |
| `chainID` | EIP-155 chain ID |
| `engine` | Consensus engine configuration |
| `blockGasTarget` | Gas target parameter |
| `engineRegistryAddress` | Configured protocol registry address where used |
| `bootstrapEngineEOA` | Bootstrap EOA where used |
| `contractDeployerAllowList` | Contract deployer allow-list configuration |
| `contractDeployerBlockList` | Contract deployer block-list configuration |
| `transactionsAllowList` | Transaction allow-list configuration |
| `transactionsBlockList` | Transaction block-list configuration |
| `bridgeAllowList` | Bridge-related allow-list field in chain parameter schema |
| `bridgeBlockList` | Bridge-related block-list field in chain parameter schema |
| `burnContract` | Burn-contract map by activation block |
| `burnContractDestinationAddress` | Burn-contract destination address |

Whether a field has runtime effect depends on whether it is configured in the published network configuration and supported by active release behavior.

---

## 29. EngineRegistry and configured protocol addresses

Published values:

| Field | Value |
|---|---|
| `params.engineRegistryAddress` | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| `params.bootstrapEngineEOA` | `0x0000000000000000000000000000000000000000` |

A zero bootstrap EOA means no non-zero bootstrap EOA is configured in the published genesis.

The registry address is a configured protocol address for XGR-specific runtime behavior where supported by the active release.

---

## 30. Access control configuration fields

The chain parameter type supports these address-list configuration fields:

| Field | Purpose |
|---|---|
| `contractDeployerAllowList` | Contract deployer allow-list configuration |
| `contractDeployerBlockList` | Contract deployer block-list configuration |
| `transactionsAllowList` | Transaction allow-list configuration |
| `transactionsBlockList` | Transaction block-list configuration |
| `bridgeAllowList` | Bridge-related allow-list field |
| `bridgeBlockList` | Bridge-related block-list field |

The published mainnet genesis does not configure these address-list fields.

If future published configurations use these fields, their effect must be interpreted according to active release behavior.

---

## 31. Burn contract configuration fields

Published values:

| Field | Value |
|---|---|
| `burnContract` | `null` |
| `burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

Runtime behavior:

- if no burn contract map is configured, burn-contract calculation returns the zero address
- the zero address means no configured burn-contract redirection from this field
- fee distribution can still depend on other active XGR fee logic and release behavior

The published mainnet genesis does not configure a burn contract map.

---

## 32. JSON-RPC surfaces

XGR Chain exposes RPC surfaces depending on node configuration and active release capabilities.

### 32.1 Standard Ethereum-compatible RPC

Typical namespaces:

```text
eth_*
net_*
web3_*
```

This is the normal EVM compatibility surface used by wallets, explorers, scripts, indexers and applications.

### 32.2 Public PoS monitoring RPC

The public PoS monitoring methods are documented in the staking / PoS endpoint reference.

Current public PoS methods:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

These methods expose validator, stake, delegation, epoch and pool data.

Exact method parameters and response schemas belong to the staking / PoS endpoint reference.

### 32.3 Operator and diagnostic RPC

Operator and diagnostic interfaces are used for:

- syncing checks
- block height checks
- peer checks
- transaction pool checks
- validator health checks where available

Operator interfaces should be exposed carefully and are not automatically intended for public RPC.

---

## 33. Application-layer boundary

XGR Chain provides:

- EVM execution
- consensus
- finality
- gas accounting
- blocks
- transactions
- receipts
- chain state
- chain RPC

Application-layer systems may build on top of this chain substrate.

This chain specification does not define:

- XDaLa rule syntax
- XDaLa process semantics
- XDaLa encryption or grant flows
- XRC-137 details
- XRC-729 details
- application-specific workflow semantics
- UI behavior

Those topics remain outside this chain-level specification.

---

## 34. Configuration authority

The chain specification is defined by:

- published genesis configuration
- active public node release
- activated fork schedule
- official operator announcements
- deployed protocol contracts where applicable

Local runtime flags can change how a node process behaves.

They do not redefine the network.

Examples of local runtime behavior:

- data directory
- JSON-RPC bind address
- gRPC bind address
- P2P bind address
- log level
- metrics bind address
- peer limits
- sealing enabled/disabled

Examples of network-defining behavior:

- chain ID
- genesis block header
- genesis allocation
- consensus engine configuration
- PoS activation block
- validator set rules
- fork activation schedule
- configured registry addresses
- published bootnodes

A node with different network-defining configuration is not running the same chain.

---

## 35. Feature-status rule

For this public chain specification, a feature is part of mainnet only if it is:

1. implemented in the active public node release, and
2. enabled by the published mainnet configuration or official network upgrade.

Code-level existence alone is not a public mainnet guarantee.

This document does not advertise unconfigured, experimental or application-layer behavior as chain-level mainnet functionality.

---

## 36. Chain specification summary

| Category | Published value / behavior |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Public node baseline | `xgr-node v2.0.5` |
| Execution model | EVM-compatible |
| Standard RPC | `eth_*`, `net_*`, `web3_*` |
| Native decimals | `18` |
| Consensus finality | IBFT |
| Validator model before block `5446500` | Initial IBFT validator set |
| Validator model from block `5446500` | Delegated PoS |
| Target block time | approximately 2 seconds |
| IBFT `blockTime` | `2000000000` ns |
| Micro epoch size | `25` blocks |
| Macro epoch micro factor | `40` |
| PoS macro epoch size | `1000` blocks |
| Genesis gas limit | `60,000,000` |
| Genesis difficulty | `0x1` |
| Genesis base fee | `0x0` |
| Forks from block `0` | Homestead, Byzantium, Constantinople, Petersburg, Istanbul, London, LondonFix, EIP-150, EIP-155, EIP-158, QuorumCalcAlignment, txHashWithType |
| Forks from block `1208500` | EIP-2930, EIP-2929, EIP-3860, EIP-3651 |
| Public transaction types | `LegacyTx`, `AccessListTx`, `DynamicFeeTx` |
| Internal transaction type | `StateTx` |
| Public PoS RPC methods | `eth_getPosValidatorsOverview`, `eth_getPosValidatorDelegators` |
| EngineRegistry address | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| Bootstrap Engine EOA | `0x0000000000000000000000000000000000000000` |
| Bootnode count | `1` |
| Staking / PoS | Active from block `5446500` |
| Delegated staking | Active from PoS cutover |
| XDaLa/XRC details | Outside this chain specification |
