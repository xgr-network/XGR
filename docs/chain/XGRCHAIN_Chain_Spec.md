# XGR Chain — Chain Specification

**Document ID:** XGRCHAIN-SPEC  
**Last updated:** 2026-05-03  
**Audience:** Protocol integrators, node operators, auditors, infrastructure engineers  
**Implementation status:** Current public baseline with development/preview components where explicitly marked  
**Source of truth:** Published XGR Chain genesis configuration, public `xgr-network/xgr-node` releases, and official XGR Network operator announcements

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
- timing and block parameters
- genesis block semantics
- bootnodes and peer discovery
- gas and fee model at specification level
- on-chain configuration registry fields
- JSON-RPC surfaces
- XDaLa and XRC integration boundaries
- staking / PoS release status

This document is the protocol-level overview of XGR Chain.

Exact operator commands, service files, key handling, runtime flags, monitoring, backups and troubleshooting belong to node-operation documentation.

Exact endpoint schemas belong to their respective RPC references.

Exact gas accounting and fee distribution details belong to the dedicated gas specification.

---

## 2. Network identity

| Field | Value |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Native execution model | EVM-compatible |
| Standard RPC namespace | `eth_*`, `net_*`, `web3_*` |
| XGR extension RPC namespace | `xgr_*` where supported |
| Native token decimals | 18 |
| Transaction replay protection | EIP-155 chain ID |

Transactions must be signed for the configured XGR Chain ID:

```text
chainId = 1643
```

The chain ID is part of the signing domain.

A transaction signed for a different chain ID is not valid for XGR Chain.

---

## 3. Public baseline and release status

XGR Chain separates the public node baseline from XGR-specific extensions and development/preview components.

### 3.1 Public baseline

The public node baseline provides:

- EVM execution
- consensus networking
- standard Ethereum JSON-RPC
- genesis/configuration loading
- transaction validation
- transaction execution
- block processing
- peer networking
- local node operation primitives

The current stable public baseline example is:

```text
v1.1.1
```

### 3.2 Published configuration

The published chain configuration defines:

- chain ID
- genesis block
- initial allocation
- consensus engine configuration
- validator set at genesis
- fork activation schedule
- bootnodes
- gas and base-fee genesis fields
- configured registry/bootstrap addresses

A node joins the published XGR Chain network by running a compatible node release with the published genesis configuration.

### 3.3 Development / preview components

Some components may exist in ongoing development before they are part of the current public baseline release.

Examples include:

- staking-based validator participation
- permissionless validator join
- delegated staking
- stake-weighted voting power
- staking-specific endpoints
- additional future fork features

A development or preview component becomes part of the operational chain only when it is included in an official release and activated through published configuration or operator announcement.

---

## 4. EVM compatibility

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

---

## 5. Account model

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

## 6. Transaction model

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

The node implementation also contains an internal state transaction type used by system-level execution paths. It is not a normal wallet transaction type.

---

## 7. Transaction signing and replay protection

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

## 8. Transaction fee fields

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

---

## 9. Execution model

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

## 10. Block model

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

The published genesis block defines:

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

---

## 11. Execution fork configuration

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

---

## 12. Forks active from block 0

The following execution features are active from genesis:

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

## 13. Forks active from block 1208500

The following execution features activate at block `1208500`:

| Fork / EIP | Activation block | Purpose |
|---|---:|---|
| `EIP2930` | `1208500` | Access-list transaction support |
| `EIP2929` | `1208500` | Gas repricing for state access |
| `EIP3860` | `1208500` | Initcode metering / initcode size limit |
| `EIP3651` | `1208500` | Warm `COINBASE` behavior |

Nodes must use the same fork activation schedule to remain execution-compatible with the published network.

---

## 14. Future fork entries

The node codebase may contain support for additional fork constants or feature flags before those features are activated on the published network.

A fork feature is part of the active chain specification only when it is present in the published chain configuration or activated by an official network upgrade.

This rule prevents code-level availability from being confused with network-level activation.

---

## 15. Consensus layer

XGR Chain uses **IBFT** as its deterministic-finality consensus protocol.

The consensus engine is configured under:

```text
params.engine.ibft
```

Published configuration:

| Field | Value |
|---|---|
| `blockTime` | `2000000000` |
| `epochSize` | `500` |
| `type` | `PoA` |
| `validator_type` | `bls` |

Interpretation:

| Field | Meaning |
|---|---|
| `blockTime` | Target block time in nanoseconds |
| `epochSize` | IBFT epoch interval in blocks |
| `type` | Current published validator-set mode |
| `validator_type` | Validator signature/sealing type |

Target block time:

```text
2000000000 ns = 2 seconds
```

Epoch duration estimate:

```text
500 blocks * 2 seconds ≈ 1000 seconds ≈ 16.7 minutes
```

---

## 16. Consensus and execution relationship

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

## 17. Validator model

The published genesis configures the current IBFT validator set through `genesis.extraData`.

The validator set contains:

- validator account addresses
- BLS public keys
- consensus extra-data fields

The current published genesis validator mode is:

```text
params.engine.ibft.type = PoA
```

Staking-based validator participation is a development/preview component until it is activated by official release and published configuration.

