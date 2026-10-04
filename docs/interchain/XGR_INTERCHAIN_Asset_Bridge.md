# XGR Interchain — Asset Bridge

**Document ID:** XGR-INTERCHAIN-ASSET-BRIDGE  
**Last updated:** 2026-10-04  
**Audience:** Developers, integrators, wallet developers, exchange integrators, infrastructure operators, auditors  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Implementation status:** XGRChain ↔ Base asset bridge deployed and bidirectionally validated on mainnet  
**Interchain implementation:** `xgr-network/xgr-hyperlane`, branch `main`  
**XGRChain implementation:** `xgr-network/xgr-node`  
**Scope:** Native XGR and wXGR asset model, lock/mint and burn/unlock semantics, transfer lifecycle, supply relationship and integration requirements

---

## 1. Purpose

This document defines the XGR Interchain asset bridge model.

It explains:

- native XGR on XGRChain,
- wrapped XGR / wXGR on Base,
- the one-to-one asset representation model,
- XGRChain → Base lock/mint behavior,
- Base → XGRChain burn/unlock behavior,
- router responsibilities,
- transfer fees,
- supply accounting,
- wallet behavior,
- bridge versus exchange behavior,
- transfer lifecycle,
- public integration requirements.

The Interchain security model is documented separately in:

```text
docs/interchain/XGR_INTERCHAIN_Security_Model.md
```

Canonical deployed addresses are documented in:

```text
docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md
```

---

## 2. Asset model

The first XGR Interchain asset route connects:

```text
XGRChain ↔ Base
```

using:

```text
XGRChain: native XGR
Base:     wrapped XGR / wXGR
```

The relationship is implemented through:

```text
XGRChain → Base
lock XGR
mint wXGR
```

and:

```text
Base → XGRChain
burn wXGR
unlock XGR
```

The bridge therefore creates a wrapped representation of XGR on Base.

It does not create a second independent native XGR asset.

---

## 3. Native XGR

XGR is the native asset of XGRChain.

Mainnet identity:

| Field | Value |
| --- | --- |
| Network | XGRChain |
| Chain ID | `1643` |
| Interchain domain | `1643` |
| Native asset | XGR |
| Decimals | `18` |

Native XGR is part of the XGRChain protocol environment.

It is used for:

- transaction fees,
- account balances,
- staking,
- native transfers,
- application interactions,
- Interchain bridge transfers.

Native XGR does not require an ERC-20 token contract to exist as the chain's native asset.

---

## 4. Wrapped XGR / wXGR

wXGR is the wrapped representation of XGR on supported external networks.

For the current Base deployment:

| Field | Value |
| --- | --- |
| Network | Base |
| Chain ID | `8453` |
| Interchain domain | `8453` |
| Asset | wXGR |
| Decimals | `18` |
| Type | Synthetic wrapped representation of native XGR |

Official Base wXGR contract:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

The contract also acts as the Base synthetic asset router for the current XGR Interchain route.

---

## 5. Canonical asset identity

A token symbol alone is not sufficient asset identification.

The canonical identity of wXGR is:

```text
chain + contract address
```

For the current deployment:

```text
Base
Chain ID 8453
0x3b83687d77170d42feddfe221629cc21e771e021
```

Wallets, exchanges, DEX interfaces and integration software should use the chain and contract address together.

The symbol:

```text
wXGR
```

must not be treated as proof that a token is the official XGR representation.

---

## 6. One-to-one representation

The bridge asset model uses a nominal one-to-one relationship:

```text
1 XGR ↔ 1 wXGR
```

This relationship describes the bridge asset conversion.

It does not represent a market price.

For example:

```text
10,000 XGR
```

sent through the forward route results conceptually in:

```text
10,000 wXGR
```

before any separately charged transfer or routing fees.

Likewise:

```text
10,000 wXGR
```

sent through the reverse route results conceptually in:

```text
10,000 XGR
```

before applicable transfer costs.

---

## 7. Bridge conversion versus market value

The bridge conversion ratio and market price are separate concepts.

Bridge:

```text
1 XGR ↔ 1 wXGR
```

Market:

