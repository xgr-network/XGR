# XGR Chain - Staking / PoS Endpoint Reference

**Document ID:** XGRCHAIN-STAKING-POS-RPC  
**Last updated:** 2026-05-24  
**Audience:** Dashboard developers, explorer developers, validator operators, backend integrators, auditors  
**Implementation status:** XGR2.0 mainnet baseline with delegated PoS active  
**Source of truth:** `xgr-network/XGR` `main` branch `genesis/mainnet/genesis.json`, public `xgr-network/xgr-node` branch `XGR2.0`, active RPC implementation in `jsonrpc/eth_pos_overview.go`, and official XGR Network operator announcements

---

## 1. Scope

This document describes XGR Chain staking / PoS related JSON-RPC endpoints exposed by the XGR2.0 node.

The endpoints are XGR-specific extensions exposed through the Ethereum-style `eth_*` JSON-RPC namespace.

They are not standard Ethereum JSON-RPC methods.

This document covers:

- `eth_getPosValidatorsOverview`
- `eth_getPosValidatorDelegators`
- PoS activation behavior
- validator overview response schema
- validator delegation response schema
- live-state versus epoch-state semantics
- reward, slash and uptime visibility
- indexing requirements for historical data

This document does not define:

- frontend/UI behavior
- explorer rendering behavior
- XDaLa behavior
- XRC standards
- staking contract source-code documentation beyond fields required to interpret the RPC response

---

## 2. Mainnet PoS activation

The published mainnet genesis defines the IBFT type schedule as:

| Phase | Type | Validator type | From | To | Deployment |
|---|---|---|---:|---:|---:|
| Pre-XGR2.0 | `PoA` | `bls` | `0` | `5446499` | n/a |
| XGR2.0 and later | `PoS` | `bls` | `5446500` | n/a | `5446500` |

The delegated PoS activation block is:

```text
5446500
```

The PoS deployment block is:

```text
5446500
```

The active PoS validator-count limits are:

| Field | Value |
|---|---:|
| `minValidatorCount` | `4` |
| `maxValidatorCount` | `25` |

The active PoS epoch configuration is:

| Field | Value |
|---|---:|
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Derived macro epoch size | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

---

## 3. Endpoint summary

| Method | Purpose | XGR2.0 status |
|---|---|---|
| `eth_getPosValidatorsOverview` | Returns deterministic live validator, staking, delegation, epoch and reward-state overview data | Active |
| `eth_getPosValidatorDelegators` | Returns live delegation and delegation-pool data for one validator | Active |

The following endpoint is not documented as active here:

| Method | Status |
|---|---|
| `eth_getBeaconTimeStatus` | Not included in this code-backed XGR2.0 reference unless an active implementation is present in the node release |

Do not expose or document `eth_getBeaconTimeStatus` as active unless the method exists in the active node code.

---

## 4. Namespace

The endpoints are exposed through the `eth_*` namespace:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
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
- stake and reward values use 18-decimal native units

Native denomination:

```text
1 XGR = 10^18 wei
```

Address values are returned as Ethereum-style `0x` addresses.

Boolean values are returned as JSON booleans.

---

## 6. Live state versus historical data

XGR Chain separates live staking state from finalized epoch history.

### 6.1 Live staking state

Live staking state is read from current chain state, staking contract state and PoS system storage.

It includes:

- current validator self-stake
- current delegated raw stake
- current delegated active stake
- current validator active/inactive status
- current consensus validator-set visibility
- current FeePool balance
- current staking contract balance
- micro-epoch accounting weights where available
- current delegation pool configuration

Live staking state is exposed through RPC endpoints.

### 6.2 Current epoch working state

During an active epoch, the node can maintain PoS working state.

This working state may include:

- proposer slots
- missed proposer slots
- epoch validator snapshots
- reward totals
- validator reward values
- slash state
- effective micro-epoch weights

This state is used for deterministic PoS accounting and endpoint reporting.

### 6.3 Historical data

Finalized historical reward, slash, uptime and stake-after history must not be reconstructed from a single live RPC call unless the endpoint explicitly reads the relevant persisted state.

Explorers and dashboards that need complete historical views should index receipts/logs and system state changes.

RPC responses are live state plus selected epoch context, not a complete analytical database.

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
| `lastFinalized` | Report last finalized epoch context where available from state/header snapshots |

