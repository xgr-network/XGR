# XGR Chain v2.1.0 — Release & Operator Notes

**Document ID:** XGRCHAIN-V2.1.0-RELEASE-NOTES  
**Last updated:** 2026-09-06  
**Audience:** Node operators, validator operators, RPC operators, infrastructure engineers, auditors  
**Release:** `xgr-node v2.1.0`  
**Node implementation:** `xgr-network/xgr-node`  
**Primary feature:** State Growth Control — Online State Trie Sweeper

---

## 1. Release status

`xgr-node v2.1.0` is the current public node release baseline documented by XGR Network.

The release introduces **State Growth Control**, an optional online garbage collector for the immutable EVM state trie.

This is a node-local storage feature.

It is not:

- a consensus fork
- an EVM execution change
- a transaction-format change
- a state-transition change
- a genesis change
- a staking change
- a validator-set change

No activation block is required.

---

## 2. What changes in v2.1.0

When enabled, the Online State Trie Sweeper periodically:

1. selects a configurable recent range of canonical state roots
2. marks trie nodes and contract code reachable from those roots
3. protects concurrent writes through GC generations
4. removes unreachable trie/code entries
5. compacts affected LevelDB ranges
6. performs a strict post-sweep integrity check against a freshly captured canonical state root

The feature is designed to reduce long-term accumulation of obsolete historical trie versions while the node remains online.

It does not impose a fixed maximum database size. Current live state can still grow.

---

## 3. Default configuration

The feature is disabled by default.

CLI flags:

```text
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Defaults:

| Setting | Default |
|---|---:|
| Trie sweeper enabled | `false` |
| Retained canonical blocks | `10000` |
| Interval between completed cycles | `6h` |

Example:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --trie-sweeper \
  --trie-sweeper-retain-blocks 10000 \
  --trie-sweeper-interval 6h
```

Equivalent configuration fields:

```yaml
trie_sweeper: true
trie_sweeper_retain_blocks: 10000
trie_sweeper_interval: 6h
```

---

## 4. Upgrade procedure

No chain configuration or genesis replacement is required for this feature.

Normal binary upgrade flow:

```bash
git clone https://github.com/xgr-network/xgr-node.git
cd xgr-node
git fetch --all --tags
git checkout v2.1.0
go build -o xgrchain .
./xgrchain version
```

Operators may first run `v2.1.0` with the trie sweeper disabled and enable State Growth Control separately after validating normal node operation.

Validator operators do not need a coordinated activation height for this release feature because state retention does not participate in consensus.

---

## 5. Historical-state implications

State Growth Control affects historical **EVM state**, not canonical block history.

The sweeper does not remove:

- canonical block headers
- canonical block bodies
- transactions
- receipts
- logs

However, when old trie state has been reclaimed, historical state-dependent RPC requests are not guaranteed to remain locally available.

Affected request classes include historical calls to:

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
```

A block can therefore remain available through `eth_getBlockByNumber` or `eth_getBlockByHash` while the full EVM state for that old block is no longer present locally.

Archive-style nodes that require arbitrary historical-state access should leave the trie sweeper disabled or choose a retention policy appropriate to that requirement.

---

## 6. Safety model

The production sweeper is designed for live node operation.

Key protections include:

- generation tracking for concurrent trie writes
- one-generation grace for recently written state
- startup synchronization before the first sweep
- mark-before-delete traversal
- short-lived bounded LevelDB iterators
- candidate rechecking under the GC write barrier before deletion
- range compaction only after scan/delete processing
- strict verification of the current canonical state root after every completed sweep

A sweep failure is logged and does not redefine canonical chain state.

---

## 7. Monitoring

Operators should monitor:

- canonical head progression
- sync state
- peer health
- disk I/O
- free disk capacity
- CPU usage
- sweep duration
- trie sweeper completion logs

Completed cycles report values including:

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

## 8. Compatibility with XGR2.0 terminology

`v2.1.0` is the node software release.

Existing documentation references to **XGR2.0** that describe the delegated-PoS network generation, PoS activation at block `5446500`, consensus configuration or genesis-era protocol transition remain valid.

Do not reinterpret those XGR2.0 references as obsolete merely because the public node binary is now `v2.1.0`.

The distinction is:

```text
XGR2.0 = network / consensus generation terminology
v2.1.0 = public node software release
```

---

## 9. Canonical technical reference

Detailed State Growth Control behavior is documented in:

```text
docs/chain/XGRCHAIN_State_Storage_and_Retention.md
```

For general chain behavior, consensus, staking and network configuration, use the existing dedicated XGR Chain documents together with this release note where a document still identifies an earlier release baseline.