```text
wXGR ↔ USDC
wXGR ↔ ETH
XGR ↔ another traded asset
```

A DEX or centralized exchange may establish a market price for wXGR.

That price does not redefine the bridge conversion ratio.

Therefore:

```text
bridge representation ratio
≠
market exchange rate
```

---

## 8. Forward route

The forward asset direction is:

```text
XGRChain → Base
```

The user provides native XGR on XGRChain.

The bridge:

1. locks the native XGR,
2. dispatches the corresponding Interchain message,
3. validates the message through the XGR Interchain security path,
4. delivers the message on Base,
5. mints the corresponding amount of wXGR.

Conceptually:

```text
native XGR
    │
    │ lock
    ▼
XGR native router
    │
    ▼
Interchain message
    │
    ▼
security verification
    │
    ▼
Base synthetic router
    │
    │ mint
    ▼
wXGR
```

---

## 9. Forward custody model

During a forward transfer, native XGR is locked by the XGRChain native asset router.

The corresponding wXGR is then issued on Base after successful destination verification.

The bridge does not require an off-chain operator to manually send a corresponding token amount.

The asset transition is implemented by the deployed router contracts and authenticated Interchain message.

---

## 10. Forward supply effect

For a successful forward transfer of amount:

```text
A
```

the intended supply relationship is:

```text
locked native XGR += A
Base wXGR supply  += A
```

Conceptually:

```text
before:

locked XGR = L
wXGR supply = W

after forwarding A:

locked XGR = L + A
wXGR supply = W + A
```

This preserves the wrapped-asset backing relationship.

---

## 11. Reverse route

The reverse asset direction is:

```text
Base → XGRChain
```

The user provides wXGR on Base.

The bridge:

1. burns the wXGR,
2. dispatches the corresponding Interchain message,
3. waits for the configured Base confirmation policy,
4. validates the checkpoint through XGR Interchain validators,
5. processes the message on XGRChain,
6. unlocks the corresponding native XGR.

Conceptually:

```text
wXGR
    │
    │ burn
    ▼
Base synthetic router
    │
    ▼
Interchain message
    │
    ▼
security verification
    │
    ▼
XGR native router
    │
    │ unlock
    ▼
native XGR
```

---

## 12. Reverse supply effect

For a successful reverse transfer of amount:

```text
A
```

the intended supply relationship is:

```text
Base wXGR supply  -= A
locked native XGR -= A
```

Conceptually:

```text
before:

locked XGR = L
wXGR supply = W

after returning A:

locked XGR = L - A
wXGR supply = W - A
```

The burned wXGR therefore corresponds to the native XGR being released.

---

## 13. Backing relationship

For the current lock/mint asset route, the principal accounting relationship is:

```text
native XGR locked through the bridge
↔
wXGR issued through the bridge
```

Under normal operation:

```text
circulating bridge-issued wXGR
```

should correspond to:

```text
native XGR retained by the bridge route
```

subject to the exact deployed router accounting state and any supported in-flight transitions.

---

## 14. No liquidity pool required for redemption

The bridge does not depend on a market liquidity pool to convert between XGR and wXGR.

Forward conversion depends on:

```text
locking native XGR
+
authenticated destination mint
```

Reverse conversion depends on:

```text
burning wXGR
+
authenticated native XGR unlock
```

Therefore bridge redemption is structurally different from swapping wXGR through a DEX.

---

## 15. DEX liquidity is separate

A decentralized exchange may provide liquidity such as:

```text
wXGR / USDC
```

or:

```text
wXGR / ETH
```

That liquidity enables trading.

It does not provide bridge backing.

The distinction is:

```text
Bridge:
XGR ↔ wXGR

DEX:
wXGR ↔ market asset
```

A DEX price can move independently from the nominal one-to-one XGR/wXGR representation relationship.

---

## 16. Arbitrage relationship

When wXGR trades on a market, the bidirectional bridge can provide a mechanism through which market participants compare:

```text
wXGR market value
```

with:

```text
native XGR market value
```

The bridge itself does not guarantee market-price equality.

Price convergence depends on:

- bridge availability,
- transaction costs,
- market liquidity,
- external exchange access,
- participant behavior.

---

