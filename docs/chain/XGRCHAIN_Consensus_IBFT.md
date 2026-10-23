# XGR Chain — IBFT Consensus

**Document ID:** XGRCHAIN-IBFT-CONSENSUS  
**Last updated:** 2026-10-03  
**Audience:** Protocol developers, node operators, validator operators, auditors  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Implementation status:** XGRChain mainnet with delegated PoS and stake-weighted consensus active  
**Mainnet configuration:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** XGRChain consensus and validator-finality behavior

---

## 1. Purpose

This document describes the IBFT consensus layer used by XGRChain.

It explains:

- deterministic finality,
- validator and proposer roles,
- IBFT round flow,
- block proposal construction,
- independent validator verification,
- quorum calculation,
- committed seals,
- BLS validator sealing,
- PoA-to-PoS transition,
- epoch and micro-epoch behavior,
- validator-set behavior,
- stake-weighted voting power,
- uptime weighting,
- operator-relevant monitoring and failure modes.

IBFT is the consensus protocol that determines which valid block becomes finalized.

The EVM execution layer determines whether the proposed state transition is valid.

Delegated PoS controls validator participation and voting power after the mainnet PoS transition.

---

## 2. Published mainnet consensus configuration

The published mainnet genesis is:

```text
genesis/mainnet/genesis.json
```

The published IBFT engine configuration contains:

| Field | Value |
| --- | ---: |
| `blockTime` | `2000000000` |
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

The published IBFT type schedule is:

| Phase | Type | Validator type | From | To | Deployment |
| --- | --- | --- | ---: | ---: | ---: |
| Initial phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| Delegated PoS phase | `PoS` | `bls` | `5446500` | n/a | `5446500` |

The delegated PoS activation block is:

```text
5446500
```

The PoS deployment block is:

```text
5446500
```

Validator-count limits:

| Field | Value |
| --- | ---: |
| `minValidatorCount` | `4` |
| `maxValidatorCount` | `25` |

The current `v3.1.1` release continues to use this published consensus configuration.

---

## 3. What IBFT provides

IBFT stands for **Istanbul Byzantine Fault Tolerance**.

It is a validator-based Byzantine fault-tolerant consensus protocol.

Its central property is deterministic finality:

```text
Once a block is committed by the required IBFT quorum,
it is final under the IBFT fault assumptions.
```

XGRChain therefore does not rely on probabilistic finality in the same way as proof-of-work chains.

For applications, explorers and infrastructure:

```text
A committed XGRChain IBFT block is final under the active consensus rules.
```

Applications may still wait for additional blocks for operational reasons, but those confirmations are not required to reduce probabilistic reorganization risk.

---

## 4. Consensus and execution boundary

Consensus and execution are separate but connected.

| Layer | Responsibility |
| --- | --- |
| EVM execution | Determines whether transactions and the resulting state transition are valid |
| IBFT consensus | Determines whether a valid proposed block is finalized |
| TxPool | Supplies candidate transactions |
| P2P networking | Transports consensus messages, blocks and transactions |
| Validator signer | Signs consensus messages and seals |
| Fork manager | Resolves active consensus mode, signer, validator set and hooks |
| PoS validator store | Provides staking-derived validator state |
| Epoch accounting | Maintains deterministic PoS activity and weighting state |

The proposer builds a candidate block.

Validators independently verify it.

Consensus quorum finalizes it.

A proposer cannot finalize a block alone.

---

## 5. High-level block lifecycle

A block follows this lifecycle:

```text
pending height
    ↓
active consensus fork resolved
    ↓
active validator set resolved
    ↓
proposer selected
    ↓
candidate block built
    ↓
proposal broadcast
    ↓
validators independently verify proposal
    ↓
prepare
    ↓
commit
    ↓
quorum verified
    ↓
committed seals written
    ↓
block inserted
    ↓
post-insert hooks
    ↓
txpool reset
    ↓
next height
```

