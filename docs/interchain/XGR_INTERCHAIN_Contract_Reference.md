# Public contracts, source fees and claims

[Documentation index](README.md). Signatures below describe the public implementation; use compiled ABI artifacts from the reviewed checkout for encoding structs and inherited methods. Values named wei are native smallest units unless explicitly a token amount.

## 1. Public Gateway

| Call | Result / effect |
| --- | --- |
| `quoteILN(uint32 destination,bytes32 recipient,uint256 amount)` | `(routeValidatorFeeWei,routerNativeValueWei,totalNativeValueWei,totalTokenAmount)`; checks current route, recipient/amount and fee-recipient availability |
| `bridge(uint32 destination,bytes32 recipient,uint256 amount) payable` | Returns original `bytes32 messageId`; exact quoted native value, ERC-20 allowance where applicable; principal/dispatch/fee allocation commit atomically |
| `ilnRegistry()`, `feeVault()`, `routeId()`, `destinationDomain()` | Immutable route identity and fee accounting contracts |
| `warpRouter()`, `warpToken()`, `nativeQuoteIncludesPrincipal()` | Underlying transfer path; zero token means native principal |
| `mailbox()`, `dispatchHook()`, `destinationRouter()`, `validatorFeeWei()` | Current canonical source Registry-derived bindings/fee |
| `activationBlock()` | Constructor's Solidity block height; use receipt RPC height for L2 backfill |
| `totalValidatorFeesEscrowedWei()` | Cumulative accounting counter; actual fee funds reside in the FeeVault |

`totalNativeValueWei = routeValidatorFeeWei + routerNativeValueWei`. Source transaction gas is additional. Never add native principal twice: respect the router quote and `nativeQuoteIncludesPrincipal`. ERC-20 `totalTokenAmount` is the amount passed to the Gateway, not a fiat value. `bridge` re-quotes; fee changes between quote and inclusion can revert exact-value validation.

ERC-20 principal is pulled from caller to Gateway, approved to the bound router where necessary, then transferred/burned through that router. Temporary router allowance is reset. Direct users approve the **public Gateway**; the optional commercial adapter has a separate allowance path.

`ILNOperation(bytes32 indexed routeId,bytes32 indexed messageId,uint32 indexed destinationDomain,uint256 validatorFeeWei)` is the source fee-qualified event. Extract it from the correct Gateway and correlate with the original Mailbox dispatch in the same successful receipt. A random event with that name is not proof.

Errors include `InvalidRoute`, `InvalidAmount`, `InvalidValue(expected,got)`, `UnsupportedWarpFee`, token transfer/approval failure, invalid message ID, `FeeRecipientsUnavailable` and reentrancy. Any such revert rolls back the source operation; inspect receipt status before deciding whether a transfer exists.

## 2. Factory deployment calls

| Call | Requirement / result |
| --- | --- |
| `deployRegistry()` | Idempotently returns the Factory's source Registry; deployment is public |
| `xgrAssetId()` | Canonical native-XGR Asset ID |
| `deployCollateralRouter(address originalToken,bytes32 salt)` | Existing local token contract; returns `(assetId,router)`; preserves remembered identity for a Factory-known synthetic underlying |
| `deploySyntheticRouter(uint64 originChainId,address originToken,uint8 decimals,string name,string symbol,bytes32 salt)` | Nonlocal nonzero original chain/token, decimals ≤18, nonempty name/symbol; returns `(assetId,router)` |
| `deployNativeXGRRouter(bytes32 salt)` | Only chain/domain 1643; returns native router |
| `deployWrappedXGRRouter(bytes32 salt)` | Only a non-hub physical chain; returns synthetic native-XGR representation |
| `registerRoute(address sourceRouter,uint64 destinationChainId,uint32 destinationDomain,address destinationRouter,address destinationToken)` | Caller created local router; valid hub topology and unused local destination binding; returns `(routeId,gateway)` |
| `assetIdForRouter(address)`, `representedAssetId(address)`, `routerCreator(address)` | Factory provenance and canonical asset lookup |
| `routeForDomainRegistered(address,uint32)` | Immutable per-router/domain registration status |

