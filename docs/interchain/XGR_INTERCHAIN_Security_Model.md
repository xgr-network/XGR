# XGR Interchain — Security Model

**Document ID:** XGR-INTERCHAIN-SECURITY  
**Last updated:** 2026-10-04  
**Audience:** Protocol developers, validator operators, infrastructure operators, integrators, auditors, security reviewers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Implementation status:** Mainnet  
**Interchain implementation:** `xgr-network/xgr-hyperlane`, branch `main`  
**XGRChain implementation:** `xgr-network/xgr-node`  
**Scope:** Validator trust, BLS attestations, quorum, message inclusion, destination verification, relayer authority and operational safety boundaries

---

## 1. Purpose

This document defines the security model of XGR Interchain.

It describes:

- the separation between XGRChain consensus and Interchain security,
- Interchain validator membership,
- validator BLS identities,
- Interchain quorum,
- checkpoint attestations,
- Merkle inclusion proofs,
- destination verification,
- validator-set versioning,
- relayer trust assumptions,
- operational safety modules,
- key and authority separation,
- failure behavior,
- principal security boundaries.

This document focuses on security semantics.

Asset-routing behavior is documented separately in:

```text
docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md
```

The normative v3.1.3 multi-route extension of this security model is defined in:

```text
docs/interchain/XGR_INTERCHAIN_v3.1.3_Protocol.md
```

The v3.1.3 specification preserves the untrusted-relayer and destination-scoped membership principles defined here while adding canonical `routeId`, dedicated `authorizedMessageId`, route-scoped governance nonce and fee-bound checkpoint semantics.

Canonical deployed addresses are documented in:

```text
docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md
```

---

## 2. Security objectives

XGR Interchain is designed around the following security objectives:

1. a relayer must not be able to forge transfer authorization;
2. a destination must independently verify the Interchain validator quorum;
3. a message must be cryptographically bound to the checkpoint being approved;
4. a message must prove inclusion in the canonical configured message tree;
5. validator-set changes must not invalidate legitimate historical attestations;
6. failure of external infrastructure must not weaken verification;
7. failure of Interchain infrastructure must not stop XGRChain consensus;
8. different key domains must retain different authority;
9. invalid or incomplete verification must fail closed;
10. asset minting or unlocking must occur only after the configured destination security policy succeeds.

The security model deliberately separates:

```text
message validity
```

from:

```text
message availability
```

A valid message may be delayed.

An invalid message must not be accepted merely to preserve availability.

---

## 3. Security architecture

At a high level:

```text
canonical source-chain message
        │
        ▼
canonical checkpoint
        │
        ▼
XGR Interchain validators
        │
        │ BLS attestation
        ▼
Interchain quorum
        │
        ▼
relayer
        │
        │ message + proof + metadata
        ▼
destination Mailbox
        │
        ▼
destination security modules
        │
        ▼
message accepted or rejected
```

The relayer transports security evidence.

It does not create the security approval.

---

## 4. Separation from XGRChain consensus

XGRChain consensus and XGR Interchain security are separate systems.

XGRChain consensus is responsible for:

- block production,
- proposal validation,
- IBFT prepare and commit voting,
- deterministic finality,
- delegated PoS validator participation,
- stake- and uptime-weighted voting power,
- canonical XGRChain state.

XGR Interchain security is responsible for:

- cross-chain checkpoint observation,
- destination-specific validator membership,
- Interchain BLS attestations,
- Interchain quorum,
- message-inclusion verification,
- destination security-module verification.

Therefore:

```text
XGRChain IBFT consensus
≠
XGR Interchain validator quorum
```

A validator may participate in both systems.

That does not make the two authority domains identical.

---

## 5. Consensus-critical isolation

The native XGR Interchain worker is deliberately outside the weighted-IBFT consensus-critical path.

An external-chain failure must not prevent:

- XGR block proposal,
- XGR block validation,
- IBFT finalization,
- normal chain synchronization,
- delegated PoS accounting.

Conceptually:

```text
XGRChain consensus
        │
        ├── EVM execution
        ├── IBFT finality
        ├── delegated PoS
        └── canonical state
                │
                │ observed by
                ▼
        Interchain worker
```

Interchain functionality consumes canonical chain state.

It does not determine whether XGRChain itself can finalize blocks.

---

