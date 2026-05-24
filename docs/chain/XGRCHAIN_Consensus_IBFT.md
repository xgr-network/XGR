# XGR Chain — IBFT Consensus

**Document ID:** XGRCHAIN-IBFT-CONSENSUS  
**Last updated:** 2026-05-24  
**Audience:** Protocol developers, node operators, validator operators, auditors  
**Implementation status:** XGR2.0 mainnet baseline with delegated PoS active  
**Source of truth:** `xgr-network/XGR` `main` branch `genesis/mainnet/genesis.json`, public `xgr-network/xgr-node` branch `XGR2.0`, and official XGR Network operator announcements

---

## 1. Purpose

This document describes the IBFT consensus layer used by XGR Chain.

It explains:

- deterministic finality
- validator and proposer roles
- IBFT round flow
- block proposal construction
- independent validator verification
- quorum calculation
- committed seals
- BLS validator sealing
- PoA to delegated PoS transition
- epoch and micro-epoch behavior
- validator-set behavior
- voting power behavior before and after PoS activation
- operator-relevant monitoring and failure modes

IBFT is the consensus protocol that decides which valid block becomes finalized.

The EVM execution layer decides whether the proposed block is valid.

Delegated PoS controls validator participation and voting power after the XGR2.0 transition.

---

## 2. Published mainnet consensus configuration

The published mainnet genesis is:

```text
genesis/mainnet/genesis.json
```

The published IBFT engine configuration contains:

| Field | Value |
|---|---:|
| `blockTime` | `2000000000` |
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

The published IBFT type schedule is:

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

The PoS validator limits are:

| Field | Value |
|---|---:|
| `minValidatorCount` | `4` |
| `maxValidatorCount` | `25` |

---

## 3. What IBFT provides

IBFT stands for **Istanbul Byzantine Fault Tolerance**.

It is a validator-based Byzantine fault-tolerant consensus protocol.

Its core property is deterministic finality:

```text
Once a block is committed by the required IBFT quorum, it is final under the IBFT fault assumptions.
```

This means XGR Chain does not rely on probabilistic finality.

For applications, explorers and infrastructure:

```text
A committed IBFT block is final under normal IBFT safety assumptions.
```

Additional confirmations may still be used by applications for operational conservatism, but they are not required for probabilistic reorg reduction in the same way as proof-of-work-style networks.

---

## 4. Consensus and execution boundary

IBFT and EVM execution are separate but connected.

| Layer | Responsibility |
|---|---|
| EVM execution | Determines whether transactions and state transition are valid |
| IBFT consensus | Determines whether a valid proposed block is finalized |
| TxPool | Supplies candidate transactions to proposers |
| P2P networking | Transports consensus messages, blocks and transactions |
| Validator signer | Signs consensus messages and block seals |
| Fork manager | Selects signer, validator set and hooks for the given height |
| PoS validator store | Provides contract-backed validator state in PoS mode |

The proposer builds a block.

Validators verify the block.

The quorum finalizes the block.

A proposer cannot finalize a block alone.

---

## 5. High-level block lifecycle

A block follows this high-level lifecycle:

```text
pending height
  ↓
active fork/signing mode resolved
  ↓
active validator set resolved
  ↓
proposer selected
  ↓
candidate block built
  ↓
proposal broadcast
  ↓
validators verify proposal
  ↓
prepare phase
  ↓
commit phase
  ↓
committed seals written
  ↓
block inserted
  ↓
post-insert hooks run
  ↓
txpool reset against new head
  ↓
next height
```

The important rule:

```text
Consensus finalizes only blocks that validators can independently verify.
```

---

## 6. Validator role

A validator participates in consensus.

A validator node:

- holds validator signing material
- checks whether its signer is part of the active validator set
- starts consensus sequences only when active
- receives proposals
- validates proposals
- signs IBFT messages
- contributes prepare and commit votes
- verifies committed seals
- inserts finalized blocks
- updates consensus snapshots and hooks
- resets the transaction pool after block insertion

