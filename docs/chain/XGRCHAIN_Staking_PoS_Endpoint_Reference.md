# XGR Chain — Staking / PoS JSON-RPC Endpoint Reference

**Document ID:** XGRCHAIN-STAKING-POS-RPC  
**Last updated:** 2026-05-24  
**Audience:** RPC integrators, explorer developers, dashboard developers, validator operators, backend developers, auditors  
**Implementation status:** XGR2.0 mainnet baseline  
**Source of truth:** `xgr-network/xgr-node` branch `XGR2.0`, file `jsonrpc/eth_pos_overview.go`; published XGR mainnet genesis `xgr-network/XGR:genesis/mainnet/genesis.json`

---

## 1. Scope

This document describes the public XGR-specific staking / PoS JSON-RPC methods implemented on the `Eth` JSON-RPC endpoint in `jsonrpc/eth_pos_overview.go`.

The public PoS methods documented here are:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

These methods are exposed through the Ethereum-style `eth_*` namespace, but they are **not standard Ethereum JSON-RPC methods**.

This document is intentionally strict:

- only public staking / PoS methods relevant for XGR2.0 are documented
- only parameters present in the active method signatures are documented
- only JSON fields produced by the current code path are documented as returned
- fields that exist in Go structs but are not populated by the current code path are explicitly marked as not currently returned
- internal, deprecated or legacy compatibility methods are not part of this public reference
- no UI behavior is defined here
- no XDaLa or XRC behavior is defined here

---

## 2. Mainnet PoS context

The published XGR mainnet genesis defines the IBFT type schedule as:

| Phase | Type | Validator type | From | To | Deployment |
|---|---|---|---:|---:|---:|
| Pre-XGR2.0 | `PoA` | `bls` | `0` | `5446499` | n/a |
| XGR2.0 and later | `PoS` | `bls` | `5446500` | n/a | `5446500` |

Mainnet PoS activation:

```text
5446500
```

Mainnet PoS deployment:

```text
5446500
```

Mainnet validator limits from genesis:

| Field | Value |
|---|---:|
| `minValidatorCount` | `4` |
| `maxValidatorCount` | `25` |

Mainnet epoch configuration from genesis:

| Field | Value |
|---|---:|
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Derived PoS epoch size | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

The RPC code resolves the active PoS epoch size as:

```text
microEpochSize * macroEpochMicroFactor
```

For mainnet:

```text
25 * 40 = 1000
```

---

## 3. Public method summary

| JSON-RPC method | Go method | Status | Purpose |
|---|---|---|---|
| `eth_getPosValidatorsOverview` | `(*Eth).GetPosValidatorsOverview(reportEpoch *string)` | Active | Returns validator, stake, delegation, epoch and monitoring overview |
| `eth_getPosValidatorDelegators` | `(*Eth).GetPosValidatorDelegators(validator types.Address, reportEpoch *string)` | Active | Returns delegation and pool details for one validator |

No other PoS-related RPC method is part of this public endpoint reference.

---

## 4. Encoding rules

Numeric values returned via `argUint64` or `argBig` are Ethereum-style JSON-RPC quantities.

Rules:

- hexadecimal string
- `0x` prefix
- no decimal formatting
- no leading zero padding except `0x0`
- stake and reward values are in wei
- basis point values are integer quantities
- address values are Ethereum-style `0x` addresses
- booleans are JSON booleans
- arrays are JSON arrays
- omitted fields are not present in the JSON response

Native denomination:

```text
1 XGR = 10^18 wei
```

---

## 5. `eth_getPosValidatorsOverview`

### 5.1 Go signature

```go
func (e *Eth) GetPosValidatorsOverview(reportEpoch *string) (interface{}, error)
```

### 5.2 Parameters

The method accepts zero or one parameter.

| Parameter index | Type | Required | Allowed values |
|---:|---|---|---|
| `0` | string | no | `current`, `lastFinalized` |

If no parameter is provided, the method reports the current epoch context.

