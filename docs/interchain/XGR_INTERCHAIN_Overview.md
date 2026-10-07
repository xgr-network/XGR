# XGR Interchain — Overview

**Document ID:** XGR-INTERCHAIN-OVERVIEW  
**Last updated:** 2026-10-04  
**Audience:** Developers, integrators, node operators, validator operators, auditors, infrastructure reviewers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Implementation status:** XGRChain ↔ Base mainnet deployment active; both asset-transfer directions validated end-to-end on mainnet  
**Interchain implementation:** `xgr-network/xgr-hyperlane`, branch `main`  
**XGRChain implementation:** `xgr-network/xgr-node`  
**Scope:** Public architecture and security overview of XGR Interchain and the XGRChain ↔ Base XGR asset route

---

## 1. Purpose

This document provides the public technical overview of XGR Interchain.

It explains:

- what XGR Interchain is,
- how XGRChain connects to external networks,
- the relationship between native XGR and wrapped XGR,
- the XGRChain ↔ Base asset route,
- native XGR Interchain attestation generation,
- BLS-based transfer verification,
- Interchain validator membership and quorum,
- relayer responsibilities,
- Hyperlane-compatible message transport,
- the separation between XGRChain consensus and Interchain security,
- public bridge and runtime-availability boundaries.

Detailed security mechanics, deployed contract addresses and operational procedures are documented separately.

The normative multi-route architecture introduced for XGR Interchain v3.1.3 is defined separately in:

```text
docs/interchain/XGR_INTERCHAIN_v3.1.3_Protocol.md
```

That document defines the route-addressable security model, dedicated-message authorization, route-scoped governance, untrusted relayer boundary and shared-vs-route-specific contract architecture. The production deployment described in this overview remains the v3.1.1 mainnet baseline until v3.1.3 contracts are deployed and validated.

---

## 2. What is XGR Interchain?

XGR Interchain is the cross-chain infrastructure of the XGR Network.

Its purpose is to connect XGRChain to supported external blockchain networks while preserving explicit security and asset-supply rules.

The first implemented production route connects:

```text
XGRChain ↔ Base
```

using:

```text
XGRChain: native XGR
Base:     wrapped XGR / wXGR
```

The asset route uses:

```text
XGRChain → Base
lock native XGR
mint wXGR

Base → XGRChain
burn wXGR
unlock native XGR
```

The route does not require a liquidity pool to create or redeem wXGR.

The bridge asset model is based on corresponding lock/mint and burn/unlock operations.

---

## 3. Network identities

The first production Interchain route uses the following networks:

| Network | Chain ID | Interchain domain | Asset |
| --- | ---: | ---: | --- |
| XGRChain Mainnet | `1643` | `1643` | Native XGR |
| Base | `8453` | `8453` | wXGR |

Current public XGRChain node baseline:

```text
xgr-node v3.1.1
```

XGRChain is an independent EVM-compatible Layer-1 blockchain.

Base is an external EVM-compatible network.

The two networks remain independent execution and consensus domains.

---

## 4. Architecture at a glance

At a high level, XGR Interchain combines:

- Hyperlane-compatible message transport,
- XGRChain-native Interchain attestation generation,
- destination-specific Interchain validator registries,
- BLS aggregate signatures,
- Merkle message-inclusion proofs,
- destination Interchain Security Modules,
- native relayer infrastructure,
- Warp-style asset routers,
- explicit runtime and safety controls.

Conceptually:

```text
XGRChain
    │
    │ cross-chain message
    ▼
Interchain validation
    │
    │ validator-approved proof
    ▼
Relayer
    │
    ▼
Destination network
```

For asset transfers:

```text
XGRChain                         Base

native XGR
    │
    │ lock
    ▼
XGR router
    │
    ▼
cross-chain verification
    │
    ▼
Base router
    │
    │ mint
    ▼
wXGR
```

Reverse:

```text
Base                             XGRChain

wXGR
    │
    │ burn
    ▼
Base router
    │
    ▼
cross-chain verification
    │
    ▼
XGR router
    │
    │ unlock
    ▼
native XGR
```

