# XGR Chain — Staking PoS Endpoint Reference

**Document ID:** XGRCHAIN-STAKING-POS-RPC  
**Last updated:** 2026-05-03  
**Audience:** Dashboard developers, explorer developers, validator operators, backend integrators, auditors  
**Implementation status:** Development / preview; not part of the public `xgr-network/xgr-node` v1.1.1 baseline  
**Source of truth:** Staking-enabled XGR node release artifacts, published staking configuration, and official XGR Network operator announcements

---

## 1. Scope

This document describes XGR Chain staking / PoS related JSON-RPC endpoints.

The endpoints described here are XGR-specific extensions exposed through the `eth_*` namespace for dashboard, explorer and validator-operator compatibility.

They are not standard Ethereum JSON-RPC methods.

This document covers:

- `eth_getPosValidatorsOverview`
- `eth_getPosValidatorDelegators`
- `eth_getBeaconTimeStatus`

The current public `xgr-network/xgr-node` v1.1.1 baseline does not include these staking/PoS endpoints.

Until an official staking-enabled release activates them, these endpoints must be treated as development / preview interfaces.

---

## 2. Endpoint summary

| Method | Purpose | Status |
|---|---|---|
| `eth_getPosValidatorsOverview` | Returns deterministic validator and staking overview data | Development / preview |
| `eth_getPosValidatorDelegators` | Returns delegation details for one validator | Development / preview |
| `eth_getBeaconTimeStatus` | Deprecated compatibility status endpoint | Deprecated compatibility endpoint |

These methods are intended for:

- staking dashboards
- explorer validator pages
- validator monitoring
- delegation views
- backend indexers
- operational diagnostics

They should not be treated as generic Ethereum RPC.

---

## 3. Release status and compatibility

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
5. Do not infer production activation from documentation alone.

---

## 4. Naming and namespace

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

## 5. Quantity encoding

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

## 6. `eth_getPosValidatorsOverview`

Returns a deterministic overview of PoS validator state.

### 6.1 Request: default mode

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": []
}
```

With no parameter, the endpoint reports the current epoch.

### 6.2 Request: current epoch

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["current"]
}
```

