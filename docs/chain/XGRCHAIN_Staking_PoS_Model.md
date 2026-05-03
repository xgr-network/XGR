# XGR Chain — Staking PoS Model

**Document ID:** XGRCHAIN-STAKING-POS-MODEL  
**Last updated:** 2026-05-03  
**Audience:** Protocol developers, validator operators, delegators, node operators, auditors  
**Implementation status:** In development / `PoS_3`  
**Source of truth:** `xgrchain` branch `PoS_3`, `contracts/staking`, `command/ibft/*`, `consensus/ibft/pos/*`, `jsonrpc/eth_pos_overview.go`

---

## 1. Scope

This document describes the XGR Chain **IBFT-PoS staking model** as implemented on the `PoS_3` branch.

It covers:

- permissionless validator join
- validator self-stake
- BLS public key registration
- validator activation/deactivation
- stake increase
- unstake / withdraw flow
- effective validator support
- epoch-boundary timing
- proposer-uptime accounting
- micro-epoch weight accounting
- FeePool-based rewards
- uptime-based reward eligibility
- slashing behavior
- monitoring model

This document does **not** describe old Polygon Rootchain/Supernet staking.

Removed / legacy concepts:

- rootchain `StakeManager`
- `CustomSupernetManager`
- WMATIC staking
- rootchain validator allowlisting
- rootchain finalization of genesis validator set
- childchain/rootchain bridge exits
- Polygon Supernet staking flows
- Beacon recovery logic

---

## 2. High-level model

The `PoS_3` model keeps **IBFT finality** but changes validator participation from a purely permissioned validator set toward a staking-backed validator model.

At a high level:

1. A validator has local ECDSA and BLS validator keys.
2. The validator funds the ECDSA validator account with enough XGR for gas and stake.
3. The validator joins by staking and registering its BLS public key on the staking contract.
4. The validator must satisfy the self-stake threshold.
5. Eligibility for active validation is evaluated by the staking/validator selection path.
6. Validator-set changes become effective at deterministic epoch boundaries.
7. Uptime/reward logic runs in deterministic IBFT hooks.
8. FeePool rewards are distributed at epoch finalization using stake and uptime-derived effective weights.

---

## 3. Staking contract

The staking contract is located at the XGR native staking predeploy address:

```text
0x0000000000000000000000000000000000001001
```

The node-side helper constant is:

```go
AddrStakingContract = types.StringToAddress("1001")
```

Important read methods used by the node include:

| Method | Purpose |
|---|---|
| `validators()` | returns validator addresses |
| `validatorBLSPublicKeys()` | returns BLS public keys |
| `accountStake(address)` | returns account stake |
| `validatorInfo(address)` | returns validator metadata |
| `stakerInfo(address)` | returns delegator/staker metadata |
| `minNumValidators()` | minimum validator count |
| `maxNumValidators()` | maximum validator count |
| `VALIDATOR_THRESHOLD()` | validator eligibility threshold |
| `VALIDATOR_MIN_SELF_STAKE()` | minimum validator self-stake |
| `epochSize()` | staking contract epoch size |

Important write methods used by CLI commands include:

| Method | CLI path | Purpose |
|---|---|---|
| `stake()` payable | `xgrchain ibft stake` / `join` | increase stake |
| `registerBLSPublicKey(bytes)` | `xgrchain ibft join` | register BLS consensus key |
| `setActive(bool)` | `xgrchain ibft set-active` | activate/deactivate validator flag |
| `unstake()` | `xgrchain ibft unstake` | full unstake / exit path |
| `withdraw(uint256)` | `xgrchain ibft withdraw` | partial stake withdrawal |

---

## 4. Validator keys

A validator requires:

| Key | Purpose |
|---|---|
| ECDSA validator key | validator account, staking transactions, proposer seal |
| BLS validator key | IBFT consensus sealing / BLS public key registration |
| libp2p network key | p2p node identity |

The `join` command can auto-generate missing ECDSA/BLS validator keys when `--init-keys` is enabled.