---

## 5. Separation from XGRChain consensus

XGR Interchain is deliberately separated from XGRChain's weighted-IBFT consensus-critical path.

XGRChain consensus is responsible for:

- block production,
- block verification,
- IBFT finality,
- delegated PoS,
- validator voting power,
- canonical XGRChain state.

XGR Interchain is responsible for:

- cross-chain checkpoint observation,
- Interchain validator attestations,
- proof construction,
- message delivery,
- destination verification,
- cross-chain asset routing.

Therefore:

```text
XGRChain consensus
≠
XGR Interchain security
```

A failure of:

- Base,
- an Interchain relayer,
- a remote RPC endpoint,
- an Interchain validator subset,
- an external destination,

must not prevent normal XGRChain consensus from continuing.

The native Interchain worker observes canonical chain state.

It does not control IBFT finalization.

---

## 6. Consensus validators and Interchain validators

XGRChain consensus validators and XGR Interchain validators are related but distinct roles.

### XGRChain consensus validator

A consensus validator participates in:

- IBFT,
- block proposal and verification,
- delegated PoS,
- stake- and uptime-weighted voting power,
- block finality.

### XGR Interchain validator

An Interchain validator participates in:

- destination-specific Interchain membership,
- cross-chain checkpoint attestation,
- BLS aggregate-signature generation,
- Interchain quorum formation.

Interchain membership does not grant additional IBFT consensus authority.

Likewise:

```text
being an XGRChain consensus validator
does not automatically make that validator
an Interchain signer for every destination
```

Interchain membership is explicitly configured according to the active destination registry and the corresponding XGR validator identity rules.

---

## 7. Interchain validator identity

The native XGR Interchain security model connects several identities.

Conceptually:

```text
XGR staking validator
        │
        ├── staking identity
        └── BLS identity
                │
                ▼
destination-specific
Interchain registry
                │
                ▼
Interchain signer
```

The destination registry defines the Interchain signing membership relevant to that destination.

Interchain signing authority is therefore not derived from possession of a relayer key or from ordinary RPC access.

---

## 8. Interchain quorum

XGR Interchain uses an unweighted two-thirds quorum of the configured destination-specific Interchain validator set.

Conceptually:

```text
required signatures
=
two-thirds quorum
of the active Interchain set
```

This must not be confused with XGRChain consensus voting power.

XGRChain delegated PoS uses stake- and uptime-aware voting power.

XGR Interchain attestation uses its own quorum semantics.

Therefore:

```text
XGRChain consensus voting power
≠
Interchain attestation voting weight
```

The two systems may use related validator identities and BLS infrastructure while remaining separate security domains.

---

## 9. Hyperlane-compatible transport

XGR Interchain uses Hyperlane-compatible message transport.

The integration retains the core messaging model including:

- Mailbox dispatch,
- Hyperlane message encoding,
- MerkleTreeHook insertion,
- message IDs,
- destination `Mailbox.process()`,
- Interchain Security Modules.

Hyperlane-compatible transport is the message-delivery framework.

XGR-specific security defines how supported XGR routes are authenticated.

For native XGR security routes, the trust anchor is not a standard relayer signature.

The security path uses XGR Interchain validator attestations and destination verification.

---

## 10. Canonical message flow

A normal Interchain message follows this conceptual lifecycle:

```text
source transaction
        │
        ▼
source Mailbox
        │
        ▼
canonical MerkleTreeHook
        │
        ▼
checkpoint
        │
        ▼
XGR Interchain validator attestation
        │
        ▼
BLS quorum
        │
        ▼
relayer proof construction
        │
        ▼
destination Mailbox
        │
        ▼
destination security verification
        │
        ▼
destination recipient / router
```

Security approval and message delivery are separate responsibilities.

---

## 11. XGRChain-native Interchain functionality

The XGRChain node contains native support for the XGR Interchain security model.

This includes:

