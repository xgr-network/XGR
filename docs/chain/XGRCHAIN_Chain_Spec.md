# XGR Chain — Chain Specification

**Document ID:** XGRCHAIN-SPEC  
**Last updated:** 2026-05-24  
**Audience:** Protocol integrators, node operators, auditors, infrastructure engineers  
**Implementation status:** XGR2.0 mainnet baseline with delegated PoS active  
**Source of truth:** Published XGR Chain mainnet configuration, public `xgr-network/xgr-node` branch `XGR2.0`, and official XGR Network operator announcements

---

## 1. Scope

This document defines the chain-level specification for **XGR Chain**.

It covers:

- network identity
- EVM compatibility
- account and transaction model
- transaction signing and replay protection
- execution model
- fork activation configuration
- genesis-level parameters
- consensus-layer relationship
- delegated PoS activation status
- validator and delegation model at chain level
- timing and block parameters
- genesis block semantics
- bootnodes and peer discovery
- gas and fee model at specification level
- chain parameter fields
- JSON-RPC surfaces relevant to chain operation
- chain-level integration boundaries for XDaLa and XRC components

This document is the protocol-level overview of XGR Chain.

Exact operator commands, service files, key handling, runtime flags, monitoring, backups and troubleshooting belong to node-operation documentation.

Exact endpoint schemas belong to their respective RPC references.

Exact gas accounting and fee distribution details belong to the dedicated gas specification.

XDaLa-specific process semantics, rule syntax, orchestration logic, encryption/grant flows and XRC standard definitions are outside the scope of this document and belong to their own documentation.

---

## 2. Network identity

| Field | Value |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Native execution model | EVM-compatible |
| Standard RPC namespace | `eth_*`, `net_*`, `web3_*` |
| XGR extension RPC namespace | `xgr_*` where supported by the active node release |
| Native token decimals | 18 |
| Transaction replay protection | EIP-155 chain ID |
| Consensus finality | IBFT deterministic finality |
| Validator participation model | Delegated PoS active from XGR2.0 cutover |

Transactions must be signed for the configured XGR Chain ID:

```text
chainId = 1643
```

The chain ID is part of the signing domain.

A transaction signed for a different chain ID is not valid for XGR Chain.

---

## 3. Public baseline and release status

XGR Chain separates:

1. the public node implementation
2. the published mainnet configuration
3. active chain-level protocol behavior
4. XGR application-layer systems documented elsewhere

The current public node baseline for the delegated PoS rollout is:

```text
xgr-network/xgr-node
```

Reference branch:

```text
XGR2.0
```

This baseline provides:

- EVM execution
- IBFT consensus networking
- delegated PoS validator participation
- validator self-staking
- delegated staking
- staking lifecycle handling
- epoch and micro-epoch accounting
- standard Ethereum JSON-RPC
- PoS monitoring RPC methods
- genesis/configuration loading
- transaction validation
- transaction execution
- block processing
- peer networking
- local node operation primitives

The previous classification of staking and delegated PoS as development or preview is obsolete for the XGR2.0 mainnet baseline.

---

## 4. Published configuration

The published chain configuration defines:

- chain ID
- genesis block
- initial allocation
- consensus engine configuration
- validator set at genesis
- fork activation schedule
- PoS activation point
- epoch and micro-epoch parameters
- bootnodes
- gas and base-fee genesis fields
- configured protocol addresses where applicable

A node joins the published XGR Chain network by running a compatible node release with the published genesis configuration.

A node with a different network-defining configuration is not running the same chain.

---

## 5. PoA to delegated PoS transition

XGR Chain originally operated with an IBFT validator set configured through genesis.

With XGR2.0, delegated PoS was rolled out to mainnet.

The mainnet delegated PoS cutover block is:

```text
5446500
```

Interpretation:

| Phase | Block range | Validator model |
|---|---:|---|
| Pre-XGR2.0 | before `5446500` | Genesis/static IBFT validator set |
| XGR2.0 and later | from `5446500` onward | Delegated PoS validator participation with IBFT finality |

IBFT remains the consensus finality mechanism.

Delegated PoS defines validator participation, staking, delegation and validator-set evolution after the cutover.

The cutover block is network-defining. Documentation, tooling and operator material must use block `5446500`.

---

## 6. EVM compatibility

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

