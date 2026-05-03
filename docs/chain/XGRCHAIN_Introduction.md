# XGR Chain — Introduction

**Document ID:** XGRCHAIN-INTRO  
**Last updated:** 2026-05-03  
**Audience:** Developers, node operators, auditors, integrators  
**Implementation status:** Mixed  
**Source of truth:** `xgrchain`, `xgr-node`, chain genesis/configuration

---

## 1. What is XGR Chain?

**XGR Chain** is the EVM-compatible Layer-1 blockchain of the XGR Network.

It provides the execution and settlement layer for:

- standard Ethereum-compatible accounts, contracts and transactions
- XGR-native fee behavior
- XDaLa Engine integration
- XRC-137 rule contracts
- XRC-729 orchestration contracts
- current and upcoming IBFT-based validator operation
- the PoS / staking transition path under active implementation

XGR Chain started from a custom genesis block and does **not** inherit Ethereum state or history. It is a separate network with its own chain ID, validator set, genesis configuration and protocol parameters.

---

## 2. What XGR Chain is not

XGR Chain is not a Polygon Supernet documentation clone.

Older Polygon Edge documentation used terms such as:

- Edge-powered chain
- Supernets
- rootchain / childchain bridge
- Polygon CDK
- PolyBFT
- rootchain predicates
- checkpoint manager
- state sender / state receiver

Those concepts are not the canonical description of the current XGR Chain documentation.

XGR Chain uses an EVM-compatible client lineage, but the public XGR documentation must describe the actual XGR implementation, not historical Polygon Edge product narratives.

---

## 3. Architecture overview

At a high level, XGR consists of four layers:

| Layer | Purpose | Implementation status |
|---|---|---|
| XGR Chain | EVM-compatible blockchain, block production, transaction execution, fees and settlement | Mainnet / evolving |
| XDaLa Engine | Validation and orchestration engine exposed through `xgr_*` JSON-RPC endpoints | Mainnet |
| XRC-137 | Rule-document smart contract standard used by the Engine | Mainnet |
| XRC-729 | Orchestration/session smart contract standard used by the Engine | Mainnet |

The chain and the Engine are documented separately:

- Chain behavior lives under `docs/chain/`
- XDaLa / Engine endpoints live in the XDaLa endpoint reference
- XRC standards live in their own XRC documents

---

## 4. Chain identity

Current public chain documentation should treat these values as the canonical baseline unless a newer genesis/configuration document overrides them.

| Parameter | Value |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| EVM compatibility | Yes |
| Transaction signing | EIP-155 chain-id protected |
| Standard RPC | Ethereum JSON-RPC compatible |
| Engine RPC namespace | `xgr_*` |
| Main contract standards | XRC-137, XRC-729 |
| Fee model | XGR-specific gas and fee behavior |

---

## 5. Consensus and validator model

XGR Chain uses **IBFT** as its finality protocol.

IBFT provides deterministic finality: once a block is committed by the required validator quorum, it is final under the IBFT safety assumptions.

The validator model is evolving:

| Component | Implementation status | Notes |
|---|---|---|
| IBFT finality | Mainnet | Core consensus mechanism |
| BLS validator signatures | Mainnet | Used by the current validator setup |
| PoA validator setup | Mainnet / historical baseline | Existing operational baseline |
| PoS staking and permissionless validator join | In development / upgrade path | Implemented in the PoS branch and documented separately when finalized |
| Delegation staking | In development / upgrade path | Belongs in the PoS/Staking documentation |

Do not describe XGR Chain as a Polygon Supernet or PolyBFT chain.

---

## 6. XDaLa integration

XDaLa is the XGR Data Layer / validation and orchestration engine.

It enables:

- rule-based validation
- encrypted and plaintext rule documents
- validation gas estimation
- orchestration sessions
- grants and encrypted access flows
- wake/kill/list session control
- XRC-137 and XRC-729 based process execution

XDaLa is exposed through the `xgr_*` JSON-RPC namespace and is documented outside the chain-introduction document.

See:

- `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md`
- `XDaLa_Permit_Catalog.md`
- `xgr_encryptionGrants.md`
- `XRC-137_Rule_Document_Spec.md`
- `XRC-137_Smart_Contract_Standard.md`
- `XRC-729_Smart_Contract_Standard.md`

---

## 7. Documentation map

Use these documents as the canonical public documentation set.

| Document | Purpose |
|---|---|
| `XGRCHAIN_Introduction.md` | Entry point and high-level architecture |
| `XGRCHAIN_Chain_Spec.md` | Chain parameters and protocol-level specification |
| `XGRCHAIN_Consensus_IBFT.md` | IBFT finality and validator consensus |
| `XGRCHAIN_Genesis_and_Configuration.md` | Genesis and runtime configuration |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Standard Ethereum-compatible RPC |
| `XRC-GAS_Gas_Price_Behavior.md` | XGR gas and fee behavior |
| `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md` | XDaLa Engine RPC namespace |
| `XRC-137_Rule_Document_Spec.md` | Rule document format |
| `XRC-137_Smart_Contract_Standard.md` | Rule contract standard |
| `XRC-729_Smart_Contract_Standard.md` | Orchestration contract standard |

Upcoming PoS/staking documentation should be added as separate chain documents, not mixed into this introduction:

- `XGRCHAIN_Staking_PoS_Model.md`
- `XGRCHAIN_Staking_PoS_Endpoint_Reference.md`

---

## 8. Glossary

| Term | Meaning |
|---|---|
| XGR Chain | The EVM-compatible blockchain layer of the XGR Network |
| XDaLa | XGR Data Layer / validation and orchestration engine |
| XRC-137 | Smart contract standard for rule documents |
| XRC-729 | Smart contract standard for orchestration/session definitions |
| IBFT | Istanbul Byzantine Fault Tolerance; deterministic-finality consensus protocol |
| PoA | Proof-of-Authority validator model; current/historical baseline |
| PoS | Proof-of-Stake validator model; staking/permissionless-join upgrade path |
| EVM | Ethereum Virtual Machine |
| Engine RPC | The `xgr_*` JSON-RPC namespace exposed by the XDaLa Engine |
| Standard RPC | Ethereum-compatible `eth_*`, `net_*`, `web3_*` RPC surface |

---

## 9. Out of scope

This introduction does not define:

- exact staking economics
- validator join/deactivation rules
- delegation rules
- PoS endpoint schemas
- low-level txpool/debug/operator RPCs
- internal Engine implementation details
- legacy Polygon bridge/rootchain/CDK behavior

Those topics must be documented in dedicated files if they remain relevant to XGR Chain.