### 6.3 Request: last finalized epoch

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["lastFinalized"]
}
```

### 6.4 `reportEpoch` parameter

| Value | Meaning |
|---|---|
| `current` | Report the current epoch |
| `lastFinalized` | Report the last finalized epoch |

Invalid values return an error.

Example error condition:

```text
invalid reportEpoch "<value>" (expected "current" or "lastFinalized")
```

---

## 7. PoS activation behavior

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

Field name:

```text
posFromBlock
```

Do not use:

```text
poSFromBlock
```

The JSON field is `posFromBlock`.

---

## 8. `eth_getPosValidatorsOverview` response

### 8.1 Top-level fields

| Field | Type | Meaning |
|---|---|---|
| `blockNumber` | quantity | Current head block number |
| `epochSize` | quantity | IBFT / staking epoch size in blocks |
| `microEpochSize` | quantity | Current micro-epoch size in blocks |
| `currentMicroEpoch` | quantity | Current micro-epoch index |
| `currentMicroEpochStartBlock` | quantity | Start block of the current micro-epoch |
| `currentMicroEpochEndBlock` | quantity | End block of the current micro-epoch |
| `currentEpoch` | quantity | Current staking/IBFT epoch |
| `lastFinalizedEpoch` | quantity | Last finalized epoch |
| `reportedEpoch` | quantity | Epoch used for reported reward/slash fields |
| `reportedEpochStartBlock` | quantity | Start block of the reported epoch |
| `reportedEpochEndBlock` | quantity | End block of the reported epoch |
| `currentEpochPendingRewards` | quantity | Live FeePool balance pending next epoch finalization |
| `stakingContractBalance` | quantity | Live staking contract balance |
| `minimumNumValidators` | quantity | Minimum validator count from staking contract |
| `maximumNumValidators` | quantity | Maximum validator count from staking contract |
| `validatorThreshold` | quantity | Validator eligibility threshold from staking contract |
| `totalCurrentStake` | quantity | Sum of current stake over returned validators |
| `rewardIneligibleCount` | quantity | Number of reward-ineligible validators in reported epoch |
| `slashedCount` | quantity | Number of slashed validators in reported epoch |
| `rewardIneligibleStatusExact` | boolean | Whether reward-ineligible status was computed exactly |
| `slashStatusExact` | boolean | Whether slash status was computed exactly |
| `lastRoundStakeExact` | boolean | Whether last-round stake distribution was computed exactly |
| `lastRoundDistributedStake` | quantity | Recorded total reward for the last finalized epoch |
| `monitoringNotes` | string array | Endpoint semantics and caveats |
| `validators` | array | Validator entries |
| `posActive` | boolean | Whether PoS is active at current head |
| `posFromBlock` | quantity, optional | PoS activation block if configured |

### 8.2 Example response shape

```json
{
  "blockNumber": "0x1234",
  "epochSize": "0x1f4",
  "microEpochSize": "0x32",
  "currentMicroEpoch": "0x24",
  "currentMicroEpochStartBlock": "0x1201",
  "currentMicroEpochEndBlock": "0x1232",
  "currentEpoch": "0xa",
  "lastFinalizedEpoch": "0x9",
  "reportedEpoch": "0x9",
  "reportedEpochStartBlock": "0xfa1",
  "reportedEpochEndBlock": "0x1194",
  "currentEpochPendingRewards": "0x0",
  "stakingContractBalance": "0x0",
  "minimumNumValidators": "0x4",
  "maximumNumValidators": "0x64",
  "validatorThreshold": "0x0",
  "totalCurrentStake": "0x0",
  "rewardIneligibleCount": "0x0",
  "slashedCount": "0x0",
  "rewardIneligibleStatusExact": true,
  "slashStatusExact": true,
  "lastRoundStakeExact": true,
  "lastRoundDistributedStake": "0x0",
  "validators": [],
  "posActive": true,
  "posFromBlock": "0x0",
  "monitoringNotes": []
}
```

---

## 9. Validator entry fields

Each item in `validators` contains validator-specific staking, consensus and monitoring data.

| Field | Type | Meaning |
|---|---|---|
| `address` | address | Validator address |
| `joinedAtBlock` | quantity, optional | Block where the validator joined |
| `joinEffectiveAtBlock` | quantity, optional | Epoch-boundary block where join becomes effective |
| `currentStake` | quantity | Current stake from staking contract state |
| `currentlyValidating` | boolean | Whether the validator is in the current consensus header validator set |
| `stakingActive` | boolean | Active flag from staking contract validator info |
| `deactivatedAtBlock` | quantity, optional | Block where validator deactivation was recorded |
| `deactivateEffectiveAtBlock` | quantity, optional | Epoch-boundary block where deactivation becomes effective |
| `unstakeAvailableAtBlock` | quantity, optional | Block after which unstake / withdraw can become available |
| `canUnstakeNow` | boolean | Whether current epoch permits unstake after deactivation |
| `wasValidatorLastEpoch` | boolean | Whether validator was in the last finalized epoch set |
| `reportedEpochReward` | quantity, optional | Validator total reward for reported epoch |
| `reportedEpochRewardValidatorNet` | quantity, optional | Validator net reward |
| `reportedEpochRewardCommission` | quantity, optional | Validator commission reward |
| `reportedEpochRewardDelegatorsNet` | quantity, optional | Delegator net reward total for this validator |
| `rewardIneligible` | boolean, optional | Reward-ineligible status for reported epoch |
| `slashed` | boolean, optional | Slashed status for reported epoch |
| `microNominalWeight` | quantity, optional | Current nominal micro-epoch weight |
| `microEffectiveWeight` | quantity, optional | Current effective micro-epoch weight |
| `microInactivity` | quantity, optional | Current inactivity counter |
| `proposalUptimeLast3EpochsBps` | quantity, optional | Rolling proposer-duty uptime over last 3 epochs, in basis points |
| `proposalUptimeLast10EpochsBps` | quantity, optional | Rolling proposer-duty uptime over last 10 epochs, in basis points |
| `proposalUptimeLast3EpochsPercent` | quantity, optional | Rolling proposer-duty uptime over last 3 epochs, integer percent |
| `proposalUptimeLast10EpochsPercent` | quantity, optional | Rolling proposer-duty uptime over last 10 epochs, integer percent |
| `proposalUptimeLast3EpochsObserved` | quantity | Observed proposer duties in 3-epoch window |
| `proposalUptimeLast10EpochsObserved` | quantity | Observed proposer duties in 10-epoch window |

---

## 10. Validator status semantics

### 10.1 `currentlyValidating`

`currentlyValidating` is derived from the current consensus header validator set.

It is a consensus visibility field.

It is not derived only from staking contract active status.

A validator can be active in staking state but not currently validating if the validator-set transition has not yet become effective or if the validator is outside the current consensus snapshot.

### 10.2 `stakingActive`

`stakingActive` is read from staking contract validator information.

It reflects staking contract state.

It is not a direct replacement for `currentlyValidating`.

### 10.3 `wasValidatorLastEpoch`

`wasValidatorLastEpoch` indicates whether the validator was visible in the last finalized epoch validator set.

The endpoint prefers epoch-keyed PoS state.

If epoch-keyed PoS state is missing, it may use the last-finalized epoch-end consensus header snapshot for RPC visibility.

This is a monitoring and display field.

It is not a consensus fallback.

### 10.4 Join and deactivation effective blocks

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

## 11. Reward and slash semantics

Reward and slash fields are reported for `reportedEpoch`.

Relevant fields:

| Field | Meaning |
|---|---|
| `reportedEpochReward` | Total validator reward for selected reported epoch |
| `reportedEpochRewardValidatorNet` | Validator net reward |
| `reportedEpochRewardCommission` | Validator commission |
| `reportedEpochRewardDelegatorsNet` | Total delegator net reward |
| `rewardIneligible` | Whether validator is reward-ineligible for reported epoch |
| `slashed` | Whether validator is slashed for reported epoch |
| `rewardIneligibleCount` | Count of reward-ineligible validators |
| `slashedCount` | Count of slashed validators |
| `lastRoundDistributedStake` | Total reward recorded for last finalized epoch |

`rewardIneligible` is computed only for validators present in the reported epoch set.

`slashed` is derived from epoch-keyed PoS state for the reported epoch.

Reward values are returned in wei.

---

## 12. Proposer uptime semantics

The endpoint exposes rolling proposer-duty reliability metrics.

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

Dashboard rule:

```text
If proposalUptime...Observed is 0 and uptime fields are omitted, show "no observed proposer duties" instead of 100%.
```

---

## 13. Micro-epoch fields

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

## 14. `monitoringNotes`

The response includes `monitoringNotes`.

These notes describe important semantics that clients should respect.

Current note themes include:

- `currentlyValidating` comes from the current consensus header validator set
- `wasValidatorLastEpoch` is a monitoring/display field
- join/deactivation effective blocks are deterministic epoch-boundary markers
- reward-ineligible status is computed for validators present in the reported epoch set
- proposer uptime fields are rolling proposer-duty reliability metrics
- zero observed proposer duties do not produce fake 100% uptime
- slashed status is derived from epoch-keyed PoS state
- current epoch pending rewards are read from the live FeePool balance
- staking contract balance is read from the live staking contract account
- unstake timing is derived from deactivation block and epoch size
- numeric stake metrics are deterministic and derived from contract state plus consensus/state data
- micro fields expose current micro-epoch uptime accounting weights

Integrators should not ignore `monitoringNotes`.

They are part of the endpoint contract for display correctness.

---

## 15. `eth_getPosValidatorDelegators`

Returns delegator details for one validator.

### 15.1 Request: current epoch

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

### 15.2 Request: explicit current epoch

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

### 15.3 Request: last finalized epoch

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
| `selfStake` | quantity | Validator self-stake |
| `delegatedRaw` | quantity | Raw delegated amount |
| `delegatedActive` | quantity | Active delegated amount |
| `delegatedActiveCurrent` | quantity | Current active delegated amount |
| `totalActiveCurrentStake` | quantity | Self stake plus current active delegated stake |
| `selfStakeLive` | quantity, optional | Live validator self-stake |
| `delegatedLiveRaw` | quantity, optional | Live raw delegated stake |
| `delegatedLiveActive` | quantity, optional | Live active delegated stake |
| `totalLiveStake` | quantity, optional | Live total stake |
| `selfStakeEpochEffective` | quantity, optional | Self stake effective at reported point |
| `delegatedEpochEffective` | quantity, optional | Delegated stake effective at reported point |
| `totalEpochEffectiveStake` | quantity, optional | Total effective stake at reported point |
| `delegationEnabled` | boolean | Whether delegation is enabled for this validator |
| `maxDelegatedStake` | quantity | Maximum delegated stake allowed |
| `commissionBps` | quantity | Validator commission in basis points |
| `delegators` | array | Delegator entries |

### 16.2 Example response shape

```json
{
  "validator": "0x0000000000000000000000000000000000000000",
  "selfStake": "0x0",
  "delegatedRaw": "0x0",
  "delegatedActive": "0x0",
  "delegatedActiveCurrent": "0x0",
  "totalActiveCurrentStake": "0x0",
  "selfStakeLive": "0x0",
  "delegatedLiveRaw": "0x0",
  "delegatedLiveActive": "0x0",
  "totalLiveStake": "0x0",
  "selfStakeEpochEffective": "0x0",
  "delegatedEpochEffective": "0x0",
  "totalEpochEffectiveStake": "0x0",
  "delegationEnabled": false,
  "maxDelegatedStake": "0x0",
  "commissionBps": "0x0",
  "delegators": []
}
```

---

## 17. Delegator entry fields

Each item in `delegators` contains:

| Field | Type | Meaning |
|---|---|---|
| `delegator` | address | Delegator address |
| `amount` | quantity | Delegated amount |
| `reportedEpochReward` | quantity, optional | Delegator reward for reported epoch |
| `active` | boolean | Active flag from staking state |
| `joinedAtBlock` | quantity, optional | Block where delegator joined |
| `deactivatedAtBlock` | quantity, optional | Block where delegator deactivated |
| `effectiveAtPoint` | boolean | Whether delegator stake is effective at the selected report point |

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

Epoch-effective fields describe stake effective at the selected report point.

Relevant fields:

```text
selfStakeEpochEffective
delegatedEpochEffective
totalEpochEffectiveStake
```

These fields are useful for reward attribution, historical epoch views and validator accounting.

A delegator can exist in live state but not be effective at the selected report point.

---

## 19. Commission and delegation pool fields

The endpoint returns validator pool information.

| Field | Meaning |
|---|---|
| `delegationEnabled` | Whether the validator accepts delegation |
| `maxDelegatedStake` | Maximum delegated stake allowed |
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

## 20. `eth_getBeaconTimeStatus`

Deprecated compatibility endpoint.

### 20.1 Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getBeaconTimeStatus",
  "params": []
}
```

