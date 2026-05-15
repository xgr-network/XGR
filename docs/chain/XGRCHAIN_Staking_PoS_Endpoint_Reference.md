# XGR Chain - Staking PoS Endpoint Reference

**Document ID:** XGRCHAIN-STAKING-POS-RPC  
**Last updated:** 2026-05-15  
**Audience:** Dashboard developers, explorer developers, validator operators, backend integrators, auditors  
**Implementation status:** Development / preview; not part of the public `xgr-network/xgr-node` v1.1.1 baseline  
**Source of truth:** Staking-enabled XGR node release artifacts, published staking configuration, official XGR Network operator announcements, and indexed chain receipts/logs

---

## 1. Scope

This document describes XGR Chain staking / PoS related JSON-RPC endpoints and epoch-finalization system logs.

The endpoints described here are XGR-specific extensions exposed through the `eth_*` namespace for dashboard, explorer and validator-operator compatibility.

They are not standard Ethereum JSON-RPC methods.

This document covers:

- `eth_getPosValidatorsOverview`
- `eth_getPosValidatorDelegators`
- `eth_getBeaconTimeStatus`
- PoS epoch-finalization system logs
- Reward, slash and uptime history indexing rules

The current public `xgr-network/xgr-node` v1.1.1 baseline does not include these staking/PoS endpoints.

Until an official staking-enabled release activates them, these endpoints must be treated as development / preview interfaces.

---

## 2. Design principle: live RPC state vs finalized epoch history

XGR Chain separates live staking state from finalized epoch history.

### 2.1 Live staking state

Live staking state is read from current chain state and staking contract state.

It includes:

- current validator stake
- current delegated raw stake
- current delegated active stake
- current validator active/inactive status
- current consensus validator set visibility
- current FeePool balance
- current staking contract balance
- current micro-epoch accounting weights

Live staking state is exposed through RPC endpoints.

### 2.2 Current epoch working state

During an active epoch, the node maintains temporary PoS working state.

This working state may include:

- proposer slots
- missed proposer slots
- epoch validator snapshot
- effective stake snapshots
- staker stake snapshots

This state is used internally for deterministic epoch finalization.

It is not intended as permanent historical storage.

### 2.3 Finalized epoch history

Finalized epoch data is not retained as permanent PoS system storage.

At epoch finalization, the node emits deterministic system logs for:

- finalized epoch summary
- validator uptime result
- staker reward credit
- staker slash operation

After these logs are emitted, finalized epoch working state is deleted.

Therefore:

```text
Finalized epoch reward, slash, uptime and stake-after history must be indexed from receipts/logs.
```

RPC endpoints expose live state and selected current/pending epoch data.

RPC endpoints must not be treated as a complete historical reward database.

---

## 3. Endpoint summary

| Method | Purpose | Status |
|---|---|---|
| `eth_getPosValidatorsOverview` | Returns deterministic live validator and staking overview data | Development / preview |
| `eth_getPosValidatorDelegators` | Returns live delegation details for one validator | Development / preview |
| `eth_getBeaconTimeStatus` | Deprecated compatibility status endpoint | Deprecated |

These methods are intended for:

- staking dashboards
- explorer validator pages
- validator monitoring
- delegation views
- backend indexers
- operational diagnostics

They should not be treated as generic Ethereum RPC.

---

## 4. Release status and compatibility

The staking endpoints are release-dependent.

| Release state | Meaning |
|---|---|
| Public baseline without staking endpoints | Methods are unavailable |
| Staking-enabled development/preview build | Methods may be available for testing and integration |
| Official staking-enabled release | Methods become available according to the published release notes |
| Staking not active at current block | Methods may return an activation error |
| Staking active | Methods return live staking and validator state |

Clients should not assume these methods exist on all XGR Chain RPC endpoints.

Recommended client behavior:

1. Probe endpoint availability.
2. Handle `method not found`.
3. Handle staking-not-active errors.
4. Treat all returned quantities as Ethereum JSON-RPC quantities.
5. Use logs/receipts for finalized epoch history.
6. Do not infer production activation from documentation alone.

---

## 5. Namespace

