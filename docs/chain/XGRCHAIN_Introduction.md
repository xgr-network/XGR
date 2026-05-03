# XGR Chain — Introduction

**Document ID:** XGRCHAIN-INTRO  
**Last updated:** 2026-05-03  
**Audience:** Developers, node operators, auditors, integrators  
**Implementation status:** Current public baseline with separately released XGR extensions and preview components  
**Source of truth:** Public `xgr-network/xgr-node` releases, published XGR Chain configuration, and official XGR Network operator announcements

---

## 1. What is XGR Chain?

**XGR Chain** is the EVM-compatible Layer-1 blockchain of the XGR Network.

It is an independent blockchain network with its own:

- genesis configuration
- chain ID
- validator set
- consensus configuration
- protocol parameters
- native fee behavior
- runtime and upgrade path

XGR Chain provides the execution and settlement layer for:

- Ethereum-compatible accounts
- Ethereum-compatible smart contracts
- Ethereum-compatible transactions
- standard Ethereum JSON-RPC access
- deterministic-finality consensus
- XGR-native gas and fee behavior
- XGR-specific validation and orchestration features where supported by the active release stack

The public node baseline is provided through:

```text
https://github.com/xgr-network/xgr-node
```

The public node baseline provides:

- EVM execution
- consensus networking
- standard Ethereum JSON-RPC interface
- configuration and genesis tooling
- node operation primitives

Network-specific values are defined by the published XGR Chain configuration.

---

## 2. Release and feature status

XGR Chain uses a staged release model.

The documentation distinguishes between:

1. **current public baseline behavior**
2. **published network configuration**
3. **XGR-specific extensions**
4. **preview or upcoming protocol components**

This distinction is important because not every XGR feature is necessarily part of the current public baseline node release.

### 2.1 Current public baseline

The current public baseline is the versioned public node software released through:

```text
xgr-network/xgr-node
```

Current stable baseline example:

```text
v1.1.1
```

This baseline covers:

| Area | Status |
|---|---|
| EVM execution | Current public baseline |
| Consensus networking | Current public baseline |
| Standard Ethereum JSON-RPC | Current public baseline |
| Genesis / configuration tooling | Current public baseline |
| Node operation | Current public baseline |
| Public release tags | Current public baseline |

### 2.2 Published chain configuration

The published XGR Chain configuration defines network-specific values such as:

- chain ID
- genesis block
- fork activation settings
- consensus parameters
- bootnodes
- pre-funded accounts
- block gas limit
- fee-related configuration
- protocol-level configured addresses where applicable

Operators must use the published XGR Chain configuration for the target network.

### 2.3 XGR-specific extensions

XGR-specific extension areas include:

- XDaLa RPC methods
- XRC-137 rule contracts
- XRC-729 orchestration/session contracts
- XGR-specific gas and fee behavior
- encrypted grants and permission flows
- validation gas behavior
- process execution and orchestration flows

Their availability depends on the active official XGR release stack and published operator instructions.

### 2.4 Preview / upcoming components

Some components may be documented as preview or upcoming when they are not part of the current public baseline release.

This includes, where applicable:

- staking-based validator model
- permissionless validator join
- delegated staking
- stake-weighted voting power
- staking-specific RPC endpoints
- micro/macro epoch staking semantics

Preview documentation is intended for technical orientation and integration planning. It should not be treated as production availability unless an official release or operator announcement activates it.

---

## 3. Architecture overview

At a high level, XGR Chain consists of several functional layers.

| Layer | Purpose | Status |
|---|---|---|
| EVM execution layer | Executes Ethereum-compatible transactions and smart contracts | Public baseline |
| Consensus layer | Produces and finalizes blocks through IBFT | Public baseline |
| Networking layer | Connects nodes through peer-to-peer networking | Public baseline |
| JSON-RPC layer | Provides Ethereum-compatible RPC access for wallets, explorers, scripts and infrastructure | Public baseline |
| Configuration layer | Defines chain ID, genesis, fork activation, bootnodes and protocol parameters | Published XGR configuration |
| XGR extension layer | Provides XGR-specific validation, orchestration and process features | Release-dependent |
| Staking / PoS layer | Provides staking, delegation and stake-weighted validator participation where applicable | Preview/upcoming unless activated |