The fundamental rule is:

```text
Consensus can finalize only a block that validators can independently verify.
```

---

## 6. Validator role

An active validator:

- holds validator signing material,
- checks whether its signer belongs to the active validator set,
- participates in the consensus sequence,
- receives block proposals,
- verifies proposals,
- signs IBFT messages,
- contributes prepare and commit votes,
- verifies committed seals,
- verifies committed voting power,
- inserts finalized blocks,
- updates consensus and PoS state,
- resets its txpool against the new canonical head.

A validator does not trust the proposer.

It verifies the candidate block independently.

---

## 7. Proposer role

For each height and round, one validator is selected as proposer.

The proposer:

- reads the current chain head,
- constructs the next header,
- selects transactions,
- executes those transactions locally,
- calculates state and receipt roots,
- calculates gas usage,
- applies active consensus hooks,
- executes deterministic PoS hooks where required,
- constructs IBFT extra data,
- signs the proposal,
- broadcasts it.

The proposer determines candidate transaction ordering.

It does not determine validity or finality unilaterally.

---

## 8. Full-node role

A full node can follow and verify XGRChain without participating in consensus.

A non-validator node:

- synchronizes blocks,
- verifies headers and execution,
- maintains local chain state,
- serves RPC if configured,
- does not contribute prepare/commit votes,
- does not need validator signing material.

Recommended configuration:

```text
--seal=false
```

A node can therefore be fully synchronized and serve valid chain data without being a validator.

---

## 9. Validator activity

The consensus backend determines whether the local signer belongs to the current active validator set.

Conceptually:

```text
isActiveValidator =
    currentValidatorSet.contains(localValidatorAddress)
```

If active:

```text
consensus participation = enabled
block production eligibility = enabled
```

If not active:

```text
consensus participation = disabled
node follows chain as non-validator
```

Staking state and current consensus membership must not be treated as identical concepts.

A validator may be present in staking state while an epoch transition or other consensus rule determines when it becomes part of the effective validator set.

---

## 10. IBFT round flow

Each height starts at round `0`.

```text
height H

round 0
    proposer P0
    proposal
    prepare
    commit
    finality if quorum reached

round 1
    proposer P1
    ...

round 2
    proposer P2
    ...
```

A round change may occur when:

- the proposer is unavailable,
- a proposal is invalid,
- prepare quorum is unavailable,
- commit quorum is unavailable,
- network messages are delayed,
- validators disagree on the validator set,
- execution verification fails,
- signing material is unavailable,
- a validator node is overloaded.

Occasional round changes are part of fault recovery.

Persistent round changes indicate a network or consensus problem.

---

## 11. Proposal construction

When the local validator is proposer, the proposal path conceptually performs:

1. read the latest canonical header,
2. verify expected next height,
3. construct the candidate header,
4. assign parent hash and block number,
5. apply IBFT header fields,
6. calculate gas limit,
7. calculate base fee,
8. apply active consensus hooks,
9. calculate the timestamp,
10. resolve parent committed-seal context,
11. initialize IBFT extra data,
12. begin the EVM state transition,
13. execute candidate transactions,
14. execute pre-commit consensus/PoS hooks,
15. append deterministic system execution where required,
16. commit the state transition,
17. calculate the state root,
18. calculate gas used,
19. build block body and receipts,
20. write proposer seal,
21. encode the proposal,
22. broadcast it.

The block produced by the proposer is still only a proposal until quorum accepts it.

---

## 12. Transaction selection

The proposer selects transactions from its local txpool.

Transactions are evaluated against:

- nonce validity,
- balance,
- transaction signature,
- transaction type,
- intrinsic gas,
- active fork rules,
- block gas availability,
- fee requirements,
- execution validity.

Possible outcomes during proposal construction include:

| Outcome | Meaning |
| --- | --- |
| Include | Transaction is valid for the candidate block |
| Drop | Transaction is invalid |
| Demote / skip | Transaction cannot currently be included but may later become valid |
| Stop | Gas limit, timing or available transaction constraints stop further selection |

