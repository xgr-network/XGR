# XGR Interchain — Relayer, delivery, proof preparation and recovery

**Document:** XGR-INTERCHAIN-RELAYER-V323  
**Source verification:** 2026-10-23; [xgr-interchain main code](https://github.com/xgr-network/xgr-interchain/tree/4b73ca5be96d3ae073fdb019c8b1068b8c52a403), [xgr-node v3.2.3](https://github.com/xgr-network/xgr-node/tree/v3.2.3).  
**Scope:** relay trust model, running services, wallet authorization, protocol-independent direct delivery, the legacy relay clients, on-call operations, failure modes and acceptance tests.  
**Terminology:** The retired repository is **xgr-hyperlane**. The active implementation is **xgr-interchain**. The historical package name XETA in code, service names or paths does not imply that its older protocol behavior is current.

> **Do not deploy a send-capable legacy relayer merely because an example unit or shell script exists.** In the user-authorized XITA transfer model, all four bridge/delivery wallet transactions in a two-hop journey are sent from the user's wallet. Validator proof preparation, asynchronous read-only observation and optional native gas sponsorship are distinct activities. Current source code deliberately prevents the managed delivery executor from starting. The optional legacy native relayer has a separate send-mode switch; it is not the default product path.

---

## 1. Scope and trust model

A source-chain wallet operation locks original collateral or burns a wrapped representation and calls the permissionless protocol `ILNGateway.bridge`. The source `Mailbox` emits the original serialized message and the source `MerkleTreeHook` appends its hash. Eligible Interchain validators independently check the confirmed source chain, route, actual FeeVault allocation, ordered Merkle tree and destination validator set, then produce quorum BLS signatures. The destination `ISM` validates the proof when somebody submits `Mailbox.process(metadata,message)`.

**A relayer is not the proof authority.** Any address may submit a valid public destination message; it cannot rewrite the signed source message, mint arbitrary collateral, approve a source wallet's ERC-20, or bypass the current-set destination ISM. Its potential ability to **send a destination gas transaction** is distinct from its inability to **sign a user's source or onward asset transfer**.

For the XITA user-operated model, the wallet must sign each of these four source/destination TXs on an external-chain-to-external-chain journey:

1. TX 1 — initial source `XITAExecutionGateway.execute` (commercial) or direct `ILNGateway.bridge` (protocol), with wallet approval where needed.
2. TX 2 — first destination `Mailbox.process` on **XGRChain**, using prepared validator proof.
3. TX 3 — independently signed **XGRChain onward** `continueJourney` where available through the verified adapter, or direct `ILNGateway.bridge` in the permissionless path.
4. TX 4 — final destination `Mailbox.process` on the spoke.

**ERC-20 approval transactions can add wallet signatures** and are separate from the four bridge/delivery actions. Validator verification and off-chain proof preparation require no extra wallet signature. The two-hop UI exposes six logical stages: 4 wallet steps plus 2 validator-verification stages.

A direct spoke-to-spoke contract call skipping XGRChain is not supported. There is no automatic signature or settlement guarantee merely because a source lock is confirmed.

## 2. Component inventory — four different activities

| Actual code | Activity | Needs wallet private key? | Broadcasts destination TX? | Current role |
| --- | --- | --- | --- | --- |
| [xgr-node `interchain/runtime/`](https://github.com/xgr-network/xgr-node/tree/v3.2.3/interchain/runtime) | Validator quorum, route discovery, source-chain verification, P2P Merkle data | Validator-owned BLS credentials only | **No customer delivery** | Required security service |
| [`services/indexer/transfer-proof-observer.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/transfer-proof-observer.mjs) | Database-backed, persistent, read-only preparation/status of proofs | **No** | **No** | Current asynchronous proof worker |
| [`services/indexer/transfer-recovery.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/transfer-recovery.mjs) and [`runtime/native-relayer/recover-iln.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/runtime/native-relayer/recover-iln.mjs) | Validates canonical messages, queries quorum/Merkle, returns unsigned destination calldata | **No** | **No** | Current user/self-service recovery path |
| [`apps/web/transfer-actions.js`](https://github.com/xgr-network/xgr-interchain/blob/main/apps/web/transfer-actions.js) | Wallet preflight and `eth_sendTransaction` for source/onward/delivery, approval where required | User wallet handles signing | **User-owned** destination TX | Current interactive execution path |
| [`services/managed-relay/worker.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/managed-relay/worker.mjs) | Historical company-owned recipient gas execution | Would require operator TX key | **Disabled as executable service** | Non-current legacy implementation; do not start |
| [`runtime/native-relayer/iln.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/runtime/native-relayer/iln.mjs) | Standalone event scanner with optional observation or sending | Requires `RELAYER_PRIVATE_KEY` even in its current observe-only startup | Only if `RELAYER_SUBMIT=true` | Legacy/alternative tool, **not** standard XITA transfer path |
| [`services/managed-relay/gas-sponsor.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/managed-relay/gas-sponsor.mjs) | Optional, conditional native-gas top-up to customer wallet | Operator's **separate service wallet** | Sends **native grant only**, never customer's `Mailbox.process` | Optional financial support |
| [`services/indexer/transfer-index-worker.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/transfer-index-worker.mjs) | Finality-aware source operation and delivery-status indexing | No | No | Status/evidence, never settlement authority |

**Security property:** The live destination contract `Mailbox.delivered(messageId)` and a successful finalized destination receipt take priority over **every** relayer log, browser status or SQL row. `AVAILABLE_UNVERIFIED` from a local node quorum RPC is an archival observation, not settlement proof.

## 3. Runtime architecture and message lifecycle

```text
USER WALLET                         SOURCE CHAIN                   XGR NODE VALIDATORS
   | TX 1, self signed                   |                                |
   |----> Fee Adapter? / ILNGateway ---->| lock / burn + fee allocate     |
   |                                     | Mailbox.Dispatch               |
   |                                     | MerkleTreeHook insertion ------>| independently read
   |                                     |                                | confirmed root/count
   |                                     |                                | FeeVault, route, msg
   |                                     |                                | current dest set
   |                                     |                                | P2P leaf replication
   |                                     |                                | quorum + Merkle proof
   |                                     |                                |
   |<--- proof service: UNSIGNED process calldata (no TX, no service wallet signing)
   |                                     
   | TX 2, self signed ------------------> XGRChain Mailbox.process
   |                                       destination ISM verifies and mints/unlocks
   | TX 3, self signed ------------------> XGRChain onward ILNGateway
   |                                          Dispatch -> new quorum
   |<--- proof service: UNSIGNED final destination process calldata
   | TX 4, self signed ------------------> spoke destination Mailbox.process
   |                                          destination ISM verifies and mints/unlocks
```

Each hop has its own immutable `routeId`, source chain, Gateway operation, message ID, source TX and destination Mailbox. Wallet UI and indexer should link the two hops only through explicit authenticated parent/child evidence (e.g. adapter onward event), **never** merely equal token amounts, wallet balance changes or guessed chronological order. A separate source operation remains a separate risk/cost; do not hide orphan or ambiguous operations.

## 4. Source of authority at each boundary

| Boundary | Who decides? | Evidence |
| --- | --- | --- |
| Customer sends/burns/locks | Customer wallet and the source router/Gateway contract | Wallet-signed source TX + successful canonical source receipt |
| Protocol source fee | On-chain source Registry and immutable route FeeVault allocation | Source `ILNOperation`, FeeVault `allocatedOperation` + `allocatedSetId` |
| Message identity | Canonical source Mailbox | Exact `Dispatch(bytes message)` in **same source transaction** |
| Source Merkle inclusion | Source Hook; independently rehashed replica | `InsertedIntoTree`, confirmed root/count and 32-sibling proof |
| Message attestation | Current destination-specific Interchain validator quorum | Read-only `xgr_getILNQuorumAttestation`, BLS aggregate/bitmap |
| Can receive destination message? | Destination ISM, on-chain | `Mailbox.process.staticCall` before signing |
| Delivery finality | Destination Mailbox and finalized transaction receipt | `delivered(messageId)` and successful receipt |
| UI state and historical lookup | Finality-aware projections only | `xita_transfer_operations` + proof observer as read-only hints |

A server API must never elevate its own `PENDING` or `READY_UNSIGNED_CALL` status into authority to skip the destination ISM simulation or into `delivered=true`.

## 5. Canonical validator route naming

The current recovery layer derives a validator route name from the **on-chain source/destination domains and immutable route ID**:

```text
iln_<SOURCE_DOMAIN>_<DESTINATION_DOMAIN>_<64-lowercase-hex-route-id-without-0x>
```

For example, a verified XGRChain → Base route has the form `iln_1643_8453_<64hex>`. It is **not** the old aliases `xgr_to_base` or `base_to_xgr` from the legacy native relayer environment examples. The current identity function is [`ilnValidatorRouteName()`](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/transfer-recovery.mjs), and tests verify that it uses domains/routeId, not per-token environment aliases.

Route names alone do not establish legitimacy. Derive them from `deployedRoutes(catalog)`, and verify source/destination chain ID, Registry route, Gateway binding, token router, Mailbox and exact source receipt. The online node's own discovered route catalog is the second independent evidence source.

## 6. Current unsigned recovery and proof preparation

### 6.1 One-shot helper

Source: [`runtime/native-relayer/recover-iln.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/runtime/native-relayer/recover-iln.mjs). This is a **public one-shot verifier**, not the legacy permanent relayer loop. It requires Node.js and the `ethers` dependency from `runtime/native-relayer/package.json`.

It takes **one immutable message ID**:

```sh
# Run from a checkout of the version you have verified:
npm install --prefix runtime/native-relayer --omit=dev
# After setting verified ORIGIN_*, DESTINATION_*, ROUTE_ID,
# ATTESTATION_ROUTE, *_RPC_URL, and preferably SOURCE_TX_HASH:
node runtime/native-relayer/recover-iln.mjs 0x<EXACT_64_HEX_MESSAGE_ID>
```

Above is a *parameterized example*, **not a copy-paste executable for an arbitrary token**. Do not invent Gateway or token addresses. The user must supply an existing confirmed message and source transaction, not start a new lock/burn to make the helper work.

The script verifies `eth_chainId` for source and destination, and specifically chain **1643** for attestation. It checks destination `delivered` first. It reads current destination ISM registry `setId` and BLS format, obtains current-set BLS attestation or requests an idempotent public quorum, validates original successful source `ILNOperation` + `Mailbox.Dispatch` in the same transaction, checks the immutable FeeVault allocation, authenticates ordered Merkle siblings from the validator replica, constructs metadata and simulates `Mailbox.process`. Only then does it output a `READY_UNSIGNED_CALL` with `to`, `value: "0x0"` and `data`. It does not access any wallet key or broadcast any transaction.

Set `SOURCE_TX_HASH` where available. It allows the verified source receipt path without relying on large historical `eth_getLogs` scans. The fallback without a transaction hash may scan source Gateway events from activation block and therefore depends on provider historical-log support. **A failed historical query is not proof that a transfer failed**.

### 6.2 Canonical one-shot environment

All address fields below must come from verified live route records, current deployment receipts and the intended chain, not from old .env example placeholders.

| Variable | Interpretation |
| --- | --- |
| `ORIGIN_RPC_URL`, `DESTINATION_RPC_URL`, `ATTESTATION_RPC_URL` | Independently checked source/destination and node-quorum RPCs; attestation RPC resolves to XGRChain |
| `ORIGIN_CHAIN_ID`, `ORIGIN_DOMAIN` | Canonical physical source identity |
| `ORIGIN_ILN_REGISTRY`, `ORIGIN_ILN_GATEWAY`, `ORIGIN_WARP_ROUTER` | Current public source route and locked/burned asset router |
| `ORIGIN_MAILBOX`, `ORIGIN_MERKLE_TREE_HOOK` | Canonical source dispatch and Hook |
| `ROUTE_ID`, `ATTESTATION_ROUTE` | Exact directed route ID and validator RPC route name |
| `DESTINATION_CHAIN_ID`, `DESTINATION_DOMAIN` | Canonical physical destination identity |
| `DESTINATION_MAILBOX`, `DESTINATION_WARP_ROUTER`, `DESTINATION_ILN_ISM` | Destination verifier and token router |
| `SOURCE_TX_HASH` | Optional but recommended immutable source receipt hint |
| `ORIGIN_CONFIRMATIONS` | Source confirmation depth |
| `ORIGIN_LOG_CHUNK` | Bound on fallback source event batch size (1–1000) |
| `DESTINATION_AGGREGATION_MODULE_COUNT`, `DESTINATION_AGGREGATION_INNER_INDEX`, `DESTINATION_AGGREGATION_EMPTY_INDEXES` | Optional aggregation metadata envelope; only configure if actually deployed |

**Do not use** `RELAYER_PRIVATE_KEY`, `RELAYER_STATE_PATH` or `RELAYER_SUBMIT` with the one-shot recovery helper; they are settings for the older send-capable `iln.mjs` transport.

### 6.3 Outcomes

| Program output | Meaning / next action |
| --- | --- |
| `ALREADY_DELIVERED` | Destination Mailbox already processed this ID; verify target receipt/balance, do **not** send |
| `PENDING` | Public validator quorum hint accepted; rerun the same original message after independent verification |
| `FRESH_QUORUM_REQUIRED` | Previously observed quorum no longer matches destination `setId`; reattest original message |
| `READY_UNSIGNED_CALL` | Exact proof and current destination `process` simulation succeeded; validate current mailbox/set again immediately before signing |
| `RECOVERY_NOT_READY` (stderr diagnostic) | Proof preparation error; inspect sanitized stage/diagnostic and canonical source/validator state; never re-bridge as a first response |

The public host endpoint may additionally expose `PREPARING` (another proof request for the same key is in flight), rate limit 429 and categorized 503 failures. These are **not** on-chain statuses.

### 6.4 Customer-side send

A wallet may submit `Mailbox.process(metadata,message)` only on the **correct destination chain** using the unsigned `{to,data,value}` from the validated current proof. XITA's current browser code explicitly repeats source/wallet ownership checks, destination `delivered` reads, `eth_call`, gas estimate, account/chain check and nonce preflight before `eth_sendTransaction`. The user's wallet confirms the transaction; the recovery worker never signs it. Recheck final on-chain delivery afterwards.

## 7. XITA HTTP proof service

Source: [`services/indexer/server.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/server.mjs). Local indexer defaults to `127.0.0.1:4088`; the reverse proxy can publish selected GET endpoints under `https://xita.xgr.network`. Do not expose its PostgreSQL or internal admin traffic.

| HTTP interface | Purpose |
| --- | --- |
| `GET /health` | HTTP metrics/indexer health only, **not** validator quorum or completed transfer |
| `GET /api/xeta/v1/transfer/health` | Is one-shot proof helper and `ethers` dependency installed? **Not** proof readiness |
| `GET /api/xeta/v1/transfer/recovery?route=...&asset=...&messageId=...&sourceTxHash=...` | Rate-limited, source-route-bound **unsigned** recovery; no wallet signing/broadcast |
| `GET /api/xeta/v1/transfers/wallet?account=0x...&pending=1` | Finality-aware wallet transfer index and recovery/proof status |
| `GET /api/xeta/v1/transfers/stats` | Transfer-index statistics, not collateral TVL |
| `GET /api/xeta/v1/transfers/discovery?account=0x...` | Optional explorer-discovered transaction **candidates**, never authority |
| `POST /api/xeta/v1/rpc/read` | Bounded, read-only, catalog-selected RPC proxy; no arbitrary external RPC URL |

The recovery HTTP handler deduplicates an in-flight request by asset/route/message, enforces per-key cooldown, bounded concurrency and sanitizes error messages. The source transaction hash is **an untrusted locator**; the actual source receipt, route and fee are independently checked.

The helper's production RPC selection is in [`services/indexer/transfer-recovery.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/transfer-recovery.mjs): it resolves routes from deployed catalog data and prefers `XITA_RECOVERY_XGR_RPC_URL` on local `127.0.0.1` for validator proofs; optional `XITA_BASE_ARCHIVE_RPC_URLS` fallback applies only if Base is actually a source or destination. The Base failover retries connection/timeouts only, **not** invalid BLS, fee or route proofs. Old generic `ORIGIN_*` / static `ATTESTATION_ROUTE=xgr_to_base` configurations are not the current web proof-service path.

## 8. Persistent asynchronous proof observer

The background worker is [`services/indexer/transfer-proof-observer.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/transfer-proof-observer.mjs). It is intentionally **read-only with respect to chain state** and does not hold a source or destination signer. It processes a rebuildable SQL journal `xita_transfer_proof_observations` created by [migration 008](https://github.com/xgr-network/xgr-interchain/blob/main/services/indexer/sql/008_transfer_proof_observations.sql).

Only previously indexed, finalized source Gateway operations whose destination Mailbox is independently observed **not delivered** are candidates. A per-message lease and `FOR UPDATE SKIP LOCKED` prevent duplicated concurrent processing; crashes release leases later. At most two jobs are claimed per tick. The default loop interval is 15 seconds; backoff depends on `waiting`, `ready`, `delivery-observed` or `unavailable`. The DB record contains only **status, reason, stage, attempts, lease and times**: it is not a persisted BLS authorization, wallet intent, signed TX or proof of destination settlement.

### 8.1 Example service verification

```sh
sudo systemctl status xita-transfer-proof-observer.service --no-pager
sudo journalctl -u xita-transfer-proof-observer.service -n 80 --no-pager
curl -sS http://127.0.0.1:4088/api/xeta/v1/transfer/health | jq .
```

The checked-in installer example is `services/indexer/xita-transfer-proof-observer.service.example` and requires a functioning PostgreSQL writer credential and **SQL 008 already applied**. Missing table, DB permissions or source RPCs produce `unavailable`/retries, not permission to mark a transfer delivered or failed.

Example **read-only** diagnostic SQL (run with a controlled read-only DB account, no customer IP records):

```sql
SELECT source_chain,message_id,state,reason,stage,attempts,last_checked_at,next_check_at
FROM xita_transfer_proof_observations
ORDER BY next_check_at ASC LIMIT 30;
```

`state='ready'` means unsigned calldata was previously verified and can be revalidated on demand; it is **not** durable calldata or confirmed destination processing. Once the destination `Mailbox.delivered` becomes true, the indexer must independently observe the finality and then update the canonical operation.

### 8.2 Background validator checks vs wallet actions

The website may show a waiting state while the proof observer requests/quorum-checks the message without user interaction. After proof readiness, the **user** must still sign the destination transaction in MetaMask. When the browser is closed, read-only proof observation may continue; **no future user-wallet signature will be generated in the background**. A two-hop transfer is not complete until both target `Mailbox.delivered` states are separately confirmed.

## 9. Native relayer — retained alternative / legacy client

Source: [`runtime/native-relayer/iln.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/runtime/native-relayer/iln.mjs), managed by [`runtime/manage-relayers.sh`](https://github.com/xgr-network/xgr-interchain/blob/main/runtime/manage-relayers.sh).

This continuously running ILN client loads a **route-specific** environment, checks `ORIGIN_CHAIN_ID` / `ATTESTATION_CHAIN_ID` / `DESTINATION_CHAIN_ID`, scans confirmed `ILNOperation`/`Dispatch`/`InsertedIntoTree` events in bounded batches, maintains a local route state file, reads current-set attestation and builds BLS/Merkle metadata. It can check `Mailbox.process.staticCall` without submitting (observation) or, **only if `RELAYER_SUBMIT=true`**, sign and pay a destination `Mailbox.process` gas transaction with its configured relay wallet.

**Important implementation limitations:**

- The current script reads `RELAYER_PRIVATE_KEY` and initializes a wallet even when `RELAYER_SUBMIT=false`; it is *not* the recommended no-key proof observer.
- It can safely initialize an **empty** source Merkle Hook, but if the current Hook already contains leaves and no compatible verified state file exists, it **fails closed**. Never silently seed from an unverified RPC historical state root or invent a past prefix.
- It stores route-specific scan cursors, leaf nodes, message bytes and pending operations in `RELAYER_STATE_PATH`. Do not share the state path between route directions; never discard it casually while operations are pending.
- The `.env.relayer.iln.*.example` files still contain placeholders and old route aliases; **they are not production configurations or deployment evidence**. Their `ATTESTATION_ROUTE` value must not override the canonical v3.2.3 route naming.
- Sending a destination transaction here is technically permissionless but **contradicts the chosen four-user-signed-transaction XITA product mode**. Enabling it is an explicit architecture/policy change requiring review, not a normal operational fix.

The manager accepts:

```sh
# Purely inspect configured legacy processes; no start or signed TX:
bash runtime/manage-relayers.sh status all

# View a configured legacy route's logs:
bash runtime/manage-relayers.sh logs iln-xgr-to-base
```

It also has `start|stop|restart` actions, but these are **not recommended for current XITA execution**. Keep historical examples for audit/recovery interpretation only. A service that prints `native_iln_relayer_started` confirms a script is running; **it does not prove destination delivery**.

The observation log event `iln_relay_ready_observe_only` means `process.staticCall` succeeded at that point, not that a wallet actually executed it. `iln_relay_submitted` is a send-capable legacy action and still needs transaction receipt + `delivered` verification. The script's compaction path is deliberately disabled to avoid unreliable historical Hook state queries.

## 10. Managed relay — disabled operator executor

The historical implementation [`services/managed-relay/worker.mjs`](https://github.com/xgr-network/xgr-interchain/blob/main/services/managed-relay/worker.mjs) retains helper functions for scanning only its own commercial `XITAExecutionGateway` emitter, checking source receipts, fee records and building/persisting gas transactions. However, **when invoked as a process**, before the loop it unconditionally throws:

```text
Managed delivery executor disabled: all four transfer transactions must be user-authorized.
```

Accordingly, `services/managed-relay/xita-managed-relayer.service.example` is **not** a current production runbook; enabling it would produce restart failures. Although some internal test helpers and on-disk schemas still exist, one cannot infer an active company-sponsored destination-signing path from their presence.

This restriction does **not** disable the separate `server.mjs` commercial **fee quote** service, the separate `gas-sponsor.mjs` native grant worker, the transfer indexer or proof observer. These have different executable entrypoints and permissions.

**Non-custody precision:** A public third-party executor submitting `Mailbox.process` signs and pays **its own delivery transaction**, not the customer's source or onward burn/lock. The current XITA product deliberately requires that same destination process step to be signed through the user's wallet. Neither model gives an executor authority to spend a user's original assets without the authenticated source transfer.

## 11. Commercial Execution Gateway and gas sponsor are not relay authorities

`XITAExecutionGateway` is an optional on-chain fee/continuation adapter. The quote endpoint `services/managed-relay/server.mjs` may sign an EIP-712 commercial quote. **That signature is a price authorization, not a signature of a customer's wallet transaction**. The frontend checks the actual deployed adapter, route, signed quote, destination gas readiness and user wallet chain/account before requesting source execution.

The separate `gas-sponsor.mjs` chooses only verified, eligible **native-currency** grants for three stages: `first-delivery`, `hub-onward`, `final-delivery`. It is disabled unless `XITA_INTERCHAIN_SPONSOR_ENABLED=true` and configured budgets, available native reserves and DB journaling conditions hold. Its on-chain output is a direct transfer of native coins **to the user wallet** and is not `Mailbox.process`, `ILNGateway.bridge` or any authorization of customer's token holdings.

The public `/api/xita/v1/managed/health` endpoint reports chain-specific sponsorship availability only from fresh checked monitor rows and correct service address. `available=false` or a green health response alone is not a funded user wallet. The customer must independently see a real grant or maintain enough native gas.

## 12. Operational incident handling

| Symptom | Evidence to inspect | Safe response |
| --- | --- | --- |
| Source TX appears mined, proof unavailable | Source receipt + `ILNOperation`/same-tx `Dispatch`; `xgr_getILNQuorum` | Do not resubmit source. Wait/repair validator proof service; preserve exact message ID |
| `PENDING` | Source confirmation depth, fee allocation, current destination set, worker heartbeat | Request/retry **the same** quorum; inspect verified node readiness |
| `PROOF_RPC_METHOD_UNAVAILABLE` | XGR node runtime tag, `xgr_requestILNQuorum` availability | Wrong/old node binary or provider; use proper v3.2.3 endpoint; no user signing until corrected |
| `PROOF_RPC_UNAVAILABLE` / timeout | Source/destination/attestation RPC chain IDs, status, 403/429/503 | Select another **verified** operator-approved RPC; do not weaken cryptographic checks |
| `PROOF_RECONSTRUCTION_UNAVAILABLE` | `xgr_getILNIndexerStatus` `localLeaves`/`lagLeaves`, Hook root, P2P donor replicas | Verify complete source-anchored replica; if all peers missing, controlled `init-merkle --dry-run` and backup |
| `FRESH_QUORUM_REQUIRED` | Destination Registry `setId`, earlier quorum set | Renew validator attestations for original message |
| `READY_UNSIGNED_CALL` but wallet rejects | Current chain/account, `Mailbox.delivered`, destination `eth_call`, fee/gas/nonce | Re-run proof preflight; no new source lock/burn |
| Destination TX mined but UI says pending | Finalized destination receipt and `Mailbox.delivered(messageId)`, indexer lag | Reconcile read-only index, restore correct journey status; never infer failure from stale UI |
| UI shows two pending items for a two-hop journey | Verified parentMessageId/child linkage, `xita_transfer_operations` | Reconcile source-derived parent-child evidence; do not merge by token amount or time |
| Native relay state path mismatch | `routeId`, chain/domain, version, Hook count; backup | Do not reset to empty if Hook has leaves; use verified existing snapshot or migrate safely |
| Managed-relay systemd restarts forever | Executable worker's explicit disabling error | Stop/remove obsolete unit; use proof observer and customer wallet UX |
| Sponsor reports unavailable | Sponsorship monitor freshness, DB grants, per-chain reserve/budgets | Present unsupported/no gas status; user funds own wallet; no promise of automatic gas |
| Wrong `ATTESTATION_ROUTE` (old alias) | Source domains and canonical route ID, node registered route catalog | Derive current `iln_<source>_<destination>_<id>` identity |
| Validator RPC `AVAILABLE_UNVERIFIED` | Stored quorum file, current destination `setId`, `process.staticCall` | Recheck current-set proof and destination contract before user sign |

### Recovery after a stopped service

1. Identify source TX, chain, route ID and message ID from canonical on-chain evidence; do not infer from HTTP input.
2. Independently check target `Mailbox.delivered`. If true, no new TX is necessary.
3. Check node worker health and full verified Merkle leaf replica; recover from peer or controlled source-Hook log seed if necessary.
4. Query or re-request current-set quorum for the **original** source message.
5. Use the **one-shot unsigned** recovery helper or XITA proof endpoint; reject stale set IDs, route mismatches or failed destination simulation.
6. Have the user wallet sign destination `Mailbox.process`, using a fresh gas/nonce check.
7. Check finalized target delivery; for a second hop, initiate only the separate previously unperformed onward operation, never repeat TX 1.
8. Reconcile indexer and UI into **one** verified journey, preserving independently evidenced child hashes.

## 13. Node CLI/RPC troubleshooting

Example local read-only calls, not signing commands:

```sh
curl -sS http://127.0.0.1:8545 -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"xgr_getILNIndexerStatus","params":[]}' | jq .
curl -sS http://127.0.0.1:8545 -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":2,"method":"xgr_getILNQuorum","params":["iln_1643_8453_<VERIFIED_64HEX>","0x<VERIFIED_64HEX_MESSAGE_ID>"]}' | jq .
```

Placeholder values must be replaced with real canonical identities, not copied literally. The node supports `xgr_requestILNQuorum(route,messageId,sourceBlockNumber)`, `xgr_getILNQuorumAttestation(route,messageId,setId)` and `xgr_getILNReplicaProof(route,messageId)`; a local node can retain a partial/status-only view while one chain is unavailable. See the [v3.2.3 operator CLI/RPC reference](https://github.com/xgr-network/xgr-node/blob/XGR3.0/docs/ILN_V323_OPERATOR_REFERENCE.md).

Do not expose node signing keys, commercial fee private keys, relayer private keys or unredacted private RPC credentials in logs, support tickets or version control.

## 14. Production deployment posture

| Item | Expected current posture | Release evidence |
| --- | --- | --- |
| Validator worker | Runs alongside eligible v3.2.3 node, independently verifies proof/quorum | Confirmed root/count, quorum RPC, worker heartbeat, load/restart tests |
| Read-only proof observer | Optional operational convenience; no wallet capability | Installed SQL 008, lease/retry records, same-message persistence |
| Unsigned recovery helper | Available independently of website and commercial fee adapter | Deterministic `READY_UNSIGNED_CALL`, current-set `process.staticCall` |
| User source & destination signing | Mandatory in chosen XITA transfer product | Four signed operations for two hops (plus optional ERC-20 approvals), 2 confirmed target Mailboxes |
| Managed delivery worker | **Intentionally disabled** | Source-code startup guard; do not install as active service |
| Legacy native ILN relayer | Retained alternative, not user-led product runtime | Explicit `RELAYER_SUBMIT` mode; state/route verification and no unchecked enabling |
| Gas sponsor | Optional, independently budgeted and monitor-checked | Verified native user-wallet top-up only; availability may be false |
| Wallet indexer | Canonical, rebuildable read-only projection | Finality-aware source receipts; Mailbox delivery; explicit parent-child linkage |

For a production release, test: token-agnostic one-hop and two-hop, ERC-20 collateral/synthetic flow, validator set rotation mid-flight, restored Merkle replica after crash, RPC 403/429/503 failover, no-duplicate source sends, no duplicate destination signing, browser close/reopen and incomplete index coverage. **Do not claim successful Mainnet testing unless matching verified source and destination receipts exist.**

## 15. Source-code audit matrix

| Documented claim | Verifiable source anchor |
| --- | --- |
| User signs destination TX | `apps/web/transfer-actions.js` → `resumeDelivery` → `eth_sendTransaction` |
| Proof endpoint never signs/sends | `services/indexer/server.mjs` → `serveUnsignedTransferRecovery` and `transfer-recovery.mjs` → `runRecoveryAttempt` |
| Quorum route name is deterministic | `services/indexer/transfer-recovery.mjs` → `ilnValidatorRouteName` |
| Proof observer persists hints, not signatures | `services/indexer/transfer-proof-observer.mjs` → `tickProofObserver` and SQL 008 |
| Managed worker is disabled as standalone service | `services/managed-relay/worker.mjs` executable entrypoint explicit `throw` |
| Legacy native ILN relay can sign if enabled | `runtime/native-relayer/iln.mjs` → `RELAYER_SUBMIT` and `destinationMailbox.process` |
| Legacy script requires private key even for observe-only | `runtime/native-relayer/iln.mjs` → unconditional `env("RELAYER_PRIVATE_KEY")`, `new Wallet` |
| No complete-prefix reconstruction from root alone | `xgr-node/interchain/runtime/iln_replica_network.go` and `interchain/evm/iln_replica_catchup.go` |
| Sponsor sends gas grants only | `services/managed-relay/gas-sponsor.mjs` → policy-checked native transfer |
| 2-hop UI has six stages, four wallet TXs | `apps/web/transfer-status-flow.js` → `deriveTransferFlow` |

**Version rule:** This document is an audit of code as inspected on 2026-10-23. A source/behavior change must update the corresponding operational claim and re-run relevant tests. Static documentation cannot certify current live RPC/contract deployment health. The predecessor `xgr-hyperlane` must not be used to configure a current Interchain service.
