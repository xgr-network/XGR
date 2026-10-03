# XGR Chain — Chain Specification

**Document ID:** XGRCHAIN-SPEC  
**Last updated:** 2026-10-03  
**Audience:** Protocol integrators, node operators, auditors, infrastructure engineers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Chain-level protocol and network specification only

---

## 1. Scope

This document defines the chain-level specification for XGRChain.

It covers:

- network identity,
- published mainnet configuration,
- EVM compatibility,
- account model,
- transaction model,
- transaction signing and replay protection,
- execution model,
- block model,
- fork activation configuration,
- consensus relationship,
- delegated PoS activation boundary,
- validator and delegation model at chain level,
- epoch and micro-epoch model,
- genesis state,
- bootnodes and peer discovery,
- gas and fee model at specification level,
- chain-parameter fields,
- native protocol precompiles relevant to the public chain baseline,
- JSON-RPC surfaces relevant to chain operation,
- integration boundaries for application-layer and external protocol systems.

This document does not define:

- node installation commands,
- validator onboarding commands,
- service files,
- monitoring setup,
- XDaLa process semantics,
- XRC standards,
- detailed interchain routing or bridge operations,
- UI behavior.

Node operation belongs to the node-operation runbook.

Exact PoS RPC schemas belong to the staking / PoS endpoint reference.

Exact gas accounting and fee-distribution details belong to the dedicated gas and fee documentation.

Detailed interchain architecture and operations are documented separately.

---

## 2. Network identity

| Field | Value |
| --- | --- |
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Native execution model | EVM-compatible |
| Standard RPC namespaces | `eth_*`, `net_*`, `web3_*` |
| Native token | XGR |
| Native token decimals | `18` |
| Transaction replay protection | EIP-155 chain ID |
| Consensus finality | IBFT deterministic finality |
| Validator participation from block `5446500` | Delegated PoS |
| Public node release baseline | `xgr-node v3.1.1` |

Transactions must be signed for:

    chainId = 1643

A transaction signed for a different chain ID is not valid for XGRChain mainnet.

---

## 3. Public node baseline

The public node implementation is:

    https://github.com/xgr-network/xgr-node

Current public release baseline:

    v3.1.1

Release commit:

    1a4844b311fb856cb8c2303a40fa8aa69b560544

The public release baseline provides:

- EVM execution,
- IBFT consensus networking,
- staking-based validator participation governed by protocol rules,
- stake-weighted quorum and voting-power behavior,
- validator self-staking,
- delegated staking,
- staking lifecycle handling,
- slashing-related protocol logic,
- epoch and micro-epoch accounting,
- XGR-specific gas and fee behavior,
- standard Ethereum JSON-RPC,
- public PoS monitoring RPC methods,
- genesis and configuration loading,
- transaction validation,
- transaction execution,
- block processing,
- peer networking,
- native protocol precompiles,
- local node operation primitives.

The public `v3.1.1` build remains buildable without access to private XGR repositories.

Private or proprietary XGR application modules are not required for normal public node operation.

XDaLa and XRC application semantics are outside this chain-level specification even where the node exposes protocol-level integration points for those systems.

---

## 4. Published mainnet configuration

The published mainnet genesis is maintained in:

    Repository: xgr-network/XGR
    Branch:     main
    Path:       genesis/mainnet/genesis.json

Raw reference path:

    https://raw.githubusercontent.com/xgr-network/XGR/main/genesis/mainnet/genesis.json

The published configuration defines:

- chain ID,
- genesis block,
- initial allocation,
- consensus engine configuration,
- initial validator data,
- fork activation schedule,
- PoS activation point,
- epoch and micro-epoch parameters,
- bootnodes,
- gas and base-fee genesis fields,
- configured protocol addresses where applicable.

A node joins the published XGRChain network by running a compatible node release with this published chain configuration.

A node with different network-defining configuration is not running the same chain.

---

## 5. Chain configuration schema