The endpoints are exposed through the `eth_*` namespace:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
eth_getBeaconTimeStatus
```

Reason:

- dashboard compatibility
- explorer compatibility
- existing Ethereum-style RPC routing
- lower integration overhead for EVM infrastructure

Despite the `eth_*` namespace, these methods are XGR-specific staking extensions.

They are not part of the Ethereum JSON-RPC standard.

---

## 6. Quantity encoding

Numeric values are returned as Ethereum-style JSON-RPC quantities unless otherwise specified.

Example:

```json
"blockNumber": "0x1234"
```

Rules:

- quantities are hexadecimal strings
- quantities are prefixed with `0x`
- quantities do not use decimal formatting
- token and stake values are returned in wei
- basis-point fields are integer quantities
- percent helper fields are integer percentages

Stake and reward values use 18-decimal native units.

```text
1 XGR = 10^18 wei
```

---

## 7. `eth_getPosValidatorsOverview`

Returns a deterministic overview of live PoS validator state.

### 7.1 Request: default mode

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": []
}
```

With no parameter, the endpoint reports the current epoch context.

### 7.2 Request: current epoch

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["current"]
}
```

### 7.3 Request: last finalized epoch context

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["lastFinalized"]
}
```

### 7.4 `reportEpoch` parameter

| Value | Meaning |
|---|---|
| `current` | Report current epoch context |
| `lastFinalized` | Report last finalized epoch context where still available from state/header snapshots |

Invalid values return an error.

Example error condition:

```text
invalid reportEpoch "<value>" (expected "current" or "lastFinalized")
```

Important:

```text
lastFinalized does not mean complete historical reward/slash reconstruction.
Finalized epoch reward/slash history must be indexed from system logs.
```

---

## 8. PoS activation behavior

If the active chain configuration defines a PoS activation block and the current head is before that block, the endpoint returns an error.

Error shape at message level:

```text
PoS is not active yet (activates at block <N>)
```

When PoS activation metadata is available and the current head is at or after the activation block, the response includes:

```json
"posActive": true,
"posFromBlock": "0x..."
```

Correct field name:

```text
posFromBlock
```

Do not use:

```text
poSFromBlock
```

---

## 9. `eth_getPosValidatorsOverview` response

### 9.1 Top-level fields

| Field | Type | Meaning |
|---|---|---|
| `blockNumber` | quantity | Current head block number |
| `epochSize` | quantity | IBFT / staking epoch size in blocks |
| `microEpochSize` | quantity | Current micro-epoch size in blocks |
| `currentMicroEpoch` | quantity | Current micro-epoch index |
| `currentMicroEpochStartBlock` | quantity | Start block of the current micro-epoch |
| `currentMicroEpochEndBlock` | quantity | End block of the current micro-epoch |
| `currentEpoch` | quantity | Current staking/IBFT epoch |
| `lastFinalizedEpoch` | quantity | Last finalized epoch number |
| `reportedEpoch` | quantity | Epoch context selected by request |
| `reportedEpochStartBlock` | quantity | Start block of the reported epoch |
| `reportedEpochEndBlock` | quantity | End block of the reported epoch context |
| `currentEpochPendingRewards` | quantity | Live FeePool balance pending next epoch finalization |
| `stakingContractBalance` | quantity | Live staking contract balance |
| `minimumNumValidators` | quantity | Minimum validator count from staking contract |
| `maximumNumValidators` | quantity | Maximum validator count from staking contract |
| `validatorThreshold` | quantity | Validator self-stake threshold from staking contract |
| `totalCurrentStake` | quantity | Sum of current validator self-stake over returned validators |
| `totalValidatorSelfStake` | quantity | Sum of validator self-stake |
| `totalDelegatedRawStake` | quantity | Sum of current raw delegated stake |
| `totalDelegatedActiveStake` | quantity | Sum of current active delegated stake |
| `totalActiveCurrentStake` | quantity | Sum of current self stake plus active delegated stake |
| `rewardIneligibleCount` | quantity, optional | Count of reward-ineligible validators if exactly available |
| `slashedCount` | quantity, optional | Count of slashed validators if exactly available |
| `rewardIneligibleStatusExact` | boolean | Whether reward-ineligible status is exact from live/current working state |
| `slashStatusExact` | boolean | Whether slash status is exact from live/current working state |
| `lastRoundStakeExact` | boolean | Whether last-round stake distribution was reconstructed exactly by RPC |
| `lastRoundDistributedStake` | quantity, optional | Deprecated / not reliable unless explicitly backed by log indexing |
| `monitoringNotes` | string array | Endpoint semantics and caveats |
| `validators` | array | Validator entries |
| `posActive` | boolean | Whether PoS is active at current head |
| `posFromBlock` | quantity, optional | PoS activation block if configured |

