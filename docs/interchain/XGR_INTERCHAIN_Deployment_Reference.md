# XGR Interchain — Deployment Reference

**Document ID:** XGR-INTERCHAIN-DEPLOYMENT-REFERENCE  
**Last updated:** 2026-10-04  
**Audience:** Developers, integrators, infrastructure operators, validator operators, auditors, wallet and exchange integrators  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Implementation status:** Mainnet  
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
- public route status,
- source-of-truth boundaries.

Both asset-transfer directions are deployed, end-to-end validated and publicly enabled on mainnet.

Public bridge:

```text
https://bridge.xgr.network
```

This document defines deployment identity.

Dynamic runtime state such as:

- current RPC health,
- router directional gates,
- PausableISM state,
- relayer process state,
- relayer submission state,
- validator attestation progress,

must still be queried live when current operational availability is material.

---

## 2. Network identities

The current production Interchain deployment connects:

| Network | Chain ID | Chain ID hex | Interchain domain | Native gas asset | Status |
| --- | ---: | --- | ---: | --- | --- |
| XGRChain Mainnet | `1643` | `0x66b` | `1643` | XGR | Mainnet |
| Base Mainnet | `8453` | `0x2105` | `8453` | ETH | Mainnet |

Current XGRChain public node baseline:

```text
xgr-node v3.1.1
```

Release commit:

```text
1a4844b311fb856cb8c2303a40fa8aa69b560544
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
| Mailbox implementation | `0xAAFc36b53FdC857429351256447E82f626d47F8a` |
| ProxyAdmin | `0xa49AB7f367B6EA25ae1362883F505E2Dc612d1e3` |
| StaticMerkleRootMultisigIsmFactory | `0xefBbbe5739662201d66b4B79017c4F6FC4E23896` |
| StaticAggregationIsmFactory | `0xFEBEa0a947349E0aC857F9b7b248f1027804438e` |
| DomainRoutingIsmFactory | `0xfbcE47b2A2Eb371700C6b82bf001d82996C64035` |
| DomainRoutingISM | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| ProtocolFee | `0xf5f7A6D1Bd721D56F016b77e4Fc59C24bE5EA75f` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |
| PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |

These contracts provide the XGRChain-side Hyperlane-compatible message infrastructure and route-security composition.

`ValidatorAnnounce` remains deployed Hyperlane-compatible infrastructure but is not the trust anchor for XGR-native BLS Interchain security.

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
XGRChain → Base:
lock native XGR

Base → XGRChain:
unlock native XGR
```

Deployment transaction:

```text
0x54229bb14d6a46a8f73b40a69e9a1c47b597741fb26b79007ae57e9d87331827
```

This router is the XGRChain asset endpoint for the production XGR ↔ wXGR route.

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

The Base synthetic router deployment transaction has not been recovered into the repository inventory.

It therefore remains intentionally unset rather than guessed.

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

Status:

```text
Mainnet
E2E validated
publicly enabled
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

Deployment transaction:

```text
0xff5615002c089761f6fd4822be328d9f296c3cc7b3459e190da7f8f4923232b8
```

Deployment block:

```text
51565950
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

Deployment transaction:

```text
0x5331761a279fd2f187c28439a7b54048f072427f4d0807cb712b88b631883778
```

Deployment block:

```text
51566144
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

Deployment transaction:

```text
0x41fdae1ce76c6da393c33f8facdafc4dd1faf469bb88c126be9935833beb5a15
```

Deployment block:

```text
51566230
```

The ISM verifies the native XGR Interchain security evidence required before XGR-origin messages can be accepted by the Base Mailbox.

---

## 18. Current forward validator set

The forward Base destination registry has been validated using:

```text
setId = 3
validators = 3
quorum = 2
```

Current validator-set membership is live deployment state and should be read from the canonical registry when current membership is required.

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

Status:

```text
Mainnet
E2E validated
publicly enabled
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

Deployment transaction:

```text
0x0cf70e63929a91ce3940bc1379dcbd2960732e69750152923480b6314f982873
```

Deployment block:

```text
10984538
```

The V2 registry supports:

- destination-specific Interchain membership,
- validator-set versioning,
- historical validator-set retention,
- BLS identity resolution.

Set-1 commitment:

```text
0xd033fe96bf990d175beaae337ef327b8de94ca1aa8335b0bccc875bfcb2bff90
```

