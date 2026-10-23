# XGR Chain — Staking and Delegated PoS Model

**Document ID:** XGRCHAIN-STAKING-POS-MODEL  
**Last updated:** 2026-10-03  
**Audience:** Validators, delegators, staking UI developers, explorer developers, auditors, node operators  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Chain-level delegated PoS, staking, voting-power and epoch-economics model

---

## 1. Scope

This document defines the XGRChain delegated PoS staking model.

It covers:

- PoA-to-PoS transition,
- staking contract,
- validator self stake,
- delegated stake,
- validator eligibility,
- validator selection,
- emergency validator selection,
- BLS validator identity,
- activation and deactivation,
- delegation pools,
- epoch-effective stake,
- consensus voting stake,
- stake-weighted voting power,
- micro-epoch uptime weighting,
- FeePool epoch rewards,
- reward eligibility,
- commission,
- slashing,
- unstaking,
- public monitoring surfaces.

This document does not define:

- node installation commands,
- validator CLI procedures,
- exact RPC response schemas,
- Interchain validator participation,
- XDaLa behavior,
- XRC standards.

Operational procedures belong to:

    XGRCHAIN_Node_Operation.md

Exact PoS RPC schemas belong to:

    XGRCHAIN_Staking_PoS_Endpoint_Reference.md

---

## 2. Mainnet PoS activation

Published mainnet consensus schedule:

| Phase | Type | Validator type | From | To | Deployment |
| --- | --- | --- | ---: | ---: | ---: |
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Delegated PoS | `PoS` | `bls` | `5446500` | n/a | `5446500` |

PoS activation:

    decimal: 5446500
    hex:     0x531b64

IBFT remains the deterministic-finality consensus protocol.

Delegated PoS changes:

- validator eligibility,
- validator-set evolution,
- stake weighting,
- delegation,
- uptime weighting,
- reward distribution,
- slashing policy.

---

## 3. Mainnet PoS parameters

| Parameter | Value |
| --- | ---: |
| Chain ID | `1643` |
| Minimum validators | `4` |
| Maximum validators | `25` |
| Validator self-stake minimum | `200,000 XGR` |
| Validator total-support threshold | `2,000,000 XGR` |
| Default delegator minimum | `10,000 XGR` |
| Maximum delegators per validator | `200` |
| `microEpochSize` | `25` blocks |
| `macroEpochMicroFactor` | `40` |
| Macro epoch size | `1000` blocks |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |
| Effective FeePoolSplit activation | `5446500` |
| Default slash rate | `20 bps` |

Macro epoch:

    25 × 40 = 1000 blocks

---

## 4. Staking contract

Native staking contract:

    0x0000000000000000000000000000000000001001

Code constant:

    AddrStakingContract

The staking contract tracks:

- validator addresses,
- validator self stake,
- delegator stake,
- active/inactive state,
- BLS public keys,
- pool configuration,
- raw delegated stake,
- active delegated stake,
- join block,
- deactivation block,
- minimum validator count,
- maximum validator count,
- validator threshold,
- macro epoch size.

This state is consensus relevant.

It is not merely explorer metadata.

---

## 5. Staking constants

`StakingV2.sol` in `v3.1.1` defines:

| Constant | Value |
| --- | ---: |
| `VALIDATOR_THRESHOLD_TOTAL` | `2,000,000 XGR` |
| `VALIDATOR_MIN_SELF_STAKE` | `200,000 XGR` |
| `DELEGATOR_MIN_STAKE` | `10,000 XGR` |
| `MAX_DELEGATORS_PER_VALIDATOR` | `200` |
| `MIN_STAKE` | alias for validator threshold |

Native denomination:

    1 XGR = 10^18 wei

The two validator stake values have different meanings:

    200,000 XGR
        = minimum validator self stake

    2,000,000 XGR
        = normal validator effective total-support threshold

They must not be conflated.

---

## 6. Validator creation

A validator creates its staking position by self-staking:

    stake()

Internally:

    owner = validator = msg.sender

A new validator position requires at least:

    200,000 XGR

When created:

- staking position exists,
- position is active,
- `joinedAtBlock` is recorded,
- validator points to itself,
- validator is added to the validator list,
- pool configuration is created,
- delegation starts disabled,
- delegation cap starts at zero,
- commission starts at zero.

