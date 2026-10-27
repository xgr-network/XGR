# Optional applications, service APIs and operations

[Documentation index](README.md). The contracts and validator worker remain independently usable. These applications help discover, price, monitor or execute transfers; none replaces canonical source evidence or destination BLS verification. Implementation source paths below are relative to public `xgr-interchain`.

## 1. Service and key separation

| Component | Entrypoint / default listen | State or credentials | Protocol authority |
| --- | --- | --- | --- |
| Static website | `apps/web/`, static SPA | Catalog, injected user wallet | No backend user signing key |
| Deployment admin | `services/admin/server.mjs`, 127.0.0.1:4087 | Local deployment journals; scoped GitHub credentials; operator wallet in browser | Its own approved-main workflow, no exclusive Factory admission |
| Read API/indexer | `services/indexer/server.mjs`, 127.0.0.1:4088 | SELECT-only database role, verified metrics file | Read/discovery and unsigned preparation |
| Source-hash intake | `services/indexer/transfer-intake.mjs`, 127.0.0.1:4089 | Restricted staging-table writer | Untrusted hints only |
| Join/onboarding | `services/onboarding/server.mjs`, 127.0.0.1:4090 | Private contact/token store, mail and scoped GitHub writer | Listing proposal only |
| Commercial quote | `services/managed-relay/server.mjs`, 127.0.0.1:4092 | Service-wallet quote key; restricted quote evidence writer | Optional adapter pricing, no BLS authority |
| Transfer index worker | `services/indexer/transfer-index-worker.mjs` | Restricted derived-state writer, chain RPC | Rebuildable finalized event projection |
| Proof observer | `services/indexer/transfer-proof-observer.mjs` | Durable database leases/state, quorum RPC | Read-only proof readiness; no broadcast |
| TVL worker | `services/indexer/tvl-worker.mjs` | Verified route/escrow inputs and local output | Metrics projection, not message authorization |
| Gas sponsor | `services/managed-relay/gas-sponsor.mjs` and listener | Service wallet and restricted grants database | Pays own gas grants to users |
| Optional managed executor | `services/managed-relay/worker.mjs` | Independent executor wallet and durable local index | Pays destination gas for valid original messages |
| Public native watcher | `runtime/native-relayer/iln.mjs` | Per-route local cursor/pending file; optional executor key | Observe or independently submit valid metadata |

Bind internal services to loopback and expose only intended reverse-proxy locations. Admin requires authenticated TLS proxy protection for **all** subpaths. A matching Origin/Host header is not user authentication. Node validator secrets and an offline commercial recovery-admin key do not belong in these service environments.

## 2. Website transfer model

The SPA routes include dashboard `/`, `/universe`, `/markets`, `/token/<slug>`, `/transfer?token=<asset>` and `/join`. Catalog generation derives chains, assets, representations and recorded deployment references from repository manifests/evidence. A configured prospect and a receipt-backed representation are distinct. Website visibility, route readiness and BLS proof readiness must remain distinct too.

`transfer-actions.js` validates raw decimal conversion, actual quote/Gateway bindings, wallet funds, native fees, expected EIP-712 bytes for optional paid use, and explicit wallet signing. `wallet-transfers.js`, pending/action modules and nonce checks reconstruct original source operations and delivery state. Index results and explorer candidates trigger independent rechecks; they do not authorize a mint/unlock.

The UI's transfer flow uses canonical source receipts and destination delivered state rather than a browser transfer journal as settlement authority. Bounded recent discovery cannot establish that no older pending transfer exists; the original source hash remains a recovery input. Dashboard/market values are not collateral proof. A wallet cancel or closed modal must not create an automatic second source transaction.

For independent execution, use the [public Gateway runbook](XGR_INTERCHAIN_v3.4.0_Operations.md). No website API or commercial quote is required.

## 3. Read API

All following paths retain their actual `xeta` namespace; do not silently rename them to `xita`. JSON responses are uncached at the HTTP layer.

