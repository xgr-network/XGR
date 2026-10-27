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



## 7. Executable wallet procedure

The following procedure prepares calls without a managed relayer, commercial signer, website or server-held user key. It assumes an already verified, reciprocally bound route. It is not a deployment wizard. Run the scripts from `runtime/native-relayer/` so they use that checkout's declared ethers dependency. Node.js must support ES modules and top-level await.

First export the verified route variables from section 3. Add `SOURCE_ACCOUNT` (your source wallet), `RECIPIENT` (destination EVM account) and `AMOUNT_RAW` (positive decimal integer in token base units). Obtain decimals from the actual token contract; native XGR uses 18. Do not place a seed or private key in these variables.

### 7.1 Prepare source quote and allowance calls

Save this block as `runtime/native-relayer/prepare-source.mjs` in your independent checkout. It only performs RPC reads and prints unsigned calls.

```javascript
import {
  Contract, JsonRpcProvider, Interface, getAddress, zeroPadValue,
  ZeroAddress, toQuantity
} from "ethers";
const need = name => {
  const value = process.env[name];
  if (!value) throw Error("Missing " + name);
  return value;
};
const eq = (a,b) => String(a).toLowerCase() === String(b).toLowerCase();
const sourceChain = BigInt(need("ORIGIN_CHAIN_ID"));
const destinationChain = BigInt(need("DESTINATION_CHAIN_ID"));
const domain = Number(need("DESTINATION_DOMAIN"));
const sourceDomain = Number(need("ORIGIN_DOMAIN"));
const routeId = need("ROUTE_ID");
const account = getAddress(need("SOURCE_ACCOUNT"));
const recipient = zeroPadValue(getAddress(need("RECIPIENT")), 32);
const raw = need("AMOUNT_RAW");
if (!/^[1-9][0-9]*$/.test(raw) || BigInt(raw) >= 2n**256n)
  throw Error("AMOUNT_RAW must be a positive uint256 decimal integer");
const amount = BigInt(raw);
const src = new JsonRpcProvider(need("ORIGIN_RPC_URL"));
const dst = new JsonRpcProvider(need("DESTINATION_RPC_URL"));
if (BigInt(await src.send("eth_chainId", [])) !== sourceChain ||
    BigInt(await dst.send("eth_chainId", [])) !== destinationChain)
  throw Error("RPC chain identity mismatch");
const gatewayAddress = getAddress(need("ORIGIN_ILN_GATEWAY"));
const gateway = new Contract(gatewayAddress, [
  "function ilnRegistry() view returns(address)",
  "function warpRouter() view returns(address)",
  "function warpToken() view returns(address)",
  "function routeId() view returns(bytes32)",
  "function destinationDomain() view returns(uint32)",
  "function quoteILN(uint32,bytes32,uint256) view returns(uint256,uint256,uint256,uint256)",
  "function bridge(uint32,bytes32,uint256) payable returns(bytes32)"
], src);
const registry = new Contract(need("ORIGIN_ILN_REGISTRY"), [
  "function getRoute(uint32,bytes32) view returns(uint64,uint32,address,address,address,address,address,uint256,bool)"
], src);
const r = await registry.getRoute(domain, routeId);
if (!r[8] || r[0] !== sourceChain || Number(r[1]) !== sourceDomain ||
    !eq(r[2], gatewayAddress) || !eq(r[3], need("ORIGIN_WARP_ROUTER")) ||
    !eq(r[4], need("ORIGIN_MAILBOX")) ||
    !eq(r[6], need("DESTINATION_WARP_ROUTER")) || r[7] <= 0n ||
    !eq(await gateway.ilnRegistry(), need("ORIGIN_ILN_REGISTRY")) ||
    !eq(await gateway.warpRouter(), r[3]) ||
    !eq(await gateway.routeId(), routeId) ||
    Number(await gateway.destinationDomain()) !== domain)
  throw Error("Canonical source binding mismatch");
const inbound = new Contract(need("DESTINATION_WARP_ROUTER"), [
  "function verifyInboundRoute(uint64,uint32,address,bytes32) view returns(bool)"
], dst);
if (!await inbound.verifyInboundRoute(sourceChain,sourceDomain,r[3],routeId))
  throw Error("Destination reciprocal route rejects source identity");
const q = await gateway.quoteILN(domain, recipient, amount);
const tokenAddress = await gateway.warpToken();
const approvals = [];
const call = (to,data,value=0n) => ({
  from:account, to, data, value:toQuantity(value), chainId:toQuantity(sourceChain)
});
if (tokenAddress !== ZeroAddress) {
  const token = new Contract(tokenAddress, [
    "function allowance(address,address) view returns(uint256)",
    "function balanceOf(address) view returns(uint256)",
    "function decimals() view returns(uint8)",
    "function approve(address,uint256) returns(bool)"
  ], src);
  if (await token.balanceOf(account) < q[3]) throw Error("Insufficient token balance");
  const allowed = await token.allowance(account,gatewayAddress);
  if (allowed < q[3]) {
    if (allowed !== 0n) approvals.push(call(tokenAddress,
      token.interface.encodeFunctionData("approve",[gatewayAddress,0n])));
    approvals.push(call(tokenAddress,
      token.interface.encodeFunctionData("approve",[gatewayAddress,q[3]])));
  }
  console.error("Token decimals:", String(await token.decimals()));
}
const bridge = call(gatewayAddress,
  gateway.interface.encodeFunctionData("bridge",[domain,recipient,amount]),q[2]);
console.log(JSON.stringify({
  sourceChainId:String(sourceChain), destinationChainId:String(destinationChain),
  routeId, account, recipient, amountRaw:raw,
  quote:{validatorFeeWei:String(q[0]),routerNativeValueWei:String(q[1]),
    totalNativeValueWei:String(q[2]),totalTokenAmount:String(q[3])},
  approvals, bridge
},null,2));
```

