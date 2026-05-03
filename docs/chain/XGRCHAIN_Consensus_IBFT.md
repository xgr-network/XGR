# XGR Chain — IBFT Consensus

**Document ID:** XGRCHAIN-IBFT-CONSENSUS  
**Last updated:** 2026-05-03  
**Audience:** Protocol developers, node operators, validator operators, auditors  
**Implementation status:** Current public baseline for unweighted IBFT; stake-weighted voting is development / preview until activated by an official release  
**Source of truth:** Public `xgr-network/xgr-node` releases, published XGR Chain configuration, staking-enabled release artifacts where applicable, and official XGR Network operator announcements

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
- commit seals
- BLS validator sealing
- epoch behavior
- validator-set behavior
- public baseline voting power
- development / preview stake-weighted voting behavior
- operator-relevant monitoring and failure modes

IBFT is the consensus protocol that decides which valid block becomes finalized.

The EVM execution layer decides whether the proposed block is valid.

---

## 2. What IBFT provides

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

## 3. Consensus and execution boundary

IBFT and EVM execution are separate but connected.

| Layer | Responsibility |
|---|---|
| EVM execution | Determines whether transactions and state transition are valid |
| IBFT consensus | Determines whether a valid proposed block is finalized |
| TxPool | Supplies candidate transactions to proposers |
| P2P networking | Transports consensus messages, blocks and transactions |
| Validator signer | Signs consensus messages and block seals |

The proposer builds a block.

Validators verify the block.

The quorum finalizes the block.

A proposer cannot finalize a block alone.

---

## 4. High-level block lifecycle

A block follows this high-level lifecycle:

```text
pending height
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
txpool reset against new head
  ↓
next height
```

The important rule:

```text
Consensus finalizes only blocks that validators can independently verify.
```

---

## 5. Validator role

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

## 6. Proposer role

For each height and round, IBFT selects one validator as proposer.

The proposer has extra work for that round.

It:

- reads the current head
- builds the next block
- selects transactions from the txpool
- executes transactions locally
- calculates gas used
- calculates state root
- prepares IBFT extra data
- writes the proposer seal
- broadcasts the proposal to validators

The proposer does not have unilateral authority.

The block still requires validator quorum.

---

## 7. Full node role

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

## 8. Validator activity check

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

## 9. IBFT round flow

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

## 10. Proposal construction

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
16. commit state transition
17. set state root
18. set gas used
19. build block body and receipts
20. write proposer seal
21. compute provisional block hash
22. return RLP-encoded proposal

Simplified:

```text
parent header
  ↓
candidate header
  ↓
IBFT extra initialized
  ↓
transactions executed
  ↓
state root / gas used set
  ↓
proposer seal written
  ↓
proposal broadcast
```

---

## 11. Transaction writing by proposer

The proposer writes transactions from the txpool into the candidate block.

The block builder:

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

## 12. Proposal verification

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

## 13. Header verification

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

## 14. Block execution verification

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

## 15. Proposer selection

The public baseline uses deterministic proposer selection over the active validator set.

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

## 16. Quorum model

IBFT needs a quorum to finalize a block.

The current public baseline supports two quorum formulas:

1. legacy quorum
2. optimal quorum

The active formula depends on the configured quorum switch block.

Default behavior uses the optimal formula unless a configuration explicitly sets a different switch boundary.

---

## 17. Fault tolerance

The maximum number of faulty validators is calculated as:

```text
f = floor((n - 1) / 3)
```

Where:

```text
n = number of validators
f = maximum tolerated faulty validators
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

## 18. Legacy quorum formula

Legacy quorum is:

```text
legacyQuorum = 2f + 1
```

Where:

```text
f = floor((n - 1) / 3)
```

Examples:

| Validators | f | Legacy quorum |
|---:|---:|---:|
| 1 | 0 | 1 |
| 2 | 0 | 1 |
| 3 | 0 | 1 |
| 4 | 1 | 3 |
| 5 | 1 | 3 |
| 6 | 1 | 3 |
| 7 | 2 | 5 |

Legacy quorum is retained for compatibility where explicitly configured.

It should not be assumed as the preferred current rule unless the active configuration selects it.

---

## 19. Optimal quorum formula

Optimal quorum is:

```text
optimalQuorum = ceil(2N / 3)
```

Special case:

```text
If f = 0, the entire validator set is required.
```

Examples:

| Validators | Optimal quorum |
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

For the current public baseline, this is the practical default unless the network configuration explicitly selects legacy behavior before a switch block.

Operationally:

```text
Commit evidence must reach the configured quorum threshold.
```

For unweighted baseline IBFT, quorum is validator-count based.

---

## 20. Quorum intuition

For common validator counts:

```text
4 validators  -> 3 commits required
5 validators  -> 4 commits required
6 validators  -> 4 commits required
7 validators  -> 5 commits required
```

This is why a 4-validator IBFT network can tolerate one faulty/offline validator but not two.

With 4 validators:

```text
required quorum = 3
```

If two validators are offline:

```text
only 2 validators remain
2 < 3
no quorum
block finalization stalls
```

This is expected IBFT behavior.

It is not a txpool problem.

It is not a proposer problem alone.

It is insufficient quorum.

---

## 21. Voting power in current public baseline

In the current public baseline, voting power is unweighted.

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
- staking amount does not affect IBFT voting power in the public baseline
- delegation does not affect IBFT voting power in the public baseline

Stake-weighted voting belongs to the staking-enabled development / preview track until officially activated.

---

## 22. Stake-weighted voting development / preview

A staking-enabled development track introduces weighted voting power.

In that mode:

- voting power is derived from effective staking state
- validator power can differ between validators
- committed seal verification remains cryptographic
- quorum acceptance depends on collected voting power
- the collected power must reach the weighted quorum threshold
- parent committed seals also require weighted verification
- missing effective stake data is consensus-critical
- validator set transitions are epoch-boundary sensitive

This behavior is not part of the current public baseline unless activated by an official staking-enabled release and published configuration.

Public-facing description:

```text
Unweighted IBFT is the current public baseline.
Stake-weighted IBFT voting is development / preview until official activation.
```

---

## 23. Commit seals

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

A finalized header must contain enough valid committed seal evidence for the configured quorum rule.

---

## 24. BLS validator sealing

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

## 25. IBFT extra data

IBFT stores consensus metadata in the block header extra-data field.

Conceptually, IBFT extra data can contain:

- vanity bytes
- validator set information where required
- proposer seal
- committed seals
- parent committed seals
- round number

The exact encoding is node-implementation specific.

External tools should not depend on undocumented offsets.

Use node RPC and explorer/indexer logic designed for the active release.

---

## 26. Parent committed seals

The node can verify parent committed seals.

Parent committed seals provide evidence for the parent block commitment inside the child header context where required.

Important behavior:

- genesis has no parent committed seals
- non-genesis parent seals are verified where required
- parent committed seal verification depends on the signer and validator set active for the parent
- in weighted development mode, parent committed seals also require weighted power verification

This is consensus-critical because invalid commit evidence must not be accepted.

---

## 27. Finalized block insertion

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

## 28. Sync interaction

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

## 29. TxPool sealing mode

The consensus backend toggles txpool sealing based on validator activity.

| Node status | TxPool sealing |
|---|---|
| Active validator | Enabled |
| Not active validator | Disabled |

This matters because only active validators should prepare blocks.

Full nodes and RPC nodes should follow the chain without attempting block production.

---

## 30. Block time

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

## 31. Epoch behavior

IBFT uses an epoch size from chain configuration.

Published XGR Chain configuration currently uses:

```text
epochSize = 500
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

IBFT epochs are consensus housekeeping / validator-set boundary concepts.

Staking-specific micro/macro epochs are separate development / preview concepts unless officially activated.

---

## 32. Validator set source

The validator set is retrieved through the active fork manager for a given height.

The consensus backend updates the active modules for the pending height:

- signer
- validator set
- hooks

Conceptually:

```text
pendingHeight = currentHead + 1

signer     = forkManager.getSigner(pendingHeight)
validators = forkManager.getValidators(pendingHeight)
hooks      = forkManager.getHooks(pendingHeight)
```

Validator-set consistency is consensus-critical.

If nodes derive different validator sets for the same height, they can disagree about:

- active validators
- proposer
- quorum
- committed seal validity
- block validity

---

## 33. Consensus hooks

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

## 34. Public baseline vs development behavior

| Area | Current public baseline | Development / preview staking mode |
|---|---|---|
| Voting power | Equal power, `1` per validator | Effective stake-derived power |
| Quorum | Validator-count quorum | Weighted quorum |
| Validator set | Configured IBFT validator set | Staking-aware validator set |
| Delegation | Not part of public baseline consensus | Can affect effective stake where activated |
| FeePool split | Not part of public baseline consensus | Can activate with PoS fork where configured |
| Micro-epoch uptime | Not part of public baseline consensus | Can affect effective weights where activated |
| Commit seal verification | Count-based quorum | Cryptographic seal check plus weighted power check |
| Parent committed seals | Standard IBFT verification | Weighted parent committed power verification where active |

Development / preview behavior becomes operational only through an official release and published configuration.

---

## 35. Safety assumptions

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
- invalid fallback behavior
- accepting missing or invalid commit evidence
- non-deterministic state transition
- key compromise

---

## 36. Liveness assumptions

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

For a 4-validator unweighted baseline network:

```text
quorum = 3
```

Therefore:

```text
2 offline validators => only 2 votes remain => no quorum
```

The chain should not finalize blocks without quorum.

---

## 37. Operational monitoring

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
- txpool pressure
- CPU, memory, disk and network usage

Important metrics themes:

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

---

## 38. Common failure modes

### 38.1 No block production

Likely causes:

- not enough online validators
- proposer offline
- quorum unavailable
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
```

---

### 38.2 Repeated round changes

Likely causes:

- proposer not producing blocks
- invalid proposal
- prepare quorum not reached
- commit quorum not reached
- peer latency
- validator offline
- validator key unavailable
- validators disagree on state or validator set

A few round changes can happen during transient faults.

Persistent round changes require operator investigation.

---

### 38.3 Proposal rejected

Likely causes:

- wrong block number
- wrong parent hash
- invalid proposer seal
- proposer not in validator set
- invalid IBFT extra data
- invalid committed seal data
- invalid transaction root
- invalid receipt root
- invalid state root
- gas used mismatch
- hook verification failure
- fork mismatch

A proposal rejected by honest validators should not finalize.

---

### 38.4 Node follows chain but does not propose

Likely causes:

- node is not in active validator set
- validator key address differs from configured validator address
- sealing disabled
- wrong data directory / wrong secrets
- validator deactivated in staking-enabled mode
- node is running as full/RPC node

Check whether the local signer address is in the current validator set.

---

### 38.5 Chain stalls after validator loss

Likely cause:

```text
online validator count or online voting power below quorum
```

Example with 4 unweighted validators:

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

### 38.6 Different nodes show different heads

Likely causes:

- fork/config mismatch
- validator set mismatch
- state execution mismatch
- block import failure
- stale RPC node
- peer isolation
- node failed to sync
- post-upgrade incompatibility

Checks:

- compare head number
- compare head hash
- compare node version
- compare genesis/config
- compare fork schedule
- inspect block import errors
- inspect consensus logs

---

## 39. Operator checklist

For validator nodes:

- correct binary version
- correct published chain configuration
- correct validator key
- stable network key
- sufficient peer connectivity
- signer address in validator set
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

---

## 40. Summary

| Topic | Current public baseline |
|---|---|
| Consensus protocol | IBFT |
| Finality | Deterministic after commit quorum |
| Validator voting power | `1` per validator |
| Quorum default | `ceil(2N/3)` with full-set requirement for `N <= 3` |
| Fault tolerance | `floor((N - 1) / 3)` Byzantine validators |
| Proposer selection | Deterministic rotation based on previous proposer and round |
| Validator sealing | BLS-based in published XGR Chain configuration |
| Header consensus data | IBFT extra data |
| Block time target | Approximately 2 seconds in published configuration |
| Epoch size | `500` blocks in published configuration |
| Full/RPC node sealing | Should be disabled |
| Stake-weighted voting | Development / preview until official activation |

IBFT protects safety by requiring quorum.

If quorum is unavailable, finality must stop rather than accepting invalid or insufficiently supported blocks.