## 6. Validator roles

XGR uses separate validator roles for separate security purposes.

### Consensus validator

An XGRChain consensus validator participates in:

- IBFT,
- block production,
- block verification,
- consensus voting,
- delegated PoS.

### Interchain validator

An XGR Interchain validator participates in:

- destination-specific Interchain membership,
- checkpoint observation,
- BLS signing,
- Interchain quorum.

The roles may be operated by the same validator organization or infrastructure.

Their authority remains distinct.

---

## 7. Interchain validator membership

Interchain membership is destination-specific.

A validator becomes an authorized Interchain signer for a destination only when the configured membership conditions are satisfied.

Conceptually:

```text
XGR validator identity
        │
        ├── staking identity
        └── BLS identity
                │
                ▼
destination-specific registry
                │
                ▼
authorized Interchain signer
```

The destination validator registry is the canonical membership source for the corresponding Interchain security path.

A relayer does not determine membership.

A wallet does not determine membership.

An RPC client does not determine membership.

---

## 8. Destination-scoped membership

Membership and checkpoint routes are separate concepts.

Membership is associated with a destination security registry.

Checkpoint attestations remain route-specific.

For example:

```text
base_to_xgr
polygon_to_xgr
arbitrum_to_xgr
```

can conceptually share:

```text
destination = XGRChain
```

and therefore use the same destination Interchain validator membership while retaining independent:

- source chains,
- Mailboxes,
- MerkleTreeHooks,
- confirmation policies,
- checkpoint streams,
- route identifiers.

This prevents validator membership from having to be duplicated for every possible source route to the same destination.

---

## 9. Interchain quorum

The native XGR Interchain validator set uses an unweighted two-thirds quorum.

Conceptually:

```text
quorum =
two-thirds of configured Interchain membership
```

The Interchain quorum does not use XGRChain's stake- and uptime-weighted IBFT voting power.

Therefore:

```text
Interchain signer count
≠
IBFT consensus voting power
```

and:

```text
Interchain quorum
≠
IBFT commit quorum
```

These systems serve different security functions.

---

## 10. Why Interchain quorum is separate

XGRChain consensus determines whether an XGRChain block becomes final.

Interchain quorum determines whether a cross-chain checkpoint receives sufficient authorized attestation.

The security domains therefore answer different questions.

Consensus asks:

```text
Is this XGRChain block finalized?
```

Interchain validation asks:

```text
Has the configured Interchain validator quorum approved this cross-chain checkpoint?
```

Conflating the two would incorrectly imply that cross-chain delivery is part of IBFT block finality.

It is not.

---

## 11. BLS identities

XGR Interchain uses BLS validator identities for aggregate checkpoint attestations.

Multiple validator signatures can be combined into an aggregate signature.

The destination security logic verifies that:

- the signing identities belong to the relevant validator set,
- the signer bitmap corresponds to valid members,
- the required quorum is reached,
- the aggregate BLS signature is valid for the approved checkpoint context.

A valid aggregate signature therefore represents approval by the required Interchain validator quorum.

---

## 12. Native XGRChain BLS verification

XGRChain exposes native BLS12-381 verification through:

```text
0x0000000000000000000000000000000000002040
```

This address is a native execution precompile.

Verification is implemented directly in the XGRChain node.

It does not depend on ordinary deployed EVM bytecode at that address.

The reverse Base → XGRChain security path uses this native verification capability for compressed BLS aggregate signatures.

---

## 13. External destination verification

External EVM destinations may use the BLS verification capabilities available on that destination.

For the current XGRChain → Base route, Base provides the destination execution environment for the XGR Interchain verification contracts.

The security invariant remains:

```text
destination execution
must independently verify
the required XGR Interchain quorum
```

The relayer's assertion alone is insufficient.

---

## 14. Checkpoint model

Cross-chain validation is performed against checkpoints derived from the configured canonical message tree.

Conceptually:

```text
message 0
message 1
message 2
...
        │
        ▼
Merkle tree
        │
        ▼
checkpoint root
```

Interchain validators attest the checkpoint context.

The destination subsequently verifies that the delivered message belongs to the approved checkpoint.

---

## 15. MerkleTreeHook security boundary

The configured canonical Hyperlane MerkleTreeHook is part of the route security boundary.

Supported messages must enter the expected tree.

Conceptually:

```text
Mailbox dispatch
        │
        ▼
configured MerkleTreeHook
        │
        ▼
canonical message tree
```

A message path that bypasses the expected tree cannot be proven against that tree.

Therefore supported public routing must either:

- use the canonical configured MerkleTreeHook, or
- reject message paths that do not satisfy the expected hook configuration.

---

## 16. Merkle inclusion proofs

Validator approval of a checkpoint does not by itself prove that an arbitrary message belongs to that checkpoint.

The destination also verifies Merkle inclusion.

Conceptually:

```text
message ID
    +
Merkle proof
    +
approved root
        │
        ▼
message inclusion verified
```

A modified or unrelated message must not validate against the approved root.

---

## 17. Binding security evidence to a message

Destination verification can include:

- route origin,
- route destination,
- checkpoint identity,
- validator-set ID,
- signer bitmap,
- aggregate signature,
- Merkle root,
- Merkle proof,
- message identity.

The combined checks bind:

```text
authorized validator quorum
```

to:

```text
a specific checkpoint
```

and bind:

```text
a specific message
```

to:

```text
that checkpoint
```

This prevents a valid signature from being treated as authorization for an unrelated message.

---

## 18. Validator-set versioning

Interchain membership can change over time.

A validator may:

- join,
- leave,
- become ineligible,
- be replaced,
- participate in a later set.

The system therefore versions validator membership.

A membership transition advances:

```text
setId
```

Security verification must distinguish:

```text
the validator set active now
```

from:

```text
the validator set that signed a historical checkpoint
```

---

## 19. Historical validator sets

The reverse XGRChain destination uses RegistryV2 semantics that preserve historical validator-set information.

This supports verification of a checkpoint created under an earlier valid set.

Conceptually:

```text
checkpoint A
signed under set 1

membership transition

current set = 2
```

does not automatically make checkpoint A unverifiable.

Verification can resolve the legitimate historical set associated with the attestation.

Unknown or fabricated historical sets must still be rejected.

---

## 20. Registry as membership authority

The destination registry is the canonical Interchain membership state.

The destination security module does not need to maintain an unrelated duplicate membership list.

Conceptually:

```text
Registry
    │
    │ membership / set history
    ▼
Interchain Security Module
    │
    │ verifies submitted proof
    ▼
accept / reject
```

This reduces the risk of divergent validator membership between independent copies of security state.

---

## 21. Destination security modules

Hyperlane-compatible message processing uses Interchain Security Modules to determine whether a message is sufficiently authenticated.

For XGR native security routes, XGR-specific ISMs verify the configured XGR Interchain security evidence.

Depending on route generation, this can include:

- validator-set resolution,
- signer bitmap validation,
- quorum validation,
- BLS aggregate-signature validation,
- checkpoint validation,
- Merkle inclusion validation,
- route identity validation.

The destination Mailbox must not process the message successfully unless the configured security policy succeeds.

---

## 22. Forward destination security

For XGRChain → Base:

```text
XGRChain
    │
    ▼
XGR Interchain attestation
    │
    ▼
relayer
    │
    ▼
Base Mailbox
    │
    ▼
XGR-native destination ISM
    │
    ▼
Base router / recipient
```

The Base-side security stack verifies the XGR-origin Interchain proof before the message can be delivered.

The relayer therefore does not have unilateral mint authority.

---

## 23. Reverse destination security

For Base → XGRChain:

```text
Base
    │
    ▼
confirmed Base checkpoint
    │
    ▼
XGR Interchain validator attestation
    │
    ▼
relayer
    │
    ▼
XGR Mailbox
    │
    ▼
XGR destination security policy
    │
    ▼
XGR router / recipient
```

The current reverse path uses native XGRChain BLS verification together with an explicit operational safety layer.

---

## 24. Reverse aggregation policy

The current Base → XGRChain route uses a two-module aggregation.

Both modules must accept the message:

```text
PausableISM
+
XGRNativeInterchainISMV2
```

Conceptually:

```text
cryptographic verification = valid
AND
operational safety gate = open
        │
        ▼
message may proceed
```

This is a 2-of-2 policy.

Failure of either required module causes rejection.

---

## 25. Pausable safety module

The PausableISM provides an explicit operational safety control.

It is separate from BLS cryptographic validation.