Txpool membership itself is not consensus state.

Validators independently re-execute the selected transactions.

---

## 13. Proposal verification

A validator receiving a proposal verifies it before voting for it.

Checks include:

- valid proposal encoding,
- expected block height,
- valid parent,
- valid IBFT header,
- valid proposer seal,
- proposer membership,
- valid parent committed-seal context,
- valid transaction root,
- valid receipt root,
- valid state root,
- correct gas usage,
- deterministic execution,
- active consensus-hook verification,
- correct PoS-derived state where applicable.

A validator must reject a proposal if its local deterministic execution does not reproduce the proposed result.

---

## 14. Header verification

Consensus-specific header checks include:

| Check | Purpose |
| --- | --- |
| IBFT mix hash | Identifies IBFT consensus block |
| Uncle root | Must match IBFT expectations |
| Difficulty | Must follow IBFT block-number rules |
| IBFT extra data | Must decode correctly |
| Proposer seal | Must be valid |
| Proposer membership | Proposer must belong to the active set |
| Committed seals | Must be valid |
| Parent committed seals | Must satisfy active consensus rules |
| Fork hooks | Must accept the header |

Header validity is consensus-critical.

---

## 15. Execution verification

Validators reproduce the proposed EVM state transition.

Important checks include:

- parent hash,
- block sequence,
- gas limit,
- transaction validity,
- transaction root,
- receipt root,
- state root,
- gas used,
- receipt count,
- deterministic consensus hooks.

A proposal with a mismatching state root, receipt root or execution result cannot be finalized by an honest validator quorum.

---

## 16. Consensus fork manager

The IBFT fork manager resolves consensus behavior for a specific block height.

Mainnet:

```text
0 ... 5446499
    PoA

5446500 ...
    PoS
```

For each height it determines relevant components such as:

- IBFT type,
- validator set,
- signer behavior,
- validator store,
- consensus hooks.

All consensus nodes must derive the same effective configuration.

Disagreement about the active fork can cause disagreement about:

- validator membership,
- proposer,
- quorum,
- seal validity,
- state transition,
- block validity.

This is why network-defining configuration must be identical across consensus nodes.

---

## 17. Proposer selection

Proposer selection is deterministic over the active validator set.

Conceptually:

```text
nextProposer =
    validators[(previousOffset + round + 1) mod validatorCount]
```

The exact implementation accounts for previous proposer and current round.

Operational consequences:

- proposer responsibility rotates,
- failed rounds select another proposer,
- every validator must derive the same proposer,
- disagreement about validator ordering is consensus-critical.

---

## 18. Pre-PoS quorum model

Before block `5446500`, voting power is validator-count based.

Each active validator contributes unit voting power:

```text
votingPower = 1
```

The practical count-based quorum corresponds to the IBFT threshold required by the active implementation.

For common validator counts:

| Validators | Required votes |
| ---: | ---: |
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

Staking and delegation do not affect voting power in the pre-PoS phase.

---

## 19. Classic IBFT fault tolerance

For an equal-weight validator set, the familiar IBFT fault-tolerance relation is:

```text
f = floor((n - 1) / 3)
```

where:

```text
n = validators
f = maximum Byzantine validators tolerated by the classic model
```

Examples:

| Validators | f |
| ---: | ---: |
| 4 | 1 |
| 5 | 1 |
| 7 | 2 |
| 10 | 3 |

The safety model assumes Byzantine participation remains within the tolerated bound.

After PoS activation, XGRChain's acceptance logic additionally operates over voting power rather than relying only on validator count.

---

## 20. PoS voting power

From the PoS phase onward, XGRChain uses PoS-aware committed voting power.

The effective power model incorporates:

- active validator membership,
- stake state,
- delegated active stake where applicable,
- deterministic epoch snapshots,
- validator uptime weighting.

