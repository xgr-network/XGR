# XGR Chain — Introduction

**Document ID:** XGRCHAIN-INTRO  
**Last updated:** 2026-05-24  
**Audience:** Developers, node operators, validators, auditors, integrators  
**Release baseline:** `xgr-node` release tag `v2.0.5`  
**Mainnet genesis source:** `xgr-network/XGR` branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Operating mode covered here:** Public standalone XGR Chain node, without xgrEngine and without XDaLa

---

## 1. What is XGR Chain?

XGR Chain is the EVM-compatible Layer-1 blockchain of the XGR Network.

It is an independent blockchain network with its own:

- genesis configuration
- chain ID
- validator set
- consensus configuration
- protocol parameters
- native gas and fee behavior
- runtime and upgrade path
- delegated PoS staking model

XGR Chain provides the execution and settlement layer for:

- Ethereum-compatible accounts
- Ethereum-compatible smart contracts
- Ethereum-compatible transactions
- standard Ethereum JSON-RPC access
- deterministic-finality consensus through IBFT
- delegated PoS validator participation
- validator self-staking
- delegated staking
- epoch-based validator activation and deactivation
- XGR-native gas and fee behavior

The public node implementation is:

```text
https://github.com/xgr-network/xgr-node
```

The current public release baseline for this documentation is:

```text
v2.0.5
```

This public node release builds as a standalone XGR Chain node.

It does not require:

```text
xgrEngine
XDaLa
private engine module
engine_embedded build tag
```

Standard public build:

```bash
git clone https://github.com/xgr-network/xgr-node.git
cd xgr-node
git fetch --all --tags
git checkout v2.0.5
go build -o xgrchain .
```

---

## 2. Mainnet genesis

The canonical public mainnet genesis is maintained in the XGR repository:

```text
Repository: xgr-network/XGR
Branch:     main
Path:       genesis/mainnet/genesis.json
```

Raw reference:

```text
https://raw.githubusercontent.com/xgr-network/XGR/main/genesis/mainnet/genesis.json
```

Operators must use this published genesis for mainnet nodes.

Do not generate or edit a local genesis for mainnet operation.

Mainnet identity:

| Field | Value |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Genesis gas limit | `0x3938700` |
| Genesis gas limit decimal | `60,000,000` |
| Consensus finality | IBFT |
| Validator participation from block `5446500` | Delegated PoS |
| Native decimals | `18` |

---

## 3. Current public baseline

The public `v2.0.5` node baseline covers:

| Area | Status |
|---|---|
| EVM execution | Active |
| IBFT block production and deterministic finality | Active |
| Delegated PoS validator participation | Active |
| Validator self-staking | Active |
| Delegated staking | Active |
| Epoch-based validator activation and deactivation | Active |
| Micro-epoch uptime accounting | Active |
| Standard Ethereum JSON-RPC | Active |
| Public PoS monitoring RPC | Active |
| Genesis and configuration loading | Active |
| Node operation | Active |

Public PoS monitoring RPC methods:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

Other endpoint schemas belong to the dedicated RPC reference.

---

## 4. Architecture overview

At a high level, XGR Chain consists of these functional layers:

| Layer | Purpose |
|---|---|
| EVM execution layer | Executes Ethereum-compatible transactions and smart contracts |
| Consensus layer | Produces and finalizes blocks through IBFT |
| Delegated PoS layer | Provides validator staking, delegation and validator participation |
| Networking layer | Connects nodes through peer-to-peer networking |
| JSON-RPC layer | Provides Ethereum-compatible RPC access and public PoS monitoring RPC |
| Configuration layer | Defines chain ID, genesis, fork activation, bootnodes and protocol parameters |
| Gas and fee layer | Applies XGR-specific gas and fee behavior |
| Access-control parameter layer | Provides allowlist/blocklist configuration fields where configured |

The chain layer remains EVM-compatible.

Delegated PoS changes validator participation and validator-set management.

It does not require a custom transaction envelope for ordinary transfers or contract calls.

---

## 5. Chain identity

XGR Chain has its own network identity.

| Field | Description |
|---|---|
| Network | XGR Chain |
| Execution model | EVM-compatible |
| Account model | Ethereum-style accounts |
| Contract model | Ethereum-compatible smart contracts |
| Transaction model | Ethereum-compatible transaction signing and execution |
| Standard RPC | `eth_*`, `net_*`, `web3_*` |
| Public PoS RPC | `eth_getPosValidatorsOverview`, `eth_getPosValidatorDelegators` |
| Finality model | IBFT deterministic finality |
| Validator model | Delegated PoS with IBFT finality |
| Native decimal model | 18 decimals |

Exact network-defining values are taken from the published mainnet genesis and the active public release.

---

## 6. Execution model

XGR Chain executes transactions through an Ethereum-compatible EVM execution pipeline.

For each valid block:

1. pending transactions are selected for inclusion
2. the proposer builds a candidate block
3. transactions are executed against the parent state
4. account balances, contract storage, logs and receipts are produced
5. gas usage and fee accounting are applied
6. the resulting state root is committed into the block header
7. validators independently verify the block and state transition
8. IBFT finality is reached after the required quorum commits the block

The proposer does not unilaterally define valid state.

Validators independently verify the block before finalization.

---

## 7. Consensus and delegated PoS

XGR Chain uses IBFT for block production and deterministic finality.

The published mainnet genesis defines the validator-participation transition as:

| Phase | Type | Validator type | From | To | Deployment |
|---|---|---|---:|---:|---:|
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Delegated PoS phase | `PoS` | `bls` | `5446500` | n/a | `5446500` |