```sh
cd runtime/native-relayer
node prepare-source.mjs > source-call.json
```

Review the JSON: chain, account, Gateway, route, recipient, raw amount, token spender and native value. The printed calls omit nonce and fee policy for the wallet to populate. Native source balance must cover quoted value **and gas**. Approval transactions also consume gas.

### 7.2 Submit through your own EIP-1193 wallet

In a local interface you control with your wallet's injected provider, paste the reviewed JSON as `prepared`. This example uses `window.ethereum`; with several wallets select the intended provider explicitly. No import or company API is required.

```javascript
const provider = window.ethereum;
if (!provider) throw Error("Select an injected EIP-1193 wallet");
await provider.request({method:"eth_requestAccounts"});
async function sendReviewed(tx) {
  const connected = await provider.request({method:"eth_accounts"});
  if (!connected.some(a => a.toLowerCase() === tx.from.toLowerCase()))
    throw Error("Expected source/destination account is not connected");
  await provider.request({method:"wallet_switchEthereumChain",
    params:[{chainId:tx.chainId}]});
  const actual = await provider.request({method:"eth_chainId"});
  if (BigInt(actual) !== BigInt(tx.chainId)) throw Error("Wrong wallet chain");
  const estimate = await provider.request({method:"eth_estimateGas",params:[tx]});
  return provider.request({method:"eth_sendTransaction",
    params:[{...tx,gas:"0x"+(BigInt(estimate)*12n/10n).toString(16)}]});
}
```

If approvals are present, submit **one at a time**, waiting for each successful canonical receipt before the next:

```javascript
// Select only the next reviewed approval, then inspect its confirmed receipt.
const approvalHash = await sendReviewed(prepared.approvals[0]);
```

After all required approvals confirm, rerun source preparation, replace `prepared` with the fresh JSON and confirm `approvals` is empty. A nonzero residual approval is not proof of successful principal transfer. Requote immediately before source execution, then explicitly submit:

```javascript
const sourceTxHash = await sendReviewed(prepared.bridge);
```

Record that hash immediately. If the wallet reports timeout or loses its connection, inspect the original hash and account nonce; never submit another principal transfer merely because the UI did not receive a receipt. If a chain has not been added to your wallet, add it using independently verified chain metadata, then repeat the switch/check.

### 7.3 Extract original receipt identity and wait for finality

Export `SOURCE_TX_HASH` as that confirmed source hash. Save this as `runtime/native-relayer/read-source.mjs`:

```javascript
import {JsonRpcProvider,Interface} from "ethers";
import {verifiedSourceReceiptEvidence} from "./receipt-evidence.mjs";
import {verifySourceFinalityReceipt} from "./source-finality.mjs";
const env = name => {
  if (!process.env[name]) throw Error("Missing " + name);
  return process.env[name];
};
const rpc = new JsonRpcProvider(env("ORIGIN_RPC_URL"));
const txHash = env("SOURCE_TX_HASH").toLowerCase();
if (BigInt(await rpc.send("eth_chainId",[])) !== BigInt(env("ORIGIN_CHAIN_ID")))
  throw Error("Wrong source RPC chain");
const receipt = await rpc.getTransactionReceipt(txHash);
if (!receipt || receipt.status !== 1) throw Error("Original source is not successful");
const abi = new Interface([
  "event ILNOperation(bytes32 indexed routeId,bytes32 indexed messageId,uint32 indexed destinationDomain,uint256 validatorFeeWei)"
]);
const found = receipt.logs.filter(log =>
  log.address.toLowerCase() === env("ORIGIN_ILN_GATEWAY").toLowerCase())
  .map(log => {try {return abi.parseLog(log);} catch {return null;}})
  .filter(event => event && event.name === "ILNOperation" &&
    event.args.routeId.toLowerCase() === env("ROUTE_ID").toLowerCase() &&
    Number(event.args.destinationDomain) === Number(env("DESTINATION_DOMAIN")));
if (found.length !== 1) throw Error("Expected exactly one matching Gateway operation");
const messageId = found[0].args.messageId;
await verifySourceFinalityReceipt(rpc,Number(env("ORIGIN_CHAIN_ID")),receipt);
const evidence = verifiedSourceReceiptEvidence({
  receipt,sourceTxHash:txHash,routeId:env("ROUTE_ID"),messageId,
  destinationDomain:Number(env("DESTINATION_DOMAIN")),
  gateway:env("ORIGIN_ILN_GATEWAY"),sourceRouter:env("ORIGIN_WARP_ROUTER"),
  sourceMailbox:env("ORIGIN_MAILBOX"),destinationRouter:env("DESTINATION_WARP_ROUTER")
});
console.log(JSON.stringify({sourceTxHash:txHash,messageId,
  sourceBlockNumber:evidence.blockNumber,
  attestationRoute:`iln_${env("ORIGIN_DOMAIN")}_${env("DESTINATION_DOMAIN")}_${env("ROUTE_ID").slice(2).toLowerCase()}`
},null,2));
```

