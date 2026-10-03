# XGR Chain — State Storage & Retention

**Document ID:** XGRCHAIN-STATE-STORAGE-RETENTION  
**Last updated:** 2026-10-03  
**Audience:** Node operators, validator operators, RPC operators, infrastructure engineers, auditors  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Feature introduced:** `xgr-node v2.1.0`  
**Feature:** State Growth Control — Online State Trie Sweeper  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Local immutable-trie storage, historical-state retention, online pruning and recovery

---

## 1. Purpose

XGRChain stores EVM state in an immutable, content-addressed trie.

As the chain evolves, new trie nodes and contract-code entries are written while historical versions can remain physically present in the local LevelDB database.

`xgr-node` includes **State Growth Control**, implemented as an online mark-and-sweep garbage collector:

```text
Online State Trie Sweeper
```

The feature was introduced in:

```text
v2.1.0
```

and remains part of the current:

```text
v3.1.1
```

production node.

It allows operators to retain a configurable window of recent canonical state roots and reclaim historical trie/code data that is no longer reachable from the retained state.

---

## 2. Consensus boundary

The Trie Sweeper is a **local storage feature**.

It does not change:

- transaction execution,
- EVM semantics,
- canonical state transitions,
- block validity,
- state roots recorded in blocks,
- receipts,
- logs,
- consensus,
- validator selection,
- staking,
- genesis,
- fork activation.

For example:

```text
Node A
    sweeper disabled

Node B
    sweeper enabled
    retain 10,000 blocks

Node C
    sweeper enabled
    retain 100,000 blocks
```

can all follow and validate the same canonical XGRChain.

The difference is how much historical EVM state remains locally available.

---

## 3. Block history versus state history

These are separate storage concepts.

### Canonical chain history

Includes:

- block headers,
- block bodies,
- transactions,
- receipts,
- logs.

### Historical EVM state

Includes historical versions of:

- accounts,
- balances,
- nonces,
- contract storage,
- contract code references,
- state tries.

The Trie Sweeper targets historical EVM trie/code storage.

It does not delete normal canonical block/receipt history.

Therefore:

```text
old block available
```

does not necessarily imply:

```text
old state root still executable/queryable
```

---

## 4. Retention model

Operator setting:

```text
--trie-sweeper-retain-blocks
```

Default:

```text
10,000
```

For every sweep:

```text
toBlock = canonical head
```

and:

```text
fromBlock =
    max(
        0,
        toBlock + 1 - retainBlocks
    )
```

The node loads every canonical header in:

```text
[fromBlock, toBlock]
```

and collects its state root.

Duplicate state roots are de-duplicated.

---

## 5. What retention means

The configured block count defines the canonical roots that must remain traversable.

For example:

```text
retainBlocks = 10,000
```

means the state roots from the most recent 10,000 canonical blocks are selected as live roots.

All trie/code data reachable from those roots is preserved.

This is not equivalent to:

> delete everything older than exactly 10,000 blocks.

Historical nodes can remain because:

- immutable trie nodes are shared across state versions,
- old nodes may still be reachable from a retained root,
- recent write generations are conservatively protected,
- conservative marker state can retain additional garbage.

Therefore the setting defines a **minimum retained canonical state-root window**, not an exact physical age cutoff.

---

## 6. What can be deleted

The production sweeper considers only two LevelDB key classes sweepable.

### Trie nodes

Raw hash-addressed keys:

```text
32-byte hash key
```

### Contract code

Keys of the form:

```text
"code" + 32-byte code hash
```

Other LevelDB keys are skipped.

The sweeper does not perform arbitrary database-key deletion.

---

## 7. Mark-and-sweep model

One production cycle performs:

```text
select retained canonical roots
        ↓
start new GC generation
        ↓
mark reachable account trie
        ↓
mark reachable storage tries
        ↓
mark referenced contract code
        ↓
scan LevelDB in bounded ranges
        ↓
identify unmarked candidates
        ↓
recheck candidates under write barrier
        ↓
delete unreachable trie/code data
        ↓
compact affected LevelDB ranges
        ↓
capture fresh canonical head
        ↓
strictly verify its state root
```

No deletion occurs before the mark phase has completed.

---

## 8. Account and storage traversal

For every retained root, the marker recursively traverses:

```text
account trie
    ↓
account value
    ├── contract code hash
    └── contract storage root
```