---

## 7. Self stake versus validator eligibility

Creating a validator staking position does not automatically make the account an active consensus validator.

Normal eligibility requires:

1. self-validator staking position exists,
2. validator is active,
3. self stake is at least `200,000 XGR`,
4. epoch-effective total stake is at least the validator threshold,
5. BLS public key is valid,
6. validator fits into the configured maximum validator set.

Mainnet threshold:

    2,000,000 XGR

Therefore a validator can legally hold:

    200,000 XGR self stake

while still being below the normal consensus eligibility threshold.

---

## 8. Epoch-effective stake

`v3.1.1` explicitly defines an epoch-effective total-stake calculation.

Implementation:

    ReadValidatorEffectiveTotalStakeAt(...)

This value is used for:

- validator eligibility,
- normal Tier-1 selection,
- epoch economic snapshots.

For this calculation:

    effectiveTotalStake =
        epoch-effective self stake
        +
        epoch-effective delegator stake

Both self stake and delegation must be effective at the target block.

---

## 9. Join maturity

A new staking position does not become epoch-effective immediately.

Conceptually:

    joined during epoch N
            ↓
    not effective inside epoch N
            ↓
    effective from later epoch boundary

The node's effective-stake logic requires:

    blockNumber / epochSize
    >
    joinedAtBlock / epochSize

for normal epoch-effective stake.

This applies to:

- validator self stake for eligibility/economic snapshots,
- delegator stake.

---

## 10. Deactivation effectiveness

A deactivated position remains epoch-effective through the epoch in which the deactivation occurred.

The effective-stake logic allows participation while:

    blockNumber / epochSize
    <=
    deactivatedAtBlock / epochSize

It ceases being effective after the next applicable epoch boundary.

This prevents intra-epoch state changes from retroactively changing the already-running epoch's stake basis.

---

## 11. Consensus voting stake

`v3.1.1` distinguishes validator eligibility stake from the stake basis used for a validator already selected into the consensus set.

Implementation:

    ReadValidatorVotingStakeAt(...)

Voting stake is:

    raw validator self stake
    +
    epoch-effective delegated stake

Important difference:

> Once a validator has already been selected into the validator set, its self stake remains part of the canonical voting-stake basis even when join/deactivation maturity rules would exclude that self stake from the normal eligibility calculation.

Delegated stake remains epoch-effective.

This distinction stabilizes consensus voting power across validator-set lifecycle boundaries.

---

## 12. Three different stake concepts

Integrators should distinguish:

| Stake concept | Purpose |
| --- | --- |
| Live staking-contract stake | Current user/contract state |
| Epoch-effective total stake | Eligibility and epoch economics |
| Voting stake | Stake basis for already-selected consensus validators |

They can differ at lifecycle boundaries.

For example, immediately after:

    join
    deactivation
    delegation change

the live contract values can differ from the stake effective for the current epoch.

---

## 13. BLS public key

XGRChain validators use BLS consensus identities.

Registration:

    registerBLSPublicKey(bytes calldata blsPubKey)

Rules:

- caller must already have a validator staking position,
- caller must be its own validator,
- key is stored in validator state,
- pool metadata mirrors the BLS key.

For BLS validator selection, `v3.1.1` attempts to decode the BLS public key.

Invalid BLS keys exclude the validator from BLS consensus selection.

---

## 14. Normal validator selection

The BLS validator fetcher reads staking state and builds the normal eligible set.

A validator is normally eligible when:

    active
    AND
    selfStake >= 200,000 XGR
    AND
    effectiveTotalStake >= validatorThreshold
    AND
    valid BLS public key

Mainnet threshold:

    validatorThreshold = 2,000,000 XGR

---

## 15. Maximum-validator selection

Mainnet:

    maxValidatorCount = 25

If the normally eligible set exceeds the maximum:

1. validators are ranked by epoch-effective total stake,
2. higher effective stake sorts first,
3. equal stake is resolved deterministically by validator address,
4. the set is truncated to the configured maximum.

Conceptually:

    eligible validators
            ↓
    sort by effective stake descending
            ↓
    address deterministic tie-break
            ↓
    take first 25

This selection is deterministic across nodes.

---