- native Interchain checkpoint processing,
- validator attestation handling,
- completed-attestation state,
- read-only Interchain RPC,
- native BLS12-381 verification support.

Current native BLS verification precompile:

```text
0x0000000000000000000000000000000000002040
```

The precompile is implemented directly by the XGRChain node.

It does not require ordinary EVM bytecode deployment at that address.

This provides native execution support for cryptographic verification used by the XGR Interchain stack.

It does not make the Interchain worker part of IBFT consensus.

---

## 12. Native attestation RPC

Completed XGR Interchain attestations can be exposed through read-only XGRChain RPC.

Current route identifiers include:

```text
base
base_to_xgr
```

Latest completed attestation:

```text
xgr_getInterchainAttestation(route)
```

Checkpoint-specific lookup:

```text
xgr_getInterchainAttestationByCheckpoint(
    route,
    setId,
    index,
    root
)
```

These RPC methods are read-only.

They do not:

- request signatures,
- force validator participation,
- create quorum,
- submit cross-chain transactions.

They expose already completed Interchain attestation state.

---

## 13. XGRChain → Base

For the forward asset route:

```text
native XGR
    │
    │ lock
    ▼
XGR native router
    │
    ▼
XGR Mailbox
    │
    ▼
XGR MerkleTreeHook
    │
    ▼
XGR Interchain BLS attestation
    │
    ▼
relayer
    │
    ▼
Base Mailbox
    │
    ▼
XGR Interchain security verification
    │
    ▼
Base synthetic router
    │
    │ mint
    ▼
wXGR
```

The forward direction has been validated end-to-end on mainnet.

A controlled mainnet validation transferred:

```text
0.1 XGR
```

from XGRChain to Base.

The test demonstrated:

- native XGR locking,
- cross-chain message dispatch,
- canonical Merkle-tree insertion,
- validator attestation,
- BLS quorum completion,
- proof construction,
- destination verification,
- Base message processing,
- wXGR minting.

---

## 14. Base → XGRChain

The reverse route observes confirmed Base state from XGR validator infrastructure.

Conceptually:

```text
wXGR
    │
    │ burn
    ▼
Base synthetic router
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
XGR destination security modules
    │
    ▼
native XGR router
    │
    │ unlock
    ▼
native XGR
```

The Base → XGRChain direction has also been validated end-to-end on mainnet.

A controlled mainnet validation transferred:

```text
0.01 wXGR
```

back to native XGR on XGRChain.

The test demonstrated:

- wXGR burning,
- Base message dispatch,
- confirmed external checkpoint observation,
- reverse XGR Interchain attestation,
- BLS verification,
- Merkle inclusion verification,
- XGR Mailbox processing,
- native XGR unlocking.

---

## 15. External-chain confirmation

External source-chain state is not accepted immediately.

For the current Base → XGRChain route, XGR Interchain validation observes Base checkpoints only after the configured confirmation policy has been satisfied.

Current Base route configuration uses:

```text
12 Base blocks
```

of confirmation delay.

This is an Interchain route policy.

It is separate from XGRChain IBFT finality.

---

## 16. wXGR asset model

wXGR is the wrapped representation of native XGR on supported external networks.

For the current Base route:

```text
XGRChain native XGR
        │
        │ locked
        ▼
Base wXGR
```

and:

```text
Base wXGR
        │
        │ burned
        ▼
XGRChain native XGR
        │
        │ unlocked
        ▼
user
```

The design establishes a direct relationship between:

```text
native XGR locked for the route
```

and:

```text
wXGR issued through that route
```

The bridge itself is therefore not an exchange-rate mechanism.

The normal conversion relationship is:

```text
1 XGR ↔ 1 wXGR
```

before transaction and routing fees.

Market prices on exchanges or liquidity pools are separate from the bridge conversion model.

---

## 17. Official Base wXGR contract

The current official Base wXGR contract and synthetic router is:

```text
Network: Base
Chain ID: 8453

0x3b83687d77170d42feddfe221629cc21e771e021
```

