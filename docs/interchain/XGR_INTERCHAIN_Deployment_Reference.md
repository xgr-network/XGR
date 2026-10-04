# XGR Interchain — Deployment Reference

**Document ID:** XGR-INTERCHAIN-DEPLOYMENT-REFERENCE  
**Last updated:** 2026-10-04  
**Audience:** Developers, integrators, infrastructure operators, validator operators, auditors, wallet and exchange integrators  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Implementation status:** XGRChain ↔ Base mainnet deployment active; both asset-transfer directions validated end-to-end on mainnet  
**Interchain implementation:** `xgr-network/xgr-hyperlane`, branch `main`  
**XGRChain implementation:** `xgr-network/xgr-node`  
**Scope:** Canonical public network identities, deployed Interchain contracts, asset routers, validator registries, security modules and route relationships for the XGRChain ↔ Base mainnet deployment

---

## 1. Purpose

This document provides the canonical public deployment reference for the first XGR Interchain production route:

```text
XGRChain ↔ Base
```

It records:

- chain and domain identities,
- Hyperlane-compatible core contracts,
- native XGR asset routers,
- the official Base wXGR contract,
- Interchain validator registries,
- BLS verification components,
- destination security modules,
- reverse safety modules,
- route relationships,
- known cross-chain address collisions,
- mainnet end-to-end validation evidence,
- source-of-truth boundaries.

This document describes public deployment identity.

Dynamic runtime state such as:

- current RPC health,
- router pause state,
- router directional gates,
- relayer process state,
- relayer submission state,

must be queried live and must not be inferred solely from this document.

---

## 2. Network identities

The current production Interchain deployment connects:

| Network | Chain ID | Chain ID hex | Interchain domain | Native gas asset |
| --- | ---: | --- | ---: | --- |
| XGRChain Mainnet | `1643` | `0x66b` | `1643` | XGR |
| Base | `8453` | `0x2105` | `8453` | ETH |

Current XGRChain public node baseline:

```text
xgr-node v3.1.1
```

---

## 3. Asset identities

### XGRChain

Native bridge asset:

```text
XGR
```

Type:

```text
native chain asset
```

Decimals:

```text
18
```

### Base

Wrapped bridge asset:

```text
wXGR
```

Type:

```text
synthetic wrapped representation of native XGR
```

Decimals:

```text
18
```

Official Base wXGR contract:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

---

## 4. Canonical asset route

The deployed asset relationship is:

```text
XGRChain native XGR
        ↕
Base wXGR
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

The nominal bridge representation is:

```text
1 XGR ↔ 1 wXGR
```

before applicable transaction and routing fees.

---

# XGRChain Deployment

## 5. XGRChain Hyperlane-compatible core

Current XGRChain mainnet Interchain contracts:

| Component | Address |
| --- | --- |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| DomainRoutingISM | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |

These contracts provide the XGRChain-side Hyperlane-compatible message infrastructure and route security composition.

---

## 6. XGRChain Mailbox

Canonical XGRChain Mailbox:

```text
0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79
```

Network:

```text
XGRChain
Chain ID 1643
Domain 1643
```

The Mailbox participates in:

- outbound message dispatch,
- inbound message processing,
- message delivery state,
- destination security-module execution.

---

## 7. XGRChain MerkleTreeHook

Canonical XGRChain MerkleTreeHook:

```text
0xeD98Af715b5a72dCD412567eb086d48225CDDACF
```

The hook maintains the canonical message tree used by the current XGR-origin native Interchain security path.

Supported public dispatches must be compatible with the configured canonical tree.

---

## 8. XGRChain native XGR router

Canonical native asset router:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

Network:

```text
XGRChain
Chain ID 1643
```

Asset:

```text
native XGR
```

Role:

```text
XGRChain → external network:
lock native XGR

