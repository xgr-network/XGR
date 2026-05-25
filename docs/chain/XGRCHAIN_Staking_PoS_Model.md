# XGR Chain — Staking and Delegated PoS Model

**Document ID:** XGRCHAIN-STAKING-POS-MODEL  
**Last updated:** 2026-05-24  
**Audience:** Validators, delegators, staking UI developers, explorer developers, auditors, node operators  
**Release baseline:** `xgr-node` release tag `v2.0.5`  
**Mainnet genesis source:** `xgr-network/XGR` branch `main`, path `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Chain-level delegated PoS and staking model only

---

## 1. Scope

This document defines the XGR Chain delegated PoS staking model.

It covers:

- PoA to delegated PoS transition
- staking contract role
- validator self-stake
- delegated stake
- validator eligibility
- validator activation and deactivation
- delegation pool configuration
- epoch and micro-epoch behavior
- FeePool-based epoch rewards
- uptime-based reward weighting
- slashing conditions
- public monitoring surfaces
- explorer and staking-interface guidance

This document does not define:

- node installation commands
- validator run commands
- JSON-RPC schema details
- UI behavior
- XDaLa behavior
- XRC standards

Node operation belongs to the node-operation runbook.

Exact PoS RPC schemas belong to the staking / PoS endpoint reference.

---

## 2. Mainnet PoS activation

The published mainnet genesis defines the IBFT participation schedule:

| Phase | Type | Validator type | From | To | Deployment |
|---|---|---|---:|---:|---:|
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Delegated PoS phase | `PoS` | `bls` | `5446500` | n/a | `5446500` |

Delegated PoS activation block:

```text
5446500
```

IBFT remains the deterministic-finality consensus protocol.

Delegated PoS changes how the active validator set is derived.

---

## 3. Mainnet PoS parameters

Published mainnet parameters:

| Parameter | Value |
|---|---:|
| Chain ID | `1643` |
| Minimum validators | `4` |
| Maximum validators | `25` |
| `microEpochSize` | `25` blocks |
| `macroEpochMicroFactor` | `40` |
| Derived PoS epoch size | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |
| FeePoolSplit activation | `5446500` |

The PoS epoch size is derived as:

```text
microEpochSize * macroEpochMicroFactor
```

For mainnet:

```text
25 * 40 = 1000 blocks
```

---

## 4. Staking contract

The delegated PoS system uses the native staking contract.

Code-level address:

```text
0x0000000000000000000000000000000000001001
```

Code-level constant:

```text
AddrStakingContract = types.StringToAddress("1001")
```

The staking contract tracks:

- validator addresses
- validator self-stake
- validator active state
- BLS public keys
- validator pool configuration
- delegator stake
- raw delegated stake
- active delegated stake
- join block
- deactivation block
- minimum and maximum validator counts
- validator threshold
- epoch size

The staking contract is consensus-critical.

Do not treat staking state as an off-chain index.

---

## 5. Staking constants

`StakingV2.sol` defines these constants:

| Constant | Value |
|---|---:|
| `VALIDATOR_THRESHOLD_TOTAL` | `2,000,000 XGR` |
| `VALIDATOR_MIN_SELF_STAKE` | `200,000 XGR` |
| `DELEGATOR_MIN_STAKE` | `10,000 XGR` |
| `MAX_DELEGATORS_PER_VALIDATOR` | `200` |
| `MIN_STAKE` | alias for `VALIDATOR_THRESHOLD_TOTAL` |

All XGR amounts use 18 decimals internally:

```text
1 XGR = 10^18 wei
```

So the raw contract values are expressed as `ether` units in Solidity.

---

## 6. Validator lifecycle

A validator is created by staking to itself.

At contract level:

```solidity
stake()
```

internally calls:

```solidity
_stakeFor(msg.sender, msg.sender, msg.value)
```

A new validator position requires:

```text
amount >= VALIDATOR_MIN_SELF_STAKE
```

For mainnet:

```text
minimum validator self-stake = 200,000 XGR
```

When the validator position is first created:

- `exists = true`
- `active = true`
- `joinedAtBlock = block.number`
- `validator = own address`
- address is appended to `_validators`
- validator pool config is created
- delegation is initially disabled
- commission is initially `0`

The validator must also have a registered BLS public key for BLS validator operation.

---

## 7. Validator threshold and eligibility

Validator eligibility is not based only on self-stake.

Normal validator eligibility requires:

1. validator is active
2. validator self-stake is at least `VALIDATOR_MIN_SELF_STAKE`
3. validator effective total stake is at least `VALIDATOR_THRESHOLD_TOTAL`
4. BLS public key is valid for BLS validator mode
5. validator is selected within the maximum validator count if there are more eligible validators than allowed

For mainnet:

```text
minimum self-stake = 200,000 XGR
validator threshold = 2,000,000 XGR
maximum validators = 25
```

Effective total stake includes validator self-stake and epoch-effective active delegated stake.

If there are more eligible validators than `maxNumValidators`, the validator store trims the selected set using weighted stake-based selection.

---

## 8. Emergency validator selection

If the normal eligibility filter produces fewer validators than `minNumValidators`, the node enters a broader validator-selection path.

For mainnet:

```text
minNumValidators = 4
```

In this mode:

- the selected validator set can be derived from a broader active/emergency candidate set
- the no-slash mode is enabled for that selection path
- this is a safety mechanism to preserve network liveness

This is not the normal target operating mode.

A healthy mainnet should have enough normally eligible validators.

---

## 9. BLS public key registration

Validator mode uses BLS validators.

The staking contract exposes:

```solidity
registerBLSPublicKey(bytes calldata blsPubKey)
```

Rules:

- caller must already be a validator
- caller must be self-validator, not just delegator
- BLS public key is stored in validator state
- BLS public key is mirrored into validator pool config

Consensus validator selection for BLS mode excludes validators whose BLS public key cannot be decoded as valid BLS public key.

---

## 10. Delegation model

A delegator stakes to a validator through:

```solidity
delegate(address validator)
```

Delegation requires:

- target validator exists
- target validator is a self-validator
- delegation pool is enabled
- amount does not exceed pool cap
- new delegator stake is at least effective minimum delegator stake
- validator does not exceed max delegator count

Default minimum delegator stake:

```text
10,000 XGR
```

Maximum delegators per validator:

```text
200
```

Delegation does not make the delegator a validator.

Delegation increases the validator's delegated stake and can help the validator reach the total validator threshold.

---

## 11. Validator pool configuration

A validator can configure its delegation pool through:

```solidity
setValidatorPoolConfig(
    bool delegationEnabled,
    uint256 maxTotalDelegatedStake,
    uint256 minDelegatorStake,
    uint16 commissionBps
)
```

Rules:

| Field | Rule |
|---|---|
| `delegationEnabled` | enables or disables delegation |
| `maxTotalDelegatedStake` | total raw delegated stake cap |
| `minDelegatorStake` | `0` means use default `DELEGATOR_MIN_STAKE`; otherwise must be at least `10,000 XGR` |
| `commissionBps` | must be `<= 10000` |

Commission basis points:

```text
10000 bps = 100%
500 bps = 5%
100 bps = 1%
```

Important:

If delegation is enabled but `maxTotalDelegatedStake = 0`, no positive delegation can fit into the pool cap.

---

## 12. Raw delegated stake vs active delegated stake

The staking contract tracks two delegated stake aggregates:

| Field | Meaning |
|---|---|
| `validatorDelegatedStakeRaw` | total delegated stake assigned to validator |
| `validatorDelegatedStakeActive` | delegated stake currently marked active |

A delegator can be active or inactive.

When a delegator stakes and is active:

```text
raw delegated stake increases
active delegated stake increases
```

When a delegator is set inactive:

```text
raw delegated stake remains
active delegated stake decreases
```

When a delegator withdraws or fully exits:

```text
raw delegated stake decreases
active delegated stake decreases if the position was active
```

---

## 13. Activation timing

The staking contract stores:

```text
joinedAtBlock
deactivatedAtBlock
```

The contract exposes:

```solidity
joinEffectiveAtBlock(address account)
deactivationEffectiveAtBlock(address account)
```

Effective block formula:

```text
effectiveAt = (epochOf(changeBlock) + 1) * epochSize
```

At contract level:

```text
epochOf(blockNumber) = blockNumber / epochSize
```

with integer division.

Practical meaning:

- a newly joined validator/delegator does not become epoch-effective inside the same epoch
- a deactivation remains relevant until the next epoch boundary
- epoch-boundary behavior is deterministic and block-number-based

For mainnet:

```text
epochSize = 1000 blocks
```

---

## 14. Active state and epoch-effective state

There are two different concepts:

| Concept | Meaning |
|---|---|
| Live active flag | current staking-contract `active` value |
| Epoch-effective participation | whether the position is effective for the epoch being finalized or reported |

A call to:

```solidity
setActive(false)
```

changes the validator's live active flag immediately.

However, consensus and reward accounting use epoch snapshots and epoch-effective rules.

This prevents last-block toggles from rewriting the accounting basis for an already-running epoch.

---

## 15. Validator deactivation

A validator deactivates with:

```solidity
setActive(false)
```

Rules:

- validator must exist
- validator must currently be active
- `deactivatedAtBlock = block.number`
- pool active flag follows validator active flag

Deactivation does not automatically withdraw stake.

Deactivation is a prerequisite for withdrawing or unstaking.

---

## 16. Delegation deactivation

A delegator deactivates a delegation with:

```solidity
setDelegationActive(address validator, bool active_)
```

Rules:

- delegator position must exist
- delegator must be assigned to that validator
- requested state must differ from current state
- when activating again, amount must still satisfy effective minimum stake

Delegator active state affects active delegated stake.

---

## 17. Withdraw and unstake

The staking contract supports partial withdraw and full exit.

Validator:

```solidity
withdraw(uint256 amount)
unstake()
```

Delegator:

```solidity
withdrawDelegation(address validator, uint256 amount)
unstakeDelegation(address validator)
```

Preconditions:

- position must exist
- position must be inactive
- `deactivatedAtBlock` must be non-zero
- the current epoch must be greater than the deactivation epoch

Contract-level timing rule:

```text
epochOf(block.number) > epochOf(deactivatedAtBlock)
```

Partial withdraw rules:

- amount must be greater than zero
- amount must be smaller than current stake
- remaining stake must stay above the applicable minimum

Full exit:

- removes the full position
- removes validator from validator list if validator exits
- removes delegator from validator delegator list if delegator exits
- emits `Unstaked`

---

## 18. Validator selection

Validator selection reads staking contract state.

Normal selection filters validators by:

- active flag
- self-stake minimum
- total active stake threshold
- valid BLS key in BLS mode

If the number of eligible validators exceeds the configured maximum, the set is trimmed using weighted stake-based selection.

Mainnet maximum:

```text
25 validators
```

The active consensus validator set is derived by the node.

Do not infer the consensus validator set only from the raw `_validators` list.

---

## 19. Epoch snapshots

PoS accounting freezes snapshots per epoch.

During uptime accounting, the node freezes:

- epoch validator membership
- validator stake snapshot
- staker stake snapshots
- effective delegator snapshots

This ensures that stake changes during an epoch do not retroactively distort that epoch's reward/slash calculation.

Snapshot state is kept in the native PoS system area:

```text
0x0000000000000000000000000000000000009999
```

This is internal chain state, not a user-facing account.

---

## 20. Micro-epoch uptime accounting

Mainnet has:

```text
microEpochSize = 25 blocks
microEpochNominalWeightUnits = 10000
microEpochInactivityDecayBps = 9000
```

The node records proposer-duty availability from finalized block headers.

The accounting model:

- genesis block is ignored
- epoch boundary blocks are skipped
- proposer slots are attributed per assigned proposer attempt
- missed proposer slots are derived from failed rounds
- successful finalized round is attributed to the actual finalized proposer
- micro-epoch weights are kept for uptime weighting

This avoids using commit-signature counting as the uptime source.

---

## 21. Epoch finalization

Epoch finalization runs at epoch boundary blocks.

Condition:

```text
header.Number > 0
header.Number % epochSize == 0
FeePoolSplit is active
```

The boundary block finalizes the epoch ending at:

```text
header.Number - 1
```

For example, with `epochSize = 1000`:

```text
block 1000 finalizes epoch 1 covering blocks 1..999
block 2000 finalizes epoch 2 covering blocks 1001..1999
```

Epoch boundary blocks are treated as system/finalization blocks for PoS accounting.

---

## 22. FeePool rewards

After PoS activation, validator fee accounting uses the FeePool path.

FeePool address:

```text
0x000000000000000000000000000000000000fEE2
```

At epoch finalization:

1. current FeePool balance is read
2. effective validator weights are calculated
3. each validator receives a share proportional to effective weight
4. each validator share is transferred from FeePool to staking contract
5. staking balances are credited internally
6. deterministic PoS system logs are emitted

Validator reward share:

```text
validatorShare = feePoolBalance * validatorEffectiveWeight / sumEffectiveWeights
```

If FeePool balance is zero, no payout is distributed.

If sum of effective weights is zero, no payout is distributed.

---

## 23. Reward split between validator and delegators

For each validator reward share:

1. self-stake share is calculated from validator self-stake
2. delegated share is calculated from active delegated stake
3. validator commission is taken from delegated share
4. delegators receive delegated net amount pro rata
5. rounding remainder is assigned to validator net

Formula:

```text
totalActiveStake = selfStake + activeDelegatedStake