The chain is intended to be usable with standard EVM tooling, subject to the active fork configuration and XGR-specific fee behavior.

Delegated PoS does not require a non-standard Ethereum wallet transaction envelope for ordinary transfers and contract calls.

---

## 7. Account model

XGR Chain uses the Ethereum-style account model.

Account state includes:

- address
- nonce
- balance
- contract code, if present
- contract storage, if present

Two account categories exist at execution level:

| Account type | Description |
|---|---|
| Externally owned account | Controlled by a private key; can sign transactions |
| Contract account | Contains EVM bytecode and storage; executed by transactions or calls |

Balances are denominated in wei.

```text
1 XGR = 10^18 wei
```

---

## 8. Transaction model

XGR Chain supports the standard Ethereum transaction model used by EVM-compatible wallets and tooling.

Supported public transaction categories include:

| Transaction category | Support | Notes |
|---|---|---|
| Legacy transaction | Yes | Uses `gasPrice` |
| EIP-155 protected transaction | Yes | Uses chain ID replay protection |
| Access-list transaction | Yes, when active by fork configuration | Uses EIP-2930 access list semantics |
| Dynamic fee / type-2 transaction | Yes | Uses `maxFeePerGas` and `maxPriorityFeePerGas` |
| Contract creation | Yes | `to` is empty / nil |
| Contract call | Yes | `to` is set and calldata may be present |
| Value transfer | Yes | Transfers native balance between accounts |

The node implementation also contains an internal state transaction type used by system-level execution paths.

Internal state transactions are not normal wallet transactions.

For PoS epoch finalization, the node implementation uses a deterministic internal system transaction shape for receipt/log indexing.

---

## 9. Transaction signing and replay protection

XGR Chain uses EIP-155 chain ID replay protection.

For XGR Chain mainnet:

```text
chainId = 1643
```

For typed transactions, the transaction chain ID must match the configured chain ID.

For protected legacy transactions, the `v` value encodes the chain ID according to EIP-155.

The effective signing domain is therefore chain-specific.

A transaction signed for another chain ID must not be accepted as a valid XGR Chain transaction.

---

## 10. Transaction fee fields

XGR Chain supports Ethereum-style fee fields according to transaction type and active fork configuration.

| Field | Used by | Meaning |
|---|---|---|
| `gasPrice` | Legacy transactions | Price per gas unit |
| `maxFeePerGas` | Dynamic fee transactions | Maximum total fee per gas unit |
| `maxPriorityFeePerGas` | Dynamic fee transactions | Maximum priority fee per gas unit |
| `gasLimit` | All transactions | Maximum gas the sender allows the transaction to consume |
| `value` | Value transfers / contract calls | Native amount transferred with the transaction |

For dynamic fee transactions, effective gas price follows the EIP-1559-style relation:

```text
effectiveGasPrice = min(maxFeePerGas, maxPriorityFeePerGas + baseFee)
```

XGR Chain may apply XGR-specific base-fee, minimum-fee and fee-distribution behavior depending on the active release and configuration.

Detailed fee behavior belongs to the dedicated gas and fee documentation.

---

## 11. Execution model

XGR Chain executes transactions through an EVM-compatible state transition pipeline.

For each valid block:

1. the proposer selects and orders transactions
2. the proposer builds a candidate block
3. transactions are executed against the parent state
4. account balances, nonces, storage and contract code are updated
5. logs and receipts are produced
6. gas usage and fee accounting are applied
7. the resulting state root is committed into the block header
8. validators independently verify the same block and state transition
9. the block is finalized through IBFT once quorum is reached

The proposer does not control valid state unilaterally.

A block is only valid if other validators can independently reproduce and verify the state transition.

---

## 12. Block model

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

The genesis block is block `0`.

The published genesis block defines the initial header fields.

Known published genesis header values:

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

## 13. Execution fork configuration

XGR Chain uses a fork activation model.

Forks are activated by block number.

A fork is active for a block when:

```text
blockNumber >= configuredForkBlock
```

Fork activation is defined in the published chain configuration under:

```text
params.forks
```

Nodes must use the same fork activation schedule to remain execution-compatible with the published network.

---

## 14. Forks active from block 0

The following execution features are active from genesis in the published chain configuration:

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