### 20.2 Response

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

Do not use it for validator, staking, delegation or micro-epoch monitoring.

Use the PoS overview endpoint instead when staking endpoints are available.

---

## 21. Error behavior

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

## 22. Client integration guidance

Dashboards and explorers should:

1. Use `eth_getPosValidatorsOverview` for validator overview pages.
2. Use `eth_getPosValidatorDelegators` only when delegation detail is needed.
3. Treat `eth_getBeaconTimeStatus` as deprecated.
4. Do not infer active validators from staking contract state alone.
5. Use `currentlyValidating` for current consensus participation display.
6. Use `stakingActive` for staking contract active/inactive display.
7. Show `joinEffectiveAtBlock`, `deactivateEffectiveAtBlock` and `unstakeAvailableAtBlock` for timing.
8. Show `proposalUptime...Observed` alongside uptime values.
9. Do not display 100% uptime when observed duties are zero.
10. Distinguish current stake from reported epoch reward.
11. Distinguish live stake from epoch-effective stake.
12. Treat all quantities as hex quantities.
13. Treat these endpoints as XGR-specific extensions, not Ethereum-standard RPC.
14. Probe availability before relying on them.
15. Handle method-not-found on non-staking public baseline nodes.

---

## 23. Dashboard display recommendations

### 23.1 Validator state