## 17. Native XGR router

The current XGRChain native asset router is:

```text
Network: XGRChain
Chain ID: 1643

0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

Its asset role is:

```text
forward: lock native XGR
reverse: unlock native XGR
```

The router participates in the authenticated Interchain transfer flow.

---

## 18. Base synthetic router

The current Base synthetic router is:

```text
Network: Base
Chain ID: 8453

0x3b83687d77170d42feddfe221629cc21e771e021
```

Its asset role is:

```text
forward: mint wXGR
reverse: burn wXGR
```

The same contract is the official Base wXGR token contract.

---

## 19. Router addresses are chain-specific

The same hexadecimal address may identify different contracts on different blockchains.

For example:

```text
0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93
```

is currently:

```text
XGRChain:
native XGR asset router
```

and on Base the same hexadecimal address is used by a different Interchain component.

Therefore integration software must never identify a bridge component by address alone.

Use:

```text
chain ID + address
```

---

## 20. Forward transfer lifecycle

A normal XGRChain → Base user transfer follows this lifecycle:

```text
1. user connects wallet
2. user selects XGRChain → Base
3. user enters XGR amount
4. bridge calculates transfer requirements
5. user signs XGRChain transaction
6. native XGR is locked
7. source Interchain message is dispatched
8. source message enters the canonical message tree
9. XGR Interchain validators attest the checkpoint
10. the required BLS quorum is reached
11. relayer reconstructs the message proof
12. relayer submits the proof to Base
13. Base verifies the Interchain proof
14. Base synthetic router mints wXGR
15. recipient receives wXGR
```

The user's wallet is required only for the user's source transaction.

---

## 21. Reverse transfer lifecycle

A normal Base → XGRChain user transfer follows this lifecycle:

```text
1. user connects wallet
2. user selects Base → XGRChain
3. user enters wXGR amount
4. bridge calculates transfer requirements
5. user signs Base transaction
6. wXGR is burned
7. Base Interchain message is dispatched
8. message enters the configured Base message tree
9. configured Base confirmation delay passes
10. XGR Interchain validators attest the confirmed checkpoint
11. the required BLS quorum is reached
12. relayer reconstructs the message proof
13. relayer submits the proof to XGRChain
14. XGRChain verifies the Interchain proof
15. XGR native router unlocks native XGR
16. recipient receives native XGR
```

---

## 22. Source transaction

Every asset transfer begins with a user-authorized source-chain transaction.

The user signs this transaction with the user's wallet.

For forward transfers:

```text
source = XGRChain
asset  = native XGR
```

For reverse transfers:

```text
source = Base
asset  = wXGR
```

The relayer does not sign the user's source transaction.

---

## 23. Recipient

By default, the recipient can be the same wallet address that initiated the transfer.

Because both current networks use EVM-style addresses, the same account address can exist on both networks.

A bridge interface may also support a different destination address.

Users must verify the destination address before signing the source transaction.

---

## 24. Recipient authority

The recipient address is encoded into the cross-chain transfer request.

After source confirmation, the normal Interchain processing path does not require a later manual recipient selection.

Changing the destination after the source transaction has been confirmed is therefore not part of the standard transfer lifecycle.

---

## 25. Wallet network selection

The wallet must sign on the source network.

For:

```text
XGRChain → Base
```

the wallet source network is:

```text
XGRChain
Chain ID 1643
```

For:

```text
Base → XGRChain
```

the wallet source network is:

```text
Base
Chain ID 8453
```

A user-facing bridge may request that the wallet switch to the appropriate source chain before transaction submission.

---

## 26. Source asset balance

The user must hold sufficient source asset balance.

Forward:

```text
required asset:
native XGR
```

Reverse:

```text
required asset:
wXGR
```

Where a route requires a separate native gas asset, the user must also hold enough of that network's native gas token to submit the source transaction.

---

## 27. Gas assets

XGRChain transaction gas is paid in:

```text
XGR
```

Base transaction gas is paid in:

```text
ETH
```

Therefore a Base → XGRChain transfer may require:

```text
wXGR
+
sufficient Base ETH for transaction gas
```

even though the transferred asset itself is wXGR.

---

## 28. Bridge transfer fees

The bridge can require fees associated with routing and destination processing.

The user-facing bridge should calculate the current route requirements before transaction submission.

A quoted transfer can contain:

- transferred asset amount,
- native routing fee,
- additional token-denominated fee where configured,
- total amount required from the source wallet.

Fee configuration is operational and may change independently from the nominal:

```text
1 XGR ↔ 1 wXGR
```

asset relationship.

---

## 29. Asset amount versus fees

The converted asset amount and fees must be distinguished.

Example conceptually:

```text
conversion amount: 100 XGR
routing fee:         separate
```

The asset representation remains:

```text
100 XGR → 100 wXGR
```

while the sender may need additional value to cover execution or route fees.

Therefore:

```text
bridge fee
≠
conversion exchange rate
```

---

## 30. Quote behavior

Before submission, the bridge can request a current quote from the source router.

The quote provides the currently required transfer cost for the selected:

- source network,
- destination network,
- recipient,
- amount.

A quote is an execution requirement.

It must not be interpreted as a guaranteed market price.

---

## 31. MAX behavior

A wallet interface offering a `MAX` action must account for source-network requirements.

For native-XGR transfers, using the entire native XGR balance can leave no balance available for source transaction gas or route costs.

A user interface may therefore reserve an amount for source-chain transaction execution.

For wrapped-token transfers on Base, the wXGR balance and ETH gas balance are separate.

---

## 32. Forward asset availability

A successful forward transfer requires at least:

- sufficient native XGR,
- source wallet authorization,
- source router enabled,
- destination router enabled,
- valid Interchain validator quorum,
- working destination verification,
- message delivery.

If a required condition is unavailable, the transfer should not be represented as available to the user.

---

## 33. Reverse asset availability

A successful reverse transfer requires at least:

- sufficient wXGR,
- sufficient Base ETH for transaction gas where required,
- source wallet authorization,
- Base router enabled,
- XGR router enabled,
- reverse Interchain validation,
- destination security policy open,
- message delivery.

The existence of the wXGR contract alone does not prove that reverse conversion is currently available.

---

## 34. Route gates

The deployed asset routers support directional operational controls.

Conceptually:

```text
outbound enabled
```

controls whether the router can initiate the relevant outbound route.

```text
inbound enabled
```

controls whether the router can accept the corresponding inbound route.

These controls are operational availability mechanisms.

They do not redefine the asset model.

---

## 35. Reverse pause control

The current Base → XGRChain route includes an additional destination safety control.

A paused required security module prevents reverse message delivery.

In that state:

```text
wXGR exists
```

and:

```text
reverse protocol is deployed
```

can both remain true while:

```text
reverse transfer currently unavailable
```

is also true.

---

## 36. Message delivery and asset delivery

Cross-chain transfer completion contains two distinct concepts:

```text
source transaction confirmed
```

and:

```text
destination asset delivered
```

A source transaction can be finalized before the destination transfer has completed.

A user interface should therefore represent cross-chain progress explicitly.

A simple user-facing model is:

```text
Sent
→
Verified
→
Received
```

---

## 37. Sent state

`Sent` means the source transaction has been confirmed and the cross-chain message has been created.

It does not yet mean that the destination asset has been received.

Forward:

```text
XGR has entered the bridge flow
```

Reverse:

```text
wXGR has entered the reverse bridge flow
```

---

## 38. Verified state

`Verified` means the required Interchain validation has progressed sufficiently for the message to be authenticated according to the route.

Internally this can include:

- checkpoint observation,
- validator attestations,
- BLS quorum,
- proof construction.

The user-facing interface does not need to expose every internal step.

---

## 39. Received state

`Received` means the destination Mailbox processing and asset transition have completed.

Forward:

```text
wXGR minted to recipient on Base
```

Reverse:

```text
native XGR unlocked to recipient on XGRChain
```

This is the asset-delivery completion state.

---

## 40. Browser history

A bridge interface may locally store recent:

- source transaction hashes,
- message IDs,
- route direction,
- amounts,
- recipient addresses,
- progress state.

Local browser history is a convenience layer.

It is not the source of truth for the transfer.

Canonical state remains on the relevant blockchains and Interchain infrastructure.

---

## 41. Closing the bridge interface

Closing the web page after a valid source transaction has been submitted does not cancel the on-chain transfer.

The transfer continues according to the deployed protocol and runtime infrastructure.

A returning user can reconstruct or monitor state using:

- source transaction,
- message ID,
- on-chain delivery state,
- locally stored bridge history where available.

---

## 42. User wallet custody

The bridge user retains control of the user's wallet signing credentials.

XGR.Network infrastructure does not require collection or storage of:

- user private keys,
- seed phrases,
- wallet signing credentials.

The user approves the source transaction through the user's wallet.

The bridge then processes the asset according to on-chain contracts and Interchain rules.

---

## 43. Locked assets

Forward native XGR is handled by the deployed XGRChain router contract.

The asset is not converted by transferring it into an ordinary user-controlled Base wallet operated by XGR.Network.

The corresponding cross-chain representation is produced according to the router and Interchain contract logic.

---

## 44. Mint authority

wXGR minting is coupled to authenticated inbound bridge processing.

A relayer transaction alone must not constitute arbitrary mint authority.

The destination message must satisfy the configured Interchain security policy before the router can perform the intended bridge mint operation.

---

## 45. Unlock authority

Native XGR unlocking is likewise coupled to authenticated inbound bridge processing.

The reverse relayer does not obtain unilateral authority to release arbitrary native XGR.

The destination message must pass the configured XGRChain security modules.

---

## 46. Supply invariant

The principal intended asset invariant is:

```text
bridge-issued wXGR
must correspond to
native XGR locked by the asset route
```

This invariant depends on:

- router implementation,
- authenticated message processing,
- correct mint/burn semantics,
- correct lock/unlock semantics.

It does not depend on DEX inventory.

---

## 47. Forward accounting example

Assume:

```text
locked native XGR before = 1,000,000 XGR
wXGR supply before       = 1,000,000 wXGR
```

A valid user bridges:

```text
100,000 XGR
```

After successful destination completion:

```text
locked native XGR = 1,100,000 XGR
wXGR supply       = 1,100,000 wXGR
```

The bridge representation remains corresponding.

---

## 48. Reverse accounting example

Assume:

```text
locked native XGR before = 1,100,000 XGR
wXGR supply before       = 1,100,000 wXGR
```

A valid user returns:

```text
100,000 wXGR
```

After successful reverse completion:

```text
locked native XGR = 1,000,000 XGR
wXGR supply       = 1,000,000 wXGR
```

The reverse operation removes the wrapped representation and releases the corresponding native asset.

---

## 49. In-flight transfers

A cross-chain transfer is not atomic across two independent chains in the same way as a single-chain transaction.

There can be a period in which:

```text
source action completed
```

while:

```text
destination action pending
```

This is normal cross-chain behavior.

Monitoring systems should distinguish completed source state from completed destination state.

---

## 50. Forward in-flight state

After the source XGR transaction succeeds but before Base delivery:

```text
native XGR may already be locked
```

while:

```text
corresponding wXGR is not yet delivered
```

The transfer remains in progress until destination processing succeeds.

---

## 51. Reverse in-flight state

After the Base source transaction succeeds but before XGRChain delivery:

```text
wXGR may already be burned
```

while:

```text
native XGR is not yet unlocked
```

The transfer remains in progress until destination processing succeeds.

This is why reverse reliability and monitoring are operationally important.

---

## 52. Relayer outage during an in-flight transfer

A relayer outage can delay a valid transfer after source confirmation.

It must not change the validity rules.

The expected security behavior is:

```text
valid message
+
temporary delivery outage
=
delayed transfer
```

not:

```text
weakened verification
```

Once valid delivery resumes, the authenticated message can continue through the destination path according to the deployed protocol.

---

## 53. Destination outage

A destination-chain or destination-RPC outage can likewise delay completion.

For example, a Base outage can delay:

```text
XGR → wXGR
```

delivery.

An XGRChain destination outage can delay:

```text
wXGR → XGR
```

delivery.

The source-chain transaction may already be final during such an outage.

---

## 54. Transfer cancellation

A transfer can be cancelled by the user only before the source transaction has been authorized and confirmed.

If the wallet confirmation is rejected before broadcast, no source transfer occurs.

After the source transaction has been confirmed, the cross-chain message exists and normal destination processing can proceed.

A user interface should not imply that a confirmed cross-chain source transaction can simply be undone by closing the page.

---

## 55. Wallet rejection

If the user rejects the wallet signing request:

```text
no source transaction
=
no bridge transfer
```

A user-facing application should present this as a normal cancellation rather than as a protocol failure.

---

## 56. Token approval behavior

Wrapped-token routes may require ERC-20 approval when the router needs permission to transfer an additional token-denominated fee or asset amount according to the deployed contract design.

Approval is separate from final transfer execution.

The wallet may therefore display more than one transaction where contract allowances are required.

The exact approval behavior must follow the current deployed router implementation.

---

## 57. Official wXGR discovery

The bridge interface should make the official wXGR contract address clearly visible.

For Base:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

This allows users to:

- add wXGR to a wallet,
- verify a token before trading,
- configure DEX liquidity,
- integrate the asset into applications,
- distinguish official wXGR from unrelated tokens using the same symbol.

---

## 58. Wallet token import

A wallet can identify official Base wXGR using:

```text
Network: Base
Chain ID: 8453
Contract: 0x3b83687d77170d42feddfe221629cc21e771e021
```

The token contract can expose standard token information required by compatible wallets.

Wallet presentation is implementation-specific and does not change the bridge asset model.

---

## 59. DEX integration

A DEX integration should use the official Base wXGR contract:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

A DEX pool involving wXGR is a market contract distinct from the bridge.

Examples:

```text
wXGR / USDC
wXGR / ETH
```

DEX pools do not mint bridge-backed wXGR.

Official bridge minting remains tied to authenticated XGR Interchain processing.

---

## 60. Creating wXGR for ecosystem liquidity

wXGR intended for normal ecosystem use should be created through the bridge route.

Conceptually:

```text
strategic native XGR
        │
        ▼