This means XGR Chain starts with a modern EVM baseline from block `0`.

---

## 15. Forks active from block 1208500

The following execution features activate at block `1208500`:

| Fork / EIP | Activation block | Purpose |
|---|---:|---|
| `EIP2930` | `1208500` | Access-list transaction support |
| `EIP2929` | `1208500` | Gas repricing for state access |
| `EIP3860` | `1208500` | Initcode metering / initcode size limit |
| `EIP3651` | `1208500` | Warm `COINBASE` behavior |

Nodes must use the same fork activation schedule to remain execution-compatible with the published network.

---

## 16. Future fork entries

The node codebase may contain support for additional fork constants or feature flags before those features are activated on the published network.

A fork feature is part of the active chain specification only when it is present in the published chain configuration or activated by an official network upgrade.

This rule prevents code-level availability from being confused with network-level activation.

---

## 17. Consensus layer

XGR Chain uses **IBFT** as its deterministic-finality consensus protocol.

The consensus engine is configured under:

```text
params.engine.ibft
```

IBFT provides:

- proposer selection
- block proposal
- validator voting
- quorum-based block commitment
- deterministic finality once a block is committed

Target block time in the published configuration is approximately:

```text
2 seconds
```

IBFT is still the consensus finality layer after delegated PoS activation.

Delegated PoS changes validator-set participation and weighting, not the finality protocol itself.

---

## 18. Consensus and execution relationship

Consensus and execution are separate but linked.

Execution determines whether a block is valid.

Consensus determines whether a valid block becomes finalized.

High-level flow:

1. the proposer builds a candidate block
2. the EVM execution pipeline computes the resulting state
3. validators independently verify the candidate block
4. validators participate in IBFT consensus
5. once quorum is reached, the block is committed
6. the committed block is final under IBFT assumptions

A validator must not vote for a block whose state transition it cannot verify.

---

## 19. Validator model

XGR Chain uses an IBFT validator set.

Before the XGR2.0 cutover, validator participation is based on the genesis/static IBFT validator model.

From block `5446500`, delegated PoS validator participation is active.

The delegated PoS validator model includes:

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

Validators that are not in the active validator set do not have IBFT voting authority for the corresponding block range.

---

## 20. Delegation model

Delegated PoS supports delegator participation.

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

Delegation affects staking-state accounting according to the active staking rules.

Exact endpoint schemas and return fields belong to the staking / PoS endpoint reference.

---

## 21. Epoch and micro-epoch model

XGR2.0 uses epoch-based staking semantics.

At a high level:

- validator joins do not become consensus-effective immediately in the same block
- validator joins become effective at an epoch boundary according to staking rules
- validator deactivations become effective at an epoch boundary according to staking rules
- delegation changes can affect active delegated stake according to epoch rules
- micro-epoch accounting is used for uptime-related weighting where configured
- PoS RPC views expose epoch and micro-epoch fields

The node resolves PoS epoch size from PoS-specific IBFT engine configuration when PoS is active.

For PoS mode, epoch sizing is derived from:

```text
microEpochSize * macroEpochMicroFactor
```

Operators and integrators must not assume the legacy IBFT `epochSize` field applies unchanged after PoS activation.

---

## 22. Timing and block parameters

Current chain-level timing and block parameters include:

| Parameter | Value |
|---|---|
| Target block time | ~2.0 seconds |
| `params.engine.ibft.blockTime` | `2000000000` ns |
| Genesis block gas limit | `60,000,000` |
| Genesis difficulty | `0x1` |
| Genesis parent hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis mix hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis timestamp | `0x0` |
| Delegated PoS activation block | `5446500` |

Legacy IBFT epoch values and PoS epoch values must be interpreted through the active chain configuration for the relevant block range.

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

Balances are denominated in wei:

```text
1 XGR = 10^18 wei
```

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

These balances are part of the published genesis state.

Changing them defines a different network.

---

## 25. Bootnodes and networking

Bootnodes are defined as libp2p multiaddresses in the published chain configuration.

Published bootnode entry:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes provide initial peer discovery.

They do not grant validator authority.

A node can use bootnodes to discover peers, but consensus participation depends on the active validator-set rules.

---

## 26. Gas and fee model

XGR Chain supports Ethereum-style transaction fee fields while applying XGR-specific fee behavior according to active configuration and release behavior.

