# XGR Chain — Introduction

**Document ID:** XGRCHAIN-INTRO  
**Last updated:** 2026-10-03  
**Audience:** Developers, node operators, validators, auditors, integrators  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Public XGRChain protocol and node overview

---

## 1. What is XGRChain?

XGRChain is the EVM-compatible Layer-1 blockchain of the XGR Network.

It is an independent blockchain with its own:

- genesis configuration,
- chain ID,
- native asset,
- validator set,
- consensus configuration,
- protocol parameters,
- gas and fee model,
- staking system,
- runtime implementation,
- upgrade path.

XGRChain provides the execution and settlement layer for:

- Ethereum-compatible accounts,
- Ethereum-compatible smart contracts,
- Ethereum-compatible transactions,
- native XGR transfers,
- standard Ethereum JSON-RPC,
- deterministic IBFT finality,
- delegated PoS validator participation,
- validator self-staking,
- delegated staking,
- epoch-based validator lifecycle,
- stake- and uptime-aware voting power,
- XGR-specific protocol primitives,
- interchain integration.

The public node implementation is:

```text id="2m0bg4"
https://github.com/xgr-network/xgr-node
```

Current public node baseline:

```text id="r52uhl"
v3.1.1
```

---

## 2. Public standalone node

`xgr-node v3.1.1` builds and operates as a standalone public XGRChain node.

Normal chain operation does not require:

```text id="945zrq"
xgrEngine
XDaLa application services
private engine repositories
```

A standard public build can be produced from the tagged release:

```bash id="34w51f"
git clone https://github.com/xgr-network/xgr-node.git
cd xgr-node
git fetch --all --tags
git checkout v3.1.1
go build -o xgrchain .
```

For production deployments, operators may instead use the published release binary and checksum artifacts.

---

## 3. Mainnet identity

The canonical mainnet genesis is maintained in:

```text id="wxuo4r"
Repository: xgr-network/XGR
Branch:     main
Path:       genesis/mainnet/genesis.json
```

Mainnet identity:

| Field | Value |
| --- | --- |
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Native asset | XGR |
| Native decimals | `18` |
| Execution model | EVM-compatible |
| Consensus | IBFT |
| Current validator model | Delegated PoS |
| PoS activation block | `5446500` |
| Target block time | approximately 2 seconds |
| Genesis gas limit | `60,000,000` |

Mainnet transactions must be signed for:

```text id="6kxwfh"
chainId = 1643
```

Operators joining mainnet must use the canonical published chain configuration.

---

## 4. Current public baseline

The current public `v3.1.1` node baseline provides:

| Area | Status |
| --- | --- |
| EVM execution | Active |
| IBFT deterministic finality | Active |
| Delegated PoS | Active |
| Stake-weighted voting power | Active |
| Uptime-weighted PoS accounting | Active |
| Validator self-staking | Active |
| Delegated staking | Active |
| Epoch-based validator lifecycle | Active |
| Standard Ethereum JSON-RPC | Active |
| Public PoS monitoring RPC | Active |
| Genesis/config loading | Active |
| State Growth Control / Trie Sweeper | Available |
| Configurable historical-state retention | Available |
| Native interchain BLS verification primitive | Active |
| XGRChain ↔ Base interchain route | Implemented and bidirectionally validated |

The node software baseline and higher-level services are versioned independently.

For example:

```text id="zrkl21"
xgr-node v3.1.1
```

defines the public node baseline, while interchain router and relayer deployments are maintained separately.

---

## 5. Architecture overview

At a high level, XGRChain consists of the following functional layers:

| Layer | Purpose |
| --- | --- |
| EVM execution | Executes transactions and smart contracts |
| IBFT consensus | Finalizes valid blocks deterministically |
| Delegated PoS | Determines validator participation and voting power |
| Networking | Connects nodes through P2P |
| JSON-RPC | Provides Ethereum-compatible application access |
| PoS RPC | Provides validator and delegation visibility |
| Configuration | Defines chain ID, genesis, forks and protocol parameters |
| Gas and fee layer | Implements XGR-specific fee behavior |
| State storage | Stores current and historical EVM state |
| Native protocol primitives | Provides XGR-specific execution capabilities |
| Interchain layer | Connects XGRChain to external networks |