### 9.2 Exactness flags

The exactness flags are critical.

| Field | Meaning |
|---|---|
| `rewardIneligibleStatusExact` | `true` only if reward-ineligible status is computed from still-available current/working state |
| `slashStatusExact` | `true` only if slash status is computed from available current/working state |
| `lastRoundStakeExact` | `true` only if last-round reward/stake values are reconstructed exactly |

For finalized epochs after working-state cleanup, clients should expect historical reward/slash details to require log indexing.

Dashboard rule:

```text
If an exactness flag is false, do not display the value as authoritative historical data.
```

---

## 10. Validator entry fields

Each item in `validators` contains validator-specific staking, consensus and monitoring data.

| Field | Type | Meaning |
|---|---|---|
| `address` | address | Validator address |
| `joinedAtBlock` | quantity, optional | Block where the validator joined |
| `joinEffectiveAtBlock` | quantity, optional | Epoch-boundary block where join becomes effective |
| `currentStake` | quantity | Current validator self-stake |
| `selfStake` | quantity, optional | Current validator self-stake |
| `delegatedRawStake` | quantity, optional | Current raw delegated stake |
| `delegatedActiveStake` | quantity, optional | Current active delegated stake |
| `totalActiveCurrentStake` | quantity, optional | Current self stake plus active delegated stake |
| `currentlyValidating` | boolean | Whether the validator is in the current consensus header validator set |
| `stakingActive` | boolean | Active flag from staking contract validator info |
| `deactivatedAtBlock` | quantity, optional | Block where validator deactivation was recorded |
| `deactivateEffectiveAtBlock` | quantity, optional | Epoch-boundary block where deactivation becomes effective |
| `unstakeAvailableAtBlock` | quantity, optional | Block after which unstake / withdraw can become available |
| `canUnstakeNow` | boolean | Whether current epoch permits unstake after deactivation |
| `wasValidatorLastEpoch` | boolean | Whether validator was visible in last finalized epoch context |
| `reportedEpochReward` | quantity, optional | Deprecated unless backed by log indexing |
| `reportedEpochRewardValidatorNet` | quantity, optional | Deprecated unless backed by log indexing |
| `reportedEpochRewardCommission` | quantity, optional | Deprecated unless backed by log indexing |
| `reportedEpochRewardDelegatorsNet` | quantity, optional | Deprecated unless backed by log indexing |
| `rewardIneligible` | boolean, optional | Reward-ineligible status if exactly available |
| `slashed` | boolean, optional | Slashed status if exactly available |
| `microNominalWeight` | quantity, optional | Current nominal micro-epoch weight |
| `microEffectiveWeight` | quantity, optional | Current effective micro-epoch weight |
| `microInactivity` | quantity, optional | Current inactivity counter |
| `proposalUptimeLast3EpochsBps` | quantity, optional | Rolling proposer-duty uptime over last 3 epochs, in basis points, if observable |
| `proposalUptimeLast10EpochsBps` | quantity, optional | Rolling proposer-duty uptime over last 10 epochs, in basis points, if observable |
| `proposalUptimeLast3EpochsPercent` | quantity, optional | Rolling proposer-duty uptime over last 3 epochs, integer percent |
| `proposalUptimeLast10EpochsPercent` | quantity, optional | Rolling proposer-duty uptime over last 10 epochs, integer percent |
| `proposalUptimeLast3EpochsObserved` | quantity | Observed proposer duties in 3-epoch window |
| `proposalUptimeLast10EpochsObserved` | quantity | Observed proposer duties in 10-epoch window |

