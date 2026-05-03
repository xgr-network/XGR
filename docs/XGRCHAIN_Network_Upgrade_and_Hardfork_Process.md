# XGR Chain — Network Upgrade & Hardfork Process

**Document ID:** XGRCHAIN-NETWORK-UPGRADE  
**Last updated:** 2026-05-03  
**Audience:** Protocol developers, node operators, validators, release managers, auditors  
**Implementation status:** Mainnet  
**Source of truth:** `xgrchain/chain/params.go`, `genesis/mainnet/genesis.json`, release artifacts

---

## 1. Scope

This document defines the XGR Chain process for **network upgrades and hardfork activation**.

It covers:

- what a hardfork is in XGR Chain
- fork activation through chain configuration
- code-level fork registration
- genesis/config updates
- release and rollout process
- validator/operator coordination
- chain split risks
- rollback boundaries
- legacy Polygon Edge hardfork guidance that should not be copied blindly

This document does **not** define:

- PoS staking economics
- validator delegation rules
- XDaLa Engine endpoint behavior
- emergency genesis recovery
- rootchain/Supernet/PolyBFT upgrade flows

---

## 2. Hardfork definition

A hardfork is a protocol change that makes new node software follow different consensus or execution rules from old node software after a specific activation block.

In XGR Chain, a hardfork may change:

- EVM execution rules
- transaction validation rules
- header validation rules
- gas accounting
- fee accounting
- consensus hook behavior
- validator-set handling
- chain parameter behavior
- state transition rules

Any change that can make two nodes disagree about block validity is a hardfork-level change.

---

## 3. Fork activation model

XGR Chain uses a block-height-based fork activation model.

Forks are configured under:

```text
params.forks
```

In code, forks are represented in `chain/params.go`.

Core structures:

```go
type Forks map[string]Fork

type Fork struct {
    Block  uint64                  `json:"block"`
    Params *forkmanager.ForkParams `json:"params,omitempty"`
}

func (f Fork) Active(block uint64) bool {
    return block >= f.Block
}
```

A fork is active when:

```text
currentBlock >= fork.block
```

Fork activity is exposed through `ForksInTime`.

---

## 4. Current fork registry

Current known fork names include:

| Fork / feature | Purpose |
|---|---|
| `homestead` | Homestead EVM behavior |
| `byzantium` | Byzantium EVM behavior |
| `constantinople` | Constantinople EVM behavior |
| `petersburg` | Petersburg EVM behavior |
| `istanbul` | Istanbul EVM behavior |
| `london` | London / EIP-1559-style behavior |
| `EIP150` | EIP-150 gas semantics |
| `EIP155` | EIP-155 chain ID replay protection |
| `EIP158` | EIP-158 account clearing |
| `quorumcalcalignment` | quorum call alignment behavior |
| `txHashWithType` | typed transaction hash behavior |
| `londonfix` | London-related fix fork |
| `EIP3860` | initcode metering / limit |
| `EIP2929` | gas repricing for state access |
| `EIP2930` | access-list transaction support |
| `EIP3651` | warm `COINBASE` |
| `feePoolSplit` | XGR fee-pool split behavior |

The actual mainnet activation heights are defined in the mainnet genesis/configuration document.

See:

- `XGRCHAIN_Genesis_and_Configuration.md`
- `XGRCHAIN_Chain_Spec.md`

---

## 5. When a change needs a hardfork

Treat a change as hardfork-level if it affects any of the following:

| Area | Examples |
|---|---|
| Block validity | header fields, extra data, seal validation |
| Transaction validity | tx type acceptance, chain ID rules, gas rules |
| EVM execution | opcode semantics, gas schedule, precompile behavior |
| State transition | balance/state/storage/log/receipt changes |
| Consensus hooks | pre-commit, post-insert, epoch/finality behavior |
| Validator set | activation/deactivation, quorum, voting power |
| Fee accounting | burn, donation, fee pool, validator payout |
| RPC-generated transactions | if output affects consensus-critical txs |
| Genesis/config rules | fork schedule, consensus config, registry addresses |

Do not hide consensus-breaking behavior behind runtime flags. Fork activation must be deterministic for all nodes.

---

## 6. Code-level steps for a new fork

### 6.1 Define the fork name

Add a fork constant in the chain parameters module.

Example:

```go
const (
    MyNewFork = "myNewFork"
)
```

### 6.2 Add the fork to `ForksInTime`

```go
type ForksInTime struct {
    ...
    MyNewFork bool
}
```

### 6.3 Wire activation into `Forks.At`

```go
func (f *Forks) At(block uint64) ForksInTime {
    return ForksInTime{
        ...
        MyNewFork: f.IsActive(MyNewFork, block),
    }
}
```

### 6.4 Add optional fork params if required

Fork-specific parameters belong in `forkmanager.ForkParams` and must be deterministic.

Use pointer fields when distinguishing unset from zero is required.

Example pattern:

```go
type ForkParams struct {
    SomeLimit *uint64 `json:"someLimit,omitempty"`
}
```

### 6.5 Use the fork flag only in the relevant code path

Fork checks should be narrow and explicit.

Preferred pattern:

```go
forks := chainConfig.Params.Forks.At(header.Number)

if forks.MyNewFork {
    // new deterministic behavior
} else {
    // old deterministic behavior
}
```

Avoid broad wrapper functions that hide fork activation semantics unless they already exist as established infrastructure.

---

## 7. Genesis/config activation

A fork is activated by adding it to the fork configuration.

Example:

```json
{
  "params": {
    "forks": {
      "myNewFork": {
        "block": 1500000
      }
    }
  }
}
```

With parameters:

```json
{
  "params": {
    "forks": {
      "myNewFork": {
        "block": 1500000,
        "params": {
          "someLimit": 20
        }
      }
    }
  }
}
```

Activation block must be chosen carefully.

---

## 8. Activation block selection

A safe activation block should:

- be far enough in the future for all validators to upgrade
- allow RPC/explorer/indexer operators to update
- avoid known maintenance windows
- avoid activation during unstable network conditions
- be clearly announced
- be tested on dev/test networks first

For IBFT networks, a hardfork activation with mixed validator software can cause:

- proposal rejection
- missing quorum
- chain halt
- chain split
- inconsistent receipts/state
- explorer/indexer divergence

Do not schedule fork activation too close to release publication.

---

## 9. Release process

Recommended release checklist:

1. Implement fork code.
2. Add unit tests for pre-fork and post-fork behavior.
3. Add integration tests around activation boundary.
4. Add e2e tests if consensus/state behavior changes.
5. Update genesis/config examples.
6. Update documentation.
7. Build release binaries.
8. Publish checksums.
9. Announce activation block and required version.
10. Confirm validator/operator upgrade readiness.
11. Monitor activation.
12. Post-activation verify chain health.

Required release artifacts:

| Artifact | Purpose |
|---|---|
| binary | node executable |
| source tag/commit | auditable source |
| checksums | artifact verification |
| genesis/config diff | exact fork schedule |
| release notes | operator guidance |
| documentation update | public protocol clarity |

---

## 10. Validator rollout process

Validator operators should:

1. Back up current binary and configuration.
2. Back up validator key material.
3. Verify release checksum.
4. Stop node only when planned.
5. Replace binary.
6. Confirm genesis/config fork schedule.
7. Restart node.
8. Verify peer connectivity.
9. Verify block sync.
10. Verify validator participation.
11. Monitor logs around activation.

Suggested pre-activation checks:

```bash
./xgrchain version
./xgrchain server --help
```

RPC checks:

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

---

## 11. Config replacement rules

Operators must not casually replace the genesis file on an already running node.

There are two distinct cases.

### 11.1 Fork schedule already in original genesis/config

If the fork schedule was already part of the chain configuration accepted by all nodes, operators only need the new binary before the activation block.

### 11.2 Fork schedule added after network launch

If a new fork entry must be added to the chain configuration after launch, this must be treated as a coordinated network upgrade.

All participating nodes must use the exact same effective fork schedule before reaching the activation block.

Any mismatch can cause chain halt or chain split.

---

## 12. Chain split risks

A chain split can occur when nodes disagree on any consensus-critical rule.

Common causes:

| Cause | Example |
|---|---|
| Different fork block | node A activates at 1,500,000, node B at 1,600,000 |
| Missing fork code | old binary cannot validate new-rule blocks |
| Different fork params | same fork block but different parameter values |
| Non-deterministic logic | local time/env/config affects block validity |
| Partial validator rollout | some validators reject blocks accepted by others |
| RPC-generated consensus tx mismatch | generated tx differs between node versions |
| Hidden fallback | one node silently accepts data another rejects |

