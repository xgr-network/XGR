# XGR Chain — Introduction

**Document ID:** XGRCHAIN-INTRO  
**Last updated:** 2026-10-04  
**Audience:** Developers, node operators, validators, auditors, integrators  
**Implementation status:** Mainnet  
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
- native Interchain integration.

The public node implementation is:

```text
https://github.com/xgr-network/xgr-node
```

Current public node baseline:

```text
v3.1.1
```

---

## 2. Public standalone node

`xgr-node v3.1.1` builds and operates as a standalone public XGRChain node.

Normal chain operation does not require:

```text
xgrEngine
XDaLa application services
private engine repositories
```

A standard public build can be produced from the tagged release:

```bash
git clone https://github.com/xgr-network/xgr-node.git
cd xgr-node
git fetch --all --tags
git checkout v3.1.1
make -f scripts/Makefile build
```

The build embeds release/version metadata into the binary.

For production deployments, operators may instead use the published release binary and checksum artifacts.

---

## 3. Mainnet identity

The canonical mainnet genesis is maintained in:

```text
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

```text
chainId = 1643
```

Operators joining mainnet must use the canonical published chain configuration.

---

## 4. Current public baseline

The current public `v3.1.1` node baseline provides:

| Area | Status |
| --- | --- |
| EVM execution | Mainnet |
| IBFT deterministic finality | Mainnet |
| Delegated PoS | Mainnet |
| Stake-weighted voting power | Mainnet |
| Uptime-weighted PoS accounting | Mainnet |
| Validator self-staking | Mainnet |
| Delegated staking | Mainnet |
| Epoch-based validator lifecycle | Mainnet |
| Standard Ethereum JSON-RPC | Mainnet |
| Public PoS monitoring RPC | Mainnet |
| Genesis/config loading | Mainnet |
| State Growth Control / Trie Sweeper | Mainnet |
| Configurable historical-state retention | Mainnet |
| Native Interchain BLS verification primitive | Mainnet |
| XGRChain ↔ Base Interchain route | Mainnet |
| Public bidirectional XGR Bridge | Mainnet |

The node software baseline and higher-level services are versioned independently.

For example:

```text
xgr-node v3.1.1
```

defines the public node baseline, while Interchain routers, validator registries, security modules and relayer runtime are maintained as a separate deployment layer.

The XGRChain ↔ Base asset route is deployed in both directions, has been validated end-to-end on mainnet and is exposed through the public XGR Bridge.

Public bridge:

```text
https://bridge.xgr.network
```

Dynamic operational state such as route gates, pause controls, current validator membership, RPC health and relayer process state remains independent from the static node release baseline.

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

```text
minimum = 4
maximum = 25
```

Validator participation is staking-based and governed by protocol-defined eligibility, lifecycle and validator-set rules.

The normal validator qualification model distinguishes:

```text
minimum validator self stake
```

from:

```text
minimum effective total support
```

Detailed thresholds and lifecycle rules are documented in the staking model.

---

## 9. Voting power

During stake-weighted PoS operation, consensus voting power is not simply one vote per validator.

At a high level:

```text
effectiveVotingPower =
    votingStake
    × effectiveUptimeWeight
    ÷ nominalUptimeWeight
```

Consensus quorum is determined from total voting power:

```text
quorum =
    ceil(2 × totalVotingPower / 3)