These layers have distinct security and operational boundaries.

---

## 6. Execution model

XGRChain uses an Ethereum-compatible EVM execution pipeline.

For each candidate block:

1. transactions are selected,
2. the proposer constructs a block,
3. transactions execute against the parent state,
4. balances, nonces, code and storage are updated,
5. logs and receipts are generated,
6. gas and fees are accounted,
7. a new state root is calculated,
8. validators independently reproduce and verify the result,
9. IBFT finality is reached when sufficient consensus voting power commits the block.

The proposer does not define canonical state unilaterally.

Every honest validator independently verifies the state transition.

---

## 7. Consensus

XGRChain uses IBFT for deterministic finality.

The current mainnet phase schedule is:

| Phase | Type | Validator type | Block range |
| --- | --- | --- | --- |
| Initial | PoA | BLS | `0–5446499` |
| Current | PoS | BLS | `5446500+` |

IBFT remains the block-finality protocol in both phases.

PoS determines:

- active validator membership,
- validator staking,
- delegation,
- voting power,
- validator-set evolution,
- epoch behavior.

---

## 8. Delegated PoS

The current validator model is delegated PoS.

It includes:

- validator self-stake,
- delegator stake,
- delegation pools,
- validator activation,
- validator deactivation,
- minimum qualification rules,
- active delegated stake,
- epoch-boundary state changes,
- stake-weighted consensus power,
- uptime-derived weighting.

Published mainnet validator-count limits:

```text id="ni5agq"
minimum = 4
maximum = 25
```

Validator participation is permissionless within the protocol rules.

---

## 9. Voting power

During PoS operation, consensus voting power is not simply one vote per validator.

At a high level:

```text id="32n8u0"
effectiveVotingPower =
    effectiveStake
    × uptimeWeight
    ÷ nominalWeight
```

Consensus quorum is determined from total voting power:

```text id="ctpkmj"
quorum =
    ceil(2 × totalVotingPower / 3)
```

Therefore:

> validator count and validator voting power are different concepts.

This is important for monitoring and fault analysis.

---

## 10. Epoch model

Published PoS parameters:

| Parameter | Value |
| --- | ---: |
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Macro epoch | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

Macro epoch:

```text id="b64ydj"
25 × 40 = 1000 blocks
```

At the nominal two-second block target:

```text id="mnn3su"
1000 blocks ≈ 33 minutes 20 seconds
```

Actual elapsed time depends on real block production.

---

## 11. EVM compatibility

XGRChain supports standard Ethereum-style execution and tooling.

Supported transaction types include:

| Type | Code |
| --- | --- |
| Legacy | `0x00` |
| Access-list | `0x01` |
| Dynamic fee | `0x02` |

The node also defines the internal protocol transaction type:

```text id="mvjquf"
StateTx = 0x7f
```

`StateTx` is used for internal system-level execution and is not a normal user-wallet transaction type.

Ordinary applications can use standard EVM transaction envelopes.

---

## 12. JSON-RPC

Standard RPC namespaces include:

```text id="0641gc"
eth_*
net_*
web3_*
```

Important XGR-specific PoS methods include:

```text id="6doq51"
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

The public RPC interface can therefore serve:

- wallets,
- explorers,
- dApps,
- monitoring systems,
- staking dashboards,
- validator tooling.

Standard Ethereum compatibility and XGR-specific extensions are documented separately.

---

## 13. Gas and fees

XGRChain uses Ethereum-compatible fee fields but XGR-specific fee policy.

Transaction fields include:

```text id="vbzc96"
gasPrice
maxFeePerGas
maxPriorityFeePerGas
```

Current public RPC suggestion behavior includes:

```text id="5dba5g"
eth_gasPrice = current base fee
eth_maxPriorityFeePerGas = 0
```

XGRChain additionally implements:

- minimum-base-fee behavior,
- utilization-dependent fee behavior,
- PoS fee distribution,
- validator fee allocation,
- protocol-specific fee handling.

Ethereum RPC compatibility does not imply Ethereum mainnet fee economics.

---

## 14. Native XGR protocol primitives

XGRChain extends standard EVM execution with XGR-specific native functionality.

One `v3.1.1` protocol primitive is the native interchain BLS12-381 verifier:

```text id="y37vgw"
0x0000000000000000000000000000000000002040
```

This precompile verifies native XGR interchain quorum attestations.

Because it is a native precompile:

- no EVM bytecode deployment is required at that address,
- execution is implemented directly by the node,
- it is available as part of the node execution environment.

The precompile does not itself define a bridge route or validator policy.

Those belong to the separate interchain layer.

---

## 15. XGR Interchain

XGR Network operates interchain infrastructure that connects XGRChain with supported external chains.

The first production route connects:

```text id="z074yk"
XGRChain ↔ Base
```

The asset model is:

```text id="6im4bm"
XGRChain                     Base