Invalid values return an error:

```text
invalid reportEpoch "<value>" (expected "current" or "lastFinalized")
```

---

## 8. PoS activation behavior

The endpoint resolves PoS activation from the chain configuration.

The implementation scans `params.engine.ibft.types[]` and finds the first entry with:

```text
type = "PoS"
```

It then uses the minimum `from` block of matching PoS entries as the PoS activation block.

For XGR2.0 mainnet:

```text
posFromBlock = 5446500
```

If the current head is before the PoS activation block, the endpoint returns an error:

```text
PoS is not active yet (activates at block <N>)
```

If PoS metadata is available and the current head is at or after the activation block, the response includes:

```json
"posActive": true,
"posFromBlock": "0x531c04"
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
| `epochSize` | quantity | Derived PoS macro-epoch size in blocks |
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
| `rewardIneligibleCount` | quantity, optional | Count of reward-ineligible validators |
| `slashedCount` | quantity, optional | Count of slashed validators |
| `rewardIneligibleStatusExact` | boolean | Whether reward-ineligible status is exact from available state |
| `slashStatusExact` | boolean | Whether slash status is exact from available state |
| `lastRoundStakeExact` | boolean | Whether last-round distributed stake is exact from available state |
| `lastRoundDistributedStake` | quantity, optional | Last finalized reward total read from PoS system state |
| `monitoringNotes` | string array | Endpoint semantics and caveats |
| `validators` | array | Validator entries |
| `posActive` | boolean | Whether PoS is active at current head |
| `posFromBlock` | quantity, optional | PoS activation block if configured |

### 9.2 Notes on `epochSize`

In XGR2.0 PoS mode, the active macro epoch size is derived from:

```text
microEpochSize * macroEpochMicroFactor
```

For mainnet:

```text
25 * 40 = 1000 blocks
```

The endpoint should report this derived PoS epoch size, not the old PoA-era `epochSize = 500`.

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
| `currentlyValidating` | boolean | Whether validator is in the current consensus header validator set |
| `stakingActive` | boolean | Active flag from staking contract validator info |
| `deactivatedAtBlock` | quantity, optional | Block where validator deactivation was recorded |
| `deactivateEffectiveAtBlock` | quantity, optional | Epoch-boundary block where deactivation becomes effective |
| `unstakeAvailableAtBlock` | quantity, optional | Block after which unstake / withdraw can become available |
| `canUnstakeNow` | boolean | Whether current epoch permits unstake after deactivation |
| `wasValidatorLastEpoch` | boolean | Whether validator was visible in last finalized epoch context |
| `reportedEpochReward` | quantity, optional | Validator reward for the reported epoch, if available in PoS system state |
| `reportedEpochRewardValidatorNet` | quantity, optional | Validator net reward for reported epoch |
| `reportedEpochRewardCommission` | quantity, optional | Commission reward for reported epoch |
| `reportedEpochRewardDelegatorsNet` | quantity, optional | Delegator net reward for reported epoch |
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

The implementation prefers epoch-keyed PoS state and can fall back to the last-finalized epoch-end header snapshot if epoch state is missing.

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

## 12. `eth_getPosValidatorDelegators`

Returns live delegation and delegation-pool data for one validator.

### 12.1 Request

The endpoint is intended to be called with the validator address.

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "eth_getPosValidatorDelegators",
  "params": ["0xValidatorAddress"]
}
```

Clients must treat this endpoint as XGR-specific.

The address parameter must be a valid Ethereum-style address.

### 12.2 Response fields

| Field | Type | Meaning |
|---|---|---|
| `validator` | address | Validator address |
| `selfStake` | quantity | Validator self-stake |
| `delegatedRaw` | quantity | Raw delegated stake |
| `delegatedActive` | quantity | Active delegated stake |
| `delegatedActiveCurrent` | quantity | Currently active delegated stake |
| `totalActiveCurrentStake` | quantity | Self stake plus active delegated stake |
| `selfStakeLive` | quantity, optional | Live self-stake |
| `delegatedLiveRaw` | quantity, optional | Live raw delegated stake |
| `delegatedLiveActive` | quantity, optional | Live active delegated stake |
| `totalLiveStake` | quantity, optional | Live self stake plus live delegated active stake |
| `selfStakeEpochEffective` | quantity, optional | Epoch-effective self-stake |
| `delegatedEpochEffective` | quantity, optional | Epoch-effective delegated stake |
| `totalEpochEffectiveStake` | quantity, optional | Epoch-effective total stake |
| `delegationEnabled` | boolean | Whether delegation is enabled for this validator |
| `maxTotalDelegatedStake` | quantity | Maximum total delegated stake accepted by validator pool |
| `minDelegatorStake` | quantity | Configured minimum delegator stake |
| `effectiveMinDelegatorStake` | quantity | Effective minimum delegator stake after runtime rules |
| `commissionBps` | quantity | Validator commission in basis points |
| `delegators` | array | Delegator entries |