Valid calls:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": []
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["current"]
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorsOverview",
  "params": ["lastFinalized"]
}
```

Invalid `reportEpoch` values return:

```text
invalid reportEpoch "<value>" (expected "current" or "lastFinalized")
```

### 5.3 PoS activation check

The method resolves the PoS activation block from `params.engine.ibft.types[]`.

It scans for entries with:

```text
type = "PoS"
```

and uses the minimum `from` value.

If the chain head is before that block, the method returns:

```text
PoS is not active yet (activates at block <N>)
```

On XGR mainnet, the expected `posFromBlock` is:

```text
5446500
```

### 5.4 Top-level response fields

The response object is `posOverviewResponse`.

The current code returns these top-level fields:

| JSON field | Type | Always present | Meaning |
|---|---|---:|---|
| `blockNumber` | quantity | yes | Current head block number |
| `epochSize` | quantity | yes | Resolved epoch size; in PoS mode `microEpochSize * macroEpochMicroFactor` |
| `microEpochSize` | quantity | yes | Current micro-epoch size after runtime adjustment |
| `currentMicroEpoch` | quantity | yes | Current micro-epoch index |
| `currentMicroEpochStartBlock` | quantity | yes | Start block of current micro-epoch |
| `currentMicroEpochEndBlock` | quantity | yes | End block of current micro-epoch |
| `currentEpoch` | quantity | yes | Current epoch number |
| `lastFinalizedEpoch` | quantity | yes | Last finalized epoch number |
| `reportedEpoch` | quantity | yes | Epoch selected by `reportEpoch` |
| `reportedEpochStartBlock` | quantity | yes | Start block of reported epoch |
| `reportedEpochEndBlock` | quantity | yes | End block of reported epoch context |
| `currentEpochPendingRewards` | quantity | yes | Live FeePool balance at current head |
| `stakingContractBalance` | quantity | yes | Live staking contract balance at current head |
| `minimumNumValidators` | quantity | yes | Staking contract minimum validator count |
| `maximumNumValidators` | quantity | yes | Staking contract maximum validator count |
| `validatorThreshold` | quantity | yes | Staking contract validator threshold |
| `totalCurrentStake` | quantity | yes | Sum of current validator self-stake over returned validators |
| `totalValidatorSelfStake` | quantity | yes | Sum of validator self-stake |
| `totalDelegatedRawStake` | quantity | yes | Sum of raw delegated stake |
| `totalDelegatedActiveStake` | quantity | yes | Sum of active delegated stake |
| `totalActiveCurrentStake` | quantity | yes | Sum of validator self-stake plus active delegated stake |
| `rewardIneligibleCount` | quantity | yes | Count computed by endpoint for reported epoch context |
| `slashedCount` | quantity | yes | Current code computes this from `slashed=false`; normally `0x0` |
| `rewardIneligibleStatusExact` | boolean | yes | Current code returns `true` |
| `slashStatusExact` | boolean | yes | Current code returns `false` |
| `lastRoundStakeExact` | boolean | yes | Current code returns `false` |
| `lastRoundDistributedStake` | quantity | yes | Current code returns zero-value `big.Int` |
| `monitoringNotes` | string array | yes | Human-readable endpoint caveats from the node |
| `validators` | array | yes | Validator entries |
| `posActive` | boolean | yes | `true` when no PoS schedule exists or `head >= posFromBlock` |
| `posFromBlock` | quantity | only if PoS schedule exists | First PoS activation block |

### 5.5 Top-level values fixed by current code

The current code sets:

```text
rewardIneligibleStatusExact = true
slashStatusExact = false
lastRoundStakeExact = false
lastRoundDistributedStake = 0
```

The current code also sets `slashed=false` for every validator entry in the overview response.

Therefore:

```text
slashedCount
```

is expected to be zero in the current implementation path.

---

## 6. Validator entries in `eth_getPosValidatorsOverview`

Each item in `validators` is `posValidatorOverview`.

### 6.1 Returned validator fields

| JSON field | Type | Present when | Meaning |
|---|---|---|---|
| `address` | address | always | Validator address |
| `currentStake` | quantity | always | Current validator self-stake |
| `currentlyValidating` | boolean | always | Whether validator is in the current consensus header validator set |
| `stakingActive` | boolean | always | Active flag from staking contract validator info if available; otherwise default false |
| `canUnstakeNow` | boolean | always | Whether unstake is currently available after deactivation |
| `wasValidatorLastEpoch` | boolean | always | Whether validator was visible in last finalized epoch context |
| `proposalUptimeLast3EpochsObserved` | quantity | always | Observed proposer duties in 3-epoch window |
| `proposalUptimeLast10EpochsObserved` | quantity | always | Observed proposer duties in 10-epoch window |
| `rewardIneligible` | boolean | always | Computed for validators present in reported epoch set; false otherwise |
| `slashed` | boolean | always | Current code sets this to false |
| `selfStake` | quantity | currently populated | Same stake amount as validator self-stake |
| `delegatedRawStake` | quantity | currently populated | Raw delegated stake for validator |
| `delegatedActiveStake` | quantity | currently populated | Active delegated stake for validator |
| `totalActiveCurrentStake` | quantity | currently populated | Self stake plus active delegated stake |
| `joinedAtBlock` | quantity | if joined block query returns > 0 | Block where validator joined |
| `joinEffectiveAtBlock` | quantity | if `joinedAtBlock` is present | Next epoch boundary after join block |
| `deactivatedAtBlock` | quantity | if validator has non-zero deactivation block | Block where deactivation was recorded |
| `deactivateEffectiveAtBlock` | quantity | if deactivation block is present | Next epoch boundary after deactivation block |
| `unstakeAvailableAtBlock` | quantity | if deactivation block is present | Next epoch boundary after deactivation block |
| `microNominalWeight` | quantity | if nominal/effective/inactivity value exists | Current nominal micro-epoch weight |
| `microEffectiveWeight` | quantity | if nominal/effective/inactivity value exists | Current effective micro-epoch weight |
| `microInactivity` | quantity | if nominal/effective/inactivity value exists | Current inactivity counter |
| `proposalUptimeLast3EpochsBps` | quantity | if observed slots exist | Rolling proposer-duty uptime over last 3 epochs in bps |
| `proposalUptimeLast10EpochsBps` | quantity | if observed slots exist | Rolling proposer-duty uptime over last 10 epochs in bps |
| `proposalUptimeLast3EpochsPercent` | quantity | if 3-epoch bps is present | Integer percent derived from bps / 100 |
| `proposalUptimeLast10EpochsPercent` | quantity | if 10-epoch bps is present | Integer percent derived from bps / 100 |

### 6.2 Struct fields not currently populated in overview code path

The Go struct contains these JSON fields, but the current overview implementation does not assign them before returning the response.

Because they are tagged with `omitempty`, they are not currently returned by the overview endpoint:

```text
reportedEpochReward
reportedEpochRewardValidatorNet
reportedEpochRewardCommission
reportedEpochRewardDelegatorsNet
```

Do not document these as active returned overview fields unless the code starts assigning them.

---

## 7. `currentlyValidating` semantics

`currentlyValidating` is derived strictly from the current consensus header validator snapshot.

The implementation reads validators from the current consensus header and then sets:

```text
currentlyValidating = address in current consensus header validator set
```

It is not inferred from stake alone.

It is not inferred from `stakingActive` alone.

This distinction is important:

| Field | Meaning |
|---|---|
| `stakingActive` | Staking contract active flag |
| `currentlyValidating` | Current consensus validator-set visibility |

A validator can be active in staking state and still not be currently validating.

---

## 8. `rewardIneligible` semantics

The endpoint computes `rewardIneligible` only for validators present in the reported epoch validator set.

For those validators, the logic reads proposer slot and missed proposer slot counters from PoS system storage and applies:

```text
okSlots = slots - missed
rewardIneligible = okSlots * 10 < slots * 8
```

If the validator is not in the reported epoch set, `rewardIneligible` remains false.

---

## 9. `slashed` semantics in current code

The current overview implementation sets:

```text
slashed = false
```

for every validator entry.

It does not currently call `isValidatorSlashedInEpoch` in the active overview loop.

Therefore:

```text
slashStatusExact = false
slashedCount = 0
```

under the current implementation path.

Do not present `slashed` as exact historical slash data from this endpoint.

---

## 10. Micro-epoch fields

The response includes current micro-epoch fields:

```text
microEpochSize
currentMicroEpoch
currentMicroEpochStartBlock
currentMicroEpochEndBlock
```

The current implementation reads micro-epoch configuration from chain params and then applies one runtime guard:

```text
if microEpochSize > 0 && validatorCount > 0 && microEpochSize < validatorCount:
    microEpochSize = 0