The chain layer remains EVM-compatible.

XGR-specific functionality extends the network through additional contracts, RPC methods and protocol modules where supported by the active release stack.

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
| XGR extension RPC | `xgr_*` where supported |
| Finality model | IBFT deterministic finality |
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

## 6. EVM compatibility

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
- dynamic fee / type-2 transactions where supported by the active fork configuration
- contract creation transactions
- contract call transactions

Exact behavior depends on the active published fork configuration.

---

## 7. Consensus and validator model

XGR Chain uses **IBFT** as its deterministic-finality consensus protocol.

IBFT provides finality under Byzantine fault assumptions.

At a high level:

1. a proposer is selected for a round
2. the proposer builds a candidate block
3. validators independently verify the candidate block
4. validators exchange consensus messages
5. a block is committed once the required quorum is reached
6. the committed block is final under IBFT assumptions

Current validator operation is part of the public node and chain operation model.

Staking-based validator participation is documented separately where applicable and must be interpreted according to its release status.

---

## 8. Staking / PoS upgrade path

XGR Chain is designed to evolve toward a staking-based validator model where activated by the official release path.

The staking model may include:

- permissionless validator join
- delegated staking
- stake-weighted voting power
- validator activation and deactivation
- validator monitoring endpoints
- epoch-based staking behavior
- staking-specific operator checks

Until activated by an official release and operator announcement, staking-related documentation should be treated as preview or upcoming technical documentation.

---

## 9. XDaLa integration

**XDaLa** is the XGR validation and orchestration layer.

It is designed for:

- rule-based validation
- rule contracts
- structured process execution
- orchestration sessions
- grants
- encrypted access flows
- validation gas estimation
- API-backed and contract-backed process logic where supported

XDaLa uses XGR-specific RPC methods in the `xgr_*` namespace where supported by the active release stack.

The standard Ethereum-compatible RPC surface and the XDaLa RPC surface are separate interfaces with different purposes.

---

## 10. XRC-137

**XRC-137** is the XGR rule-document / rule-contract standard.

It is used to describe validation logic in a structured format.

Depending on the active release stack and deployed contracts, XRC-137 can be used by XDaLa to:

- read rule definitions
- validate inputs
- estimate validation gas
- enforce structured rule logic
- connect on-chain contracts with validation and orchestration flows

XRC-137 belongs to the XGR extension layer.

---

## 11. XRC-729

**XRC-729** is the XGR orchestration/session contract standard.

It is designed to support controlled process execution and session-based orchestration.

Depending on the active release stack and deployed contracts, XRC-729 can be used for:

- orchestration sessions
- wake/kill/list session control
- process execution coordination
- structured execution state
- contract-mediated process rules

XRC-729 belongs to the XGR extension layer.

---

## 12. JSON-RPC surfaces

XGR Chain exposes different RPC surfaces for different purposes.

### 12.1 Standard Ethereum-compatible RPC

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

This surface is the compatibility layer for normal EVM tooling.

### 12.2 Operator and diagnostic RPC

Used by node operators for:

- status checks
- node diagnostics
- peer inspection
- transaction pool inspection
- validator and consensus monitoring where available

These methods are operational interfaces and should not automatically be exposed publicly.

### 12.3 XGR extension RPC

Used by validation and orchestration clients.

Typical namespace:

```text
xgr_*
```

This surface is used by XGR-specific features such as XDaLa where supported by the active release stack.

---

## 13. Gas and fee behavior

XGR Chain has XGR-specific gas and fee behavior.