## 16. Minimum-validator emergency mode

Mainnet:

    minValidatorCount = 4

If normal eligibility produces fewer than four validators:

    emergency mode = active

and:

    noSlash = true

for that macro-epoch selection context.

This protects liveness while avoiding slashing validators under emergency-selection rules.

---

## 17. Emergency BLS selection

The BLS emergency path is broader than normal eligibility.

The implementation builds:

### Active emergency set

Contains validators that are:

- active,
- equipped with a valid BLS key.

This set does not require the normal `2,000,000 XGR` eligibility threshold.

### Weighted emergency candidates

Can include validators with:

- positive canonical voting stake,
- valid BLS key,

including inactive-but-staked validators.

If the active emergency set already contains at least the configured minimum, it is used and trimmed to the configured maximum if necessary.

Otherwise, the broader emergency candidate list is deterministically sorted by voting stake and used as fallback.

This is a liveness mechanism.

It is not the intended steady-state operating model.

---

## 18. Delegation

A delegator stakes to a validator through:

    delegate(address validator)

Requirements include:

- validator exists,
- target is a self-validator,
- delegation pool is enabled,
- delegation stays within pool cap,
- new delegation meets effective minimum,
- maximum delegator count is not exceeded.

Default minimum:

    10,000 XGR

Maximum delegators:

    200

Delegation does not grant validator identity.

---

## 19. Delegation pool configuration

Validators configure delegation using:

    setValidatorPoolConfig(
        bool delegationEnabled,
        uint256 maxTotalDelegatedStake,
        uint256 minDelegatorStake,
        uint16 commissionBps
    )

Rules:

| Field | Behavior |
| --- | --- |
| `delegationEnabled` | Allows new delegation |
| `maxTotalDelegatedStake` | Raw delegated-stake cap |
| `minDelegatorStake` | `0` uses protocol default |
| `commissionBps` | Maximum `10000` |

If a custom minimum is non-zero:

    minDelegatorStake >= 10,000 XGR

Commission examples:

    100 bps   = 1%
    500 bps   = 5%
    10000 bps = 100%

---

## 20. Initial pool state

When a validator is first created:

    delegationEnabled      = false
    maxTotalDelegatedStake = 0
    minDelegatorStake      = 0
    commissionBps          = 0

Therefore simply creating a validator does not automatically open it for delegation.

If delegation is enabled while:

    maxTotalDelegatedStake = 0

positive delegation still cannot fit under the pool cap.

---

## 21. Raw versus active delegated stake

The staking contract maintains:

    validatorDelegatedStakeRaw
    validatorDelegatedStakeActive

### Raw delegated stake

Represents delegation still assigned to the validator.

### Active delegated stake

Represents currently live-active delegated positions.

A delegator deactivation therefore causes:

    raw delegated stake      unchanged
    active delegated stake   decreases

A withdrawal or full exit reduces raw delegated stake as well.

---

## 22. Epoch-effective delegation

Neither raw nor current active delegation necessarily equals stake effective for the current consensus epoch.

For consensus eligibility and snapshots, the node evaluates every delegator using:

- join maturity,
- deactivation epoch,
- target block.

Therefore:

    delegatedRaw
    delegatedActive
    delegatedEpochEffective

are three distinct concepts.

---

## 23. Validator activation state

A validator can call:

    setActive(bool active)

Deactivation records:

    deactivatedAtBlock = block.number

The validator pool active flag follows validator active state.

A live `active=false` does not erase the position or withdraw funds.

---

## 24. Delegator activation state

Delegators use:

    setDelegationActive(
        validator,
        active
    )

Reactivation requires the delegation amount to remain above the effective minimum stake.

Active-state changes update the live delegated-active aggregate.

Epoch-effectiveness remains subject to epoch-boundary rules.

---

## 25. Unstaking

Validator full exit:

    unstake()

Delegator full exit:

    unstakeDelegation(address validator)

Prerequisites:

- position exists,
- position is inactive,
- `deactivatedAtBlock != 0`,
- current epoch is later than the deactivation epoch.

Contract condition:

    epochOf(currentBlock)
    >
    epochOf(deactivatedAtBlock)

Full validator exit removes the validator from the staking-contract validator list.

---

## 26. Partial withdrawal