IBFT remains the finality mechanism.

Delegated PoS defines how validators enter, leave and participate economically in the validator set.

Delegated PoS includes:

- validator self-stake
- delegated stake
- validator pool configuration
- validator activation state
- validator deactivation state
- epoch-boundary effectiveness
- micro-epoch uptime-related accounting
- stake-aware validator participation

---

## 8. Epoch and micro-epoch model

XGR Chain uses epoch-based staking semantics.

Published mainnet values:

| Parameter | Value |
|---|---:|
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Derived macro epoch size | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

The PoS macro epoch size is derived from:

```text
microEpochSize * macroEpochMicroFactor
```

For mainnet:

```text
25 * 40 = 1000 blocks
```

At a high level:

- validator joins become effective through epoch rules
- validator deactivations become effective through epoch rules
- stake and delegation changes can affect active validator accounting through epoch rules
- micro-epoch accounting supports uptime-related weighting
- PoS monitoring RPC exposes epoch and micro-epoch fields

Operators and integrators must use the published configuration and live RPC data, not guessed constants.

---

## 9. Staking and delegation model

XGR Chain supports delegated PoS.

The model includes:

- validator self-stake
- validator minimum stake rules
- validator activation and deactivation state
- delegator stake
- delegation pool configuration
- delegated raw stake
- delegated active stake
- total active current stake
- validator and delegator lifecycle handling

Operator actions such as join, pool configuration, activation, deactivation, stake, unstake and withdraw are documented in the node-operation runbook.

Public PoS RPC response schemas are documented in the staking / PoS endpoint reference.

---

## 10. EVM compatibility

XGR Chain supports standard EVM tooling.

This includes:

- externally owned accounts
- smart contract deployment
- smart contract calls
- Ethereum-style logs
- Ethereum-style receipts
- Ethereum-style transaction nonces
- Ethereum-style gas accounting
- Ethereum-style transaction signing
- Ethereum JSON-RPC methods used by wallets, explorers, indexers and scripts

Supported transaction categories include:

- `LegacyTx`
- `AccessListTx`
- `DynamicFeeTx`

The node also has internal `StateTx` for system-level execution paths.

`StateTx` is not an ordinary wallet transaction.

XGR Chain does not require wallets or integrators to adopt a non-standard transaction envelope for ordinary transfers or contract calls.

---

## 11. JSON-RPC access

XGR Chain exposes standard Ethereum-compatible JSON-RPC methods.

Standard method families include:

```text
eth_*
net_*
web3_*
```

Public XGR PoS monitoring methods:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

PoS RPC data is intended for:

- operators
- explorers
- staking dashboards
- monitoring systems
- validator tooling
- delegation interfaces
- auditors

RPC consumers must treat live node data as authoritative for current chain state.

Historical analytics should be built through indexing, not by assuming a live endpoint is a full history database.

---

## 12. Gas and fee behavior

XGR Chain has XGR-native gas and fee behavior.

The chain configuration and node implementation define:

- base fee behavior
- minimum fee behavior
- block gas target behavior
- fee-related fork behavior
- configured fee destinations where applicable
- fee-pool behavior after PoS activation

Key public constants in the node implementation include:

| Constant | Value |
|---|---:|
| `MinBaseFee` | `100000000000` |
| `CriticalGasThresholdPct` | `80` |
| `EmergencyBaseFeeChangeDenom` | `4` |

Exact fee behavior belongs in the dedicated gas and fee documentation.

This introduction only establishes that gas and fee behavior is chain-level protocol behavior.

---

## 13. Node operation

An XGR node is responsible for:

- loading the published chain configuration
- connecting to peers
- synchronizing blocks
- validating block headers
- executing transactions
- verifying state transitions
- participating in IBFT consensus when configured as an active validator
- exposing JSON-RPC access where enabled
- maintaining local chain state

The practical node runbook explains:

- how to build `v2.0.5`
- how to install the binary
- how to install the mainnet genesis
- how to start a full node
- how to start an RPC node
- how to join as validator
- how to open a delegation pool
- how to activate or deactivate a validator
- how to stake, unstake and withdraw

For normal full nodes and RPC nodes, sealing must be disabled:

```text
--seal=false
```

Validator nodes intentionally use:

```text
--seal=true
```

---

## 14. Configuration as source of truth

The published chain configuration is part of the protocol source of truth.

Documentation must not override or invent network-defining values.

Network-defining values include:

- chain ID
- genesis hash
- bootnodes
- IBFT settings
- PoS activation block
- epoch parameters
- fork activation blocks
- block gas limit
- fee parameters
- configured system addresses
- allowlist and blocklist settings where configured

If documentation and published configuration conflict, the published configuration and active node implementation take precedence.

---

## 15. Separation from application-layer documentation

This document describes XGR Chain as a blockchain protocol and node implementation.

It does not define:

- XDaLa process semantics
- application-specific validation rules
- business-process orchestration
- encrypted grant workflows
- external API validation flows
- UI behavior
- explorer UI behavior
- marketing claims

Those topics must be documented separately.

Chain documentation should remain limited to:

- protocol behavior
- node behavior
- consensus
- staking
- configuration
- gas
- RPC
- operator behavior

---

## 16. Document update triggers

This document must be updated whenever one of the following changes:

- public node release baseline
- published mainnet genesis
- chain ID
- PoS activation settings
- staking behavior
- validator lifecycle behavior
- public PoS RPC behavior
- fork activation settings
- gas or fee behavior
- node build requirements
- operator runbook assumptions

For the current public baseline, use:

```text
xgr-node v2.0.5
xgr-network/XGR main genesis/mainnet/genesis.json
```