Users and integrators must identify a token by:

```text
chain + contract address
```

rather than by symbol alone.

The symbol:

```text
wXGR
```

must not be treated as sufficient token identification.

Canonical deployment details are maintained in the Interchain deployment documentation.

---

## 18. Relayer role

The native relayer is intentionally not the security authority for a transfer.

Its responsibilities include:

- observing source messages,
- indexing canonical MerkleTreeHook leaves,
- retrieving completed XGR Interchain attestations,
- reconstructing Merkle proofs,
- constructing destination metadata,
- paying destination transaction gas,
- submitting the destination `Mailbox.process()` transaction.

Conceptually:

```text
validator quorum
    │
    │ creates security approval
    ▼
completed attestation
    │
    ▼
relayer
    │
    │ transports proof
    ▼
destination
```

A relayer can affect availability by delaying or withholding submission.

A relayer cannot create a valid validator quorum by itself.

---

## 19. Relayer key authority

The relayer uses a transaction-signing key because destination-chain gas must be paid.

That key provides authority to:

```text
submit a destination transaction
```

It does not provide authority to:

- sign as an XGR Interchain validator,
- generate a valid BLS quorum,
- change validator registry membership,
- finalize XGRChain blocks,
- spend a user's wallet assets,
- bypass destination security verification.

Therefore:

```text
relayer key
≠
validator key
≠
user wallet key
≠
XGRChain consensus authority
```

These are separate security domains.

---

## 20. Destination verification

A destination processes an Interchain message only after the configured security policy accepts it.

Depending on route and destination generation, verification can include:

- origin identity,
- destination identity,
- validator-set ID,
- signer bitmap,
- quorum,
- BLS aggregate signature,
- message identity,
- checkpoint root,
- Merkle inclusion proof,
- operational safety modules.

If required verification fails, the message must not be delivered.

---

## 21. Reverse safety layer

The current Base → XGRChain route includes an explicit operational safety layer in addition to cryptographic verification.

The XGRChain destination path uses a two-module aggregation requiring both:

```text
PausableISM
+
XGRNativeInterchainISMV2
```

to accept the message.

This means the reverse path can be operationally paused without changing the underlying cryptographic validator model.

The pause state is dynamic operational state.

It must be read from the live deployment rather than assumed from static documentation.

---

## 22. Fail-closed design

XGR Interchain is intended to fail closed.

A message must not be delivered when required validation fails.

Examples include:

- insufficient Interchain quorum,
- unknown validator set,
- invalid signer bitmap,
- invalid BLS aggregate signature,
- invalid checkpoint,
- wrong source domain,
- wrong destination domain,
- modified message,
- invalid Merkle proof,
- paused safety module,
- disabled route direction.

The system must not weaken security verification merely to restore availability.

---

## 23. Asset-transfer safety boundary

Asset movement and message transport are separate layers.

The asset routers enforce the lock/mint and burn/unlock model.

The Interchain security stack determines whether the corresponding cross-chain message may be accepted.

Conceptually:

```text
asset router
+
authenticated cross-chain message
+
destination verification
=
authorized asset transition
```

A relayer alone cannot authorize minting or unlocking.

---

## 24. Public bridge

The user-facing bridge provides access to the XGRChain ↔ Base asset route.

Its purpose is to allow a wallet user to convert:

```text
XGR → wXGR
```

or:

```text
wXGR → XGR
```

without requiring the user to manually construct Interchain messages.

The interface remains non-custodial with respect to the user's wallet.

The user signs the source transaction with the user's own wallet.

XGR Network infrastructure does not require possession of the user's private key to perform the transfer.

---

## 25. Public bridge terminology

The public user interface may use simplified terminology such as:

```text
Convert XGR to wXGR
Convert wXGR to XGR
```

The underlying protocol operation remains:

```text
XGRChain → Base:
lock / message / verify / mint

Base → XGRChain:
burn / message / verify / unlock
```

User-interface wording must not redefine the underlying asset or security model.