official XGR bridge
        │
        ▼
official wXGR
        │
        ▼
DEX / application liquidity
```

This preserves the same lock/mint relationship used for ordinary users.

---

## 61. Burning wXGR through the bridge

When wXGR is returned through the official reverse bridge route, it is burned as part of the reverse asset transition.

Sending wXGR to an arbitrary inaccessible address is not equivalent to using the authenticated reverse bridge flow.

The reverse bridge message is required to authorize corresponding native XGR unlocking.

---

## 62. Bridge is not a generic token wrapper

The current asset bridge is not merely a local wrapper contract on one chain.

It coordinates state across two independent networks.

Therefore:

```text
local wrap / unwrap
```

and:

```text
cross-chain XGR / wXGR conversion
```

are different operations.

The XGR Interchain route requires authenticated cross-chain delivery.

---

## 63. Bridge security dependency

The asset model depends on the Interchain security path.

Forward minting depends on successful validation of the XGR-origin message.

Reverse unlocking depends on successful validation of the Base-origin message.

Detailed validator, BLS, proof and destination-security behavior is defined in:

```text
docs/interchain/XGR_INTERCHAIN_Security_Model.md
```

---

## 64. Mainnet forward validation

The forward bridge has completed a controlled mainnet end-to-end transfer.

Validation amount:

```text
0.1 XGR
```

Source:

```text
XGRChain
```

Destination:

```text
Base
```

The validation demonstrated successful:

- native XGR locking,
- Interchain dispatch,
- validator attestation,
- proof delivery,
- Base verification,
- wXGR minting.

---

## 65. Mainnet reverse validation

The reverse bridge has completed a controlled mainnet end-to-end transfer.

Validation amount:

```text
0.01 wXGR
```

Source:

```text
Base
```

Destination:

```text
XGRChain
```

The validation demonstrated successful:

- wXGR burning,
- Base message dispatch,
- external checkpoint confirmation,
- XGR Interchain attestation,
- native XGRChain verification,
- native XGR unlocking.

---

## 66. End-to-end validation meaning

End-to-end validation demonstrates that the full asset path has executed successfully.

It does not by itself mean that:

- every route is permanently enabled,
- every relayer is always online,
- every RPC endpoint is always healthy,
- every future transfer is guaranteed to complete within a fixed time.

Operational availability is a live system property.

---

## 67. Public bridge availability

A public bridge should only allow submission when the required route conditions are available.

Relevant conditions can include:

- source network reachable,
- destination network reachable,
- source router enabled,
- destination router enabled,
- required safety module unpaused,
- relayer submission enabled,
- relayer process operational.

The UI should fail closed when these required conditions are not satisfied.

---

## 68. User-facing terminology

A user-facing bridge may describe the asset operation as:

```text
Convert XGR to wXGR
```

and:

```text
Convert wXGR to XGR
```

This terminology is intended to simplify the user experience.

The technical semantics remain:

```text
XGR → wXGR
lock / verify / mint
```

and:

```text
wXGR → XGR
burn / verify / unlock
```

---

## 69. Bridge branding versus protocol terminology

The public service can be presented as:

```text
XGR Bridge
```

while the primary user action is described as:

```text
Move XGR
```

or:

```text
Convert XGR to wXGR
```

This does not alter the underlying XGR Interchain protocol terminology.

Public user-interface wording and protocol documentation serve different audiences.

---

## 70. Integration requirements

An application integrating the asset bridge should know at minimum:

- source chain ID,
- destination chain ID,
- source router,
- destination router,
- source asset,
- destination asset,
- asset decimals,
- transfer amount,
- recipient,
- current fee quote,
- source transaction hash,
- Interchain message ID,
- destination completion state.

Applications should not hard-code assumptions about current availability based solely on deployment existence.

---

## 71. Chain IDs

Current chain IDs:

```text
XGRChain: 1643
Base:     8453
```

Current Interchain domains use the same numeric values:

```text
XGRChain domain: 1643
Base domain:     8453
```

Applications must distinguish chain identity explicitly.

---

## 72. Decimals

Native XGR uses:

```text
18 decimals
```

Current Base wXGR uses:

```text
18 decimals
```

This permits direct unit correspondence at the current asset precision.

Applications must still use integer base units for on-chain calls.

---

## 73. Amount encoding

Human-readable amounts must be converted to integer base units before contract interaction.

Conceptually:

```text
1 XGR
=
1 × 10^18 base units
```

and:

```text
1 wXGR
=
1 × 10^18 base units
```

Floating-point arithmetic should not be used for exact on-chain asset accounting.

---

## 74. Transaction evidence

A complete bridge transfer can produce several identifiers.

These may include:

- source transaction hash,
- Interchain message ID,
- checkpoint index,
- destination transaction hash.

The source transaction hash alone proves the source transaction occurred.

It does not by itself prove destination completion.

Destination completion must be verified independently.

---

## 75. Message ID

The Interchain message ID identifies the dispatched cross-chain message.

It can be used to correlate:

```text
source transaction
```

with:

```text
validator attestation
```

and:

```text
destination delivery
```

Monitoring infrastructure should retain this relationship where possible.

---

## 76. Destination completion

A bridge application can determine destination completion from destination-chain state.

A completed destination message indicates that the configured destination Mailbox accepted and processed the authenticated Interchain message.

For the asset route this is associated with the corresponding:

```text
mint
```

or:

```text
unlock
```

operation.

---

## 77. Explorer usage

Users and integrators can inspect chain transactions using the relevant network explorer.

XGRChain explorer:

```text
https://explorer.xgr.network
```

Base transactions and contracts can be inspected through compatible Base explorers such as BaseScan.

Explorer presentation does not replace direct chain-state verification for protocol integrations.

---

## 78. Contract verification

External integrations should verify that they are interacting with the intended deployed contract on the intended chain.

At minimum verify:

```text
chain ID
contract address
```

before:

- importing wXGR,
- creating a DEX pool,
- approving token spending,
- building bridge integrations.

---

## 79. Fake-token risk

Because token symbols are not unique, unrelated contracts can use:

```text
wXGR
```

as a symbol.

Users should therefore rely on the official Base contract address:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

and not on token name or symbol alone.

---

## 80. Unsupported networks

wXGR on one supported chain must not be assumed to exist on another chain at the same address.

Each future supported external network requires explicit deployment and documentation.

Therefore:

```text
wXGR on Base
```

does not imply:

```text
wXGR on Polygon
```

or any other network.

Each deployment must be identified independently.

---

## 81. Future network expansion

The asset model is designed to support additional external networks.

Conceptually:

```text
                   ┌── Base wXGR
                   │