The public node chain schema contains:

    {
      "name": "xgrchain",
      "genesis": {},
      "params": {},
      "bootnodes": []
    }

Runtime genesis allocation is defined in:

    genesis.alloc

The published mainnet genesis also contains a top-level `alloc` object that mirrors `genesis.alloc`.

The node runtime allocation source is `genesis.alloc`.

---

## 6. PoA to delegated PoS transition

The published mainnet genesis defines the IBFT type schedule as:

| Phase | Type | Validator type | From | To | Deployment |
| --- | --- | --- | ---: | ---: | ---: |
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Delegated PoS phase | `PoS` | `bls` | `5446500` | n/a | `5446500` |

Delegated PoS activation block:

    5446500

Delegated PoS deployment block:

    5446500

The published PoS fork also defines:

| Parameter | Value |
| --- | ---: |
| `minValidatorCount` | `4` |
| `maxValidatorCount` | `25` |

IBFT remains the deterministic-finality consensus mechanism.

Delegated PoS defines validator participation, staking, delegation, voting-power behavior and validator-set evolution from block `5446500`.

---

## 7. EVM compatibility

XGRChain executes Ethereum-compatible smart contracts through an EVM-compatible execution pipeline.

Supported compatibility areas include:

- externally owned accounts,
- smart contract accounts,
- contract deployment,
- contract calls,
- native-value transfers,
- calldata execution,
- event logs,
- receipts,
- nonces,
- gas accounting,
- Ethereum-style transaction signatures,
- Ethereum-compatible JSON-RPC for common wallet, explorer and infrastructure operations.

Ordinary transfers and contract calls use standard EVM transaction envelopes.

Delegated PoS does not require a special wallet-side transaction envelope for normal user transactions.

XGRChain also extends the standard EVM execution environment with XGR-specific protocol behavior and native precompiles.

---

## 8. Account model

XGRChain uses the Ethereum-style account model.

Account state includes:

- address,
- nonce,
- balance,
- contract code, if present,
- contract storage, if present.

Execution-level account categories:

| Account type | Description |
| --- | --- |
| Externally owned account | Controlled by a private key; can sign transactions |
| Contract account | Contains EVM bytecode and storage; executed by transactions or calls |

Balances are denominated in wei:

    1 XGR = 10^18 wei

---

## 9. Transaction model

XGRChain supports the standard Ethereum transaction model used by EVM wallets and tooling.

Public transaction categories:

| Transaction category | Code-level type | Support |
| --- | --- | --- |
| Legacy transaction | `LegacyTx` / `0x00` | Yes |
| Access-list transaction | `AccessListTx` / `0x01` | Yes when active by fork configuration |
| Dynamic-fee transaction | `DynamicFeeTx` / `0x02` | Yes |
| Contract creation | `to == nil` | Yes |
| Contract call | `to != nil` with optional calldata | Yes |
| Value transfer | `value > 0`, empty calldata, non-contract-creation | Yes |

The node also defines:

| Internal type | Code-level type | Purpose |
| --- | --- | --- |
| State transaction | `StateTx` / `0x7f` | Internal system-level execution paths |

The deterministic PoS epoch-finalization system transaction uses the internal `StateTx` shape for receipt and log indexing.

Internal state transactions are not ordinary wallet transactions.

---

## 10. Transaction signing and replay protection

XGRChain uses EIP-155 chain-ID replay protection.

Mainnet signing domain:

    chainId = 1643

For typed transactions, the transaction chain ID must match the configured chain ID.

For protected legacy transactions, the `v` value encodes the chain ID according to EIP-155.

Transactions signed for another chain ID must not be accepted as valid XGRChain mainnet transactions.

---

## 11. Transaction fee fields

XGRChain supports Ethereum-style fee fields according to transaction type and active fork configuration.

| Field | Used by | Meaning |
| --- | --- | --- |
| `gasPrice` | Legacy transactions | Price per gas unit |
| `maxFeePerGas` | Dynamic-fee transactions | Maximum total fee per gas unit |
| `maxPriorityFeePerGas` | Dynamic-fee transactions | Maximum priority fee per gas unit |
| `gasLimit` | All transactions | Maximum gas the sender allows the transaction to consume |
| `value` | Value transfers / contract calls | Native amount transferred with the transaction |