```

Therefore:

> validator count and validator voting power are different concepts.

The PoS transition boundary contains additional deterministic cutover behavior documented in the IBFT and staking references.

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

```text
25 × 40 = 1000 blocks
```

At the nominal two-second block target:

```text
1000 blocks ≈ 33 minutes 20 seconds
```

Actual elapsed time depends on real block production.

---

## 11. EVM compatibility

XGRChain supports standard Ethereum-style execution and tooling.

Supported public transaction types include:

| Type | Code |
| --- | --- |
| Legacy | `0x00` |
| Access-list | `0x01` |
| Dynamic fee | `0x02` |

The node also defines the internal protocol transaction type:

```text
StateTx = 0x7f
```

`StateTx` is used for internal system-level execution and is not a normal user-wallet transaction type.

Ordinary applications can use standard EVM transaction envelopes.

---

## 12. JSON-RPC

Registered RPC namespaces include:

```text
eth_*
net_*
web3_*
txpool_*
bridge_*
xgr_*
debug_*
```

Not every registered namespace should be exposed unrestricted to public clients.

Important XGR-specific PoS methods include:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

Native Interchain attestation methods include:

```text
xgr_getInterchainAttestation
xgr_getInterchainAttestationByCheckpoint
```

The public RPC interface can therefore serve:

- wallets,
- explorers,
- dApps,
- monitoring systems,
- staking dashboards,
- validator tooling,
- Interchain infrastructure.

Standard Ethereum compatibility, PoS extensions and operator interfaces are documented separately.

---

## 13. Gas and fees

XGRChain uses Ethereum-compatible fee fields but XGR-specific fee policy.

Transaction fields include:

```text
gasPrice
maxFeePerGas
maxPriorityFeePerGas
```

Current public RPC suggestion behavior includes:

```text
eth_gasPrice = current header base fee
eth_maxPriorityFeePerGas = 0
```

The TxPool validates transaction fee sufficiency against the base fee calculated for the next block.

During emergency congestion above the configured utilization threshold, the TxPool admission value can therefore exceed the current-header value returned by `eth_gasPrice`.

XGRChain additionally implements:

- configurable minimum-base-fee behavior,
- utilization-dependent emergency pricing,
- XGR-specific fee accounting,
- donation and burn components,
- immediate validator fees,
- PoS FeePool distribution.

Ethereum RPC compatibility does not imply Ethereum mainnet fee economics.

---

## 14. Native XGR protocol primitives

XGRChain extends standard EVM execution with XGR-specific native functionality.

One `v3.1.1` protocol primitive is the native Interchain BLS12-381 verifier:

```text
0x0000000000000000000000000000000000002040
```

This precompile verifies native XGR Interchain quorum attestations.

Because it is a native precompile:

- no EVM bytecode deployment is required at that address,
- execution is implemented directly by the node,
- it is available as part of the node execution environment.

This provides native execution support for the XGR Interchain security stack.

The precompile does not itself define:

- a bridge route,
- router deployment,
- relayer availability,
- Interchain validator membership,
- destination security policy.

Those belong to the separate Interchain layer.

---

## 15. XGR Interchain

XGR Network maintains XGRChain-native Interchain infrastructure connecting XGRChain with supported external chains.

The first production XGR asset route connects:

```text
XGRChain ↔ Base
```

Network identities:

| Network | Chain ID | Interchain domain | Asset |
| --- | ---: | ---: | --- |
| XGRChain | `1643` | `1643` | Native XGR |
| Base | `8453` | `8453` | wXGR |

The asset model is:

```text
XGRChain                     Base

native XGR
   │
   │ lock
   ▼
XGR router
   │
   │ authenticated
   │ cross-chain message
   ▼
                              mint
                               │
                               ▼
                              wXGR
```

Reverse direction:

```text
Base                         XGRChain

wXGR
  │
  │ burn
  ▼
Base router
  │
  │ authenticated
  │ cross-chain message
  ▼
                              unlock
                                │
                                ▼
                            native XGR
```

Both directions are deployed and have been validated end-to-end on mainnet.

The public bidirectional bridge is available at:

```text
https://bridge.xgr.network
```

Official Base wXGR contract:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

The nominal bridge representation is:

```text
1 XGR ↔ 1 wXGR
```

before applicable transaction and routing fees.

The Interchain layer uses:

- Hyperlane-compatible cross-chain messaging,
- destination-specific XGR Interchain validator registries,
- XGR-native validator attestations,
- BLS aggregate signatures,
- Merkle inclusion proofs,
- destination security modules,
- native relayers,
- asset router contracts,
- explicit operational safety controls.

XGRChain provides native support for this security model, including the native BLS verification precompile at:

```text
0x0000000000000000000000000000000000002040
```

The Interchain worker is deliberately separated from weighted-IBFT consensus-critical execution.

Therefore:

```text
XGRChain consensus
≠
XGR Interchain validator quorum
```

A remote-network or relayer failure must not prevent XGRChain block production, verification or IBFT finality.

Public Interchain specification:

```text
docs/interchain/XGR_INTERCHAIN_Overview.md
docs/interchain/XGR_INTERCHAIN_Security_Model.md
docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md
docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md
```

Implementation and deployment tooling:

```text
https://github.com/xgr-network/xgr-hyperlane
```

Dynamic operational availability remains a live property.

Route gates, pause controls, current validator membership, RPC health and relayer process state must therefore be queried from current deployment and runtime state when operational availability matters.

---

## 16. Consensus validators vs Interchain validators

These are related but separate roles.

### XGRChain consensus validator

Participates in:

- IBFT,
- block production,
- block finality,
- delegated PoS,
- stake- and uptime-weighted consensus voting power.

### XGR Interchain validator

Participates in:

- destination-specific Interchain membership,
- cross-chain checkpoint attestation,
- BLS aggregate signatures,
- Interchain quorum.

An Interchain validator does not automatically receive additional XGRChain consensus authority.

Likewise, a consensus validator is not automatically part of every Interchain validator set.

The current native Interchain quorum uses separate quorum semantics from weighted XGRChain IBFT consensus.

Therefore:

```text
XGRChain consensus voting power
≠
Interchain attestation voting weight
```

Detailed security semantics are documented in:

```text
docs/interchain/XGR_INTERCHAIN_Security_Model.md
```

---

## 17. State storage

XGRChain stores EVM state in an immutable, content-addressed trie.

Historical state can consume substantial disk space over time.

Starting with:

```text
xgr-node v2.1.0
```

the node includes State Growth Control through the Online State Trie Sweeper.

This feature remains available in:

```text
v3.1.1
```

---

## 18. State Growth Control

The Online State Trie Sweeper allows operators to retain a configurable window of recent canonical state roots and reclaim unreachable historical trie and contract-code data.

Default settings:

| Setting | Default |
| --- | ---: |
| Sweeper | Disabled |
| Retention | `10,000` blocks |
| Interval | `6h` |

CLI controls:

```text
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

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
eth_estimateGas
debug_trace*
```

Archive-style nodes requiring unrestricted historical-state access should keep the Trie Sweeper disabled or use a retention policy suitable for that workload.

Detailed behavior is documented in:

```text
XGRCHAIN_State_Storage_and_Retention.md
```

---

## 20. Node roles

Typical XGRChain node roles include:

### Full node

- follows the canonical chain,
- validates blocks,
- maintains state,
- participates in P2P,
- does not produce blocks.

Typical configuration:

```text
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