---

## 26. Deployment state and availability

The following states are distinct:

### Implemented

The protocol and contracts exist.

### Deployed

The required on-chain components have been deployed.

### Configured

The route's registries, routers and security modules are configured.

### End-to-end validated

A complete real transfer has successfully traversed the route.

### Operationally enabled

The required live runtime components are currently enabled.

### Publicly available

The route is intentionally exposed to normal users.

Therefore:

```text
deployed
≠
publicly available
```

and:

```text
E2E validated
≠
permanently enabled
```

Dynamic route availability must be evaluated from live deployment and runtime state.

---

## 27. Mainnet validation status

The first XGR asset route has passed controlled end-to-end validation in both directions.

| Direction | Status |
| --- | --- |
| XGRChain → Base | Mainnet E2E validated |
| Base → XGRChain | Mainnet E2E validated |

Forward validation amount:

```text
0.1 XGR
```

Reverse validation amount:

```text
0.01 wXGR
```

These tests provide direct evidence that the full lock/mint and burn/unlock paths have completed successfully on mainnet.

They do not replace continuous runtime monitoring.

---

## 28. Native security terminology

The following description is accurate:

```text
XGRChain-native Interchain security
```

because XGRChain provides native Interchain functionality and native BLS verification support.

The following concepts must remain distinct:

```text
native Interchain verification
```

and:

```text
XGRChain IBFT consensus
```

XGR Interchain is not simply another name for XGRChain consensus.

The native Interchain worker is intentionally outside the weighted-IBFT consensus-critical path.

For technical descriptions, preferred terminology includes:

```text
XGRChain-native Interchain security
```

```text
native BLS-verified Interchain security
```

```text
XGR-native validator attestations
```

rather than implying that external-chain delivery itself is part of IBFT consensus.

---

## 29. Security-domain separation

XGR Interchain separates key and authority domains.

| Authority | Primary role |
| --- | --- |
| User wallet key | User transaction authorization |
| XGR consensus validator key | IBFT consensus |
| XGR Interchain BLS identity | Cross-chain attestation |
| Relayer key | Destination gas and transaction submission |
| Router / deployment administration | Contract administration |

Compromise of one domain must not automatically be treated as compromise of every other domain.

Operational deployments should preserve this separation wherever practical.

---

## 30. Chain and address identity

Contract addresses must always be interpreted together with their chain.

This is especially important because identical hexadecimal addresses can exist on different networks while referring to completely different contracts.

Therefore the canonical identity is:

```text
chain ID + contract address
```

not:

```text
contract address alone
```

Detailed deployment identities are documented in:

```text
docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md
```

---

## 31. Supply relationship

For the lock/mint asset model, supply integrity depends on the router asset invariants.

Conceptually:

```text
locked native XGR
↔
issued wXGR
```

Forward conversion increases:

```text
locked native XGR
and
wXGR supply
```

by corresponding amounts.

Reverse conversion decreases:

```text
wXGR supply
and
locked native XGR
```

by corresponding amounts.

This relationship is independent from the market price at which wXGR may trade on a decentralized or centralized exchange.

---

## 32. Bridge versus exchange

The XGR Interchain bridge is not itself a market.

It performs a cross-network asset conversion based on the configured asset-routing rules.

A decentralized exchange may separately provide:

- wXGR/USDC liquidity,
- wXGR/ETH liquidity,
- market-price discovery,
- swaps between wXGR and other assets.

Therefore:

```text
bridge conversion
≠
DEX trade
```

The bridge defines the XGR ↔ wXGR route relationship.

A DEX defines market exchange rates between assets.

---

## 33. Source-of-truth boundaries

Different parts of XGR Interchain have different authoritative sources.

| Area | Primary source |
| --- | --- |
| XGRChain native Interchain functionality | `xgr-network/xgr-node` |
| Public XGR Interchain documentation | `xgr-network/XGR/docs/interchain/` |
| Interchain contracts and deployment tooling | `xgr-network/xgr-hyperlane` |
| Deployment manifests | `xgr-network/xgr-hyperlane/deployments/` |
| Relayer runtime | `xgr-network/xgr-hyperlane/runtime/` |
| Dynamic route state | Live contract and runtime state |
| User-facing bridge | XGR Network bridge application |