The safety module allows the configured reverse route to be paused if necessary without changing:

- validator private keys,
- BLS cryptography,
- validator registry membership,
- XGRChain consensus.

Therefore:

```text
cryptographically valid
```

does not necessarily mean:

```text
operationally permitted
```

when an explicit pause control is active.

At the current mainnet baseline, the reverse route is publicly enabled and the required safety gate is open.

The pause state remains dynamic and must be verified live when current route availability is material.

---

## 26. External-chain confirmation policy

The reverse route observes an external source chain.

External state must satisfy the configured confirmation policy before XGR Interchain validators attest it.

For Base → XGRChain, the current route uses:

```text
12 Base blocks
```

of confirmation delay before the corresponding checkpoint is considered eligible for attestation.

This separates:

```text
newly observed external state
```

from:

```text
state accepted for Interchain attestation
```

The confirmation policy belongs to route configuration.

It does not alter XGRChain IBFT finality.

---

## 27. Native attestation generation

Participating XGR validator infrastructure independently observes the configured checkpoint state.

After all route conditions are satisfied, eligible Interchain validators can contribute their BLS attestation.

Conceptually:

```text
canonical checkpoint observed
        │
        ▼
route policy satisfied
        │
        ▼
eligible Interchain signer
        │
        ▼
BLS signature
```

The system aggregates signatures after sufficient valid contributions exist.

A relayer does not request an authoritative signature through RPC.

---

## 28. Read-only attestation RPC

Completed native attestations can be exposed through XGRChain RPC.

Examples include:

```text
xgr_getInterchainAttestation(route)
```

and:

```text
xgr_getInterchainAttestationByCheckpoint(
    route,
    setId,
    index,
    root
)
```

These methods expose already completed state.

They do not:

- create validator signatures,
- lower quorum,
- force a validator to sign,
- create a new checkpoint,
- submit the destination transaction.

This distinction prevents RPC access from becoming signing authority.

---

## 29. Relayer trust model

The XGR native relayer is intentionally untrusted for message validity.

Its responsibilities include:

- observing Dispatch events,
- indexing MerkleTreeHook state,
- retrieving completed attestations,
- reconstructing Merkle proofs,
- constructing destination metadata,
- paying destination gas,
- submitting `Mailbox.process()`.

Its responsibilities do not include:

- determining Interchain membership,
- generating validator keys,
- lowering quorum,
- forging BLS signatures,
- bypassing destination ISMs.

---

## 30. Relayer availability versus validity

A malicious or failed relayer can affect availability.

Examples:

- delay a message,
- refuse to submit,
- lose synchronization,
- run out of destination gas,
- stop processing.

A relayer must not be able to turn an invalid message into a valid one.

Therefore:

```text
relayer compromise
can affect liveness
```

but must not imply:

```text
relayer compromise
grants validator quorum authority
```

---

## 31. Permissionless delivery property

Because destination verification determines message validity, the security model does not inherently require trust in a specific delivery identity for cryptographic authorization.

The current native relayer is an operational delivery service.

Security acceptance remains based on the submitted proof and the destination security policy.

This separation is important:

```text
who submits
```

must not replace:

```text
what is cryptographically verified
```

---

## 32. Relayer signing key

The relayer requires a blockchain account to submit destination transactions and pay gas.

The relayer key therefore authorizes:

```text
transaction submission from the relayer account
```

It does not authorize:

- user-wallet transactions,
- BLS validator attestations,
- IBFT consensus votes,
- registry membership changes unless separately granted,
- arbitrary minting,
- arbitrary unlocking.

The destination transaction still passes through the configured security checks.

---

## 33. User wallet authority

The user wallet authorizes the source asset transaction.

For a normal asset transfer:

```text
user wallet
    │
    │ signs
    ▼
source transaction
```

XGR.Network infrastructure does not require possession of the user's private key.

The relayer does not sign the source transaction on the user's behalf.

The destination validator quorum does not possess the user's wallet key.

---

## 34. Asset authorization boundary

The bridge asset routers execute the asset transition only as part of the authenticated cross-chain flow.

Forward:

```text
native XGR locked
        │
        ▼
authenticated message
        │
        ▼
wXGR minted
```

Reverse:

```text
wXGR burned
        │
        ▼
authenticated message
        │
        ▼
native XGR unlocked
```