---

## 23. Current reverse validator set

The reverse XGRChain destination registry has been validated using:

```text
setId = 1
validators = 3
quorum = 2
```

Verifier format:

```text
compressed
```

Verifier:

```text
0x0000000000000000000000000000000000002040
```

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

Deployment transaction:

```text
0x6dbadb839dd1765f86455965a5fa237b73e9221ce77d332c5b60dca88f7c0708
```

Deployment block:

```text
11070512
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

Deployment transaction:

```text
0xdc160be658e85ca4f1c34ee49b1e4e6ad3722f93f886f796f454af70c45e7e67
```

Deployment block:

```text
11070639
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

At the current mainnet baseline the required reverse safety gate is open and the route is publicly enabled.

Current state must still be queried on-chain when operational availability is material.

---

## 27. Reverse DomainRoutingISM

Canonical XGRChain DomainRoutingISM:

```text
0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51
```

Base source domain:

```text
8453
```

is configured to use the reverse V2 AggregationISM:

```text
0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e
```

Routing update transaction:

```text
0x6f94a1652effdc487bf36ea51c47401536b5a06be64fd6e224cbbb53f897850f
```

XGRChain block:

```text
11070767
```

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

| Network | Asset | Router | Role | Status |
| --- | --- | --- | --- | --- |
| XGRChain | Native XGR | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` | Lock / unlock | Mainnet |
| Base | wXGR | `0x3b83687d77170d42feddfe221629cc21e771e021` | Mint / burn | Mainnet |

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

Base address:

```text
0x3b83687d77170d42feDDFe221629cc21e771e021
```

identifies:

```text
official wXGR contract
Base synthetic XGR router
```

The corresponding checksummed address on XGRChain:

```text
0x3b83687d77170D42feDDFe221629cc21e771E021
```

identifies:

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

Interchain message ID:

```text
0x1b73073ea020bbebbd716a68a58f11a10f8c0d712ccbd38d41ed1dfc53550ad7
```

Base destination processing transaction:

```text
0x686e93af92e2a14dee061b33042b62683bd51dcc7069374339d778c54403b90e
```

Checkpoint index:

```text
3
```

Set ID:

```text
3
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

The forward route is publicly enabled on mainnet.

---

## 36. Reverse end-to-end validation

The Base → XGRChain route completed a controlled mainnet end-to-end asset transfer.

Amount:

```text
0.01 wXGR
```

Base source transaction:

```text
0x7a1b61b106e4d631ac599af322cdd7a54510e110ce747076fd934880e27edc89
```

Interchain message ID:

```text
0x47919e62a3811e192d5bfe3c1b70f1309675c6d8f8c2b2ee3a439358276c2160
```

Checkpoint index:

```text
2184212
```

Set ID:

```text
1
```

XGRChain destination processing transaction:

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

The reverse route is publicly enabled on mainnet.

---

## 37. Validation evidence and production identity

End-to-end validation establishes that the configured route has successfully executed real mainnet asset transfers in both directions.

Historical validation transactions are evidence.

They are not themselves protocol configuration.

The canonical production identity remains defined by:

- chain IDs,
- deployed contract addresses,
- active route configuration,
- validator registries,
- security modules,
- live contract state where dynamic.

---

# Runtime Boundaries

## 38. Static deployment versus dynamic state

This document contains canonical deployment identity.

The following values are dynamic:

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

At the current documentation baseline, both production directions are publicly enabled.

Dynamic state can still change after publication and must be checked live when current availability matters.

---

## 39. Current mainnet route state

Current production route:

```text
XGRChain ↔ Base
```

Forward:

```text
XGRChain → Base
status: Mainnet
E2E validated: yes
publicly enabled: yes
relayer submission: enabled
relayer process: running
```

Reverse:

```text
Base → XGRChain
status: Mainnet
E2E validated: yes
publicly enabled: yes
relayer submission: enabled
relayer process: running
```

Public bridge:

```text
https://bridge.xgr.network
```

These runtime observations do not convert dynamic controls into immutable protocol properties.

---

## 40. Route availability

A production route can be:

```text
Mainnet
```

while temporarily:

```text
unavailable
```

for example because:

- a router direction is disabled,
- a required safety module is paused,
- validator quorum is unavailable,
- a relayer is stopped,
- an RPC endpoint is unavailable.