Creation salts bind caller, role, identity and role-specific parameters; arbitrary reuse is not an address guarantee. Router deployer contracts implement construction. Factory constructor binds chain, validator registry, transport and deployers and verifies transport consistency. It has no project approval list.

Events: `RegistryDeployed`, `RouterDeployed(assetId,router,creator)`, `RouteRegistered(routeId,router,gateway)`. Reject wrong chain/origin/configuration, unknown router, wrong creator, duplicate destination or invalid remote/topology. See [asset procedure](XGR_INTERCHAIN_Asset_Bridge.md).

## 3. Source Registry

`getRoute(uint32 destinationDomain,bytes32 routeId)` returns, in order:

```text
uint64 sourceChainId, uint32 sourceDomain, address gateway,
address sourceRouter, address mailbox, address dispatchHook,
address destinationRouter, uint256 validatorFeeWei, bool enabled
```

`assetRoute(domain,routeId)` returns `(bytes32 assetId,uint64 destinationChainId,address sourceToken,address destinationToken)`. `exists(domain,routeId)` distinguishes registered identity. Read `sourceChainId`, `sourceDomain`, `factory`, `governanceRegistry`, `validatorFeeWei` and `sourceFeeNonce` separately for provenance/governance.

`registerRouteInstance(...)` is Factory-only and append-only. Do not call it as an alternative user registration path. `RouteAdded` records the new directed entry. Registered entries are enabled immediately. Current `getRoute` returns the shared positive source fee; a historical event's fee need not equal today's fee.

## 4. Source-fee governance

`applySourceFee(SourceFeeProposalV315 proposal,bytes signerBitmap,bytes aggregateSignature)` can be executed by anyone holding valid quorum. Proposal fields are:

| Field | Solidity type |
| --- | --- |
| `sourceChainId` | uint64 |
| `sourceDomain` | uint32 |
| `registry` | address |
| `setId` | uint64 |
| `nonce` | uint64 |
| `validUntil` | uint64 Unix timestamp |
| `validatorFeeWei` | uint256, positive |

Canonical signing bytes are packed ASCII `XITA_SOURCE_FEE_V315`, then field widths 8,4,20,8,8,8,32 bytes. Source identity and exact Registry must match; set must be current; nonce must equal confirmed `sourceFeeNonce+1`; current time cannot exceed expiry. Invalid binding/quorum, stale nonce and expired proposals revert.

The initial fee is a positive Factory constructor input; nonce zero is bootstrap. Subsequent changes apply to **all routes of that source Registry**. Create/approve/execute are distinct CLI operations; unsigned creation does not silently approve. The node limits proposal TTL to a positive duration ≤10 minutes. See [CLI](XGR_INTERCHAIN_CLI.md).

## 5. FeeVault accounting and pull claims

Each Gateway creates a vault bound to source governance registry, Gateway, route and destination domain. Only that Gateway may allocate the positive native fee of a new nonzero message ID. Duplicate allocation is rejected. `allocatedOperation(messageId)` and `allocatedSetId(messageId)` provide durable original-operation evidence.

Allocation snapshots the current fee-recipient set ID/count. For epoch total `T` and count `n`, each canonical index receives `floor(T/n)` and the first `T mod n` indices receive one extra wei. Historical epoch membership determines entitlement even after membership changes.

| Call | Meaning |
| --- | --- |
| `claimable(address validator)` | Aggregate claimable fees; may traverse many epochs |
| `claimablePage(address validator,uint64 fromSetId,uint64 maxEpochs)` | Bounded read: `(amountWei,nextSetId,hasMore)`; positive bound and valid claim cursor |
| `claim()` | Claim using default bounded processing (32 epochs) |
| `claim(uint64 maxEpochs)` | Bounded claim; repeat until remaining epochs processed |

Claims update paid/cursor accounting before sending native currency and are reentrancy-guarded. A failed recipient transfer reverts. The vault's public accounting getters/events are specified by the [source API inventory](XGR_INTERCHAIN_Contract_API.md).