| Method/path | Parameters/body | Meaning and failures |
| --- | --- | --- |
| GET `/health` | None | Process reports `xita-metrics`, read-only; not complete chain-data coverage |
| GET `/api/xeta/v1/transfer/health` | None | Recovery script and ethers installation check; 503 if absent; not a quorum test |
| GET `/api/xeta/v1/transfer/recovery` | `asset`, `route`, `messageId`, `sourceTxHash` | Resolve documented route, verify original source and return unsigned recovery outcome; no broadcasting |
| GET `/api/xeta/v1/transfers/wallet` | Valid EVM `account`; optional `pending=1` | Derived wallet operations and coverage; unavailable database/evidence yields 503 |
| GET `/api/xeta/v1/transfers/discovery` | Valid EVM `account` | Cached explorer candidates; explicitly not delivery/signing authority |
| GET `/api/xeta/v1/transfers/stats` | None | Indexed hop counts/raw amounts and delivery coverage; not deduplicated journey volume or TVL |
| GET `/api/xeta/v1/metrics/toplist` | None | Verified evidence, sourced market data, visibility and optional history; unknown values remain null |
| GET `/api/xeta/v1/visibility` | None | Derived application publication eligibility |
| GET `/api/xeta/v1/systems/<chain>` | Optional `sort`, `q` | Catalog system rankings filtered by actual visibility |
| POST `/api/xeta/v1/rpc/read` | `{rpcUrl,method,params}` | Restricted catalog endpoint and bounded read-only RPC forwarding |

Recovery outcomes include `PENDING`, `ALREADY_DELIVERED` and `READY_UNSIGNED_CALL`; an identical in-flight request may return HTTP 202 `PREPARING`. The server limits parallel preparation to two processes and recent admission keys to 60/minute; an identity is throttled for 15 seconds. Busy callers receive 429. A sanitized stage/reason and 503 express unavailable proof; never interpret this as a failed original source lock/burn.

Example local read:

```sh
curl -fsS 'http://127.0.0.1:4088/api/xeta/v1/transfers/wallet?account=0xYOUR40HEXADDRESS&pending=1'
```

Replace the address before executing. Check HTTP and body status; `curl` success does not turn `unknown` evidence into confirmed delivery.

### Read proxy method constraints

Allowed methods are `eth_chainId`, `eth_blockNumber`, `eth_gasPrice`, `eth_getBalance`, `eth_getTransactionCount`, `eth_call`, `eth_getTransactionByHash`, `eth_getTransactionReceipt`, `eth_getLogs`, `eth_getCode`, `eth_getBlockByNumber`.

The requested RPC URL must already exist in the generated chain catalog and pass HTTPS/hostname checks. The request contains exactly the three named keys. The server checks upstream chain identity, tries bounded catalog alternatives and reports sanitized failure categories. It is not an arbitrary URL proxy.

Limits include an 8192-byte HTTP payload; bounded call data (≤4100 hex characters); latest or numeric-block `eth_call`; latest-only `eth_getCode`; header-only block reads (`false` transaction bodies); and a single-address, ≤256-block log window with bounded topics. There is no `eth_sendTransaction`, raw-transaction submission or arbitrary signing endpoint. Invalid requests are 400; unavailable verified upstreams are 503. Do not use this bounded proxy as an unrestricted historical scanner.

## 4. Transfer indexing, intake and proof observer

The transfer worker verifies source chain identity, finality, canonical blocks/receipts, Gateway operation and Mailbox dispatch before recording a derived operation. Its cursor/reorg logic can retract and rebuild affected projections. Delivery refresh is separate from source indexing. User/source amounts are token base units; hop counts cannot be advertised as unique two-hop journeys.

POST `/api/xeta/v1/transfers/announce` accepts exactly:

```json
{"account":"0xUSER_ADDRESS","sourceChain":"base","txHash":"0xORIGINAL_SOURCE_HASH"}
```

Actual values must be valid nonzero account, supported configured source name and 32-byte transaction hash. A successful HTTP 202 returns `REPORTED_UNVERIFIED`, `verified:false`. The intake has only staging INSERT authority. The worker subsequently verifies the original transaction sender/account and canonical operation. An announcement is not wallet authentication, source settlement or authorization. Body, origin and rate limits apply.