At a high level:

```text
effectiveVotingPower =
    effectiveStake
    × effectiveUptimeWeight
    ÷ nominalWeight
```

Mainnet nominal weight:

```text
10000
```

If positive stake and positive weight would mathematically round below one voting-power unit, the implementation preserves a minimum positive power.

A required stake snapshot must not silently disappear or be replaced with arbitrary local data.

Consensus nodes must derive the same voting power.

---

## 21. Weighted quorum

During active weighted PoS operation:

```text
weightedQuorum =
    ceil(2 × totalVotingPower / 3)
```

Integer form:

```text
weightedQuorum =
    (2 × totalVotingPower + 2) / 3
```

A commit is accepted only when:

```text
committedVotingPower >= weightedQuorum
```

The number of signatures alone is therefore insufficient to determine PoS quorum.

Example:

```text
Validator A: power 40
Validator B: power 30
Validator C: power 20
Validator D: power 10

total = 100
quorum = 67
```

Different subsets of three validators can therefore represent different voting power.

---

## 22. First PoS boundary

PoS activates at:

```text
5446500
```

The voting-power calculation uses deterministic parent-state context.

Therefore the first PoS block is a special boundary:

| Height | Current mode | Parent mode |
| ---: | --- | --- |
| `5446499` | PoA | PoA |
| `5446500` | PoS | PoA |
| `5446501` | PoS | PoS |

At the first PoS block the consensus machinery has switched to the PoS path while its deterministic parent context still originates from the final PoA block.

Later PoS blocks operate with PoS parent context.

This transition must remain deterministic for all nodes.

---

## 23. Validator-set evolution

In the PoS phase, validator membership is derived from staking-aware protocol state.

Important concepts include:

- self stake,
- delegated stake,
- active stake,
- active/inactive validator state,
- minimum qualification,
- validator-count limits,
- activation timing,
- deactivation timing,
- epoch boundaries.

Published validator limits are:

```text
minimum = 4
maximum = 25
```

Changes in staking state do not imply arbitrary mid-block validator-set changes.

Validator-set evolution follows deterministic PoS and epoch rules.

---

## 24. Commit seals

Validators sign commit messages after accepting the proposal.

Finalized blocks contain commit evidence.

Conceptually:

```text
proposal
   ↓
validators verify
   ↓
commit signatures
   ↓
committed seal data
   ↓
power/quorum verification
   ↓
final block
```

The node verifies:

- signature validity,
- participant membership,
- structural integrity,
- quorum or voting-power sufficiency.

A block without valid commit evidence must not be accepted as finalized.

---

## 25. Parent committed seals

XGRChain can verify commitment evidence for the parent block in the child-block context where required.

Parent verification depends on the consensus mode and validator state applicable to that parent.

In the PoS path this includes weighted voting-power validation where required.

Parent commitment evidence prevents consensus import paths from accepting a parent whose required commitment cannot be verified.

---

## 26. Consensus BLS

XGRChain uses BLS validator sealing for IBFT consensus.

The published genesis identifies the validator type as:

```text
bls
```

Consensus BLS is used for:

- validator consensus identities,
- block proposal/commit cryptography,
- aggregated consensus evidence,
- compact representation of validator participation.

Consensus BLS is part of XGRChain's validator-finality mechanism.

Applications normally do not need to decode this representation directly.

They should use standard block, transaction and receipt interfaces unless implementing consensus-aware tooling.

---

## 27. Consensus BLS vs interchain BLS

`xgr-node v3.1.1` also contains the native interchain BLS12-381 verification precompile:

```text
0x0000000000000000000000000000000000002040
```

These two BLS uses must not be confused.

| Area | Consensus BLS | Interchain BLS |
| --- | --- | --- |
| Purpose | XGRChain block consensus | Verification of external/cross-chain attestations |
| Security domain | XGRChain validator consensus | Interchain security configuration |
| Determines XGRChain block finality | Yes | No |
| Determines validator-set participation | Yes, together with PoS rules | No |
| Used by IBFT | Yes | No |
| Native verifier precompile `0x2040` | No | Yes |