For contract accounts it therefore marks:

- account-trie nodes,
- storage-trie nodes,
- referenced contract code.

If referenced contract code is found, the implementation recalculates its Keccak hash and verifies it against the stored account code hash.

A mismatch causes the mark operation to fail.

---

## 9. Missing retained state is an error

During marking, a hash-linked trie node required by a retained root must exist.

If it does not:

```text
missing trie node ...
```

is returned.

The sweeper does not silently reinterpret missing retained data as empty state.

This is an important integrity property.

---

# Online concurrency safety

## 10. Write tracking

The immutable-trie LevelDB implementation contains a GC write barrier.

When the sweeper is enabled:

```text
normal trie write
        ↓
GC barrier read lock
        ↓
mark written key with current generation
        ↓
write key to trie database
```

Both:

```text
Put(...)
```

and batched writes are generation protected.

Contract code uses the same protected storage path.

---

## 11. GC generations

When write tracking begins:

```text
gcGeneration = 1
```

Each sweep starts a new generation:

```text
gcGeneration++
```

For a production sweep with generation:

```text
G
```

the deletion logic preserves keys whose marker generation is:

```text
>= G - 1
```

Therefore both:

```text
current generation
```

and:

```text
immediately previous generation
```

are protected.

---

## 12. Why the previous generation is retained

The extra generation protects the race where state is written shortly before the sweep generation changes but becomes canonical only afterward.

Conceptually:

```text
state written in generation G-1
        ↓
sweep begins generation G
        ↓
that state becomes canonical
```

Without the grace generation it could appear unmarked during the new retained-root snapshot.

The previous-generation protection prevents this race from deleting newly canonical state.

---

## 13. Startup synchronization

The sweeper enables write tracking before recording its synchronization head.

Startup sequence:

```text
initialize Trie Sweeper
        ↓
enable GC write tracking
        ↓
record current canonical head H
        ↓
wait until canonical head > H
        ↓
begin first sweep
```

Polling interval:

```text
250 ms
```

The first sweep therefore intentionally does not run immediately after process start.

---

## 14. Why it waits for a new head

A state transition may already have been in flight when write tracking was enabled.

In IBFT such a transition can target the next canonical height.

Waiting for one canonical head advance ensures that this pre-tracking/in-flight state becomes either:

- canonical and covered by retained-root selection, or
- obsolete.

This closes the startup race before deletion begins.

---

# Production scan path

## 15. `SweepLive`

The production server uses:

```text
SweepLive(...)
```

not the older snapshot-based sweep path.

This matters operationally.

`SweepLive` does not hold one long-lived LevelDB snapshot across a potentially very long full-database sweep.

---

## 16. Why long-lived snapshots are avoided

A LevelDB snapshot or iterator can pin SSTables that it can still see.

During a large online cleanup this could temporarily prevent physical disk reclamation of obsolete SSTables for hours.

The production implementation instead:

1. marks against the live immutable database,
2. scans in bounded chunks,
3. releases each iterator,
4. deletes candidates,
5. compacts the completed key range.

This allows disk reclamation to progress during the sweep itself.

---

## 17. Range scanning

The production sweep scans the database by first-byte ranges:

```text
0x00
0x01
...
0xff
```

There are therefore:

```text
256
```

top-level scan ranges.

Within each range, scanning occurs in bounded chunks.

---

## 18. Internal batching defaults

Current `v3.1.1` internal defaults:

| Internal setting | Value |
| --- | ---: |
| Delete batch | `256` keys |
| Scan batch | `4096` keys |
| Mark batch | `2048` operations |
| GC pause | `10 ms` |

These are implementation details, not current operator CLI settings.

Small batches and short pauses are intended to keep normal block/state processing ahead of garbage collection.

---

## 19. Candidate deletion recheck

The scan itself does not directly delete a candidate.

Before deletion:

1. scan iterator is released,
2. exclusive GC write barrier is acquired,
3. candidate generation marker is re-read,
4. candidate is deleted only if it is still unprotected.

This closes the race where a key becomes live between:

```text
scan
```

and:

```text
delete
```

---

## 20. Conservative failure behavior

If trie deletion succeeds but cleanup of its temporary GC marker metadata fails, the implementation reports an error.

However, stale marker metadata is conservative.

It can cause later cycles to:

```text
retain too much
```

but not to:

```text
delete live state because of the stale marker
```