Cross-chain asset release must therefore remain dependent on successful message authentication.

---

## 35. No relayer mint authority

A relayer cannot legitimately create wXGR merely by submitting a transaction.

The destination message must pass the configured security verification.

Likewise, a reverse relayer cannot legitimately unlock native XGR by itself.

Therefore:

```text
relayer transaction
+
invalid proof
=
rejected
```

The relayer is not a minting or custody authority.

---

## 36. Key-domain separation

The system distinguishes multiple sensitive key domains.

| Key domain | Authority |
| --- | --- |
| User wallet key | User asset transactions |
| XGR consensus validator key | IBFT consensus |
| XGR Interchain BLS identity | Interchain checkpoint attestation |
| Relayer key | Destination transaction submission and gas |
| Router / deployment administrator | Authorized contract administration |

These keys must not be treated as interchangeable.

Compromise of one domain has a different impact from compromise of another.

---

## 37. Consensus-key compromise

Compromise of an XGRChain consensus validator key affects the validator's consensus authority according to the active XGRChain validator rules.

It does not automatically provide:

- another validator's Interchain BLS key,
- a user wallet key,
- a relayer key,
- router ownership.

Consensus security is documented separately under:

```text
docs/chain/XGRCHAIN_Consensus_IBFT.md
```

---

## 38. Interchain-key compromise

Compromise of an Interchain validator BLS identity can allow unauthorized signatures from that validator identity.

It does not by itself satisfy the Interchain quorum unless sufficient additional authorized signing power is also compromised.

The quorum requirement therefore limits the authority of one individual Interchain signing key.

---

## 39. Relayer-key compromise

Compromise of the relayer key can allow an attacker to spend the relayer account's gas balance and submit transactions from that account.

It does not by itself create:

- a valid BLS aggregate signature,
- sufficient Interchain quorum,
- a valid Merkle inclusion proof for a fabricated message,
- XGRChain IBFT authority,
- user-wallet signing authority.

The destination verification path remains the security barrier for message acceptance.

---

## 40. Administrative-key compromise

Router, registry or security-module administration may have deployment-specific authority.

Administrative permissions are therefore a separate security domain and must be evaluated according to the deployed contract configuration.

Administrative authority must not be confused with:

- validator BLS authority,
- user-wallet authority,
- consensus authority,
- relayer authority.

Canonical ownership and deployment relationships belong in the deployment reference and current on-chain state.

---

## 41. Fail-closed verification

The system is designed to reject rather than silently weaken verification.

A message must fail when required conditions are not met.

Examples include:

- unknown validator set,
- invalid validator-set ID,
- invalid signer bitmap,
- insufficient signer quorum,
- invalid BLS aggregate signature,
- wrong checkpoint,
- wrong origin,
- wrong destination,
- modified message,
- invalid Merkle proof,
- paused required safety module.

The system must not fall back to a weaker security mechanism merely because the preferred verification path fails.

---

## 42. Invalid signer bitmap

The signer bitmap identifies which members of the referenced validator set participated in an aggregate signature.

Verification must reject a bitmap that:

- refers to invalid membership,
- implies insufficient quorum,
- is inconsistent with the aggregate signature,
- exceeds the valid membership context.

A bitmap alone is not proof.

It is interpreted together with the validator set and BLS signature.

---

## 43. Unknown validator set

A submitted historical `setId` must correspond to legitimate registry state.

An arbitrary or fabricated set identifier must not be accepted merely because metadata contains validator information.

Historical verification depends on canonical registry history.

Therefore:

```text
submitted validator list
≠
canonical validator set
```

The canonical registry state remains authoritative.

---

## 44. Invalid BLS signature

An invalid aggregate BLS signature must cause verification failure.

Possible causes include:

- modified checkpoint data,
- incorrect validator keys,
- malformed aggregate signature,
- incorrect signer bitmap,
- insufficient valid signers,
- signature generated for a different message.

There must be no successful message-delivery path that ignores a required BLS verification failure.

---

## 45. Invalid Merkle proof

A valid validator attestation does not authorize a message that is not contained in the approved checkpoint tree.

If the Merkle proof does not reconstruct the expected checkpoint root, message verification must fail.

Therefore an attacker cannot reuse a valid checkpoint attestation as generic authorization for arbitrary messages.

---

## 46. Message modification

