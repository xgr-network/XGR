# XGR Chain — Network Upgrade & Hardfork Process

**Document ID:** XGRCHAIN-NETWORK-UPGRADE  
**Last updated:** 2026-05-24  
**Audience:** Node operators, validators, release managers, protocol developers, auditors  
**Implementation status:** XGR2.0 mainnet baseline with delegated PoS active  
**Source of truth:** `xgr-network/XGR` `main` branch `genesis/mainnet/genesis.json`, public `xgr-network/xgr-node` branch `XGR2.0`, and official XGR Network operator announcements

---

## 1. Scope

This document describes the process for XGR Chain network upgrades and hardfork activation.

It covers:

- what a network upgrade is
- what a hardfork is
- how fork activation works
- how published configuration affects activation
- how releases should be rolled out
- validator and operator coordination
- activation block selection
- chain split risk
- rollback boundaries
- monitoring during activation
- post-upgrade validation
- configuration replacement rules
- staking / PoS upgrade handling
- fee-model upgrade handling
- RPC-impacting upgrade handling

This document is written for production network coordination.

It is not a local development guide.

It does not define XDaLa process behavior, XRC standards, UI behavior or application-layer workflows.

---

## 2. Current XGR2.0 mainnet upgrade state

XGR2.0 has already activated delegated PoS on mainnet.

The published mainnet genesis defines:

| Phase | Type | Validator type | From | To | Deployment |
|---|---|---|---:|---:|---:|
| Pre-PoS phase | `PoA` | `bls` | `0` | `5446499` | n/a |
| XGR2.0 PoS phase | `PoS` | `bls` | `5446500` | n/a | `5446500` |

The active PoS cutover block is:

```text
5446500
```

The active PoS deployment block is:

```text
5446500
```

The active PoS validator limits are:

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

The active chain ID is:

```text
1643
```

The current upgrade baseline is therefore:

```text
XGR2.0 delegated PoS mainnet active
```

---

## 3. Network upgrade categories

Not every upgrade has the same risk.

| Upgrade type | Description | Coordination level |
|---|---|---|
| Operational upgrade | Logging, metrics, CLI usability, non-consensus bug fixes | Low if execution and consensus behavior are unchanged |
| RPC upgrade | Adds or changes non-consensus read behavior | Low to medium depending on public clients |
| Performance upgrade | Improves execution, networking, storage or txpool performance without changing results | Medium if not carefully tested |
| Configuration upgrade | Changes runtime configuration or published chain configuration | Medium to high depending on field |
| Hardfork upgrade | Changes block validity, transaction validity, state transition or consensus behavior | High |
| Validator-set upgrade | Changes validator participation, voting power or epoch behavior | High |
| Fee-model upgrade | Changes gas, base fee, minimum fee, fee pool or reward behavior | High |
| Staking / PoS upgrade | Changes staking, delegation, validator eligibility or voting power behavior | High |

The upgrade process must match the risk level.

A binary-only upgrade without consensus changes is not the same as a hardfork.

A hardfork requires coordinated release and activation.

---

## 4. Hardfork definition

A hardfork is a protocol change that makes upgraded nodes follow different block-validity, transaction-validity or state-transition rules from non-upgraded nodes after a defined activation point.

A hardfork can change:

- EVM execution rules
- transaction validation rules
- gas accounting
- fee accounting
- header validation
- receipt generation
- log generation
- state transition behavior
- validator-set behavior
- consensus voting rules
- epoch transition logic
- staking activation logic
- protocol-level configured addresses
- fork-specific parameters

Any change that can make two nodes disagree about whether a block is valid is hardfork-level.

---

## 5. Fork activation model

XGR Chain uses a block-height-based fork activation model.

Forks are configured under:

```text
params.forks
```

Each fork entry defines an activation block.

The code-level activation rule is:

```text
fork is active when currentBlock >= fork.block
```

Example configuration shape:

```json
{
  "params": {
    "forks": {
      "EIP2930": {
        "block": 1208500
      }
    }
  }
}
```

Fork activation must be deterministic.

All nodes participating in the same network must use the same effective fork schedule.

---

## 6. Published mainnet fork configuration

The published mainnet configuration activates the following fork features from block `0`:

| Fork / feature | Activation block |
|---|---:|
| `homestead` | `0` |
| `byzantium` | `0` |
| `constantinople` | `0` |
| `petersburg` | `0` |
| `istanbul` | `0` |
| `london` | `0` |
| `londonfix` | `0` |
| `EIP150` | `0` |
| `EIP155` | `0` |
| `EIP158` | `0` |
| `quorumcalcalignment` | `0` |
| `txHashWithType` | `0` |

The published mainnet configuration activates the following fork features from block `1208500`:

| Fork / feature | Activation block |
|---|---:|
| `EIP2930` | `1208500` |
| `EIP2929` | `1208500` |
| `EIP3860` | `1208500` |
| `EIP3651` | `1208500` |

Nodes must use the published fork schedule for the target network.

A different fork schedule means different execution rules.

---

## 7. PoS activation as network upgrade

The XGR2.0 PoS activation is encoded in the IBFT engine configuration, not as a normal EVM fork entry in `params.forks`.

The published mainnet IBFT schedule is:

```text
PoA: from 0 to 5446499
PoS: from 5446500
```

Operational meaning:

| Block range | Consensus participation model |
|---:|---|
| `0` to `5446499` | Pre-PoS IBFT validator set |
| `5446500` and later | Delegated PoS validator participation with IBFT finality |

The activation point is deterministic and block-height based.

All validators and infrastructure nodes must run a compatible XGR2.0 node release for the PoS phase.

---

## 8. FeePoolSplit alignment with PoS activation

The XGR2.0 node contains explicit alignment logic for `feePoolSplit`.

The rule is:

```text
feePoolSplit must activate at the first PoS IBFT fork block.
```

Behavior:

- the node scans the IBFT fork schedule
- it finds the first `PoS` entry
- if `feePoolSplit` already exists and its block differs from the first PoS block, initialization fails
- if `feePoolSplit` is missing and a PoS fork exists, the node sets `feePoolSplit` internally to the first PoS block

For XGR2.0 mainnet:

```text
first PoS block = 5446500
feePoolSplit effective block = 5446500
```

Operators must not manually add or edit `feePoolSplit` to a different block.

A mismatch is consensus-relevant because fee and reward behavior can affect state transition.

---

## 9. Supported fork names in XGR2.0

The XGR2.0 node supports the fork names used by the published mainnet configuration and internal fee-pool alignment.

Supported fork constants include:

| Fork / feature |
|---|
| `homestead` |
| `byzantium` |
| `constantinople` |
| `petersburg` |
| `istanbul` |
| `london` |
| `londonfix` |
| `EIP150` |
| `EIP155` |
| `EIP158` |
| `quorumcalcalignment` |
| `txHashWithType` |
| `EIP2930` |
| `EIP2929` |
| `EIP3860` |
| `EIP3651` |
| `feePoolSplit` |

A fork name being supported by the node binary does not by itself define a public network activation block.

Network activation depends on the published chain configuration and deterministic node alignment logic.

---

## 10. What requires hardfork coordination

Treat a change as hardfork-level if it affects any of the following:

| Area | Examples |
|---|---|
| Transaction validity | New transaction type, fee validation, chain ID rules, nonce handling |
| EVM execution | Opcode behavior, gas schedule, precompile behavior |
| State transition | Balance changes, storage changes, log/receipt differences |
| Block validity | Header fields, base fee, gas limit, extra data, seal validation |
| Consensus behavior | Proposal validation, commit rules, round logic, quorum behavior |
| Validator set | Join/leave behavior, activation/deactivation, voting power |
| Staking behavior | Delegation, self-stake, epoch effectiveness, reward ineligibility, rewards |
| Fee accounting | Base fee, minimum fee, fee pool, rewards |
| Fork schedule | Activation block, fork-specific parameters |
| Protocol registry behavior | Configured protocol addresses or registry-dependent behavior |
| RPC-generated protocol actions | Any RPC-generated transaction or action that affects consensus state |

If non-upgraded and upgraded nodes can disagree about block validity, the change requires coordinated activation.

---

## 11. What usually does not require hardfork coordination

Some changes may not require a hardfork if they do not affect consensus, execution results or network-wide deterministic behavior.

Examples:

| Change | Typical status |
|---|---|
| Documentation update | No hardfork |
| Logging improvement | No hardfork |
| Metrics improvement | No hardfork |
| CLI help text | No hardfork |
| Non-consensus read-only RPC endpoint | Usually no hardfork |
| Dashboard-only formatting | No hardfork |
| Internal refactor with identical behavior | No hardfork if verified |
| Performance optimization with identical output | No hardfork if verified |
| Additional monitoring endpoint | Usually no hardfork |

These changes still need testing.

A non-consensus change can become dangerous if it accidentally changes state transition, block validation or transaction validation.

---

## 12. Published configuration versus runtime flags

The published chain configuration defines network behavior.

Runtime flags define how a local node process runs.

Examples of published configuration fields:

| Field group | Examples |
|---|---|
| Chain identity | `name`, `params.chainID` |
| Fork schedule | `params.forks.*` |
| Consensus config | `params.engine.ibft.*` |
| Genesis state | `genesis.alloc` |
| Validator genesis data | `genesis.extraData` |
| Protocol addresses | `engineRegistryAddress`, `bootstrapEngineEOA` |
| Fee-related config | `blockGasTarget`, `burnContract`, `burnContractDestinationAddress` |
| Bootnodes | `bootnodes` |

Examples of runtime flags:

| Runtime flag | Meaning |
|---|---|
| `--chain` | Path to chain configuration file |
| `--data-dir` | Local node database path |
| `--libp2p` | Local P2P bind address |
| `--jsonrpc` | Local JSON-RPC bind address |
| `--grpc-address` | Local gRPC bind address |
| `--seal` | Whether the node attempts block sealing |
| `--max-peers` | Local peer limit |
| `--log-level` | Local logging verbosity |

Runtime flags must not be used to create local, node-specific consensus behavior.

Consensus-critical changes must be deterministic across the network.

---

## 13. Configuration update model

There are two different cases.

### 13.1 Activation already published

If the activation schedule is already present in the published chain configuration, operators need to run a compatible node release before the activation block.

In this case:

- all nodes know the activation block
- compatible binaries are required before activation
- incompatible binaries may fail at or after activation
- validators must coordinate rollout before the activation block

### 13.2 Activation added through a new published configuration

If a new fork entry or consensus activation entry is added after network launch, this is a coordinated network upgrade.

All participating nodes must use the same effective fork or consensus activation schedule before reaching the activation block.

A mismatch can cause:

- chain halt
- block rejection
- validator disagreement
- inconsistent state
- chain split

Operators must not locally modify the fork or consensus schedule unless the update is part of an official network upgrade.

---

## 14. Activation block selection

A safe activation block should:

- be far enough in the future for validators to upgrade
- give RPC and explorer operators time to upgrade
- avoid known maintenance windows
- avoid high-risk external deadlines
- avoid periods of known network instability
- leave time for testnet or staging validation
- be clearly announced
- be deterministic and unambiguous

Bad activation blocks are:

- too close to release publication
- chosen before validators confirm readiness
- during active incident response
- during heavy infrastructure migration
- during known operator unavailability
- based on local wall-clock assumptions instead of chain height

The activation block must be communicated as an exact block number.

---

## 15. Release artifacts

A production network upgrade should provide clear release artifacts.

Recommended artifacts:

| Artifact | Purpose |
|---|---|
| Release tag | Auditable source version |
| Binary artifact | Operator-installable node binary |
| Checksums | Artifact verification |
| Release notes | Behavior and compatibility explanation |
| Required version statement | Minimum version required before activation |
| Activation block | Exact block number |
| Configuration diff | Exact network-defining configuration change, if any |
| Operator instructions | Upgrade procedure and checks |
| Rollback note | Clear rollback boundary |
| Post-activation checks | What operators should verify |

Operators should not rely on informal build names or unpublished commits for production upgrades.

---

## 16. Release readiness checklist

Before announcing a hardfork activation, verify:

- implementation is complete
- pre-activation behavior is unchanged
- post-activation behavior is correct
- activation boundary is tested
- block import across activation works
- full sync from genesis across activation works
- validator nodes can propose and verify post-activation blocks
- RPC nodes can follow post-activation blocks
- explorer and indexer dependencies are known
- gas and fee behavior is verified if affected
- staking and validator behavior is verified if affected
- release artifacts are reproducible
- release notes are complete
- activation block is selected
- validator rollout plan exists
- monitoring plan exists
- incident plan exists