---

## 11. Validator status semantics

### 11.1 `currentlyValidating`

`currentlyValidating` is derived from the current consensus header validator set.

It is a consensus visibility field.

It is not derived only from staking contract active status.

A validator can be active in staking state but not currently validating if the validator-set transition has not yet become effective or if the validator is outside the current consensus snapshot.

### 11.2 `stakingActive`

`stakingActive` is read from staking contract validator information.

It reflects staking contract state.

It is not a direct replacement for `currentlyValidating`.

### 11.3 `wasValidatorLastEpoch`

`wasValidatorLastEpoch` indicates whether the validator was visible in the last finalized epoch context.

This is a monitoring and display field.

It is not a consensus fallback.

### 11.4 Join and deactivation effective blocks

Join and deactivation timing use deterministic epoch-boundary markers.

Fields:

```text
joinedAtBlock
joinEffectiveAtBlock
deactivatedAtBlock
deactivateEffectiveAtBlock
unstakeAvailableAtBlock
canUnstakeNow
```

These fields are intended for dashboard timing, validator status pages and operator UX.

---

## 12. Reward and slash semantics

### 12.1 Current rule

Finalized reward and slash history is emitted as system logs.

It is not retained as permanent PoS system state.

Therefore, historical reward/slash information must be reconstructed from:

```text
block receipts + PoS system logs
```

### 12.2 RPC limitations

The RPC overview endpoint may expose live/current context data.

It does not replace a log indexer.

For finalized epochs, the following fields must not be treated as authoritative unless an official release explicitly documents log reconstruction support:

```text
reportedEpochReward
reportedEpochRewardValidatorNet
reportedEpochRewardCommission
reportedEpochRewardDelegatorsNet
lastRoundDistributedStake
rewardIneligible
slashed
```

### 12.3 Indexer rule

Explorers and dashboards that display finalized epoch rewards or slashes must index:

- `EpochFinalized`
- `ValidatorUptimeFinalized`
- `StakerRewarded`
- `StakerSlashed`

from receipts.

Do not infer finalized rewards from live stake deltas alone.

---

## 13. Proposer uptime semantics

The endpoint exposes rolling proposer-duty reliability metrics where observable.

Fields:

```text
proposalUptimeLast3EpochsBps
proposalUptimeLast10EpochsBps
proposalUptimeLast3EpochsPercent
proposalUptimeLast10EpochsPercent
proposalUptimeLast3EpochsObserved
proposalUptimeLast10EpochsObserved
```

Meaning:

| Field group | Meaning |
|---|---|
| `...Observed` | Number of observed proposer duties in the window |
| `...Bps` | Uptime in basis points |
| `...Percent` | Integer percentage derived from basis points |

Important behavior:

- the metric is proposer-duty uptime, not lifetime validator uptime
- epochs before join-effective block are excluded
- epochs after deactivation-effective block are excluded
- if observed duties are zero, uptime fields are omitted
- zero observed duties must not be displayed as 100% uptime
- finalized historical uptime must be indexed from `ValidatorUptimeFinalized` logs after working-state cleanup

Dashboard rule:

```text
If proposalUptime...Observed is 0 and uptime fields are omitted, show "no observed proposer duties" instead of 100%.
```

---

## 14. Micro-epoch fields

The endpoint exposes micro-epoch accounting fields where available.

Top-level fields:

| Field | Meaning |
|---|---|
| `microEpochSize` | Current micro-epoch size in blocks |
| `currentMicroEpoch` | Current micro-epoch index |
| `currentMicroEpochStartBlock` | Start block of the current micro-epoch |
| `currentMicroEpochEndBlock` | End block of the current micro-epoch |

Validator-level fields:

| Field | Meaning |
|---|---|
| `microNominalWeight` | Nominal weight for current micro-epoch accounting |
| `microEffectiveWeight` | Effective weight after uptime/inactivity effects |
| `microInactivity` | Current inactivity counter |