Protocol fees compensate source validator recipients. They are separate from a destination executor's gas, an optional commercial charge, membership deactivation reserves and user principal. They are not a refundable managed-relay performance bond.

## 6. Destination contracts

`XITADirectBLSISM.verify(bytes metadata,bytes message)` checks the exact original message, current set, recipient router's reverse binding and Registry quorum. `encodeAuthorization(Authorization)` produces canonical signing bytes bound to that deployed ISM/Registry. `registry`, `destinationDomain` and `moduleType` identify the verifier; custom module type is 0.

Validator Registry `getValidatorSet`, `getValidatorSetEIP2537` and `getValidatorSetForVerification` expose canonical order/key forms. `quorumThreshold()` is ceil(2n/3). `verifyQuorum(requestedSetId,payload,bitmap,signature)` verifies an epoch, while message ISM independently requires **current** epoch. Do not use historical Registry verification to bypass the ISM current-set rule.

`provePossession`, bootstrap encoding and `applyMembership` cover validator membership, not tokens. ADD locks a deactivation reserve; REMOVE requires zero `msg.value`, reimburses bounded executor costs from reserve, and credits the remainder under Registry rules. Successful transition increments `setId` and commits ordered membership. `claim()` withdraws Registry credits; it is separate from FeeVault claims.

The membership cross-Registry replay limitation and one-active-Registry invariant are explicit in the [security model](XGR_INTERCHAIN_Security_Model.md).

## 7. Router and native claim interfaces

`xetaRouteIdForDomain(domain)`, inherited `routers(domain)` and `verifyInboundRoute(sourceChain,sourceDomain,sourceRouter,signedRouteId)` expose binding validation. `bootstrapXETARoute` is a one-time canonical bootstrap and cannot replace an existing remote. Upstream ownership does not create a parallel permission to dispatch outside the internal Gateway guard.

Native `pendingNativeXGR(beneficiary)`, `totalPendingNativeXGR()` and `withdrawPendingNativeXGR(payoutRecipient)` describe deferred payout. Only the original beneficiary withdraws their claim; confirm claim completion separately from Mailbox delivery. See [native payout procedure](XGR_INTERCHAIN_Asset_Bridge.md).

## 8. Optional commercial adapter

`XITAExecutionGateway` is one source-chain adapter for paid interface service, distinct from the public per-route Gateway. `execute(Quote,signature)` requires caller equal quoted payer and a valid service-wallet EIP-712 quote, fresh issuance, unused payer nonce, correct route/amount and exact bridge value plus service fee.

The quote binds payer, Gateway, route, immediate/final destination and recipient, onward route, amount, bridge value, commercial fee, nonce and `issuedAt`. Lifetime is a live on-chain policy (1–90 seconds); there is no independently signed absolute deadline. EIP-712 domain is `XITA Interchain Fee`, version `1`, with chain and verifying contract binding.

The independent recovery admin can change quote lifetime or rotate `serviceWallet`; that wallet signs quotes, receives service fees and funds optional sponsorship. Rotation invalidates old signer quotes and directs accrued fees to the new wallet. Two-step ownership transfer remains separate; renunciation is disabled. Neither role controls public protocol asset admission, minting or BLS membership.

`continueJourney` links a wallet-authorized hub onward operation to its parent. It is optional; independent users can initiate the next public Gateway hop directly. `claimFees()` withdraws commercial fees under adapter rules. Service fees can be claimed before destination completion; this is operator trust, not an on-chain execution/refund guarantee. See [services](XGR_INTERCHAIN_Services.md).

## 9. API completeness and integration errors

The [generated declared contract surface](XGR_INTERCHAIN_Contract_API.md) lists every named public/external function, event and custom error in the repository's production Solidity files. It complements these semantic descriptions. Inherited library ABI and generated public-variable getters must be obtained from the pinned compiler artifacts; source signatures are not a substitute for ABI encoding.

Clients should decode reverts using the exact deployed ABI, preserve original transaction/receipt identity, re-read mutable fee/set/lifetime before signing, and check JSON-RPC errors separately from HTTP status. Never present a failed quote or unavailable state as a zero fee, empty validator set or successful delivery.
