# Declared production Solidity API inventory

[Documentation index](README.md). Generated from every production `contracts/*.sol` file, excluding test mocks. This is a declaration inventory, not a compiled ABI. Compiler-generated public-variable getters and inherited methods are additional ABI surface. Use pinned artifacts for byte encoding. [Behavior and failure semantics](XGR_INTERCHAIN_Contract_Reference.md).

## ILNGateway

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/ILNGateway.sol)

```solidity
function governanceRegistry() external view returns (IXGRInterchainValidatorSetV2);
function token() external view returns (address);
function quoteTransferRemote( uint32 destination, bytes32 recipient, uint256 amount ) external view returns (ILNQuote[] memory quotes);
function transferRemote( uint32 destination, bytes32 recipient, uint256 amount ) external payable returns (bytes32 messageId);
error InvalidConfiguration();
error InvalidRoute();
error InvalidAmount();
error InvalidValue(uint256 expected, uint256 got);
error UnsupportedWarpFee();
error TokenTransferFailed();
error TokenApprovalFailed();
error InvalidMessageId();
error ReentrantCall();
error FeeRecipientsUnavailable();
event ILNOperation( bytes32 indexed routeId, bytes32 indexed messageId, uint32 indexed destinationDomain, uint256 validatorFeeWei );
function mailbox() external view returns (address);
function dispatchHook() external view returns (address);
function destinationRouter() external view returns (address);
function validatorFeeWei() external view returns (uint256);
function quoteILN( uint32 requestedDestinationDomain, bytes32 recipient, uint256 amount ) external view returns ( uint256 routeValidatorFeeWei, uint256 routerNativeValueWei, uint256 totalNativeValueWei, uint256 totalTokenAmount );
function bridge( uint32 requestedDestinationDomain, bytes32 recipient, uint256 amount ) external payable nonReentrant returns (bytes32 messageId);
```

## IXGRILNRegistry

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/IXGRILNRegistry.sol)

```solidity
function getRoute(uint32 destinationDomain, bytes32 routeId) external view returns ( uint64 sourceChainId, uint32 sourceDomain, address gateway, address sourceRouter, address mailbox, address dispatchHook, address destinationRouter, uint256 validatorFeeWei, bool enabled );
```

## IXGRInterchainBLSVerifier

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/IXGRInterchainBLSVerifier.sol)

```solidity
function verify( bytes calldata message, bytes[] calldata publicKeys, bytes calldata signerBitmap, bytes calldata aggregateSignature ) external view returns (bool);
```

## IXGRInterchainValidatorSetV2

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/IXGRInterchainValidatorSetV2.sol)

```solidity
function originChainId() external view returns (uint64);
function setId() external view returns (uint64);
function destinationDomain() external view returns (uint32);
function verifier() external view returns (address);
function verifierKeyFormat() external view returns (uint8);
function getValidatorStatus(address validator) external view returns (bool active, uint64 setId);
function getFeeRecipients() external view returns (address[] memory validators, uint64 currentSetId);
function getFeeRecipientCountAndSetId() external view returns (uint256 count, uint64 currentSetId);
function getFeeRecipientIndexForSet(uint64 requestedSetId, address validator) external view returns (uint256 indexPlusOne, uint256 count);
function getValidatorSet() external view returns (address[] memory validators, bytes[] memory blsPublicKeys, uint64 setId);
function getValidatorSetForVerification() external view returns (address[] memory validators, bytes[] memory verificationKeys, uint64 setId);
function getValidatorSetForVerification(uint64 requestedSetId) external view returns (address[] memory validators, bytes[] memory verificationKeys, uint64 resolvedSetId);
function quorumThreshold() external view returns (uint256);
function validatorSetCommitment(uint64 setId) external view returns (bytes32);
function verifyQuorum( uint64 requestedSetId, bytes calldata payload, bytes calldata signerBitmap, bytes calldata aggregateSignature ) external view returns (bool);
```

## XETACollateralRouterDeployer

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETACollateralRouterDeployer.sol)

```solidity
function deploy(address token, address registry, address mailbox, address hook, address ism, uint256 gasLimit, bytes32 salt) external returns(address router);
```

## XETAGuardedCollateralWarpRouterV315

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETAGuardedCollateralWarpRouterV315.sol)

```solidity
error UnsupportedUnderlyingToken();
function token() public view override returns (address);
```

## XETAGuardedNativeWarpRouter

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETAGuardedNativeWarpRouter.sol)

```solidity
error NoPendingNativeXGR();
error InvalidPayoutRecipient();
error NativeClaimReentrancy();
error NativePayoutFailed();
error InsufficientUnreservedNativeXGR(uint256 requiredWei, uint256 availableWei);
event NativeDeliveryDeferred(address indexed recipient, uint256 amount);
event PendingNativeXGRWithdrawn(address indexed beneficiary, address indexed payoutRecipient, uint256 amount);
function withdrawPendingNativeXGR(address payable payoutRecipient) external;
function token() public pure override returns (address);
```

## XETAGuardedSyntheticWarpRouter

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETAGuardedSyntheticWarpRouter.sol)

```solidity
// No named external/public declarations; see library/internal construction source.
```

## XETANativeRouterDeployer

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETANativeRouterDeployer.sol)

```solidity
function deploy(address registry, address mailbox, address hook, address ism, uint256 gasLimit, bytes32 salt) external returns(address router);
```

## XETARouterCore

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETARouterCore.sol)

```solidity
function assetRoute(uint32 domain, bytes32 routeId) external view returns ( bytes32 assetId, uint64 remoteChainId, address sourceToken, address destinationToken);
function ilnRegistry() external view returns (IXGRILNRegistry);
function routeId() external view returns (bytes32);
function destinationDomain() external view returns (uint32);
function warpRouter() external view returns (address);
error XETAInvalidConfiguration();
error XETAInvalidRoute();
error XETAUnauthorizedGateway();
error XETAAlreadyInitialized();
error XETAInvalidGatewayBinding();
event XETARouteBootstrapped( uint32 indexed destinationDomain, bytes32 indexed routeId, address indexed gateway, address destinationRouter );
function bootstrapXETARoute(uint32 destination, bytes32 routeId) external;
function verifyInboundRoute( uint64 originChainId, uint32 originDomain, address originRouter, bytes32 signedOriginRouteId ) external view returns (bool);
```

## XETASyntheticRouterDeployer

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETASyntheticRouterDeployer.sol)

```solidity
function deploy(address registry, address mailbox, address hook, address ism, uint256 gasLimit, uint8 decimals, string calldata name, string calldata symbol, bytes32 salt) external returns(address router);
```

## XETATokenFactoryV315

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XETATokenFactoryV315.sol)

```solidity
function token() external view returns (address);
function bootstrapXETARoute(uint32 destinationDomain, bytes32 routeId) external;
error InvalidConfiguration();
error RegistryNotDeployed();
error InvalidOrigin();
error WrongChain();
error RouterUnauthorized();
error RouteAlreadyRegistered();
error InvalidDestination();
error InvalidRouteRegistration();
event RegistryDeployed(address indexed registry);
event RouterDeployed(bytes32 indexed assetId, address indexed router, address indexed creator);
event RouteRegistered(bytes32 indexed routeId, address indexed router, address indexed gateway);
function deployRegistry() external returns (address);
function xgrAssetId() public pure returns (bytes32);
function deployCollateralRouter(address originalToken, bytes32 salt_) external returns (bytes32 assetId, address router);
function deploySyntheticRouter( uint64 originChainId, address originToken, uint8 decimals_, string calldata name_, string calldata symbol_, bytes32 salt_ ) external returns (bytes32 assetId, address router);
function deployNativeXGRRouter(bytes32 salt_) external returns (address router);
function deployWrappedXGRRouter(bytes32 salt_) external returns (address router);
function registerRoute( address sourceRouter, uint64 destinationChainId, uint32 destinationDomain, address destinationRouter, address destinationToken ) external returns (bytes32 routeId, address gateway);
```

## XGRILNFeeVault

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XGRILNFeeVault.sol)

```solidity
error InvalidConfiguration();
error InvalidValidatorSet();
error InvalidOperation();
error InvalidClaimWindow();
error UnauthorizedGateway();
error NothingToClaim();
error TransferFailed();
error Reentrancy();
event FeeAllocated(bytes32 indexed messageId, uint64 indexed validatorSetId, uint256 amountWei);
event Claimed(address indexed validator, uint256 amountWei);
event ClaimAdvanced(address indexed validator, uint64 nextSetId, bool caughtUp);
function recipientCount() external view returns (uint256);
function recipientSetId() external view returns (uint64);
function allocate(bytes32 messageId) external payable;
function claimable(address validator) external view returns (uint256);
function claimablePage(address validator, uint64 from, uint64 maxEpochs) external view returns (uint256 amountWei, uint64 nextSetId, bool hasMore);
function claim() external;
function claim(uint64 maxEpochs) external;
```