Avoid soft fallbacks in consensus-critical paths unless explicitly designed and documented.

---

## 13. Boundary testing

Every hardfork must test the activation boundary.

Minimum cases:

| Case | Expected behavior |
|---|---|
| block `forkBlock - 1` | old behavior |
| block `forkBlock` | new behavior active |
| block `forkBlock + 1` | new behavior remains active |
| missing fork config | deterministic old behavior or explicit startup failure |
| mismatched params | explicit failure or deterministic handling |
| replay on fresh node | same canonical chain |

For consensus or state changes, include:

- unit tests
- integration tests
- block import tests
- e2e activation tests
- replay/sync test from genesis across activation

---

## 14. Rollback boundaries

Before activation:

- rollback is usually possible by delaying or removing the planned activation from future configs, if all nodes coordinate.

After activation:

- rollback is a new hardfork unless the activated behavior has not produced divergent state.
- reverting binaries without reverting state/config can halt the chain.
- do not instruct operators to downgrade blindly after activation.

If activation caused invalid state divergence, treat it as an incident, not a normal rollback.

---

## 15. Monitoring during activation

Monitor:

- block production
- round changes
- peer count
- validator logs
- proposal errors
- block verification errors
- transaction execution errors
- receipt/log anomalies
- RPC errors
- explorer/indexer lag
- validator participation

Important symptoms:

| Symptom | Possible cause |
|---|---|
| no new blocks | validator quorum disagreement |
| repeated round changes | proposer blocks rejected / connectivity issue |
| block import errors | fork mismatch or invalid state transition |
| validators split by height | activation mismatch |
| explorers disagree | RPC/indexer on wrong version or fork |

---

## 16. Documentation requirements

Every network upgrade should update:

| Document | When relevant |
|---|---|
| `XGRCHAIN_Chain_Spec.md` | fork list, feature activation |
| `XGRCHAIN_Genesis_and_Configuration.md` | config/genesis fields, activation height |
| `XGRCHAIN_Consensus_IBFT.md` | consensus behavior change |
| `XRC-GAS_Gas_Price_Behavior.md` | gas/fee behavior change |
| `XGRCHAIN_Node_Operation.md` | operator command/process change |
| `XGRCHAIN_Staking_PoS_Model.md` | PoS/staking behavior change |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | RPC behavior change |

Do not leave old Polygon/Edge documents as the active upgrade guidance.

---

## 17. Example: adding a new execution fork

High-level example:

1. Add fork constant.
2. Add `ForksInTime` field.
3. Wire `Forks.At`.
4. Add behavior guarded by the fork flag.
5. Add genesis/config fork entry.
6. Add tests around the activation block.
7. Release binary.
8. Coordinate validator rollout.
9. Monitor activation.

Example config:

```json
{
  "params": {
    "forks": {
      "myExecutionFork": {
        "block": 1500000
      }
    }
  }
}
```

Code path:

```go
forks := config.Params.Forks.At(header.Number)

if forks.MyExecutionFork {
    return executeNewRules(...)
}

return executeOldRules(...)
```

---

## 18. Legacy Polygon Edge guidance not retained

The old Polygon Edge hardfork document used an example of adding `ExtraData` to an `Extra` struct and replacing the genesis file around block `100`.

That document is useful as a conceptual developer example, but it is not sufficient as XGR operator guidance.

Do not copy the following blindly:

- Edge-powered chain wording
- generic `ExtraData` example as if it were XGR policy
- casual genesis replacement instruction
- rootchain/Supernet-linked deployment references
- fork-manager parameter examples unrelated to current XGR forks

XGR upgrades must be release-managed and validator-coordinated.

---

## 19. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Chain_Spec.md` | chain-level fork and execution specification |
| `XGRCHAIN_Genesis_and_Configuration.md` | genesis/config fork schedule |
| `XGRCHAIN_Node_Operation.md` | operator runtime process |
| `XGRCHAIN_Consensus_IBFT.md` | consensus/finality behavior |
| `XGRCHAIN_Networking_P2P.md` | p2p and validator connectivity |
| `XGRCHAIN_Node_Operator_RPC_Reference.md` | diagnostic/operator RPC |
