# XGR Chain — Network Upgrade & Hardfork Process

**Document ID:** XGRCHAIN-NETWORK-UPGRADE  
**Last updated:** 2026-05-03  
**Audience:** Node operators, validators, release managers, protocol developers, auditors  
**Implementation status:** Current public baseline with development/preview handling for not-yet-released protocol changes  
**Source of truth:** Public `xgr-network/xgr-node` releases, published XGR Chain configuration, release artifacts, and official XGR Network operator announcements

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
- development / preview handling for not-yet-released protocol changes

This document is written for production network coordination.

It is not a local development guide.

---

## 2. Network upgrade categories

Not every upgrade has the same risk.

| Upgrade type | Description | Consensus risk |
|---|---|---|
| Operational upgrade | Logging, metrics, CLI usability, non-consensus bug fixes | Low if execution/consensus behavior is unchanged |
| RPC upgrade | Adds or changes non-consensus RPC behavior | Low to medium depending on clients |
| Performance upgrade | Improves execution, networking, storage or txpool performance without changing results | Medium if not carefully tested |
| Configuration upgrade | Changes runtime configuration or published chain configuration | Medium to high depending on field |
| Hardfork upgrade | Changes block validity, transaction validity, state transition or consensus behavior | High |
| Validator-set upgrade | Changes validator participation, voting power or epoch behavior | High |
| Fee-model upgrade | Changes gas/base-fee/min-fee/burn/donation/reward behavior | High |
| Staking/PoS upgrade | Activates staking, delegation or stake-weighted validator behavior | High |

The upgrade process must match the risk level.

A binary-only upgrade without consensus changes is not the same as a hardfork.

A hardfork requires coordinated release and activation.

---

## 3. Hardfork definition

A hardfork is a protocol change that makes upgraded nodes follow different block-validity, transaction-validity or state-transition rules from older nodes after a defined activation point.

A hardfork can change:

- EVM execution rules
- transaction validation rules
- gas accounting
- fee accounting
- header validation
- receipt generation
- log generation
- state transition behavior
- block reward behavior
- validator-set behavior
- consensus voting rules
- epoch transition logic
- staking activation logic
- protocol-level configured addresses
- fork-specific parameters

Any change that can make two nodes disagree about whether a block is valid is hardfork-level.

---

## 4. Fork activation model

XGR Chain uses a block-height-based fork activation model.

Forks are configured under:

```text
params.forks
```

Each fork entry defines an activation block.

Conceptually:

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

## 5. Published mainnet fork configuration

The published mainnet configuration currently activates the following forks from block `0`:

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

The published mainnet configuration currently activates the following forks from block `1208500`:

| Fork / feature | Activation block |
|---|---:|
| `EIP2930` | `1208500` |
| `EIP2929` | `1208500` |
| `EIP3860` | `1208500` |
| `EIP3651` | `1208500` |

Nodes must use the published fork schedule for the target network.

A different fork schedule means different execution rules.

---

## 6. Public baseline fork support

The public `xgr-network/xgr-node` baseline supports the fork names used by the published mainnet configuration.

Public baseline fork set includes:

| Fork / feature | Status |
|---|---|
| `homestead` | Public baseline |
| `byzantium` | Public baseline |
| `constantinople` | Public baseline |
| `petersburg` | Public baseline |
| `istanbul` | Public baseline |
| `london` | Public baseline |
| `londonfix` | Public baseline |
| `EIP150` | Public baseline |
| `EIP155` | Public baseline |
| `EIP158` | Public baseline |
| `quorumcalcalignment` | Public baseline |
| `txHashWithType` | Public baseline |
| `EIP2930` | Public baseline |
| `EIP2929` | Public baseline |
| `EIP3860` | Public baseline |
| `EIP3651` | Public baseline |

A fork name being supported by the node binary does not mean it is active on the network.

Network activation depends on the published chain configuration.

---

## 7. Development and preview fork support

Some fork features can exist in development before they are part of the public baseline or the published mainnet configuration.

Example:

| Fork / feature | Status |
|---|---|
| `feePoolSplit` | Development / preview until included in an official public release and activated through published configuration |

A development fork feature is not production-active merely because it exists in development code.

A feature becomes operational only when all required conditions are met:

1. the feature is included in an official node release
2. release notes describe the behavior
3. the published chain configuration activates it, if activation is configuration-based
4. validators and operators are instructed to upgrade
5. the activation block or activation condition is reached