An interchain validator is not automatically an XGRChain consensus validator.

A successful interchain BLS verification does not grant block-production or consensus authority.

---

## 28. IBFT extra data

IBFT consensus metadata is stored in the block header's extra-data field.

Depending on the active mode, this can represent information including:

- validator information,
- proposer seal,
- committed seal data,
- parent committed-seal data,
- round information.

The exact binary representation is implementation-specific.

External software should not rely on undocumented offsets or hand-written parsing against assumptions from older releases.

---

## 29. Finalized block insertion

Once quorum has been established, the finalized block is inserted into the canonical chain.

Conceptually:

1. collect commit evidence,
2. encode committed seals,
3. verify extra data,
4. verify block execution,
5. write canonical block,
6. update consensus state,
7. run post-insert hooks,
8. reset txpool against the new head.

Consensus data must remain valid after committed seals are inserted into the finalized header.

---

## 30. Synchronization interaction

A validator can learn a finalized block through synchronization while it is still participating locally at that height.

When that occurs:

```text
local sequence at H
      ↓
valid finalized H received
      ↓
local sequence cancelled
      ↓
node advances to H + 1
```

This prevents validators from continuing obsolete consensus work for a height already finalized by the network.

---

## 31. Txpool and sealing

The consensus backend enables block-production behavior only for active validators.

| Node | Sealing |
| --- | --- |
| Active validator | Enabled |
| Non-validator full node | Disabled |
| Public RPC node | Normally disabled |

Recommended non-validator configuration:

```text
--seal=false
```

Txpool contents themselves are not consensus state.

Only transactions included in finalized valid blocks become canonical chain history.

---

## 32. Block time

Published block time:

```text
2000000000 ns
```

Equivalent target:

```text
approximately 2 seconds
```

This is a target interval.

Actual time between finalized blocks can be longer because of:

- round changes,
- proposer failure,
- insufficient quorum,
- network latency,
- validator resource saturation,
- temporary synchronization problems.

Consensus safety takes precedence over maintaining the target block interval.

---

## 33. Macro epochs

Mainnet configuration:

```text
microEpochSize = 25
macroEpochMicroFactor = 40
```

Therefore:

```text
macroEpochSize =
    25 × 40
    = 1000 blocks
```

Macro epochs provide deterministic boundaries for staking and PoS accounting.

A macro epoch must not be confused with a fixed wall-clock duration.

At a two-second target block time:

```text
1000 blocks ≈ 2000 seconds
```

but actual elapsed time depends on real block production.

---

## 34. Micro epochs and uptime

Published mainnet parameters:

| Field | Value |
| --- | ---: |
| `microEpochSize` | `25` |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |

Micro-epoch accounting supports deterministic validator activity weighting.

The parent header is used as deterministic finalized context for uptime accounting.

This avoids deriving consensus state from an uncommitted current proposal.

Uptime therefore influences effective voting power without relying on a local, non-deterministic wall-clock measurement.

---

## 35. Consensus hooks

The node uses consensus hooks around specific stages of block processing.

Examples include:

- header modification,
- header verification,
- block verification,
- pre-commit state processing,
- post-insert processing,
- transaction-writing policy.

Hooks allow XGR-specific PoS behavior to integrate with IBFT while keeping the core round protocol separate.

A hook becomes consensus-critical whenever it affects:

- block validity,
- state transition,
- validator set,
- voting power,
- finality evidence.

---

## 36. PoA vs PoS behavior