Recommended validator status display:

| Display field | Source field |
|---|---|
| Currently validating | `currentlyValidating` |
| Staking active | `stakingActive` |
| Current stake | `currentStake` |
| Joined at | `joinedAtBlock` |
| Effective join | `joinEffectiveAtBlock` |
| Deactivated at | `deactivatedAtBlock` |
| Effective deactivation | `deactivateEffectiveAtBlock` |
| Can unstake | `canUnstakeNow` |
| Unstake available from | `unstakeAvailableAtBlock` |

Do not collapse `currentlyValidating` and `stakingActive` into one status.

They answer different questions.

### 23.2 Rewards and slashing

Recommended reward/slash display:

| Display field | Source field |
|---|---|
| Reported epoch | `reportedEpoch` |
| Validator reward | `reportedEpochReward` |
| Validator net reward | `reportedEpochRewardValidatorNet` |
| Commission | `reportedEpochRewardCommission` |
| Delegators net reward | `reportedEpochRewardDelegatorsNet` |
| Reward ineligible | `rewardIneligible` |
| Slashed | `slashed` |

### 23.3 Uptime

Recommended uptime display:

| Display field | Source field |
|---|---|
| Last 3 epochs uptime | `proposalUptimeLast3EpochsBps` or `proposalUptimeLast3EpochsPercent` |
| Last 10 epochs uptime | `proposalUptimeLast10EpochsBps` or `proposalUptimeLast10EpochsPercent` |
| Observed duties, 3 epochs | `proposalUptimeLast3EpochsObserved` |
| Observed duties, 10 epochs | `proposalUptimeLast10EpochsObserved` |

