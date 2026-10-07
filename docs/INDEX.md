# XGR Documentation Index

**Document ID:** XGR-DOCS-INDEX  
**Last updated:** 2026-10-04  
**Audience:** Developers, node operators, validators, integrators, auditors, contributors  
**Implementation status:** Mainnet  
**Source of truth:** `docs/`

---

## 1. Overview

This index is the primary navigation entry point for the public XGR Network documentation.

The documentation is divided into:

- XGR Network overview,
- XGRChain protocol and node documentation,
- XDaLa documentation,
- XRC standards,
- MCP documentation,
- XGR Interchain documentation,
- user-interface documentation.

The current XGRChain documentation baseline is:

```text
xgr-node v3.1.1
```

unless an individual document explicitly states otherwise.

XDaLa, XRC standards, MCP services, UI components and Interchain infrastructure are independently versioned where required.

---

# Core

## 2. General overview

- [`general-overview.md`](general-overview.md)

Provides the high-level relationship between:

```text
XGR Network
    ├── XGRChain
    ├── XDaLa
    ├── XRC standards
    ├── MCP
    └── Interchain
```

---

# XGRChain

## 3. XGRChain introduction and specification

Start here when integrating with or evaluating XGRChain.

- [`chain/XGRCHAIN_Introduction.md`](chain/XGRCHAIN_Introduction.md)
- [`chain/XGRCHAIN_Chain_Spec.md`](chain/XGRCHAIN_Chain_Spec.md)
- [`chain/XGRCHAIN_Genesis_and_Configuration.md`](chain/XGRCHAIN_Genesis_and_Configuration.md)

These documents define:

- chain identity,
- chain ID,
- genesis,
- EVM compatibility,
- protocol configuration,
- public node baseline,
- major protocol components.

---

## 4. Consensus and staking

- [`chain/XGRCHAIN_Consensus_IBFT.md`](chain/XGRCHAIN_Consensus_IBFT.md)
- [`chain/XGRCHAIN_Staking_PoS_Model.md`](chain/XGRCHAIN_Staking_PoS_Model.md)
- [`chain/XGRCHAIN_Staking_PoS_Endpoint_Reference.md`](chain/XGRCHAIN_Staking_PoS_Endpoint_Reference.md)

These documents cover:

- IBFT deterministic finality,
- PoA-to-PoS transition,
- delegated PoS,
- validator selection,
- stake-weighted voting power,
- micro-epoch uptime weighting,
- staking and delegation,
- reward and slashing behavior,
- public PoS monitoring RPC.

Current XGRChain mainnet PoS activation:

```text
block 5,446,500
```

---

## 5. Node operation and networking

- [`chain/XGRCHAIN_Node_Operation.md`](chain/XGRCHAIN_Node_Operation.md)
- [`chain/XGRCHAIN_Networking_P2P.md`](chain/XGRCHAIN_Networking_P2P.md)
- [`chain/XGRCHAIN_State_Storage_and_Retention.md`](chain/XGRCHAIN_State_Storage_and_Retention.md)

These documents cover:

- installing and operating `xgr-node`,
- validator operation,
- P2P networking,
- bootnodes and peer discovery,
- systemd deployment,
- state storage,
- Online State Trie Sweeper,
- historical-state retention,
- pruning and recovery.

---

## 6. JSON-RPC and operator interfaces

- [`chain/XGRCHAIN_Ethereum_JSON_RPC_Reference.md`](chain/XGRCHAIN_Ethereum_JSON_RPC_Reference.md)
- [`chain/XGRCHAIN_Node_Operator_RPC_Reference.md`](chain/XGRCHAIN_Node_Operator_RPC_Reference.md)

These documents cover:

- Ethereum-compatible JSON-RPC,
- XGR-specific RPC,
- transaction-pool inspection,
- EVM tracing,
- node operator gRPC,
- native Interchain attestation RPC,
- historical-state limitations.

---

## 7. Gas and fee behavior

