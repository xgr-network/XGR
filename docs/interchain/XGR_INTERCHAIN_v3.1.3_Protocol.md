# XGR Interchain v3.1.3 — Multi-Route Security and Contract Architecture

**Document ID:** XGR-INTERCHAIN-V3.1.3  
**Last updated:** 2026-10-07  
**Audience:** Protocol developers, contract developers, validator operators, relayer operators, integrators, auditors  
**Protocol status:** Normative v3.1.3 architecture  
**Node implementation:** `xgr-network/xgrchain`, branch `PoS_3`  
**Contract implementation:** `xgr-network/xgr-hyperlane`  
**Production note:** The currently deployed XGRChain ↔ Base bridge remains the v3.1.1 production baseline until the v3.1.3 contract stack is deployed and validated end-to-end.

---

## 1. Purpose

XGR Interchain v3.1.3 generalizes the original XGRChain ↔ Base bridge into a route-addressable Interchain security layer.

The protocol is intentionally split into three authority domains:

```text
XGRChain / validator nodes
    = security plane and quorum production

smart contracts
    = canonical route state, authorization enforcement,
      asset logic and settlement

relayers
    = untrusted transport and destination transaction submission
```

The node layer must not perform asset routing, custody, minting, burning, unlocking, liquidity management or application orchestration.

The relayer must not be trusted for correctness.

Security-critical and economic state transitions must be enforced by canonical source state, XGR Interchain validator quorum and destination smart contracts.

---

## 2. Canonical route identity

Every independent Interchain hop has a canonical route key:

```text
sourceChainId
+
sourceDomain
+
destinationDomain
+
routeId
```

where:

```text
routeId = bytes32, non-zero
```

`routeId` is deliberately generic. It is not defined as a token identifier.

This allows multiple independent routes between the same source and destination domains, including different assets, applications or settlement semantics.

Two routes that differ only by `routeId` are independent security and governance objects.

---

## 3. Destination-scoped validator membership

Interchain validator membership is scoped to a destination chain, not to an individual asset route.

Conceptually:

```text
XGR PoS validator identity
        │
        ├── active XGR staking identity
        └── matching BLS identity
                │
                ▼
destination-specific
Interchain validator registry
                │
                ▼
authorized signer for that destination
```

A validator that joins XGR Interchain for Base is entered once in the canonical Base destination validator registry.

That membership can secure multiple legitimate Base-bound routes.

The validator is not automatically authorized for Polygon, Arbitrum or any other destination. Each destination has its own membership decision.

Membership authority must remain singular:

```text
one canonical validator membership registry per destination chain
```

Other contracts may consume validator-set proofs, snapshots or commitments, but they must not create an independent writable membership authority for the same destination.

---

## 4. Shared contracts versus route-specific contracts

For an EVM destination such as Base, the target architecture is:

```text
BASE
│
├─ XGRInterchainValidatorRegistry   shared once for Base
├─ BLS Verifier                     shared once for Base
├─ ILN Registry                     shared once for all Base-hosted source routes
├─ generic ILN ISM                  shared where compatible
├─ Hyperlane Core                   shared infrastructure
│
├─ Route ABC
│    ├─ Warp Router / Token Adapter
│    └─ ILN Gateway
│
├─ Route XYZ
│    ├─ Warp Router / Token Adapter
│    └─ ILN Gateway
│
└─ Route XGR
     ├─ Warp Router / Token Adapter
     └─ ILN Gateway
```

The ILN Registry is not deployed once per token.

The validator registry and BLS verifier are not deployed once per route.

The normal route-local deployment unit is:

```text
route-specific Warp Router / Token Adapter
+
route-specific ILN Gateway
+
routeId registration in the shared ILN Registry
```

A generic destination ISM should be reused across routes whenever its immutable destination security context permits this safely.

---

## 5. Canonical ILN route record

The shared source-chain ILN Registry stores one record for:

```text
(destinationDomain, routeId)
```

