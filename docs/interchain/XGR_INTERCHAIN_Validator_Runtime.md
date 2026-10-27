# Validator runtime, observation and durable state

[Documentation index](README.md). Source authority: public xgr-node `interchain/config.go`, `interchain/runtime/`, `interchain/evm/`, dedicated IBFT read adapters and Interchain JSON-RPC/CLI. This worker is separate from ordinary block production and stake-weighted IBFT consensus.

## 1. Startup and identity

The node uses reviewed compiled physical-chain policies. The three configured networks are `xgr` (alias `xgrchain`), `base` and `arbitrum`. Policies bind chain ID/domain, finality, verifier format, validator Registry, source Registry and canonical receipt-based activation height. Per-token additions are discovered; they do not require per-route environment variables.

XGR sources/destinations use the node's local native chain reader and local submission adapter. No external XGR Interchain RPC policy is configured for validators. Remote-chain RPC URLs and independent-operator labels are compiled. Changing supported networks is a reviewed release/configuration operation; replacing a route's evidence with arbitrary operator ENV is not supported.

Worker startup creates control, pending, attestation, cursor, vote and governance directories, registers known RPC route labels, recovers persisted local votes and starts heartbeat, quorum hint, maintenance, governance execution and worker loops. Errors must remain visible; a running node process does not imply an active healthy Interchain worker.

## 2. Route discovery

The source Registry's confirmed `RouteAdded` history, persistent route catalog, canonical lookup hints and authenticated peer route notices contribute discovery. Catalog entries and peer notices are not signatures or route-admission approvals. Each accepted candidate is checked against the configured source Registry and Gateway/route/transport bindings.

Peer route announcements require a connected peer and bounded/rate-limited processing. Outgoing notices are based on a route the sender can itself verify, at most 16 per tick with per-identity publication spacing. A late-joining node may learn identity through peers and verify it from current append-only Registry state when old log discovery is unavailable.

The canonical route label includes both domains and the entire directed route ID. Separate router pairs and opposite directions cannot be collapsed into a chain-name alias.

## 3. Grouped source observation

Current `iln_observer_worker.go` groups verified routes by source network. Its dispatch key includes Gateway, destination domain and route ID. Native source windows use the local multi-Gateway reader; external windows use bounded multi-address log scanning, with provider-compatible splitting. Observed operations are sorted deterministically and deduplicated by route/transaction/log/message identity.

The durable cursor model is still **per-route** (`_direct_<route>`). A shared window begins from the minimum relevant route cursor; unknown routes begin from the configured source Registry activation boundary. It is incorrect to describe this implementation as one durable registry-version-qualified source cursor. Grouped scanning reduces duplicate observation but does not erase all individual route state.

Head regression fails closed. Adaptive catch-up has finite per-poll work budgets; a scan cursor only advances after the window is processed or failed operations are durably admitted to retry. Discovery never substitutes for the complete independent evidence check at signing.

## 4. Durable observer retry journal

A source operation that cannot yet be verified is stored with source, route name/ID, Gateway, destination domain, message ID, source height, source transaction hash and log index. An atomic temporary-file write, file fsync, rename and directory fsync precede cursor advancement past that failure. A conflict, storage error or full journal holds the source window.

Current bounds from `iln_observer_retry.go`:

| Limit | Value |
| --- | ---: |
| Pending retry records per route | 4096 |
| Encoded record size | ≤1024 bytes |
| Retry attempts per source poll | 24 |
| Retry attempts per route per poll | 2 |
| Minimum retry interval | 30 seconds |

Replay validates persisted identity and calls the same full signing path. Failed records remain and are rotated by modification time. Successful verification or an affirmative already-delivered result removes a record with directory durability. Old age alone is not authority to discard queued transfers.

## 5. Evidence, finality and endpoint failover

XGR verification uses locally committed blocks, original receipt logs, source Registry/Gateway bindings and FeeVault allocation. Base/Arbitrum require two distinct RPC operators with matching complete finality-qualified evidence. `rpc_evidence_quorum.go` explicitly forbids assembling one observation from fragments supplied by different endpoints.

Ordinary read failover and complete witness verification share endpoint health/cooldown behavior. HTTP/RPC failure, timeouts and throttling must not silently reset scan cursors or change finality to `latest`. More URLs from the same company provide transport redundancy, not more independent witnesses.

See [security model](XGR_INTERCHAIN_Security_Model.md) for the complete signed fields and evidence checks. Node synchronization is rechecked at signing entry and before signing after evidence reads. Discovery activity while unsynchronized is not permission to emit BLS authorization.

## 6. Votes, gossip and quorum

The dedicated P2P topic is `/xgr/interchain/direct-bls/1.0.0`. The internal envelope `iln_checkpoint_vote` and some Go type/file names are historical identifiers; the payload is current per-message `XITA_DIRECT_MESSAGE_V1`, not a checkpoint-root authorization.

