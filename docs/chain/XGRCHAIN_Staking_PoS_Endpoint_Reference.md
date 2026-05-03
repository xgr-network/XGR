# XGR Chain — Staking PoS Endpoint Reference

**Document ID:** XGRCHAIN-STAKING-POS-RPC  
**Last updated:** 2026-05-03  
**Audience:** dashboard developers, explorer developers, validator operators, backend integrators, auditors  
**Implementation status:** In development / `PoS_3`  
**Source of truth:** `xgrchain/jsonrpc/eth_pos_overview.go`

---

## 1. Scope

This document describes the PoS/staking-related JSON-RPC endpoints currently implemented on the `PoS_3` branch.

It covers:

- `eth_getPosValidatorsOverview`
- `eth_getPosValidatorDelegators`
- `eth_getBeaconTimeStatus` as deprecated compatibility endpoint

These endpoints are not part of standard Ethereum JSON-RPC. They are XGR Chain extensions exposed through the `eth_*` namespace for dashboard/explorer compatibility.

---

## 2. Endpoint summary

| Method | Purpose | Status |
|---|---|---|
| `eth_getPosValidatorsOverview` | deterministic validator/staking overview | active on `PoS_3` |
| `eth_getPosValidatorDelegators` | delegator details for one validator | active on `PoS_3` |
| `eth_getBeaconTimeStatus` | legacy beacon status endpoint | deprecated; returns disabled/deprecated status |

---

## 3. `eth_getPosValidatorsOverview`

Returns a deterministic overview of PoS validator state.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": []
}
```

Optional `reportEpoch` parameter:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["lastFinalized"]
}
```

Allowed values:

| Value | Meaning |
|---|---|
| `"current"` | report current epoch |
| `"lastFinalized"` | report last finalized epoch |

Invalid values return an error.

### PoS activation behavior

If PoS has a configured activation block and the current head is before that block, the method returns an error:

```text
PoS is not active yet (activates at block <N>)
```

---

## 4. Response top-level fields

| Field | Type | Meaning |
|---|---|---|
| `blockNumber` | quantity | current head block number |
| `epochSize` | quantity | IBFT/staking epoch size |
| `microEpochSize` | quantity | current micro-epoch size |
| `currentMicroEpoch` | quantity | current micro-epoch index |
| `currentMicroEpochStartBlock` | quantity | start block of current micro-epoch |
| `currentMicroEpochEndBlock` | quantity | end block of current micro-epoch |
| `currentEpoch` | quantity | current epoch |
| `lastFinalizedEpoch` | quantity | last finalized epoch |
| `reportedEpoch` | quantity | epoch used for reported reward/slash fields |
| `reportedEpochStartBlock` | quantity | start block of reported epoch |
| `reportedEpochEndBlock` | quantity | end block of reported epoch |
| `currentEpochPendingRewards` | quantity | current FeePool balance pending next epoch finalization |
| `stakingContractBalance` | quantity | live staking contract balance |
| `minimumNumValidators` | quantity | staking contract minimum validator count |
| `maximumNumValidators` | quantity | staking contract maximum validator count |
| `validatorThreshold` | quantity | validator eligibility threshold |
| `totalCurrentStake` | quantity | total current stake over validators |
| `rewardIneligibleCount` | quantity | number of reward-ineligible validators in reported epoch |
| `slashedCount` | quantity | number of slashed validators in reported epoch |
| `rewardIneligibleStatusExact` | boolean | reward-ineligible status is exact |
| `slashStatusExact` | boolean | slash status is exact |
| `lastRoundStakeExact` | boolean | last-round stake distribution is exact |
| `lastRoundDistributedStake` | quantity | recorded total reward for last finalized epoch |
| `monitoringNotes` | string[] | endpoint semantics and caveats |
| `validators` | array | validator entries |
| `posActive` | boolean | whether PoS is active at current head |
| `poSFromBlock` | quantity | optional PoS activation block |

---

## 5. Validator entry fields

Each item in `validators` contains:

| Field | Type | Meaning |
|---|---|---|
| `address` | address | validator address |
| `joinedAtBlock` | quantity | validator join block |
| `joinEffectiveAtBlock` | quantity | epoch-boundary join effective marker |
| `currentStake` | quantity | current stake |
| `currentlyValidating` | boolean | derived strictly from current consensus header validator set |
| `stakingActive` | boolean | active flag from staking contract |
| `deactivatedAtBlock` | quantity | block where validator was deactivated |
| `deactivateEffectiveAtBlock` | quantity | epoch-boundary deactivation effective marker |
| `unstakeAvailableAtBlock` | quantity | block after which unstake/withdraw can become available |
| `canUnstakeNow` | boolean | whether current epoch permits unstake after deactivation |
| `wasValidatorLastEpoch` | boolean | whether validator was in last finalized epoch set |
| `reportedEpochReward` | quantity | validator reward for reported epoch |
| `reportedEpochRewardValidatorNet` | quantity | validator net reward |
| `reportedEpochRewardCommission` | quantity | validator commission reward |
| `reportedEpochRewardDelegatorsNet` | quantity | delegator net reward total |
| `rewardIneligible` | boolean | reward-ineligible in reported epoch |
| `slashed` | boolean | slashed in reported epoch |
| `microNominalWeight` | quantity | current nominal micro-epoch weight |
| `microEffectiveWeight` | quantity | current effective micro-epoch weight |
| `microInactivity` | quantity | current inactivity counter |
| `proposalUptimeLast3EpochsBps` | quantity | rolling proposer-duty uptime over last 3 epochs, basis points |
| `proposalUptimeLast10EpochsBps` | quantity | rolling proposer-duty uptime over last 10 epochs, basis points |
| `proposalUptimeLast3EpochsPercent` | quantity | rolling proposer-duty uptime over last 3 epochs, percent |
| `proposalUptimeLast10EpochsPercent` | quantity | rolling proposer-duty uptime over last 10 epochs, percent |
| `proposalUptimeLast3EpochsObserved` | quantity | observed proposer duties in 3-epoch window |
| `proposalUptimeLast10EpochsObserved` | quantity | observed proposer duties in 10-epoch window |