For dynamic-fee transactions, the effective gas price follows the EIP-1559-style relation:

    effectiveGasPrice = min(maxFeePerGas, maxPriorityFeePerGas + baseFee)

XGRChain has additional XGR-specific base-fee, minimum-fee and fee-distribution behavior.

Detailed fee behavior belongs to the dedicated gas and fee documentation.

---

## 12. Execution model

XGRChain executes transactions through an EVM-compatible state-transition pipeline.

For each valid block:

1. the proposer selects and orders transactions,
2. the proposer builds a candidate block,
3. transactions are executed against the parent state,
4. balances, nonces, storage and contract code are updated,
5. logs and receipts are produced,
6. gas usage and fee accounting are applied,
7. the resulting state root is committed into the block header,
8. validators independently verify the same block and state transition,
9. the block is finalized through IBFT once quorum is reached.

The proposer does not control valid state unilaterally.

A block is only valid if validators can independently reproduce and verify the state transition.

### 12.1 Native protocol precompiles

The `v3.1.1` public node baseline contains XGR-specific native precompiles in addition to standard EVM precompiles.

One protocol-relevant precompile is:

| Precompile | Address | Purpose |
| --- | --- | --- |
| Interchain BLS verification | `0x0000000000000000000000000000000000002040` | Native XGR BLS12-381 interchain quorum-attestation verification |

The node registers this address as:

    InterchainBLSVerificationPrecompile = 0x2040

The precompile is part of the execution implementation and therefore does not require deployed EVM bytecode at the address.

It provides a chain-level cryptographic primitive.

The existence of this precompile does **not** itself define:

- a bridge route,
- an interchain validator set,
- a relayer,
- a wrapped-token contract,
- an interchain security policy.

Those are separate protocol and application-layer components built on top of the chain primitive and are documented separately.

---

## 13. Block model

A block contains:

- block number,
- parent hash,
- timestamp,
- gas limit,
- gas used,
- base-fee field,
- state root,
- transaction root,
- receipts root,
- logs bloom,
- proposer/sealer data,
- consensus-specific extra data,
- transactions.

Genesis is block `0`.

Published genesis header values:

| Field | Value |
| --- | --- |
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

XGRChain uses block-number-based fork activation.

Forks are defined under:

    params.forks

A fork is active when:

    blockNumber >= configuredForkBlock

All nodes participating in the same network must use the same effective fork schedule.

---

## 15. Forks active from block `0`

The published mainnet configuration activates the following execution features from genesis:

| Fork / feature | Activation block |
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

---

## 16. Forks active from block `1208500`

The published mainnet configuration activates:

| Fork / EIP | Activation block | Purpose |
| --- | ---: | --- |
| `EIP2930` | `1208500` | Access-list transaction support |
| `EIP2929` | `1208500` | Gas repricing for state access |
| `EIP3860` | `1208500` | Initcode metering / initcode size limit |
| `EIP3651` | `1208500` | Warm `COINBASE` behavior |

These activations provide important Berlin-/Shanghai-era execution behavior required by the current XGRChain execution model.

---

## 17. FeePoolSplit alignment

`feePoolSplit` is a supported fork constant in `xgr-node v3.1.1`.

The node aligns `feePoolSplit` with the first PoS IBFT fork.

For XGRChain mainnet:

    first PoS block = 5446500
    feePoolSplit effective block = 5446500

If `feePoolSplit` is explicitly configured to a different block from the first PoS fork, node initialization fails.

If it is absent and a PoS fork exists, the node resolves the effective `feePoolSplit` activation to the first PoS block.

This alignment is consensus relevant because PoS accounting and XGR-specific fee-pool behavior depend on the same activation boundary.

---

## 18. Consensus layer

XGRChain uses IBFT as its deterministic-finality consensus protocol.