If observed duties are zero:

```text
Display: no observed proposer duties
Do not display: 100%
```

### 23.4 Delegation

Recommended delegation display:

| Display field | Source field |
|---|---|
| Delegation enabled | `delegationEnabled` |
| Validator commission | `commissionBps` |
| Max delegated stake | `maxDelegatedStake` |
| Raw delegated stake | `delegatedRaw` |
| Active delegated stake | `delegatedActive` |
| Live total stake | `totalLiveStake` |
| Epoch-effective total stake | `totalEpochEffectiveStake` |

---

## 24. Security and exposure

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
- avoid enabling expensive staking views on overloaded validator nodes
- prefer dedicated RPC/indexer nodes for dashboards
- handle unavailable staking state gracefully
- do not expose unrelated debug/operator namespaces just because staking endpoints are public

---

## 25. Endpoint availability checklist

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

---

## 26. Summary

| Endpoint | Status | Primary use |
|---|---|---|
| `eth_getPosValidatorsOverview` | Development / preview until official staking activation | Validator overview, staking dashboard, explorer validator page |
| `eth_getPosValidatorDelegators` | Development / preview until official staking activation | Delegator table, validator pool page, reward attribution |
| `eth_getBeaconTimeStatus` | Deprecated compatibility endpoint | Do not use for current staking monitoring |

Key field corrections:

| Field | Correct name |
|---|---|
| PoS activation block | `posFromBlock` |
| Current consensus validator flag | `currentlyValidating` |
| Staking contract active flag | `stakingActive` |
| Last finalized epoch validator flag | `wasValidatorLastEpoch` |
| Live validator/delegator total stake | `totalLiveStake` |
| Epoch-effective stake | `totalEpochEffectiveStake` |
