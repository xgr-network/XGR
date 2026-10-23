# XGR Chain — Network Upgrade & Hardfork Process

**Document ID:** XGRCHAIN-NETWORK-UPGRADE  
**Last updated:** 2026-10-03  
**Audience:** Node operators, validators, release managers, protocol developers, infrastructure engineers, auditors  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet configuration:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Scope:** Production XGRChain software upgrades, protocol activations and hardfork coordination

---

## 1. Scope

This document describes the production upgrade model for XGRChain.

It covers:

- node software releases,
- operational upgrades,
- RPC upgrades,
- storage upgrades,
- consensus-sensitive execution changes,
- hardforks,
- fork activation,
- validator rollout,
- configuration changes,
- staking and PoS upgrades,
- fee-model changes,
- native-precompile changes,
- activation monitoring,
- rollback boundaries,
- chain-split prevention,
- external interchain-service upgrades.

This document does not define:

- XDaLa application upgrades,
- XRC specification versioning,
- individual smart-contract upgrade mechanisms,
- detailed interchain relayer operation,
- UI deployment procedures.

---

## 2. Current mainnet baseline

Current public node release:

```text id="ijrkei"
xgr-node v3.1.1
```

Release commit:

```text id="i4r8yd"
1a4844b311fb856cb8c2303a40fa8aa69b560544
```

Current XGRChain mainnet identity remains:

```text id="ss1aqf"
chainId = 1643
```

The current consensus phase is delegated PoS.

Published transition:

| Phase | Type | Validator type | Blocks |
| --- | --- | --- | --- |
| Initial | `PoA` | `bls` | `0–5446499` |
| Current | `PoS` | `bls` | `5446500+` |

PoS configuration:

| Parameter | Value |
| --- | ---: |
| Activation block | `5446500` |
| Deployment block | `5446500` |
| Minimum validators | `4` |
| Maximum validators | `25` |
| Micro epoch | `25` blocks |
| Macro factor | `40` |
| Macro epoch | `1000` blocks |
| Inactivity decay | `9000` bps |
| Nominal uptime weight | `10000` |

The `v3.1.1` release does not create a new mainnet genesis.

---

## 3. Upgrade classification

Not every new binary is a hardfork.

XGRChain upgrades should first be classified by what they can change.

| Upgrade class | Example | Consensus coordination |
| --- | --- | --- |
| Documentation | Documentation only | None |
| Operational | Logging, metrics, CLI | Normally none |
| RPC | Read-only API behavior | Usually none |
| Storage | Trie sweeper, local retention | None if canonical execution is unchanged |
| Performance | Networking, database, execution optimization | Depends on deterministic equivalence |
| External service | Relayer, indexer, monitoring | Not consensus by itself |
| Execution | Precompile/EVM/state-transition behavior | Potentially consensus-critical |
| Fee model | Base fee, fee allocation | Consensus-critical |
| PoS/staking | Validator set, voting power, rewards | Consensus-critical |
| Hardfork | New block/state validity rules | Coordinated activation required |

The relevant question is:

> Can upgraded and non-upgraded consensus nodes produce or accept different canonical state for the same block?

If yes, the change is consensus-sensitive.

---

## 4. What is a hardfork?

A hardfork is a protocol change that can cause upgraded and non-upgraded nodes to disagree about valid canonical chain state after an activation boundary.

Examples include changes to:

- transaction validity,
- EVM execution,
- gas accounting,
- native precompiles,
- block-header validation,
- state transition,
- receipt generation,
- consensus voting,
- validator-set calculation,
- staking behavior,
- fee distribution,
- protocol system transactions,
- fork activation rules.

A binary version change alone is not necessarily a hardfork.

---

## 5. Fork activation model

XGRChain supports block-height-based fork activation.

Configured EVM forks live under:

```text id="6s6jgd"
params.forks
```

A configured fork is active when:

```text id="9bkfos"
currentBlock >= fork.block
```

All nodes participating in consensus must resolve the same effective protocol rules for the same block height.

---

## 6. Current published EVM fork schedule

Active from block `0`:

| Fork | Block |
| --- | ---: |
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

Active from block `1208500`:

| Fork | Block |
| --- | ---: |
| `EIP2930` | `1208500` |
| `EIP2929` | `1208500` |
| `EIP3860` | `1208500` |
| `EIP3651` | `1208500` |

