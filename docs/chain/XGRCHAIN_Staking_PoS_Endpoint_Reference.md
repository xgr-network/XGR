# XGR Chain — Staking / PoS JSON-RPC Endpoint Reference

**Document ID:** XGRCHAIN-STAKING-POS-RPC  
**Last updated:** 2026-10-03  
**Audience:** RPC integrators, explorer developers, dashboard developers, validator operators, backend developers, auditors  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Implementation source:** `xgr-network/xgr-node`, `jsonrpc/eth_pos_overview.go`  
**Mainnet genesis source:** `xgr-network/XGR`, `genesis/mainnet/genesis.json`  
**Scope:** Public XGR-specific PoS monitoring JSON-RPC

---

## 1. Scope

This document describes the XGR-specific staking and PoS JSON-RPC methods implemented on the `Eth` endpoint in `xgr-node v3.1.1`.

The two supported PoS data methods are:

    eth_getPosValidatorsOverview
    eth_getPosValidatorDelegators

The node also currently registers the deprecated legacy compatibility method:

    eth_getBeaconTimeStatus

These methods use the Ethereum-style:

    eth_*

namespace but are not standard Ethereum JSON-RPC methods.

This reference intentionally distinguishes between:

- fields actually populated by the current code,
- fields defined in response structs but omitted because they are not populated,
- exact versus approximate/historical monitoring information,
- current staking state versus historical epoch analytics.

---

## 2. Mainnet PoS context

The published XGRChain mainnet consensus schedule is:

| Phase | Type | Validator type | From | To | Deployment |
| --- | --- | --- | ---: | ---: | ---: |
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Current phase | `PoS` | `bls` | `5446500` | n/a | `5446500` |

PoS activation:

    decimal: 5446500
    hex:     0x531b64

PoS deployment:

    5446500

Validator limits:

| Field | Value |
| --- | ---: |
| `minValidatorCount` | `4` |
| `maxValidatorCount` | `25` |

Epoch configuration:

| Field | Value |
| --- | ---: |
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Derived macro epoch | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

The PoS RPC derives macro epoch size as:

    microEpochSize × macroEpochMicroFactor

For mainnet:

    25 × 40 = 1000 blocks

---

## 3. Method summary

| JSON-RPC method | Go method | Status | Purpose |
| --- | --- | --- | --- |
| `eth_getPosValidatorsOverview` | `GetPosValidatorsOverview` | Active | Validator, stake, epoch and PoS monitoring overview |
| `eth_getPosValidatorDelegators` | `GetPosValidatorDelegators` | Active | Delegation and pool information for one validator |
| `eth_getBeaconTimeStatus` | `GetBeaconTimeStatus` | Deprecated | Legacy compatibility status only |

No other method should be documented as part of the supported `v3.1.1` PoS monitoring API without implementation verification.

---

## 4. Encoding rules

Numeric values represented by `argUint64` and `argBig` use Ethereum JSON-RPC quantity encoding.

Examples:

    0        -> "0x0"
    25       -> "0x19"
    1000     -> "0x3e8"
    5446500  -> "0x531b64"

Rules:

- hexadecimal,
- `0x` prefix,
- no unnecessary leading zeros,
- stake amounts are in wei,
- reward amounts are in wei,
- basis-point values are integer quantities,
- addresses use normal Ethereum address encoding,
- booleans are JSON booleans,
- omitted `omitempty` pointer fields are not returned.

Native denomination:

    1 XGR = 10^18 wei

---

# `eth_getPosValidatorsOverview`

## 5. Method signature

Implementation:

```go
func (e *Eth) GetPosValidatorsOverview(
    reportEpoch *string,
) (interface{}, error)
```

JSON-RPC:

    eth_getPosValidatorsOverview

---

## 6. Parameters

The endpoint accepts zero or one parameter.

| Index | Type | Required | Allowed values |
| ---: | --- | --- | --- |
| `0` | string | No | `current`, `lastFinalized` |