external network → XGRChain:
unlock native XGR
```

This router is the XGRChain asset endpoint for the current XGR ↔ wXGR route.

---

## 9. Native BLS verification precompile

XGRChain provides native BLS12-381 verification at:

```text
0x0000000000000000000000000000000000002040
```

This is a native precompile implemented by the XGRChain node.

It is not an ordinary EVM contract deployment.

The reverse Interchain security path uses this native execution primitive to verify compressed aggregate BLS signatures.

---

# Base Deployment

## 10. Base Hyperlane-compatible core

Current Base infrastructure used by the XGR Interchain route:

| Component | Address |
| --- | --- |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| ValidatorAnnounce | `0x182E8d7c5F1B06201b102123FC7dF0EaeB445a7B` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| InterchainGasPaymaster | `0xc3F23848Ed2e04C0c6d41bd7804fa8f89F940B94` |

These contracts are Base-side Hyperlane infrastructure.

They are not XGRChain consensus components.

---

## 11. Base Mailbox

Canonical Base Mailbox:

```text
0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D
```

Network:

```text
Base
Chain ID 8453
Domain 8453
```

It provides:

- Base outbound dispatch,
- Base inbound processing,
- Hyperlane-compatible message delivery,
- destination ISM execution.

---

## 12. Base MerkleTreeHook

Canonical Base MerkleTreeHook:

```text
0x19dc38aeae620380430C200a6E990D5Af5480117
```

For the reverse Base → XGRChain route, participating XGR Interchain infrastructure observes the configured Base message tree after the required confirmation policy.

---

## 13. Official Base wXGR contract

Canonical Base wXGR contract:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

Network:

```text
Base
Chain ID 8453
```

Asset:

```text
wXGR
```

Role:

```text
XGRChain → Base:
mint wXGR

Base → XGRChain:
burn wXGR
```

The same contract acts as:

```text
official wXGR token
+
Base synthetic XGR asset router
```

Wallets, DEXs, exchanges and integrations must identify official wXGR using:

```text
Base chain ID 8453
+
0x3b83687d77170d42feddfe221629cc21e771e021
```

The symbol `wXGR` alone is not sufficient identification.

---

# Forward Security Deployment

## 14. Forward route

Forward route:

```text
XGRChain → Base
```

Attestation route identifier:

```text
base
```

Source:

```text
XGRChain
domain 1643
```

Destination:

```text
Base
domain 8453
```

Asset transition:

```text
native XGR
→
wXGR
```

---

## 15. Base BLS verifier

Forward XGR Interchain BLS verifier on Base:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

Network:

```text
Base
Chain ID 8453
```

Component:

```text
XGRInterchainBLSVerifier
```

This component performs destination-side BLS verification for the deployed forward native XGR security generation.

---

## 16. Base Interchain validator registry

Canonical forward validator registry:

```text
0x70F5752326735b31641f21D174BA035E904Db93c
```

Network:

```text
Base
```

Component:

```text
XGRInterchainValidatorRegistry
```

Generation:

```text
V1
```

Purpose:

- canonical forward destination Interchain membership,
- validator identity resolution,
- quorum context.

The registry is distinct from XGRChain IBFT consensus membership.

---

## 17. Base native XGR ISM

Canonical forward destination ISM:

```text
0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc
```

Network:

```text
Base
```

Component:

```text
XGRNativeInterchainISM
```

The ISM verifies the native XGR Interchain security evidence required before XGR-origin messages can be accepted by the Base Mailbox.

---

## 18. Current forward validator set

The forward Base destination registry has been validated using:

```text
setId = 3
```

with:

```text
quorum = 2
```

for the mainnet validation configuration.

Validator-set membership is live deployment state and should be read from the canonical registry when current membership is required.

Static documentation must not be treated as a permanent substitute for live registry state.

---

## 19. Forward security flow

The current deployed path is:

```text
XGR native router
        │
        ▼
XGR Mailbox
        │
        ▼
XGR MerkleTreeHook
        │
        ▼
XGR native Interchain attestation
        │
        ▼
relayer
        │
        ▼
Base Mailbox
        │
        ▼
XGRNativeInterchainISM
        │
        ▼