A hardfork release should not be activated based only on unit tests.

It should be validated with integration tests, end-to-end tests and activation-boundary tests.

---

## 17. Validator rollout

Validator rollout is the most important part of a consensus-affecting upgrade.

Validators should:

- install the required binary before activation
- verify the correct published configuration
- verify validator key material
- verify peer connectivity
- verify local head
- verify chain ID
- verify service health
- verify logs
- confirm readiness before activation
- remain reachable during the activation window

The target state for a hardfork is:

```text
All validators upgraded before activation.
```

For XGR2.0 PoS operation, validators must also verify:

- PoS active state after block `5446500`
- validator presence in the active validator set
- staking active status
- delegated stake visibility where relevant
- epoch and micro-epoch values
- reward and fee-pool behavior
- PoS monitoring RPC output

---

## 18. RPC and indexer rollout

RPC and indexer operators should upgrade before users depend on post-activation behavior.

RPC and indexer operators should verify:

- node version
- chain ID
- block height
- sync status
- peer count
- transaction receipt behavior
- block import behavior
- explorer and indexer compatibility
- public RPC latency
- error rate
- logs around activation
- affected RPC methods

Public RPC infrastructure should not lag behind consensus-critical upgrades.

A stale RPC node can mislead users, wallets, explorers and dashboards even if validators are healthy.

---

## 19. Mixed-version risk

During rollout, the network may temporarily contain different node versions.

Mixed versions are acceptable only before activation if the different versions still agree on block validity.

At or after activation:

- upgraded nodes follow new rules
- non-upgraded nodes may reject valid new-rule blocks
- non-upgraded validators may fail to participate correctly
- non-upgraded RPC nodes may stop syncing
- non-upgraded explorers may show stale or wrong data

For hardforks, the target state must be:

```text
All validators upgraded before activation.
```

For RPC infrastructure, the target state should be:

```text
All public and indexing nodes upgraded before activation or before users depend on post-activation behavior.
```

---

## 20. Chain split risk

A chain split can occur when nodes disagree on consensus-critical rules.

Common causes:

| Cause | Example |
|---|---|
| Different fork block | Node A activates at block X, node B at block Y |
| Missing fork support | Non-compatible binary cannot validate post-activation blocks |
| Different fork parameters | Same fork name and block, different params |
| Different published config | Operators use different config files |
| Non-deterministic behavior | Local clock/environment affects block validity |
| Partial validator rollout | Some validators reject blocks accepted by others |
| Hidden fallback | One node silently accepts invalid or missing data |
| Fee mismatch | Nodes calculate base fee or rewards differently |
| Staking mismatch | Nodes calculate validator set or voting power differently |

Chain split prevention requires:

- deterministic code
- identical published configuration
- coordinated validator rollout
- clear activation block
- sufficient test coverage
- monitoring during activation

---

## 21. Rollback boundaries

Rollback depends on activation state.

### 21.1 Before activation

Before the activation block, rollback may be possible if:

- the new rules have not activated
- validators coordinate
- the network has not processed post-activation blocks
- the previous binary remains compatible with current chain state
- the published instructions clearly allow rollback

Before activation, rollback usually means replacing the binary and/or delaying the planned activation through a coordinated update.

### 21.2 At or after activation

After activation, rollback is dangerous.

A simple downgrade may fail if:

- the node has processed post-activation blocks
- state was changed under new rules
- receipts/logs differ under new rules
- validator set behavior changed
- fee accounting changed
- transaction validation changed
- the previous binary cannot import the canonical head

After activation, reversing behavior is usually another network upgrade.

Operators must not downgrade after activation unless official instructions explicitly define that path.

---

## 22. Incident handling during activation

If activation fails, first classify the symptom.

| Symptom | Likely class |
|---|---|
| No new blocks | Validator quorum or consensus disagreement |
| Repeated round changes | Validators reject proposals or cannot communicate |
| Some nodes advance, others stop | Fork mismatch or version mismatch |
| RPC nodes lag | RPC/indexer not upgraded or disconnected |
| Block import errors | Execution or fork mismatch |
| Receipt/state mismatch | State transition mismatch |
| High peer churn | Networking or version incompatibility |
| Validator signer errors | Key/config/service issue |