If micro-epoch configuration is invalid or unavailable, the endpoint can return zero-valued top-level micro-epoch fields and omit validator-level micro fields.

Micro-epoch fields are part of the staking/PoS development track until activated by official release.

---

## 15. `eth_getPosValidatorDelegators`

Returns live delegator details for one validator.

This endpoint is primarily a live/current staking-state view.

It is not a complete finalized historical reward API.

### 15.1 Request: current epoch context

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": [
    "0xValidatorAddress"
  ]
}
```

### 15.2 Request: explicit current epoch context

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": [
    "0xValidatorAddress",
    "current"
  ]
}
```

### 15.3 Request: last finalized epoch context

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": [
    "0xValidatorAddress",
    "lastFinalized"
  ]
}
```

Important:

```text
For finalized epochs, epoch-effective stake snapshots may no longer be available from state after cleanup.
Use finalized system logs for exact reward/slash/stake-after history.
```

### 15.4 Parameters

| Parameter | Type | Required | Meaning |
|---|---|---:|---|
| `validator` | address | yes | Validator address |
| `reportEpoch` | string | no | `current` or `lastFinalized` |

Invalid `reportEpoch` values return an error.

---

## 16. `eth_getPosValidatorDelegators` response

### 16.1 Top-level fields

| Field | Type | Meaning |
|---|---|---|
| `validator` | address | Validator address |
| `selfStake` | quantity | Current validator self-stake |
| `delegatedRaw` | quantity | Current raw delegated amount |
| `delegatedActive` | quantity | Current active delegated amount |
| `delegatedActiveCurrent` | quantity | Current active delegated amount derived from current total |
| `totalActiveCurrentStake` | quantity | Current self stake plus current active delegated stake |
| `selfStakeLive` | quantity, optional | Live validator self-stake |
| `delegatedLiveRaw` | quantity, optional | Live raw delegated stake |
| `delegatedLiveActive` | quantity, optional | Live active delegated stake |
| `totalLiveStake` | quantity, optional | Live total active stake |
| `selfStakeEpochEffective` | quantity, optional | Current/working epoch effective self stake if available |
| `delegatedEpochEffective` | quantity, optional | Current/working epoch effective delegated stake if available |
| `totalEpochEffectiveStake` | quantity, optional | Current/working epoch effective total stake if available |
| `delegationEnabled` | boolean | Whether delegation is enabled for this validator |
| `maxTotalDelegatedStake` | quantity | Maximum total delegated stake allowed |
| `minDelegatorStake` | quantity | Configured minimum delegator stake |
| `effectiveMinDelegatorStake` | quantity | Effective minimum delegator stake |
| `commissionBps` | quantity | Validator commission in basis points |
| `delegators` | array | Delegator entries |

Do not use the old field name:

```text
maxDelegatedStake
```

Correct field name:

```text
maxTotalDelegatedStake
```

---

## 17. Delegator entry fields

Each item in `delegators` contains:

| Field | Type | Meaning |
|---|---|---|
| `delegator` | address | Delegator address |
| `amount` | quantity | Current delegated amount |
| `epochEffectiveAmount` | quantity, optional | Current/working epoch effective amount if available |
| `reportedEpochReward` | quantity, optional | Deprecated unless backed by log indexing |
| `active` | boolean | Active flag from staking state |
| `joinedAtBlock` | quantity, optional | Block where delegator joined |
| `deactivatedAtBlock` | quantity, optional | Block where delegator deactivated |
| `effectiveAtPoint` | boolean | Whether delegator stake is effective at selected report point, if known |

Delegator entries are sorted by delegator address.

The validator's own self-stake is not returned as a delegator entry.

---

## 18. Live stake vs epoch-effective stake

The delegators endpoint separates live stake from epoch-effective stake.

### 18.1 Live stake

Live fields describe current contract state at the current head.

Relevant fields:

```text
selfStakeLive
delegatedLiveRaw
delegatedLiveActive
totalLiveStake
```

These fields are useful for current dashboard display.

### 18.2 Epoch-effective stake

Epoch-effective fields describe stake effective at the selected report point if still available from current/working state.

Relevant fields:

```text
selfStakeEpochEffective
delegatedEpochEffective
totalEpochEffectiveStake
epochEffectiveAmount
effectiveAtPoint
```

For finalized epochs after working-state cleanup, these fields may be zero or unavailable unless reconstructed by an external indexer from logs.

Dashboard rule:

```text
Do not interpret missing or zero epoch-effective fields for finalized epochs as proof that the validator or delegator had no effective stake.
```

Use finalized logs for exact historical attribution.

---

## 19. Commission and delegation pool fields

The endpoint returns validator pool information.

| Field | Meaning |
|---|---|
| `delegationEnabled` | Whether the validator accepts delegation |
| `maxTotalDelegatedStake` | Maximum total delegated stake allowed |
| `minDelegatorStake` | Minimum allowed delegator stake |
| `effectiveMinDelegatorStake` | Effective minimum delegator stake |
| `commissionBps` | Commission in basis points |

Commission basis points:

```text
10000 bps = 100%
100 bps = 1%
```

Example:

```text
commissionBps = 500
```

means:

```text
5%
```

---

## 20. PoS epoch-finalization system logs

Finalized epoch history is represented by deterministic system logs emitted from the PoS system address.

System log address:

```text
0x0000000000000000000000000000000000009999
```

These logs are emitted into a deterministic system receipt attached to the epoch-finalization system transaction on the epoch-boundary block.

The epoch-boundary block is user-transaction-free once PoS finalization is active.

---

## 21. `EpochFinalized` log

### 21.1 Signature

```text
EpochFinalized(uint256,uint256,uint256,uint256,uint256,uint256,uint256)
```

### 21.2 Topics

| Topic index | Value |
|---:|---|
| `topics[0]` | Event signature hash |
| `topics[1]` | `epoch` |
| `topics[2]` | `blockNumber` |

### 21.3 Data words

| Data word | Field | Meaning |
|---:|---|---|
| `0` | `poolBalanceBefore` | FeePool balance before distribution |
| `1` | `totalDistributed` | Total amount distributed as rewards |
| `2` | `poolRemainder` | Remaining undistributed FeePool amount |
| `3` | `totalSlashed` | Total amount slashed in the epoch |
| `4` | `activeValidators` | Number of active validators after finalization |

---

## 22. `ValidatorUptimeFinalized` log

### 22.1 Signature

```text
ValidatorUptimeFinalized(uint256,address,uint256,uint256,uint256,uint256,uint256,bool,bool)
```

### 22.2 Topics

| Topic index | Value |
|---:|---|
| `topics[0]` | Event signature hash |
| `topics[1]` | `epoch` |
| `topics[2]` | `validator` |

### 22.3 Data words

| Data word | Field | Meaning |
|---:|---|---|
| `0` | `slots` | Proposer slots assigned |
| `1` | `missed` | Missed proposer slots |
| `2` | `uptimeBps` | Uptime in basis points |
| `3` | `effectiveWeight` | Effective reward weight after uptime adjustment |
| `4` | `stakeSnapshot` | Validator effective stake snapshot used for the epoch |
| `5` | `rewardEligible` | Whether validator was reward-eligible |
| `6` | `slashed` | Whether validator was slashed |

---

## 23. `StakerRewarded` log

### 23.1 Signature

```text
StakerRewarded(uint256,address,address,uint8,uint256,uint256,uint256,uint256)
```

### 23.2 Topics

| Topic index | Value |
|---:|---|
| `topics[0]` | Event signature hash |
| `topics[1]` | `epoch` |
| `topics[2]` | `validator` |
| `topics[3]` | `staker` |

### 23.3 Data words

| Data word | Field | Meaning |
|---:|---|---|
| `0` | `role` | `1` = validator self-stake, `2` = delegator |
| `1` | `amount` | Reward amount credited |
| `2` | `stakeSnapshot` | Effective stake snapshot used for attribution |
| `3` | `stakeBefore` | Staker amount before reward credit |
| `4` | `stakeAfter` | Staker amount after reward credit |

---

## 24. `StakerSlashed` log

### 24.1 Signature

```text
StakerSlashed(uint256,address,address,uint8,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)
```

### 24.2 Topics

| Topic index | Value |
|---:|---|
| `topics[0]` | Event signature hash |
| `topics[1]` | `epoch` |
| `topics[2]` | `validator` |
| `topics[3]` | `staker` |

### 24.3 Data words

| Data word | Field | Meaning |
|---:|---|---|
| `0` | `role` | `1` = validator self-stake, `2` = delegator |
| `1` | `amount` | Amount slashed |
| `2` | `stakeSnapshot` | Effective stake snapshot used for slash allocation |
| `3` | `stakeBefore` | Staker amount before slash |
| `4` | `stakeAfter` | Staker amount after slash |
| `5` | `slots` | Proposer slots assigned to validator |
| `6` | `missed` | Missed proposer slots |
| `7` | `slashBps` | Slash rate in basis points |
| `8` | `destination` | Slash destination address |

---

## 25. Indexer requirements

Explorers and dashboards that need finalized historical staking data must index PoS system logs.

Minimum indexed keys:

| Use case | Required logs |
|---|---|
| Epoch reward summary | `EpochFinalized` |
| Validator uptime history | `ValidatorUptimeFinalized` |
| Validator reward history | `StakerRewarded` where `role = 1` |
| Delegator reward history | `StakerRewarded` where `role = 2` |
| Validator slash history | `StakerSlashed` where `role = 1` |
| Delegator slash history | `StakerSlashed` where `role = 2` |
| Historical stake-after view | `StakerRewarded` and `StakerSlashed` |
| Finalized epoch eligibility | `ValidatorUptimeFinalized` |

Recommended index dimensions:

```text
epoch
blockNumber
validator
staker
role
eventType
```

Recommended derived tables:

```text
pos_epochs
pos_validator_epoch_uptime
pos_staker_rewards
pos_staker_slashes
pos_validator_epoch_rewards
pos_delegator_epoch_rewards
```

---

## 26. Dashboard display recommendations

### 26.1 Validator state

Recommended validator status display:

| Display field | Source field |
|---|---|
| Currently validating | `currentlyValidating` |
| Staking active | `stakingActive` |
| Current self stake | `selfStake` / `currentStake` |
| Current delegated raw stake | `delegatedRawStake` |
| Current delegated active stake | `delegatedActiveStake` |
| Current active total stake | `totalActiveCurrentStake` |
| Joined at | `joinedAtBlock` |
| Effective join | `joinEffectiveAtBlock` |
| Deactivated at | `deactivatedAtBlock` |
| Effective deactivation | `deactivateEffectiveAtBlock` |
| Can unstake | `canUnstakeNow` |
| Unstake available from | `unstakeAvailableAtBlock` |

Do not collapse `currentlyValidating` and `stakingActive` into one status.

They answer different questions.

### 26.2 Rewards and slashing

Recommended finalized reward/slash display:

| Display field | Source |
|---|---|
| Epoch finalized | `EpochFinalized` log |
| Validator uptime | `ValidatorUptimeFinalized` log |
| Validator reward | `StakerRewarded` log with `role = 1` |
| Validator commission / net reward | Derived by indexer from reward split logs and role |
| Delegator reward | `StakerRewarded` log with `role = 2` |
| Validator slash | `StakerSlashed` log with `role = 1` |
| Delegator slash | `StakerSlashed` log with `role = 2` |

Do not use live RPC zero values as finalized historical reward/slash facts.

### 26.3 Uptime

Recommended uptime display:

| Display field | Source |
|---|---|
| Current rolling uptime | RPC proposal uptime fields if observed |
| Finalized epoch uptime | `ValidatorUptimeFinalized` logs |
| Observed duties | RPC `proposalUptime...Observed` or indexed `slots` |
| Missed duties | Indexed `missed` |

If observed duties are zero:

```text
Display: no observed proposer duties
Do not display: 100%
```

### 26.4 Delegation

Recommended delegation display:

| Display field | Source field |
|---|---|
| Delegation enabled | `delegationEnabled` |
| Validator commission | `commissionBps` |
| Max delegated stake | `maxTotalDelegatedStake` |
| Min delegator stake | `minDelegatorStake` |
| Effective min delegator stake | `effectiveMinDelegatorStake` |
| Raw delegated stake | `delegatedRaw` |
| Active delegated stake | `delegatedActive` |
| Live total stake | `totalLiveStake` |
| Finalized historical rewards | Indexed `StakerRewarded` logs |

---

## 27. `eth_getBeaconTimeStatus`

Deprecated compatibility endpoint.

### 27.1 Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getBeaconTimeStatus",
  "params": []
}
```

