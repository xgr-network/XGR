# XGR Chain — State Storage & Retention

**Document ID:** XGRCHAIN-STATE-STORAGE-RETENTION  
**Last updated:** 2026-09-06  
**Audience:** Node operators, validator operators, RPC operators, infrastructure engineers, auditors  
**Release baseline:** `xgr-node` release tag `v2.1.0`  
**Node implementation:** `xgr-network/xgr-node`  
**Feature:** State Growth Control — Online State Trie Sweeper  
**Scope:** Local immutable-trie storage, historical-state retention and storage reclamation

---

## 1. Purpose

XGR Chain `v2.1.0` introduces **State Growth Control**, implemented as an online garbage collector for the immutable EVM state trie.

The feature allows node operators to control long-term state-storage growth by retaining a configurable window of recent canonical state roots and reclaiming trie nodes and contract-code entries that are no longer reachable from the retained state.

The implementation is designed to operate while the node remains online.

It does not change:

- transaction execution
- EVM semantics
- block validity
- canonical state roots
- receipts or logs
- consensus
- validator selection
- staking
- genesis configuration
- fork activation

State Growth Control is therefore a **local node-storage feature**, not a consensus fork.

---

## 2. Feature summary

XGR Chain uses an immutable, content-addressed state trie.

As chain state changes, new trie nodes are created while historical nodes can remain physically present in the local trie database even when they are no longer needed for the operator's desired historical-state window.

Starting with `xgr-node v2.1.0`, operators may enable the **Online State Trie Sweeper**.

When enabled, the node periodically:

1. identifies the configured recent canonical block range
2. collects the corresponding canonical state roots
3. marks all trie nodes and contract code reachable from those roots
4. protects state written concurrently with the sweep
5. removes unreachable trie and code entries
6. compacts affected LevelDB ranges
7. verifies a freshly captured canonical state root after the sweep

This allows physical storage occupied by obsolete historical trie data to be reclaimed without stopping normal block processing.

---

## 3. Consensus boundary

The trie sweeper is not consensus-critical.

Two nodes may use different local state-retention settings while following the same canonical XGR Chain.

For example:

```text
Node A:
trie sweeper disabled

Node B:
trie sweeper enabled
retain 10,000 blocks

Node C:
trie sweeper enabled
retain 100,000 blocks
```

All three nodes can:

- validate the same blocks
- reproduce the same current state transition
- participate in the same network
- agree on the same canonical state root

The retention configuration affects only which historical state data remains available in each node's local state database.

No mainnet genesis change, activation block or hardfork is required.

---

## 4. Retention model

The retention window is defined in canonical blocks.

The default configured retention value is:

```text
10,000 blocks
```

For each sweep, the node determines:

```text
toBlock = current canonical head
```

and:

```text
fromBlock = max(0, toBlock + 1 - retainBlocks)
```

The state roots of the canonical blocks in that range are selected as retained roots.

Duplicate state roots are de-duplicated before traversal.

All trie data and contract code reachable from those retained roots remain live.

Trie and code entries that are:

- outside the retained state history
- not reachable from a retained root
- not protected by the concurrent-write generations

may be deleted.

Retention therefore applies to **historical state availability**, not to block history.

---

## 5. Online safety model

State Growth Control is designed to operate concurrently with normal node activity.

### 5.1 Write tracking

When the trie sweeper starts, trie writes are generation-tracked.

The current and immediately previous write generations are protected during garbage collection.

This protects state that is created while a sweep is running or immediately around a sweep-generation boundary.

### 5.2 Startup synchronization

After write tracking becomes active, the sweeper records the current canonical head.

Before the first sweep starts, it waits until the canonical chain advances by at least one block.

This closes the startup race between state writes that were already in progress and the first garbage-collection cycle.

### 5.3 Mark before delete

The sweeper first traverses and marks all state reachable from the retained canonical roots.

No trie entries are deleted during this mark phase.

### 5.4 Bounded scanning

The production sweep does not hold one long-lived LevelDB snapshot across the entire database.

Instead, the trie database is scanned using short-lived iterators and bounded ranges.

This avoids keeping obsolete SSTables pinned for the duration of a potentially long-running sweep.

### 5.5 Recheck before deletion

Deletion candidates are rechecked under the trie GC write barrier before they are removed.

A trie entry that became live through a concurrent write is retained.

### 5.6 Post-sweep integrity verification

After deletion and compaction, the node captures a fresh canonical head and performs a strict traversal of its state root.

The verified result must equal the state root stored in that canonical block header.

A missing hash-linked node or state-root mismatch is treated as an integrity failure.

---

## 6. Configuration

State Growth Control is disabled by default.

### 6.1 CLI flags

```text
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Defaults:

| Setting | Default | Meaning |
|---|---:|---|
| `--trie-sweeper` | `false` | Enable online state-trie garbage collection |
| `--trie-sweeper-retain-blocks` | `10000` | Number of latest canonical blocks whose state roots are retained |
| `--trie-sweeper-interval` | `6h` | Delay between completed sweep cycles |

Example:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --trie-sweeper \
  --trie-sweeper-retain-blocks 10000 \
  --trie-sweeper-interval 6h
```

### 6.2 Configuration-file fields

Equivalent configuration fields are:

```yaml
trie_sweeper: true
trie_sweeper_retain_blocks: 10000
trie_sweeper_interval: 6h
```

### 6.3 Validation requirements

When enabled:

```text
trie_sweeper_retain_blocks > 0
trie_sweeper_interval > 0
```

The node also requires:

- a persistent data directory
- an initialized canonical chain head
- the supported LevelDB-backed immutable-trie storage

The temporary GC working directory is created under:

```text
<data-dir>/trie-gc
```

Marker metadata is stored under:

```text
<data-dir>/trie-gc/marks
```

This marker database contains disposable garbage-collection metadata and is rebuilt when the node starts.

---

## 7. Sweep scheduling

The first sweep does not start immediately when the node process starts.

Sequence:

```text
node start
    ↓
trie write tracking enabled
    ↓
current head recorded
    ↓
wait for one canonical head advance
    ↓
first sweep
```

After a sweep finishes, the node waits for the configured interval before beginning the next cycle.

With the default setting:

```text
--trie-sweeper-interval 6h
```

the next cycle starts approximately six hours after the previous cycle completed.

The interval is not measured from the start of the previous sweep.

---

## 8. Operator profiles

### 8.1 Bounded-history full node

Example:

```text
trie sweeper: enabled
retain blocks: 10,000
interval: 6h
```

This profile prioritizes bounded historical-state retention and reduced long-term trie-storage accumulation.

At the XGR Chain target block time of approximately two seconds:

```text
10,000 blocks × 2 seconds
≈ 20,000 seconds
≈ 5 hours 33 minutes
```

This is only an approximate wall-clock window. Actual retention time depends on real block production.

### 8.2 Longer historical-state window

Operators that require more historical state can increase:

```text
--trie-sweeper-retain-blocks
```

Example:

```text
--trie-sweeper-retain-blocks 100000
```

A larger retention window requires more local storage.

### 8.3 Archive-style node

A node that must preserve historical EVM state for arbitrary old block heights should leave the trie sweeper disabled:

```text
--trie-sweeper=false
```

Block-history retention and historical-state retention are different requirements.

---

## 9. Historical RPC implications

The trie sweeper does not delete canonical block headers, block bodies, transactions, receipts or logs.

It affects historical **EVM state** stored in the immutable trie.

With State Growth Control enabled, historical state older than the configured retention window is not guaranteed to remain locally available.

This affects RPC operations that require execution or state lookup against an older state root, including:

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
```

when an old block selector is used.

A block may therefore still be available through:

```text
eth_getBlockByNumber
eth_getBlockByHash
```

while the complete EVM state associated with that historical block is no longer locally available.

Applications that require arbitrary historical-state queries should use an archive-style node or another indexed historical-state service designed for that purpose.

---

## 10. Storage behavior

State Growth Control reduces accumulation caused by obsolete historical trie versions.

It does **not** impose a fixed maximum database size.

The local trie database can still grow because:

- the current live account set can grow
- contract storage can grow
- new contract code can be deployed
- the configured retention window can contain more state over time
- LevelDB maintains its own storage and compaction structures

The feature should therefore be understood as:

> reclamation of unreachable historical trie and code data

rather than:

> a fixed-size state database

Disk-space reclamation is coupled with LevelDB compaction of ranges in which garbage collection deleted data.

---

## 11. Runtime impact

Garbage collection is performed in bounded batches.

The implementation inserts short pauses between batches so normal block processing remains prioritized over storage cleanup.

A sweep can take significant time on a large database.

This is expected.

The node remains online while the sweep runs.

Operators should monitor:

- block-head progression
- peer health
- CPU utilization
- disk I/O
- free disk space
- trie sweeper logs
- sweep duration

---

## 12. Logging

When enabled, the node reports initialization parameters including:

```text
retainBlocks
interval
trackingFromBlock
workDir
```

A sweep reports its selected canonical range:

```text
fromBlock
toBlock
roots
```

A completed sweep reports statistics including:

```text
generation
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

These values can be used to monitor storage-reclamation behavior over time.

A cycle failure is logged and does not silently redefine canonical chain state.

---

## 13. Disabling the feature

The feature may be disabled by removing:

```text
--trie-sweeper
```

or configuring:

```yaml
trie_sweeper: false
```

Disabling the sweeper prevents future garbage-collection cycles.

It does **not** restore historical trie data that has already been deleted.

If an operator later requires historical state that was previously pruned, that state must be reconstructed from an appropriate source or by rebuilding/resynchronizing the node under an archive-compatible retention policy.

---

## 14. Upgrade classification

State Growth Control was introduced with:

```text
xgr-node v2.1.0
```

Upgrade classification:

| Property | v2.1.0 State Growth Control |
|---|---|
| Consensus change | No |
| EVM execution change | No |
| State-transition change | No |
| Canonical state-root change | No |
| Transaction-format change | No |
| Genesis change | No |
| Fork activation | No |
| Required activation block | No |
| Node-local storage behavior | Yes |
| Historical-state retention behavior | Yes, when enabled |
| Operator configurable | Yes |

Nodes can therefore adopt `v2.1.0` without a coordinated consensus activation block.

---

## 15. Operator checklist

Before enabling State Growth Control:

- confirm the node runs `xgr-node v2.1.0` or later
- confirm the data directory is persistent
- determine the historical-state window required by local applications
- do not enable pruning on a node intended to provide unrestricted archive-state access
- ensure sufficient temporary free disk capacity for normal LevelDB operation and compaction
- monitor the first completed sweep carefully

After enabling:

- verify normal block progression
- verify the node remains synchronized
- inspect trie sweeper completion logs
- confirm the reported `verifiedStateRoot`
- monitor disk usage across multiple sweep cycles
- verify RPC applications do not depend on state older than the configured retention window

---

## 16. Design principle

XGR Chain separates canonical state correctness from local historical-state retention.

The blockchain determines **what the current canonical state is**.

The node operator determines **how much historical state must remain locally queryable**.

State Growth Control makes that retention policy explicit and operationally configurable while preserving the canonical state-transition and consensus model of XGR Chain.