Base synthetic router / wXGR
```

---

# Reverse Security Deployment

## 20. Reverse route

Reverse route:

```text
Base → XGRChain
```

Attestation route identifier:

```text
base_to_xgr
```

Source:

```text
Base
domain 8453
```

Destination:

```text
XGRChain
domain 1643
```

Asset transition:

```text
wXGR
→
native XGR
```

---

## 21. Reverse external-source configuration

Current Base source configuration:

| Field | Value |
| --- | --- |
| Chain | Base |
| Chain ID | `8453` |
| Domain | `8453` |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| Confirmation delay | `12` blocks |

The confirmation delay is part of the current reverse route configuration.

---

## 22. XGRChain RegistryV2

Canonical reverse validator registry:

```text
0x013F2F2f7dB897F941b19C4ab71C5395a48A0292
```

Network:

```text
XGRChain
```

Component:

```text
XGRInterchainValidatorRegistryV2
```

Generation:

```text
V2
```

The V2 registry supports:

- destination-specific Interchain membership,
- validator-set versioning,
- historical validator-set retention,
- BLS identity resolution.

---

## 23. Current reverse validator set

The reverse XGRChain destination registry has been validated using:

```text
setId = 1
```

with:

```text
quorum = 2
```

across:

```text
3 configured Interchain validators
```

for the validated mainnet reverse deployment.

Current membership must be read from live registry state when operationally relevant.

---

## 24. Reverse XGR native ISM

Canonical reverse native security module:

```text
0x3b83687d77170D42feDDFe221629cc21e771E021
```

Network:

```text
XGRChain
```

Component:

```text
XGRNativeInterchainISMV2
```

The ISM verifies:

- checkpoint origin,
- destination,
- validator-set ID,
- signer bitmap,
- quorum,
- compressed BLS aggregate signature,
- Hyperlane-compatible Merkle inclusion.

Compressed BLS verification uses the XGRChain native precompile:

```text
0x0000000000000000000000000000000000002040
```

---

## 25. Reverse AggregationISM

Canonical reverse aggregation module:

```text
0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e
```

Network:

```text
XGRChain
```

Policy:

```text
2-of-2
```

Required modules:

```text
PausableISM
+
XGRNativeInterchainISMV2
```

Both required modules must accept the message.

---

## 26. Reverse PausableISM

Canonical reverse safety module:

```text
0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA
```

Network:

```text
XGRChain
```

Role:

```text
operational safety gate
```

The pause state is dynamic.

Current availability must be queried on-chain and must not be assumed from this document.

---

## 27. Reverse DomainRoutingISM

Canonical XGRChain DomainRoutingISM:

```text
0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51
```

The Base source domain is configured to use the corresponding reverse destination security path.

The routing relationship is part of the deployed Interchain security configuration.

---

## 28. Reverse security flow

Current deployed reverse path:

```text
Base wXGR router
        │
        ▼
Base Mailbox
        │
        ▼
Base MerkleTreeHook
        │
        ▼
confirmed Base checkpoint
        │
        ▼
XGR Interchain validators
        │
        ▼
base_to_xgr BLS attestation
        │
        ▼
reverse relayer
        │
        ▼
XGR Mailbox
        │
        ▼
DomainRoutingISM
        │
        ▼
2-of-2 AggregationISM
        │
        ├── PausableISM
        │
        └── XGRNativeInterchainISMV2
                  │
                  ▼
        native BLS precompile 0x2040
                  │
                  ▼
XGR native router
```

---

# Asset Routers

## 29. Router reference

| Network | Asset | Router | Role |
| --- | --- | --- | --- |
| XGRChain | Native XGR | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` | Lock / unlock |
| Base | wXGR | `0x3b83687d77170d42feddfe221629cc21e771e021` | Mint / burn |

These addresses define the current canonical XGRChain ↔ Base asset route.

---

## 30. Official wXGR identity

The canonical Base wrapped asset is:

```text
Network: Base
Chain ID: 8453
Token: wXGR
Decimals: 18
Contract: 0x3b83687d77170d42feddfe221629cc21e771e021
```

Integrators should publish the full identity rather than only:

```text
wXGR
```

---

# Cross-Chain Address Collisions

## 31. Address collision principle

EVM addresses are interpreted within a chain-specific address space.

Therefore the same hexadecimal address can identify unrelated contracts on different networks.

The canonical identity is:

```text
chain ID + address
```

An address alone is insufficient.

---

## 32. `0x202C10...` collision

Address:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

On XGRChain:

```text
native XGR asset router
```

On Base:

```text
XGRInterchainBLSVerifier
```

These are separate contracts on separate networks.

---

## 33. `0x3b83687...` collision

Address:

```text
0x3b83687d77170d42feDDfe221629cc21e771e021
```

On Base:

```text
official wXGR contract
Base synthetic XGR router
```

On XGRChain:

```text
XGRNativeInterchainISMV2
```

These are separate contracts on separate networks.

---

## 34. Integration requirement

Applications must never configure production Interchain identities using only:

```text
address
```

Use:

```text
chain ID
+
address
```

for:

- token imports,
- router configuration,
- explorer links,
- monitoring,
- DEX integration,
- security analysis,
- operational tooling.

---

# Mainnet Validation Evidence

## 35. Forward end-to-end validation

The XGRChain → Base route completed a controlled mainnet end-to-end asset transfer.

Amount:

```text
0.1 XGR
```

XGRChain source transaction:

```text
0x08671a6c4bc10ab8af4fda602f8d09a393f17212b3e4bf729002c92ce1e50613
```

Source block:

```text
10836602
```

The transfer produced an Interchain message and completed through the Base destination path.

Observed Base destination processing transaction:

```text
0x686e93af...
```

The validation confirmed:

- native XGR lock,
- message dispatch,
- Merkle-tree insertion,
- XGR validator attestation,
- BLS quorum,
- Merkle proof,
- Base destination verification,
- wXGR mint.

Where complete transaction identifiers are required for external audit evidence, use the canonical deployment and validation records in the Interchain repository rather than abbreviated documentation values.

---

## 36. Reverse end-to-end validation

The Base → XGRChain route completed a controlled mainnet end-to-end asset transfer.

Amount:

```text
0.01 wXGR
```

Base source transaction:

```text
0x7a1b61b1...
```

Interchain message ID:

```text
0x47919e62a3811e192d5bfe3c1b70f1309675c6d8f8c2b2ee3a439358276c2160
```

Observed XGRChain destination process transaction:

```text
0x968503696b8a2eebd2c3701fc4c25ef7bde650883e1d81c63a472b0587f333ec
```

Destination block:

```text
11140781
```

Observed destination gas use:

```text
461505
```

The validation confirmed:

- wXGR burn,
- Base dispatch,
- Base checkpoint observation,
- configured confirmation delay,
- reverse XGR validator attestation,
- compressed BLS verification,
- Merkle inclusion verification,
- XGR Mailbox processing,
- native XGR unlock.

---

## 37. Validation evidence and production identity

End-to-end validation establishes that the configured route has successfully executed a real mainnet asset transfer.

It does not make historical test transactions part of the protocol configuration.

The canonical production identity remains defined by:

- live chain IDs,
- deployed contract addresses,
- active route configuration,
- validator registries,
- security modules.

---

# Runtime Boundaries

## 38. Static deployment versus dynamic state

This document contains static deployment identity.

The following values are dynamic and must be checked live:

```text
router outboundEnabled
router inboundEnabled
PausableISM paused
relayer process state
relayer submission state
RPC health
validator attestation progress
current registry membership
current registry setId
```

A static deployment reference must never be used as proof that a route is currently available.

---

## 39. Route availability

A production route can be:

```text
deployed
```

while temporarily:

```text
unavailable
```

For example because:

- a router direction is disabled,
- a required safety module is paused,
- validator quorum is unavailable,
- a relayer is stopped,
- destination RPC is unavailable.

Deployment identity and operational availability are intentionally separate concepts.

---

## 40. Forward availability checks

For XGRChain → Base, current operational availability can depend on:

```text
XGR native router outboundEnabled
Base wXGR router inboundEnabled
forward relayer submission enabled
forward relayer process running
source and destination RPC availability
validator attestation health
```

These values must be queried from current runtime or live chain state.

---

## 41. Reverse availability checks

For Base → XGRChain, current operational availability can depend on:

```text
Base wXGR router outboundEnabled
XGR native router inboundEnabled
PausableISM unpaused
reverse relayer submission enabled
reverse relayer process running
source and destination RPC availability
reverse validator attestation health
```

These values must be queried live.

---

# Attestation Routes

## 42. Forward attestation route

Forward route identifier:

```text
base
```

Latest completed forward attestation can be queried through:

```text
xgr_getInterchainAttestation("base")
```

---

## 43. Reverse attestation route

Reverse route identifier:

```text
base_to_xgr
```

Latest completed reverse attestation can be queried through:

```text
xgr_getInterchainAttestation("base_to_xgr")
```

---

## 44. Checkpoint-specific lookup

A completed historical attestation can be queried using:

```text
xgr_getInterchainAttestationByCheckpoint(
    route,
    setId,
    index,
    root
)
```

These methods are read-only.

They do not request or force new validator signatures.

---

# Relayer Deployment

## 45. Native relayer implementation

The current native relayer implementation is maintained in:

```text
xgr-network/xgr-hyperlane
```

runtime path:

```text
runtime/native-relayer/
```

Route process management is implemented through:

```text
runtime/manage-relayers.sh
```

---

## 46. Forward and reverse processes

Forward:

```text
XGRChain → Base
```

Reverse:

```text
Base → XGRChain
```

The processes maintain independent:

- configuration,
- indexed state,
- logs,
- submission controls.

This allows one direction to be operated independently from the other.

---

## 47. Relayer authority

The relayer account pays destination-chain transaction gas and submits message-delivery transactions.

It does not hold:

```text
Interchain validator quorum authority
```

and does not gain:

```text
XGRChain IBFT consensus authority
```

through its relayer role.

Detailed trust semantics are documented in:

```text
docs/interchain/XGR_INTERCHAIN_Security_Model.md
```

---

# Explorers and RPC

## 48. XGRChain public RPC

Canonical public RPC:

```text
https://rpc.xgr.network
```

Chain ID:

```text
1643
```

---

## 49. XGRChain explorer

Canonical public XGRChain explorer:

```text
https://explorer.xgr.network
```

---

## 50. Base RPC

The current public Base RPC endpoint used by XGR Interchain public configuration is:

```text
https://base-rpc.publicnode.com
```

Chain ID:

```text
8453
```

RPC provider endpoints are operational dependencies and may change without changing the deployed on-chain contract identities.

---

## 51. Base explorer

Canonical explorer links for the current public bridge use:

```text
https://basescan.org
```

The official wXGR contract can therefore be inspected under:

```text
Base
0x3b83687d77170d42feddfe221629cc21e771e021
```

---

# Deployment Source of Truth

## 52. Public Interchain implementation

Implementation repository:

```text
https://github.com/xgr-network/xgr-hyperlane
```

The canonical public implementation branch is:

```text
main
```

The repository contains:

- Interchain contracts,
- tests,
- deployment scripts,
- deployment manifests,
- native relayer runtime,
- runtime configuration examples,
- architecture documentation,
- operations documentation.

---

## 53. Deployment manifests

Machine-readable deployment inventories are maintained under:

```text
xgr-network/xgr-hyperlane/deployments/
```

These manifests are the repository-level inventory for deployed components.

When exact deployment transaction hashes, blocks or superseded deployment history are required, the deployment manifests should be used together with live chain state.

---

## 54. XGR public specifications

Public XGR specifications and reference documentation are maintained in:

```text
https://github.com/xgr-network/XGR
```

Interchain public documentation:

```text
docs/interchain/
```

This document is part of that specification layer.

---

## 55. XGRChain node implementation

Native XGRChain Interchain functionality is implemented in:

```text
https://github.com/xgr-network/xgr-node
```

Current public release baseline:

```text
v3.1.1
```

Native Interchain node functionality and on-chain Interchain deployment are independently versioned layers.

---

# Canonical Address Summary

## 56. XGRChain

| Component | Address |
| --- | --- |
| Native XGR router | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |
| DomainRoutingISM | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Reverse RegistryV2 | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Reverse XGRNativeInterchainISMV2 | `0x3b83687d77170D42feDDFe221629cc21e771E021` |
| Reverse AggregationISM | `0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e` |
| Native BLS precompile | `0x0000000000000000000000000000000000002040` |

---

## 57. Base

| Component | Address |
| --- | --- |
| Official wXGR / synthetic router | `0x3b83687d77170d42feddfe221629cc21e771e021` |
| Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| MerkleTreeHook | `0x19dc38aeae620380430C200a6E990D5Af5480117` |
| ValidatorAnnounce | `0x182E8d7c5F1B06201b102123FC7dF0EaeB445a7B` |
| InterchainGasPaymaster | `0xc3F23848Ed2e04C0c6d41bd7804fa8f89F940B94` |
| Forward BLS verifier | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Forward validator registry | `0x70F5752326735b31641f21D174BA035E904Db93c` |
| Forward XGRNativeInterchainISM | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` |

---

# Integration Reference

## 58. Minimum wallet integration data

For XGRChain:

```text
Network name: XGRChain
Chain ID: 1643
Chain ID hex: 0x66b
Native currency: XGR
RPC: https://rpc.xgr.network
Explorer: https://explorer.xgr.network
```

For Base:

```text
Network name: Base
Chain ID: 8453
Chain ID hex: 0x2105
Native currency: ETH
Official wXGR:
0x3b83687d77170d42feddfe221629cc21e771e021
```

---

## 59. Minimum DEX integration data

A Base DEX integrating official wXGR should use:

```text
Network: Base
Chain ID: 8453
Token: wXGR
Decimals: 18
Contract:
0x3b83687d77170d42feddfe221629cc21e771e021
```

The DEX pool itself remains separate from the XGR Interchain bridge contracts.

---

## 60. Minimum bridge integration data

Forward:

```text
Source:
XGRChain
domain 1643
router 0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93