High-level fee fields:

| Topic | XGR behavior |
|---|---|
| Legacy fee field | `gasPrice` |
| Dynamic fee fields | `maxFeePerGas`, `maxPriorityFeePerGas` |
| Base fee field | Present in block/genesis model |
| Genesis base fee | `0x0` |
| Genesis gas limit | `60,000,000` |
| Transaction pool price limit | Runtime node setting |
| Fee policy | XGR-specific and release/configuration-dependent |

The published genesis contains:

| Field | Value |
|---|---|
| `genesis.baseFee` | `0x0` |
| `genesis.baseFeeEM` | `0x0` |
| `genesis.baseFeeChangeDenom` | `0x0` |
| `params.blockGasTarget` | `0` |
| `params.burnContract` | `null` |
| `params.burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

Gas and fee behavior must be interpreted together with:

- active transaction type
- active fork configuration
- base-fee behavior
- minimum-fee behavior
- txpool admission rules
- fee accounting and distribution logic
- configured registry values where supported

---

## 27. Minimum base fee and fee-policy constants

The public node baseline includes XGR-specific constants for fee behavior.

Relevant constants include:

| Constant | Value | Meaning |
|---|---:|---|
| `MinBaseFee` | `100000000000` | Static fallback minimum base fee |
| `CriticalGasThresholdPct` | `80` | Utilization threshold below which base fee remains at minimum behavior |
| `EmergencyBaseFeeChangeDenom` | `4` | Maximum emergency base-fee ramp denominator |

These values are part of XGR-specific fee behavior.

Effective fee behavior can also depend on registry-provided values where supported by the active release stack.

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
| `bridgeAllowList` | Bridge-related allow-list field retained in schema |
| `bridgeBlockList` | Bridge-related block-list field retained in schema |
| `burnContract` | Burn-contract map by activation block |
| `burnContractDestinationAddress` | Burn-contract destination address |

Whether a field has runtime effect depends on whether it is configured and supported by the active release behavior.

---

## 29. EngineRegistry and configured protocol addresses

The published chain configuration includes configured protocol address fields where applicable.

Known published values:

| Field | Value |
|---|---|
| `params.engineRegistryAddress` | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| `params.bootstrapEngineEOA` | `0x0000000000000000000000000000000000000000` |

The public node baseline includes these fields in chain parameters.

During chain import, genesis-provided registry/bootstrap values are applied when present.

The registry address is a configured protocol address for XGR-specific runtime behavior where supported by the active release stack.

A zero bootstrap EOA means no non-zero bootstrap EOA is configured in the published genesis.

---

## 30. Access control configuration fields

The chain parameter type supports address-list configuration fields for access-control behavior.

Supported parameter fields include:

| Field | Purpose |
|---|---|
| `contractDeployerAllowList` | Contract deployer allow-list configuration |
| `contractDeployerBlockList` | Contract deployer block-list configuration |
| `transactionsAllowList` | Transaction allow-list configuration |
| `transactionsBlockList` | Transaction block-list configuration |
| `bridgeAllowList` | Bridge-related allow-list field retained in chain parameter schema |
| `bridgeBlockList` | Bridge-related block-list field retained in chain parameter schema |

If the published configuration does not configure these address-list fields, they do not define additional mainnet restrictions by themselves.

If future published configurations use these fields, their effect must be interpreted according to the active release behavior.

---

## 31. Burn contract configuration fields

The chain parameter type supports burn-contract configuration fields.

Published values:

| Field | Value |
|---|---|
| `burnContract` | `null` |
| `burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

Runtime behavior:

- if no burn contract map is configured, burn-contract calculation returns the zero address
- the zero address means no configured burn-contract redirection from this field
- fee distribution can still depend on other active XGR fee logic and release behavior

The published genesis therefore does not configure a burn contract map.

---

## 32. JSON-RPC surfaces

XGR Chain exposes multiple RPC surfaces depending on node configuration and active release capabilities.

### 32.1 Standard Ethereum-compatible RPC

Used by:

- wallets
- explorers
- scripts
- infrastructure tools
- indexers
- applications

Typical namespaces:

```text
eth_*
net_*
web3_*
```

This is the normal EVM compatibility surface.

### 32.2 PoS monitoring RPC