Default:

    current

when no parameter is supplied.

### Current epoch

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": []
}
```

Equivalent explicit call:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["current"]
}
```

### Last finalized epoch

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["lastFinalized"]
}
```

Invalid values return:

    invalid reportEpoch "<value>" (expected "current" or "lastFinalized")

---

## 7. PoS activation guard

The endpoint resolves the first configured:

    type = "PoS"

IBFT phase and selects its lowest `from` block.

For mainnet:

    posFromBlock = 5446500

If the current head is below that block:

    PoS is not active yet (activates at block 5446500)

is returned.

Current mainnet is already beyond this activation boundary.

---

## 8. Epoch semantics

The endpoint calculates the epoch as:

    if block == 0:
        epoch = 0

    else if block % epochSize == 0:
        epoch = block / epochSize

    else:
        epoch = block / epochSize + 1

For PoS mainnet:

    epochSize = 1000

Current epoch start:

    (epoch - 1) × epochSize + 1

Current epoch end while still in progress:

    current head block

---

## 9. Top-level response

Current `v3.1.1` response type:

    posOverviewResponse

Fields:

| JSON field | Type | Meaning |
| --- | --- | --- |
| `blockNumber` | quantity | Current local canonical head |
| `epochSize` | quantity | Current macro epoch size |
| `microEpochSize` | quantity | Effective micro-epoch size |
| `currentMicroEpoch` | quantity | Current micro-epoch index |
| `currentMicroEpochStartBlock` | quantity | Current micro-epoch first block |
| `currentMicroEpochEndBlock` | quantity | Current micro-epoch nominal final block |
| `currentEpoch` | quantity | Current macro epoch |
| `lastFinalizedEpoch` | quantity | Last finalized macro epoch context |
| `reportedEpoch` | quantity | Epoch selected by `reportEpoch` |
| `reportedEpochStartBlock` | quantity | Reported epoch start |
| `reportedEpochEndBlock` | quantity | Reported epoch end/context |
| `currentEpochPendingRewards` | quantity | Current FeePool balance |
| `stakingContractBalance` | quantity | Current staking-contract balance |
| `minimumNumValidators` | quantity | Contract minimum validator count |
| `maximumNumValidators` | quantity | Contract maximum validator count |
| `validatorThreshold` | quantity | Staking-contract validator threshold |
| `totalCurrentStake` | quantity | Sum of current validator self stake |
| `totalValidatorSelfStake` | quantity | Sum of validator self stake |
| `totalDelegatedRawStake` | quantity | Sum of raw delegated stake |
| `totalDelegatedActiveStake` | quantity | Sum of active delegated stake |
| `totalActiveCurrentStake` | quantity | Self stake plus active delegated stake |
| `rewardIneligibleCount` | quantity | Validators currently computed reward-ineligible for reported context |
| `slashedCount` | quantity | Slash count exposed by current implementation |
| `rewardIneligibleStatusExact` | boolean | Exactness marker |
| `slashStatusExact` | boolean | Exactness marker |
| `lastRoundStakeExact` | boolean | Exactness marker |
| `lastRoundDistributedStake` | quantity | Current implementation placeholder value |
| `monitoringNotes` | string[] | Implementation caveats |
| `validators` | array | Validator details |
| `posActive` | boolean | Whether PoS is active |
| `posFromBlock` | quantity | First configured PoS block |

---

## 10. Fixed exactness values in `v3.1.1`

Current implementation sets:

    rewardIneligibleStatusExact = true
    slashStatusExact            = false
    lastRoundStakeExact         = false
    lastRoundDistributedStake   = 0

The current overview loop also sets:

    slashed = false

for every returned validator.

Therefore:

> `slashed` and `slashedCount` must not be interpreted as exact historical slash information.

The endpoint explicitly tells clients:

    slashStatusExact = false

---

## 11. Current epoch pending rewards

`currentEpochPendingRewards` is read from the live:

    FeePool

account balance at the current state root.

It represents the live pool pending distribution at the next applicable epoch processing point.

It is not finalized historical reward accounting for an earlier epoch.

---

## 12. Staking-contract balance

`stakingContractBalance` is the live native-token balance of the staking contract.

It can help operators identify inconsistencies between:

- recorded stake,
- reward accounting,
- actual contract balance.

It should not be interpreted as one validator's stake balance.

---

# Validator entries

## 13. Validator response fields

Each `validators[]` item can contain:

| Field | Meaning |
| --- | --- |
| `address` | Validator address |
| `joinedAtBlock` | Recorded validator join block |
| `joinEffectiveAtBlock` | Derived next macro-epoch activation boundary |
| `currentStake` | Current self stake |
| `selfStake` | Current self stake |
| `delegatedRawStake` | Raw delegated stake |
| `delegatedActiveStake` | Currently active delegated stake |
| `totalActiveCurrentStake` | Self + active delegated stake |
| `currentlyValidating` | Membership in current consensus-header validator set |
| `stakingActive` | Current staking-contract active flag |
| `deactivatedAtBlock` | Recorded deactivation block |
| `deactivateEffectiveAtBlock` | Derived macro-epoch deactivation boundary |
| `unstakeAvailableAtBlock` | Derived unstake boundary |
| `canUnstakeNow` | Whether current contract/epoch conditions allow unstaking |
| `wasValidatorLastEpoch` | Validator presence in last-finalized context |
| `rewardIneligible` | Current endpoint-computed eligibility result |
| `slashed` | Non-exact current compatibility field |
| `microNominalWeight` | Current nominal micro-epoch weight |
| `microEffectiveWeight` | Current effective micro-epoch weight |
| `microInactivity` | Current inactivity counter |
| `proposalUptimeLast3EpochsBps` | Rolling proposer uptime in basis points |
| `proposalUptimeLast10EpochsBps` | Rolling proposer uptime in basis points |
| `proposalUptimeLast3EpochsPercent` | Integer percentage |
| `proposalUptimeLast10EpochsPercent` | Integer percentage |
| `proposalUptimeLast3EpochsObserved` | Observed proposer duties |
| `proposalUptimeLast10EpochsObserved` | Observed proposer duties |

Fields marked `omitempty` appear only when populated.

---

## 14. `currentlyValidating`

This is one of the most important fields in the endpoint.

The current code derives it strictly from:

    current consensus header validator snapshot

Conceptually:

    currentlyValidating =
        validator address exists
        in current IBFT header validator set

There is deliberately no stake-based heuristic fallback.

Therefore:

    stakingActive = true

does not necessarily mean:

    currentlyValidating = true

---

## 15. `stakingActive`

`stakingActive` comes from current staking-contract validator information.

It describes staking lifecycle state.

It does not alone prove current IBFT voting authority.

Use:

    currentlyValidating

for current consensus-set membership.

---

## 16. Join activation

When `joinedAtBlock` is available, the endpoint derives:

    joinEpoch =
        joinedAtBlock / epochSize

    joinEffectiveAtBlock =
        (joinEpoch + 1) × epochSize

This exposes the deterministic macro-epoch boundary used for validator lifecycle visibility.

---

## 17. Deactivation and unstaking

When a non-zero `deactivatedAtBlock` exists:

    deactEpoch =
        deactivatedAtBlock / epochSize

The endpoint derives:

    deactivateEffectiveAtBlock =
        (deactEpoch + 1) × epochSize

and:

    unstakeAvailableAtBlock =
        (deactEpoch + 1) × epochSize

`canUnstakeNow` additionally requires the validator to be inactive and the current contract epoch to have advanced beyond the deactivation epoch.

---

## 18. `wasValidatorLastEpoch`

The endpoint first attempts to obtain validator membership from epoch-keyed PoS state.

If that state is unavailable, it falls back to the consensus-header validator snapshot at the last-finalized epoch boundary.

This behavior is explicitly called out in `monitoringNotes`.

---

## 19. Reward eligibility

`rewardIneligible` is computed only when the validator was part of the reported epoch validator set.

The endpoint reads:

    proposer slots
    missed proposer slots

and calculates:

    okSlots = slots - missed

The validator is considered reward-ineligible when:

    okSlots × 10 < slots × 8

Equivalent threshold:

    successful proposer duties < 80%

If no proposer slots are recorded:

    rewardIneligible = false

---

## 20. Rolling proposer uptime

The endpoint exposes rolling proposer-duty reliability over:

    3 epochs
    10 epochs

These metrics are not lifetime validator uptime.

They are based on observed proposer duties.

Fields include:

    proposalUptimeLast3EpochsBps
    proposalUptimeLast10EpochsBps
    proposalUptimeLast3EpochsPercent
    proposalUptimeLast10EpochsPercent
    proposalUptimeLast3EpochsObserved
    proposalUptimeLast10EpochsObserved

If no proposer duties were observed:

    Observed = 0

and the corresponding uptime fields are omitted rather than fabricating:

    100%

---

## 21. Micro-epoch weight fields

The endpoint reads current PoS-system-state values for:

    microNominalWeight
    microEffectiveWeight
    microInactivity

These fields expose current micro-epoch uptime accounting used by the weighted PoS path.

They are returned when at least one corresponding stored value is non-zero.

---

## 22. Effective micro-epoch size

The chain configuration defines:

    microEpochSize = 25

The endpoint applies a runtime safety check:

    if microEpochSize < currentValidatorCount:
        effective microEpochSize = 0

For current mainnet configuration:

    max validators = 25
    microEpochSize = 25

so the configured maximum does not exceed the micro-epoch size.

---

## 23. Reward fields defined but not populated

The validator response struct still defines:

    reportedEpochReward
    reportedEpochRewardValidatorNet
    reportedEpochRewardCommission
    reportedEpochRewardDelegatorsNet

Current `v3.1.1` overview code does not assign these fields.

Tests explicitly expect:

    ReportedEpochReward == nil

Because they use:

    omitempty

they are not returned in normal JSON output.

Clients must not depend on them.

---

## 24. Historical rewards and slashing

Current implementation comments and monitoring notes explicitly state that historical:

    rewards
    slashes
    stake-after values

are emitted as PoS system logs and must be indexed from receipts for historical analytics.

The PoS RPC is primarily a:

    live/current-state monitoring API

not a complete historical accounting API.

Finalized epoch working state can be deleted after epoch finalization.

For historical analytics:

    index canonical receipts / PosSysAddr logs

rather than expecting all history from the live endpoint.

---

# `eth_getPosValidatorDelegators`

## 25. Method signature

Implementation:

```go
func (e *Eth) GetPosValidatorDelegators(
    validator types.Address,
    reportEpoch *string,
) (interface{}, error)
```

JSON-RPC:

    eth_getPosValidatorDelegators

---

## 26. Parameters

| Index | Type | Required | Values |
| ---: | --- | --- | --- |
| `0` | address | Yes | Validator address |
| `1` | string | No | `current`, `lastFinalized` |

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": [
    "0x<validator-address>"
  ]
}
```