Proof observation uses durable per-message jobs and PostgreSQL `FOR UPDATE ... SKIP LOCKED` leases (75 seconds). Jobs are only queued after verified source indexing and explicitly undelivered destination state. `READY_UNSIGNED_CALL` maps to ready; missing quorum maps to waiting; errors are unavailable; a delivered observation still needs canonical delivery reconciliation. Retrying does not dispatch source principal. The observer has no wallet or broadcast path.

Indexer database/schema files live under `services/indexer/sql/`. They cover publication, transfer operations/journeys, grants, announcements, timing, proof observations, tax evidence and sponsor commitments/resolution. There are two differently named migrations numbered 010; use the explicit reviewed installer path, not a guessed “apply one file per number” procedure. Provision each reader/writer role for its actual tables. A public reader must not inherit sponsor, tax writer or transfer verification permissions.

## 5. Metrics and TVL

`tvl-verifier.mjs`, `tvl-worker.mjs`, `escrow-flow-24h.mjs`, `indexed-flow-24h.mjs`, publication and history modules implement evidence generation/projection. Their existence replaces the old blanket assertion that no verifier is implemented. It does not prove those workers are installed or healthy on a production server.

The read server accepts a bounded schema-1 local metrics file, rejects future timestamps and treats evidence older than two minutes as unavailable. It preserves unknown totals when active asset coverage is incomplete. CoinGecko price/market cap is third-party market data and is not collateral evidence. Refresh caching is 120 seconds after success and 60 seconds after errors.

Count actual original collateral only once across represented chains. Synthetic supply, validator FeeVault funds, commercial balances and unsolicited escrow deposits are not automatically additional locked principal. Preserve as-of/source/coverage and distinguish custody, movement and market values. Gross 24-hour flow is not net collateral or exchange trading volume.

## 6. Commercial quote and sponsorship APIs

| Method/path | Input | Effect |
| --- | --- | --- |
| GET `/api/xita/v1/managed/health` | None | Catalog-enabled adapters, paid quote database readiness and sponsor availability |
| GET `/api/xita/v1/managed/sponsorship` | `account`, `source`, `messageId` | Public journal view bound to verified original wallet/paid transfer; no grant reservation or payment command |
| POST `/api/xita/v1/managed/preview` | `{asset,source,destination,payer,recipient,amountRaw}` | Unsigned price/route preview |
| POST `/api/xita/v1/managed/quote` | Same exact allowed field set | Reviewed EIP-712 quote with persisted evidence/commitments before response, or fail closed |

Preview-only mode `XITA_INTERCHAIN_PREVIEW_ONLY=1` disables signing and refuses `/quote`. Normal mode verifies service-wallet address/key consistency and actual ExecutionGateway configuration. Commercial quote expiry is governed by on-chain issuance/lifetime policy, maximum 90 seconds. Quote signer cannot execute a transfer for a user; the wallet authorizes each source operation.

Wallet-aware sponsorship prices only the required downstream shortfall using verified balances, required native fees and buffered gas, excluding token principal and source transaction gas/approval. Immutable quote intents/commitments bind payer, route, adapter, nonce, fee, recipient and promised stages/amounts. Paid source event identity activates a commitment. A later wallet balance is not permission to invent an unquoted grant.

The sponsor reserves unique grant identity/nonce and budget under database locks before broadcasting its own native gas payment, then reconciles exact transaction receipts. Per-chain reserves and daily caps apply. Expired quote commitments are only released under explicit canonical unused/paid resolution rules; ambiguous RPC evidence leaves them reserved. Gas prices beyond a committed buffer require visible shortfall handling, not unlimited automatic funding.

The service wallet signs optional quotes, receives fees and funds sponsorship. The recovery admin is a different offline identity. No private key belongs in a public catalog, browser, receipt or GitHub file. Commercial fees are not an on-chain delivery/refund bond. Direct users fund their own gas and bypass this adapter.

### Managed executor implementation limit