native XGR
   │
   │ lock
   ▼
XGR router
   │
   │ cross-chain message
   ▼
                              mint
                               │
                               ▼
                              wXGR
```

Reverse direction:

```text id="ohikmh"
Base                         XGRChain

wXGR
  │
  │ burn
  ▼
Base router
  │
  │ cross-chain message
  ▼
                              unlock
                                │
                                ▼
                            native XGR
```

Both directions have been validated end-to-end on mainnet.

The interchain layer uses:

- cross-chain messaging,
- validator attestations,
- BLS verification,
- Merkle proofs,
- destination security modules,
- relayers,
- router contracts.

Detailed interchain architecture is documented separately.

---

## 16. Consensus validators vs interchain validators

These are different roles.

### XGRChain consensus validator

Participates in:

- IBFT,
- block production,
- block finality,
- delegated PoS,
- consensus voting power.

### Interchain validator

Participates in:

- cross-chain checkpoint attestation,
- interchain message verification,
- interchain security policy.

An interchain validator does not automatically receive XGRChain consensus authority.

Likewise, a consensus validator is not automatically part of an interchain validator set.

---

## 17. State storage

XGRChain stores EVM state in an immutable, content-addressed trie.

Historical state can consume substantial disk space over time.

Starting with:

```text id="x30pzf"
xgr-node v2.1.0
```

the node includes State Growth Control through the Online State Trie Sweeper.

This feature remains available in:

```text id="0i83cm"
v3.1.1
```

---

## 18. State Growth Control

The Online State Trie Sweeper allows operators to retain a configurable window of recent canonical state roots and reclaim unreachable historical trie data.

Default settings:

| Setting | Default |
| --- | ---: |
| Sweeper | Disabled |
| Retention | `10,000` blocks |
| Interval | `6h` |

CLI controls:

```text id="bkfzxu"
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

The sweeper is a local storage feature.

It does not change:

- consensus,
- canonical state roots,
- transaction validity,
- genesis,
- validator selection,
- staking.

---

## 19. Historical-state implications

Trie pruning affects historical EVM state.

It does not remove normal canonical block history such as:

- block headers,
- block bodies,
- transactions,
- receipts,
- logs.

However, sufficiently old state-dependent requests may no longer be available on a pruned node.

Examples include historical:

```text id="h2184a"
eth_getBalance
eth_getCode
eth_getStorageAt
eth_call
```

Archive-style nodes requiring unrestricted historical-state access should keep the trie sweeper disabled or use a retention policy suitable for that workload.

Detailed behavior is documented in:

```text id="qcc3y7"
XGRCHAIN_State_Storage_and_Retention.md
```

---

## 20. Node roles

Typical XGRChain node roles include:

### Full node

- follows canonical chain,
- validates blocks,
- maintains state,
- participates in P2P,
- does not produce blocks.

Recommended:

```text id="dba7kz"
--seal=false
```

### RPC node

- performs full-node duties,
- additionally serves application RPC,
- should normally be separated from validator infrastructure.

### Validator

- maintains chain state,
- participates in IBFT,
- signs consensus messages,
- requires validator signing material.

Validator operation uses:

```text id="4bsiz3"
--seal=true
```

### Archive-style node

- preserves historical state for long-term state queries,
- typically runs without state trie pruning.

---

## 21. Networking

Nodes communicate through XGRChain's peer-to-peer network.

Networking provides:

- peer discovery,
- transaction propagation,
- block propagation,
- synchronization,
- consensus messaging.

Bootnodes assist initial peer discovery.

They do not grant validator or transaction authority.

---

## 22. Configuration boundaries

XGRChain distinguishes three major configuration domains.

### Chain configuration

Defines:

- chain ID,
- genesis,
- consensus,
- PoS activation,
- fork schedule,
- protocol addresses.

### Node runtime configuration

Defines:

- data directory,
- RPC bind addresses,
- P2P interfaces,
- logging,
- metrics,
- sealing,
- trie sweeper,
- local retention.

### External-service configuration

Defines systems such as:

- interchain relayers,
- remote-chain RPCs,
- router deployments,
- security modules,
- operational monitoring services.

These configuration domains must not be conflated.

---

## 23. Access-control boundaries

XGRChain security spans multiple independent layers:

- infrastructure access,
- P2P connectivity,
- RPC exposure,
- transaction validation,
- txpool admission,
- validator authority,
- smart-contract authorization,
- external service credentials.

For example:

> a public RPC user is not a validator.

Likewise:

> an interchain relayer account is not a consensus validator.

Permission boundaries are documented in:

```text id="qe7gkx"
XGRCHAIN_Access_Control_and_Permission_Boundaries.md
```

---

## 24. XGRChain and XDaLa

XGRChain is the blockchain substrate.

XDaLa is a higher-level execution and process framework built on top of XGR infrastructure.

XGRChain itself provides:

- execution,
- consensus,
- finality,
- state,
- RPC,
- staking,
- protocol primitives.

XDaLa provides separate application/process capabilities.

A standard public XGRChain node does not need to run the complete XDaLa service stack.

---

## 25. Documentation structure

The Chain documentation is divided into specialized references.

Key documents include:

```text id="2nuogx"
XGRCHAIN_Introduction.md
XGRCHAIN_Chain_Spec.md
XGRCHAIN_Consensus_IBFT.md
XGRCHAIN_Genesis_and_Configuration.md
XGRCHAIN_Node_Operation.md
XGRCHAIN_Networking_P2P.md
XGRCHAIN_Ethereum_JSON_RPC_Reference.md
XGRCHAIN_Node_Operator_RPC_Reference.md
XGRCHAIN_Staking_PoS_Model.md
XGRCHAIN_Staking_PoS_Endpoint_Reference.md
XGRCHAIN_State_Storage_and_Retention.md
XGRCHAIN_Access_Control_and_Permission_Boundaries.md
XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md
XRC-GAS_Gas_Price_Behavior.md
```

Interchain architecture and operations are maintained as separate documentation.

---

## 26. Source-of-truth hierarchy

For network-defining behavior, the source-of-truth order is:

1. active compatible node implementation,
2. canonical published mainnet configuration,
3. deployed protocol state where applicable,
4. current technical documentation.

Documentation must describe the actual implementation and network state.

It must not invent protocol behavior that is not supported by the active release or deployment.

---

## 27. Update triggers

This document must be reviewed when any of the following changes:

- public node release,
- mainnet genesis,
- chain ID,
- consensus behavior,
- PoS behavior,
- validator lifecycle,
- voting-power logic,
- epoch configuration,
- Ethereum RPC behavior,
- gas or fee behavior,
- native protocol precompiles,
- state-retention behavior,
- interchain architecture,
- node build requirements.

Current documentation baseline:

```text id="np0zs2"
xgr-node v3.1.1
```

Canonical network configuration:

```text id="aylsv8"
xgr-network/XGR
genesis/mainnet/genesis.json
```

---

## 28. Summary

| Topic | Current XGRChain behavior |
| --- | --- |
| Public node | `xgr-node v3.1.1` |
| Chain ID | `1643` |
| Native asset | XGR |
| EVM compatibility | Active |
| IBFT finality | Active |
| Delegated PoS | Active |
| PoS activation | block `5446500` |
| Validator limits | `4–25` |
| Stake-weighted consensus | Active |
| Uptime weighting | Active |
| Block target | approximately 2 seconds |
| Standard Ethereum RPC | Active |
| PoS monitoring RPC | Active |
| Trie Sweeper | Available |
| Default state retention when enabled | `10,000` blocks |
| Native interchain BLS precompile | `0x2040` |
| XGRChain ↔ Base route | Bidirectionally validated |
| Public node dependency on XDaLa | None |

XGRChain is a standalone EVM-compatible Layer-1 with deterministic IBFT finality, delegated PoS, configurable state retention and native protocol support for the XGR interchain stack.