The canonical route record contains:

```text
sourceChainId
sourceDomain
gateway
sourceRouter
mailbox
merkleTreeHook
destinationRouter
validatorFeeWei
enabled
```

The Registry also exposes route-scoped governance replay state:

```text
governanceNonce(destinationDomain, routeId)
```

The registry record is protocol truth for route configuration.

Validator nodes must re-read the exact historical registry state at the source block being attested rather than trusting relayer-supplied configuration.

---

## 6. Route-specific Gateway

Each route has a dedicated ILN Gateway bound to the route's canonical source-side execution context.

The Gateway must expose immutable or otherwise fail-closed bindings to:

```text
ILN Registry
Warp Router / source router
Mailbox
MerkleTreeHook
```

The Gateway does not replace the Warp Router as the Hyperlane sender.

Its security purpose is to make one concrete user operation fee-qualified and route-qualified.

For every accepted Interchain operation it emits:

```text
ILNOperation(
    bytes32 routeId,
    bytes32 messageId,
    uint32 destinationDomain,
    uint256 validatorFeeWei
)
```

Each event authorizes exactly one Hyperlane message ID.

A direct router call that bypasses the canonical Gateway must not become validator-authorized merely because its message appears in the Merkle tree.

---

## 7. Dedicated-message authorization

XGR Interchain validators do not sign a generic remote-chain checkpoint without operation context.

For v3.1.3, the validator quorum is bound to a specific authorized message and its canonical route.

The signed checkpoint payload includes:

```text
sourceChainId
sourceDomain
destinationDomain
routeId
setId
sourceBlockNumber
registry
gateway
sourceRouter
mailbox
merkleTreeHook
destinationRouter
validatorFeeWei
authorizedMessageId
root
index
```

The payload domain is:

```text
XGR_ILN_CHECKPOINT_V2
```

A valid quorum for one `routeId` or `authorizedMessageId` must not be reusable for another route or message.

---

## 8. Validator signing requirements

A validator may sign an ILN checkpoint only if all required conditions succeed.

At minimum:

1. the validator belongs to the Interchain validator set for the payload destination;
2. the validator remains an active XGR PoS validator;
3. the validator's XGR PoS BLS identity matches the destination Interchain registry identity;
4. the source block satisfies the configured confirmation policy;
5. the route exists at the exact historical source block;
6. the route is enabled;
7. the `routeId` and destination domain match;
8. the Gateway is bound to the canonical Registry, Warp Router, Mailbox and MerkleTreeHook;
9. an `ILNOperation` exists for the exact `authorizedMessageId`;
10. the operation fee equals the canonical route `validatorFeeWei`;
11. the checkpoint root and index match the canonical MerkleTreeHook state at that source block.

Any mismatch must fail closed.

---

## 9. XGRChain security-plane boundary

The XGRChain node is an Interchain security and quorum producer.

It may:

- observe confirmed canonical source state,
- validate route configuration,
- validate dedicated Gateway operations,
- validate validator eligibility,
- create BLS votes,
- aggregate the configured two-thirds quorum,
- persist completed attestations,
- expose completed attestations and governance quorums through read-only RPC.

It must not:

- lock or unlock bridged assets,
- mint or burn wrapped assets,
- choose application routes for users,
- perform DEX swaps,
- manage route liquidity,
- decide asset prices,
- act as a trusted bridge server,
- bypass destination smart-contract verification.

---

## 10. Untrusted and replaceable relayer

The relayer is untrusted for correctness.

The relayer may:

- observe canonical messages,
- retrieve completed validator quorums,
- reconstruct Merkle proofs,
- construct destination calldata,
- pay destination gas,
- call destination contracts.

The relayer must not have authority to determine:

- the canonical route,
- the route fee,
- the authorized message ID,
- the validator set,
- the signer bitmap,
- the aggregate signature,
- the transfer amount,
- the transfer recipient,
- the destination router,
- whether an invalid message should be accepted.