Last-finalized context:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": [
    "0x<validator-address>",
    "lastFinalized"
  ]
}
```

Invalid epoch selector:

    invalid reportEpoch "<value>" (expected "current" or "lastFinalized")

---

## 27. Delegator response

Top-level response fields:

| Field | Meaning |
| --- | --- |
| `validator` | Requested validator |
| `selfStake` | Current validator self stake |
| `delegatedRaw` | Current raw delegated stake |
| `delegatedActive` | Current active delegated stake |
| `delegatedActiveCurrent` | Active delegated stake derived from current total |
| `totalActiveCurrentStake` | Current self + active delegated stake |
| `selfStakeLive` | Live self stake |
| `delegatedLiveRaw` | Live raw delegation |
| `delegatedLiveActive` | Live active delegation |
| `totalLiveStake` | Current total active stake |
| `selfStakeEpochEffective` | Epoch-effective validator stake snapshot |
| `delegatedEpochEffective` | Sum of epoch-effective delegator stake |
| `totalEpochEffectiveStake` | Epoch-effective total stake snapshot |
| `delegationEnabled` | Delegation-pool state |
| `maxTotalDelegatedStake` | Pool maximum |
| `minDelegatorStake` | Configured minimum |
| `effectiveMinDelegatorStake` | Effective minimum |
| `commissionBps` | Validator commission |
| `delegators` | Delegator list |

---

## 28. Current vs epoch-effective stake

The delegator endpoint deliberately exposes both live and epoch-effective values.

### Live state

    selfStakeLive
    delegatedLiveRaw
    delegatedLiveActive
    totalLiveStake

represents current staking-contract state.

### Epoch-effective state

    selfStakeEpochEffective
    delegatedEpochEffective
    totalEpochEffectiveStake

represents PoS snapshot values for the selected epoch context.

These can legitimately differ.

---

## 29. Delegator entry fields

Each `delegators[]` entry includes:

| Field | Meaning |
| --- | --- |
| `delegator` | Delegator address |
| `amount` | Current live amount |
| `epochEffectiveAmount` | Epoch-effective stake snapshot |
| `active` | Current staking active flag |
| `joinedAtBlock` | Recorded join block |
| `deactivatedAtBlock` | Recorded deactivation block |
| `effectiveAtPoint` | Whether epoch-effective amount is greater than zero |

The validator's own address is explicitly skipped when constructing the delegator array.

Entries are sorted by delegator address.

---

## 30. `effectiveAtPoint`

Current implementation sets:

    effectiveAtPoint =
        epochEffectiveAmount > 0

This provides a direct signal for whether the delegator contributes to the selected epoch-effective stake snapshot.

---

## 31. Delegator reward field

The delegator struct defines:

    reportedEpochReward

but current `v3.1.1` code does not assign it.

The corresponding test expects the value to remain nil.

Because it is tagged:

    omitempty

it is not returned in current JSON output.

Clients must not rely on this field.

---

## 32. Pool configuration fallback

If validator pool configuration cannot be obtained, the endpoint creates a zero-value fallback view.

At minimum:

    maxTotalDelegatedStake = 0

is initialized.

Other unavailable pool values remain zero/default values.

Clients should not interpret zero-value fallback fields as proof that an explicitly configured limit is zero without considering endpoint health and validator configuration.

---

# Deprecated Compatibility Endpoint

## 33. `eth_getBeaconTimeStatus`

The `Eth` endpoint still exports:

    eth_getBeaconTimeStatus

but `v3.1.1` explicitly marks it as:

    Deprecated legacy endpoint

The old beacon recovery path has been removed.

Current response:

```json
{
  "enabled": false,
  "active": false,
  "healthy": false,
  "deprecated": true,
  "reason": "deprecated"
}
```

This endpoint must not be used for current XGRChain PoS health monitoring.

Use:

    eth_getPosValidatorsOverview

instead.

---

## 34. Why the legacy endpoint still exists

The dispatcher registers exported `Eth` methods automatically.

Therefore a deprecated compatibility method may remain callable even though its underlying mechanism has been retired.

This demonstrates an important API rule:

> RPC method availability does not necessarily mean the represented subsystem is active.

Clients should respect the explicit:

    deprecated = true

status.

---

# Error behavior

## 35. Common errors

| Condition | Result |
| --- | --- |
| Head unavailable | `header has a nil value` |
| Invalid epoch selector | `invalid reportEpoch ...` |
| Overview called before PoS activation | `PoS is not active yet ...` |
| Missing chain params | `missing chain params` |
| Missing IBFT configuration | `missing ibft engine config` |
| Invalid IBFT configuration | `invalid ibft engine config type ...` |
| Missing PoS epoch parameters | `unable to resolve PoS epoch size...` |
| Epoch multiplication overflow | `macro epoch size overflow...` |
| Endpoint unavailable on another implementation | `method not found` |

---

## 36. Overview versus delegator PoS guard

`eth_getPosValidatorsOverview` explicitly checks whether PoS has reached its configured activation block.

`eth_getPosValidatorDelegators` does not contain the same explicit:

    head >= posFromBlock

guard.

It does, however, depend on valid PoS epoch configuration and staking state.

Clients should not use this difference as a protocol signal.

For current mainnet operation PoS is already active.

---

# Integration guidance

## 37. Explorer / dashboard rules

Dashboards should use:

    currentlyValidating

for current consensus validator-set membership.

Use:

    stakingActive

for current staking lifecycle state.

Do not combine them into one field.

A useful UI can therefore distinguish:

    Staking active:       yes/no
    Currently validating: yes/no

---

## 38. Stake presentation

All stake fields are returned in wei.

Example:

    2000000000000000000000000 wei

equals:

    2,000,000 XGR

Convert only in the presentation layer.

Do not change the RPC representation.

---

## 39. Validator eligibility

The PoS monitoring endpoint should not be reduced to a single threshold comparison.

Relevant state can include:

- self stake,
- delegated active stake,
- total active current stake,
- staking active state,
- consensus-set membership,
- epoch-effective state,
- uptime weight.

For operator decisions, inspect the full validator entry rather than only `currentStake`.

---

## 40. Historical analytics

For historical:

- validator rewards,
- delegator rewards,
- slashing,
- stake-after events,
- finalized epoch accounting,

use an event/receipt index.

Do not infer historical results from only the current live-state RPC.

---

## 41. Trie pruning considerations

The two current PoS methods operate primarily against the current head state and current PoS system state.

Therefore normal use does not require an archive node.

However, a separate historical analytics pipeline that reconstructs old state or traces old events must account for the node's historical-state retention policy.

Canonical logs and receipts are distinct from retained historical EVM trie state.

---

## 42. Monitoring fields with caveats

The endpoint itself supplies `monitoringNotes`.

Important current caveats include:

- `currentlyValidating` comes strictly from current consensus header state,
- historical rewards/slashes must be indexed from receipts,
- uptime metrics are rolling proposer-duty metrics,
- zero observed proposer duties do not imply 100% uptime,
- current FeePool balance is pending rather than finalized historical reward distribution,
- micro fields expose current uptime weighting state.

Integrators should not discard these semantics when mapping the response into a simplified data model.

---

## 43. Mainnet expected configuration values

For XGRChain mainnet, clients can expect the following protocol configuration:

| Field | Value |
| --- | --- |
| PoS active | Yes |
| `posFromBlock` | `0x531b64` |
| PoS activation decimal | `5446500` |
| `epochSize` | `0x3e8` |
| Epoch size decimal | `1000` |
| `microEpochSize` | normally `0x19` |
| Micro epoch decimal | `25` |
| Minimum validators | `0x4` |
| Maximum validators | `0x19` |

The actual response remains authoritative for live values.

---

## 44. Code-backed active field checklist

### Overview top-level

    blockNumber
    epochSize
    microEpochSize
    currentMicroEpoch
    currentMicroEpochStartBlock
    currentMicroEpochEndBlock
    currentEpoch
    lastFinalizedEpoch
    reportedEpoch
    reportedEpochStartBlock
    reportedEpochEndBlock
    currentEpochPendingRewards
    stakingContractBalance
    minimumNumValidators
    maximumNumValidators
    validatorThreshold
    totalCurrentStake
    totalValidatorSelfStake
    totalDelegatedRawStake
    totalDelegatedActiveStake
    totalActiveCurrentStake
    rewardIneligibleCount
    slashedCount
    rewardIneligibleStatusExact
    slashStatusExact
    lastRoundStakeExact
    lastRoundDistributedStake
    monitoringNotes
    validators
    posActive
    posFromBlock

---

## 45. Validator active field checklist

    address
    joinedAtBlock
    joinEffectiveAtBlock
    currentStake
    selfStake
    delegatedRawStake
    delegatedActiveStake
    totalActiveCurrentStake
    currentlyValidating
    stakingActive
    deactivatedAtBlock
    deactivateEffectiveAtBlock
    unstakeAvailableAtBlock
    canUnstakeNow
    wasValidatorLastEpoch
    rewardIneligible
    slashed
    microNominalWeight
    microEffectiveWeight
    microInactivity
    proposalUptimeLast3EpochsBps
    proposalUptimeLast10EpochsBps
    proposalUptimeLast3EpochsPercent
    proposalUptimeLast10EpochsPercent
    proposalUptimeLast3EpochsObserved
    proposalUptimeLast10EpochsObserved

Not all optional fields are present for every validator.

---

## 46. Validator fields currently not populated

Defined but not populated by the overview path:

    reportedEpochReward
    reportedEpochRewardValidatorNet
    reportedEpochRewardCommission
    reportedEpochRewardDelegatorsNet

Do not model these as required API fields.

---

## 47. Delegator top-level checklist

    validator
    selfStake
    delegatedRaw
    delegatedActive
    delegatedActiveCurrent
    totalActiveCurrentStake
    selfStakeLive
    delegatedLiveRaw
    delegatedLiveActive
    totalLiveStake
    selfStakeEpochEffective
    delegatedEpochEffective
    totalEpochEffectiveStake
    delegationEnabled
    maxTotalDelegatedStake
    minDelegatorStake
    effectiveMinDelegatorStake
    commissionBps
    delegators

---

## 48. Delegator-entry checklist

    delegator
    amount
    epochEffectiveAmount
    active
    joinedAtBlock
    deactivatedAtBlock
    effectiveAtPoint

Currently not populated:

    reportedEpochReward

---

## 49. Client integration rules

Clients should:

1. Treat numeric fields as hexadecimal JSON-RPC quantities.
2. Convert wei to XGR only in presentation/business layers.
3. Use `currentlyValidating` for current consensus-set membership.
4. Keep `stakingActive` separate from consensus membership.
5. Respect `posFromBlock`.
6. Use `0x531b64` for mainnet block `5446500`.
7. Expect macro epoch size `1000`.
8. Treat `slashStatusExact = false` literally.
9. Do not fabricate omitted reward fields.
10. Interpret proposer uptime as rolling duty reliability, not lifetime uptime.
11. Use receipt/log indexing for historical reward and slash analytics.
12. Treat `eth_getBeaconTimeStatus` as deprecated.
13. Revalidate this reference whenever `jsonrpc/eth_pos_overview.go` changes.

---

## 50. Summary

| Topic | `v3.1.1` behavior |
| --- | --- |
| PoS overview | `eth_getPosValidatorsOverview` |
| Delegator detail | `eth_getPosValidatorDelegators` |
| Deprecated legacy status | `eth_getBeaconTimeStatus` |
| Epoch selectors | `current`, `lastFinalized` |
| Mainnet PoS block | `5446500` |
| Mainnet PoS block hex | `0x531b64` |
| Macro epoch | `1000` blocks |
| Micro epoch | `25` blocks |
| Minimum validators | `4` |
| Maximum validators | `25` |
| Current consensus membership source | Header validator snapshot |
| Live staking state | Staking contract |
| Reward-ineligible status exact | Yes |
| Slash status exact | No |
| Historical rewards from overview | Not exposed |
| Historical slash accounting | Index receipts/system logs |
| Current FeePool balance | Exposed |
| Delegation-pool configuration | Exposed |
| Epoch-effective delegation | Exposed |
| Rolling proposer uptime | Exposed |
| Deprecated beacon recovery | Disabled |

The PoS RPC is designed primarily as a deterministic live validator and staking monitoring interface.

It is not a complete historical accounting API.