Mainnet describes the production deployment environment.

Current availability remains a live operational property.

---

## 41. Forward availability checks

For XGRChain → Base, current operational availability can depend on:

```text
XGR native router outboundEnabled
Base destination route state
forward relayer submission enabled
forward relayer process running
source and destination RPC availability
validator attestation health
```

These values should be queried from current runtime or live chain state.

---

## 42. Reverse availability checks

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

These values should be queried live.

---

# Attestation Routes

## 43. Forward attestation route

Forward route identifier:

```text
base
```

Latest completed forward attestation can be queried through:

```text
xgr_getInterchainAttestation("base")
```

---

## 44. Reverse attestation route

Reverse route identifier:

```text
base_to_xgr
```

Latest completed reverse attestation can be queried through:

```text
xgr_getInterchainAttestation("base_to_xgr")
```

---

## 45. Checkpoint-specific lookup

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

## 46. Native relayer implementation

The current native relayer implementation is maintained in:

```text
xgr-network/xgr-hyperlane
```

Runtime path:

```text
runtime/native-relayer/
```

Route process management:

```text
runtime/manage-relayers.sh
```

---

## 47. Forward and reverse processes

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

## 48. Current relayer baseline

Forward:

```text
attestation route: base
signature format: eip2537
RELAYER_SUBMIT=true
process: RUNNING
```

Reverse:

```text
attestation route: base_to_xgr
signature format: compressed
RELAYER_SUBMIT=true
process: RUNNING
```

Current reverse Base RPC:

```text
https://base-rpc.publicnode.com
```

Runtime process state must still be monitored live.

---

## 49. Relayer authority

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

## 50. XGRChain public RPC

Canonical public RPC:

```text
https://rpc.xgr.network
```

Chain ID:

```text
1643
```

---

## 51. XGRChain explorer

Canonical public XGRChain explorer:

```text
https://explorer.xgr.network
```

---

## 52. Base RPC

The current Base RPC endpoint used by XGR Interchain runtime configuration is:

```text
https://base-rpc.publicnode.com
```

Chain ID:

```text
8453
```

RPC provider endpoints are operational dependencies and may change without changing deployed on-chain contract identities.

---

## 53. Base explorer

Canonical Base explorer:

```text
https://basescan.org
```

The official wXGR contract can therefore be inspected under:

```text
Base
0x3b83687d77170d42feDDFe221629cc21e771e021
```

---

# Deployment Source of Truth

## 54. Public Interchain implementation

Implementation repository:

```text
https://github.com/xgr-network/xgr-hyperlane
```

Canonical public implementation branch:

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

## 55. Deployment manifests

Machine-readable deployment inventories are maintained under:

```text
xgr-network/xgr-hyperlane/deployments/
```

Current canonical route manifests include:

```text
deployments/xgrchain-mainnet.json
deployments/xgr-base-route.json
```

These manifests are the repository-level inventory for deployed components.

Exact deployment transaction hashes, blocks and superseded deployment history should be taken from these manifests together with live chain state where verification is required.

---

## 56. Human-readable deployment inventory

The implementation repository also maintains:

```text
docs/DEPLOYMENTS.md
```

as the human-readable deployment inventory.

The public XGR specification and the implementation inventory serve different documentation layers and should remain synchronized.

---

## 57. XGR public specifications

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

## 58. XGRChain node implementation

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

## 59. XGRChain

| Component | Address |
| --- | --- |
| Native XGR router | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| Mailbox implementation | `0xAAFc36b53FdC857429351256447E82f626d47F8a` |
| ProxyAdmin | `0xa49AB7f367B6EA25ae1362883F505E2Dc612d1e3` |
| MerkleTreeHook | `0xeD98Af715b5a72dCD412567eb086d48225CDDACF` |
| ValidatorAnnounce | `0x1814Be3E608883cA510707d3dc6f31792FD5CAaF` |
| DomainRoutingISM | `0xAf03B407FED3c4857A24Be9ac8EC64b7d178AA51` |
| PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Reverse RegistryV2 | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Reverse XGRNativeInterchainISMV2 | `0x3b83687d77170D42feDDFe221629cc21e771E021` |
| Reverse AggregationISM | `0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e` |
| Native BLS precompile | `0x0000000000000000000000000000000000002040` |

---

## 60. Base

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

## 61. Minimum wallet integration data

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