A compromised relayer may affect availability or waste its own gas.

A compromised relayer must not be able to cause unauthorized minting, unlocking or other settlement.

Multiple independent relayers may submit the same already-authorized message. Message replay protection and destination execution semantics must make repeated delivery harmless or rejected.

Correctness is enforced by:

```text
canonical source state
+
XGR validator quorum
+
destination smart contracts
```

not by relayer trust.

---

## 11. Destination smart-contract enforcement

Destination smart contracts are the final execution boundary.

Before asset execution, the destination security path must verify the evidence required by the route, including where applicable:

- origin and destination domains,
- route identity,
- authorized message identity,
- validator-set ID,
- historical validator set,
- signer bitmap,
- two-thirds quorum,
- BLS aggregate signature,
- Merkle message inclusion,
- destination router / recipient context,
- operational safety modules.

Only after successful destination verification may the route-specific Router or Adapter perform mint, unlock or another defined asset transition.

---

## 12. Route-specific validator fee

Validator fees are route-specific.

The canonical value is:

```text
ILNRegistry.getRoute(destinationDomain, routeId).validatorFeeWei
```

The fee is denominated in the source chain's native currency unless a future route type explicitly defines another model.

Principal and validator fee are separate economic values.

The Gateway operation fee must exactly equal the canonical fee in the Registry state used for the attestation.

A merely positive fee is insufficient.

---

## 13. Route governance

The following route mutations require Interchain validator governance quorum:

```text
ROUTE_ADD
FEE_UPDATE
ROUTE_ENABLE
ROUTE_DISABLE
```

The signed governance payload domain is:

```text
XGR_ILN_GOVERNANCE_V2
```

The payload binds:

```text
sourceChainId
sourceDomain
destinationDomain
routeId
registry
setId
nonce
validUntil
proposalType
route-specific mutation data
```

For a fee update, the new `validatorFeeWei` is part of the signed payload.

A quorum for one route must not authorize a mutation of another route.

---

## 14. Route-scoped governance nonce

Governance replay protection is route-scoped:

```text
governanceNonce(destinationDomain, routeId)
```

The normal proposer flow is:

```text
read confirmed current nonce from source ILN Registry
        │
        ▼
nextNonce = currentNonce + 1
        │
        ▼
construct governance proposal
```

For a previously unused route key:

```text
currentNonce = 0
first proposal nonce = 1
```

The CLI should derive the nonce automatically from confirmed source state.

An explicitly supplied nonce may be used only as an expected-value check and must be rejected when it differs from the confirmed next nonce.

After one proposal with nonce N is executed, another proposal with the same route and nonce N must fail.

Independent routes do not share a global governance nonce.

---

## 15. Governance quorum RPC

Completed governance quorums are read-only protocol evidence.

The canonical lookup is by `proposalId`, where:

```text
proposalId = keccak256(full signed governance payload)
```

The v3.1.3 RPC result exposes at minimum:

```text
version
proposalId
proposalType
sourceChainId
sourceDomain
destinationDomain
routeId
validatorFeeWei
registry
setId
nonce
validUntil
payload
signerBitmap
aggregateSignature
aggregateSignatureCompressed
```

The RPC must reject legacy governance quorum versions as v3.1.3 data.

RPC exposure does not execute governance.

---

## 16. Governance contract verification requirement

The source-chain ILN Registry must not trust the relayer, operator, validator or other caller when applying a governance quorum.

The caller is only an executor that transports an already-completed quorum from read-only XGR RPC into the source-chain contract.

Route governance is authorized by the canonical XGR Interchain ValidatorRegistryV2 deployed on the same chain as the ILN Registry whose state is being mutated.

For example:

```text
Base ILN Registry
    ↓
verifies quorum against
    ↓
Base ValidatorRegistryV2
```

The ILN Registry therefore verifies the signed governance payload, setId, signer bitmap and aggregate BLS signature directly against the local destination-scoped Interchain membership contract.

