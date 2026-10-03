# XGR Chain v2.1.0 — Release & Operator Notes

**Document ID:** XGRCHAIN-V2.1.0-RELEASE-NOTES  
**Document status:** Historical release documentation  
**Last reviewed:** 2026-10-03  
**Release:** `xgr-node v2.1.0`  
**Release commit:** `e40e3ebb55c7bb85c8f789343ae3906938e2ed7e`  
**Published:** 2026-08-28  
**Node implementation:** `xgr-network/xgr-node`  
**Primary feature:** State Growth Control — Online State Trie Sweeper  
**Audience:** Node operators, validator operators, RPC operators, infrastructure engineers, auditors

> **Historical document**
>
> This document describes `xgr-node v2.1.0` as it was released.
>
> It must not be interpreted as the current XGRChain node baseline.
>
> The current public node baseline is:
>
> ```text
> xgr-node v3.1.1
> ```
>
> Current operational and protocol documentation should be used for new deployments. This file is retained to document the introduction and original operator model of State Growth Control.

---

## 1. Release status

`xgr-node v2.1.0` was published on:

```text
2026-08-28
```

Release commit:

```text
e40e3ebb55c7bb85c8f789343ae3906938e2ed7e
```

The release introduced **State Growth Control**, implemented as an optional online garbage collector for the immutable EVM state trie.

This feature remained present in subsequent node releases, including the current `v3.1.1` baseline.

For the historical `v2.1.0` release, State Growth Control was:

```text
node-local storage functionality
```

It was not:

- a consensus fork,
- an EVM execution change,
- a transaction-format change,
- a canonical state-transition change,
- a genesis change,
- a staking change,
- a validator-set change.

No network activation block was required for the Trie Sweeper.

---

## 2. Release artifacts

The `v2.1.0` release published:

```text
xgrchain-v2.1.0-linux-amd64
version.txt
sha256sums.txt
```

Linux AMD64 binary SHA-256:

```text
476c3a7fd6bb3a17f166151bd5c9c9c6d79b562826d9d8ca87c989126e16636e
```

Operators using the historical binary should verify the artifact checksum before installation.

---

## 3. What changed in `v2.1.0`

The major operator-facing addition was:

```text
State Growth Control
        ↓
Online State Trie Sweeper
```

When enabled, the production implementation:

1. enabled generation tracking for trie writes,
2. waited for one canonical head advance after tracking activation,
3. selected a configurable recent range of canonical state roots,
4. marked account-trie nodes reachable from those roots,
5. marked storage tries reachable from contract accounts,
6. marked referenced contract code,
7. protected current and immediately previous write generations,
8. scanned LevelDB in bounded ranges,
9. rechecked deletion candidates under the GC write barrier,
10. deleted unreachable trie/code entries,
11. compacted affected LevelDB ranges,
12. captured a fresh canonical head,
13. strictly verified its current canonical state root.

The feature was designed to reclaim obsolete historical trie versions while the node remained online.

---

## 4. Storage objective

XGRChain uses an immutable, content-addressed EVM state trie.

Normal state updates create new trie versions.

Without reclamation, obsolete historical nodes can remain physically present in the local database indefinitely.

State Growth Control introduced the ability to define:

```text
how many recent canonical state roots
must remain locally reachable
```

and reclaim trie/code data that was no longer reachable from those roots or protected by concurrent-write generations.

The feature did not impose a fixed maximum database size.

Current live state could continue to grow.

---

## 5. Default configuration

The Trie Sweeper was disabled by default in `v2.1.0`.

CLI flags:

```text
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Defaults:

| Setting | `v2.1.0` default |
| --- | ---: |
| Trie Sweeper enabled | `false` |
| Retained canonical blocks | `10,000` |
| Interval | `6h` |

Example:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --trie-sweeper \
  --trie-sweeper-retain-blocks 10000 \
  --trie-sweeper-interval 6h
```

Equivalent configuration-file fields:

```yaml
trie_sweeper: true
trie_sweeper_retain_blocks: 10000
trie_sweeper_interval: 6h
```

---

## 6. Validation requirements

When enabled, `v2.1.0` required:

```text
trie_sweeper_retain_blocks > 0
```

and:

```text
trie_sweeper_interval > 0
```

The implementation additionally required:

- a persistent data directory,
- an initialized canonical chain head,
- LevelDB-backed immutable-trie storage.

GC working data was created below:

```text
<data-dir>/trie-gc
```

with marker metadata under:

```text
<data-dir>/trie-gc/marks
```

---

## 7. Retention semantics

For one sweep:

```text
toBlock = current canonical head
```

and:

```text
fromBlock =
    max(
        0,
        toBlock + 1 - retainBlocks
    )
```

The state roots of canonical blocks inside this range were collected.

