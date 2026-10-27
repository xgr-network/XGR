# Source map, reference coverage and verification

[Documentation index](README.md). This map organizes the two implementations by responsibility and ties their public behavior to the corresponding reference. It is a documentation review and reproducible surface inventory, not a new security audit or a certification that every code path was executed.

## 1. Exact source baselines

- Public node source: `418926f90f9b85af66f4ea4b0cc060dce6cdc862` on XGR3.0, with v3.4.0 execution code. Release tag `v3.4.0` points to `cbe6f8a4ae1718429a9924dcf87f0d28591d74e1`.
- Public Interchain source/deployment snapshot: `9518472c04432c57a5939a3688e90be332180636` on main. Contract suffixes and helper package versions are independent interface/tool versions.
- XGR and organization-profile READMEs link these references. MCP is a separately versioned client/service; this documentation update does not modify its implementation.
- Private development repositories are not an alternative source authority. Historical audit records are unchanged.

## 2. Module-to-document mapping

| Source module | Responsibilities | Detailed reference |
| --- | --- | --- |
| [xgr-interchain/contracts](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/contracts) | Protocol/identity, Factory/Registry, guarded routers, Gateway/FeeVault, transport, Direct-BLS ISM, membership/BLS, optional commercial adapter | [Contract_Reference](XGR_INTERCHAIN_Contract_Reference.md), [Contract_API](XGR_INTERCHAIN_Contract_API.md) |
| [xgr-interchain/runtime/native-relayer](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/runtime/native-relayer) | Original receipt/finality verification, canonical codecs, unsigned recovery, optional watcher/executor, gas planning | [v3.4.0_Operations](XGR_INTERCHAIN_v3.4.0_Operations.md), [Security_Model](XGR_INTERCHAIN_Security_Model.md) |
| [xgr-interchain/script](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/script) | Shared infrastructure deployment scripts and reviewed constructor/build inputs | [Deployment_Reference](XGR_INTERCHAIN_Deployment_Reference.md), [Services](XGR_INTERCHAIN_Services.md) |
| [xgr-interchain/config](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/config) | Approved application manifests: chains, assets/routes, publication and defaults; prospect does not mean active node support | [Asset_Bridge](XGR_INTERCHAIN_Asset_Bridge.md), [Deployment_Reference](XGR_INTERCHAIN_Deployment_Reference.md) |
| [xgr-interchain/deployments](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/deployments) | Append-only receipts, shared addresses, representations and directed Gateway/FeeVault records | [Deployment_Reference](XGR_INTERCHAIN_Deployment_Reference.md), [Contract_Reference](XGR_INTERCHAIN_Contract_Reference.md) |
| [xgr-interchain/services/admin](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/services/admin) | Main gate, chain/asset planners, artifact verification, wallet intents, journals, reconciliation, receipt auto-sync, operations health | [Services](XGR_INTERCHAIN_Services.md), [Deployment_Reference](XGR_INTERCHAIN_Deployment_Reference.md) |
| [xgr-interchain/services/indexer](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/services/indexer) | Canonical transfer index, reorg handling, discovery/intake, proof job leases, read proxy, TVL/flow/history/publication | [Services](XGR_INTERCHAIN_Services.md), [v3.4.0_Operations](XGR_INTERCHAIN_v3.4.0_Operations.md) |
| [xgr-interchain/services/managed-relay](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/services/managed-relay) | Commercial quote/tax evidence, price cache, immutable sponsor commitments, grant budgets/nonces/reconciliation, fee claims and optional executor | [Services](XGR_INTERCHAIN_Services.md), [Contract_Reference](XGR_INTERCHAIN_Contract_Reference.md) |
| [xgr-interchain/services/onboarding](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/services/onboarding) | Manifest proposals, live original-token identity checks, private confirmation storage, mail/publisher/status notifications | [Services](XGR_INTERCHAIN_Services.md), [Asset_Bridge](XGR_INTERCHAIN_Asset_Bridge.md) |
| [xgr-interchain/apps/web](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/apps/web) | Wallet selection, quotes/actions/nonces, original transfer discovery, recovery/worklists, catalog visibility, rankings and SPA rendering | [Services](XGR_INTERCHAIN_Services.md), [v3.4.0_Operations](XGR_INTERCHAIN_v3.4.0_Operations.md) |
| [xgr-interchain/tools](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/tools) | Manifest/catalog validation, bootstrap/receipt/route readiness tools, narrow reverse-proxy and installation generators | [Services](XGR_INTERCHAIN_Services.md), [Deployment_Reference](XGR_INTERCHAIN_Deployment_Reference.md) |
| [xgr-interchain/.github/workflows](https://github.com/xgr-network/xgr-interchain/tree/9518472c04432c57a5939a3688e90be332180636/.github/workflows) | Validation, contract tests/review, Join checks and BLS receipt workflows | [Source_Map](XGR_INTERCHAIN_Source_Map.md), [Deployment_Reference](XGR_INTERCHAIN_Deployment_Reference.md) |
| [xgr-node/interchain/config.go](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/interchain/config.go) | Compiled physical network identity, finality, Registry/RPC/operator pinning and one-active-Registry invariant | [Validator_Runtime](XGR_INTERCHAIN_Validator_Runtime.md), [Security_Model](XGR_INTERCHAIN_Security_Model.md) |
| [xgr-node/consensus/ibft/interchain](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/consensus/ibft/interchain) | Canonical Direct-BLS, identity, membership, fee payloads and aggregate quorum verification | [Security_Model](XGR_INTERCHAIN_Security_Model.md), [Contract_Reference](XGR_INTERCHAIN_Contract_Reference.md) |
| [xgr-node/interchain/runtime](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/interchain/runtime) | Lifecycle, source discovery/catalog/P2P, grouped scans, retries, signing, archive/quorum hints, source fee execution, storage and health | [Validator_Runtime](XGR_INTERCHAIN_Validator_Runtime.md), [RPC](XGR_INTERCHAIN_RPC.md) |
| [xgr-node/interchain/evm](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/interchain/evm) | Native/local and remote evidence, finality, independent witness agreement, route/fee/binding reads, BLS format, transaction submission and failover | [Security_Model](XGR_INTERCHAIN_Security_Model.md), [Validator_Runtime](XGR_INTERCHAIN_Validator_Runtime.md) |
| [xgr-node/interchain/verification](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/interchain/verification) | Verification helpers and their regression coverage | [Security_Model](XGR_INTERCHAIN_Security_Model.md), [Validator_Runtime](XGR_INTERCHAIN_Validator_Runtime.md) |
| [xgr-node/command/ibft/interchain](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/command/ibft/interchain) | Bootstrap proof, membership activation, source fee create/approve/execute, read-only storage diagnostics | [CLI](XGR_INTERCHAIN_CLI.md), [RPC](XGR_INTERCHAIN_RPC.md) |
| [xgr-node/jsonrpc](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/jsonrpc) | Actual RPC endpoint implementation, explicit-set archives, request/progress queues, validators, governance and schema-2 health | [RPC](XGR_INTERCHAIN_RPC.md), [Validator_Runtime](XGR_INTERCHAIN_Validator_Runtime.md) |
| [xgr-node/command](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/command) | Entire registered node CLI, server, secrets, consensus/staking, peers, txpool, backup/regenesis and diagnostics | [CLI](XGR_INTERCHAIN_CLI.md), [Source_Map](XGR_INTERCHAIN_Source_Map.md) |
| [xgr-node/consensus/ibft](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/consensus/ibft) | Native local chain read/submission integration and ordinary consensus; distinguish Interchain worker from weighted block consensus | [Validator_Runtime](XGR_INTERCHAIN_Validator_Runtime.md), [Source_Map](XGR_INTERCHAIN_Source_Map.md) |
| [xgr-node/state](https://github.com/xgr-network/xgr-node/tree/418926f90f9b85af66f4ea4b0cc060dce6cdc862/state) | Chain execution/accounting and state storage; v3.4.0 consensus gate and transaction-local SSTORE context are separate from message format | [Security_Model](XGR_INTERCHAIN_Security_Model.md), [Source_Map](XGR_INTERCHAIN_Source_Map.md) |

The ordinary node chain/consensus/storage/PoS/networking documentation retains its own scope in [the chain index](../INDEX.md). The [complete node CLI](../chain/XGRCHAIN_CLI_Reference.md) enumerates all registered commands and flags. This Interchain map does not replace the broader chain specification with bridge-only prose.

## 3. Generated interface and deployment coverage

- [Declared contract API](XGR_INTERCHAIN_Contract_API.md): every production top-level Solidity source, excluding test mocks; all named public/external functions, events and custom errors. Inherited ABI and generated getters are additional compiler output.
- [Node CLI](../chain/XGRCHAIN_CLI_Reference.md): 46 command/help entries obtained from a fresh build, including all application command families; command bodies were not run during help collection.
- [Interchain RPC](XGR_INTERCHAIN_RPC.md): all eight current Interchain method names, ordered parameters, result fields, progress states, explicit-set archive and errors. Compatibility reads are distinguished from active processing hints.
- [Deployment inventory](XGR_INTERCHAIN_Deployment_Reference.md): shared contracts on three supported chains, two canonical assets with three representations each, and eight directed route records. Sixty recorded component/representation/route references were checked against receipt identity/runtime-hash fields.
- [Independent runbook](XGR_INTERCHAIN_v3.4.0_Operations.md): source preparation, allowance, wallet submission, original receipt/finality, current-set unsigned recovery, destination submission and recipient/deferred-claim checks.

## 4. Reproduce the repository inventory

Run from each reviewed checkout. This includes tracked application source and configuration, while excluding vendored dependencies and immutable audit artifacts from the implementation inventory. It is a file inventory, not proof of line-by-line audit.

```sh
git rev-parse HEAD
rg --files -g '*.go' -g '*.sol' -g '*.mjs' -g '*.js' -g '*.sh' -g '*.json' -g '*.sql' -g '*.yml' -g '*.yaml' -g '!lib/**' -g '!vendor/**' -g '!node_modules/**' -g '!**/node_modules/**' -g '!audits/**' -g '!audit/**'
```

When adding a module or public method, update this map, its behavioral reference, CLI/RPC/ABI surface where applicable, examples and validation evidence. Do not update a release label while retaining incompatible old method/field descriptions.

## 5. Deterministic tests and their meaning

| Area | Existing test source / invocation | Evidence limit |
| --- | --- | --- |
| Canonical signing bytes, identity and quorum | node `consensus/ibft/interchain/*_test.go` | Vectors and negative cases; not a live quorum deployment |
| Independent evidence/finality/failover | node `interchain/evm/*_test.go` | Mock/native readers and inconsistent witness rejection; not proof of real endpoint availability |
| Grouped scans, retries and persistence | node `interchain/runtime/*_test.go` | Bounded windows, journal/restart logic and identity checks; not production catch-up timing |
| CLI/RPC | node `command/ibft/interchain`, `jsonrpc` tests; fresh CLI help | Parsing, storage/schema/error behavior; not wallet execution |
| Contract behavior | Interchain `test/`, configured Foundry workflow | Local contract invariants and simulations; not all deployed cross-chain transfers |
| Recovery codecs and receipts | `runtime/native-relayer/*.test.mjs` | Canonical metadata, original receipt/finality and gas calculations |
| Website/admin/indexer/services | component `*.test.mjs`, `*.test.js`, tools tests | Tested application policies/fixtures; no assumed production enablement |

Reproducible node invocation:

```sh
go test ./consensus/ibft/interchain ./command/ibft/interchain ./jsonrpc ./interchain/...
```

Reproducible helper checks after installing the package-declared dependencies:

```sh
cd runtime/native-relayer
npm install --ignore-scripts
npm test
```

The broader repository CI retains its configured contract, web, service and manifest checks. A documentation-only PR does not weaken or skip those gates. Live network transfer, full node sync across the consensus fork, real endpoint failover, three-validator restart/recovery and commercial service rollout require separately recorded chain/service evidence. None is inferred from a green documentation or unit check.

## 6. Known boundaries that must remain visible

- One active ValidatorRegistry per physical chain is an operating invariant; membership payloads retain the accepted cross-Registry replay limitation. Message ISM binding is not a fix for that separate domain.
- Node grouped observation retains per-route durable cursors. The old one-source-cursor acceptance target is not described as implemented.
- Pending attestation cache cleanup can occur after 30 days only when complete original evidence can be reverified for regeneration; source principal does not expire.
- The optional paid executor currently configures XGRChain/Base paid sources explicitly; public protocol/quote catalog coverage does not make that worker generic for every chain.
- Native successful message delivery can reserve a beneficiary claim when immediate payment fails; balances and claim state must be checked.
- Recorded deployments, implementation presence, server installation and live end-to-end readiness are different evidence levels.

## 7. Validation of this documentation correction

A fresh public-node build succeeded. The protocol, Interchain CLI, JSON-RPC and all `interchain/...` package tests passed. All 14 public native-recovery helper tests passed, including cross-language signing/metadata vectors and receipt/finality cases. The seven JavaScript runbook blocks passed syntax checking; they were not broadcast to live chains. Changed Markdown links and receipt-reference consistency were checked locally. Repository PR checks remain an additional merge gate.