```

If `microEpochSize` becomes zero, current micro-epoch start/end fields remain zero.

For XGR mainnet with `microEpochSize = 25` and max validators `25`, this guard is expected not to disable micro-epochs under normal validator counts.

---

## 11. `eth_getPosValidatorDelegators`

### 11.1 Go signature

```go
func (e *Eth) GetPosValidatorDelegators(validator types.Address, reportEpoch *string) (interface{}, error)
```

### 11.2 Parameters

The method accepts one required parameter and one optional parameter.

| Parameter index | Type | Required | Allowed values |
|---:|---|---|---|
| `0` | address | yes | Validator address |
| `1` | string | no | `current`, `lastFinalized` |

Valid calls:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": ["0x0000000000000000000000000000000000000000"]
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": ["0x0000000000000000000000000000000000000000", "current"]
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": ["0x0000000000000000000000000000000000000000", "lastFinalized"]
}
```

Invalid `reportEpoch` values return:

```text
invalid reportEpoch "<value>" (expected "current" or "lastFinalized")
```

### 11.3 Response fields

The response object is `posValidatorDelegatorsResponse`.

| JSON field | Type | Always present | Meaning |
|---|---|---:|---|
| `validator` | address | yes | Validator address from request |
| `selfStake` | quantity | yes | Live validator self-stake |
| `delegatedRaw` | quantity | yes | Live raw delegated stake |
| `delegatedActive` | quantity | yes | Live active delegated stake |
| `delegatedActiveCurrent` | quantity | yes | `totalActiveCurrentStake - selfStake`, clamped at zero |
| `totalActiveCurrentStake` | quantity | yes | Self stake plus active delegated stake |
| `selfStakeLive` | quantity | yes | Copy of live self-stake |
| `delegatedLiveRaw` | quantity | yes | Copy of live raw delegated stake |
| `delegatedLiveActive` | quantity | yes | Copy of live active delegated stake |
| `totalLiveStake` | quantity | yes | Copy of total active current stake |
| `selfStakeEpochEffective` | quantity | yes | Epoch-effective self-stake from PoS system storage |
| `delegatedEpochEffective` | quantity | yes | Sum of effective delegator stake entries |
| `totalEpochEffectiveStake` | quantity | yes | Epoch-effective total stake from PoS system storage |
| `delegationEnabled` | boolean | yes | Pool configuration flag |
| `maxTotalDelegatedStake` | quantity | yes | Pool maximum total delegated stake |
| `minDelegatorStake` | quantity | yes | Pool minimum delegator stake |
| `effectiveMinDelegatorStake` | quantity | yes | Effective minimum delegator stake |
| `commissionBps` | quantity | yes | Validator commission in basis points |
| `delegators` | array | yes | Delegator entries |