No remote validator-set mirror, trusted operator permission or second membership authority is required.

Transfer authorization remains destination-specific to the transfer destination. Route-governance authorization is local to the chain whose canonical route state is being changed.

The concrete contract implementation must preserve this authority boundary.

---

## 17. Validator membership lifecycle

A validator joins Interchain security for a destination, not for every individual route.

Therefore:

```text
validator joins Base
    → one Base destination membership entry

new ABC → Base route
    → no second validator membership registration

new XYZ → Base route
    → no third validator membership registration
```

The same validator must separately join another destination such as Polygon before signing Polygon-bound Interchain operations.

Historical validator sets must remain verifiable through `setId` snapshots where required.

---

## 18. Persistence and route isolation

Node persistence and aggregation state must preserve route separation.

At minimum:

- route configuration names must not alias the same canonical route identity;
- local vote files are content-addressed by signed payload hash;
- completed message attestations are stored by route and authorized message ID;
- governance proposals and quorums are stored by proposal ID;
- incompatible pre-v3.1.3 gossip payloads must not be accepted as v3.1.3 votes.

The v3.1.3 Interchain gossip protocol is isolated from incompatible prior payload generations.

---

## 19. Generic asset semantics

The validator protocol does not distinguish stablecoins, native coins, ERC-20s, gaming assets or other application-specific asset classes.

Those semantics belong to Router / Adapter contracts and route configuration.

Typical route modes include:

```text
native lock / wrapped mint
wrapped burn / native unlock
ERC-20 collateral lock / synthetic mint
synthetic burn / collateral unlock
issuer-authorized burn / mint
```

The security layer only authorizes the specific route operation defined by canonical contract state.

---

## 20. Failure model

The system must fail closed on at least:

- unknown or zero `routeId`,
- disabled route,
- route configuration mismatch,
- Gateway binding mismatch,
- missing dedicated `ILNOperation`,
- wrong `authorizedMessageId`,
- fee mismatch,
- unconfirmed source state,
- wrong destination,
- stale validator set,
- ineligible validator,
- mismatched BLS identity,
- insufficient quorum,
- invalid aggregate signature,
- invalid Merkle proof,
- wrong destination router,
- expired governance proposal,
- stale governance nonce,
- legacy incompatible payload version.

Availability failure must never be converted into authorization.

---

## 21. Clean v3.1.3 deployment boundary

v3.1.3 uses a clean contract generation and does not require backward-compatible security semantics inside the new contracts.

On destinations such as Base, the v3.1.3 security stack is deployed as a new generation built around:

```text
XGRInterchainValidatorRegistryV2-compatible membership
shared BLS verifier
shared ILN Registry
generic ILN ISM
route-specific ILN Gateways
route-specific Warp Routers / Token Adapters
```

Legacy v3.1.1 contract layouts, checkpoint domains and ISM metadata formats are not carried into the v3.1.3 contract interfaces.

The v3.1.1 deployment remains relevant only as historical production evidence and as the currently active route until cutover.

A v3.1.3 production cutover must occur only after:

1. v3.1.3 node tests pass;
2. v3.1.3 contracts pass unit and integration tests;
3. a controlled end-to-end route succeeds;
4. supply and settlement invariants are verified;
5. relayer replacement / recovery is tested;
6. production configuration is reviewed.

---

## 22. Normative architecture summary

```text
                   XGR SECURITY PLANE
             ┌─────────────────────────┐
             │ active XGR PoS identity │
             │ destination membership  │
             │ route validation        │
             │ message validation      │
             │ BLS vote + 2/3 quorum   │
             └────────────┬────────────┘
                          │
                    read-only quorum
                          │
                          ▼
SOURCE CHAIN        UNTRUSTED RELAYER       DESTINATION CHAIN
────────────        ─────────────────       ─────────────────
ILN Registry                                  Validator Registry
Route Gateway       message + proof +        BLS Verifier
Warp Router   ───►  quorum transport  ───►   generic ILN ISM
Mailbox/Hook                                  route Router/Adapter
     │                                              │
     └─ canonical source truth                     └─ final execution
```