Duplicate state roots were de-duplicated.

All trie/code data reachable from those roots was preserved.

This meant the configured number represented a retained canonical-state-root window.

It did **not** mean that every physical trie node older than that exact block age would necessarily be deleted.

Trie nodes can be shared across multiple state versions.

---

## 8. Production sweep implementation

The production server already used:

```text
SweepLive(...)
```

in `v2.1.0`.

This path deliberately avoided holding one long-lived LevelDB snapshot across the complete database sweep.

Instead it:

- marked against the live immutable trie,
- scanned LevelDB in bounded chunks,
- released iterators before deletion,
- deleted candidates in batches,
- compacted processed ranges where data had been reclaimed.

This behavior was already part of the original `v2.1.0` State Growth Control implementation.

---

## 9. Concurrent-write protection

Every normal trie write was generation marked before entering the trie database.

The sweeper preserved:

```text
current write generation
+
immediately previous write generation
```

in addition to everything reachable from retained canonical state roots.

This one-generation grace protected state written immediately before a new sweep generation but canonicalized shortly afterward.

Deletion candidates were rechecked while holding the GC write barrier.

A key that became protected after the initial scan was therefore retained.

---

## 10. Startup synchronization

The first sweep intentionally did not begin immediately after process startup.

Sequence:

```text
node starts
    ↓
GC write tracking enabled
    ↓
current canonical head recorded
    ↓
wait for at least one canonical head advance
    ↓
first sweep begins
```

This closed the race involving state transitions already in flight when tracking became active.

---

## 11. Mark-before-delete safety

During the mark phase, no trie data was deleted.

The implementation traversed the retained roots and marked:

- account trie nodes,
- contract storage trie nodes,
- contract code referenced by retained accounts.

A missing required trie node caused marking to fail.

Contract code was also validated against its expected code hash.

Only after marking completed did the sweep begin candidate deletion.

---

## 12. Bounded database scanning

`v2.1.0` scanned LevelDB using bounded iterators.

The production path iterated through first-byte ranges:

```text
0x00
...
0xff
```

rather than holding one iterator over the entire database for the full sweep duration.

This prevented a long-running sweep from unnecessarily pinning obsolete LevelDB SSTables.

---

## 13. Internal batching

Historical `v2.1.0` implementation defaults included:

| Internal setting | Value |
| --- | ---: |
| Delete batch | `256` |
| Scan batch | `4096` |
| Mark batch | `2048` |
| GC pause | `10 ms` |

These were implementation constants rather than public operator CLI parameters.

Small batches and pauses were intended to prioritize normal block processing over garbage-collection work.

---

## 14. LevelDB compaction

The production server invoked the Trie Sweeper with compaction enabled.

Affected first-byte ranges were compacted after scan/delete processing when entries had actually been deleted.

This allowed LevelDB to physically reclaim storage after logical deletion.

Disk usage was not guaranteed to fall immediately or by a fixed amount after one cycle.

---

## 15. Post-sweep integrity verification

After deletion and compaction, `v2.1.0` captured a fresh canonical head.

Its state root was checked through the strict trie hash checker.

The checker:

- required referenced hash-linked nodes to exist,
- reconstructed the trie,
- recalculated the root,
- compared it with the current block header's state root.

Failure produced an integrity error.

The sweeper did not silently substitute missing trie branches with empty state.

---

## 16. Sweep scheduling

The first sweep occurred after write tracking had synchronized with one canonical head advance.

After a completed cycle, the node waited:

```text
trie_sweeper_interval
```

before starting the next one.

Default:

```text
6h
```

Therefore the schedule was:

```text
sweep
    ↓
sweep completes
    ↓
wait 6h
    ↓
next sweep
```

not a fixed six-hour interval measured from process start.

---

## 17. Historical-state implications

State Growth Control affected historical **EVM state**, not canonical block history.

The sweeper did not target normal canonical:

- block headers,
- block bodies,
- transactions,
- receipts,
- logs.

However, once old trie state had been reclaimed, historical state-dependent requests were no longer guaranteed to work locally.

Examples include old-block calls to:

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
```

A node could therefore still return:

```text
eth_getBlockByNumber
```

for an old block while no longer retaining the complete EVM state associated with that block.

---

## 18. Archive-style operation

An operator requiring arbitrary historical state was expected to leave the Trie Sweeper disabled or use a retention strategy appropriate to that workload.

For example:

```text
archive-style RPC
    → Trie Sweeper disabled