## XGRILNProtocol

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XGRILNProtocol.sol)

```solidity
error InvalidRouteKey();
error InvalidGovernanceProposal();
```

## XGRILNRegistryV315

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XGRILNRegistryV315.sol)

```solidity
error InvalidConfiguration();
error InvalidRoute();
error UnauthorizedRegistrar();
error RouteAlreadyExists();
error InvalidFeeQuorum();
error ExpiredFeeProposal();
error InvalidFeeNonce();
event RouteAdded( uint32 indexed destinationDomain, bytes32 indexed routeId, address indexed gateway, address sourceRouter, address destinationRouter, uint256 validatorFeeWei, uint64 nonce );
event SourceFeeInitialized(uint256 validatorFeeWei, uint64 validatorSetId);
event SourceFeeUpdated(uint256 previousFeeWei, uint256 newFeeWei, uint64 indexed nonce, uint64 validatorSetId);
function applySourceFee( XGRILNProtocol.SourceFeeProposalV315 calldata proposal, bytes calldata signerBitmap, bytes calldata aggregateSignature ) external;
function registerRouteInstance( bytes32 assetId, uint64 destinationChainId, uint32 destinationDomain, address sourceToken, address destinationToken, address gateway, address sourceRouter, address mailbox, address dispatchHook, address destinationRouter ) external returns (bytes32 routeId);
function getRoute(uint32 destinationDomain, bytes32 routeId) external view returns ( uint64 routeSourceChainId, uint32 routeSourceDomain, address gateway, address sourceRouter, address mailbox, address dispatchHook, address destinationRouter, uint256 fee, bool enabled );
function assetRoute(uint32 destinationDomain, bytes32 routeId) external view returns (AssetRoute memory);
function exists(uint32 destinationDomain, bytes32 routeId) external view returns (bool);
```

## XGRInterchainBLSVerifier

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XGRInterchainBLSVerifier.sol)

```solidity
function verify( bytes calldata message, bytes[] calldata publicKeys, bytes calldata signerBitmap, bytes calldata aggregateSignature ) external view returns (bool);
```

## XGRInterchainValidatorRegistryV3

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XGRInterchainValidatorRegistryV3.sol)

```solidity
function registryVersion() external pure returns (uint256);
event PossessionVerified(address indexed validator, bytes32 indexed keyHash);
function provePossession( address validator, bytes calldata blsKey, bytes calldata blsKeyEIP2537, bytes calldata possessionProof ) external;
error InvalidBootstrap();
error InvalidTransition();
error StaleSetId(uint64 expected, uint64 got);
error InsufficientQuorum();
error InsufficientReserve(uint256 required, uint256 supplied);
error TransferFailed();
error NothingToClaim();
event ValidatorAdded(address indexed validator, uint64 indexed setId, uint256 reserveWei);
event ValidatorRemoved(address indexed validator, uint64 indexed setId, address indexed executor, uint256 reimbursementWei);
event ReserveIncreased(address indexed validator, uint256 amountWei, uint256 newReserveWei);
event Claimed(address indexed account, uint256 amountWei);
event ValidatorSetCommitted(uint64 indexed setId, bytes32 indexed commitment);
function claim() external;
function getValidatorStatus(address validator) external view returns (bool active, uint64 currentSetId);
function getValidator(address validator) external view returns (bool active, bytes memory blsPublicKey, uint256 reserveWei);
function getFeeRecipientCountAndSetId() external view returns (uint256 count, uint64 currentSetId);
function getFeeRecipientIndexForSet(uint64 requestedSetId, address validator) external view returns (uint256 indexPlusOne, uint256 count);
function getFeeRecipients() external view returns (address[] memory validators, uint64 currentSetId);
function getValidatorSet() external view returns (address[] memory validators, bytes[] memory blsPublicKeys, uint64 currentSetId);
function getValidatorSetEIP2537() external view returns (address[] memory validators, bytes[] memory blsPublicKeysEIP2537, uint64 currentSetId);
function getValidatorSetForVerification() external view returns (address[] memory validators, bytes[] memory verificationKeys, uint64 currentSetId);
function getValidatorSetForVerification(uint64 requestedSetId) external view returns (address[] memory validators, bytes[] memory verificationKeys, uint64 resolvedSetId);
function quorumThreshold() public view returns (uint256);
function verifyQuorum( uint64 requestedSetId, bytes calldata payload, bytes calldata signerBitmap, bytes calldata aggregateSignature ) external view returns (bool);
function applyMembership( MembershipTransition calldata transition, bytes calldata signerBitmap, bytes calldata aggregateSignature ) external payable;
function encodeMembershipPayload( uint64 originChainId_, uint32 destinationDomain_, uint64 expectedSetId, uint64 validUntil, uint8 action, address validator, bytes memory validatorBLSPublicKey, bytes memory validatorBLSPublicKeyEIP2537 ) public pure returns (bytes memory);
function encodeBootstrapPayload( uint64 originChainId_, uint32 destinationDomain_, address validator, bytes memory validatorBLSPublicKey, bytes memory validatorBLSPublicKeyEIP2537 ) public pure returns (bytes memory);
function computeValidatorSetCommitment( address[] calldata validators, bytes[] calldata blsPublicKeys ) external pure returns (bytes32 commitment);
```