The marker database is therefore safety-biased toward over-retention.

---

# Compaction

## 21. LevelDB compaction

The production server invokes the sweeper with:

```text
Compact: true
```

After a first-byte range has been scanned, that range is compacted only when the sweep actually deleted data from it.

This helps physically reclaim LevelDB storage.

Deletion alone does not guarantee immediate filesystem shrinkage without compaction.

---

## 22. Disk usage expectations

The Trie Sweeper does not create a fixed maximum database size.

Disk can continue to grow because:

- current live state grows,
- more accounts exist,
- contracts add storage,
- new code is deployed,
- retained roots share substantial history,
- the chosen retention window is large,
- LevelDB maintains SSTables and compaction overhead,
- temporary GC metadata also consumes storage during operation.

Therefore:

```text
retainBlocks = 10,000
```

does not mean:

```text
database will stay below a specific GB size
```

---

# Post-sweep verification

## 23. Fresh canonical-head verification

After sweep deletion and compaction, the server captures the current canonical head again.

This can be newer than:

```text
toBlock
```

selected at the beginning of the sweep.

That fresh head's state root is passed to:

```text
HashCheckerStrict(...)
```

---

## 24. Strict hash checker

The strict checker:

- requires hash-linked trie nodes to exist,
- recursively reconstructs the trie,
- recalculates its root,
- returns an error for missing referenced nodes.

The calculated root must equal:

```text
head.StateRoot
```

If not, the cycle fails with an integrity mismatch.

---

## 25. Scope of the post-sweep check

There are two integrity layers.

### During mark phase

Every configured retained root is traversed.

Missing nodes or code for those roots cause marking to fail before deletion.

### After sweep

A freshly captured **current canonical head** is traversed again using the strict checker.

The post-sweep check does not separately re-run the strict checker for every historical retained root.

It verifies that current canonical state remained intact across the online sweep.

---

## 26. Completion log

A successful production cycle logs:

```text
generation
fromBlock
toBlock
roots
marked
scanned
deleted
retained
skipped
duration
verifiedHead
verifiedStateRoot
```

A normal operator should pay particular attention to:

```text
deleted
duration
verifiedHead
verifiedStateRoot
```

---

# Configuration

## 27. CLI flags

```text
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Current defaults:

| Setting | Default |
| --- | ---: |
| Sweeper | disabled |
| Retained canonical blocks | `10,000` |
| Interval | `6h` |

The defaults are defined directly by the `v3.1.1` server configuration.

---

## 28. Configuration-file fields

Equivalent JSON/YAML/HCL configuration fields:

```yaml
trie_sweeper: true
trie_sweeper_retain_blocks: 10000
trie_sweeper_interval: 6h
```

---

## 29. Validation requirements

When the feature is enabled:

```text
retainBlocks > 0
```

and:

```text
interval > 0
```

are required.

The sweeper additionally requires:

- persistent non-empty data directory,
- initialized canonical head,
- LevelDB-backed immutable-trie storage.

If these conditions are not met, startup of the sweeper fails.

---

## 30. Work directory

The GC work directory is:

```text
<data-dir>/trie-gc
```

Marker database:

```text
<data-dir>/trie-gc/marks
```

Example:

```text
/var/lib/xgr/node/trie-gc/marks
```

---

## 31. Marker data is temporary

When the Trie Sweeper initializes, the implementation removes and recreates:

```text
<data-dir>/trie-gc
```

The marker database is therefore disposable garbage-collection metadata.

It is not canonical blockchain state.

It should not be treated as an authoritative component of a blockchain-state backup.

The canonical trie database remains the important persistent state.

---

# Sweep scheduling

## 32. First cycle

The first cycle starts after:

```text
one canonical head advance
```

following write-tracking activation.

It does not wait six hours before the first sweep.

---

## 33. Following cycles

After a cycle ends, the worker starts a timer for:

```text
--trie-sweeper-interval
```

Default:

```text
6h
```

Therefore the cadence is:

```text
sweep duration
        +
configured interval
        +
next sweep
```

not:

```text
fixed every six hours from process start
```

---

## 34. Failed cycle behavior

If a cycle fails:

- the error is logged,
- canonical chain state is not silently changed to hide the error,
- the background worker remains alive,
- the normal interval is waited before another cycle is attempted.

Integrity failures therefore remain visible in logs.

---

# Operator profiles

## 35. General bounded-history node

Example:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --seal=false \
  --trie-sweeper \
  --trie-sweeper-retain-blocks 10000 \
  --trie-sweeper-interval 6h
```