A validator does not blindly trust the proposer.

Every validator verifies the candidate block before accepting it.

---

## 7. Proposer role

For each height and round, IBFT selects one validator as proposer.

The proposer has extra work for that round.

It:

- reads the current head
- builds the next block
- selects transactions from the txpool
- executes transactions locally
- calculates gas used
- calculates state root
- applies active consensus hooks
- prepares IBFT extra data
- writes the proposer seal
- broadcasts the proposal to validators

The proposer does not have unilateral authority.

The block still requires validator quorum.

---

## 8. Full node role

A full node follows and verifies the chain but does not sign consensus messages unless it is also an active validator.

A non-validator full node:

- receives blocks through sync/P2P
- verifies headers and block execution
- maintains local state
- serves RPC if configured
- does not participate in prepare/commit voting
- should not attempt sealing

Recommended non-validator runtime behavior:

```text
--seal=false
```

---

## 9. Validator activity check

The IBFT backend checks whether the node's signer is part of the active validator set.

Conceptually:

```text
isActiveValidator = currentValidators.includes(localSignerAddress)
```

If the node is active:

```text
txpool sealing = true
consensus sequence starts for pending height
```

If the node is not active:

```text
txpool sealing = false
node follows the chain but does not participate in consensus
```

This distinction matters for RPC nodes and full nodes.

A node can be fully synced without being a validator.

---

## 10. IBFT round flow

Each block height can have one or more rounds.

```text
height H
  round 0
    proposer P0 proposes
    validators verify
    prepare
    commit
    finalize if quorum reached

  round 1
    used if round 0 fails or times out
    proposer P1 proposes

  round 2
    used if round 1 fails or times out
```

A round can fail because:

- proposer is offline
- proposal is invalid
- validators cannot reach quorum
- network messages are delayed
- validator set is inconsistent
- state verification fails
- signer/key problems occur
- node is overloaded

Round changes are normal during faults.

Persistent round changes indicate an operational or consensus problem.

---

## 11. Proposal construction

When the node is proposer, it builds a proposal for the pending height.

The proposal construction path performs the following steps:

1. read latest header
2. verify that `latestHeader.Number + 1 == view.Height`
3. create a new header
4. set parent hash
5. set block number
6. set IBFT mix hash
7. calculate gas limit
8. calculate base fee
9. apply consensus hook header modifications
10. calculate timestamp from block-time schedule
11. extract parent committed seals
12. initialize IBFT extra data
13. begin EVM state transition
14. write transactions from the txpool
15. run pre-commit state hook
16. append deterministic epoch-finalization system transaction if the PoS finalization hook produced the matching system receipt
17. commit state transition
18. set state root
19. set gas used
20. build block body and receipts
21. write proposer seal
22. compute provisional block hash
23. return RLP-encoded proposal

Simplified:

```text
parent header
  ↓
candidate header
  ↓
active hooks modify header
  ↓
IBFT extra initialized
  ↓
transactions executed
  ↓
pre-commit hook runs
  ↓
state root / gas used set
  ↓
proposer seal written
  ↓
proposal broadcast
```

---

## 12. Transaction writing by proposer

The proposer writes transactions from the txpool into the candidate block.

The block builder:

- checks whether active hooks allow transactions to be written for the block
- prepares the txpool
- peeks the next transaction
- rejects transactions exceeding block gas limit
- writes transactions into the state transition
- drops invalid transactions
- demotes recoverable transactions
- stops when block gas limit is reached
- stops when the transaction pool is empty
- aligns block production with the configured block-time deadline

Transaction outcomes during proposal construction:

| Outcome | Meaning |
|---|---|
| `success` | Transaction executed and included |
| `fail` | Transaction invalid for inclusion and dropped |
| `skip` | Recoverable issue; transaction demoted |
| stop | Block gas limit reached or no more transactions |

The proposer does not include transactions that fail execution validation.

---

## 13. Proposal verification