### 27.2 Response

```json
{
  "enabled": false,
  "active": false,
  "healthy": false,
  "deprecated": true,
  "reason": "deprecated"
}
```

This endpoint is intentionally not a staking health endpoint.

Do not use it for validator, staking, delegation, reward, slash or micro-epoch monitoring.

Use the PoS overview endpoint and indexed PoS system logs instead.

---

## 28. Error behavior

Known error conditions include:

| Condition | Behavior |
|---|---|
| Missing head/header | Returns error |
| Invalid `reportEpoch` | Returns error |
| PoS configured but not active yet | Returns error |
| Staking contract query fails | Returns error |
| Staking state unavailable | Returns error |
| Invalid validator address encoding | Returns JSON-RPC parameter error |
| Unsupported method on current release | Returns method-not-found error |
| Endpoint unavailable on public baseline | Returns method-not-found error |

Clients must handle errors gracefully.

A dashboard must not assume that a missing endpoint means the network is unhealthy.

It may simply mean the connected RPC node is not running a staking-enabled release.

---

## 29. Security and exposure

These endpoints expose operational staking and validator-state information.

Recommended exposure policy:

| Endpoint | Public exposure |
|---|---|
| `eth_getPosValidatorsOverview` | Can be public once staking is officially active, subject to rate limits |
| `eth_getPosValidatorDelegators` | Can be public once staking is officially active, subject to rate limits and response-size monitoring |
| `eth_getBeaconTimeStatus` | No operational need; deprecated |