Operators joining mainnet must not invent their own fork schedule.

---

## 7. PoS activation

The PoS transition is configured through:

```text id="zh716w"
params.engine.ibft.types
```

rather than through a normal EVM fork entry.

Mainnet:

```text id="3kl7cc"
PoA: blocks 0–5446499
PoS: blocks 5446500+
```

IBFT remains the deterministic-finality mechanism after PoS activation.

PoS changes:

- validator participation,
- staking,
- delegation,
- voting power,
- validator-set evolution,
- epoch accounting.

---

## 8. `feePoolSplit` alignment

`xgr-node v3.1.1` requires the effective `feePoolSplit` activation to match the first PoS fork.

For mainnet:

```text id="0g603p"
first PoS block = 5446500
```

Therefore:

```text id="i09psf"
feePoolSplit = 5446500
```

If an explicit `feePoolSplit` configuration disagrees with the first PoS block, node initialization fails.

This prevents inconsistent PoS fee-accounting activation.

---

## 9. Native precompiles and upgrade risk

Native precompiles are implemented directly by the node execution engine.

They are therefore different from ordinary deployed smart contracts.

For example, `v3.1.1` registers the native XGR interchain BLS12-381 verifier at:

```text id="0ipp0x"
0x0000000000000000000000000000000000002040
```

A change that:

- adds a precompile,
- removes a precompile,
- changes its input validation,
- changes gas accounting,
- changes its return value,
- changes cryptographic verification behavior,

can be consensus-sensitive.

If validators execute the same transaction differently because they run different precompile implementations, they can derive different state-transition results.

Therefore:

> Native execution primitives must be treated with the same release discipline as other consensus-relevant EVM behavior.

---

## 10. External interchain services are a separate upgrade domain

The XGR interchain backend also contains components outside `xgr-node`.

Examples include:

- Hyperlane-compatible relayers,
- remote-chain routers,
- checkpoint generation,
- validator-attestation services,
- deployment tooling,
- operational monitoring.

A relayer software update does not automatically change XGRChain consensus.

For example:

```text id="ap1a6q"
relayer retry logic
log rotation
snapshot compaction
health checks
```

are service-level concerns.

However, changing an on-chain router or security module can affect the interchain protocol even though it does not change XGRChain block consensus.

Therefore there are two separate questions:

```text id="w41441"
Does this change XGRChain consensus?
```

and:

```text id="1votqk"
Does this change interchain security or asset behavior?
```

Both can be operationally critical, but they are different upgrade classes.

---

## 11. Trie Sweeper upgrades are local storage upgrades

The Online State Trie Sweeper is node-local storage functionality.

Configuration includes:

```text id="uzb189"
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Changing:

- whether pruning is enabled,
- the local retention window,
- the sweep interval,

does not change canonical XGRChain state.

Two nodes may therefore use different retention policies while following the same chain.

Trie pruning does affect:

- disk usage,
- LevelDB compaction,
- historical-state availability,
- historical RPC capability.

It does not affect:

- chain ID,
- validator set,
- block validity,
- current state root,
- consensus quorum.

State-retention policy changes do not require a hardfork.

---

## 12. What requires consensus coordination?

Consensus coordination is required for any change that can affect:

| Area | Examples |
| --- | --- |
| Transaction validation | chain ID, nonce, fee validation |
| EVM execution | opcode/precompile behavior |
| State transition | balances, storage, system transactions |
| Block validity | headers, roots, gas, extra data |
| Consensus | proposal, seal, quorum behavior |
| Validator set | activation, removal, ordering |
| Voting power | stake weighting, uptime weighting |
| PoS | epoch behavior, staking lifecycle |
| Fees | base fee, allocation, rewards |
| Fork schedule | activation blocks |
| Protocol execution | native system addresses or precompiles |

A consensus-affecting binary must not be rolled out casually.

---

## 13. Changes that normally do not require a hardfork

Examples:

- logging,
- metrics,
- documentation,
- CLI help,
- monitoring,
- local storage retention,
- trie garbage collection,
- read-only non-consensus RPC additions,
- reverse-proxy configuration,
- systemd configuration,
- external relayer monitoring,
- indexer UI changes.

These changes still require testing.

A bug in a supposedly non-consensus refactor can still become consensus-relevant if it changes deterministic execution.

---

## 14. Published chain configuration versus local runtime

Published chain configuration includes:

- chain ID,
- genesis,
- consensus schedule,
- fork schedule,
- validator genesis data,
- epoch parameters,
- protocol addresses.

Local runtime configuration includes:

- bind addresses,
- data directory,
- metrics,
- logging,
- peer limits,
- RPC exposure,
- sealing,
- trie retention.

External-service configuration includes:

- interchain relayers,
- remote RPC endpoints,
- relayer accounts,
- service state,
- health checks.

These must not be treated as one configuration layer.

---

## 15. Bootnode updates

Bootnodes assist peer discovery.

Changing a bootnode does not change:

- chain ID,
- block validity,
- transaction validity,
- validator voting power.

Therefore bootnode-list maintenance is a networking/discovery change, not a consensus hardfork.

Operators should still use the published network entry points unless an official network update specifies replacements.

---

## 16. Activation models

There are several valid upgrade models.

### Binary-only compatible upgrade

Used when:

- canonical execution is unchanged,
- consensus is unchanged,
- chain configuration remains unchanged.

Procedure:

```text id="wt0k3w"
install binary
restart node
verify version
verify sync
```

### Scheduled protocol activation

Used when a future activation block is already known.

Procedure:

```text id="v5tl71"
release compatible binary
upgrade validators
verify readiness
reach activation block
monitor
```

### Configuration-backed activation

Used when a new published fork schedule or consensus configuration is required.

All consensus nodes must use the same effective network-defining configuration before activation.

### External-service upgrade

Used for systems such as interchain relayers.

This normally has its own deployment and rollback process independent of XGRChain consensus activation.

---

## 17. Activation-block selection

For a future hardfork, the activation block should:

- be explicitly specified,
- be sufficiently far in the future,
- allow validator rollout,
- allow RPC/indexer rollout,
- allow staging/testnet validation,
- avoid known maintenance windows,
- provide incident-response margin.

Use an exact block number.

Do not rely on a wall-clock statement such as:

```text id="5rq5nj"
activate Tuesday afternoon
```

Consensus activates by deterministic chain state, not human calendar interpretation.

---

## 18. Release artifacts

A production XGRChain release should provide:

- immutable release tag,
- source commit,
- binary artifact where supported,
- checksum file,
- version artifact,
- release notes,
- compatibility statement,
- operator instructions.

The `v3.1.1` release provides a Linux AMD64 binary and checksum/version artifacts.

Operators should verify downloaded binaries before replacing a production executable.

---

## 19. Release-readiness validation

For consensus-sensitive releases, validate:

- unit tests,
- integration tests,
- E2E tests,
- deterministic execution,
- proposal verification,
- block import,
- validator quorum,
- fork boundary,
- state-root agreement,
- transaction receipts,
- fee behavior,
- staking behavior,
- synchronization.

For native precompile changes additionally validate:

- valid input,
- invalid input,
- malformed input,
- cryptographic failure,
- deterministic return data,
- deterministic gas behavior.

---

## 20. Compatibility vectors

Consensus-sensitive code should be tested with deterministic vectors where possible.

Vectors should ensure independent nodes agree on:

- transaction decoding,
- execution result,
- state transition,
- receipt data,
- protocol primitives.

Compatibility testing is particularly important when:

- changing EVM execution,
- introducing precompiles,
- modifying transaction validation,
- changing fee calculations.

---

## 21. Validator rollout

Validators are the highest-priority upgrade group for consensus-sensitive releases.

Before activation they should verify:

- exact binary version,
- release commit,
- canonical chain configuration,
- validator signing key,
- current head,
- peer connectivity,
- validator-set membership,
- service health,
- sufficient disk space.

For a scheduled hardfork, the desired state is:

```text id="l7p17t"
all consensus validators upgraded before activation
```

---

## 22. Mixed-version operation

Mixed node versions can be safe only while they produce identical consensus results.

For a consensus-changing release:

```text id="lhxn4n"
before activation:
mixed versions may be acceptable if rules are identical