If pool configuration is missing, the code creates a fallback pool object with:

```text
maxTotalDelegatedStake = 0
```

Other missing pool fields then remain their zero values.

### 11.4 Delegator entry fields

Each item in `delegators` is `posDelegatorEntry`.

| JSON field | Type | Always present | Meaning |
|---|---|---:|---|
| `delegator` | address | yes | Delegator address |
| `amount` | quantity | yes | Delegator live staker amount |
| `epochEffectiveAmount` | quantity | yes | Epoch-effective stake snapshot for reported epoch |
| `active` | boolean | yes | Delegator active flag from staker info |
| `joinedAtBlock` | quantity | yes | Joined-at block from staker info; zero if missing |
| `deactivatedAtBlock` | quantity | yes | Deactivated-at block from staker info; zero if missing |
| `effectiveAtPoint` | boolean | yes | Whether epoch-effective amount is greater than zero |

The method skips the validator address itself when iterating validator stakers:

```text
if owner == validator:
    continue
```

Delegator entries are sorted by delegator address string.

### 11.5 Struct field not currently populated in delegator entry code path

The Go struct contains:

```text
reportedEpochReward
```

But the current implementation does not assign it when appending `posDelegatorEntry`.

Because it has `omitempty`, it is not currently returned by `eth_getPosValidatorDelegators`.

