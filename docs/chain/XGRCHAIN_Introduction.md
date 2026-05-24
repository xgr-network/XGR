# XGR Chain — Introduction

**Document ID:** XGRCHAIN-INTRO  
**Last updated:** 2026-05-24  
**Audience:** Developers, node operators, auditors, integrators  
**Implementation status:** XGR2.0 mainnet baseline with delegated PoS active  
**Source of truth:** Public `xgr-network/xgr-node` branch `XGR2.0`, published XGR Chain configuration, and official XGR Network operator announcements

---

## 1. What is XGR Chain?

**XGR Chain** is the EVM-compatible Layer-1 blockchain of the XGR Network.

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

The public node implementation is provided through:

```text
https://github.com/xgr-network/xgr-node
```

The active public source branch for the XGR2.0 delegated PoS rollout is:

```text
XGR2.0
```

The public node baseline provides:

- EVM execution
- IBFT consensus networking
- delegated PoS validator selection
- validator self-staking
- delegated staking
- staking contract interaction
- epoch and micro-epoch accounting
- standard Ethereum JSON-RPC interface
- PoS monitoring RPC endpoints
- configuration and genesis tooling
- node operation primitives

Network-specific values are defined by the published XGR Chain configuration.

---

## 2. Release and feature status

XGR Chain uses a staged release and activation model.

The documentation distinguishes between:

1. **current public node behavior**
2. **published mainnet configuration**
3. **XGR-specific chain extensions**
4. **application-layer systems documented separately**

This distinction is important because chain-level behavior is defined by the active node implementation and the published network configuration.

Application-layer systems such as XDaLa are not part of this chain introduction and are documented separately.

---

## 2.1 Current public baseline

The current public baseline for the delegated PoS mainnet rollout is the public node implementation maintained in:

```text
xgr-network/xgr-node
```

Reference branch:

```text
XGR2.0
```

This baseline covers:

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
| PoS monitoring RPC endpoints | Active |
| Genesis and configuration tooling | Active |
| Node operation | Active |

---

## 2.2 Published chain configuration

The published XGR Chain configuration defines network-specific values such as:

- chain ID
- genesis block
- fork activation settings
- consensus parameters
- IBFT engine parameters
- PoS activation settings
- bootnodes
- pre-funded accounts
- block gas limit
- fee-related configuration
- protocol-level configured addresses where applicable

Operators must use the published XGR Chain configuration for the target network.

For XGR mainnet, the delegated PoS transition is part of the XGR2.0 rollout. The effective PoS activation point is defined by the published chain configuration and must not be guessed from documentation text alone.

---

## 2.3 XGR-specific chain extensions

XGR-specific chain extensions currently relevant to chain documentation include:

- XGR-native gas and fee behavior
- delegated PoS validator participation
- validator self-staking
- delegated staking
- epoch-boundary validator activation
- epoch-boundary validator deactivation
- micro-epoch uptime accounting
- PoS monitoring RPC endpoints
- chain-level configuration parameters
- access-control parameters where configured

These are chain-level features.

Application-layer process engines, orchestration systems, encrypted grants, business rules, workflow execution models and XDaLa-specific components are documented separately.

---

## 3. Architecture overview

At a high level, XGR Chain consists of several functional layers.

| Layer | Purpose | Status |
|---|---|---|
| EVM execution layer | Executes Ethereum-compatible transactions and smart contracts | Active |
| Consensus layer | Produces and finalizes blocks through IBFT | Active |
| Delegated PoS layer | Provides validator staking, delegation and stake-weighted validator participation | Active in XGR2.0 |
| Networking layer | Connects nodes through peer-to-peer networking | Active |
| JSON-RPC layer | Provides Ethereum-compatible RPC access and PoS monitoring endpoints | Active |
| Configuration layer | Defines chain ID, genesis, fork activation, bootnodes and protocol parameters | Published XGR configuration |
| Gas and fee layer | Applies XGR-specific gas and fee behavior where configured | Active where configured |
| Access-control layer | Applies allowlist and blocklist rules where configured | Active where configured |

The chain layer remains EVM-compatible.

Delegated PoS changes validator participation and validator-set management. It does not require a custom Ethereum transaction format.

---

## 4. Chain identity

XGR Chain has its own network identity.

High-level identity:

| Field | Description |
|---|---|
| Network | XGR Chain |
| Execution model | EVM-compatible |
| Account model | Ethereum-style accounts |
| Contract model | Ethereum-compatible smart contracts |
| Transaction model | Ethereum-compatible transaction signing and execution |
| Standard RPC | `eth_*`, `net_*`, `web3_*` |
| PoS monitoring RPC | Available where enabled by the active node release |
| Finality model | IBFT deterministic finality |
| Validator model | Delegated PoS with IBFT block production |
| Native decimal model | 18 decimals unless otherwise specified by published chain configuration |

