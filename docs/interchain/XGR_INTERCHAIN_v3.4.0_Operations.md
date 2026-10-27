# XGR Interchain v3.4.0 — independent transfer and recovery

**Reviewed:** 2026-10-27. This runbook uses the public [xgr-interchain implementation](https://github.com/xgr-network/xgr-interchain), particularly `contracts/ILNGateway.sol` and `runtime/native-relayer/recover-iln.mjs`. Read the [technical reference](./XGR_INTERCHAIN_v3.4.0_Reference.md) for quorum, topology and trust assumptions.

## 1. Required resources and boundaries

Direct execution does not require the XITA website, its commercial Execution Gateway, sponsor or managed relayer. You need your own source wallet, source principal, allowances where applicable, native gas on each chain, the protocol source fee, working chain RPCs and a reachable XGR quorum RPC backed by eligible validators. The public helper prepares unsigned calldata; it cannot replace missing validator quorum.

Use the current verified deployment receipts under `deployments/chains/` and `deployments/assets/` in xgr-interchain. Match actual chain ID, source Registry/Gateway/router/Mailbox, destination router/Mailbox/ISM and current validator registry against on-chain state. A manifest's presence, token name or website listing is not sufficient evidence.

Every directed hop must have XGRChain (chain/domain 1643) at one endpoint. Base is 8453; Arbitrum is 42161. For a different spoke pair use two distinct hops via XGRChain.

## 2. Quote and execute the source hop

1. Verify the source Gateway's `ilnRegistry()`, `warpRouter()`, `warpToken()`, `routeId()` and `destinationDomain()` against the intended route. Verify the destination router's inbound binding and confirm the return route separately if needed.
2. Use the destination account encoded as the protocol's 32-byte recipient. Convert the amount to token base units using the token's decimals; never infer decimals from a symbol.
3. Call `quoteILN(destinationDomain, recipient, amount)` on the **public ILNGateway**. The return includes `validatorFeeWei`, `routerNativeValueWei`, `totalNativeValueWei` and `totalTokenAmount`. Check native principal inclusion for native XGR. For ERC-20, grant the necessary allowance to this Gateway, not to an unrelated commercial adapter.
4. With the source wallet call `bridge(destinationDomain, recipient, amount)` and exact quoted `msg.value`. Pay source transaction gas separately. Retain the successful original transaction hash and message ID from the matching `ILNOperation` and canonical Mailbox dispatch.
5. Wait for the accepted source finality boundary: committed XGRChain head or checked Base/Arbitrum `safe`. A pending source transaction is not a successful dispatch. Do not create a second lock/burn when delivery is delayed.

## 3. Prepare unsigned destination delivery

Install the helper's declared dependencies from the reviewed checkout:

```sh
cd runtime/native-relayer
npm install --ignore-scripts
cd ../..
```

Set the following variables from independently verified public state. These are **helper process** variables, not validator runtime configuration and not private keys.

| Variable | Meaning |
| --- | --- |
| `ORIGIN_CHAIN_ID`, `ORIGIN_DOMAIN` | Physical source chain and message domain |
| `DESTINATION_CHAIN_ID`, `DESTINATION_DOMAIN` | Destination chain and message domain |
| `ORIGIN_RPC_URL`, `DESTINATION_RPC_URL` | Correct-chain RPC endpoints |
| `ATTESTATION_RPC_URL` | XGRChain 1643 node exposing the public quorum methods |
| `ORIGIN_ILN_REGISTRY`, `ORIGIN_ILN_GATEWAY` | Canonical source Registry and Gateway |
| `ORIGIN_WARP_ROUTER`, `ORIGIN_MAILBOX` | Canonical source router and Mailbox |
| `DESTINATION_WARP_ROUTER`, `DESTINATION_MAILBOX` | Verified destination router and Mailbox |
| `DESTINATION_ILN_ISM` | Expected current destination message ISM |
| `ROUTE_ID` | Full nonzero directed bytes32 route ID |
| `ATTESTATION_ROUTE` | Exact dynamically discovered route name used by the node RPC |
| `SOURCE_TX_HASH` | Required original successful source transaction hash |

```sh
node runtime/native-relayer/recover-iln.mjs "$MESSAGE_ID"
```

The helper checks chain IDs (including XGRChain 1643 for quorum access), original receipt identity/status/finality, canonical source events, route/Gateway bindings, durable FeeVault allocation, destination current set and key format. It obtains the Direct-BLS attestation, compares its canonical signed payload and bindings, verifies the destination router, aggregate quorum and ISM, then simulates `Mailbox.process`. It rechecks set rotation and replay status before producing calldata. It does not require an Interchain Merkle hook, stored leaf prefix or historical source-state call.

The exact supported attestation version is `XITA_DIRECT_MESSAGE_V1`. An old checkpoint/Merkle payload is rejected. The destination registry selects compressed or uncompressed signature format; do not change formats manually.

## 4. Interpret the result and submit with your wallet

| Result | Action |
| --- | --- |
| `PENDING` | The helper requested quorum; retry the same message when eligible validators have responded |
| `ALREADY_DELIVERED` | Verify existing destination receipt/balance; do not broadcast another source operation |
| `READY_UNSIGNED_CALL` | Review `destinationChainId`, `to`, `data`, `value`, `setId` and `messageId` before signing |
| Nonzero exit / `RECOVERY_NOT_READY` | Read the diagnostic stage and resolve its source, route, fee, quorum or destination verification failure |

On `READY_UNSIGNED_CALL`, connect your independently controlled wallet to the **destination chain**, confirm the Mailbox address and recipient/message binding, recheck `delivered(messageId) == false` and current set ID, estimate gas, then sign and broadcast the emitted call. It invokes `Mailbox.process(metadata,message)`. No XITA/company signature is needed for this direct delivery. Any gas-paying executor can submit the same valid authorization; changing transaction sender does not change the authorized recipient.

After confirmation verify receipt success, `delivered(messageId) == true` and the expected mint/unlock/balance. A returned transaction hash alone is not settlement. If a set rotates before broadcast, prepare fresh authorization for the original message under the current set.

## 5. Two-hop journey

Complete delivery to XGRChain and verify the user's intermediate hub balance. Independently quote and execute the XGRChain → target Gateway operation, then repeat destination preparation and delivery for its new message ID. Maintain both source hashes and both message IDs. Approval of the hub synthetic token may be necessary.

The direct path does not assume the website's `continueJourney` linkage, commercial quote, indexer or sponsor. All source actions remain wallet-authorized. Recovery of an already dispatched hop must never create another principal transfer merely because an optional interface lost its local state.

## 6. Operator troubleshooting

- Relayer unavailable: use this unsigned path or an independently operated executor. Do not give another operator your wallet keys.
- Quorum unavailable: inspect `xgr_getILNIndexerStatus`, `xgr_getILNQuorum` and chain-specific validator errors; restore eligible validator observation/signing. Another relay cannot forge the missing authorization.
- RPC/finality unavailable or wrong chain: restore suitable canonical access. Do not substitute `latest` for unsupported `safe`.
- Destination set mismatch: re-attest the same source message; never reuse an ineligible historical set.
- Recipient execution or router failure: simulation must succeed before signing. Proof validity alone is not evidence that application execution can complete.
- Source receipt missing: obtain the original canonical transaction receipt/logs from suitable RPC infrastructure. A requirement for old receipt evidence does not imply a requirement for historical `eth_call`.

Node v3.4.0 obtains Interchain chain settings from its reviewed compiled `interchain/config.go`; new supported physical chains require a reviewed configuration/release rollout. No per-token validator environment edit is a permissionless registration prerequisite. Back up validator secrets and databases independently of relay/indexer services. Network consensus activation and data recovery follow the [node runbook](../chain/XGRCHAIN_v3.4.0_Release_and_Activation.md).