`services/managed-relay/worker.mjs` currently has an explicit configured paid-source map for **XGRChain and Base**. Do not infer generic Arbitrum paid-source execution support merely from a dynamically generated quote catalog or public protocol support. This is an optional worker limitation, not a restriction on public Arbitrum routes or independent delivery.

The executor uses its own destination wallet, durable source index, original receipt verification, unsigned recovery and bounded gas simulation. Its key is separate from validator BLS and user keys. The public native watcher below is another independent execution option.

## 7. Public native watcher configuration

`runtime/native-relayer/iln.mjs` can observe and prepare without broadcasting. Set `RELAYER_SUBMIT=true` only when intentionally operating an executor; then `RELAYER_PRIVATE_KEY` funds destination gas. This key does not own source user principal or sign validator messages.

| Variable | Default / meaning |
| --- | --- |
| Route/RPC/contract variables | Same original/destination identity variables as the recovery runbook |
| `RELAYER_SUBMIT` | `false`, observation-only |
| `RELAYER_PRIVATE_KEY` | Required only for intentional destination submission |
| `ORIGIN_LOG_CHUNK` | 10, clamped to 1–10 blocks |
| `POLL_INTERVAL_MS` | 5000, bounded 1000–60000 ms |
| `ORIGIN_START_BLOCK` | 0; new state otherwise starts near confirmed head, not full historical backfill |
| `RELAYER_STATE_FILE` / `ILN_STATE_PATH` | Optional explicit state path; default identity-qualified route file |

Version-2 local state binds physical source/destination, Gateway and route identity, tracks cursor and original source hashes for pending messages, and uses atomic mode-0600 persistence. Never share a state file across different routes. The loop limits scan batches, preserves pending failures and submits only prepared valid calls. An observe-only “ready” log is not delivered settlement.

`runtime/manage-relayers.sh {start|stop|restart|status|logs} [iln-<source>-to-<destination>|all]` operates configured `.env.relayer.iln.<source>-to-<destination>` files. These shell aliases are not node RPC route labels. With several asset instances in one direction, launch independent processes/state identities rather than assuming a chain-pair alias distinguishes every route.

## 8. Deployment admin

Admin's approved-main gate checks remote GitHub main against a clean local main and derives its queue from that exact inventory. A PR, issue label or local modified manifest is not an additional application deployment authorization. Public protocol registration remains independent of that application gate.

The implemented chain/asset operators plan dependencies, build/verify trusted artifacts and constructor parameters, prepare wallet calls, record submitted hashes, reconcile canonical receipts/code/bindings and append deployment evidence. Browser wallet approval remains necessary. The previous README assertion that the entire executor was still unimplemented is obsolete. Readiness can still block a particular missing artifact, counterpart or receipt.

Important API groups (all under authenticated `/admin/api/`):

| Group | Implemented operations |
| --- | --- |
| Inventory/health | GET `workqueue`, `infrastructure`, `chain-preflight`, `operations/health`, `balance`, `fee-treasury` |
| Bootstrap/readiness | GET `bootstrap`, `bootstrap/suggestions`, `deployment-readiness`, `route-lifecycle` |
| Chain deployment | POST `chain-deploy/preview`, `prepare`, `hash`, `reconcile`, `cancel-prepared`; GET `chain-deploy/status` |
| Asset deployment | POST `asset-deploy/preview`, `prepare`, `hash`, `reconcile`, `cancel-prepared` |
| Progress/sync | POST `deploy/advance`; GET `deployment-sync/status`, `progress`, `plan`, `jobs`; diagnostic POST `inspect`, `evidence`, `jobs/status` |

Each path after a group prefix is literal, e.g. `/admin/api/asset-deploy/reconcile`. Bodies are validated by the corresponding operator module; no generic arbitrary transaction signing API exists. Use the local authenticated UI/API-client implementation for the exact prepared-intent body. A receipt-reporting failure must resume evidence sync without re-executing an already successful creation transaction.

State defaults to `runtime-state/admin`, configurable with `XGR_ADMIN_STATE_DIR`. Trusted artifacts, journals and append-only deployment receipts must remain distinct from browser claims. GitHub writer credentials stay backend-only. Current validator health is Direct-BLS schema 2; Merkle leaf/replica health fields are obsolete.