---

## 6. Monitoring notes semantics

The endpoint returns `monitoringNotes`.

Important semantics:

- `currentlyValidating` is derived from current consensus header validator set, not heuristic fallback.
- `wasValidatorLastEpoch` is a monitoring/display field. It may use the last-finalized epoch-end header snapshot only for RPC visibility if epoch-keyed PoS state is unavailable. This is not a consensus finalization fallback.
- join/deactivation effective blocks are deterministic epoch-boundary markers.
- reward-ineligible status is computed only for validators present in the reported epoch set.
- proposer uptime windows are rolling proposer-duty reliability metrics, not lifetime uptime.
- if observed proposer duties are zero, uptime fields are omitted rather than fabricated as 100%.
- `currentEpochPendingRewards` is the live FeePool balance.
- `stakingContractBalance` is the live staking contract balance.
- micro fields expose current micro-epoch uptime accounting weights.

---

## 7. Example response shape

```json
{
  "blockNumber": "0x1234",
  "epochSize": "0x1f4",
  "microEpochSize": "0x32",
  "currentEpoch": "0xa",
  "lastFinalizedEpoch": "0x9",
  "reportedEpoch": "0x9",
  "currentEpochPendingRewards": "0x0",
  "stakingContractBalance": "0x0",
  "minimumNumValidators": "0x4",
  "maximumNumValidators": "0x64",
  "validatorThreshold": "0x...",
  "totalCurrentStake": "0x...",
  "rewardIneligibleStatusExact": true,
  "slashStatusExact": true,
  "lastRoundStakeExact": true,
  "validators": [
    {
      "address": "0x...",
      "currentStake": "0x...",
      "currentlyValidating": true,
      "stakingActive": true,
      "canUnstakeNow": false,
      "wasValidatorLastEpoch": true,
      "reportedEpochReward": "0x0",
      "rewardIneligible": false,
      "slashed": false,
      "proposalUptimeLast3EpochsObserved": "0x0",
      "proposalUptimeLast10EpochsObserved": "0x0"
    }
  ],
  "posActive": true,
  "monitoringNotes": []
}
```

---

## 8. `eth_getPosValidatorDelegators`

Returns delegator details for one validator.

### Request

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

Optional `reportEpoch` parameter:

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

Allowed values:

| Value | Meaning |
|---|---|
| `"current"` | current epoch |
| `"lastFinalized"` | last finalized epoch |

---

## 9. Delegators response fields

| Field | Type | Meaning |
|---|---|---|
| `validator` | address | validator address |
| `selfStake` | quantity | validator self-stake |
| `delegatedRaw` | quantity | raw delegated amount |
| `delegatedActive` | quantity | active delegated amount |
| `delegatedActiveCurrent` | quantity | current active delegated amount |
| `totalActiveCurrentStake` | quantity | self stake + current active delegated stake |
| `delegationEnabled` | boolean | whether delegation is enabled for validator |
| `maxDelegatedStake` | quantity | maximum delegated stake allowed |
| `commissionBps` | quantity | commission in basis points |
| `delegators` | array | delegator entries |

Delegator entry:

| Field | Type | Meaning |
|---|---|---|
| `delegator` | address | delegator address |
| `amount` | quantity | delegated amount |
| `reportedEpochReward` | quantity | reward for reported epoch |
| `active` | boolean | active flag |
| `joinedAtBlock` | quantity | join block |
| `deactivatedAtBlock` | quantity | deactivation block |
| `effectiveAtPoint` | boolean | whether effective at current point |

---

## 10. `eth_getBeaconTimeStatus`

Deprecated compatibility endpoint.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getBeaconTimeStatus",
  "params": []
}
```

### Response

```json
{
  "enabled": false,
  "active": false,
  "healthy": false,
  "deprecated": true,
  "reason": "deprecated"
}
```

Do not use this endpoint for current PoS monitoring.

---

## 11. Error behavior

Known errors include:

| Condition | Behavior |
|---|---|
| missing head | returns error |
| invalid `reportEpoch` | returns error |
| PoS configured but not active yet | returns error |
| staking query fails | returns error |
| missing/invalid staking ABI behavior | returns error |

---

## 12. Integration guidance

Dashboards and explorers should:

1. Use `eth_getPosValidatorsOverview` for validator overview.
2. Use `eth_getPosValidatorDelegators` only when validator delegation detail is needed.
3. Treat `eth_getBeaconTimeStatus` as deprecated.
4. Do not infer active validators from staking contract alone; use `currentlyValidating`.
5. Use `joinEffectiveAtBlock`, `deactivateEffectiveAtBlock` and `unstakeAvailableAtBlock` for UX timing.
6. Display `proposalUptime...Observed`; do not show 100% uptime when observed duties are zero.
7. Distinguish current stake from reported epoch reward.
8. Treat the endpoint as XGR-specific, not Ethereum-standard.

---

## 13. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Staking_PoS_Model.md` | PoS staking model |
| `XGRCHAIN_Consensus_IBFT.md` | IBFT finality |
| `XGRCHAIN_Node_Operation.md` | validator/node operation |
| `XRC-GAS_Gas_Price_Behavior.md` | FeePool and gas behavior |