At the nominal two-second block target:

```text
10,000 blocks
≈ 20,000 seconds
≈ 5h 33m
```

The wall-clock duration is only approximate.

---

## 36. Longer-history RPC node

Example:

```text
--trie-sweeper-retain-blocks 100000
```

Nominal time window:

```text
100,000 × 2 seconds
≈ 55h 33m
```

A larger retention window requires more disk and more mark work.

---

## 37. Archive-style node

For unrestricted historical EVM-state access:

```text
Trie Sweeper disabled
```

Do not enable pruning on the only node intended to provide arbitrary historical state.

An archive-style node is appropriate for workloads requiring old:

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
debug_trace*
```

against arbitrary historical heights.

---

## 38. Validator profile

The Trie Sweeper can technically run on a validator because pruning is consensus-independent.

However, validators are latency-sensitive.

Before enabling it on validators:

- validate behavior on a full/RPC node,
- ensure adequate storage IOPS,
- monitor consensus round changes,
- monitor block progression,
- monitor sweep duration,
- avoid excessively aggressive retention policies without operational evidence.

Consensus reliability takes priority over disk reclamation.

---

# RPC implications

## 39. State-dependent historical RPC

Pruning can affect requests such as:

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
eth_estimateGas
debug_traceCall
debug_traceTransaction
debug_traceBlockByNumber
debug_traceBlockByHash
```

when execution requires an old state root that has been reclaimed.

---

## 40. History that remains independent

The sweeper does not target canonical:

```text
eth_getBlockByNumber
eth_getBlockByHash
eth_getTransactionByHash
eth_getTransactionReceipt
eth_getLogs
```

data merely because its corresponding historical trie state is no longer retained.

A node can therefore answer:

```text
What happened in block N?
```

while being unable to answer:

```text
What would this contract call have returned against state at block N?
```

---

## 41. No exact expiry guarantee

Operators should not promise clients that state will disappear exactly after:

```text
retainBlocks
```

because trie nodes can remain reachable through newer roots.

The safe client contract is:

> State inside the configured retained canonical-root window is intended to remain available; arbitrary state older than that window is not guaranteed.

---

# Operational monitoring

## 42. Logs to monitor

Initialization:

```text
Trie sweeper enabled
retainBlocks
interval
trackingFromBlock
workDir
```

Startup synchronization:

```text
Trie sweeper write tracking synchronized
trackingFromBlock
currentBlock
```

Cycle start:

```text
Trie sweeper cycle started
fromBlock
toBlock
roots
```

Completion:

```text
Trie sweeper cycle completed
generation
marked
scanned
deleted
retained
skipped
duration
verifiedHead
verifiedStateRoot
```

Failure:

```text
Trie sweeper cycle failed
```

---

## 43. System metrics to correlate

Monitor:

- free filesystem capacity,
- LevelDB directory size,
- GC marker directory size,
- disk latency,
- disk throughput,
- CPU,
- memory,
- block progression,
- synchronization state,
- peer count,
- validator round behavior if applicable,
- RPC latency,
- sweep duration.

Disk-space trends should be evaluated across multiple completed sweeps rather than immediately after enabling the feature.

---

## 44. Healthy cycle indicators

A healthy completed cycle should show:

```text
verifiedHead
verifiedStateRoot
```

and continued:

```text
canonical block progression
```

after completion.

The absolute number of:

```text
deleted
```

entries can vary widely by chain state and prior pruning history.

A low deletion count does not itself indicate failure.

---

## 45. Disk does not shrink immediately

Possible explanations include:

- few unreachable nodes existed,
- much data is shared with retained roots,
- current live state is large,
- retention window is large,
- filesystem/LevelDB effects lag behind logical deletion,
- concurrent chain growth offsets reclaimed space.

Use trend monitoring rather than a single filesystem snapshot.

---

# Disabling and recovery

## 46. Disable future pruning

Remove:

```text
--trie-sweeper
```

or configure:

```yaml
trie_sweeper: false
```

This stops future sweeps.

It does not recreate deleted state.

---

## 47. Deleted historical state cannot be toggled back on

After pruning:

```text
disable sweeper
```

does **not** mean:

```text
historical state restored
```

The node has no local inverse operation that reconstructs deleted trie nodes simply from the configuration change.

---

## 48. Recovery when historical state is needed again

Possible recovery paths include:

- rebuild/resynchronize under an archive-compatible policy,
- restore a suitable pre-pruning/archive backup,
- query another archive-style node,
- rebuild a dedicated historical-state service.

Which approach is appropriate depends on the workload and available infrastructure.

---

## 49. Recovery after integrity failure

If a sweep reports:

```text
post-sweep trie integrity check ...
```

or:

```text
post-sweep trie integrity mismatch ...
```

treat it as a serious storage-integrity event.

Recommended procedure:

1. preserve node logs,
2. avoid treating the node as authoritative,
3. if it is a validator, remove it from production consensus duties if integrity cannot immediately be established,
4. compare block number and head hash with trusted nodes,
5. check filesystem and disk health,
6. preserve relevant database files for investigation if required,
7. rebuild/resynchronize from a trusted state if integrity cannot be proven.

Do not suppress the error and continue assuming historical/current trie integrity.

---

## 50. Backup considerations

The canonical trie database is persistent node state.

The directory:

```text
trie-gc
```

contains temporary GC tracking metadata.

A backup/recovery strategy should therefore focus on:

- canonical chain database,
- trie database,
- node role/configuration,
- validator key material where applicable.

Validator key backups must remain protected independently of storage-pruning policy.

---

# Upgrade classification

## 51. Feature history

State Growth Control was introduced in:

```text
xgr-node v2.1.0
```

Current verified baseline:

```text
xgr-node v3.1.1
```

The original introduction remains historical; the current implementation reference should use `v3.1.1`.

---

## 52. Upgrade classification

| Property | Trie Sweeper |
| --- | --- |
| Consensus change | No |
| EVM semantics change | No |
| State-transition change | No |
| Canonical state-root change | No |
| Transaction-format change | No |
| Genesis change | No |
| Hardfork required | No |
| Activation block required | No |
| Local storage behavior | Yes |
| Historical-state availability | Yes |
| Operator configurable | Yes |

Changing local retention does not require validator-wide coordination.

---

## 53. Operator checklist before enabling

- Run a release that supports the Trie Sweeper.
- For this documentation baseline, use `v3.1.1`.
- Confirm a persistent data directory.
- Confirm adequate free disk space.
- Determine required historical-state window.
- Determine whether any application needs archive RPC.
- Determine whether historical debug tracing is required.
- Do not prune the only archive node.
- Record the chosen retention setting.
- Record the sweep interval.
- Ensure storage/IO monitoring is active.
- Plan recovery before deleting historical state.

---

## 54. Operator checklist after enabling

Verify:

- sweeper initialization log,
- write-tracking synchronization,
- first cycle starts after head advancement,
- canonical head continues advancing,
- synchronization remains healthy,
- sweep completion appears,
- `verifiedHead` is plausible,
- `verifiedStateRoot` is present,
- no integrity error appears,
- disk latency remains acceptable,
- applications function inside the expected state-history window.

---

## 55. Production defaults summary

| Parameter | `v3.1.1` |
| --- | --- |
| Sweeper enabled by default | No |
| Default retention | `10,000` blocks |
| Default interval | `6h` |
| Production sweep path | `SweepLive` |
| Long-lived full DB snapshot | No |
| Scan ranges | `256` first-byte ranges |
| Default scan batch | `4096` |
| Default delete batch | `256` |
| Default mark batch | `2048` |
| Default GC pause | `10 ms` |
| Current + previous generation protected | Yes |
| Contract code marked | Yes |
| Contract code hash checked | Yes |
| Compaction | Affected ranges |
| Post-sweep current-head verification | Strict |
| GC marker DB persistent canonical state | No |
| Historical state outside window | Not guaranteed |
| Canonical block history removed | No |

---

## 56. Design principle

XGRChain separates:

```text
canonical state correctness
```

from:

```text
historical-state retention policy
```

The blockchain determines the canonical state root.

The operator decides how much old EVM state must remain locally queryable.

The Online State Trie Sweeper makes that policy explicit while protecting concurrent writes, retained canonical roots and the freshly captured canonical head.

The operational contract is therefore:

```text
retain what is required
verify what remains canonical
reclaim what is no longer reachable
```

without changing XGRChain consensus.