Consensus engine path:

    params.engine.ibft

IBFT provides:

- proposer selection,
- block proposal,
- validator voting,
- quorum-based block commitment,
- deterministic finality once a block is committed.

Published block time:

    params.engine.ibft.blockTime = 2000000000 ns

This is approximately:

    2 seconds

IBFT remains the finality mechanism after delegated PoS activation.

PoS changes how validator participation, voting power and validator-set evolution are determined; it does not replace IBFT block finality.

---

## 19. Validator model

XGRChain uses an IBFT validator set.

From block `5446500`, validator participation is driven by delegated PoS state.

At chain-spec level, delegated PoS includes:

- validator self-stake,
- validator minimum-stake requirements,
- validator activation state,
- validator deactivation state,
- delegated stake,
- active delegated stake,
- raw delegated stake,
- epoch-boundary activation,
- epoch-boundary deactivation,
- stake-weighted voting-power behavior,
- validator-set updates derived from active staking state.

Published validator-count bounds for the PoS phase:

    minimum validators = 4
    maximum validators = 25

The active validator set is consensus-critical.

Validators not in the active validator set do not have IBFT voting authority for the corresponding block range.

---

## 20. Delegation model

Delegated PoS supports delegation to validators.

At chain-spec level, delegation includes:

- delegator address,
- target validator address,
- delegated amount,
- active/inactive delegation state,
- delegation activation timing,
- delegation deactivation timing,
- validator delegation-pool configuration,
- minimum delegator stake where configured,
- maximum delegated stake per validator where configured,
- commission basis points where configured.

Exact public RPC response schemas belong to the staking / PoS endpoint reference.

Exact operator commands belong to the node-operation runbook.

---

## 21. Epoch and micro-epoch model

The current XGRChain PoS implementation uses epoch-based staking and validator-accounting semantics.

Mainnet PoS epoch configuration:

| Parameter | Value |
| --- | ---: |
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Derived macro epoch size | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

PoS macro-epoch size is derived from:

    microEpochSize * macroEpochMicroFactor

For mainnet:

    25 * 40 = 1000 blocks

Micro-epoch accounting is used by the PoS implementation for validator activity and weighting behavior.

Validator joins, deactivations and delegation effects are interpreted through the active staking and epoch rules.

---

## 22. Timing and block parameters

| Parameter | Value |
| --- | --- |
| Target block time | approximately 2 seconds |
| `params.engine.ibft.blockTime` | `2000000000` ns |
| Genesis gas limit | `60,000,000` |
| Genesis difficulty | `0x1` |
| Genesis parent hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis mix hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis timestamp | `0x0` |
| Delegated PoS activation block | `5446500` |
| PoS minimum validator count | `4` |
| PoS maximum validator count | `25` |
| Micro epoch size | `25` blocks |
| PoS macro epoch size | `1000` blocks |

---

## 23. Genesis state

XGRChain starts from the published genesis state.

Genesis defines:

- chain name,
- chain ID,
- genesis block header,
- initial account allocation,
- consensus engine parameters,
- initial validator data,
- fork activation schedule,
- bootnodes,
- configured protocol addresses,
- gas and fee-related starting fields.

Initial balances are defined in:

    genesis.alloc

Balances are denominated in wei.

The top-level allocation in the published genesis mirrors the genesis allocation.

For runtime genesis state, `genesis.alloc` is the relevant allocation object.

Changing the allocation defines a different network.

---

## 24. Initial allocation summary

Published genesis allocation entries:

| Address | Balance in wei | Balance in native units |
| --- | ---: | ---: |
| `0x0000000000000000000000000000000000000000` | `0` | `0` |
| `0x00000000000000000000000000000000000000e1` | `1` | `0.000000000000000001` |
| `0x2A021a1B25DA25e14C4046e5BAc9375Ec3bebf8c` | `2103833846420000000000000000` | `2,103,833,846.42` |
| `0x4675EdCa3c4637E68Ed1C1776a11EB5c9828F056` | `3141592653580000000000000000` | `3,141,592,653.58` |
| `0x7818A59b2D279Fe3444B75dcE1A443C1b124c161` | `1380649000000000000000000000` | `1,380,649,000` |