### 12.3 Delegator entry fields

Each item in `delegators` contains:

| Field | Type | Meaning |
|---|---|---|
| `delegator` | address | Delegator address |
| `amount` | quantity | Delegated amount |
| `epochEffectiveAmount` | quantity, optional | Amount effective for the reported/current epoch context |
| `reportedEpochReward` | quantity, optional | Delegator reward for reported epoch if available |
| `active` | boolean | Whether delegation is active |
| `joinedAtBlock` | quantity, optional | Block where delegation joined |
| `deactivatedAtBlock` | quantity, optional | Block where delegation was deactivated |
| `effectiveAtPoint` | boolean | Whether delegation is effective at the current/reported point |

---

## 13. Reward and slash semantics

### 13.1 Current rule

Reward and slash data exposed by RPC is tied to live chain state and PoS system state.

The endpoint reads epoch reward and slash values from deterministic PoS system keys where available.

Relevant logical state categories include:

```text
xgr.pos.prop.slots
xgr.pos.prop.miss
xgr.pos.epoch.validators.len
xgr.pos.epoch.validators.val
xgr.pos.slashed
xgr.pos.reward.total
xgr.pos.reward.validator
```

### 13.2 RPC limitations

The RPC overview endpoint may expose current or selected epoch context data.

It does not replace a full historical log/indexing pipeline.

For complete historical analytics, dashboards and explorers should index receipts/logs across finalized epochs.

### 13.3 Display rule

If a dashboard displays reward/slash data from RPC, it must label the value as:

```text
live / endpoint-reported epoch state
```

unless it has independently indexed and reconciled finalized logs.

---

## 14. Proposer uptime semantics

The overview endpoint can expose proposer uptime fields.

Relevant fields:

```text
proposalUptimeLast3EpochsBps
proposalUptimeLast10EpochsBps
proposalUptimeLast3EpochsPercent
proposalUptimeLast10EpochsPercent
proposalUptimeLast3EpochsObserved
proposalUptimeLast10EpochsObserved
```

Semantics:

- `Bps` values are basis points
- `Percent` values are integer percentages
- `Observed` values are observed proposer duties in the rolling window
- absence of optional fields means the value is not available in the current response context

Uptime is a PoS monitoring and weighting signal.

It must not be confused with generic node uptime.

---

## 15. Delegation semantics

Delegated PoS distinguishes several stake categories.

| Category | Meaning |
|---|---|
| self stake | Stake owned by validator |
| raw delegated stake | Total delegated stake recorded for validator |
| active delegated stake | Delegated stake currently active for PoS accounting |
| live stake | Stake read from current contract state |
| epoch-effective stake | Stake effective for the epoch context |
| total active current stake | Validator self stake plus active delegated stake |

Delegation can be enabled or disabled per validator pool.

A validator can define:

- maximum total delegated stake
- minimum delegator stake
- effective minimum delegator stake
- commission basis points

Commission is represented in basis points.

```text
10000 bps = 100%
```

---

## 16. Error behavior

Known error conditions include:

| Condition | Error behavior |
|---|---|
| Current head is unavailable | Returns `header has a nil value` |
| Invalid `reportEpoch` | Returns `invalid reportEpoch "<value>" (expected "current" or "lastFinalized")` |
| Current head is before configured PoS activation | Returns `PoS is not active yet (activates at block <N>)` |
| Staking contract query fails | Returns the underlying query error |
| Invalid validator address | JSON-RPC parameter decoding error |
| Missing validator/delegation state | Endpoint-specific error or zero/empty response depending on implementation path |

Clients must not assume that all public RPC nodes expose these methods.

Recommended client behavior:

1. Probe method availability.
2. Handle `method not found`.
3. Handle PoS-not-active errors.
4. Handle empty validator/delegator arrays.
5. Treat numeric values as hex quantities.
6. Use logs/indexing for historical analytics.

---

## 17. Monitoring notes

The overview endpoint returns a `monitoringNotes` array.

The current implementation uses it to expose important caveats, including:

- `currentlyValidating` is derived from the current consensus header validator set
- `wasValidatorLastEpoch` prefers epoch-keyed PoS state and can fall back to last-finalized epoch-end header snapshot
- join and deactivation effective blocks are deterministic epoch-boundary markers
- `rewardIneligible` is computed only for validators present in the reported epoch set
- `slashed` is derived from epoch-keyed PoS state for the reported epoch
- `lastRoundDistributedStake` is read from consensus epoch reward state
- `currentEpochPendingRewards` is the live FeePool balance pending next epoch switch
- `stakingContractBalance` is the live staking contract balance
- unstake fields are derived from validator deactivation state and epoch size
- numeric stake metrics are derived from contract state and events

Dashboards should surface these caveats where they affect interpretation.

---

## 18. Security and correctness rules for clients

Client implementations must follow these rules:

1. Do not treat these endpoints as standard Ethereum RPC.
2. Do not use decimal parsing for quantity fields.
3. Do not infer validator authority from `stakingActive` alone.
4. Use `currentlyValidating` for current consensus-set visibility.
5. Use `posActive` and `posFromBlock` for PoS activation visibility.
6. Use `genesis/mainnet/genesis.json` as the source of published activation parameters.
7. Treat delegation and reward data as live/epoch-context data unless backed by historical indexing.
8. Do not hard-code epoch size as `500`.
9. For XGR2.0 mainnet, use derived PoS epoch size `1000`.
10. Handle unavailable methods gracefully.

---

## 19. Example: overview response shape

Simplified example:

```json
{
  "blockNumber": "0x532000",
  "epochSize": "0x3e8",
  "microEpochSize": "0x19",
  "currentMicroEpoch": "0x1",
  "currentEpoch": "0x153",
  "lastFinalizedEpoch": "0x152",
  "currentEpochPendingRewards": "0x0",
  "stakingContractBalance": "0x0",
  "minimumNumValidators": "0x4",
  "maximumNumValidators": "0x19",
  "validatorThreshold": "0x...",
  "totalCurrentStake": "0x...",
  "totalValidatorSelfStake": "0x...",
  "totalDelegatedRawStake": "0x...",
  "totalDelegatedActiveStake": "0x...",
  "totalActiveCurrentStake": "0x...",
  "posActive": true,
  "posFromBlock": "0x531c04",
  "validators": []
}
```

The example is structural.

Do not copy numeric values from the example into production code.

---

## 20. Example: validator delegators response shape

Simplified example:

```json
{
  "validator": "0xValidatorAddress",
  "selfStake": "0x...",
  "delegatedRaw": "0x...",
  "delegatedActive": "0x...",
  "delegatedActiveCurrent": "0x...",
  "totalActiveCurrentStake": "0x...",
  "delegationEnabled": true,
  "maxTotalDelegatedStake": "0x...",
  "minDelegatorStake": "0x...",
  "effectiveMinDelegatorStake": "0x...",
  "commissionBps": "0x0",
  "delegators": [
    {
      "delegator": "0xDelegatorAddress",
      "amount": "0x...",
      "active": true,
      "effectiveAtPoint": true
    }
  ]
}
```

The example is structural.

Do not copy numeric values from the example into production code.

---

## 21. Summary

| Topic | XGR2.0 behavior |
|---|---|
| PoS active from | block `5446500` |
| PoS deployment | block `5446500` |
| Endpoint namespace | `eth_*` |
| Active overview endpoint | `eth_getPosValidatorsOverview` |
| Active delegation endpoint | `eth_getPosValidatorDelegators` |
| Deprecated/unsupported endpoint | `eth_getBeaconTimeStatus` not part of this active reference |
| Quantity format | Ethereum JSON-RPC hex quantities |
| Stake denomination | wei |
| Mainnet micro epoch | `25` blocks |
| Mainnet macro factor | `40` |
| Mainnet derived epoch size | `1000` blocks |
| Validator min/max | `4` / `25` |
| Historical analytics | Use indexing; do not rely only on live RPC |