For production:

- do not use insecure local key storage
- back up validator keys
- keep validator keys off public RPC nodes
- verify that the registered BLS public key matches the local BLS secret key

---

## 5. Permissionless validator join

The current one-shot join flow is exposed through:

```bash
xgrchain ibft join
```

High-level flow:

1. initialize/load secrets manager
2. ensure ECDSA and BLS keys exist
3. derive validator address from ECDSA key
4. derive BLS public key from BLS secret key
5. optionally run in `--init-only` mode to print address/pubkey without transactions
6. query `VALIDATOR_MIN_SELF_STAKE`
7. query existing `accountStake`
8. stake the missing delta if below requested amount
9. register the BLS public key if not already registered
10. report `joinedAtBlock`, stake and eligibility note

Example:

```bash
xgrchain ibft join \
  --jsonrpc http://127.0.0.1:8545 \
  --data-dir ./data \
  --stake 200000
```

The command's default stake is:

```text
200,000 XGR
```

The command validates that the requested stake is at least the on-chain `VALIDATOR_MIN_SELF_STAKE`.

---

## 6. Validator self-stake and effective support

The `join` command explicitly distinguishes:

| Requirement | Meaning |
|---|---|
| validator self-stake minimum | minimum amount the validator itself must stake |
| effective total support stake | larger support threshold for actual eligibility in the validator selection path |

The current CLI note states:

```text
Join requires >=200k self stake and becomes effective in next epoch.
Eligibility in fetcher still additionally requires >=2M effective total support stake.
```

Therefore:

- staking enough to pass self-stake is necessary
- it may not be sufficient for active validation
- final active eligibility depends on the validator selection/fetcher path

Do not document rootchain WMATIC staking or Supernet staking for XGR.

---

## 7. Increasing stake

A validator can increase stake with:

```bash
xgrchain ibft stake \
  --jsonrpc http://127.0.0.1:8545 \
  --data-dir ./data \
  --amount 1000
```

Behavior:

- `--amount` is interpreted in token units
- default decimals: `18`
- amount is converted to wei
- the command sends payable `stake()`
- the transaction uses a dynamic-fee transaction
- after success it queries `accountStake`

Only positive amounts are accepted by the CLI.

---

## 8. Activation and deactivation

Validator activity is controlled through:

```bash
xgrchain ibft set-active --value true
xgrchain ibft set-active --value false
```

The command calls:

```solidity
setActive(bool active_)
```

When a validator is deactivated, the CLI reads:

- `deactivatedAtBlock`
- `epochSize`
- `accountStake`

It derives:

```text
unstakeAvailableAtBlock = (deactivatedEpoch + 1) * epochSize
```

where:

```text
deactivatedEpoch = deactivatedAtBlock / epochSize
```

Meaning:

- deactivation is not treated as instantly removable from all consensus/reward contexts
- epoch-boundary timing matters
- unstake/withdraw availability is derived from deactivation block and epoch size

---

## 9. Unstake

Full unstake / validator exit uses:

```bash
xgrchain ibft unstake \
  --jsonrpc http://127.0.0.1:8545 \
  --data-dir ./data
```

The command calls:

```solidity
unstake()
```

Precondition from CLI behavior:

```text
You must deactivate before unstake.
```

The command first queries `epochSize` and fails if the staking contract returns `epochSize=0`.

Error handling maps known contract errors to operator-facing messages, including:

| Case | Operator meaning |
|---|---|
| validator must be deactivated first | run `set-active --value false` |
| staking panic 0x12 | likely invalid `epochSize=0` in staking contract state |
| validator not found | wrong key or wrong chain/RPC endpoint |

---

## 10. Withdraw

Partial withdrawal uses:

```bash
xgrchain ibft withdraw \
  --jsonrpc http://127.0.0.1:8545 \
  --data-dir ./data \
  --amount 1000
```

The command calls:

```solidity
withdraw(uint256 amount)
```