Do not document `reportedEpochReward` as an active delegator-entry response field unless the code starts assigning it.

---

## 12. Error behavior

### 12.1 Common errors

| Condition | Error |
|---|---|
| Current head is nil | `header has a nil value` |
| Invalid `reportEpoch` | `invalid reportEpoch "<value>" (expected "current" or "lastFinalized")` |
| PoS overview called before configured PoS activation | `PoS is not active yet (activates at block <N>)` |
| Missing chain params in epoch resolver | `missing chain params` |
| Missing IBFT engine config in epoch resolver | `missing ibft engine config` |
| Invalid IBFT engine config type | `invalid ibft engine config type <T>` |
| PoS epoch config missing micro/macro values | `unable to resolve PoS epoch size: missing valid microEpochSize/macroEpochMicroFactor` |
| PoS macro epoch multiplication overflow | `macro epoch size overflow: microEpochSize=<N> macroEpochMicroFactor=<N>` |
| Missing non-PoS epoch configuration | `unable to resolve IBFT epoch size: missing valid epoch configuration` |

### 12.2 Method availability

Clients must still handle:

```text
method not found
```

because not every public or third-party RPC node is required to expose XGR-specific methods.

---

## 13. Client integration rules

Clients must follow these rules:

1. Treat all numeric response fields as JSON-RPC quantities.
2. Do not parse stake values as decimals.
3. Do not assume `stakingActive` means currently validating.
4. Use `currentlyValidating` for current consensus-set visibility.
5. Use `posActive` and `posFromBlock` for PoS activation visibility.
6. Do not hard-code the old PoA `epochSize`.
7. For XGR2.0 mainnet, expect PoS epoch size `1000`.
8. Do not present `slashed` from the overview endpoint as exact slash history.
9. Do not present `reportedEpochReward*` overview fields as active unless the code starts populating them.
10. Do not present delegator `reportedEpochReward` as active unless the code starts populating it.
11. Use logs/indexing for public historical analytics.
12. Treat this document as invalidated whenever `jsonrpc/eth_pos_overview.go` changes.

---

## 14. Code-backed field checklist

### 14.1 Public methods

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

### 14.2 Overview response fields currently returned

```text
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
```

`posFromBlock` is returned only if a PoS schedule is found.

### 14.3 Validator fields currently returned when populated

```text
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
```

### 14.4 Delegator response fields currently returned

```text
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
```

### 14.5 Delegator entry fields currently returned

```text
delegator
amount
epochEffectiveAmount
active
joinedAtBlock
deactivatedAtBlock
effectiveAtPoint
```

---

## 15. Summary

| Topic | Current XGR2.0 public PoS RPC behavior |
|---|---|
| Overview method | `eth_getPosValidatorsOverview` |
| Delegator method | `eth_getPosValidatorDelegators` |
| Overview optional parameter | `current` or `lastFinalized` |
| Delegator required parameter | validator address |
| Delegator optional parameter | `current` or `lastFinalized` |
| Overview PoS activation guard | yes |
| Delegator PoS activation guard | no explicit `posFromBlock` guard in the method body |
| Overview slash exactness | `false` |
| Overview slashed flag | current code sets false |
| Overview last-round stake exactness | `false` |
| Overview reward-ineligible exactness | `true` |
| Mainnet PoS activation block | `5446500` |
| Mainnet PoS epoch size | `1000` blocks |

This reference must be updated whenever `jsonrpc/eth_pos_overview.go` changes.