The worker hashes canonical payload bytes, deduplicates local votes, verifies current eligibility, set and delivery state, signs using the local BLS secret, persists its vote, accepts it locally and then publishes. Incoming votes must pass payload, signer and quorum validation. A peer cannot make arbitrary bytes signable by labelling them a known route.

Completed quorum is archived by route/message/set, with message/latest aliases. Set rotation invalidates delivery under the retired set and permits re-attestation of the **same original source message**. Never repeat source principal movement to obtain a new message merely because a local proof is stale.

## 7. Scheduling

| Work | Default interval / constraint |
| --- | --- |
| Local state/gossip loop | 2 seconds |
| External message polling | 30 seconds |
| External discovery | 60 seconds |
| External membership polling | 60 seconds |
| External retries | 30 seconds |
| Local health refresh | 10 seconds |
| Pending request rebroadcast | 10 seconds |
| Storage maintenance | 5 minutes |

These are implementation scheduling defaults, not end-to-end delivery SLAs. Remote request latency, catch-up, missing witnesses, set rotation, disk pressure and validator availability affect actual progress. The fast local loop does not imply querying every remote chain every two seconds.

## 8. Storage and retention

All paths are relative to `<data-dir>/interchain/`:

| Path/category | Purpose |
| --- | --- |
| `requests/`, `pending/`, `results/` | Local membership control admission, durable pending work, completed command results |
| `attestations/<route>/<messageId>/<setId>.json` | Set-specific Direct-BLS authorization archive |
| `attestations/<route>/<messageId>.json`, `latest.json` | Message/latest lookup aliases; not guaranteed current-set proof |
| `iln/local-votes/` | Persisted local BLS votes for restart/rebroadcast |
| `iln/quorum-requests/` | Public original-message hints with bounded request leases |
| `iln/observer-retries/<source>/<route>/` | Durable failed-operation retry identities |
| `iln/indexer-health.json`, `worker.heartbeat` | Diagnostic snapshots/liveness |
| `governance/` | Source-fee proposals, requests, results and completed quorums |

Use `ibft interchain storage-status --data-dir ... --json` for measured file/byte categories. Back up secrets and node databases according to node operations policy; optional service databases cannot replace validator state. Do not copy a live signing identity into a second simultaneously running signer as a backup procedure.

Current cleanup behavior in `iln_storage.go` must be distinguished from its older introductory comment:

- Completed attestation cache entries are considered after seven days, within a maintenance budget of 64 candidates. Destination delivery must be read canonically.
- An undelivered archive older than 30 days may also be pruned **only if** its persisted original identity/payload is valid and complete original fee-qualified source evidence can be reverified under a current destination set (`canRegenerateILNQuorum`). This is cache reclamation; it is not source principal expiry.
- Unknown routes, unreachable destination/source, invalid evidence or failed regeneration retain those cache candidates. A pruned source RPC is not permission to discard an unrecoverable pending cache.
- Expired governance proposals/quorums are removed only after the configured seven-day post-expiry age. Completed local command result files may be reclaimed after seven days; pending requests are not thereby deleted.
- The 15-minute public request lease is admission/retry bookkeeping, not an expiry on asset entitlement or source dispatch.

Neither blanket “all pending proofs live forever” nor “all transfers expire after 30 days” describes this implementation.

## 9. Monitoring and incident response

Use `xgr_getILNIndexerStatus` for schema-2 worker/per-route state and `xgr_getILNQuorum` for a particular message. Track head/cursor-known flags, lag, last successful scan, worker timestamp and errors. A fresh heartbeat can coexist with a source RPC outage. A queue hint or `AVAILABLE_UNVERIFIED` archive does not prove delivery.

Exported metrics include Interchain worker availability, per-route Direct-BLS readiness/lag and source RPC availability. Do not advertise unimplemented per-chain provider/query counters merely because an older acceptance checklist requested them.

| Symptom | Investigate | Preserve |
| --- | --- | --- |
| Worker unavailable | Startup/configuration, heartbeat, local permissions and logs | Secrets and durable state |
| Growing source lag | Finality heads, endpoints/throttling, bounded catch-up, retry capacity | Cursors/retry records |
| Partial quorum | Current destination set, eligible/synchronized signers, P2P reachability | Original receipt/message ID |
| Stale authorization | Destination set rotation; request same message for current set | Original principal operation |
| Delivery simulation revert | Current route/ISM, recipient, collateral, signature format | Diagnostic stage/revert data |
| Delivered but native funds absent | Deferred payout event and beneficiary's reserved claim | Original recipient entitlement |

A managed-relayer restart is not a fix for missing canonical evidence. Restoring observation must not erase a pending transfer or create a second source operation.

## 10. Verification boundaries

The source map links deterministic regression suites for discovery, grouped scans, durable retries, witness agreement, malformed evidence, set rotation, storage and RPC. Unit tests demonstrate their asserted invariants. They do not prove a live three-validator deployment, all production routes, a complete mainnet sync or every failover scenario. Record actual chain transaction evidence separately.