Until then, it must be treated as development / preview.

---

## 8. What requires hardfork coordination

Treat a change as hardfork-level if it affects any of the following:

| Area | Examples |
|---|---|
| Transaction validity | New tx type, fee validation, chain ID rules, nonce handling |
| EVM execution | Opcode behavior, gas schedule, precompile behavior |
| State transition | Balance changes, storage changes, log/receipt differences |
| Block validity | Header fields, base fee, gas limit, extra data, seal validation |
| Consensus behavior | Proposal validation, commit rules, round logic, quorum behavior |
| Validator set | Join/leave behavior, activation/deactivation, voting power |
| Staking behavior | Delegation, self-stake, epoch effectiveness, slashing, rewards |
| Fee accounting | Base fee, min fee, burn, donation, fee pool, rewards |
| Fork schedule | Activation block, fork-specific parameters |
| Protocol registry behavior | Configured protocol addresses or registry-dependent behavior |
| RPC-generated protocol actions | Any RPC-generated transaction or action that affects consensus state |

If old and new nodes can disagree about block validity, the change requires coordinated activation.

---

## 9. What usually does not require hardfork coordination

Some changes may not require a hardfork if they do not affect consensus, execution results or network-wide deterministic behavior.

Examples:

| Change | Typical status |
|---|---|
| Documentation update | No hardfork |
| Logging improvement | No hardfork |
| Metrics improvement | No hardfork |
| CLI help text | No hardfork |
| Non-consensus RPC read endpoint | Usually no hardfork |
| Dashboard-only formatting | No hardfork |
| Internal refactor with identical behavior | No hardfork if verified |
| Performance optimization with identical output | No hardfork if verified |
| Additional monitoring endpoint | Usually no hardfork |

These changes still need testing.

A “non-consensus” change can become dangerous if it accidentally changes state transition, block validation or transaction validation.

---

## 10. Published configuration vs runtime flags

The published chain configuration defines network behavior.

Runtime flags define local node behavior.

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

## 11. Configuration update model

There are two different cases.

### 11.1 Fork schedule already published

If the fork schedule is already present in the published chain configuration, operators usually need to run a compatible node release before the activation block.

In this case:

- all nodes already know the activation block
- upgraded binaries are required before activation
- older binaries may fail at or after activation
- validators must coordinate rollout before the fork block

### 11.2 Fork schedule added after launch

If a new fork entry is added after network launch, this is a coordinated network upgrade.

All participating nodes must use the same effective fork schedule before reaching the activation block.

A mismatch can cause:

- chain halt
- block rejection
- validator disagreement
- inconsistent state
- chain split

Operators must not locally modify the fork schedule unless the update is part of an official network upgrade.

---

## 12. Activation block selection

A safe activation block should:

- be far enough in the future for validators to upgrade
- give RPC and explorer operators time to upgrade
- avoid known maintenance windows
- avoid high-risk external deadlines
- avoid periods of known network instability
- leave time for testnet/staging validation
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

## 13. Release artifacts

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

## 14. Release readiness checklist

Before announcing a hardfork activation, verify:

- implementation is complete
- pre-fork behavior is unchanged
- post-fork behavior is correct
- activation boundary is tested
- block import across activation works
- full sync from genesis across activation works
- validator nodes can propose and verify post-fork blocks
- RPC nodes can follow post-fork blocks
- explorer/indexer dependencies are known
- gas/fee behavior is verified if affected
- staking/validator behavior is verified if affected
- release artifacts are reproducible
- release notes are complete
- activation block is selected
- validator rollout plan exists
- monitoring plan exists
- incident plan exists

A hardfork release should not be activated based only on unit tests.

Boundary and replay behavior matter.

---

## 15. Test requirements

Testing must match the risk of the change.

Minimum hardfork test cases:

| Case | Expected behavior |
|---|---|
| block `forkBlock - 1` | Old behavior |
| block `forkBlock` | New behavior active |
| block `forkBlock + 1` | New behavior remains active |
| missing fork config | Deterministic behavior according to release design |
| mismatched fork params | Explicit failure or deterministic behavior |
| fresh sync across activation | Same canonical chain |
| block import across activation | Same state root and receipts |
| validator proposal after activation | Accepted by upgraded validators |
| old binary after activation | Fails predictably if rules are incompatible |

Additional tests for consensus changes:

- validator-set transition tests
- quorum tests
- proposer selection tests
- round-change tests
- snapshot/replay tests
- network restart tests
- mixed-upgrade simulations where safe and useful

Additional tests for staking/PoS changes:

- validator join
- validator activation
- validator deactivation
- delegation
- undelegation
- reward attribution
- slashing / reward ineligibility
- micro/macro epoch boundaries
- stake-weighted voting behavior
- liveness under offline validators

---

## 16. Validator rollout

Validator operators should upgrade before the activation block.

Recommended validator rollout steps:

1. Read release notes.
2. Confirm required version.
3. Confirm activation block.
4. Back up validator key material.
5. Back up service configuration.
6. Verify release artifact checksum.
7. Install the new binary.
8. Confirm binary version.
9. Confirm the node uses the published chain configuration.
10. Restart the node during the agreed rollout window.
11. Verify peer connectivity.
12. Verify block height.
13. Verify validator participation.
14. Monitor logs.
15. Remain available during activation.

Useful checks:

```bash
/opt/xgr/bin/xgrchain version
```

```bash
/opt/xgr/bin/xgrchain server --help
```

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
```

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Validator nodes should not be upgraded blindly without verifying the target release and activation block.

---

## 17. Full node and RPC rollout

Full nodes and RPC nodes should also upgrade before activation when the upgrade affects execution, RPC compatibility or fork behavior.

RPC/indexer operators should verify:

- node version
- chain ID
- block height
- sync status
- peer count
- transaction receipt behavior
- block import behavior
- explorer/indexer compatibility
- public RPC latency
- error rate
- logs around activation

Public RPC infrastructure should not lag behind consensus-critical upgrades.

A stale RPC node can mislead users, wallets, explorers and dashboards even if validators are healthy.

---

## 18. Mixed-version risk

During rollout, the network may temporarily contain old and new node versions.

Mixed versions are acceptable only before activation if old and new nodes still agree on block validity.

At or after activation:

- upgraded nodes follow new rules
- old nodes may reject valid new-rule blocks
- old validators may fail to participate correctly
- old RPC nodes may stop syncing
- old explorers may show stale or wrong data

For hardforks, the target state must be:

```text
All validators upgraded before activation.
```

For RPC infrastructure, the target state should be:

```text
All public and indexing nodes upgraded before activation or before users depend on post-fork behavior.
```

---

## 19. Chain split risk

A chain split can occur when nodes disagree on consensus-critical rules.

Common causes:

| Cause | Example |
|---|---|
| Different fork block | Node A activates at block X, node B at block Y |
| Missing fork support | Old binary cannot validate post-fork blocks |
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

## 20. Rollback boundaries

Rollback depends on activation state.

### 20.1 Before activation

Before the activation block, rollback may be possible if:

- the new rules have not activated
- validators coordinate
- the network has not processed post-fork blocks
- the previous binary remains compatible with current chain state
- the published instructions clearly allow rollback

Before activation, rollback usually means replacing the binary and/or delaying the planned activation through a coordinated update.

### 20.2 At or after activation

After activation, rollback is dangerous.

A simple downgrade may fail if:

- the node has processed post-fork blocks
- state was changed under new rules
- receipts/logs differ under new rules
- validator set behavior changed
- fee accounting changed
- transaction validation changed
- the old binary cannot import the canonical head

After activation, reversing behavior is usually another network upgrade.

Operators must not downgrade after activation unless official instructions explicitly define that path.

---

## 21. Incident handling during activation

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

## 22. Activation monitoring

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

For hardforks, monitoring should cover:

- at least several epochs or operational windows before activation
- the activation block itself
- several blocks immediately after activation
- enough time to confirm explorer/indexer/RPC stability

---

## 23. Post-activation validation

After activation, verify:

- blocks continue to be produced
- validators remain connected
- validator participation is normal
- no repeated round-change loop appears
- node logs do not show block import failures
- head hashes match across trusted nodes
- RPC nodes follow the same head
- explorers/indexers follow the same head
- transaction receipts are generated correctly
- affected RPC methods behave as expected
- gas/fee behavior matches release expectations
- staking/validator behavior matches release expectations, if applicable

Post-activation validation must include both consensus nodes and infrastructure nodes.

A successful validator activation is incomplete if public RPC and explorers are unusable.

---

## 24. Configuration replacement rules

Operators must not casually replace the chain configuration file on a production node.

There are different cases.

### 24.1 Same genesis, new binary

If the published chain configuration remains unchanged and the upgrade is binary-only:

- install the new binary
- keep the same chain configuration
- restart the node
- verify sync and health

### 24.2 Same genesis, fork already scheduled

If the fork schedule is already in the published configuration:

- install a compatible binary before activation
- keep the published chain configuration
- do not locally edit fork values
- verify the binary can process the scheduled fork

### 24.3 Updated published configuration

If XGR Network publishes an updated configuration:

- use the exact published file
- verify checksum or source
- ensure validators use the same effective configuration
- restart according to the operator instructions
- verify chain ID and fork schedule
- monitor activation

### 24.4 Local edits

Local edits to network-defining fields create risk.

Do not locally edit:

- chain ID
- fork activation blocks
- consensus engine parameters
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

## 25. Staking / PoS upgrades

Staking / PoS activation is hardfork-level or coordinated network-upgrade-level behavior.

It can affect:

- validator eligibility
- validator set selection
- voting power
- quorum calculation
- reward distribution
- slashing or reward ineligibility
- activation/deactivation timing
- delegation accounting
- epoch-boundary logic
- consensus snapshots
- dashboard and endpoint behavior

Until activated through an official release and published configuration, staking/PoS features are development / preview.

A staking activation must define:

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

## 26. Fee-model upgrades

Fee-model upgrades require special care.

They can affect:

- transaction pool admission
- effective gas price
- base fee
- minimum base fee
- priority fee behavior
- burn behavior
- donation behavior
- fee-pool behavior
- validator reward accounting
- explorer fee display
- transaction receipt interpretation

Fee-model changes can break consensus if different nodes compute different state transitions.

Fee-model release notes must specify:

- activation block
- affected transaction types
- base-fee behavior
- min-fee behavior
- fee distribution behavior
- txpool behavior
- expected explorer display
- compatibility with existing wallets

If a feature such as `feePoolSplit` is present only in development, it remains development / preview until included in an official release and activated by published configuration.

---

## 27. RPC-impacting upgrades

Some upgrades do not change consensus but still affect clients.

Examples:

- new RPC endpoint
- removed RPC endpoint
- changed response field
- changed field name
- changed error behavior
- changed quantity encoding
- changed namespace exposure
- changed debug/txpool behavior
- changed XGR extension endpoint

RPC-impacting upgrades should define:

- whether the endpoint is public baseline or extension
- whether it is development / preview
- expected method name
- request schema
- response schema
- error behavior
- compatibility notes
- endpoint exposure policy

Examples of release-dependent XGR extension areas:

- XDaLa endpoints
- staking endpoints
- validator monitoring endpoints
- grant management endpoints
- orchestration/session endpoints

Client-facing schema changes should be treated as breaking unless explicitly backward-compatible.

---

## 28. Upgrade communication

An operator-facing upgrade announcement should include:

| Field | Required content |
|---|---|
| Release version | Exact version/tag |
| Required by | Validators, RPC nodes, indexers, all nodes |
| Activation block | Exact block number, if applicable |
| Activation type | Binary-only, config update, hardfork, staking activation, fee change |
| Minimum required version | Old versions that become unsafe/incompatible |
| Configuration changes | Exact published config file or diff |
| Operator action | Commands or high-level steps |
| Risk level | Low / medium / high |
| Rollback boundary | Before/after activation instructions |
| Monitoring guidance | What to watch |
| Support channel | Where operators report issues |

Ambiguous upgrade announcements create operational risk.

Use exact versions and exact blocks.

---

## 29. Operator checklist

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

## 30. Summary

| Topic | Rule |
|---|---|
| Fork activation | Block-height based through published configuration |
| Active fork condition | `currentBlock >= fork.block` |
| Current public baseline | Supports published mainnet fork set |
| Development features | Not production-active until official release and activation |
| `feePoolSplit` | Development / preview until public release and published activation |
| Staking / PoS | Development / preview until official activation |
| Validator rollout | Must complete before hardfork activation |
| Configuration edits | Only use published configuration updates |
| Mixed versions | Safe only before activation if behavior remains compatible |
| Rollback before activation | Usually possible with coordination |
| Rollback after activation | Dangerous; usually another network upgrade |
| Chain split prevention | Deterministic code, same config, coordinated validators |
| Monitoring | Required before, during and after activation |

Network upgrades are operationally sensitive because they can affect block validity.

Hardforks require explicit release management, validator coordination and post-activation verification.