```sh
node read-source.mjs
```

If finality has not been reached, wait and repeat this read of the **same** source hash. Export the returned `MESSAGE_ID` and exact `ATTESTATION_ROUTE`. Quorum is requested by the recovery helper if no explicit-set archive is available. You may inspect progress using [RPC](XGR_INTERCHAIN_RPC.md), without giving the node a user wallet key.

### 7.4 Prepare destination and submit

From repository root:

```sh
node runtime/native-relayer/recover-iln.mjs "$MESSAGE_ID" > destination-call.json
```

For `PENDING`, retry the same message later. For a diagnostic failure inspect its named stage. For `ALREADY_DELIVERED`, verify existing recipient result. Only `READY_UNSIGNED_CALL` contains a submission candidate.

Paste the reviewed result as `ready` in your own wallet interface. Select the destination executor account; it may differ from the source wallet and does not become the asset recipient. Before calling, rerun preparation if time has passed or a validator epoch rotated.

```javascript
if (ready.status !== "READY_UNSIGNED_CALL") throw Error("No verified call ready");
const destinationAccounts = await provider.request({method:"eth_requestAccounts"});
const executor = destinationAccounts[0]; // Explicitly select your intended account.
const destinationTxHash = await sendReviewed({
  from:executor, to:ready.to, data:ready.data, value:ready.value,
  chainId:"0x"+BigInt(ready.destinationChainId).toString(16)
});
```

`sendReviewed` above rechecks connected accounts for each submission. If changing wallet providers, select the intended provider in your interface before submitting. Confirm the expected Mailbox address and message identity and keep the destination hash. The executor needs destination native gas. No new source approval or lock is part of this step.

### 7.5 Confirm destination and recipient result

Save as `runtime/native-relayer/read-destination.mjs`, exporting `DESTINATION_TX_HASH`:

```javascript
import {Contract,JsonRpcProvider} from "ethers";
const rpc = new JsonRpcProvider(process.env.DESTINATION_RPC_URL);
if (BigInt(await rpc.send("eth_chainId",[])) !== BigInt(process.env.DESTINATION_CHAIN_ID))
  throw Error("Wrong destination chain");
const receipt = await rpc.getTransactionReceipt(process.env.DESTINATION_TX_HASH);
if (!receipt || receipt.status !== 1) throw Error("Destination execution not confirmed successful");
const mailbox = new Contract(process.env.DESTINATION_MAILBOX,
  ["function delivered(bytes32) view returns(bool)"],rpc);
if (!await mailbox.delivered(process.env.MESSAGE_ID)) throw Error("Original message not delivered");
console.log("Message delivered; verify recipient token balance/Transfer logs or native claim next");
```

This receipt read proves included successful execution at the current RPC view. Apply the destination's accepted finality policy before reporting final settlement; Base/Arbitrum `safe` can lag inclusion. Recheck the receipt/block hash at that boundary. Verify mint/unlock amount and beneficiary separately. For native XGR inspect `NativeDeliveryDeferred`, `pendingNativeXGR` and `totalPendingNativeXGR`; only the beneficiary can withdraw a deferred payout to an alternate recipient.

### 7.6 Onward hop and restart

For Base → XGRChain → Arbitrum (or the reverse spoke journey), stop after first-hop recipient verification. Set the second route's source variables to XGRChain and destination variables to the target, quote its actual router/token, approve where needed and execute its new source call. Repeat receipt/quorum/recovery/delivery with a **new** message ID. Keep both identities together in your own records.

An optional service's `continueJourney` call is not a requirement for direct two-hop operation. A relayer, indexer, website or browser restart does not erase an original canonical dispatch. Recover using the original successful source hash and message ID; do not pay principal twice to reconstruct UI state.