Operational controls:

- apply rate limits
- monitor response size
- monitor RPC latency
- prefer dedicated RPC/indexer nodes for dashboards
- handle unavailable staking state gracefully
- do not expose unrelated debug/operator namespaces just because staking endpoints are public
- use indexed receipts/logs for finalized historical staking views

---

## 30. Endpoint availability checklist

Before integrating these endpoints, verify:

- the connected node runs a staking-enabled release
- the method exists
- PoS is active or expected to become active at `posFromBlock`
- the staking contract is deployed and queryable
- the node is synced
- the node can read current headers
- the node can read consensus validator snapshots
- the node can query staking contract state
- FeePool and staking contract balances are readable
- response quantities are decoded as hex quantities
- dashboard handles missing optional fields
- dashboard does not interpret missing historical RPC values as zero historical rewards
- indexer can read receipts for epoch-boundary system transactions
- indexer can decode PoS system logs from address `0x0000000000000000000000000000000000009999`

---

## 31. Summary

| Component | Status | Primary use |
|---|---|---|
| `eth_getPosValidatorsOverview` | Development / preview until official staking activation | Live validator overview, staking dashboard, explorer validator page |
| `eth_getPosValidatorDelegators` | Development / preview until official staking activation | Live delegator table, validator pool page |
| `eth_getBeaconTimeStatus` | Deprecated compatibility endpoint | Do not use for current staking monitoring |
| PoS system logs | Required for finalized history | Rewards, slashes, uptime, finalized epoch accounting |

Key rules:

| Topic | Correct rule |
|---|---|
| Live validator status | Use RPC |
| Current stake/delegation | Use RPC |
| Current pending rewards | Use RPC FeePool field |
| Finalized reward history | Use indexed `StakerRewarded` logs |
| Finalized slash history | Use indexed `StakerSlashed` logs |
| Finalized uptime history | Use indexed `ValidatorUptimeFinalized` logs |
| Finalized epoch summary | Use indexed `EpochFinalized` logs |
| Historical epoch working state | Not retained permanently in PoS system storage |
| Missing historical RPC value | Do not treat as proof of zero reward/stake |
