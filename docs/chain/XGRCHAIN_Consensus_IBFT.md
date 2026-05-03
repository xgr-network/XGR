# XGR Chain — IBFT Consensus

**Document ID:** XGRCHAIN-IBFT-CONSENSUS  
**Last updated:** 2026-05-03  
**Audience:** Protocol developers, node operators, validators, auditors  
**Implementation status:** Mainnet  
**Source of truth:** `xgrchain/consensus/ibft`

---

## 1. Scope

This document describes the **IBFT consensus layer** used by XGR Chain.

It covers:

- deterministic finality
- proposer and validator roles
- IBFT voting phases
- quorum and fault assumptions
- block proposal and validation flow
- BLS-based commit sealing where applicable
- operator-relevant behavior

This document intentionally does **not** define the upcoming staking-based validator model.

Staking, delegation, weighted voting power, validator activation, validator deactivation, micro/macro epochs, rewards and slashing belong in a separate document:

- `XGRCHAIN_Staking_PoS_Model.md`

This separation keeps the current mainnet IBFT documentation stable while allowing the PoS/staking model to evolve independently.

---

## 2. What IBFT provides

IBFT stands for **Istanbul Byzantine Fault Tolerance**.

It is a PBFT-family consensus protocol designed for validator-based networks. Its main property is deterministic finality:

```text
Once a block is committed by the required IBFT quorum, it is final under the IBFT fault assumptions.
```

Unlike probabilistic consensus systems, applications do not need to wait for many confirmations to reduce reorg probability. Finality is reached at commit.

---

## 3. Consensus roles

### 3.1 Validator

A validator participates in consensus by:

- receiving block proposals
- independently validating proposed blocks
- checking block headers, signatures and state transition validity
- voting in the IBFT prepare and commit phases
- contributing to finality by signing commit messages

Validators do not blindly trust the proposer. Every validator executes and verifies the proposed block before committing it.

### 3.2 Proposer

For each height and round, IBFT selects one validator as proposer.

The proposer:

- selects transactions from the pool
- builds the candidate block
- executes the block locally
- fills consensus-related header fields
- broadcasts the proposal to the validator set

The proposer has more packaging responsibility for that round, but it does not have unilateral authority. The block still needs the validator quorum.

### 3.3 Active validator set

IBFT operates over an active validator set.

In the current mainnet baseline, the validator set is operated as a validator-authorized set. Future staking-based validator selection and weighted voting power are documented separately.

---

## 4. IBFT round flow

Each block height proceeds in rounds.

```text
height h
  round 0
    proposer proposes block
    validators prepare
    validators commit
    block finalizes if quorum is reached
  round 1
    used if round 0 times out or fails
  round 2
    ...
```

High-level flow:

1. **Proposal / Pre-prepare**  
   The proposer broadcasts a candidate block for the current height and round.

2. **Block verification**  
   Validators verify the proposal:
   - parent linkage
   - header validity
   - transaction validity
   - state transition
   - gas accounting
   - consensus metadata

3. **Prepare**  
   Validators signal that they accept the proposed block for the current round.

4. **Commit**  
   Validators sign the block commitment once prepare quorum is reached.

5. **Finalize**  
   The block is inserted once commit quorum is reached.

6. **Round change**  
   If progress stalls, validators move to the next round with a new proposer.

---

## 5. Fault model and quorum

IBFT tolerates Byzantine validators as long as the active validator set satisfies the usual BFT assumptions.

For an unweighted validator set:

```text
n = number of validators
f = floor((n - 1) / 3)
```

The network can tolerate up to `f` Byzantine validators, and block finalization requires a quorum larger than two thirds of the validator set.

Equivalent intuition:

```text
commit power must be at least 2/3 of the validator set, with implementation-specific rounding
```

For current unweighted IBFT operation, this is validator-count based.

Weighted voting power for the PoS/staking model is not defined here. It belongs in:

- `XGRCHAIN_Staking_PoS_Model.md`

---

## 6. Finality

IBFT finality is immediate after commit quorum.

A finalized block should not be reverted unless the IBFT safety assumptions are violated, for example by excessive Byzantine voting power or severe implementation/configuration faults.

For application developers:

- one finalized IBFT block is conceptually final
- additional confirmations may still be used for operational conservatism
- explorers and wallets should treat committed blocks as final under IBFT assumptions

---

## 7. Block proposal and validation

The proposer creates the block, but validators independently verify it.

A validator must reject a proposal if, for example:

- the parent hash is wrong
- the block number is wrong
- the timestamp rules are violated
- the proposer is invalid for the height/round
- transaction execution does not produce the expected state
- gas accounting is invalid
- consensus metadata is malformed
- commit/proposer seals are invalid
- block-specific protocol hooks fail

This is why the proposer does not control the chain alone. It only initiates the round.

---

## 8. Signatures and seals

XGR Chain's current validator setup uses BLS-based consensus sealing.

At a high level:

- validator identity is represented by an address
- validators hold consensus key material
- commit votes are represented compactly
- BLS aggregation allows multiple commit signatures to be represented as one aggregated seal plus participant bitmap

This reduces commit proof size and improves verification/storage efficiency compared with storing many separate signatures.

Implementation details belong to the node code, not to the public high-level consensus specification.

---

## 9. Header metadata

IBFT stores consensus metadata in the block header extra-data area.

Conceptually, this metadata contains:

- validator set information where required
- proposer seal
- committed seal / aggregated commit proof
- parent committed seal where required
- round number

The exact encoding is implementation-specific and should be treated as part of the node consensus implementation.

External integrations should normally use standard JSON-RPC block and receipt APIs rather than parsing IBFT extra data manually.

---

## 10. Epochs and validator-set checkpoints

IBFT implementations commonly use epoch boundaries for validator-set handling, snapshots and consensus housekeeping.

For XGR Chain:

- epoch behavior must be interpreted through the active chain configuration
- staking-specific epoch semantics must not be inferred from generic IBFT behavior
- PoS micro/macro epoch logic is documented separately

Do not mix the following concepts into this IBFT document:

- staking epochs
- delegation epochs
- weighted voting-power epochs
- reward epochs
- slashing windows

Those belong in `XGRCHAIN_Staking_PoS_Model.md`.

---

## 11. Operator notes

Validators should monitor:

- block production
- round changes
- peer connectivity
- signer/key availability
- missed proposals
- commit participation
- node clock drift
- JSON-RPC and p2p health

Persistent round changes usually indicate one of:

- proposer not producing valid blocks
- validator connectivity problems
- validator key/signing problems
- insufficient online quorum
- state divergence / invalid proposal rejection

For IBFT networks, stable low-latency connectivity between validators is operationally important.

---

## 12. Out of scope

This document does not describe:

- staking economics
- permissionless validator join
- validator delegation
- weighted voting power
- reward distribution
- slashing
- PoS monitoring endpoints
- legacy Polygon Bridge / Supernet / PolyBFT behavior
- rootchain / childchain bridge mechanics

---

## 13. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Introduction.md` | High-level XGR Chain overview |
| `XGRCHAIN_Chain_Spec.md` | Chain parameters and protocol configuration |
| `XGRCHAIN_Genesis_and_Configuration.md` | Genesis and configuration details |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Standard Ethereum-compatible RPC |
| `XRC-GAS_Gas_Price_Behavior.md` | XGR gas and fee behavior |
| `XGRCHAIN_Staking_PoS_Model.md` | Future staking / weighted voting-power model |