## 62. Minimum DEX integration data

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

## 63. Minimum bridge integration data

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
router 0x3b83687d77170d42feDDFe221629cc21e771e021

Destination:
XGRChain
domain 1643
router 0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

Applications must additionally respect live route availability.

---

# Security and Operational Boundaries

## 64. Addresses do not prove availability

The existence of deployed bytecode at the canonical addresses proves deployment.

It does not prove that every required runtime dependency is currently healthy.

At the current mainnet baseline, both route directions are publicly enabled.

Live availability can nevertheless change independently from deployment identity.

---

## 65. Registry state is dynamic

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

## 66. Safety state is dynamic

The PausableISM address is static.

Its:

```text
paused()
```

state is dynamic.

At the current mainnet baseline the required reverse safety module is not paused.

Monitoring systems must still query the contract for current state.

---

## 67. Router gates are dynamic

Router directional state such as:

```text
outboundEnabled()
```

and:

```text
inboundEnabled()
```

is dynamic.

At the current mainnet baseline the required XGRChain ↔ Base route gates are enabled.

Integrations should still read current state when deciding whether users can transfer.

---

## 68. Relayer state is off-chain runtime state

Relayer process state and submission state are not encoded solely by deployed contract addresses.

Examples:

```text
process running / stopped
RELAYER_SUBMIT=true / false
```

belong to the operational runtime layer.

At the current mainnet baseline:

```text
forward RELAYER_SUBMIT=true
forward process=RUNNING

reverse RELAYER_SUBMIT=true
reverse process=RUNNING
```

These values remain dynamic and must be monitored operationally.

---

# Documentation Relationships

## 69. Interchain overview

Architecture overview:

```text
docs/interchain/XGR_INTERCHAIN_Overview.md
```

---

## 70. Security model

Validator, BLS, quorum and trust semantics:

```text
docs/interchain/XGR_INTERCHAIN_Security_Model.md
```

---

## 71. Asset bridge

Asset and supply behavior:

```text
docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md
```

---

## 72. Implementation documentation

Detailed implementation, deployment and operator documentation:

```text
https://github.com/xgr-network/xgr-hyperlane
```

Relevant repository documentation includes:

```text
README.md
docs/architecture.md
docs/operations.md
docs/DEPLOYMENTS.md
```

and the deployment manifests under:

```text
deployments/
```

---

## 73. Update triggers

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

## 74. Deployment summary

| Topic | Current production deployment |
| --- | --- |
| Implementation status | Mainnet |
| Native network | XGRChain |
| XGRChain ID/domain | `1643` |
| External network | Base |
| Base ID/domain | `8453` |
| Native asset | XGR |
| Wrapped asset | wXGR |
| Asset decimals | `18` |
| Nominal representation | `1 XGR ↔ 1 wXGR` |
| XGR native router | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Base wXGR / router | `0x3b83687d77170d42feddfe221629cc21e771e021` |
| XGR Mailbox | `0x5632409bc2f0e8bAc4AaF43654D4FFc7822C9c79` |
| Base Mailbox | `0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D` |
| Forward registry | `0x70F5752326735b31641f21D174BA035E904Db93c` |
| Forward set | `setId 3`, `3 validators`, `quorum 2` |
| Forward ISM | `0x3d2aDD3a7dAcb82C11338b6731B22d2aFeD4E1Cc` |
| Reverse RegistryV2 | `0x013F2F2f7dB897F941b19C4ab71C5395a48A0292` |
| Reverse set | `setId 1`, `3 validators`, `quorum 2` |
| Reverse ISMV2 | `0x3b83687d77170D42feDDFe221629cc21e771E021` |
| Reverse AggregationISM | `0x35c2B8403a65D3bd2b86294BF1f26E13A246c05e` |
| Reverse PausableISM | `0x1175F84765CFeA514ea1fd75162CFE8a6C64d4CA` |
| Native XGR BLS precompile | `0x2040` |
| Reverse confirmation delay | `12 Base blocks` |
| Forward route | Mainnet / E2E validated / public |
| Reverse route | Mainnet / E2E validated / public |
| Forward relayer | Submission enabled / running |
| Reverse relayer | Submission enabled / running |
| Public bridge | `https://bridge.xgr.network` |

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

The XGRChain ↔ Base Interchain route is deployed, bidirectionally validated, operationally enabled and publicly available on mainnet.