XGR2.0 exposes PoS monitoring data through chain RPC methods.

PoS monitoring covers:

- current block number
- PoS active status
- PoS activation block
- epoch size
- micro-epoch size
- current epoch
- last finalized epoch
- validator self-stake
- delegated raw stake
- delegated active stake
- total active current stake
- validator active state
- validator join/deactivation timing
- delegator entries for a validator
- delegation pool settings
- staking contract balance
- current pending epoch rewards

Exact method names, parameters and return schemas belong to the staking / PoS endpoint reference.

### 32.3 XGR extension RPC

XGR Chain may expose XGR-specific RPC methods where supported by the active node release and enabled configuration.

Typical namespace:

```text
xgr_*
```

This document does not define XDaLa endpoint schemas or XRC-specific RPC behavior.

Those details belong to the respective XDaLa and XRC documentation.

### 32.4 Operator and diagnostic RPC

Used for node and network diagnostics.

Examples of operational use cases:

- peer inspection
- syncing checks
- block height checks
- transaction pool checks
- consensus status where available
- validator health checks where available

Operator interfaces should be exposed carefully and are not automatically intended for public RPC.

---

## 33. XDaLa and XRC integration boundary

XGR Chain provides the EVM-compatible execution, settlement and RPC substrate that XDaLa and XRC components can use.

At chain-spec level, the boundary is:

| Layer | Responsibility |
|---|---|
| XGR Chain | EVM execution, consensus, finality, gas, blocks, transactions, receipts, chain state and chain RPC |
| XDaLa | Process validation, orchestration and application-layer execution semantics |
| XRC standards | Standardized rule, process or contract formats built above the chain layer |

This chain specification does not define:

- XDaLa rule syntax
- XDaLa process semantics
- XDaLa encryption or grant flows
- XRC-137 details
- XRC-729 details
- application-specific workflow semantics
- UI behavior

Those topics remain in their own documentation.

This document only states the chain-level dependency boundary.

---

## 34. Configuration authority

The chain specification is defined by:

- published genesis configuration
- active public node release or branch
- activated fork schedule
- official operator announcements
- deployed protocol contracts where applicable

Local runtime flags can change how a node process behaves, but they do not redefine the network.

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
- consensus engine config
- PoS activation block
- validator set rules
- fork activation schedule
- configured registry addresses
- bootnodes in published genesis

A node with a different network-defining configuration is not running the same chain.

---

## 35. Active and inactive feature handling

For chain-level specification, feature status is determined as follows:

| Situation | Status |
|---|---|
| Present in public release and activated by published configuration | Active baseline |
| Present in public release but not activated by published configuration | Available but inactive |
| Present only in development code | Development / preview |
| Documented for future activation | Preview / upcoming |
| Activated by official release and configuration update | Active after upgrade |

For XGR2.0 mainnet, delegated PoS and delegated staking are active chain-level features from block `5446500`.

---

## 36. Chain specification summary

| Category | Published value / behavior |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Execution model | EVM-compatible |
| Standard RPC | `eth_*`, `net_*`, `web3_*` |
| XGR extension RPC | `xgr_*` where supported by active release |
| Native decimals | 18 |
| Consensus finality | IBFT |
| Validator model before block `5446500` | Genesis/static IBFT validator set |
| Validator model from block `5446500` | Delegated PoS |
| Target block time | ~2 seconds |
| IBFT `blockTime` | `2000000000` ns |
| Genesis gas limit | `60,000,000` |
| Genesis difficulty | `0x1` |
| Genesis base fee | `0x0` |
| Forks from block `0` | Homestead, Byzantium, Constantinople, Petersburg, Istanbul, London, LondonFix, EIP-150, EIP-155, EIP-158, QuorumCalcAlignment, txHashWithType |
| Forks from block `1208500` | EIP-2930, EIP-2929, EIP-3860, EIP-3651 |
| Public transaction types | Legacy, AccessList, DynamicFee |
| Internal transaction type | StateTx |
| EngineRegistry address | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| Bootstrap Engine EOA | `0x0000000000000000000000000000000000000000` |
| Bootnode count | `1` |
| Staking / PoS | Active from block `5446500` |
| Delegated staking | Active from XGR2.0 PoS cutover |
| XDaLa/XRC details | Separate documentation; only chain boundary defined here |