Destination:
Base
domain 8453
router 0x3b83687d77170d42feddfe221629cc21e771e021
```

Reverse:

```text
Source:
Base
domain 8453
router 0x3b83687d77170d42feddfe221629cc21e771e021

Destination:
XGRChain
domain 1643
router 0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

Applications must additionally respect live route availability.

---

# Security and Operational Boundaries

## 61. Addresses do not prove availability

The existence of deployed bytecode at the canonical addresses proves deployment.

It does not prove:

```text
route currently open
```

Current route operation depends on live state.

---

## 62. Registry state is dynamic

The validator registry addresses are static deployment identities.

Their contents can evolve according to the deployed membership model.

Therefore static documentation may identify:

```text
which registry is authoritative
```

but current membership should be read from:

```text
the live registry
```

when needed.

---

## 63. Safety state is dynamic

The PausableISM address is static.

Its current:

```text
paused()
```

state is dynamic.

A monitoring system must query the contract rather than infer current state from this document.

---

## 64. Router gates are dynamic

Router directional state such as:

```text
outboundEnabled()
```

and:

```text
inboundEnabled()
```

is dynamic.

Integrations that need to decide whether users can currently transfer should read current state.

---

## 65. Relayer state is off-chain runtime state

Relayer process state and submission state are not encoded solely by deployed contract addresses.

Examples:

```text
process running / stopped
RELAYER_SUBMIT=true / false
```

belong to the operational runtime layer.

They must be monitored separately.

---

# Documentation Relationships

## 66. Interchain overview

Architecture overview:

```text
docs/interchain/XGR_INTERCHAIN_Overview.md
```

---

## 67. Security model

Validator, BLS, quorum and trust semantics:

```text
docs/interchain/XGR_INTERCHAIN_Security_Model.md
```

---

## 68. Asset bridge

Asset and supply behavior:

```text
docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md
```

---

## 69. Implementation documentation

Detailed implementation, deployment and operator documentation:

```text
https://github.com/xgr-network/xgr-hyperlane
```

Relevant repository documentation includes:

```text
docs/architecture.md
docs/operations.md
```

and the deployment manifests under:

```text
deployments/
```

---

## 70. Update triggers

This document must be reviewed when any of the following changes:

- chain ID or Interchain domain,
- XGRChain Mailbox,
- Base Mailbox,
- canonical MerkleTreeHook,
- native XGR router,
- official wXGR contract,
- validator registry,
- BLS verifier,
- destination ISM,
- DomainRoutingISM,
- AggregationISM,
- PausableISM,
- native BLS precompile identity,
- supported production network,
- canonical production deployment generation.

Dynamic state changes such as:

- a relayer restart,
- temporary RPC outage,
- pause activation,
- router gate change,

do not require rewriting static deployment identity unless they change the canonical deployed architecture.

---

## 71. Deployment summary

| Topic | Current production deployment |
| --- | --- |
| Native network | XGRChain |
| XGRChain ID/domain | `1643` |
| External network | Base |
| Base ID/domain | `8453` |
| Native asset | XGR |
| Wrapped asset | wXGR |
| XGR native router | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Base wXGR / router | `0x3b83687d77170d42feddfe221629cc21e771e021` |
| XGR Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| Base Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| Forward registry | `0x70F5752326735b31641f21D174BA035E904Db93c` |
| Forward ISM | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` |
| Reverse RegistryV2 | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Reverse ISMV2 | `0x3b83687d77170D42feDDFe221629cc21e771E021` |
| Reverse AggregationISM | `0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e` |
| Reverse PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Native XGR BLS precompile | `0x2040` |
| Forward route | Mainnet E2E validated |
| Reverse route | Mainnet E2E validated |

The canonical production asset identity is:

```text
XGRChain native XGR
↔
Base wXGR
```

with official Base wXGR at:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

All deployment addresses must be interpreted together with their network identity.