Immediate response priorities:

1. determine whether validators are producing blocks
2. determine whether the chain has split
3. determine which versions validators are running
4. determine whether the activation block has passed
5. identify block import errors
6. identify consensus round-change patterns
7. compare head hashes across trusted nodes
8. avoid uncoordinated downgrades
9. issue operator instructions only after cause is clear

Do not make multiple simultaneous emergency changes.

---

## 23. Activation monitoring

Monitor before, during and after activation.

Critical signals:

| Signal | Why it matters |
|---|---|
| Block height | Confirms chain progress |
| Block time | Detects slowdown or halt |
| Head hash across nodes | Detects split |
| Peer count | Detects network isolation |
| Validator logs | Shows proposal/commit problems |
| Round changes | Shows consensus instability |
| Block import errors | Shows execution/config mismatch |
| RPC error rate | Shows public endpoint issues |
| Txpool size | Shows transaction pressure |
| CPU/memory/disk | Shows infrastructure saturation |
| Explorer/indexer height | Shows downstream compatibility |
| Receipt/log behavior | Shows execution/result compatibility |
| PoS overview RPC | Shows validator, stake, delegation and epoch state after PoS activation |

For hardforks, monitoring should cover:

- at least several epochs or operational windows before activation
- the activation block itself
- several blocks immediately after activation
- enough time to confirm explorer, indexer and RPC stability

---

## 24. Post-activation validation

After activation, verify:

- blocks continue to be produced
- validators remain connected
- validator participation is normal
- no repeated round-change loop appears
- node logs do not show block import failures
- head hashes match across trusted nodes
- RPC nodes follow the same head
- explorers and indexers follow the same head
- transaction receipts are generated correctly
- affected RPC methods behave as expected
- gas and fee behavior matches release expectations
- staking and validator behavior matches release expectations, if applicable

For XGR2.0 PoS, verify:

- head is above block `5446500`
- PoS overview reports `posActive = true`
- `posFromBlock` equals `5446500`
- epoch size resolves to `1000`
- micro-epoch size resolves to `25` unless runtime guard disables it due to validator-count conditions
- minimum validators resolve to `4`
- maximum validators resolve to `25`
- validator set matches expected PoS state
- fee-pool and staking contract balances are readable

Post-activation validation must include both consensus nodes and infrastructure nodes.

A successful validator activation is incomplete if public RPC and explorers are unusable.

---

## 25. Configuration replacement rules

Operators must not casually replace the chain configuration file on a production node.

There are different cases.

### 25.1 Same genesis, new binary

If the published chain configuration remains unchanged and the upgrade is binary-only:

- install the new binary
- keep the same chain configuration
- restart the node
- verify sync and health

### 25.2 Same genesis, activation already scheduled

If the fork or consensus activation schedule is already in the published configuration:

- install a compatible binary before activation
- keep the published chain configuration
- do not locally edit activation values
- verify the binary can process the scheduled activation

### 25.3 Updated published configuration

If XGR Network publishes an updated configuration:

- use the exact published file
- verify checksum or source
- ensure validators use the same effective configuration
- restart according to the operator instructions
- verify chain ID and fork schedule
- monitor activation

### 25.4 Local edits

Local edits to network-defining fields create risk.

Do not locally edit:

- chain ID
- fork activation blocks
- consensus engine parameters
- PoA/PoS schedule
- genesis allocations
- validator genesis data
- protocol registry addresses
- fee-related configured addresses
- bootnodes unless instructed for network operation

Local runtime configuration is separate.

It is fine to configure local:

- data directory
- bind addresses
- log level
- metrics address
- peer limits
- sealing flag according to node role

---

## 26. Staking / PoS upgrades

Staking / PoS changes are high-risk network upgrades because they can affect:

- validator eligibility
- validator set selection
- voting power
- quorum calculation
- reward distribution
- reward ineligibility
- activation/deactivation timing
- delegation accounting
- epoch-boundary logic
- consensus snapshots
- dashboard and endpoint behavior

For XGR2.0 mainnet, delegated PoS is already active from block:

```text
5446500
```

A future staking / PoS change must define:

- activation block or activation condition
- minimum required node version
- validator onboarding process
- staking contract state assumptions
- delegation rules
- epoch semantics
- reward semantics
- monitoring endpoints
- rollback boundary
- expected dashboard behavior

Validators and RPC/indexer operators must upgrade consistently.

---

## 27. Fee-model upgrades

Fee-model upgrades require special care.

They can affect:

- transaction pool admission
- effective gas price
- base fee
- minimum base fee
- priority fee behavior
- fee-pool behavior
- validator reward accounting
- explorer fee display
- transaction receipt interpretation

Fee-model changes can break consensus if different nodes compute different state transitions.

Fee-model release notes must specify:

- activation block
- affected transaction types
- base-fee behavior
- minimum-fee behavior
- fee distribution behavior
- txpool behavior
- expected explorer display
- compatibility with existing wallets

For XGR2.0, `feePoolSplit` is internally aligned to the first PoS block.

Operators must not configure it to any other block.

---

## 28. RPC-impacting upgrades

Some upgrades do not change consensus but still affect clients.

Examples:

- new public RPC endpoint
- removed public RPC endpoint
- changed response field
- changed field name
- changed error behavior
- changed quantity encoding
- changed namespace exposure
- changed debug or txpool behavior
- changed XGR extension endpoint

RPC-impacting upgrades should define:

- whether the endpoint is public baseline or internal/operator-only
- expected method name
- request schema
- response schema
- error behavior
- compatibility notes
- endpoint exposure policy

Client-facing schema changes should be treated as breaking unless explicitly backward-compatible.

For public PoS RPC, the code-backed endpoint reference is the authoritative public schema document.

---

## 29. Upgrade communication

An operator-facing upgrade announcement should include:

| Field | Required content |
|---|---|
| Release version | Exact version/tag |
| Required by | Validators, RPC nodes, indexers, all nodes |
| Activation block | Exact block number, if applicable |
| Activation type | Binary-only, config update, hardfork, staking activation, fee change |
| Minimum required version | Versions that become unsafe/incompatible |
| Configuration changes | Exact published config file or diff |
| Operator action | Commands or high-level steps |
| Risk level | Low / medium / high |
| Rollback boundary | Before/after activation instructions |
| Monitoring guidance | What to watch |
| Support channel | Where operators report issues |

Ambiguous upgrade announcements create operational risk.

Use exact versions and exact blocks.

---

## 30. Operator checklist

Before upgrade:

- read release notes
- confirm required version
- confirm whether activation block exists
- confirm whether configuration changes exist
- back up binary
- back up service config
- back up validator key material where applicable
- verify checksum
- verify disk space
- verify monitoring
- verify peer connectivity
- schedule maintenance window if needed

During upgrade:

- stop service cleanly
- replace binary
- update configuration only if officially required
- restart service
- verify version
- verify chain ID
- verify peer count
- verify block height
- verify logs
- verify validator participation if validator
- verify RPC health if RPC node

After upgrade:

- monitor block production
- monitor logs
- monitor RPC errors
- monitor peers
- monitor resource usage
- compare head with trusted nodes
- remain available during activation window
- do not downgrade after activation unless instructed

---

## 31. Summary

| Topic | Rule |
|---|---|
| Fork activation | Block-height based through published configuration |
| Active fork condition | `currentBlock >= fork.block` |
| XGR2.0 PoS activation | block `5446500` |
| XGR2.0 PoS deployment | block `5446500` |
| XGR2.0 PoS epoch size | `25 * 40 = 1000` blocks |
| XGR2.0 validator limits | min `4`, max `25` |
| `feePoolSplit` | Internally aligned to the first PoS block |
| Validator rollout | Must complete before hardfork activation |
| Configuration edits | Only use published configuration updates |
| Mixed versions | Safe only before activation if behavior remains compatible |
| Rollback before activation | Usually possible with coordination |
| Rollback after activation | Dangerous; usually another network upgrade |
| Chain split prevention | Deterministic code, same config, coordinated validators |
| Monitoring | Required before, during and after activation |

Network upgrades are operationally sensitive because they can affect block validity.

Hardforks require explicit release management, validator coordination and post-activation verification.