Validator:

    withdraw(uint256 amount)

Delegator:

    withdrawDelegation(
        address validator,
        uint256 amount
    )

Requirements:

- position inactive,
- deactivation epoch has passed,
- amount is positive,
- amount is less than full position,
- remaining balance stays above the applicable minimum.

To remove the complete position, use the full unstake path.

---

# Consensus Voting Power

## 27. Stake-weighted IBFT

After the PoS transition matures into a PoS-parent context, IBFT uses stake-weighted voting power.

Consensus calculates a deterministic stake snapshot for each selected validator.

The stake snapshot is then modified by its current micro-epoch uptime weight.

Conceptually:

    effectiveVotingPower =
        votingStakeSnapshot
        × effectiveUptimeWeight
        ÷ nominalUptimeWeight

---

## 28. First PoS block

The PoS fork begins at:

    5446500

Its parent is:

    5446499

which is still PoA.

`v3.1.1` enables stake-weighted voting only when the **parent block is already PoS-active**.

Therefore:

    block 5446500
        PoS fork active
        parent still PoA
        → unit voting power

Then:

    block 5446501
        parent is PoS
        → stake-weighted voting power active

This is a deliberate deterministic cutover behavior.

---

## 29. Unit voting mode

When stake-weighted voting is not yet active:

    every validator power = 1

This applies to the PoA phase and the first PoS transition block described above.

---

## 30. Uptime-weighted voting power

For stake-weighted mode, the node reads:

- validator stake snapshot,
- effective micro-epoch uptime weight,
- nominal uptime weight.

If stored nominal weight is zero, it falls back to:

    microEpochNominalWeightUnits = 10000

Voting power is computed through:

    WeightedStake(...)

If:

- stake > 0,
- uptime weight > 0,
- nominal weight > 0,

but integer division would produce zero, `v3.1.1` preserves a minimum power of:

    1

---

## 31. Weighted quorum

Total voting power is the sum of validator effective voting powers.

Required quorum:

    ceil(2 × totalVotingPower / 3)

This means consensus quorum after stake weighting cannot be determined from validator count alone.

---

# Epoch and Uptime Accounting

## 32. Macro epochs

Mainnet:

    macro epoch = 1000 blocks

Macro epochs define deterministic boundaries for:

- validator-set evolution,
- economic snapshots,
- reward distribution,
- slashing evaluation.

---

## 33. Micro epochs

Mainnet:

    micro epoch = 25 blocks

Uptime state includes:

- nominal weight,
- effective weight,
- inactivity count,
- processed micro-epoch data.

Mainnet parameters:

    nominal weight = 10000
    inactivity decay = 9000 bps

This current uptime state contributes to stake-weighted consensus power.

---

## 34. Epoch validator snapshots

The PoS system creates deterministic epoch validator snapshots.

Native PoS system address:

    0x0000000000000000000000000000000000009999

Snapshot information includes:

- epoch validator set,
- validator stake snapshot,
- individual staker snapshots,
- uptime counters,
- no-slash mode.

This state supports deterministic epoch finalization.

---

## 35. Epoch boundary behavior

Epoch finalization runs when:

    header.Number > 0
    AND
    header.Number % epochSize == 0
    AND
    FeePoolSplit active

With mainnet:

    epochSize = 1000

Boundary block:

    1000

finalizes accounting for:

    blocks 1..999

Similarly:

    block 2000

finalizes the preceding epoch workload:

    blocks 1001..1999

The boundary block itself is treated as a system/finalization block for this accounting path.

---

## 36. Proposer-duty uptime

Epoch reward/slash uptime is derived from proposer duties.

For each validator:

    slots  = assigned proposer slots
    missed = missed proposer slots
    ok     = slots - missed

Uptime:

    uptimeBps =
        ok × 10000 / slots

If:

    slots = 0

the validator receives:

- zero reward weight,
- no uptime penalty.

---

# Rewards

## 37. FeePool

FeePool address:

    0x000000000000000000000000000000000000fEE2

FeePool collection/distribution is consensus relevant after:

    FeePoolSplit activation = 5446500

The epoch finalizer reads the current FeePool balance.

---

## 38. Validator reward weight

The reward policy uses proposer uptime.