When active, staking may define:

- permissionless validator join
- delegated staking
- stake-weighted voting power
- validator activation/deactivation
- staking-specific epoch transitions
- staking-specific RPC methods

Those semantics are not inferred from the current published genesis alone.

---

## 18. Timing and block parameters

Current published chain-level timing and block parameters:

| Parameter | Value |
|---|---|
| Target block time | ~2.0 seconds |
| `params.engine.ibft.blockTime` | `2000000000` ns |
| `params.engine.ibft.epochSize` | `500` blocks |
| Genesis block gas limit | `60,000,000` |
| Genesis difficulty | `0x1` |
| Genesis parent hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis mix hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis timestamp | `0x0` |

The base chain epoch described here is the IBFT epoch interval.

Staking-specific micro/macro epoch semantics are separate development/preview concepts unless activated by an official release.

---

## 19. Genesis state

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
- configured registry/bootstrap addresses
- gas and fee-related starting fields

Initial balances are defined in:

```text
genesis.alloc
```

Balances are denominated in wei:

```text
1 XGR = 10^18 wei
```

The top-level `alloc` field in the published genesis mirrors the genesis allocation.

For runtime genesis state, `genesis.alloc` is the relevant allocation object.

---

## 20. Initial allocation summary

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

## 21. Bootnodes and networking

Bootnodes are defined as libp2p multiaddresses in the published chain configuration.

Published bootnode entry:

```text
/ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck
```

Bootnodes provide initial peer discovery.

They do not grant validator authority.

A node can use bootnodes to discover peers, but consensus participation depends on the active validator-set rules.

---

## 22. Gas and fee model

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

## 23. Minimum base fee and fee-policy constants

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

## 24. EngineRegistry and configured protocol addresses

The published chain configuration includes:

| Field | Value |
|---|---|
| `params.engineRegistryAddress` | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| `params.bootstrapEngineEOA` | `0x0000000000000000000000000000000000000000` |

The public node baseline includes these fields in chain parameters.

During chain import, genesis-provided registry/bootstrap values are applied when present.

The registry address is a configured protocol address for XGR-specific runtime behavior where supported by the active release stack.

A zero bootstrap EOA means no non-zero bootstrap EOA is configured in the published genesis.

---

## 25. JSON-RPC surfaces

XGR Chain exposes multiple RPC surfaces depending on node configuration and active release capabilities.

### 25.1 Standard Ethereum-compatible RPC

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

### 25.2 Operator and diagnostic RPC

Used for node and network diagnostics.

Examples of operational use cases:

- peer inspection
- syncing checks
- block height checks
- transaction pool checks
- consensus status where available
- validator health checks where available

Operator interfaces should be exposed carefully and are not automatically intended for public RPC.

### 25.3 XGR extension RPC

Used by XGR-specific validation and orchestration clients.

Typical namespace:

```text
xgr_*
```

Availability depends on the active XGR release stack.

---

## 26. XDaLa and XRC standards

XGR Chain provides the EVM-compatible execution and settlement layer used by XGR-specific validation and orchestration components.

### 26.1 XDaLa

XDaLa is the XGR validation and orchestration layer.

It can use XGR-specific RPC methods and XGR contracts where supported by the active release stack.

### 26.2 XRC-137

XRC-137 is the rule-document / rule-contract standard.

It is used for structured validation rules.

### 26.3 XRC-729

XRC-729 is the orchestration/session contract standard.

It is used for controlled process execution and session-based orchestration.

The chain specification defines the chain layer these systems rely on.

Endpoint schemas, rule syntax, orchestration semantics and encryption/grant behavior are specified in their respective documents.

---

## 27. Access control configuration fields

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

The published mainnet genesis shown in this specification does not configure these address-list fields.

If future published configurations use these fields, their effect must be interpreted according to the active release behavior.

---

## 28. Burn contract configuration fields

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

## 29. Configuration authority

The chain specification is defined by:

- published genesis configuration
- active public node release
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
- validator set at genesis
- fork activation schedule
- configured registry addresses
- bootnodes in published genesis

A node with a different network-defining configuration is not running the same chain.

---

## 30. Development and preview status handling

A feature can exist in development before it is part of the current public baseline.

For chain-level specification, this means:

| Situation | Status |
|---|---|
| Present in public release and activated by published configuration | Active baseline |
| Present in public release but not activated by published configuration | Available but inactive |
| Present only in development code | Development / preview |
| Documented for future activation | Preview / upcoming |
| Activated by official release and configuration update | Active after upgrade |

Staking/PoS features belong in this category until activated through an official release path.

---

## 31. Chain specification summary

| Category | Published value / behavior |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Execution model | EVM-compatible |
| Standard RPC | `eth_*`, `net_*`, `web3_*` |
| XGR extension RPC | `xgr_*` where supported |
| Native decimals | 18 |
| Consensus engine | IBFT |
| Published validator mode | `PoA` |
| Validator type | `bls` |
| Target block time | ~2 seconds |
| IBFT `blockTime` | `2000000000` ns |
| IBFT `epochSize` | `500` blocks |
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
| Staking / PoS | Development / preview until official activation |