Changing any security-relevant part of a cross-chain message changes the data being verified.

A modified message must not continue to validate under a proof created for the original message.

This includes changes to security-relevant routing or payload fields covered by the message identity and proof path.

---

## 47. Replay and delivery state

Hyperlane-compatible Mailbox processing tracks delivered messages.

A successfully processed message must not be treated as a fresh independent delivery merely by resubmitting identical data.

Destination delivery state is therefore part of the broader replay-resistance model.

Message IDs must be handled as canonical cross-chain identifiers.

---

## 48. Route identity

Security evidence is route-sensitive.

Forward and reverse routes are not interchangeable.

Examples:

```text
base
```

and:

```text
base_to_xgr
```

represent distinct attestation contexts.

A valid attestation for one configured route must not be assumed valid for another route with different:

- source,
- destination,
- checkpoint stream,
- confirmation policy,
- security configuration.

---

## 49. Chain identity

Chain identity is part of the security model.

Addresses alone are insufficient because identical hexadecimal addresses can exist on multiple chains.

Canonical identification requires:

```text
chain/domain + address
```

This applies to:

- routers,
- Mailboxes,
- registries,
- ISMs,
- hooks,
- tokens.

Deployment documentation must always include network identity together with an address.

---

## 50. Address collisions

The current deployment contains identical hexadecimal addresses used for different contracts on different chains.

This is valid because EVM address spaces are chain-specific.

It creates an operational requirement:

```text
never interpret a production Interchain address
without its chain context
```

Monitoring, documentation, incident response and deployment tooling must preserve this distinction.

---

## 51. Dynamic operational controls

Some security-related state is dynamic.

Examples include:

- router direction gates,
- PausableISM state,
- active validator-set membership,
- relayer submission state,
- relayer process state.

Static documentation cannot prove the current value of dynamic state indefinitely.

Operational systems must query live state where current availability matters.

At the current mainnet documentation baseline:

```text
XGRChain → Base = publicly enabled
Base → XGRChain = publicly enabled
```

and both native relayer directions are configured for submission.

---

## 52. Availability is not security equivalence

The route can become unavailable while its cryptographic architecture remains intact.

Examples include:

```text
relayer stopped
```

```text
router direction disabled
```

```text
PausableISM paused
```

These conditions can prevent successful transfers.

They do not imply that the system should bypass security checks.

The correct failure behavior is:

```text
route unavailable
```

rather than:

```text
weaker verification
```

---

## 53. Public route gating

The public bridge must not infer availability from contract deployment alone.

A safe availability decision can depend on:

- source-chain RPC health,
- destination-chain RPC health,
- source router direction,
- destination router direction,
- pause state,
- relayer submission state,
- relayer process state,
- route configuration.

Therefore:

```text
contract exists
≠
route available
```

The production bridge currently exposes both XGRChain ↔ Base directions, while continuing to evaluate live route state separately.

Public bridge:

```text
https://bridge.xgr.network
```

---

## 54. End-to-end validation

Both XGRChain ↔ Base asset-transfer directions have completed controlled mainnet end-to-end validation.

This demonstrates that the configured security path has successfully performed:

- source asset transition,
- message dispatch,
- checkpoint inclusion,
- validator attestation,
- quorum completion,
- proof construction,
- destination verification,
- destination asset transition.

Forward validation transferred:

```text
0.1 XGR
```

from XGRChain to Base.

Reverse validation transferred:

```text
0.01 wXGR
```

from Base back to XGRChain.

End-to-end validation provides strong implementation evidence.

The production route is currently publicly enabled in both directions.

Validation evidence does not replace ongoing monitoring of dynamic runtime state.

---

## 55. Forward trust boundary

For XGRChain → Base, the security path can be summarized as:

```text
XGR canonical state
        │
        ▼
XGR canonical message tree
        │
        ▼
authorized XGR Interchain quorum
        │
        ▼
Base destination verification
        │
        ▼
message delivery
```

No single relayer signature is the trust anchor.

---

## 56. Reverse trust boundary

For Base → XGRChain, the security path can be summarized as:

```text
confirmed Base state
        │
        ▼
canonical Base message tree
        │
        ▼
authorized XGR Interchain quorum
        │
        ▼
native XGR BLS verification
        │
        +
        ▼
operational safety gate
        │
        ▼
message delivery
```