- [`chain/XRC-GAS_Gas_Price_Behavior.md`](chain/XRC-GAS_Gas_Price_Behavior.md)

Covers:

- XGRChain base-fee behavior,
- congestion pricing,
- transaction fee validation,
- `eth_gasPrice`,
- DynamicFee transactions,
- XGR-specific fee accounting,
- burn and donation components,
- validator fee distribution,
- PoS FeePool behavior.

---

## 8. Security and upgrade boundaries

- [`chain/XGRCHAIN_Access_Control_and_Permission_Boundaries.md`](chain/XGRCHAIN_Access_Control_and_Permission_Boundaries.md)
- [`chain/XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md`](chain/XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md)

These documents distinguish:

- infrastructure authority,
- validator authority,
- contract authority,
- external-service authority,
- node-local configuration,
- consensus-sensitive changes,
- hardforks,
- binary-only upgrades,
- external-service upgrades.

---

## 9. Current XGRChain documentation set

The current `docs/chain/` directory contains:

```text
XGRCHAIN_Access_Control_and_Permission_Boundaries.md
XGRCHAIN_Chain_Spec.md
XGRCHAIN_Consensus_IBFT.md
XGRCHAIN_Ethereum_JSON_RPC_Reference.md
XGRCHAIN_Genesis_and_Configuration.md
XGRCHAIN_Introduction.md
XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md
XGRCHAIN_Networking_P2P.md
XGRCHAIN_Node_Operation.md
XGRCHAIN_Node_Operator_RPC_Reference.md
XGRCHAIN_Staking_PoS_Endpoint_Reference.md
XGRCHAIN_Staking_PoS_Model.md
XGRCHAIN_State_Storage_and_Retention.md
XRC-GAS_Gas_Price_Behavior.md
```

The current Chain documentation targets:

```text
xgr-node v3.1.1
```

and the corresponding release commit:

```text
1a4844b311fb856cb8c2303a40fa8aa69b560544
```

---

# XDaLa

## 10. XDaLa documentation

- [`XDaLa_Agent_Authoring_Rules.md`](XDaLa_Agent_Authoring_Rules.md)
- [`XDaLa_XGR_Endpoint_Reference.md`](XDaLa_XGR_Endpoint_Reference.md)
- [`XDaLa_Limits.md`](XDaLa_Limits.md)
- [`XDaLa_Permit_Catalog.md`](XDaLa_Permit_Catalog.md)
- [`xgr_expression_evaluation_developer_guide.md`](xgr_expression_evaluation_developer_guide.md)

These documents cover:

- XDaLa process execution,
- engine-facing RPC,
- limits,
- permits,
- expression evaluation,
- agent authoring behavior.

XDaLa functionality may evolve independently from the public XGRChain node release.

---

# XRC Standards

## 11. XRC-137

- [`XRC-137_Rule_Document_Spec.md`](XRC-137_Rule_Document_Spec.md)
- [`XRC-137_Smart_Contract_Standard.md`](XRC-137_Smart_Contract_Standard.md)
- [`XRC-137_Validation_Gas.md`](XRC-137_Validation_Gas.md)

XRC-137 defines the XDaLa rule-document and rule-container model.

---

## 12. XRC-729

- [`XRC-729_Smart_Contract_Standard.md`](XRC-729_Smart_Contract_Standard.md)
- [`xrc_729_orchestration_session_manager.md`](xrc_729_orchestration_session_manager.md)

XRC-729 defines orchestration and session-management behavior.

---

## 13. Encryption and grants

- [`xgr_encryptionGrants.md`](xgr_encryptionGrants.md)

Covers XGR/XDaLa encryption and grant-related behavior.

---

# MCP

## 14. XGR MCP Gateway

