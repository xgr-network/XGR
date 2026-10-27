# Assets, routers and permissionless registration

[Documentation index](README.md). Authority: `XGRILNProtocol.sol`, `XETATokenFactoryV315.sol`, `XGRILNRegistryV315.sol`, `XETARouterCore.sol` and the three concrete guarded router contracts in public xgr-interchain.

## 1. Asset identity

All integers below use the ABI type widths shown, and addresses are EVM addresses. Asset ID is:

```solidity
keccak256(abi.encode(
  keccak256(bytes("XITA_ASSET_V315")),
  uint64(canonicalChainId), address(originalToken), uint8(kind)
))
```

Native assets use kind 0 and zero token address. ERC-20 uses kind 1 and nonzero token. Zero chain ID, inconsistent kind/token or another kind is rejected. Supported native router deployment is specifically native XGR on chain/domain 1643; the general identity helper is not a deployment adapter for every native currency.

Synthetic names, symbols and decimals are creation parameters, not proof of backing. Two representations with the same symbol can have different canonical identities or independent router escrows.

## 2. Directed route identity

```solidity
keccak256(abi.encode(
  keccak256(bytes("XITA_ROUTE_INSTANCE_V315")), bytes32(assetId),
  uint64(sourceChainId), uint32(sourceDomain),
  uint64(destinationChainId), uint32(destinationDomain),
  address(sourceRouter), address(destinationRouter)
))
```

This is standard `abi.encode`, not packed encoding. Reject zero IDs/routers, equal chains or domains, an inconsistent hub chain/domain pair, or a direction without XGRChain. Reverse IDs differ. Parallel router pairs differ. The route ID cannot be inferred from a ticker or two chain names alone.

The node's discovery/RPC label is `iln_<sourceDomain>_<destinationDomain>_<64 lowercase hex route ID without 0x>`. It is an operational label for that directed identity.

## 3. Deployment roles and supply

| Router | Source movement | Authenticated inbound action | Principal location |
| --- | --- | --- | --- |
| Guarded native XGR | Accept native principal | Pay recipient or reserve deferred payout | Native router balance, less reserved claims |
| Guarded collateral | Transfer underlying ERC-20 into escrow | Transfer underlying to recipient | That router's underlying-token balance |
| Guarded synthetic | Burn the transferred representation | Mint representation | Supply represents backing reachable through the bound routes |

Synthetic router supply starts at zero and its initializer is consumed in construction. Concrete router setup uses no permanently privileged owner. The internal outbound path is Gateway-guarded even when an upstream public `transferRemote` method exists.

A Factory-created synthetic on the hub can itself become the underlying of a separately created collateral router. The Factory reuses its remembered original Asset ID for that case. That onward topology **locks the hub representation** in collateral; it must not be described universally as a hub burn. A hub synthetic router used directly for onward dispatch burns its own tokens. Inspect the actual router/underlying pair to determine the accounting.

Independent collateral instances do not share an escrow merely because Asset IDs match. A valid message for a different router pair must not unlock this instance's collateral.

## 4. Prepare a router pair

1. Select already supported physical chains and verify their public Factory, source Registry, Mailbox, hook, ISM and validator registry using receipts and current code/bindings.
2. Establish the original chain/token identity. Read original decimals. Fee-on-transfer/deflationary collateral is explicitly unsupported; the collateral router checks exact incoming balance increase. Rebasing, blacklist, pause and upgrade semantics require separate token-specific assessment.
3. Deploy the correct router on each physical chain. Use your wallet, pay deployment gas and retain `RouterDeployed(assetId,router,creator)` and receipts. Both ends must represent the same intended asset.
4. Independently verify the remote contract/code and intended recipient token/metadata. Cross-chain remote addresses cannot be authenticated merely by checking local `code.length`.
5. Register each local directed route through its Factory from that source router's creator account. Repeat on the other chain for the reciprocal inbound binding.
6. Read both Registries and both routers. Recompute directed IDs, check Factory provenance, canonical Gateway immutable getters, remote enrollment and `verifyInboundRoute` before transferring principal.

Public Factory calls and exact signatures are in the [contract reference](XGR_INTERCHAIN_Contract_Reference.md). XITA listing/GitHub approval is unnecessary for these public calls. Anyone can create their own routers; they cannot bind someone else's created router or overwrite a registered destination binding.

## 5. Atomic route registration

`registerRoute(sourceRouter,destinationChainId,destinationDomain,destinationRouter,destinationToken)` requires that `routerCreator[sourceRouter]` is the caller and the asset is known to that Factory. It creates a route-specific Gateway with CREATE2 salt `keccak256(abi.encode("XITA_GATEWAY_V315",routeId))`.

Gateway construction also creates its bound FeeVault. Factory registration then appends the source Registry entry and bootstraps the router remote. The transaction reverts as a unit if any step fails. Registry writes are factory-only; this is enforcement of public canonical construction, not company-only admission.

Registered routes are immediately `enabled:true`. There is no subsequent route-admission BLS vote or mutable route-owner switch. The positive shared source fee must exist. Message signing still independently checks original evidence and destination reciprocal identity.

## 6. Cardinality and reciprocal authentication

`routeForDomainRegistered[sourceRouter][destinationDomain]` and `xetaRouteIdForDomain` enforce one immutable destination binding on a particular router. A hub router may bind Base and Arbitrum separately. Another router pair may create another route for the same asset and direction.

For inbound processing, the destination router reads its local reverse route's asset identity and expected remote chain/router. It recomputes the signed original directed route ID using those values and itself as destination. Matching a local reverse ID to an original forward ID directly would be incorrect; the IDs are directed.

A Factory registration event is therefore not sufficient proof of bilateral transfer readiness. A source can dispatch before a remote counterpart is ready; this can leave principal awaiting valid destination configuration/authorization. Verify reciprocity first.

## 7. Native XGR deferred payout

A native inbound transfer first checks unreserved escrow: `balance - totalPendingNativeXGR` must cover the new amount. If not, processing reverts. Existing pending claims cannot be spent by unrelated messages.

The router attempts recipient payment with 30,000 gas. If recipient code rejects it, it records `pendingNativeXGR[recipient]`, increases `totalPendingNativeXGR`, and emits `NativeDeliveryDeferred`. The authenticated message can be delivered while that native balance remains reserved in the router.

Only the original beneficiary can call:

```solidity
withdrawPendingNativeXGR(address payable payoutRecipient)
```

A nonzero alternate recipient can be selected by that beneficiary. The claim clears accounting before transfer and is reentrancy-guarded; a failed payout reverts. A relayer cannot withdraw someone else's pending balance. Confirm `PendingNativeXGRWithdrawn` and the receiving balance. Do not dispatch principal again to repair a deferred claim.

## 8. User transfer and recovery

Use public `ILNGateway.quoteILN` and `bridge`, approving the Gateway for ERC-20. The [independent runbook](XGR_INTERCHAIN_v3.4.0_Operations.md) supplies wallet examples, receipt extraction, quorum and unsigned destination delivery. This requires no commercial quote or company signing permission.

For spoke-to-spoke use, complete the first hop, inspect the hub token/router and actual available balance, then independently authorize hop two. Keep each source receipt/message ID and each fee separate. A reverse direction is also a separate source operation; it is not a refund of the first source fee.