---

## 25. Bootnodes and networking

Published mainnet bootnode:

    /ip4/217.154.225.157/tcp/1478/p2p/16Uiu2HAmGYfGAKCNzuzZPPauKk7FpqMk192hEmiQsqYTXvrga4Ck

Bootnodes provide initial peer discovery.

They do not grant validator authority.

Consensus participation depends on active validator-set and staking rules.

Additional networking details belong to the dedicated P2P documentation.

---

## 26. Gas and fee model

XGRChain supports Ethereum-style transaction fee fields together with XGR-specific fee behavior.

High-level fee fields:

| Topic | XGR behavior |
| --- | --- |
| Legacy fee field | `gasPrice` |
| Dynamic-fee fields | `maxFeePerGas`, `maxPriorityFeePerGas` |
| Base-fee field | Present in block/genesis model |
| Genesis base fee | `0x0` |
| Genesis gas limit | `60,000,000` |
| Transaction-pool price limit | Runtime node setting |
| Fee policy | XGR-specific and release/configuration-dependent |
| PoS fee-pool behavior | Active from the PoS / `feePoolSplit` boundary |

Published genesis fee-related fields:

| Field | Value |
| --- | --- |
| `genesis.baseFee` | `0x0` |
| `genesis.baseFeeEM` | `0x0` |
| `genesis.baseFeeChangeDenom` | `0x0` |
| `params.blockGasTarget` | `0` |
| `params.burnContract` | `null` |
| `params.burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

Detailed XGR fee-distribution semantics are documented separately.

---

## 27. Minimum base fee and fee-policy constants

The public `xgr-node v3.1.1` implementation includes the following XGR-specific fee constants:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `MinBaseFee` | `100000000000` | Static fallback minimum base fee when no dynamic registry value is available |
| `CriticalGasThresholdPct` | `80` | Utilization threshold below which base-fee behavior remains at the configured/fallback minimum |
| `EmergencyBaseFeeChangeDenom` | `4` | Maximum emergency base-fee ramp denominator |

`EmergencyBaseFeeChangeDenom = 4` corresponds to a maximum increase of approximately 25% of the current base fee per full block under the emergency ramp calculation.

Effective fee behavior can additionally depend on active registry values and fork state.

The dedicated gas-price and fee document is authoritative for the detailed calculation path.

---

## 28. Chain parameter fields

The chain parameter schema includes:

| Field | Purpose |
| --- | --- |
| `forks` | Fork activation configuration |
| `chainID` | EIP-155 chain ID |
| `engine` | Consensus engine configuration |
| `blockGasTarget` | Gas target parameter |
| `engineRegistryAddress` | Configured protocol registry address where used |
| `bootstrapEngineEOA` | Bootstrap EOA where used |
| `contractDeployerAllowList` | Contract-deployer allow-list configuration |
| `contractDeployerBlockList` | Contract-deployer block-list configuration |
| `transactionsAllowList` | Transaction allow-list configuration |
| `transactionsBlockList` | Transaction block-list configuration |
| `bridgeAllowList` | Bridge-related allow-list field in chain parameter schema |
| `bridgeBlockList` | Bridge-related block-list field in chain parameter schema |
| `burnContract` | Burn-contract map by activation block |
| `burnContractDestinationAddress` | Burn-contract destination address |

Whether a field has runtime effect depends on:

- whether it is configured in the published network configuration,
- whether the active node release implements the behavior,
- whether any required activation boundary has been reached.

Schema presence alone does not imply active mainnet behavior.

---

## 29. EngineRegistry and configured protocol addresses

Published values:

| Field | Value |
| --- | --- |
| `params.engineRegistryAddress` | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| `params.bootstrapEngineEOA` | `0x0000000000000000000000000000000000000000` |

A zero bootstrap EOA means no non-zero bootstrap EOA is configured in the published genesis.

The EngineRegistry address is loaded from the chain configuration and is used by XGR-specific runtime behavior supported by the active release.

Where registry code or a configured registry value is unavailable, individual runtime components may define explicit fallback behavior.

Those fallbacks are implementation-specific and must remain deterministic across consensus nodes.

---

## 30. Access-control configuration fields

The chain parameter type supports the following address-list configuration fields:

| Field | Purpose |
| --- | --- |
| `contractDeployerAllowList` | Contract-deployer allow-list configuration |
| `contractDeployerBlockList` | Contract-deployer block-list configuration |
| `transactionsAllowList` | Transaction allow-list configuration |
| `transactionsBlockList` | Transaction block-list configuration |
| `bridgeAllowList` | Bridge-related allow-list field |
| `bridgeBlockList` | Bridge-related block-list field |

The published mainnet genesis does not configure these address-list fields.

Therefore their presence in the public node schema must not be interpreted as an active XGRChain mainnet allowlist or blocklist.

If future published configurations use these fields, their effect must be interpreted according to the active node release and network configuration.

---

## 31. Burn-contract configuration fields

Published values:

| Field | Value |
| --- | --- |
| `burnContract` | `null` |
| `burnContractDestinationAddress` | `0x0000000000000000000000000000000000000000` |

Current configuration meaning:

- no burn-contract map is configured through this genesis field,
- the burn-contract destination field is the zero address,
- these values do not activate a genesis-configured burn-contract redirection.

Fee distribution can still depend on other active XGR-specific fee logic.

These fields must not be confused with the complete XGRChain fee-distribution mechanism.

---

## 32. JSON-RPC surfaces

XGRChain exposes RPC surfaces depending on node configuration and active release capabilities.

### 32.1 Standard Ethereum-compatible RPC

Typical namespaces:

    eth_*
    net_*
    web3_*

This is the normal EVM compatibility surface used by:

- wallets,
- explorers,
- scripts,
- indexers,
- applications.

### 32.2 Public PoS monitoring RPC

Current public PoS methods include:

    eth_getPosValidatorsOverview
    eth_getPosValidatorDelegators

These methods expose validator, stake, delegation, epoch and pool information.

Exact method parameters and response schemas belong to the staking / PoS endpoint reference.

### 32.3 Operator and diagnostic RPC

Operator and diagnostic interfaces are used for functions such as:

- synchronization checks,
- block-height checks,
- peer checks,
- transaction-pool checks,
- validator-health checks where available,
- execution diagnostics.

Operator interfaces should be exposed carefully and are not automatically intended for public RPC access.

---

## 33. External protocol and interchain boundary

XGRChain provides protocol primitives that external systems can use.

For interchain infrastructure, the chain provides:

- normal EVM contract execution,
- native XGR transfers,
- transaction finality,
- logs and receipts,
- standard RPC access,
- the native interchain BLS12-381 verification precompile at `0x2040`.

The chain specification does not itself define:

- remote chains,
- wrapped or synthetic assets,
- cross-chain router contracts,
- Hyperlane Mailboxes,
- Interchain Security Modules,
- validator registries used specifically for cross-chain attestations,
- relayer topology,
- lock/mint or burn/unlock policy.

Those components form a separate interchain protocol layer.

Interchain validators and relayers must not be confused with XGRChain consensus validators merely because both systems may use validator identities or BLS cryptography.

---

## 34. Application-layer boundary

XGRChain provides:

- EVM execution,
- consensus,
- deterministic finality,
- gas accounting,
- blocks,
- transactions,
- receipts,
- chain state,
- chain RPC,
- protocol-level precompiles.

Application-layer systems may build on this chain substrate.

This chain specification does not define:

- XDaLa rule syntax,
- XDaLa process semantics,
- XDaLa encryption or grant flows,
- XRC-137 details,
- XRC-729 details,
- application-specific workflow semantics,
- UI behavior.

Those topics remain outside this chain-level specification.

---

## 35. Configuration authority

The effective chain specification is determined by:

- published genesis configuration,
- active compatible node release,
- activated fork schedule,
- protocol-defined upgrade behavior,
- deployed protocol contracts where applicable.

Local runtime flags can change how an individual node process behaves.

They do not redefine the network.

Examples of local runtime behavior:

- data directory,
- JSON-RPC bind address,
- gRPC bind address,
- P2P bind address,
- log level,
- metrics bind address,
- peer limits,
- sealing enabled/disabled.

Examples of network-defining behavior:

- chain ID,
- genesis block header,
- genesis allocation,
- consensus engine configuration,
- PoS activation block,
- validator-set rules,
- fork activation schedule,
- configured protocol addresses,
- consensus-critical protocol behavior.

Bootnodes are part of the published network configuration for discovery but are not consensus authorities.

A node using incompatible network-defining configuration is not participating correctly in the same XGRChain network.

---

## 36. Feature-status rule

For this public chain specification, a feature should be described as active XGRChain mainnet functionality only when it is:

1. implemented by the active compatible public node release, and
2. enabled by the published mainnet configuration, active fork state or protocol deployment required for that feature.

Code-level existence alone is not a public mainnet guarantee.

Likewise:

- a schema field is not necessarily configured,
- a precompile capability does not imply that every system using it is active,
- a contract implementation does not imply that a specific deployment is canonical,
- application-layer functionality does not automatically become part of the chain protocol.

This document therefore distinguishes between protocol capability and deployed higher-level services.

---

## 37. Chain specification summary

| Category | Published value / behavior |
| --- | --- |
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Public node baseline | `xgr-node v3.1.1` |
| Release commit | `1a4844b311fb856cb8c2303a40fa8aa69b560544` |
| Execution model | EVM-compatible with XGR-specific protocol extensions |
| Standard RPC | `eth_*`, `net_*`, `web3_*` |
| Native asset | XGR |
| Native decimals | `18` |
| Consensus finality | IBFT |
| Validator type | BLS |
| Validator model before block `5446500` | Initial IBFT PoA validator set |
| Validator model from block `5446500` | Delegated PoS |
| PoS minimum validator count | `4` |
| PoS maximum validator count | `25` |
| Target block time | approximately 2 seconds |
| IBFT `blockTime` | `2000000000` ns |
| Micro epoch size | `25` blocks |
| Macro epoch micro factor | `40` |
| PoS macro epoch size | `1000` blocks |
| Micro-epoch inactivity decay | `9000` bps |
| Micro-epoch nominal weight | `10000` units |
| Genesis gas limit | `60,000,000` |
| Genesis difficulty | `0x1` |
| Genesis base fee | `0x0` |
| PoS / `feePoolSplit` activation | block `5446500` |
| Forks from block `0` | Homestead, Byzantium, Constantinople, Petersburg, Istanbul, London, LondonFix, EIP-150, EIP-155, EIP-158, QuorumCalcAlignment, txHashWithType |
| Forks from block `1208500` | EIP-2930, EIP-2929, EIP-3860, EIP-3651 |
| Public transaction types | `LegacyTx`, `AccessListTx`, `DynamicFeeTx` |
| Internal transaction type | `StateTx` / `0x7f` |
| Public PoS RPC methods | `eth_getPosValidatorsOverview`, `eth_getPosValidatorDelegators` |
| Native interchain BLS precompile | `0x0000000000000000000000000000000000002040` |
| Interchain precompile primitive | BLS12-381 quorum-attestation verification |
| EngineRegistry address | `0x72cbbb5c95662510da052b98add933ff99ec820f` |
| Bootstrap Engine EOA | `0x0000000000000000000000000000000000000000` |
| Published bootnode count | `1` |
| Staking / PoS | Active from block `5446500` |
| Delegated staking | Active from PoS cutover |
| Interchain route architecture | Separate protocol documentation |
| XDaLa/XRC details | Outside this chain specification |
