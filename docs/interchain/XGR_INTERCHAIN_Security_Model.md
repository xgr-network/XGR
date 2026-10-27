# Direct-BLS security model and wire format

[Documentation index](README.md). Implementation: `XITADirectProtocol.sol`, `XITADirectBLSISM.sol`, `XGRInterchainValidatorRegistryV3.sol`; node `consensus/ibft/interchain/xita_direct_message.go`, `interchain/runtime/iln_direct_signing.go` and `interchain/evm/` evidence readers.

## 1. Authorization model

An authorization concerns one original, fee-qualified Mailbox message. Validators do not sign caller-chosen arbitrary bytes through JSON-RPC. RPC requests, peer hints, source scans and website announcements are discovery inputs. The signing entry point independently verifies source evidence, destination state and signer eligibility.

The destination checks a quorum of its **current** Interchain validator set. Threshold is integer `(2*n+2)/3`, i.e. ceil(2n/3), with one vote per registered validator. This is distinct from stake-weighted IBFT chain consensus. A one-validator set is representable; protocol syntax alone is not evidence of operational decentralization.

## 2. Canonical Direct-BLS signing bytes

The exact domain is the **22 ASCII bytes** `XITA_DIRECT_MESSAGE_V1`. No zero terminator, length prefix or ABI dynamic-string wrapper is included. It is followed by fixed-width, big-endian fields in this exact order:

| Field | Bytes | Source |
| --- | ---: | --- |
| Domain literal | 22 | `XITA_DIRECT_MESSAGE_V1` |
| `sourceChainId` | 8 | Physical source EVM chain |
| `sourceDomain` | 4 | Source Mailbox domain |
| `destinationDomain` | 4 | Destination Mailbox domain |
| `routeId` | 32 | Original directed route |
| `setId` | 8 | Current destination validator epoch |
| `sourceBlockNumber` | 8 | Original source RPC/local canonical height |
| `sourceRegistry` | 20 | Canonical source route registry |
| `gateway` | 20 | Canonical source Gateway |
| `sourceRouter` | 20 | Dispatching router |
| `sourceMailbox` | 20 | Dispatching Mailbox |
| `destinationRouter` | 20 | Actual recipient router |
| `validatorFeeWei` | 32 | Positive fee of the original operation |
| `messageId` | 32 | Keccak-256 of exact original message bytes |
| `destinationIsm` | 20 | Actual destination verifier deployment |
| `destinationRegistry` | 20 | Actual destination validator registry |

The fixed-width tail is 268 bytes and the complete payload is 290 bytes. Verify these lengths against both codecs when implementing a client. There is no Merkle root, insertion index or replica prefix. Identity/amount requirements reject zero values where the protocol requires nonzero. Source and destination domains must differ.

The destination ISM and validator registry addresses are appended by the destination ISM's encoder using its own deployed bindings. They are part of the signed message even though they are not fields of the Solidity `Authorization` struct.

## 3. Metadata and message framing

The Solidity metadata is standard ABI encoding of one `Metadata` struct:

```solidity
struct Metadata {
  Authorization authorization;
  bytes signerBitmap;
  bytes aggregateSignature;
}
```

`Authorization` contains the fields above through `messageId`, excluding domain and the final ISM/registry addresses. Preserve the struct tuple layout; do not replace it with raw concatenation of signatures and payload. Use the repository codec rather than inventing an encoding.

The original Mailbox V3 message header is:

| Byte range (start inclusive/end exclusive) | Field |
| --- | --- |
| 0..1 | Version |
| 1..5 | Nonce |
| 5..9 | Origin domain |
| 9..41 | Sender as bytes32 |
| 41..45 | Destination domain |
| 45..77 | Recipient as bytes32 |
| 77..end | Application body |

ISM requires at least 77 bytes. It compares origin, destination, padded source router, padded destination router and the Keccak message hash with authorization. Mailbox processing and router application handling enforce their own framing and execution conditions as well. A malformed ABI metadata decode can revert; `verify` is not guaranteed to return `false` for every malformed byte string.

## 4. Bitmap and signature representations

Validators are in canonical Registry order. Do not sort addresses or keys before interpreting bits. Each selected validator counts once; out-of-range/noncanonical bitmap forms and insufficient quorum must be rejected by Registry verification.

The node archives compressed 96-byte aggregate signatures and 256-byte EIP-2537 signatures. Registry verifier format 1 selects compressed, format 2 EIP-2537. Compressed public keys are 48 bytes; the expanded EIP-2537 form is separately represented. Recovery selects the destination's actual format and verifies the matching signature; converting a hex length without mathematical conversion is invalid.

XGR uses its native BLS precompile at `0x2040`; the reviewed Base/Arbitrum deployments use their EIP-2537 verifier path. This is not evidence that any unconfigured EVM chain supports the same verification machinery.

## 5. Independent source evidence

Before signing, a validator requires:

1. Its local XGR node is synchronized, checked at signing entry and again before using the BLS key.
2. A configured source/destination and original nonzero source height/message ID.
3. A successful canonical source transaction receipt and matching block hash under that chain's accepted finality rule.
4. Matching original Gateway `ILNOperation` and Mailbox dispatch, same route/domain/message identity and positive fee.
5. Source Registry/Gateway/router/Mailbox bindings and the message's destination router are canonical.
6. The bound FeeVault has durably allocated that message to a nonzero fee-recipient epoch; event claims alone do not substitute for allocation checks.
7. The destination's actual ISM and configured validator registry agree, current membership is readable, and the message is not already delivered.
8. The local signer is eligible for the destination set and canonical XGR validator state.
9. A final set/delivery recheck passes before signing and the local vote is persisted before gossip.

XGR source verification reads the validator's own locally committed IBFT blocks/receipts/state. It does not rely on a public XGR RPC witness.

For Base/Arbitrum, node signing requires two matching **complete** evidence observations from distinct configured RPC operators. Every observation verifies the whole operation using one endpoint. The comparison includes canonical source block hash, transaction/log identity, source height, route/domain, fee, message bytes and route snapshot. Data from different providers is not spliced into a synthetic witness. Multiple URLs operated by one entity count as one witness.

This mitigates one malicious RPC operator; it does not eliminate collusion, incorrect shared operator attribution, compromised validators, rollup risks or underlying-chain failures. A recovery client that validates a receipt through one chosen RPC is not itself a replacement for validators' independent witness policy.

## 6. Finality

XGR uses locally committed canonical IBFT state. Base/Arbitrum use checked `safe` heads, matching numbered-block hashes and receipt inclusion below that boundary. Unsupported `safe`, inconsistent hashes or regressed heads are failures, not permission to switch silently to `latest` or a fixed number of confirmations.

Arbitrum source heights are RPC L2 heights. Solidity `block.number` can carry L1-origin semantics on an L2; deployment activation/backfill must use canonical receipt/RPC height, not blindly reuse that getter. `safe` policy is the implementation's accepted boundary; it must not be advertised as an unconditional L1-finality guarantee.

## 7. Destination route and replay checks

The ISM only accepts the current destination `setId`. It asks the actual destination router to validate the original source chain/domain/router and directed route ID against its own asset identity and reciprocal binding. This prevents treating a valid quorum for another asset/router pair as authority to release this escrow.

The Mailbox delivery map prevents processing the same original message twice. A different executor cannot redirect the recipient, change amount or create a new message ID from existing signatures. Set rotation requires fresh authorization for the same source message; it never requires a second source lock/burn.

A Registry's historical `verifyQuorum` capability is not a statement that the ISM accepts historical epochs. The ISM performs its own current-set check before invoking it.

## 8. Separate membership and fee domains

Source fee proposals use `XITA_SOURCE_FEE_V315`, binding source chain/domain, exact source Registry, current set, next nonce, expiry and positive fee. They authorize chain-wide fee changes, not route admission or arbitrary delivery.

Membership uses its own domain/payload. **Accepted residual PRE-S03:** membership transition signatures do not bind the exact destination Registry contract address. With matching chain/domain, set and keys, replay across separate Registry deployments may be possible. The reviewed policy requires one active receipt-pinned ValidatorRegistry per chain. Direct-message binding to destination ISM/Registry does not cryptographically fix membership replay. Reassess before operating multiple active Registries on one chain.

Possession proofs prevent accepting a candidate key merely from a claimed address; bootstrap/current-set validation still needs reviewed deployment and eligibility evidence. Membership reserves/reimbursements and validator fee claims are separate accounting systems.

## 9. Service independence and keys

| Actor/key | Can do | Cannot establish by itself |
| --- | --- | --- |
| User wallet | Approve and spend own source assets; submit delivery; claim own deferred native payout | BLS quorum or source finality |
| Validator BLS key | Sign eligible independently verified payloads | Unilaterally satisfy multi-member threshold |
| Destination executor | Pay gas and submit existing valid metadata/message | Alter recipient, principal or signed bindings |
| Commercial service wallet | Sign its optional EIP-712 price quotes, receive service fees, sponsor gas | Register company-only routes, mint arbitrarily or replace BLS authorization |
| Commercial recovery admin | Rotate service wallet/lifetime under that adapter's authority | Change public protocol Registry/ISM/router permissions |
| Indexer/GitHub/catalog | Discovery, deployment records and application listing | Canonical source receipt or cryptographic settlement |

Keep validator secrets, independent executor keys, commercial service key, recovery-admin key, database roles and GitHub writer tokens separate. Optional services are not protocol oracles. Technical roles support accurate descriptions of permissionless operation; they do not constitute a legal conclusion.

## 10. Settlement and recovery limits

Proof availability, broadcast, successful receipt, Mailbox delivery and recipient balance are distinct states. Native delivery may reserve a recipient claim instead of paying immediately. Insufficient unreserved native escrow reverts rather than recording an unbacked claim.

Keep original source receipt identity. Recovery depends on canonical receipt/log availability, live destination membership, valid routes and eligible quorum. A local attestation archive is useful evidence, but its existence alone proves neither current-set acceptance nor completed delivery. See [runtime retention](XGR_INTERCHAIN_Validator_Runtime.md) and [runbook](XGR_INTERCHAIN_v3.4.0_Operations.md).
