# XGR Chain — Emergency Recovery & Restart Runbook

**Document ID:** XGRCHAIN-EMERGENCY-RECOVERY  
**Last updated:** 2026-05-03  
**Audience:** Core protocol maintainers, validator operators, release managers, incident coordinators  
**Implementation status:** Operational procedure / release-dependent  
**Source of truth:** `xgrchain`, active release branch, canonical mainnet genesis, validator incident decision record

---

## 1. Scope

This document defines the documentation boundary and operational rules for **emergency recovery / restart scenarios** on XGR Chain.

It covers:

- what an emergency restart is
- why genesis/template changes are dangerous
- required source values
- validator coordination
- recovery decision gates
- recovery artifact rules
- template usage rules
- chain split risks
- what must never be treated as a normal upgrade

This document does **not** define normal network upgrades.

Normal hardfork and release rollouts are documented in:

- `XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md`

---

## 2. Critical warning

An emergency genesis/restart process can create a **different chain**.

If any network-defining value differs between nodes, they may not join the same network or may diverge.

Do not treat an emergency genesis template as a runnable mainnet file.

A template is only a placeholder. It must never be copied directly into production.

---

## 3. Emergency restart vs normal hardfork

| Scenario | Normal hardfork | Emergency restart / recovery |
|---|---|---|
| Purpose | planned protocol change | incident recovery |
| Timing | announced in advance | incident-dependent |
| Activation | configured fork block | coordinated recovery procedure |
| Chain continuity | preserved | must be explicitly verified |
| Operator action | upgrade binary/config | follow incident-specific recovery artifact |
| Risk | chain halt/split if miscoordinated | very high chain split / state inconsistency risk |
| Documentation | public upgrade runbook | restricted operator/core-maintainer runbook |

Emergency restart procedures must not be used for normal feature activation.

---

## 4. Valid reasons for emergency recovery

Emergency recovery may be considered only for severe incidents such as:

- unrecoverable validator-set failure
- consensus halt with no safe normal upgrade path
- corrupted or unusable consensus state
- catastrophic validator key loss affecting quorum
- protocol bug requiring coordinated restart procedure
- chain stuck at a height where normal hardfork activation cannot be reached

It should not be used for:

- ordinary node upgrades
- parameter tuning
- routine validator replacement
- deployment convenience
- testnet resets mistaken for mainnet operations

---

## 5. Source values required

Any emergency recovery artifact must be derived from **verified original chain values**.

Required values include:

| Field | Requirement |
|---|---|
| `genesis.extraData` | must match the intended recovery validator/consensus encoding |
| `genesis.alloc` | must preserve intended balances/state assumptions |
| `params.chainID` | must match intended network signing domain |
| `params.forks` | must match intended fork schedule unless explicitly changed by recovery decision |
| `params.engine.ibft.epochSize` | must match or be explicitly changed and justified |
| `params.engine.ibft.blockTime` | must match or be explicitly changed and justified |
| `params.engine.ibft.type` | must match active/recovery consensus mode |
| `params.engine.ibft.validator_type` | must match expected consensus key type |
| `params.engineRegistryAddress` | must match intended registry configuration where applicable |
| `bootnodes` | must point to intended recovery network peers |

Do not guess these values.

---

## 6. Template usage rule

A JSON file with placeholders such as:

```text
0x<REPLACE_WITH_REAL_EXTRADATA_FROM_RUNNING_CHAIN>
0x<REPLACE_WITH_BLS_PUBKEY_HEX>
/ip4/<REPLACE_IP>/tcp/<REPLACE_PORT>/p2p/<REPLACE_PEER_ID>
```

is not a valid genesis.

A JSON file containing example values such as:

```text
chainID: 2030
epochSize: 200
gasLimit: 0x500000
```

is not XGR mainnet unless those exact values are intentionally approved for the recovery procedure.

Before use, every placeholder and every example value must be replaced or explicitly confirmed.

---

## 7. Emergency validators

Some recovery designs may use an `emergencyValidators` field in the IBFT engine configuration.

If used, every entry must bind:

```text
0x<validatorAddress>:0x<validatorBlsPublicKeyHex>
```

Rules:

- address must be the validator address
- BLS public key must match the validator's consensus key
- every validator entry must be verified independently
- ordering must be deterministic if ordering affects encoding
- the active release must explicitly support the field
- tests must verify the recovered validator set before production use

Do not document `emergencyValidators` as generally available unless the active release code supports it.

---

## 8. Release-dependent verification

Before executing any emergency recovery procedure, verify against the exact active release:

1. Does the binary parse the recovery fields?
2. Does the binary enforce the intended validator set?
3. Does the binary reject malformed BLS keys?
4. Does the binary preserve the intended chain ID?
5. Does the binary preserve the intended fork schedule?
6. Does replay/import behave deterministically?
7. Do all validators derive the same genesis hash / recovery state?
8. Do all validators agree on first recovery block?
9. Do RPC nodes and explorers follow the same chain?
10. Are old nodes unable or instructed not to continue the old chain?

If any answer is uncertain, do not execute recovery.

---

## 9. Recovery artifact requirements

A production emergency recovery must produce a single signed/approved artifact set.

Required artifacts:

| Artifact | Purpose |
|---|---|
| recovery genesis/config file | exact recovery configuration |
| validator list | addresses and BLS public keys |
| bootnode list | recovery peer discovery |
| release binary | recovery-compatible node |
| source commit/tag | auditability |
| checksums | artifact integrity |
| incident decision record | why recovery is required |
| operator instructions | exact step-by-step rollout |
| rollback/abort criteria | when to stop |
| post-recovery verification checklist | chain health validation |

Do not distribute multiple conflicting genesis/config variants.

---

## 10. Pre-recovery checklist

Before recovery:

- freeze normal upgrade changes
- identify incident height and last agreed canonical block
- collect validator logs
- confirm quorum status
- confirm validator key availability
- confirm current genesis/config
- confirm active release version
- generate recovery artifact
- test recovery on isolated environment
- get validator/operator approval
- announce exact procedure
- set maintenance window
- stop affected services if needed
- preserve backups

---

## 11. Validator procedure outline

A final recovery procedure must be incident-specific, but the shape is:

1. Stop validator process.
2. Back up data directory.
3. Back up current binary.
4. Back up current genesis/config.
5. Verify recovery binary checksum.
6. Verify recovery genesis/config checksum.
7. Install recovery binary.
8. Install recovery config only if instructed.
9. Start node with exact command from recovery instructions.
10. Verify peer connectivity.
11. Verify consensus participation.
12. Verify block production.
13. Verify RPC height.
14. Verify explorer/indexer alignment.
15. Report status.

Operators must not improvise local edits during recovery.

---

## 12. Chain split prevention

A recovery is unsafe if validators use different:

- binary
- genesis/config
- fork schedule
- validator list
- BLS keys
- chain ID
- bootnode network
- recovery height
- state assumptions

Prevent split by:

- distributing one artifact package
- publishing checksums
- requiring validator confirmation
- rehearsing on isolated test environment
- disabling stale instructions
- monitoring all validators during restart
- preventing old chain continuation where applicable

---

## 13. State and balance safety

Emergency recovery must preserve state assumptions explicitly.

If the procedure uses a genesis-like restart file, the team must decide whether it represents:

| Model | Meaning |
|---|---|
| restart from original genesis | same initial state only, not full chain recovery |
| restart from exported state | balances/storage exported at incident point |
| validator-set-only recovery | preserve state through node DB, change consensus handling |
| new chain launch | not a recovery; this is a new network |

Never imply that a template with empty `alloc` preserves mainnet state.

---

## 14. Interaction with explorers and RPC nodes

RPC and explorer operators must be included in recovery coordination.

Check:

- block height after recovery
- chain ID
- genesis hash / network identity
- transaction receipt continuity
- event indexing
- XDaLa Engine compatibility
- fee display
- validator/consensus status
- stale indexer data

Explorers must not silently index a new chain as if it were uninterrupted unless continuity is verified.

---

## 15. Abort criteria

Abort the recovery if:

- validators derive different genesis/recovery hashes
- BLS key mapping is inconsistent
- fewer than required validators can participate
- recovery binary differs across validators
- fork schedules differ
- first recovery block differs between nodes
- unexpected state root appears
- old chain continues with competing quorum
- critical RPC/explorer mismatch is detected

Do not continue through ambiguity.

---

## 16. Documentation rules

Emergency recovery docs must be precise.

Allowed:

- incident-specific checklist
- explicit artifact checksums
- exact commands
- exact validator list
- exact bootnodes
- explicit source commit
- explicit recovery assumptions

Not allowed:

- generic placeholder JSON as if runnable
- example chain ID presented as production value
- generic genesis replacement instructions
- bridge/rootchain/Supernet recovery assumptions
- unverified `emergencyValidators` behavior
- mixing normal hardfork docs with emergency recovery

---

## 17. Recommendation for repository placement

Emergency recovery templates should not live as casual public docs next to normal chain documentation.

Recommended placement options:

| File type | Recommended placement |
|---|---|
| public explanation | `XGR/docs/chain/XGRCHAIN_Emergency_Recovery_Runbook.md` |
| runnable recovery artifact | release artifact / incident package only |
| template with placeholders | internal ops repository or clearly named `.example` file |
| old generic template | remove from node repo docs |

If a template remains in the node repository, name it clearly:

```text
genesis-emergency-template.example.json
```

and place a warning at the top-level README or next to the file.

---

## 18. Legacy template decision

The old `docs/genesis-emergency-template.md` and `docs/genesis-emergency-template.json` are not suitable as active public XGR documentation because:

- the Markdown file is too short for the operational risk
- the JSON file contains placeholders and example values
- the JSON file is explicitly not runnable as-is
- wrong usage can create a different chain
- release support for emergency fields must be verified per active branch
- normal operators may confuse it with a standard mainnet config

The safe replacement is this runbook plus incident-specific signed recovery artifacts when needed.

---

## 19. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md` | normal hardfork and release upgrades |
| `XGRCHAIN_Genesis_and_Configuration.md` | canonical genesis/config values |
| `XGRCHAIN_Consensus_IBFT.md` | consensus/finality behavior |
| `XGRCHAIN_Node_Operation.md` | operator runtime procedure |
| `XGRCHAIN_Networking_P2P.md` | peer/bootnode networking |