| Successful proposer duties | Reward behavior |
| --- | --- |
| `>= 90%` | Full stake weight |
| `>= 80%` and `< 90%` | Linearly reduced weight |
| `< 80%` | Zero reward weight |
| No proposer slots | Zero reward weight, no penalty |

Reward eligibility is therefore:

    okSlots / slots >= 80%

---

## 39. Reduced reward range

Between 80% and 90% uptime:

    effectiveWeight =
        stakeSnapshot
        × okSlots
        × 10
        /
        (slots × 9)

At or above 90%:

    effectiveWeight =
        stakeSnapshot

Below 80%:

    effectiveWeight = 0

---

## 40. Reward distribution between validators

If the FeePool has value and total reward weight is positive:

    validatorReward =
        feePoolBalance
        × validatorEffectiveRewardWeight
        /
        sumEffectiveRewardWeights

The reward is then transferred from:

    FeePool

to:

    staking contract

and credited to staking positions.

---

## 41. Delegation reward split

For one validator reward:

    totalStake =
        selfStake
        +
        effectiveDelegatedStake

Self-stake reward:

    selfShare =
        validatorReward
        × selfStake
        /
        totalStake

Delegated share:

    delegatedShare =
        validatorReward
        -
        selfShare

Validator commission:

    commission =
        delegatedShare
        × commissionBps
        /
        10000

Delegator net reward:

    delegatorsNet =
        delegatedShare
        -
        commission

Each eligible delegator receives a proportional amount based on its effective epoch stake.

---

## 42. Rounding remainder

Integer division can leave a small remainder after delegator allocation.

The finalizer assigns this deterministic remainder to the validator.

Therefore:

    validatorNet =
        selfStakeReward
        +
        commission
        +
        delegatorRemainder

and verifies that:

    validatorNet
    +
    delegatorPayments
    =
    validatorReward

---

## 43. Reward compounding

Reward credits increase staking positions directly.

For validator reward:

    validator stake increases

For delegator reward:

    delegator stake increases

Delegator reward also updates validator delegated aggregates according to the delegator's current live active state.

Rewards therefore compound into future staking state.

---

# Slashing

## 44. Slashing threshold

A validator enters the slashing path when:

    successful proposer duties < 50%

Code condition:

    okSlots × 2 < slots

This is stricter than the reward-ineligibility threshold.

Therefore:

    <80%
        → no epoch reward

    <50%
        → no epoch reward
          + possible slash

---

## 45. Slash rate

Current `v3.1.1` default:

    20 bps

Equivalent:

    0.2%

Slash calculations are subject to the staking/effective-stake constraints implemented by the finalizer.

---

## 46. No-slash emergency mode

Slashing is enabled only when the macro-epoch snapshot says:

    noSlashMode = false

Emergency validator selection stores:

    noSlashMode = true

for the affected macro-epoch context.

Therefore emergency validator fallback does not expose validators to normal epoch slashing.

---

## 47. Slash destination

Current `v3.1.1` slash destination resolves to:

    0x0000000000000000000000000000000000000666

The implementation describes slashed stake as burned at this address.

---

## 48. Zero successful proposer duties

If:

    okSlots = 0

the epoch finalizer can additionally mark the validator inactive in staking state.

This is separate from the percentage slash calculation.

---

# Public Monitoring

## 49. PoS monitoring RPC

Primary methods:

    eth_getPosValidatorsOverview
    eth_getPosValidatorDelegators

The overview exposes live information such as:

- validator set,
- self stake,
- delegation,
- active state,
- consensus membership,
- effective lifecycle blocks,
- proposer uptime,
- micro uptime weight,
- FeePool pending balance,
- staking-contract balance.

---

## 50. Live state versus historical accounting

The PoS RPC does not provide complete permanent historical reward/slash accounting.

Historical finalized economic records are emitted as deterministic PoS system logs.

For historical analytics, index:

    canonical receipts
    +
    PosSysAddr system logs

Do not infer historical reward history from only current staking balances.

---

## 51. Explorer guidance

Explorers should distinguish:

| Display item | Meaning |
| --- | --- |
| Self stake | Current validator position |
| Raw delegation | Assigned delegation |
| Active delegation | Current live-active delegation |
| Epoch-effective delegation | Stake effective for epoch accounting |
| Total effective support | Eligibility/economic stake |
| Voting stake | Consensus stake basis for selected validator |
| Effective voting power | Voting stake modified by uptime |
| Currently validating | Current IBFT header validator set |
| Staking active | Current staking-contract lifecycle state |
| Pending rewards | Current FeePool balance |
| Finalized reward | Historical system log |

These values should not be collapsed into one generic:

    stake

field.

---

## 52. Validator UI guidance

A validator view should expose at least:

- validator address,
- self stake,
- delegated raw stake,
- delegated active stake,
- epoch-effective total stake,
- threshold,
- staking active state,
- currently-validating state,
- BLS status,
- delegation enabled,
- pool cap,
- minimum delegation,
- commission,
- join effective block,
- deactivation effective block,
- unstake availability,
- uptime weight,
- proposer reliability.

---

## 53. Delegator UI guidance

A delegator view should expose:

- validator,
- current delegated amount,
- active/inactive status,
- epoch-effective amount,
- commission,
- pool minimum,
- pool cap,
- join timing,
- deactivation timing,
- withdrawal availability.

A delegation should not be shown as contributing to the current epoch merely because the transaction has already finalized.

---

## 54. Key integration rules

1. `200,000 XGR` is the minimum validator self stake, not the normal validator eligibility threshold.
2. `2,000,000 XGR` is the normal total-support threshold.
3. Use epoch-effective total stake for normal validator eligibility.
4. Do not assume live stake is already epoch-effective.
5. Distinguish validator eligibility stake from selected-validator voting stake.
6. Delegated stake must satisfy epoch-effectiveness rules.
7. BLS validity is required for BLS validator selection.
8. `currentlyValidating` is the authoritative live consensus-set indicator exposed by PoS RPC.
9. More than 25 normally eligible validators are deterministically ranked by effective stake.
10. Fewer than four normally eligible validators activates emergency selection and no-slash mode.
11. The first PoS block uses the transition/unit voting path because its parent is still PoA.
12. Subsequent PoS voting power is stake- and uptime-weighted.
13. Historical rewards/slashes should be indexed from canonical logs.
14. Emergency-mode behavior must be accounted for when interpreting historical slashing.
15. Do not mix XGRChain consensus staking with Interchain validator participation.

---

## 55. Mainnet summary

| Topic | `v3.1.1` mainnet behavior |
| --- | --- |
| PoS activation | `5446500` / `0x531b64` |
| Finality protocol | IBFT |
| Validator cryptography | BLS |
| Staking contract | `0x0000000000000000000000000000000000001001` |
| FeePool | `0x000000000000000000000000000000000000fEE2` |
| PoS system address | `0x0000000000000000000000000000000000009999` |
| Slash destination | `0x0000000000000000000000000000000000000666` |
| Minimum validators | `4` |
| Maximum validators | `25` |
| Minimum validator self stake | `200,000 XGR` |
| Normal total-support threshold | `2,000,000 XGR` |
| Default delegation minimum | `10,000 XGR` |
| Max delegators | `200` |
| Macro epoch | `1000` blocks |
| Micro epoch | `25` blocks |
| Nominal uptime weight | `10000` |
| Inactivity decay | `9000` bps |
| Full reward | `>= 90%` proposer duty success |
| Reduced reward | `>= 80%` and `< 90%` |
| Reward ineligible | `< 80%` |
| Slash threshold | `< 50%` |
| Default slash | `20 bps` / `0.2%` |
| Emergency selection | Active if normal eligible count `< 4` |
| Emergency slashing | Disabled |
| First PoS block voting | Unit voting |
| Later PoS voting | Stake + uptime weighted |

---

## 56. Design principle

The XGRChain PoS model intentionally separates four concepts:

    staking position
            ↓
    epoch-effective eligibility
            ↓
    selected validator voting stake
            ↓
    uptime-weighted consensus power

A staking transaction alone does not grant immediate consensus authority.

Delegation alone does not grant validator identity.

Live balances do not automatically equal current epoch-effective stake.

And validator count alone does not determine PoS quorum.

This separation allows XGRChain to combine delegated economic support, deterministic validator-set transitions, IBFT finality and uptime-sensitive consensus weighting without making intra-epoch staking changes retroactively alter the current consensus epoch.