The reverse path therefore combines:

- external-chain observation,
- XGR Interchain quorum,
- native BLS verification,
- explicit pause capability.

---

## 57. Threat: malicious relayer

A malicious relayer may attempt to:

- submit malformed metadata,
- submit a modified message,
- submit an invalid proof,
- replay already delivered material,
- delay a valid message.

Expected behavior:

- invalid security evidence is rejected,
- duplicate delivered messages do not become independent valid transfers,
- delayed valid messages affect liveness rather than authorization.

---

## 58. Threat: compromised minority of validators

If fewer than the required Interchain quorum is compromised, the attacker must not be able to produce a valid quorum attestation.

The system therefore depends on maintaining the configured quorum security assumption.

Operational validator diversity is important because cryptographic quorum does not by itself guarantee organizational independence.

---

## 59. Threat: external-chain RPC failure

External RPC failure can prevent:

- checkpoint observation,
- confirmation tracking,
- proof indexing,
- message delivery.

It must not:

- weaken the confirmation policy,
- fabricate source state,
- stop XGRChain IBFT finality.

The correct response is reduced Interchain availability.

---

## 60. Threat: destination RPC failure

Destination RPC failure can prevent transaction submission or monitoring.

It does not authorize bypassing the destination security modules.

The route should remain delayed or unavailable until destination interaction can resume safely.

---

## 61. Threat: validator-set transition

A membership transition creates the risk of incorrectly validating an older checkpoint against a newer validator set.

Historical-set support exists to prevent this ambiguity.

Verification must resolve the set actually associated with the attestation.

Therefore:

```text
current membership
```

is not automatically:

```text
membership that signed every historical checkpoint
```

---

## 62. Threat: stale operational state

A dashboard, manifest or static configuration can become stale.

Security-sensitive operational decisions must not rely solely on previously recorded state when live state is required.

Examples include:

- pause state,
- router gates,
- active runtime submission,
- current block height,
- current validator-set version.

Static documentation describes architecture.

Live state determines current operation.

---

## 63. Cryptographic verification versus operational policy

The system intentionally has multiple layers.

A message may satisfy its cryptographic proof and still be blocked by an explicit operational safety control.

Conversely, an open operational gate must not make an invalid cryptographic proof acceptable.

Conceptually:

```text
cryptographic validity
AND
required operational policy
=
delivery eligibility
```

Both dimensions matter.

---

## 64. Security of wrapped supply

The wXGR asset model depends on authenticated cross-chain transitions.

Security therefore requires that minting and unlocking remain coupled to valid Interchain messages.

The target invariant is:

```text
wXGR issuance
corresponds to
native XGR locked through the bridge route
```

and:

```text
native XGR unlocking
corresponds to
wXGR burned through the reverse route
```

Market trading of wXGR does not change these bridge-security rules.

---

## 65. DEX independence

A decentralized exchange is outside the core bridge security boundary.

A DEX may:

- hold wXGR liquidity,
- establish a market price,
- enable swaps.

It does not determine:

- XGR Interchain validator quorum,
- bridge backing,
- router authorization,
- native XGR unlocking.

Therefore:

```text
DEX market security
≠
XGR Interchain bridge security
```

---

## 66. Non-custodial wallet boundary

The user-facing bridge does not require XGR.Network infrastructure to take possession of the user's private key.

The user:

1. connects a wallet,
2. selects a transfer,
3. signs the source transaction.

The user's signing authority remains in the wallet.

The bridge contracts and Interchain infrastructure subsequently execute according to their deployed rules.

---

## 67. Private-key handling

Production infrastructure must never require public documentation or source repositories to contain:

- user private keys,
- validator private keys,
- Interchain BLS secret keys,
- relayer private keys,
- deployment private keys,
- seed phrases,
- keystore passwords.

Only public identities and non-secret configuration belong in public repositories.

---

## 68. Secret separation

Operational systems should maintain separate credentials for separate roles wherever practical.

Conceptually:

```text
consensus signer
Interchain signer
relayer account
deployment administrator
user wallet
```

should not be collapsed into one universal credential.

This limits the blast radius of a single-key compromise.

---

## 69. Monitoring requirements

Production security monitoring should distinguish:

- validator attestation health,
- Interchain quorum availability,
- source checkpoint progress,
- router gates,
- pause state,
- relayer process health,
- relayer gas balance,
- destination delivery success.

Monitoring availability must not be confused with modifying the cryptographic security model.

---

## 70. Incident response principle

If the route's required security assumptions cannot be verified, the safe operational response is to stop or pause affected transfer processing.

Examples include:

- unexplained validator-set mismatch,
- invalid attestation behavior,
- inconsistent checkpoint state,
- compromised signing credentials,
- security-module failure.

The correct principle is:

```text
fail closed first
investigate second
restore only after verification
```

---

## 71. Upgrade boundaries

Different Interchain components can evolve independently.

Examples include:

- XGRChain node support,
- registry contracts,
- ISMs,
- relayer runtime,
- routing configuration.

An upgrade to one layer must not silently redefine authority in another layer.

For example:

```text
new relayer version
```

must not imply:

```text
new validator quorum rules
```

unless those rules are explicitly changed in the relevant authoritative implementation.

---

## 72. V1 and V2 terminology

V1 and V2 identify generations of specific Interchain security contracts.

They do not mean:

```text
forward
versus
reverse
```

and they do not represent different fundamental trust anchors.

Both deployed XGR native security generations use XGR Interchain validator BLS security.

V2 additionally supports requirements such as historical validator-set verification used by the reverse XGRChain destination path.

---

## 73. Security source-of-truth boundaries

| Security area | Primary source |
| --- | --- |
| XGRChain consensus security | `xgr-network/xgr-node` and XGRChain consensus documentation |
| Native BLS precompile | `xgr-network/xgr-node` |
| Interchain validator contracts | `xgr-network/xgr-hyperlane` |
| Deployment addresses | Interchain deployment manifests and live chain state |
| Relayer implementation | `xgr-network/xgr-hyperlane/runtime/` |
| Dynamic pause / gate state | Live on-chain state |
| Public security documentation | `xgr-network/XGR/docs/interchain/` |

No single static document replaces live verification of dynamic operational state.

---

## 74. Related documents

Interchain overview:

```text
docs/interchain/XGR_INTERCHAIN_Overview.md
```

Asset bridge:

```text
docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md
```

Deployment reference:

```text
docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md
```

XGRChain consensus:

```text
docs/chain/XGRCHAIN_Consensus_IBFT.md
```

XGRChain access-control boundaries:

```text
docs/chain/XGRCHAIN_Access_Control_and_Permission_Boundaries.md
```

XGR Interchain implementation:

```text
https://github.com/xgr-network/xgr-hyperlane
```

---

## 75. Update triggers

This document must be reviewed when any of the following changes:

- Interchain validator membership rules,
- Interchain quorum,
- BLS signature format,
- native BLS verification behavior,
- registry-set versioning,
- historical-set verification,
- route confirmation policy,
- MerkleTreeHook assumptions,
- destination ISM composition,
- PausableISM policy,
- relayer trust assumptions,
- key-authority boundaries,
- asset authorization model.

Purely cosmetic bridge-UI changes do not require a security-model revision unless they change the represented trust or authority model.

---

## 76. Security summary

| Security property | Current model |
| --- | --- |
| Implementation status | Mainnet |
| XGRChain consensus | IBFT with delegated PoS |
| Interchain security | Separate validator-attestation domain |
| Interchain signature scheme | BLS |
| Interchain quorum | Unweighted two-thirds |
| Membership | Destination-specific registry |
| Historical sets | Supported where required by RegistryV2 |
| Message inclusion | Merkle proof |
| Forward destination | Base security contracts |
| Reverse destination | XGRChain native BLS verification |
| Native BLS precompile | `0x2040` |
| Reverse operational safety | 2-of-2 aggregation with PausableISM |
| Relayer trust | Untrusted for message validity |
| Relayer authority | Destination transaction submission |
| User authority | Source transaction signing |
| Invalid verification | Fail closed |
| Consensus / Interchain relationship | Separate security domains |
| XGRChain → Base | Mainnet / public |
| Base → XGRChain | Mainnet / public |
| Public bridge | `https://bridge.xgr.network` |

The central XGR Interchain security principle is:

```text
validators authorize
proofs demonstrate
destinations verify
relayers deliver
users retain wallet authority
```

No single relayer is intended to replace validator quorum, message inclusion or destination verification.