- [`mcp/XGR-MCP-Gateway-Overview.md`](mcp/XGR-MCP-Gateway-Overview.md)
- [`mcp/XGR-MCP-Tool-Reference.md`](mcp/XGR-MCP-Tool-Reference.md)
- [`mcp/XGR-MCP-Operation-Handoff.md`](mcp/XGR-MCP-Operation-Handoff.md)
- [`mcp/XGR-MCP-Authoring-and-Knowledge.md`](mcp/XGR-MCP-Authoring-and-Knowledge.md)
- [`mcp/XGR-MCP-Setup-and-Configuration.md`](mcp/XGR-MCP-Setup-and-Configuration.md)

The MCP documentation covers:

- XGRChain state inspection,
- account-state inspection,
- transaction and receipt evidence,
- XDaLa session evidence,
- XRC-137 and XRC-729 discovery,
- native-XGR address relation graphs,
- relation transaction tracing,
- native-XGR value-flow provenance,
- XDaLa Session Start payload history,
- XDaLa authoring and validation,
- operation handoffs,
- optional mainnet XGR purchase tooling,
- optional native XGR starter-gas tooling.

Public implementation:

https://github.com/xgr-network/xgr-mcp

Mainnet MCP endpoint:

```text
https://mcp.xgr.network/mcp
```

Testnet MCP endpoint:

```text
https://mcp.testnet.xgr.network/mcp
```

---

# Interchain

## 15. XGR Interchain

XGR Interchain is the cross-chain infrastructure of the XGR Network.

The public specification set is maintained under:

```text
docs/interchain/
```

Start with:

- [`interchain/XGR_INTERCHAIN_Overview.md`](interchain/XGR_INTERCHAIN_Overview.md)
- [`interchain/XGR_INTERCHAIN_Security_Model.md`](interchain/XGR_INTERCHAIN_Security_Model.md)
- [`interchain/XGR_INTERCHAIN_Asset_Bridge.md`](interchain/XGR_INTERCHAIN_Asset_Bridge.md)
- [`interchain/XGR_INTERCHAIN_Deployment_Reference.md`](interchain/XGR_INTERCHAIN_Deployment_Reference.md)
- [`interchain/XGR_INTERCHAIN_v3.1.3_Protocol.md`](interchain/XGR_INTERCHAIN_v3.1.3_Protocol.md)

These documents define:

- Interchain architecture,
- the separation between XGRChain consensus and Interchain security,
- destination-specific validator membership,
- BLS checkpoint attestations,
- Interchain quorum,
- Merkle inclusion verification,
- relayer trust boundaries,
- native XGR and wXGR asset semantics,
- lock/mint and burn/unlock behavior,
- canonical XGRChain ↔ Base deployment identities,
- v3.1.3 canonical route identity, route-specific governance and dedicated-message authorization,
- shared destination security contracts versus route-specific Gateway/Router contracts.

The first production asset route connects:

```text
XGRChain
    ↕
Base
```

using:

```text
XGRChain: native XGR
Base:     wXGR
```

Forward:

```text
XGRChain → Base
lock native XGR
mint wXGR
```

Reverse:

```text
Base → XGRChain
burn wXGR
unlock native XGR
```

Both asset-transfer directions have been validated end-to-end on mainnet.

XGRChain provides native support for the Interchain security model, including native BLS12-381 verification through:

```text
0x0000000000000000000000000000000000002040
```

XGR Interchain security remains deliberately separated from weighted-IBFT consensus-critical execution.

Therefore:

```text
XGRChain consensus
≠
XGR Interchain validator quorum
```

The public Interchain implementation repository is:

https://github.com/xgr-network/xgr-hyperlane

Implementation-specific and operator documentation is maintained there:

- [Interchain repository overview](https://github.com/xgr-network/xgr-hyperlane)
- [Interchain architecture](https://github.com/xgr-network/xgr-hyperlane/blob/main/docs/architecture.md)
- [Interchain operations](https://github.com/xgr-network/xgr-hyperlane/blob/main/docs/operations.md)

The Interchain implementation repository contains:

- contracts,
- deployment manifests,
- deployment tooling,
- validator-registry and ISM implementations,
- native relayer runtime,
- operational configuration,
- operator procedures.

Public XGR specifications remain in this repository.

Detailed implementation and operations remain in `xgr-network/xgr-hyperlane`.

Dynamic operational state such as:

- router directional gates,
- safety-module pause state,
- current validator-set membership,
- relayer process state,
- relayer submission state,
- RPC health,

must be read from live deployment and runtime state rather than inferred from static documentation.

---

# UI Documentation

## 16. User-interface documentation

UI-specific documentation is maintained below:

```text
ui/builder137/
ui/builder729/
ui/ops/
ui/test-suite/
```

These documents cover user-facing and operational interfaces rather than chain-consensus behavior.

The public XGR Bridge intentionally presents a simplified user-facing view of XGR ↔ wXGR transfers.

Deep Interchain protocol details belong in:

```text
docs/interchain/
```

and the Interchain implementation repository rather than in the normal bridge workflow.

---

# Source-of-truth boundaries

## 17. Where authoritative behavior lives

Different parts of the XGR stack have different implementation sources.

| Area | Primary source |
| --- | --- |
| XGRChain consensus and execution | `xgr-network/xgr-node` |
| Mainnet genesis/configuration | `xgr-network/XGR/genesis/` |
| Public specifications | `xgr-network/XGR/docs/` |
| XDaLa engine behavior | XDaLa implementation and corresponding specifications |
| XRC standards | `xgr-network/XGR/docs/` and referenced contracts |
| MCP Gateway | `xgr-network/xgr-mcp` |
| Public Interchain specifications | `xgr-network/XGR/docs/interchain/` |
| Interchain contracts and runtime | `xgr-network/xgr-hyperlane` |
| Interchain deployment manifests | `xgr-network/xgr-hyperlane/deployments/` |
| Dynamic Interchain availability | Live contract and runtime state |
| User interfaces | Corresponding UI/application repositories |

Documentation should not silently move authority between these layers.

For Interchain specifically:

```text
public architecture and specification
=
xgr-network/XGR/docs/interchain/
```

while:

```text
implementation, deployments and runtime
=
xgr-network/xgr-hyperlane
```

and:

```text
current operational availability
=
live on-chain and runtime state
```

---

## 18. Versioning rule

The current XGRChain documentation baseline is:

```text
xgr-node v3.1.1
```

A new node release does not automatically imply:

- a new genesis,
- a hardfork,
- a new chain ID,
- a new Interchain deployment,
- a new XDaLa specification.

Likewise, an Interchain contract, registry, relayer or route update does not automatically imply a new XGRChain node release.

Each component must be evaluated according to its own compatibility and versioning boundary.

---

## 19. Official developer entry points

- XGR Network: https://xgr.network
- Documentation: https://xgr.network/docs
- GitHub Organization: https://github.com/xgr-network
- Specifications: https://github.com/xgr-network/XGR
- XGRChain node: https://github.com/xgr-network/xgr-node
- Interchain: https://github.com/xgr-network/xgr-hyperlane
- MCP: https://github.com/xgr-network/xgr-mcp
- Explorer: https://explorer.xgr.network
- Testnet Faucet: https://faucet.xgr.network

---

## 20. Documentation maintenance

When implementation changes:

1. update the implementation-specific documentation,
2. update the corresponding public specification when architecture, security or public behavior changes,
3. update this index if files are added, removed or renamed,
4. update public entry-point READMEs where the change affects project positioning or operator guidance,
5. update deployment references when canonical production identities change,
6. preserve historical facts only where they remain useful,
7. avoid leaving obsolete release or runtime claims inside the current protocol-reference set.

For Interchain changes, keep the following layers synchronized where applicable:

```text
xgr-network/XGR/docs/interchain/
xgr-network/xgr-hyperlane
current deployment manifests
public bridge documentation
```

The documentation index should describe the files and interfaces that actually exist in the public repositories.