Exact network-defining values belong to the active published chain configuration.

---

## 5. Execution model

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

## 6. Consensus and delegated PoS

XGR Chain uses IBFT for block production and deterministic finality.

With XGR2.0, validator participation is governed by delegated PoS mechanics.

This means:

- validators participate through staking
- validators may have self-stake
- validators may receive delegated stake
- delegated stake can affect active validator weight where supported by the active staking rules
- validator activation is epoch-boundary based
- validator deactivation is epoch-boundary based
- staking state is exposed through PoS-related RPC views
- the current validator set remains enforced through the consensus layer

IBFT remains the finality mechanism.

Delegated PoS defines how validators enter, leave and participate economically in the validator set.

---

## 7. Epoch and micro-epoch model

XGR2.0 introduces an epoch-based staking model.

At a high level:

- validator joins are not necessarily effective immediately in the same epoch
- validator deactivations are not necessarily effective immediately in the same epoch
- stake and delegation changes can become effective at epoch boundaries
- micro-epoch accounting can be used for uptime-related weighting
- PoS monitoring endpoints expose epoch and micro-epoch fields

The exact epoch size, micro-epoch size and macro-epoch factor are defined by the active chain configuration.

Operators and integrators must use live RPC data and the published network configuration rather than hard-coded assumptions.

---

## 8. Staking and delegation model

XGR2.0 supports a delegated PoS staking model.

The model includes:

- validator self-stake
- validator minimum stake rules
- validator activation and deactivation state
- delegator stake
- delegation pool configuration
- delegation activation and deactivation state
- delegated raw stake
- delegated active stake
- total active current stake
- validator and delegator lifecycle handling

Validator and delegator lifecycle behavior is enforced by the node implementation and staking logic.

The documentation for staking endpoints is maintained separately in the PoS endpoint reference.

---

## 9. EVM compatibility

XGR Chain is designed to support standard EVM tooling.

This includes compatibility with:

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

- legacy transactions
- EIP-155 protected transactions
- Ethereum-compatible transaction formats supported by the active node implementation

XGR Chain does not require wallets or integrators to adopt a non-standard transaction envelope for ordinary transfers or contract calls.

---

## 10. JSON-RPC access

XGR Chain exposes standard Ethereum-compatible JSON-RPC methods.

These include method families such as:

- `eth_*`
- `net_*`
- `web3_*`

Where supported by the active node release, additional PoS monitoring endpoints expose validator, staking, delegation and epoch-related state.

PoS RPC data is intended for:

- operators
- explorers
- staking dashboards
- monitoring systems
- validator tooling
- delegation interfaces
- auditors

RPC consumers must treat live node data as authoritative for current chain state.

---

## 11. Gas and fee behavior

XGR Chain has XGR-native gas and fee behavior.

The chain configuration and node implementation define:

- base fee behavior
- minimum fee behavior
- block gas target behavior
- fee-related fork behavior
- configured fee destinations where applicable

Exact fee behavior belongs in the dedicated gas and fee documentation.

This introduction only establishes that gas and fee behavior is chain-level protocol behavior and not an application-layer convention.

---

## 12. Node operation

An XGR node is responsible for:

- loading the published chain configuration
- connecting to peers
- synchronizing blocks
- validating block headers
- executing transactions
- verifying state transitions
- participating in IBFT consensus where configured as a validator
- exposing JSON-RPC access where enabled
- maintaining local chain state

Validator nodes additionally participate in block production and consensus voting according to the active validator set.

With delegated PoS active, validator participation depends on the staking and validator-set rules enforced by the active chain configuration and node implementation.

---

## 13. Configuration as source of truth

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

## 14. Separation from application-layer documentation

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

Those topics must be documented in their own documents.

Chain documentation should remain limited to protocol, node, consensus, staking, configuration, gas, RPC and operator behavior.

---

## 15. Document status

This document reflects the XGR2.0 delegated PoS mainnet baseline.

It should be updated whenever one of the following changes:

- active node branch or release baseline
- published chain configuration
- PoS activation settings
- staking contract behavior
- validator lifecycle behavior
- delegation lifecycle behavior
- epoch or micro-epoch behavior
- gas or fee behavior
- RPC endpoint behavior
- node operation requirements

For implementation-level details, use the public node source code and the published XGR Chain configuration as the authoritative references.