The defining v3.1.3 rule is:

> XGRChain produces security decisions and quorum evidence; smart contracts enforce route and asset behavior; the relayer only transports already-authorized evidence.



---

## 23. Multi-asset deployment and repository model

v3.1.3 is designed so that chain-level security infrastructure is deployed once per physical chain and reused across many assets and routes.

The following components are chain-shared and MUST NOT be redeployed for every token unless a deliberate protocol upgrade requires a new generation:

```text
Hyperlane Mailbox / Core
MerkleTreeHook
BLS verifier
XGRInterchainValidatorRegistryV2
XGRILNRegistry
generic XGRILNInterchainISMV2
```

The normal incremental deployment unit for a new asset is therefore:

```text
asset-specific Warp Router / Token Adapter
+
route-specific ILNGateway
+
routeId registration in the shared ILN Registry
```

A new token onboarding MUST NOT require a fresh validator registry, BLS verifier or generic destination ISM merely because the asset is new.

### 23.1 Configuration versus deployment state

Repository configuration SHOULD distinguish desired configuration from observed deployment state.

Recommended logical structure:

```text
config/
├─ chains/
│  ├─ xgrchain.json
│  ├─ base.json
│  └─ ...
└─ assets/
   ├─ XGR/
   │  ├─ asset.json
   │  └─ routes.json
   └─ <ASSET>/
      ├─ asset.json
      └─ routes.json

deployments/
└─ <network>/
   ├─ infrastructure/
   │  ├─ xgrchain.json
   │  ├─ base.json
   │  └─ ...
   └─ assets/
      ├─ XGR.json
      └─ <ASSET>.json
```

`asset.json` SHOULD describe stable asset identity and semantics, including `assetId`, name, symbol, decimals, canonical chain, canonical token and synthetic representation metadata.

`routes.json` SHOULD describe desired route topology, including source chain, destination chain and route identity.

Generated deployment records SHOULD contain observed contract addresses, deployment transactions, route IDs and other chain-specific state. Generated addresses MUST NOT be treated as hand-maintained desired configuration.

### 23.2 Asset onboarding automation

The intended operational model is an idempotent deployment orchestrator:

```text
deploy-asset(asset, network)
    ↓
load chain-shared infrastructure
    ↓
verify existing contracts and canonical addresses
    ↓
deploy only missing asset-specific routers/adapters
    ↓
deploy only missing route gateways
    ↓
derive/check deterministic route IDs
    ↓
write deployment records
    ↓
produce governance proposals
    ↓
activate only after validator quorum
```

Running the same deployment command again SHOULD detect already-correct infrastructure and skip redundant deployments.

Automation MUST fail closed on configuration mismatches. Existing contracts may only be reused after their code, immutable bindings and required administrative controls have been verified against expected configuration.

### 23.3 Existing asset reuse

For an already deployed asset representation, a protocol upgrade SHOULD prefer reusing the existing token/router when doing so preserves supply, liquidity and address continuity without weakening security.

Security contracts may be replaced while asset contracts remain in place, provided the existing asset/router supports the required security-module transition and the cutover is explicitly verified.

This separation is intentional:

```text
asset continuity
!=
security-contract continuity
```

A legacy ISM, registry or aggregation module MAY remain deployed historically but MUST NOT remain authoritative after the route has been migrated to the new canonical v3.1.3 security path.

### 23.4 Productization boundary

The same manifest model is intended to support later self-service onboarding and white-label bridge tooling.

Partner-editable configuration may include branding and supported route selection, but security-critical values such as contract addresses, validator membership, canonical route IDs, security thresholds and mint/burn authority MUST remain derived from or verified against canonical deployment state.