native XGR ────────┼── future network wXGR
on XGRChain        │
                   └── future network wXGR
```

Each route requires its own:

- deployment,
- source/destination configuration,
- security configuration,
- operational validation.

A future route must not be treated as active merely because the architecture supports expansion.

---

## 82. Multi-network supply accounting

If wXGR is later issued on multiple external chains, supply accounting must distinguish:

```text
wXGR supply on Base
wXGR supply on Network B
wXGR supply on Network C
```

The aggregate wrapped supply relationship becomes conceptually:

```text
total bridge-backed wrapped XGR
=
sum of bridge-backed wXGR across supported networks
```

subject to the deployed routing model.

---

## 83. No automatic assumption across routes

A successful XGRChain ↔ Base deployment does not automatically validate:

- XGRChain ↔ Polygon,
- XGRChain ↔ Arbitrum,
- XGRChain ↔ another chain.

Each route must be separately:

- deployed,
- configured,
- security-validated,
- end-to-end tested,
- operationally enabled.

---

## 84. Source-of-truth boundaries

| Area | Primary source |
| --- | --- |
| Native XGR behavior | XGRChain node and canonical chain state |
| XGR Interchain asset contracts | `xgr-network/xgr-hyperlane` |
| Official deployment addresses | Interchain deployment manifests and live chain state |
| Public asset-bridge specification | `xgr-network/XGR/docs/interchain/` |
| Dynamic route availability | Live on-chain and runtime state |
| User-facing bridge | XGR Network bridge application |

Static documentation describes the intended and deployed asset model.

Live chain state remains authoritative for current balances, supply and route status.

---

## 85. Related documents

Overview:

```text
docs/interchain/XGR_INTERCHAIN_Overview.md
```

Security model:

```text
docs/interchain/XGR_INTERCHAIN_Security_Model.md
```

Deployment reference:

```text
docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md
```

XGRChain introduction:

```text
docs/chain/XGRCHAIN_Introduction.md
```

XGR Interchain implementation:

```text
https://github.com/xgr-network/xgr-hyperlane
```

---

## 86. Update triggers

This document must be reviewed when any of the following changes:

- native XGR router,
- official wXGR contract,
- supported destination networks,
- asset decimals,
- lock/mint semantics,
- burn/unlock semantics,
- transfer-fee model,
- router call interface,
- token approval requirements,
- bridge supply accounting,
- public transfer lifecycle,
- multi-network wrapped-asset model.

Purely cosmetic user-interface changes do not require a revision unless they change the represented asset semantics.

---

## 87. Asset bridge summary

| Topic | Current model |
| --- | --- |
| Native asset | XGR |
| Native network | XGRChain |
| XGRChain ID | `1643` |
| Wrapped asset | wXGR |
| Current wrapped network | Base |
| Base chain ID | `8453` |
| Decimals | `18` |
| Forward conversion | Lock XGR / mint wXGR |
| Reverse conversion | Burn wXGR / unlock XGR |
| Nominal representation | `1 XGR ↔ 1 wXGR` |
| Liquidity pool required for bridge redemption | No |
| DEX market price | Separate from bridge ratio |
| Official Base wXGR | `0x3b83687d77170d42feddfe221629cc21e771e021` |
| XGR native router | `0x202C10bDeCf3B796EA4B4025C81952C4F2DD9f93` |
| Forward route | Mainnet E2E validated |
| Reverse route | Mainnet E2E validated |

The core asset invariant is:

```text
native XGR is locked before corresponding wXGR is issued
```

and:

```text
wXGR is burned before corresponding native XGR is released
```

XGR Interchain therefore extends native XGR to supported external networks without redefining the underlying XGR asset or relying on market liquidity for bridge redemption.