```

A bounded-history full node and an archive-style node could follow the same XGRChain consensus while retaining different amounts of historical state.

---

## 19. Consensus compatibility

State Growth Control did not affect:

```text
transaction validity
EVM execution
canonical state calculation
IBFT voting
validator membership
staking
block validity
chain ID
genesis
```

Nodes with different Trie Sweeper settings could therefore participate in the same network.

No coordinated hardfork activation was required.

---

## 20. Upgrade procedure at the time

For the historical `v2.1.0` source release:

```bash
git clone https://github.com/xgr-network/xgr-node.git
cd xgr-node

git fetch --all --tags
git checkout v2.1.0

git rev-parse HEAD
```

Expected commit:

```text
e40e3ebb55c7bb85c8f789343ae3906938e2ed7e
```

For a versioned source build, use:

```bash
make -f scripts/Makefile build
```

The build target embedded:

- release tag/version,
- commit,
- branch,
- build time.

Check:

```bash
./xgrchain version
```

No replacement mainnet genesis was required solely to adopt the Trie Sweeper feature.

---

## 21. Incremental operator rollout

An operator could upgrade to `v2.1.0` while leaving:

```text
--trie-sweeper
```

disabled.

A conservative rollout therefore allowed:

```text
install v2.1.0
        ↓
verify normal node operation
        ↓
enable Trie Sweeper separately
        ↓
monitor first sweep
```

Validator operators did not need a coordinated activation height for this storage feature.

---

## 22. Monitoring

Operators were expected to monitor:

- canonical head progression,
- synchronization,
- peer health,
- CPU,
- memory,
- disk I/O,
- free disk capacity,
- sweep duration,
- Trie Sweeper logs.

A completed cycle reported:

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

---

## 23. Example healthy lifecycle

```text
Trie sweeper enabled
        ↓
write tracking synchronized
        ↓
Trie sweeper cycle started
        ↓
mark retained roots
        ↓
scan/delete/compact
        ↓
strict current-head verification
        ↓
Trie sweeper cycle completed
```

Operators should verify continued block progression during and after the cycle.

---

## 24. Disabling State Growth Control

Removing:

```text
--trie-sweeper
```

or configuring:

```yaml
trie_sweeper: false
```

prevented future sweep cycles.

It did not reconstruct historical state that had already been deleted.

This remains an important characteristic of the feature.

---

## 25. Recovery of previously pruned state

If an operator later required historical state already reclaimed by the Trie Sweeper, disabling pruning alone was insufficient.

Recovery required an appropriate source, for example:

- resynchronizing/rebuilding with an archive-compatible policy,
- restoring an appropriate backup,
- querying another archive-style node.

The Trie Sweeper was not designed as a reversible compression layer.

---

## 26. Release classification

| Property | `v2.1.0` State Growth Control |
| --- | --- |
| Consensus change | No |
| EVM execution change | No |
| State-transition change | No |
| Canonical state-root change | No |
| Transaction-format change | No |
| Genesis change | No |
| Staking change | No |
| Validator-set change | No |
| Fork activation | No |
| Required activation block | No |
| Node-local storage behavior | Yes |
| Historical-state retention behavior | Yes |
| Operator configurable | Yes |

---

## 27. XGR2.0 terminology

At the time of this release, existing documentation used **XGR2.0** terminology for the delegated-PoS network generation.

That historical terminology should not be confused with the node software tag:

```text
XGR2.0
    = historical network / consensus-generation terminology

v2.1.0
    = node software release
```

Likewise, current documentation should not infer current software version from older XGR2.0 references.

---

## 28. Relationship to current releases

`v2.1.0` is retained in documentation because it introduced State Growth Control.

It is no longer the current node baseline.

Current baseline as of this document review:

```text
xgr-node v3.1.1
```

Current technical behavior of the Trie Sweeper is documented in:

```text
docs/chain/XGRCHAIN_State_Storage_and_Retention.md
```

Current node-operation guidance is documented in:

```text
docs/chain/XGRCHAIN_Node_Operation.md
```

When current documentation and this historical release note differ, use the current documentation for new production deployments.

---

## 29. Historical operator checklist

Before enabling State Growth Control under `v2.1.0`:

- verify the exact `v2.1.0` binary/source,
- verify the release commit,
- use a persistent data directory,
- determine required historical-state retention,
- do not prune an archive endpoint unintentionally,
- ensure sufficient free disk capacity,
- monitor the first complete sweep.

After enabling:

- verify canonical head progression,
- verify node synchronization,
- inspect completion logs,
- check `verifiedHead`,
- check `verifiedStateRoot`,
- monitor disk I/O,
- verify dependent applications do not require state outside the retained window.

---

## 30. Historical significance

`xgr-node v2.1.0` established the XGRChain storage model in which:

```text
canonical chain correctness
```

is separated from:

```text
operator-selected historical-state retention
```

The blockchain determines the canonical state.

The operator determines how much historical EVM state must remain locally available.

That separation remains part of the modern XGRChain node architecture.