## 9. Join/onboarding

GET `/api/xita/join/status` exposes readiness. POST `preview`, `submit`, `confirm` under that prefix implement manifest preview and private email-confirmed submission. The server validates canonical token/CoinGecko identity, current catalog and current-main identity before preparing a GitHub **draft listing PR**.

Submission stores contact and confirmation-token hashes in private storage and sends a time-limited confirmation email. No GitHub proposal is created before confirmation. Repeated confirmed links return the recorded PR; notification retry must not create duplicate proposals. Missing mail/private storage/scoped writer fails closed. Application rejection/listing and public route validity are different states.

Never put applicant email, confirmation secrets or private role-holder information in public manifests. The website may export a draft when optional submission is unavailable. The Join service's listing policy does not control public Factory admission.

## 10. Operations and configuration ownership

Install dependencies in the component package directory using its declared package manager. Packages without a lockfile use `npm install --ignore-scripts`, not `npm ci`. Do not infer a service's dependency installation from the native relayer's ethers install.

| Configuration | Owner / purpose |
| --- | --- |
| `XGR_ADMIN_HOST`, `XGR_ADMIN_PORT`, `XGR_ADMIN_STATE_DIR` | Loopback admin host/port/journal root |
| `XITA_INDEXER_HOST`, `XITA_INDEXER_PORT`, `XITA_INDEXER_DATABASE_URL` | Read API and SELECT-only role |
| `XITA_METRICS_EVIDENCE`, `XITA_TVL_HISTORY` | Verified local evidence/history paths |
| `XITA_TRANSFER_WORKER_DATABASE_URL` | Restricted finalized projection/proof worker writer |
| `XITA_TRANSFER_INTAKE_DATABASE_URL`, `XITA_TRANSFER_INTAKE_PORT` | Restricted unverified staging service |
| `XITA_JOIN_PORT` | Loopback Join API; private mail/storage/writer configuration in Join examples |
| `XITA_INTERCHAIN_PREVIEW_ONLY`, `XITA_MANAGED_QUOTE_PORT` | Read-only preview mode / quote API port |
| `XITA_INTERCHAIN_FEE_ADDRESS`, `XITA_INTERCHAIN_FEE_PRIVATE_KEY` | Optional commercial service identity |
| `XITA_INTERCHAIN_SPONSOR_ENABLED` | Explicit sponsor enablement; no second sponsorship-mode switch |
| `XITA_SPONSOR_DATABASE_URL`, `XITA_SPONSOR_STATUS_DATABASE_URL` | Grant worker / read-only sponsor status roles |
| `XITA_TAX_QUOTE_DATABASE_URL`, `XITA_TAX_COUNTRY_CIDR_PATH` | Restricted quote evidence writer / local country dataset |
| `XITA_MANAGED_RELAYER_PRIVATE_KEY`, `XITA_MANAGED_INDEX_FILE` | Optional paid executor key / durable source index |

Complete component example files and SQL grants are authoritative for additional limits/credentials; see the [source map](XGR_INTERCHAIN_Source_Map.md). Do not copy a production environment into docs. For each service inspect the installed unit, loaded environment, current commit, API body coverage and worker logs; process health alone is insufficient.

`manage.sh` controls web/admin installation/publication, not validators or public relay processes. Commands include `status`, `start`, `stop`, `restart`, `logs`, `follow`, `health`, `check`, `check-routes`, `publish-web`, `update`, `install-sync`, `install-join`, `install-transfer-api`, `install-transfer-intake`, `repair-transfer-db`, `install-tvl`, `install-fee-preview`, `install-interchain-fee`, `install-fee-tax-ledger`. `deploy` is a web-publication alias. `hard-reset-dev` is explicitly destructive development reset, not a routine upgrade instruction. Additional explicit installers are documented by their current case implementation; inspect `./manage.sh help` and the script before invoking a mutation.

This documentation update installs, restarts, funds or enables none of those services. Source implementation, recorded deployment and actual server rollout are separate evidence levels.
