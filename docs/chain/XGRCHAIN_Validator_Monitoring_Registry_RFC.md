# XGR Chain — Validator Monitoring Registry RFC

**Document ID:** XGRCHAIN-POS-VMR-RFC  
**Last updated:** 2026-05-03  
**Audience:** protocol developers, monitoring developers, validator dashboard developers, auditors  
**Implementation status:** Spec only / RFC  
**Source of truth:** original `xgrchain/docs/pos-deterministic-monitoring-rfc.md`; not active implementation on `PoS_3`

---

## 1. Scope

This document preserves the design idea from the original deterministic PoS monitoring RFC.

It is **not** active XGR Chain implementation documentation.

It describes a possible future **Validator Monitoring Registry (VMR)** that would provide canonical on-chain validator monitoring data for:

- validator state
- jailed/slashed status
- epoch metadata
- epoch reward distribution
- per-validator epoch reward/slash deltas
- deterministic monitoring reads
- fork-safe monitoring activation

Current active PoS monitoring is documented in:

- `XGRCHAIN_Staking_PoS_Model.md`
- `XGRCHAIN_Staking_PoS_Endpoint_Reference.md`

---

## 2. Non-implementation warning

The following RFC functions are not currently documented as active `PoS_3` implementation:

```solidity
getValidatorState(address)
getEpochMeta(uint64)
getEpochDistribution(uint64)
getValidatorEpochDelta(uint64,address)
getCurrentEpoch()
getValidatorSetRoot(uint64)
```

Do not expose these as public API or dashboard requirements unless and until the VMR design is implemented and fork-activated.

---

## 3. Problem statement

The current staking/validator ABI can expose validator and stake information, but a fully deterministic monitoring model benefits from a single canonical state source for:

- `isJailed(validator)`
- `isSlashed(validator, epoch)`
- epoch reward totals
- per-validator reward/slash deltas
- finalized epoch metadata
- validator set roots

Without a canonical on-chain monitoring source, clients may reconstruct state from events, logs or mixed data sources.

That creates risks:

| Risk | Meaning |
|---|---|
| non-exactness | clients interpret events rather than read canonical state |
| reorg sensitivity | event scans can drift across competing branches |
| client drift | different off-chain implementations may aggregate differently |
| unclear finality | dashboards may show non-final monitoring data as final |

---

## 4. Proposed VMR concept

The RFC proposes a dedicated deterministic storage owner:

```text
Validator Monitoring Registry (VMR)
```

Possible implementation forms:

| Option | Description |
|---|---|
| staking contract extension | VMR storage and reads live inside staking contract |
| separate registry contract | dedicated registry written by deterministic chain logic |
| system storage owner | node/consensus writes canonical state into reserved system storage |

The core requirement is:

```text
VMR writes must be deterministic and consensus-derived.
```

No off-chain oracle input is allowed.

---

## 5. Proposed read API

Possible VMR v1 read API:

```solidity
function getValidatorState(address v)
    external
    view
    returns (
        uint256 stake,
        bool active,
        bool jailed,
        bool slashed,
        uint64 lastUpdateEpoch
    );

function getEpochMeta(uint64 epoch)
    external
    view
    returns (
        uint64 startBlock,
        uint64 endBlock,
        bool finalized
    );

function getEpochDistribution(uint64 epoch)
    external
    view
    returns (
        uint256 totalDistributed,
        bytes32 distributionRoot
    );

function getValidatorEpochDelta(uint64 epoch, address v)
    external
    view
    returns (
        int256 stakeDelta,
        uint256 reward,
        uint256 slashAmount
    );

function getCurrentEpoch()
    external
    view
    returns (uint64);

function getValidatorSetRoot(uint64 epoch)
    external
    view
    returns (bytes32);
```

These are RFC targets, not current active endpoints.

---

## 6. Proposed VMR v1 minimal ABI

A narrower first implementation could expose:

```solidity
function isJailed(address v) external view returns (bool);
function isSlashedInEpoch(address v, uint64 epoch) external view returns (bool);
function getSlashAmount(address v, uint64 epoch) external view returns (uint256);
function getEpochRewardTotal(uint64 epoch) external view returns (uint256);
function getEpochValidatorReward(address v, uint64 epoch) external view returns (uint256);
function getEpochStartEnd(uint64 epoch) external view returns (uint64 start, uint64 end);
function getCurrentEpoch() external view returns (uint64);
function getDataVersion() external pure returns (uint32);
```

Proposed audit events:

```solidity
event ValidatorJailed(address indexed validator, uint64 indexed epoch, bytes32 reasonCode);
event ValidatorSlashed(address indexed validator, uint64 indexed epoch, uint256 amount, bytes32 reasonCode);
event EpochFinalized(uint64 indexed epoch, uint256 totalReward, bytes32 distributionRoot);
```

Events are for audit/tracing. The canonical truth would be storage reads.

---

## 7. Proposed storage model

Suggested VMR v1 storage:

```solidity
mapping(address => bool) jailed;

struct EpochMeta {
    uint64 start;
    uint64 end;
    bool finalized;
    uint256 totalReward;
    bytes32 distributionRoot;
}

mapping(uint64 => EpochMeta) epochMeta;

struct ValidatorEpochData {
    uint256 reward;
    uint256 slashAmount;
    bool slashed;
}

mapping(uint64 => mapping(address => ValidatorEpochData)) epochValidatorData;
```

Rule:

```text
epochMeta[epoch].finalized == true
```

means the epoch snapshot is immutable/write-once.

---

## 8. Deterministic write points

VMR writes must happen only in deterministic consensus/state-transition paths.

Possible write points:

| Write point | Data written |
|---|---|
| slash/jail decision | jailed/slashed status, slash amount, reason |
| epoch finalization | epoch metadata, total reward, distribution root, per-validator reward |
| validator set transition | validator set root / epoch validator state |

No after-the-fact off-chain corrections.

---

## 9. Epoch snapshot model

At epoch finalization, the implementation would atomically write:

- `EpochMeta[epoch]`
- `EpochDistribution[epoch]`
- per-validator reward/slash data
- optional validator-set root
- optional distribution root

Goal:

```text
"last round distributed" and per-validator epoch values become uniquely versioned by epoch.
```

---

## 10. Fork-safety model

Because VMR state would live in canonical chain state:

- losing branches are discarded by normal state reorg behavior
- RPC reads canonical head/finalized state
- no external event database is needed for truth
- replaying the same block must produce the same VMR storage root

RPC could expose two read modes:

| Mode | Meaning |
|---|---|
| `head` | reads current canonical head |
| `finalized` | reads only finalized/confirmed epoch state |

---

## 11. Fork activation plan

VMR should be activated by explicit fork parameter.

Suggested parameters:

```text
vmrForkBlock
vmrShadowStartBlock
```

Behavior:

| Phase | Behavior |
|---|---|
| before shadow | no VMR writes |
| shadow phase | write VMR, but RPC does not use it as source of truth |
| active phase | RPC reads only VMR for exact monitoring fields |

Before activation:

```text
exact=false
```

After activation:

```text
exact=true
```

for fields backed by VMR.

---

## 12. Migration plan

### Phase 0 — Preparation

- finalize storage schema
- finalize ABI
- define invariants
- benchmark gas cost
- define fork parameters

### Phase 1 — Shadow writes

- write VMR state
- keep old RPC behavior
- compare old derived values with VMR values
- log divergence

### Phase 2 — Fork activation

- switch RPC to VMR as source of truth
- remove heuristics for VMR-backed fields
- expose exactness flags

### Phase 3 — Cleanup

- remove old aggregation paths
- update dashboards
- update documentation
- keep audit events for traceability

---

## 13. Determinism and safety invariants

Required invariants:

1. `epoch.finalized => epoch.startBlock <= epoch.endBlock`
2. `sum(validator.reward for epoch) == epoch.totalDistributed`
3. `validator.slashed => validator.slashAmount(epoch) > 0`
4. jail status changes only through defined transitions
5. epoch finalization is idempotent
6. re-executing the same block produces the same storage root
7. VMR writes are deterministic and chain-state-derived
8. no off-chain oracle input affects VMR writes
9. RPC exactness flags are true only when backed by VMR or equivalent canonical state

---

## 14. RPC target model after VMR

After implementation, `eth_getPosValidatorsOverview` could expose exact values for:

- jailed/slashed status
- last distributed reward
- jailed/slashed counts
- validator epoch reward
- delegator epoch reward
- epoch start/end/finalized state
- source epoch
- data version
- finalized/head read mode

Possible additional fields:

```json
{
  "dataVersion": "vmr-v1",
  "sourceEpoch": "0x10",
  "isFinalizedView": true,
  "exact": true
}
```

---

## 15. Test strategy

Required tests:

| Test category | Purpose |
|---|---|
| state transition tests | slash/jail/finalize write expected slots |
| replay tests | same block execution yields same root |
| reorg tests | losing branch VMR state is discarded |
| fork activation tests | pre/post fork behavior |
| invariant tests | sum checks, finalization idempotency |
| RPC tests | exact flags and VMR read behavior |

---

## 16. Definition of Done

VMR should be considered complete only when:

- jail/slash/reward/epoch data are exactly readable from canonical state
- RPC exactness flags are backed by canonical storage
- replay/reorg/fork tests pass
- invariant checks are mandatory in CI
- dashboards no longer infer these fields from logs/events
- documentation marks VMR-backed fields clearly

---

## 17. Current documentation decision

This RFC should not be merged into active chain documentation as if implemented.

Recommended placement:

```text
XGR/docs/research/XGRCHAIN_Validator_Monitoring_Registry_RFC.md
```

or equivalent research/spec directory.

If no research/spec section is maintained, the old RFC can be deleted from `xgrchain` without active replacement.