When a validator receives a proposal, it validates it before accepting it.

The proposal verification path checks:

- the proposal can be decoded
- the proposal block number is the expected next height
- IBFT header fields are valid
- proposer seal is valid
- proposer belongs to the validator set
- parent committed seals are valid where required
- block body is valid
- transaction root is correct
- receipt root is correct
- state root is correct
- gas used is correct
- execution succeeds deterministically
- consensus hooks accept the block

Simplified:

```text
proposal received
  ↓
decode block
  ↓
verify expected height
  ↓
verify IBFT header
  ↓
execute/verify block
  ↓
verify hooks
  ↓
accept or reject proposal
```

A validator rejects the proposal if local execution does not reproduce the proposed result.

---

## 14. Header verification

IBFT header verification checks consensus-specific header fields.

Important checks include:

| Check | Meaning |
|---|---|
| Mix hash | Must match IBFT Istanbul digest |
| Uncles root | Must be empty uncle hash |
| Difficulty | Must match block number |
| IBFT extra data | Must decode correctly |
| Proposer seal | Must recover a valid proposer |
| Proposer membership | Proposer must be in validator set |
| Parent committed seals | Must be valid where required |
| Hook verification | Active fork/consensus hooks must accept the header |

Header verification is part of both proposal validation and finalized-block validation.

---

## 15. Block execution verification

The blockchain layer verifies that the proposed block body and execution result are correct.

Important checks include:

- parent exists
- parent hash matches
- block number sequence is correct
- gas limit is valid
- transaction root matches
- receipts root matches
- state root matches
- gas used matches
- receipts count matches transactions
- EVM execution result is reproducible

A block with an invalid state root or receipt root must not be accepted.

---

## 16. Fork manager and active consensus mode

The IBFT fork manager resolves the active consensus modules for a given height.

For each height it can provide:

- active signer
- active validator set
- active hooks
- active validator store
- active IBFT type

The published mainnet type schedule means:

```text
height 0..5446499  -> PoA
height >= 5446500  -> PoS
```

The fork manager treats a height as PoS-active when the IBFT fork selected for that height has type `PoS`.

Validator-set consistency is consensus-critical.

If nodes derive different validator sets for the same height, they can disagree about:

- active validators
- proposer
- quorum
- committed seal validity
- block validity

---

## 17. Proposer selection

IBFT uses deterministic proposer selection over the active validator set.

Conceptually:

```text
nextProposer = validators[(offset + round + 1) mod validatorCount]
```

Where:

- `offset` is based on the previous proposer index
- `round` is the current IBFT round
- for genesis / zero previous proposer, the seed is the round number

The effect:

- proposer rotates through the validator set
- a round change changes the proposer
- proposer selection is deterministic
- all validators must derive the same proposer for the same height and round

If validators disagree about the active validator set, they can disagree about the proposer.

That is consensus-critical.

---

## 18. Quorum model before PoS activation

Before PoS activation, quorum is validator-count based.

The backend supports two count-based quorum formulas:

1. legacy quorum
2. optimal quorum

The active formula depends on the configured quorum switch block.

Default behavior uses the optimal formula unless a configuration explicitly sets a different switch boundary.

For practical current operation before PoS activation, count-based quorum is:

```text
ceil(2N / 3)
```

with the classic IBFT special handling used by `OptimalQuorumSize`.

For common validator counts:

| Validators | Count-based quorum |
|---:|---:|
| 1 | 1 |
| 2 | 2 |
| 3 | 3 |
| 4 | 3 |
| 5 | 4 |
| 6 | 4 |
| 7 | 5 |
| 8 | 6 |
| 9 | 6 |
| 10 | 7 |

---

## 19. Fault tolerance

The maximum number of Byzantine validators in the classic IBFT model is calculated as:

```text
f = floor((n - 1) / 3)
```

Where:

```text
n = number of validators
f = maximum tolerated Byzantine validators
```

Examples:

| Validators | Max faulty validators |
|---:|---:|
| 1 | 0 |
| 2 | 0 |
| 3 | 0 |
| 4 | 1 |
| 5 | 1 |
| 6 | 1 |
| 7 | 2 |
| 8 | 2 |
| 9 | 2 |
| 10 | 3 |

The usual IBFT safety assumption is:

```text
faulty validators <= f
```

If more than `f` validators behave Byzantine, safety assumptions no longer hold.

---

## 20. Voting power before PoS activation

Before the PoS transition, voting power is unit-based.

Each validator has voting power:

```text
1
```

Therefore:

```text
validator count = voting power count
```

This means:

- each validator contributes equally
- quorum is validator-count based
- staking amount does not affect pre-PoS IBFT voting power
- delegation does not affect pre-PoS IBFT voting power

---

## 21. Voting power after PoS activation

From the PoS activation height, the node verifies committed power through PoS-aware voting-power logic.

At a high level:

- the active validator set is obtained through the PoS validator store
- stake snapshots are used when stake-weighted mode is active
- uptime weights can affect effective voting power
- total voting power is summed across the active validator set
- collected voting power is summed from committed seal signers
- the collected power must reach the weighted quorum threshold

The node computes voting powers using:

```text
effective stake * uptime-derived effective weight / nominal weight
```

The implementation guarantees a minimum voting power of `1` when stake is positive, weight is positive and integer scaling would otherwise round to zero.

If effective stake data is missing for a stake-weighted validator, the block must not pass weighted power verification.

---

## 22. First PoS boundary behavior

The published PoS activation block is:

```text
5446500
```

At PoS heights, the node performs weighted committed-power verification.

The effective voting-power snapshot uses the parent header.

Because the parent of block `5446500` is block `5446499`, which is still PoA, the first PoS block is a boundary case.

Operational interpretation:

| Height | IBFT mode for height | Parent mode | Voting-power snapshot behavior |
|---:|---|---|---|
| `5446499` | PoA | PoA | Unit voting |
| `5446500` | PoS | PoA | PoS verification path with parent-based unit voting snapshot |
| `5446501` and later | PoS | PoS | Stake-weighted voting snapshot where staking data is available |

This boundary behavior is intentional and code-driven.

---

## 23. Weighted quorum formula

In PoS weighted mode, quorum is based on total voting power.

The weighted quorum threshold is:

```text
weightedQuorum = ceil((2 * totalVotingPower) / 3)
```

The integer-safe implementation is equivalent to:

```text
weightedQuorum = (2 * totalVotingPower + 2) / 3
```

A committed block passes weighted quorum if:

```text
collectedVotingPower >= weightedQuorum
```

Invalid cases:

- total voting power is zero
- collected voting power is zero
- collected voting power is below threshold
- required stake snapshot is missing
- committed seals are structurally invalid
- committed seals belong to non-validators

---

## 24. Commit seals

During commit, validators sign the proposal.

Finalized blocks contain committed seal evidence.

High-level flow:

```text
proposal hash
  ↓
validators sign commit
  ↓
committed seals collected
  ↓
seals written into IBFT extra data
  ↓
block inserted
```

The node verifies committed seals when importing or validating finalized blocks.

In PoA mode, signer-level committed seal verification enforces count-based quorum.

In PoS mode, signer-level verification remains a structural and cryptographic guard, while weighted committed-power verification is the quorum acceptance rule.

A finalized header must contain enough valid committed seal evidence for the configured quorum rule.

---

## 25. Parent committed seals

The node can verify parent committed seals.

Parent committed seals provide evidence for the parent block commitment inside the child header context where required.

Important behavior:

- genesis has no parent committed seals
- non-genesis parent seals are verified where required
- parent committed seal verification depends on the signer and validator set active for the parent
- in PoS mode, parent committed seals require weighted committed-power verification
- missing parent committed seals in PoS weighted mode are invalid where the code requires them

This is consensus-critical because invalid commit evidence must not be accepted.

---