It supports Ethereum-style transaction fee fields where supported by the active release and fork configuration, but XGR fee policy must not be assumed to be identical to Ethereum mainnet.

Relevant topics include:

- `gasPrice`
- `maxFeePerGas`
- `maxPriorityFeePerGas`
- base fee behavior
- minimum base fee behavior
- transaction pool price acceptance
- fee accounting
- burn, donation, validator or fee-pool semantics where configured
- explorer fee display

The exact gas and fee behavior is defined in the dedicated gas documentation and the active chain configuration.

---

## 14. Node operation

XGR Chain nodes can be operated in different roles.

Common roles include:

| Role | Purpose |
|---|---|
| Validator node | Participates in consensus and signs blocks |
| Full node | Follows and verifies the chain without signing blocks |
| RPC node | Serves JSON-RPC traffic for users, applications or infrastructure |
| Bootnode | Provides stable peer discovery support |

Node operation includes:

- release selection
- binary build or installation
- genesis/configuration setup
- data directory management
- key material handling
- P2P configuration
- RPC configuration
- validator operation
- monitoring
- logging
- metrics
- backups
- upgrades
- security

Node role and release status determine which options should be enabled.

---

## 15. Genesis and configuration

Genesis and configuration define the actual network.

They include:

- chain ID
- genesis block
- initial allocation
- fork activation settings
- consensus configuration
- bootnodes
- block gas limit
- fee-related parameters
- configured protocol addresses where applicable

Operators must not invent or locally alter production genesis values.

For public networks, use only the published XGR Chain configuration.

---

## 16. Network upgrades

Network upgrades and hardforks may involve:

- binary releases
- validator coordination
- fork activation
- configuration changes
- node rollout windows
- rollback boundaries
- monitoring requirements
- post-upgrade checks

Production upgrade instructions must come from official XGR Network release and operator announcements.

A local build or unpublished development state is not a production upgrade path.

---

## 17. Access control and permission boundaries

XGR Chain has multiple permission and exposure boundaries.

Relevant areas include:

- JSON-RPC exposure
- debug/operator endpoint exposure
- validator key isolation
- P2P boundary
- contract ownership
- XDaLa permits
- XDaLa grants
- encryption-related access flows

Validator infrastructure and public RPC infrastructure should be separated wherever possible.

Public RPC nodes should not hold validator signing material.

---

## 18. Networking and P2P

XGR Chain nodes communicate through peer-to-peer networking.

P2P operation includes:

- libp2p address handling
- bootnodes
- NAT configuration
- DNS advertisement
- peer limits
- discovery
- validator connectivity
- RPC vs P2P separation
- operational troubleshooting

A healthy node should maintain stable peer connectivity and follow the current chain height.

Validators require reliable networking to participate in consensus.

---

## 19. Glossary

| Term | Meaning |
|---|---|
| XGR Chain | The EVM-compatible blockchain layer of the XGR Network |
| XGR Network | The broader project, infrastructure, standards and ecosystem around XGR Chain |
| XDaLa | XGR validation and orchestration layer |
| XRC-137 | Rule-document / rule-contract standard |
| XRC-729 | Orchestration/session contract standard |
| IBFT | Istanbul Byzantine Fault Tolerance; deterministic-finality consensus protocol |
| EVM | Ethereum Virtual Machine |
| RPC | Remote Procedure Call interface |
| Standard RPC | Ethereum-compatible `eth_*`, `net_*`, `web3_*` RPC surface |
| XGR RPC | XGR-specific `xgr_*` RPC surface |
| Validator | Node participating in consensus and block finalization |
| Full node | Node that follows and verifies the chain but does not sign blocks |
| RPC node | Full node configured to serve JSON-RPC traffic |
| Bootnode | Node used for peer discovery |
| Genesis | Initial chain configuration and state |
| Chain ID | Replay-protection identifier for signed transactions |
| Release tag | Versioned public node release marker |