```text
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
- Trie Sweeper,
- local state retention.

### External-service configuration

Defines systems such as:

- Interchain relayers,
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
- TxPool admission,
- validator authority,
- smart-contract authorization,
- external-service credentials.

For example:

> a public RPC user is not a validator.

Likewise:

> an Interchain relayer account is not a consensus validator.

The main authority domains include:

```text
user wallet authority
XGRChain consensus authority
XGR Interchain BLS authority
relayer transaction-submission authority
contract administration authority
```

These must not be treated as interchangeable.

Permission boundaries are documented in:

```text
XGRCHAIN_Access_Control_and_Permission_Boundaries.md
```

Interchain-specific authority boundaries are documented in:

```text
../interchain/XGR_INTERCHAIN_Security_Model.md
```

---

## 24. XGRChain and XDaLa

XGRChain is the blockchain substrate.

XDaLa is a higher-level execution and process framework built on XGR infrastructure.

XGRChain itself provides:

- execution,
- consensus,
- finality,
- state,
- RPC,
- staking,
- protocol primitives.

XDaLa provides separate application and process capabilities.

XDaLa functionality is deployed on XGRChain mainnet.

A standard public XGRChain node does not need to run the complete XDaLa service stack.

---

## 25. Documentation structure

The Chain documentation is divided into specialized references.

Current documents include:

```text
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

Public Interchain specifications are maintained in:

```text
docs/interchain/
```

Current Interchain documents include:

```text
XGR_INTERCHAIN_Overview.md
XGR_INTERCHAIN_Security_Model.md
XGR_INTERCHAIN_Asset_Bridge.md
XGR_INTERCHAIN_Deployment_Reference.md
```

Implementation-specific Interchain contracts, deployment manifests, relayer runtime and operator documentation are maintained separately in:

```text
xgr-network/xgr-hyperlane
```

---

## 26. Source-of-truth hierarchy

For network-defining behavior, the source-of-truth order is:

1. active compatible node implementation,
2. canonical published mainnet configuration,
3. deployed protocol state where applicable,
4. current technical documentation.

For XGR Interchain, additional implementation and runtime sources are:

```text
xgr-network/xgr-hyperlane
live deployed Interchain contracts
live relayer runtime state
```

Documentation must describe the actual implementation and network state.

It must not invent protocol behavior that is not supported by the active release or deployment.

Static documentation must not override live operational state when current availability is being evaluated.

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
- Interchain architecture,
- public Interchain deployment,
- node build requirements.

Current documentation baseline:

```text
xgr-node v3.1.1
```

Canonical network configuration:

```text
xgr-network/XGR
genesis/mainnet/genesis.json
```

Canonical public Interchain specifications:

```text
xgr-network/XGR
docs/interchain/
```

Canonical Interchain implementation:

```text
xgr-network/xgr-hyperlane
```

---

## 28. Summary

| Topic | Current XGRChain behavior |
| --- | --- |
| Implementation status | Mainnet |
| Public node | `xgr-node v3.1.1` |
| Chain ID | `1643` |
| Native asset | XGR |
| EVM compatibility | Mainnet |
| IBFT finality | Mainnet |
| Delegated PoS | Mainnet |
| PoS activation | block `5446500` |
| Validator limits | `4–25` |
| Stake-weighted consensus | Mainnet |
| Uptime weighting | Mainnet |
| Block target | approximately 2 seconds |
| Standard Ethereum RPC | Mainnet |
| PoS monitoring RPC | Mainnet |
| Trie Sweeper | Mainnet |
| Default state retention when enabled | `10,000` blocks |
| Native Interchain BLS precompile | `0x2040` |
| XGRChain ↔ Base route | Mainnet |
| Bidirectional asset transfer | Mainnet validated |
| Public XGR Bridge | Mainnet |
| Public node dependency on XDaLa | None |

XGRChain is a standalone EVM-compatible Layer-1 with deterministic IBFT finality, delegated PoS, configurable state retention and native protocol support for the XGR Interchain stack.

The current production Interchain route connects native XGR on XGRChain with wXGR on Base through a bidirectional mainnet bridge secured by XGR-native BLS-verified Interchain infrastructure.