## XITADirectBLSISM

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XITADirectBLSISM.sol)

```solidity
function verifyInboundRoute( uint64 sourceChainId, uint32 sourceDomain, address sourceRouter, bytes32 routeId ) external view returns (bool);
error InvalidConfiguration();
function moduleType() external pure returns (uint8);
function verify(bytes calldata metadata, bytes calldata message) external view returns (bool);
function encodeAuthorization(XITADirectProtocol.Authorization calldata a) external view returns (bytes memory);
```

## XITADirectProtocol

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XITADirectProtocol.sol)

```solidity
// No named external/public declarations; see library/internal construction source.
```

## XITADirectTransport

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XITADirectTransport.sol)

```solidity
function destinationDomain() external view returns (uint32);
error InvalidTransportConfiguration();
event TransportDeployed(address indexed mailbox, address indexed dispatchHook);
```

## XITAExecutionGateway

[Source](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/contracts/XITAExecutionGateway.sol)

```solidity
function ilnRegistry() external view returns (IXGRILNRegistry);
function routeId() external view returns (bytes32);
function destinationDomain() external view returns (uint32);
function warpToken() external view returns (address);
function quoteILN(uint32 destination, bytes32 recipient, uint256 amount) external view returns (uint256 validatorFeeWei, uint256 routerNativeWei, uint256 bridgeNativeWei, uint256 tokenAmount);
function bridge(uint32 destination, bytes32 recipient, uint256 amount) external payable returns (bytes32 messageId);
function relayerOwner() public view returns (address);
function interchainFeeRecipient() public view returns (address);
error InvalidConfiguration();
error UnauthorizedRelayer();
error InvalidQuote();
error InvalidSignature();
error QuoteExpired();
error InvalidQuoteLifetime();
error QuoteNonceUsed();
error InvalidBridgeValue();
error InvalidRegisteredRoute();
error InvalidTokenDebit();
error DuplicateMessageId();
error NoClaimableFee();
error NativePayoutFailed();
error ReentrantCall();
event InterchainFeeCharged( bytes32 indexed messageId, address indexed payer, address indexed gateway, bytes32 routeId, uint32 destinationDomain, bytes32 recipient, uint32 finalDestinationDomain, bytes32 finalRecipient, bytes32 onwardRouteId, uint256 amount, uint256 validatorFeeWei, uint256 bridgeNativeWei, uint256 interchainFeeWei, uint256 quoteNonce );
event InterchainFeeClaimed(address indexed beneficiary, uint256 amountWei);
event OnwardJourneyDispatched( bytes32 indexed parentMessageId, bytes32 indexed messageId, address indexed payer, bytes32 routeId, uint32 destinationDomain, bytes32 recipient, uint256 amount, uint256 validatorFeeWei, uint256 bridgeNativeWei );
event QuoteLifetimeUpdated(uint64 previousSeconds, uint64 newSeconds);
event ServiceWalletUpdated(address indexed previousWallet, address indexed newWallet);
function setServiceWallet(address payable nextWallet) external onlyOwner;
function renounceOwnership() public override onlyOwner;
function quoteDigest(Quote calldata q) external view returns (bytes32);
function setQuoteLifetimeSeconds(uint64 newSeconds) external;
function execute(Quote calldata q, bytes calldata signature) external payable nonReentrant returns (bytes32 messageId);
function continueJourney( bytes32 parentMessageId, address gatewayAddress, bytes32 expectedRouteId, uint32 destination, bytes32 recipient, uint256 amount ) external payable nonReentrant returns (bytes32 messageId);
function claimFees() external nonReentrant;
```