after activation:
old versions may become incompatible
```

For execution changes without an explicit activation gate, operators must be especially careful.

If the new functionality can be invoked immediately, consensus validators need compatible execution behavior before applications rely on it.

---

## 23. Public RPC and indexer rollout

RPC/indexer infrastructure should normally follow validator rollout closely.

Verify:

- node version,
- sync state,
- current head,
- peer count,
- receipt behavior,
- log indexing,
- gas RPC behavior,
- historical-state policy,
- explorer compatibility.

An outdated RPC node can remain online yet return stale data.

---

## 24. Trie-pruned RPC compatibility

Trie pruning deserves a separate operational check during upgrades.

After upgrading a pruned RPC node verify:

- current state queries succeed,
- canonical head progresses,
- sweeper remains healthy,
- historical RPC expectations match configured retention.

Do not interpret failure of an old historical `eth_call` on a deliberately pruned node as a consensus failure.

It can simply mean that the required historical state has been reclaimed.

---

## 25. Chain-split risk

A chain split can occur if consensus nodes disagree about deterministic protocol behavior.

Examples:

- different fork activation heights,
- different EVM rules,
- different native precompile implementation,
- different validator-set calculation,
- different voting-power calculation,
- different fee calculation,
- inconsistent configuration,
- non-deterministic execution.

Prevention requires:

- deterministic implementation,
- release discipline,
- identical network-defining configuration,
- validator coordination,
- activation tests,
- head/hash monitoring.

---

## 26. Rollback before activation

Before a scheduled protocol activation, rollback can be possible if:

- the new rules have not yet activated,
- old software remains compatible with the current chain,
- validators coordinate the rollback,
- no incompatible canonical blocks have been finalized.

Rollback instructions should be release-specific.

---

## 27. Rollback after activation

After consensus-changing behavior has been used on canonical mainnet, arbitrary downgrade is unsafe.

Examples:

- new fork has activated,
- new precompile has affected execution,
- new staking rules have changed state,
- new fee rules have changed balances.

In such cases, reverting behavior normally requires another coordinated protocol upgrade.

Do not simply replace the binary with an older version without explicit compatibility analysis.

---

## 28. Storage-feature rollback

Storage features have a different rollback boundary.

Disabling:

```text id="516wi2"
--trie-sweeper
```

prevents future pruning.

It does **not** restore historical trie data already deleted.

If previously removed historical state is required again, an operator may need to:

- rebuild,
- resynchronize,
- restore from an appropriate backup,
- use an archive-compatible node.

This is an operational recovery issue, not a chain rollback.

---

## 29. Interchain-service rollback

Relayer or interchain-service deployments can often be stopped independently of XGRChain consensus.

Examples:

```text id="3qdzvn"
stop relayer
disable submission
restore previous service binary
```

However, operators must first consider:

- pending cross-chain messages,
- already submitted transactions,
- route state,
- locked/minted assets,
- checkpoint state.

An external-service rollback must not be confused with reverting finalized XGRChain transactions.

Finalized chain state remains finalized.

---

## 30. Activation monitoring

For consensus-sensitive upgrades monitor:

- block number,
- block interval,
- head hash across trusted nodes,
- peer count,
- validator participation,
- round changes,
- proposer failures,
- block-import failures,
- state-root mismatch,
- receipt-root mismatch,
- signer errors,
- CPU,
- memory,
- disk,
- RPC health.

For PoS additionally monitor:

- validator set,
- active stake,
- effective voting power,
- epoch state,
- uptime weighting.

---

## 31. Incident classification

### No new blocks

Possible causes:

- insufficient consensus power,
- validator disagreement,
- proposer failure,
- incompatible binaries.

### Some nodes advance, others stop

Likely causes:

- version mismatch,
- execution divergence,
- configuration mismatch.

### Same height, different head hashes

Potential consensus split.

Escalate immediately.

### Validators healthy but RPC stale

Likely infrastructure or RPC-node problem rather than validator consensus.

### Interchain transfer failure while chain progresses

Likely interchain-contract, validator, relayer or remote-chain problem rather than XGRChain consensus.

---

## 32. Post-upgrade validation

After any node release, verify:

```text id="hnsyxy"
binary version
chain ID
block progression
peer count
head hash
logs
```

For validators additionally verify:

```text id="shc3qb"
validator membership
sealing
consensus participation
voting power
epoch status
```

For RPC nodes verify:

```text id="7jz7dd"
eth_chainId
eth_blockNumber
eth_syncing
net_peerCount
eth_call
eth_estimateGas
eth_getTransactionReceipt
```

For trie-pruned nodes also verify sweeper health.

---

## 33. Configuration replacement rules

### Same chain config, new binary

Keep the canonical chain file unchanged.

Replace only the binary and restart.

### New scheduled protocol rules

Use the officially published compatible binary and configuration.

Do not locally modify activation heights.

### Local runtime change

Changes such as:

```text id="uslk02"
log level
RPC binding
metrics
trie retention
```

do not require replacing mainnet genesis.

### External-service change

Relayer configuration should be changed in the interchain service configuration, not by editing XGRChain genesis.

---

## 34. PoS upgrade rules

Changes to PoS can affect:

- validator eligibility,
- staking,
- delegation,
- validator ordering,
- voting power,
- uptime weighting,
- quorum,
- rewards,
- epochs.

Such changes should be considered consensus-sensitive unless proven otherwise.

A PoS upgrade must define:

- affected behavior,
- required node version,
- activation boundary,
- expected validator-set behavior,
- migration assumptions,
- validation procedure.

---

## 35. Fee-model upgrade rules

Changes affecting:

- base fee,
- minimum fee,
- transaction fee validation,
- validator allocation,
- fee pool,
- burn destination,
- rewards,

can alter state transition.

They therefore require consensus-safe rollout.

Wallet-facing RPC behavior should also be tested whenever fee policy changes.

---

## 36. RPC-only upgrade rules

A genuinely read-only RPC change normally does not require a hardfork.

Examples:

- new monitoring method,
- additional response field,
- improved error reporting.

However, client compatibility still matters.

Document:

- method name,
- parameters,
- response fields,
- errors,
- public/private exposure.

An RPC that generates or submits protocol actions may require stronger classification.

---

## 37. Release communication

Every operator-facing production release should identify:

| Field | Required |
| --- | --- |
| Release version | Yes |
| Commit | Yes |
| Required operator action | Yes |
| Consensus impact | Yes |
| Config change | Yes/No |
| Activation block | If applicable |
| Validator requirement | If applicable |
| RPC impact | If applicable |
| Storage impact | If applicable |
| Rollback boundary | Yes |
| Verification steps | Yes |

Avoid ambiguous statements such as:

```text id="rkhp1l"
upgrade soon
```

Use exact release identifiers.

---

## 38. Operator checklist

Before upgrading:

- read release notes,
- identify upgrade class,
- verify binary/checksum,
- back up service configuration,
- protect validator keys,
- verify disk space,
- verify peers,
- verify current head.

During upgrade:

- stop service cleanly,
- replace binary,
- change configuration only if required,
- restart,
- verify version,
- verify chain ID,
- verify synchronization,
- inspect logs.

After upgrade:

- verify head progression,
- compare head hash,
- verify peers,
- verify validator status if applicable,
- verify RPC if applicable,
- verify Trie Sweeper if enabled,
- monitor for repeated errors.

---

## 39. Current `v3.1.1` baseline summary

| Area | Current status |
| --- | --- |
| Node release | `v3.1.1` |
| Release commit | `1a4844b311fb856cb8c2303a40fa8aa69b560544` |
| Mainnet chain ID | `1643` |
| Genesis replacement required | No |
| Consensus | IBFT |
| Current validator model | Delegated PoS |
| PoS activation | `5446500` |
| Validator limits | `4–25` |
| Macro epoch | `1000` blocks |
| Trie Sweeper | Local node feature |
| Trie-retention changes | No hardfork |
| Native precompile changes | Potentially consensus-sensitive |
| Interchain BLS precompile | `0x2040` |
| Relayer upgrades | External-service upgrade |
| Bridge/router upgrades | Interchain protocol upgrade |
| XGRChain ↔ Base route | Operationally separate from chain consensus |

---

## 40. Design principle

XGRChain upgrades should be classified by their actual effect rather than by version number.

The critical separation is:

```text id="jxt9a6"
node software
       │
       ├── local-only behavior
       │
       ├── consensus execution behavior
       │
       └── RPC behavior

chain configuration
       │
       └── network-defining protocol state

external services
       │
       └── interchain / indexing / operational infrastructure
```

A production upgrade process must identify which boundary is being changed before rollout begins.

Consensus-affecting behavior requires validator coordination.

Local storage behavior does not.

External interchain services have their own operational and security lifecycle.

Keeping those boundaries explicit reduces unnecessary hardforks while protecting XGRChain against accidental consensus divergence.