## 26. BLS validator sealing

The published XGR Chain genesis uses BLS validator sealing.

High-level model:

- validator identity has an address
- validator consensus key material signs consensus messages
- committed seals are represented compactly
- BLS mode can aggregate commit signatures
- participant information is encoded with the seal data
- verifiers check that the commit evidence corresponds to the validator set

Integrators should not parse BLS commit internals unless they are building consensus-level tooling.

Normal applications should use standard block and receipt RPC.

---

## 27. IBFT extra data

IBFT stores consensus metadata in the block header extra-data field.

Conceptually, IBFT extra data can contain:

- vanity bytes
- validator set information where required
- proposer seal
- committed seals
- parent committed seals
- round number

The exact encoding is implementation-specific.

External tools should not depend on undocumented offsets.

Use node RPC and explorer/indexer logic designed for the active release.

---

## 28. Finalized block insertion

After consensus reaches commit quorum, the block is inserted.

Insertion path:

1. decode proposal block
2. collect committed seals by signer address
3. write committed seals into header
4. validate extra-data format after seal writing
5. write block to the blockchain
6. update consensus metrics
7. run post-insert hooks
8. reset txpool against the new head

If seal writing corrupts extra data, the block is not written.

This protects the node from storing malformed consensus headers.

---

## 29. Sync interaction

The IBFT backend also runs a syncer.

If the syncer imports a valid block for the height currently being worked on, the local consensus sequence is cancelled.

Conceptually:

```text
local validator building/participating at height H
  ↓
syncer receives valid block H from peers
  ↓
local sequence cancelled
  ↓
node moves to height H+1
```

This avoids wasting work on a height that has already been finalized by the network.

---

## 30. TxPool sealing mode

The consensus backend toggles txpool sealing based on validator activity.

| Node status | TxPool sealing |
|---|---|
| Active validator | Enabled |
| Not active validator | Disabled |

This matters because only active validators should prepare blocks.

Full nodes and RPC nodes should follow the chain without attempting block production.

---

## 31. Block time

The consensus backend uses configured block time for round timeout and block production timing.

The published XGR Chain configuration targets approximately:

```text
2 seconds
```

The proposer uses block time to calculate the next block timestamp and transaction-writing deadline.

If block production is delayed, the timestamp calculation rounds forward to align with the configured block-time schedule.

Operational meaning:

- block time is a target, not a guarantee under faults
- round changes can increase time to finality
- insufficient quorum can halt block production
- overloaded nodes can miss timing windows

---

## 32. Epoch and micro-epoch behavior

XGR2.0 mainnet uses PoS micro/macro epoch configuration.

Published values:

| Field | Value |
|---|---:|
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| Derived macro epoch size | `1000` blocks |

The derived macro epoch size is:

```text
25 * 40 = 1000 blocks
```

The backend computes epoch number conceptually as:

```text
if blockNumber % epochSize == 0:
    epoch = blockNumber / epochSize
else:
    epoch = blockNumber / epochSize + 1
```

The backend checks whether a block is the last block of an epoch as:

```text
blockNumber > 0 && blockNumber % epochSize == 0
```

For XGR2.0 PoS, `epochSize` is derived from:

```text
microEpochSize * macroEpochMicroFactor
```

Do not document the old `epochSize = 500` as the active XGR2.0 mainnet epoch size.

---

## 33. Uptime accounting

In PoS mode, the pre-commit path records deterministic uptime using the parent header.

The parent header is used because it is already sealed and final in the local context.

This avoids non-determinism during block construction.

Uptime-related configuration:

| Field | Value |
|---|---:|
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

Effective voting power can be affected by uptime-derived weights.

This is consensus-relevant in PoS weighted mode.

---

## 34. Consensus hooks

The IBFT implementation uses hooks to extend consensus behavior at defined points.

Hook categories include:

- modify header
- verify header
- verify block
- process header
- pre-commit state
- post-insert block
- whether transactions should be written