Static documentation must not override live on-chain state.

Likewise, a historical runtime state must not be presented as permanent protocol behavior.

---

## 34. Documentation layers

The public documentation is intentionally divided by audience.

### XGR repository

The `xgr-network/XGR` repository documents:

- public architecture,
- security model,
- asset model,
- deployment reference,
- protocol boundaries.

### Interchain repository

The `xgr-network/xgr-hyperlane` repository documents:

- implementation details,
- contracts,
- deployment tooling,
- machine-readable manifests,
- relayer runtime,
- operator procedures.

### User-facing bridge

The public bridge interface documents only what a normal user needs in order to:

- understand XGR and wXGR,
- connect a wallet,
- select a direction,
- enter an amount,
- confirm a transfer,
- identify the official wXGR contract,
- observe transfer status.

Deep protocol internals do not need to be exposed in the normal bridge workflow.

---

## 35. Related Interchain documents

The public XGR Interchain documentation set consists of:

```text
docs/interchain/XGR_INTERCHAIN_Overview.md
docs/interchain/XGR_INTERCHAIN_Security_Model.md
docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md
docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md
```

### Overview

Defines the architecture and system boundaries.

### Security Model

Defines:

- validator membership,
- BLS attestations,
- quorum,
- Merkle proofs,
- destination verification,
- relayer trust,
- security-module composition,
- failure behavior.

### Asset Bridge

Defines:

- native XGR,
- wXGR,
- lock/mint,
- burn/unlock,
- conversion semantics,
- supply relationship,
- user-transfer lifecycle.

### Deployment Reference

Defines:

- chain identities,
- router addresses,
- Mailboxes,
- MerkleTreeHooks,
- validator registries,
- ISMs,
- safety modules,
- official wXGR contract,
- current canonical deployment identities.

---

## 36. Implementation repositories

XGRChain node:

```text
https://github.com/xgr-network/xgr-node
```

XGR Interchain implementation:

```text
https://github.com/xgr-network/xgr-hyperlane
```

Public XGR specifications and documentation:

```text
https://github.com/xgr-network/XGR
```

---

## 37. Update triggers

This document must be reviewed when any of the following changes:

- supported Interchain networks,
- XGRChain public node baseline,
- native Interchain attestation behavior,
- native BLS verification behavior,
- Interchain validator membership model,
- Interchain quorum model,
- Hyperlane transport integration,
- asset-routing semantics,
- official wXGR deployment,
- public bridge architecture,
- security-domain boundaries.

Dynamic runtime changes such as:

- a temporary relayer restart,
- a pause event,
- RPC maintenance,

do not necessarily require changes to this architecture document unless they alter the defined public operating model.

---

## 38. Summary

| Topic | Current design |
| --- | --- |
| First production route | XGRChain ↔ Base |
| XGRChain chain/domain | `1643` |
| Base chain/domain | `8453` |
| XGRChain asset | Native XGR |
| Base asset | wXGR |
| Forward asset model | Lock XGR / mint wXGR |
| Reverse asset model | Burn wXGR / unlock XGR |
| Message transport | Hyperlane-compatible |
| Interchain approval | XGR Interchain validator BLS quorum |
| Interchain quorum | Unweighted two-thirds |
| XGR native BLS verifier | Precompile `0x2040` |
| Relayer trust | Untrusted for message validity |
| Consensus relationship | Separate from weighted IBFT consensus |
| XGRChain → Base | Mainnet E2E validated |
| Base → XGRChain | Mainnet E2E validated |
| Public availability | Operational state, evaluated separately |

XGR Interchain extends XGRChain to supported external networks while keeping chain consensus, Interchain validation, relayer operation and user-wallet authority as explicitly separated security domains.