| Area | PoA phase | PoS phase |
| --- | --- | --- |
| Block range | `0–5446499` | `5446500+` |
| IBFT type | PoA | PoS |
| Validator cryptography | BLS | BLS |
| Validator-set source | Initial IBFT set | Staking-aware PoS store |
| Voting power | Unit | Stake / uptime weighted |
| Quorum | Count-based | Voting-power based |
| Delegation | No consensus effect | May contribute to effective stake |
| Epoch behavior | Legacy phase | Micro/macro PoS accounting |
| Validator limits | Initial configured set | min `4`, max `25` |

IBFT remains the finality protocol in both phases.

PoS changes validator economics, participation and voting power.

---

## 37. Consensus safety assumptions

Safety requires:

- deterministic EVM execution,
- deterministic PoS state,
- identical consensus configuration,
- correct validator set,
- correct voting-power snapshots,
- correct uptime state,
- valid validator signatures,
- correct quorum calculation,
- correct fork activation,
- sufficient honest voting power.

Potential safety problems include:

- divergent node software,
- inconsistent genesis,
- incorrect fork configuration,
- non-deterministic protocol state,
- validator key compromise,
- excessive Byzantine voting power,
- invalid validator-set derivation.

Consensus-critical changes must therefore be deployed conservatively and verified across validators.

---

## 38. Consensus liveness assumptions

Liveness requires enough active voting power to participate and communicate.

Block production may halt when:

- required voting power is offline,
- network partitions prevent communication,
- proposers repeatedly fail,
- validators reject proposals because of state divergence,
- validator signers are unavailable,
- node resources are exhausted,
- different validators run incompatible consensus behavior.

Stopping finality is preferable to accepting a block without sufficient quorum.

---

## 39. Example: validator outage

In an equal-power four-validator configuration:

```text
A = 25
B = 25
C = 25
D = 25

total = 100
quorum = 67
```

Three validators provide:

```text
75 >= 67
```

and can reach quorum.

Two validators provide:

```text
50 < 67
```

and cannot.

Under unequal stake weighting the calculation must use voting power, not merely validator count.

---

## 40. Operational monitoring

Validator operators should monitor at least:

- canonical block height,
- head hash,
- block interval,
- peer count,
- round changes,
- proposer failures,
- validator process health,
- signer/key availability,
- block-import errors,
- state-root errors,
- receipt-root errors,
- proposer-seal errors,
- committed-seal errors,
- current validator set,
- staking state,
- delegated active stake,
- effective voting power,
- current macro epoch,
- micro-epoch progress,
- uptime-derived weight,
- reward/finalization processing,
- CPU,
- memory,
- network,
- disk capacity.

Key signals:

| Signal | Interpretation |
| --- | --- |
| Increasing block height | Consensus progressing |
| Repeated round changes | Proposer/quorum/network problem |
| Divergent head hashes | Potential sync or consensus incompatibility |
| Signer errors | Validator key or signer problem |
| Low peer count | P2P reliability risk |
| PoS overview mismatch | Validator or staking-state issue |
| Block verification errors | Potential execution or consensus divergence |

---

## 41. Common failure modes

### 41.1 No block production

Check:

```text
eth_blockNumber
net_peerCount
validator process
validator logs
round-change logs
signer availability
current validator set
effective voting power
```

Likely causes include:

- insufficient online voting power,
- proposer failure,
- network partition,
- validator-set disagreement,
- execution divergence,
- signer failure.

---

### 41.2 Repeated round changes

Common causes:

- proposer unavailable,
- proposal rejected,
- prepare quorum unavailable,
- commit quorum unavailable,
- peer latency,
- state divergence,
- validator-set divergence,
- signer failure.

Persistent round changes require investigation.

---

### 41.3 Proposal rejection

Possible causes:

- wrong parent,
- invalid block number,
- invalid proposer seal,
- proposer not in active validator set,
- malformed IBFT extra data,
- invalid commit evidence,
- transaction-root mismatch,
- receipt-root mismatch,
- state-root mismatch,
- gas-used mismatch,
- fork mismatch,
- PoS snapshot mismatch,
- uptime-weight mismatch.