Hooks allow fork-specific or release-specific behavior without changing the high-level IBFT flow.

Hook behavior is consensus-critical when it affects block validity or state transition.

---

## 35. PoA vs PoS consensus behavior

| Area | PoA phase | PoS phase |
|---|---|---|
| Mainnet block range | `0` to `5446499` | `5446500` and later |
| IBFT type | `PoA` | `PoS` |
| Validator type | `bls` | `bls` |
| Validator set source | Genesis/static IBFT validator set | PoS validator store |
| Voting power | Unit voting | Effective stake / uptime weighted after parent PoS activation |
| Quorum | Count-based | Weighted committed power |
| Delegation | Not consensus-active | Can contribute through staking rules |
| Parent committed seals | Standard IBFT verification | Structural verification plus weighted committed-power verification |
| Epoch size | Legacy PoA context | `microEpochSize * macroEpochMicroFactor` |

---

## 36. Safety assumptions

IBFT safety depends on:

- deterministic state execution
- correct validator set
- correct quorum calculation
- valid consensus signatures
- consistent chain configuration
- sufficient honest voting power
- correct fork activation
- reliable validator networking
- no excessive Byzantine validators
- no hidden local consensus divergence

Safety can be compromised by:

- too many Byzantine validators
- inconsistent genesis/configuration
- inconsistent fork activation
- inconsistent validator set calculation
- accepting missing or invalid commit evidence
- non-deterministic state transition
- key compromise
- wrong PoS stake snapshot
- wrong uptime weighting state

---

## 37. Liveness assumptions

IBFT liveness depends on enough validators being online and able to communicate.

Liveness can fail if:

- quorum cannot be reached
- proposer is offline and round changes fail
- too many validators are offline
- validators cannot communicate
- validator nodes have clock or resource issues
- validators derive different validator sets
- validators reject each other's proposals
- P2P connectivity is broken
- state execution diverges
- signer/key material is unavailable
- weighted committed power is below threshold

For a 4-validator equal-weight case:

```text
quorum = 3
```

Therefore:

```text
2 offline validators => only 2 votes remain => no quorum
```

The chain should not finalize blocks without quorum.

---

## 38. Operational monitoring

Validator operators should monitor:

- block height
- block time
- round changes
- peer count
- validator process health
- signer/key availability
- proposal success
- commit participation
- block import errors
- state root errors
- receipt root errors
- proposer seal errors
- committed seal errors
- parent committed seal errors
- PoS active status
- active validator set
- validator self-stake
- delegated stake
- effective voting power
- current epoch and micro-epoch
- current pending epoch rewards
- staking contract balance
- txpool pressure
- CPU, memory, disk and network usage

Important metrics and signals:

| Metric / signal | Meaning |
|---|---|
| consensus validators | Current validator count |
| block interval | Time between blocks |
| number of txs | Transactions per produced block |
| base fee | Header base fee |
| peer count | P2P health |
| round-change logs | Consensus progress problems |
| block import errors | Execution or consensus mismatch |
| signer errors | Validator key problem |
| PoS overview RPC | Validator/stake/epoch visibility |

---

## 39. Common failure modes

### 39.1 No block production

Likely causes:

- not enough online validators
- proposer offline
- quorum unavailable
- weighted voting power unavailable
- validator networking broken
- validators disagree on validator set
- validators reject proposals
- signer unavailable
- node resource exhaustion
- invalid fork/configuration mismatch

Immediate checks:

```text
eth_blockNumber
net_peerCount
validator logs
round-change logs
signer logs
peer connectivity
PoS overview RPC
```

---

### 39.2 Repeated round changes

Likely causes:

- proposer not producing blocks
- invalid proposal
- prepare quorum not reached
- commit quorum not reached
- peer latency
- validator offline
- validator key unavailable
- validators disagree on state or validator set
- insufficient weighted committed power

A few round changes can happen during transient faults.

Persistent round changes require operator investigation.

---

### 39.3 Proposal rejected

Likely causes:

- wrong block number
- wrong parent hash
- invalid proposer seal
- proposer not in validator set
- invalid IBFT extra data
- invalid committed seal data
- invalid parent committed seal data
- invalid transaction root
- invalid receipt root
- invalid state root
- gas used mismatch
- hook verification failure
- fork mismatch
- PoS stake snapshot mismatch
- uptime weighting mismatch

A proposal rejected by honest validators should not finalize.

---

### 39.4 Node follows chain but does not propose

Likely causes:

- node is not in active validator set
- validator key address differs from configured validator address
- sealing disabled
- wrong data directory / wrong secrets
- validator deactivated in PoS mode
- validator stake no longer qualifies
- node is running as full/RPC node

Check whether the local signer address is in the current validator set.

---

### 39.5 Chain stalls after validator loss

Likely cause:

```text
online validator count or online voting power below quorum
```

Example with 4 equal-weight validators:

```text
required quorum = 3
```

If two validators are offline:

```text
available = 2
required = 3
result = no finality
```

This is expected safety behavior.

The chain must not finalize without quorum.

---

### 39.6 Different nodes show different heads

Likely causes:

- fork/config mismatch
- validator set mismatch
- state execution mismatch
- block import failure
- stale RPC node
- peer isolation
- node failed to sync
- post-upgrade incompatibility
- different genesis file
- wrong PoS activation settings
- wrong micro/macro epoch settings

Checks:

- compare head number
- compare head hash
- compare node version
- compare genesis/config
- compare fork schedule
- inspect block import errors
- inspect consensus logs
- inspect PoS overview RPC

---

## 40. Operator checklist

For validator nodes:

- correct binary version
- correct published chain configuration
- correct genesis file
- correct validator key
- stable network key
- sufficient peer connectivity
- signer address in validator set
- validator stake/delegation state valid after PoS activation
- JSON-RPC not publicly exposed unless intended
- gRPC internal only
- debug internal only
- monitoring active
- logs monitored
- disk space sufficient
- system clock stable
- host resources sufficient

For non-validator full/RPC nodes:

- correct binary version
- correct published chain configuration
- sealing disabled
- no validator key material required
- stable peer connectivity
- public RPC protected by gateway/rate limits
- node follows current head
- no consensus signing expected

Configuration values to verify:

| Field | Required value |
|---|---|
| `params.chainID` | `1643` |
| `params.engine.ibft.blockTime` | `2000000000` |
| `params.engine.ibft.microEpochSize` | `25` |
| `params.engine.ibft.macroEpochMicroFactor` | `40` |
| `params.engine.ibft.microEpochInactivityDecayBps` | `9000` |
| `params.engine.ibft.microEpochNominalWeightUnits` | `10000` |
| PoA range | `0` to `5446499` |
| PoS `from` | `5446500` |
| PoS `deployment` | `5446500` |
| PoS min validators | `4` |
| PoS max validators | `25` |

---

## 41. Summary

| Topic | XGR2.0 mainnet behavior |
|---|---|
| Consensus protocol | IBFT |
| Finality | Deterministic after commit quorum |
| Validator sealing | BLS |
| Pre-cutover validator model | PoA/static IBFT validator set |
| PoA range | `0` to `5446499` |
| PoS activation | `5446500` |
| PoS deployment | `5446500` |
| PoS validator model | Delegated PoS |
| Validator limits | min `4`, max `25` |
| Pre-PoS voting power | Unit power per validator |
| PoS voting power | Effective stake and uptime-weighted power |
| Weighted quorum | `ceil(2 * totalVotingPower / 3)` |
| Block time target | Approximately 2 seconds |
| Micro epoch size | `25` blocks |
| Macro epoch factor | `40` |
| Derived macro epoch size | `1000` blocks |
| Full/RPC node sealing | Should be disabled |

IBFT protects safety by requiring quorum.

If quorum or weighted committed power is unavailable, finality must stop rather than accepting invalid or insufficiently supported blocks.