The command documentation describes two cases:

| Case | Meaning |
|---|---|
| partial withdraw | keeps validator in staking contract |
| full exit | use `unstake()` instead |

Operator-facing preconditions:

- validator is deactivated
- epoch transition has passed
- remaining stake after withdraw must stay above the contract minimum
- amount must be valid and positive

The current CLI error mapping includes:

| Error condition | Message |
|---|---|
| validator still active | deactivate first and wait if required |
| too early after deactivation | wait until next epoch |
| remaining stake below minimum | remaining stake would fall below `MIN_STAKE` |
| invalid amount | amount must be > 0 and less than current stake |
| validator not found | wrong account or endpoint |

---

## 11. Epoch timing

The PoS logic relies on deterministic epoch boundaries.

At a high level:

```text
epochSize = staking/IBFT epoch size
epoch boundary block = height where height % epochSize == 0
```

Important behavior:

- epoch boundary blocks are tx-free system/finalize blocks
- `FinalizeEpoch` runs only at epoch boundary blocks
- the finalized epoch is the epoch ending at `boundaryBlock - 1`
- `RecordBlockUptime` skips genesis and epoch-boundary blocks
- join/deactivation effects are represented through deterministic epoch-boundary markers

Exact epoch size is read from active chain/staking configuration.

---

## 12. PoA → PoS cutover boundary

At the PoA → PoS transition, a boundary block can be the first PoS block while the epoch being finalized is still fully pre-PoS.

## 13. FeePoolSplit gate

PoS policy logic is fork-gated by `FeePoolSplit`.

Relevant paths:

| Path | Gate |
|---|---|
| uptime accounting | skipped if `FeePoolSplit` is not active |
| epoch finalization | skipped if `FeePoolSplit` is not active |
| fee-pool reward distribution | only meaningful with `FeePoolSplit` active |

This prevents PoS policy logic from affecting pre-PoS / pre-fee-pool execution.

---

## 14. Uptime accounting

Uptime accounting is performed by `RecordBlockUptime`.

The model is proposer-slot based.

Per epoch and validator:

| Counter | Meaning |
|---|---|
| `proposerSlots` | assigned proposer duties |
| `proposerMissed` | missed proposer duties from failed rounds |

Important design choices:

- commit signatures are not used for slashing, because headers may only contain quorum seals
- `RoundNumber` is used to attribute missed proposer slots
- expected proposer mismatch is diagnostic and does not create false slashing
- only provable missed proposer slots are counted
- epoch boundary blocks are skipped

This avoids false slashing from incomplete commit-signature information.

---

## 15. Micro-epoch uptime weights

The implementation has micro-epoch uptime weight accounting.

Conceptually:

- micro-epochs are block ranges inside the larger epoch
- validator proposer duty participation affects current micro-epoch weight fields
- monitoring exposes nominal/effective/inactivity weight fields
- the current endpoint describes micro-epoch values as uptime-accounting weights used in the weighted PoS path

The monitoring endpoint exposes:

| Field | Meaning |
|---|---|
| `microEpochSize` | block-based micro-epoch size |
| `currentMicroEpoch` | current micro-epoch index |
| `currentMicroEpochStartBlock` | start block |
| `currentMicroEpochEndBlock` | end block |
| `microNominalWeight` | nominal micro-epoch weight |
| `microEffectiveWeight` | effective micro-epoch weight |
| `microInactivity` | inactivity counter |

---

## 16. Epoch finalization

`FinalizeEpoch` runs on the tx-free epoch boundary block.

It performs:

1. resolve finalized epoch from `header.Number - 1`
2. load validator membership for that epoch
3. read proposer slot/missed counters
4. derive uptime-based effective weight
5. optionally slash severe underperformance
6. distribute the FeePool proportional to effective weights
7. credit rewards back into staking contract state

### Uptime thresholds

The current policy:

| Uptime in epoch | Behavior |
|---|---|
| `>= 90%` | full effective weight |
| `80% .. <90%` | linearly reduced effective weight |
| `< 80%` | zero reward weight |
| `< 50%` | zero reward weight + slash if slashing enabled |

### Slashing

Current slash default:

```text
slashBpsDefault = 100
```

Meaning:

```text
1%
```

Slashing is skipped when emergency mode is active.

Bootstrap/no-slash floor:

```text
10 wei
```

Stake at or below this floor is liveness-only and not slashed.

---

## 17. Rewards

Fees accumulated in the FeePool are distributed at epoch finalization.

Reward distribution:

```text
validatorShare = feePoolBalance * effectiveWeight / sumEffectiveWeights
```

Rewards are transferred from:

```text
FeePoolAddress -> staking contract
```

Then credited to validator stake state.

Important:

- if FeePool balance is zero, no payout occurs
- if total effective weights are zero, no payout occurs
- reward state is recorded per epoch
- rewards are reflected in staking contract state

---

## 18. Delegation model

The monitoring endpoint exposes delegation-related fields for validators and delegators.

Read fields include:

| Field | Meaning |
|---|---|
| `selfStake` | validator self-stake |
| `delegatedRaw` | raw delegated stake |
| `delegatedActive` | active delegated stake |
| `delegatedActiveCurrent` | current active delegated stake |
| `totalActiveCurrentStake` | self stake + active delegated stake |
| `delegationEnabled` | whether validator delegation pool is enabled |
| `maxDelegatedStake` | delegation cap |
| `commissionBps` | validator commission in basis points |
| `delegators` | delegator entries |

Delegator entries expose:

| Field | Meaning |
|---|---|
| `delegator` | delegator address |
| `amount` | delegated amount |
| `reportedEpochReward` | delegator reward for reported epoch |
| `active` | current active flag |
| `joinedAtBlock` | join block |
| `deactivatedAtBlock` | deactivation block |
| `effectiveAtPoint` | whether effective at current point |

This document does not define delegation write operations unless the specific CLI/contract write path is separately documented and verified.

---

## 19. Monitoring and exactness

The PoS overview endpoint is designed to avoid fake values.

It explicitly states that reward eligibility/slash and epoch reward distribution should not be fabricated if not directly available.

Current monitoring design exposes exactness flags such as:

| Field | Meaning |
|---|---|
| `rewardIneligibleStatusExact` | reward-ineligibility status is exact |
| `slashStatusExact` | slash status is exact |
| `lastRoundStakeExact` | last-round stake distribution is exact |

The old monitoring RFC proposed a future Validator Monitoring Registry. That RFC is not the current source of truth unless implemented. Current documentation should describe the actual endpoint and state reads.

---

## 20. Deprecated beacon endpoint

The legacy endpoint:

```text
eth_getBeaconTimeStatus
```

is deprecated.

Current behavior:

```json
{
  "enabled": false,
  "active": false,
  "healthy": false,
  "deprecated": true,
  "reason": "deprecated"
}
```

Do not document Beacon recovery as active XGR behavior.

---

## 21. Current implementation caveats

The `PoS_3` implementation is still an upgrade branch. Treat these as code-review-sensitive areas:

1. Snapshot/finalization behavior must be checked against the final branch before publication.
2. Any fallback from missing epoch validator snapshot to boundary header validators must be reviewed against the intended safety policy.
3. Delegation write APIs should not be documented until the concrete write paths are verified.
4. Final fork activation height and mainnet rollout status must be added before marking this file as `Mainnet`.
5. Old rootchain staking docs must not be reused.

---

## 22. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Consensus_IBFT.md` | IBFT finality model |
| `XGRCHAIN_Staking_PoS_Endpoint_Reference.md` | PoS JSON-RPC endpoints |
| `XGRCHAIN_Node_Operation.md` | node operation |
| `XGRCHAIN_Genesis_and_Configuration.md` | genesis/config |
| `XRC-GAS_Gas_Price_Behavior.md` | fee and FeePool behavior |