An invalid proposal must not finalize.

---

### 41.4 Synced node does not propose

Possible causes:

- `--seal=false`,
- local signer is not an active validator,
- validator is pending activation,
- validator has been deactivated,
- staking qualification is insufficient,
- signer/key configuration is wrong,
- node is intentionally configured as a full/RPC node.

Synchronization alone does not grant validator authority.

---

### 41.5 Chain stalls

The key question is not simply:

```text
How many validators are online?
```

but, during weighted PoS:

```text
How much eligible voting power is online?
```

If available committed power remains below quorum, finality must halt.

---

### 41.6 Nodes disagree on head

Check:

- binary version,
- release commit,
- genesis/configuration,
- fork schedule,
- head number,
- head hash,
- validator set,
- effective voting power,
- block-import errors,
- consensus logs.

Running different consensus-critical implementations across validators is unsafe.

---

## 42. Local state retention is not consensus

XGRChain's Online State Trie Sweeper is a node-local storage feature.

It does not change:

- canonical block validity,
- state-transition rules,
- consensus voting power,
- validator membership,
- finality.

Different nodes may therefore retain different amounts of historical state while participating in the same consensus.

However, every consensus node must retain all state required to validate the current canonical chain.

Detailed pruning and state-retention operation belongs to:

```text
XGRCHAIN_State_Storage_and_Retention.md
```

and the node-operation runbook.

---

## 43. Operator checklist

For validators:

- run a compatible production node release,
- use the canonical mainnet genesis,
- verify `chainId = 1643`,
- verify correct validator key,
- verify stable network identity,
- verify P2P connectivity,
- verify local signer appears in the active validator set,
- verify expected self/delegated stake,
- verify effective voting power,
- verify epoch status,
- use `--seal=true`,
- keep JSON-RPC/gRPC exposure restricted,
- monitor round changes and signer errors,
- maintain sufficient disk space,
- keep system time synchronized,
- maintain controlled key backups.

For non-validator full/RPC nodes:

- use the same network-defining configuration,
- use `--seal=false`,
- maintain stable peers,
- monitor canonical head,
- protect public RPC,
- do not store validator signing material unnecessarily.

Mainnet consensus values to verify:

| Parameter | Value |
| --- | --- |
| `chainID` | `1643` |
| `blockTime` | `2000000000` ns |
| `microEpochSize` | `25` |
| `macroEpochMicroFactor` | `40` |
| `microEpochInactivityDecayBps` | `9000` |
| `microEpochNominalWeightUnits` | `10000` |
| PoA range | `0–5446499` |
| PoS activation | `5446500` |
| PoS deployment | `5446500` |
| Minimum validators | `4` |
| Maximum validators | `25` |

---

## 44. Summary

| Topic | Current XGRChain mainnet behavior |
| --- | --- |
| Public node baseline | `xgr-node v3.1.1` |
| Consensus protocol | IBFT |
| Finality | Deterministic |
| Consensus validator cryptography | BLS |
| Initial validator phase | PoA |
| PoA range | `0–5446499` |
| PoS activation | `5446500` |
| PoS model | Permissionless delegated PoS |
| PoS validator limits | `4–25` |
| Pre-PoS voting power | Unit voting |
| PoS voting power | Stake and deterministic uptime weighted |
| PoS quorum | `ceil(2 × totalVotingPower / 3)` |
| Target block time | approximately 2 seconds |
| Micro epoch | `25` blocks |
| Macro epoch factor | `40` |
| Macro epoch | `1000` blocks |
| Consensus BLS | IBFT block consensus |
| Interchain BLS | Separate security domain |
| Interchain BLS precompile | `0x2040` |
| Trie pruning | Node-local, non-consensus |
| Non-validator sealing | Disabled |

IBFT protects chain safety by requiring quorum before finality.

If sufficient committed voting power is unavailable, XGRChain must stop finalizing blocks rather than weakening the quorum requirement.