selfShare = validatorReward * selfStake / totalActiveStake

delegatedShare = validatorReward - selfShare

commission = delegatedShare * commissionBps / 10000

delegatorsNet = delegatedShare - commission

delegatorPart = delegatorsNet * delegatorStake / activeDelegatedStake

validatorNet = selfShare + commission + delegatorRemainder
```

If there are no active delegations, the full reward is validator net.

---

## 24. Uptime reward weighting

At epoch finalization, each validator's proposer duty is evaluated.

Definitions:

```text
slots = proposer slots assigned to validator
missed = missed proposer slots
okSlots = slots - missed
uptimeBps = okSlots * 10000 / slots
```

Reward weighting:

| Uptime | Reward weight |
|---|---|
| no slots | zero reward weight, no penalty |
| `>= 90%` | full stake weight |
| `>= 80%` and `< 90%` | linearly reduced stake weight |
| `< 80%` | zero reward weight |
| `< 50%` | zero reward weight and slashing path can apply |

Linear reduced weight between 80% and 90%:

```text
effectiveWeight = stakeSnapshot * okSlots * 10 / (slots * 9)
```

A validator with zero successful proposer slots can also be set inactive by the epoch finalization logic.

---

## 25. Slashing

Default slashing rate:

```text
20 bps = 0.2%
```

Slashing applies only when:

- validator proposer performance is below the slashing threshold
- slashing mode is enabled
- stake snapshot is above the no-slash floor
- staking contract balance is sufficient

Slashing is proportional across validator and effective delegator positions.

Slash destination:

```text
0x0000000000000000000000000000000000000666
```

The slash amount is capped by:

- stake snapshot
- effective total stake
- staking contract balance

If the emergency no-slash mode is active, slashing is skipped.

---

## 26. Public monitoring RPC

Public PoS monitoring methods:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

High-level overview fields include:

- block number
- epoch size
- micro-epoch size
- current epoch
- current micro-epoch
- current epoch pending rewards
- staking contract balance
- minimum validator count
- maximum validator count
- validator threshold
- total current stake
- total validator self-stake
- total delegated raw stake
- total delegated active stake
- total active current stake
- validator entries
- PoS activation status
- PoS activation block

Validator fields include:

- address
- joined block
- join effective block
- current stake
- self-stake
- delegated raw stake
- delegated active stake
- total active current stake
- current consensus membership flag
- staking active flag
- deactivation block
- deactivation effective block
- unstake available block
- can unstake now
- reward eligibility fields
- proposer uptime metrics
- micro-epoch weight fields

Delegator fields include:

- delegator address
- amount
- epoch-effective amount
- active flag
- joined block
- deactivated block
- effective-at-point flag

---

## 27. Explorer guidance

Explorers should distinguish clearly between:

| Display concept | Source |
|---|---|
| Live validator self-stake | staking contract |
| Live delegated raw stake | staking contract |
| Live delegated active stake | staking contract |
| Current consensus validator set | current consensus header / PoS overview |
| Epoch-effective stake | PoS system snapshots |
| FeePool pending rewards | FeePool balance |
| Finalized reward events | PoS system receipts/logs |
| Slashing events | PoS system receipts/logs |

Do not infer the active validator set only from the raw validator list.

Do not treat raw delegated stake as epoch-effective delegated stake.

Do not treat current live stake as historical epoch stake.

---

## 28. Staking UI guidance

Staking interfaces should show these validator facts:

- validator address
- self-stake
- delegated raw stake
- delegated active stake
- total active stake
- validator threshold
- active/inactive state
- currently validating state
- delegation enabled
- pool cap
- effective minimum delegator stake
- commission bps
- max delegator limit
- join effective block
- deactivation effective block
- unstake availability
- current FeePool pending rewards

For delegators, UI should show:

- assigned validator
- delegated amount
- active state
- epoch-effective amount
- validator commission
- pool cap
- minimum delegation
- withdrawal timing after deactivation

---

## 29. Important integration rules

1. Use live RPC for current state.
2. Use receipts/logs for finalized historical reward and slashing accounting.
3. Do not hardcode validator set membership.
4. Do not treat stake changes as effective inside the same epoch.
5. Do not assume a validator is consensus-active just because it exists in the staking contract.
6. Do not assume delegations are effective immediately for the current epoch.
7. Do not ignore BLS public-key validity in BLS validator mode.
8. Do not ignore maximum validator count.
9. Do not ignore no-slash emergency mode when interpreting slashing.
10. Do not mix chain documentation with XDaLa or XRC application-layer behavior.

---

## 30. Summary

| Topic | Mainnet behavior |
|---|---|
| PoS activation | block `5446500` |
| Consensus finality | IBFT |
| Validator type | BLS |
| Staking contract | `0x0000000000000000000000000000000000001001` |
| FeePool address | `0x000000000000000000000000000000000000fEE2` |
| PoS system address | `0x0000000000000000000000000000000000009999` |
| Minimum validators | `4` |
| Maximum validators | `25` |
| Validator self-stake minimum | `200,000 XGR` |
| Validator total threshold | `2,000,000 XGR` |
| Default delegator minimum | `10,000 XGR` |
| Max delegators per validator | `200` |
| Epoch size | `1000` blocks |
| Micro-epoch size | `25` blocks |
| Full reward threshold | `>= 90%` proposer uptime |
| Reduced reward range | `80%` to `< 90%` proposer uptime |
| Reward-ineligible threshold | `< 80%` proposer uptime |
| Slashing threshold | `< 50%` proposer uptime |
| Default slash rate | `20 bps` |
| Public PoS RPC | `eth_getPosValidatorsOverview`, `eth_getPosValidatorDelegators` |
