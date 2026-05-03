# XGR Chain — Chain Specification

**Document ID:** XGRCHAIN-SPEC  
**Last updated:** 2026-05-03  
**Audience:** Protocol integrators, node operators, auditors  
**Implementation status:** Mainnet  
**Source of truth:** `xgrchain` / genesis configuration / consensus configuration

---

## 1. Scope

This document defines the **chain-level specification** for **XGR Chain** (`xgrchain`).

It covers:

- network identity
- EVM compatibility
- transaction model
- fork / execution configuration
- genesis-level parameters
- consensus-layer references
- fee-model references
- JSON-RPC compatibility
- boundaries between chain specification, XDaLa Engine specification and upcoming PoS/staking specification

This document does **not** describe:

- XDaLa Engine internals
- XRC-137 rule syntax
- XRC-729 orchestration semantics
- staking / delegation / weighted voting power
- PoS validator activation/deactivation rules
- Polygon Bridge / Rootchain / Childchain / PolyBFT mechanics

Those topics are documented separately where relevant.

---

## 2. Network identity

| Field | Value |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Native execution model | EVM-compatible |
| Standard RPC namespace | `eth_*`, `net_*`, `web3_*` |
| XDaLa Engine RPC namespace | `xgr_*` |
| Native token decimals | 18 |
| Transaction replay protection | EIP-155 chain ID |

### Normative behavior

Transactions **must** be signed with the configured chain ID.

```text
chainId = 1643
```

Nodes and clients must reject transactions whose signature chain ID does not match the active XGR Chain configuration.

---

## 3. Client basis and compatibility

XGR Chain uses an EVM-compatible client lineage based on Polygon Edge concepts and implementation structures, but the XGR public specification is defined by the actual XGR repositories and chain configuration.

XGR Chain supports:

- EVM smart contract execution
- Ethereum-style externally owned accounts
- contract creation
- event logs and receipts
- Ethereum-compatible transaction signing
- Ethereum-compatible JSON-RPC for common wallet/explorer operations
- legacy transactions
- EIP-1559 / type-2 transactions
- chain-specific `xgr_*` Engine extension endpoints

XGR Chain should not be described as a Polygon Supernet, PolyBFT chain, Rootchain/Childchain bridge network or CDK chain.

---

## 4. Execution model

XGR Chain executes transactions through an Ethereum-compatible EVM execution pipeline.

For each valid block:

1. transactions are selected and ordered by the proposer
2. each transaction is executed against the parent state
3. account balances, contract storage, logs and receipts are produced
4. gas usage and fee accounting are applied
5. the resulting state root is committed into the block header
6. validators independently verify the same state transition before committing the block

The proposer does not control state unilaterally. Validators must independently verify the block and its state transition before finalizing it through IBFT.

---

## 5. Transaction model

XGR Chain supports the standard Ethereum transaction model used by EVM-compatible wallets and tooling.

Supported transaction categories include:

| Transaction type | Support | Notes |
|---|---|---|
| Legacy transaction | Yes | Uses `gasPrice` |
| EIP-155 protected transaction | Yes | Chain ID replay protection |
| Access-list transaction | Yes, when corresponding fork is active | Berlin / EIP-2930 behavior |
| Dynamic fee / type-2 transaction | Yes | Uses `maxFeePerGas` and `maxPriorityFeePerGas` |
| Contract creation | Yes | Standard EVM contract deployment |
| Contract call | Yes | Standard EVM calldata execution |

The canonical public RPC documentation is:

- `XGRCHAIN_Ethereum_JSON_RPC_Reference.md`

---

## 6. Execution hardfork configuration

XGR Chain uses a staged fork activation model.

The following baseline EVM forks / features are enabled from **block 0**:

| Fork / feature | Activation |
|---|---|
| Homestead | block `0` |
| Byzantium | block `0` |
| Constantinople | block `0` |
| Petersburg | block `0` |
| Istanbul | block `0` |
| London | block `0` |
| LondonFix | block `0` |
| EIP-150 | block `0` |
| EIP-155 | block `0` |
| EIP-158 | block `0` |
| Quorum call alignment | block `0` |
| `txHashWithType` | block `0` |

Additional fork features are activated from **block `1208500`**:

| Fork / EIP | Purpose |
|---|---|
| EIP-2930 | Berlin access-list transactions |
| EIP-2929 | Berlin gas repricing for state access |
| EIP-3860 | Shanghai initcode metering / limit |
| EIP-3651 | Shanghai warm `COINBASE` |

Not active in the current public specification:

| Feature | Status |
|---|---|
| EIP-4895 withdrawals | Not active |
| Ethereum beacon withdrawals | Not part of XGR Chain execution model |
| Polygon Bridge / Rootchain state sync | Not part of current XGR Chain specification |
| PolyBFT bridge/checkpoint flow | Not part of current XGR Chain specification |

---

## 7. Consensus layer

XGR Chain uses **IBFT** as its deterministic-finality consensus protocol.

The detailed consensus document is:

- `XGRCHAIN_Consensus_IBFT.md`

This chain specification only defines the relationship between chain execution and consensus:

- the proposer builds a candidate block
- validators independently verify the block and state transition
- finality is reached through IBFT quorum
- committed blocks are final under IBFT fault assumptions

### Current validator model

The current mainnet consensus documentation is intentionally separated from the upcoming staking-based validator model.

| Component | Implementation status | Document |
|---|---|---|
| IBFT finality | Mainnet | `XGRCHAIN_Consensus_IBFT.md` |
| Current validator operation | Mainnet | `XGRCHAIN_Consensus_IBFT.md` |
| Staking / weighted voting power | In development | `XGRCHAIN_Staking_PoS_Model.md` |
| PoS monitoring endpoints | In development | `XGRCHAIN_Staking_PoS_Endpoint_Reference.md` |

This separation prevents the mainnet IBFT specification from being polluted with in-development staking rules.

---

## 8. Timing and block parameters

Current chain-level timing and block parameters:

| Parameter | Value |
|---|---|
| Target block time | ~2.0 seconds |
| `blockTime` | `2000000000` ns |
| Epoch size | 500 blocks |
| Genesis block gas limit | 60,000,000 |
| Genesis difficulty | `0x1` |
| Genesis parent hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis mix hash | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Genesis timestamp | `0x0` |

Operational estimate:

```text
500 blocks * 2 seconds ≈ 1000 seconds ≈ 16.7 minutes
```

This is the base chain epoch concept. PoS-specific micro/macro epoch semantics are documented separately.

---

## 9. Genesis block

XGR Chain starts from its own genesis block.

It does not inherit:

- Ethereum state
- Ethereum account balances
- Polygon state
- Polygon validator history
- Polygon bridge state

Genesis defines:

- chain ID
- block gas limit
- initial allocations
- bootnodes
- consensus parameters
- fork activation configuration
- protocol-level registry addresses where configured

### Genesis allocation semantics

Genesis `alloc` entries define pre-funded accounts in wei.

Balances must be interpreted with 18 decimals:

```text
1 native unit = 10^18 wei
```

Exact allocation values belong in the Genesis and Configuration document:

- `XGRCHAIN_Genesis_and_Configuration.md`

They should not be duplicated across multiple documents unless necessary for auditing.

---

## 10. Bootnodes and networking

Bootnodes are defined in chain configuration / genesis-level network configuration as libp2p multiaddresses.

Their purpose is peer discovery, not consensus authority.

A node may join the p2p network through bootnodes, but consensus participation still depends on validator-set rules and active consensus configuration.

Detailed node operation belongs in:

- `XGRCHAIN_Node_Operation.md`

---

## 11. Gas and fee model

XGR Chain supports EIP-1559-compatible transaction fields, but it does **not** use Ethereum mainnet fee economics one-to-one.

The canonical fee document is:

- `XRC-GAS_Gas_Price_Behavior.md`

Key high-level points:

| Topic | XGR behavior |
|---|---|
| Legacy fee field | `gasPrice` |
| Dynamic fee fields | `maxFeePerGas`, `maxPriorityFeePerGas` |
| Base fee | Chain-controlled / minimum-fee aware |
| Suggested priority fee | Currently zero in the node suggestion path |
| Fee distribution | XGR-specific burn / donation / validator or fee-pool split |
| Explorer display | Must not label the entire fee as burned |

For exact behavior, always use the dedicated gas document, not this chain spec.

---

## 12. On-chain configuration registry

XGR Chain can use on-chain configuration contracts to expose governance-controlled parameters.

The chain specification treats on-chain configuration as the verifiable source for protocol-relevant values where such contracts are active.

Relevant examples include:

- minimum base fee
- fee-policy parameters
- Engine-related configured addresses
- public sale / core address discovery where exposed

Detailed semantics belong in the specific documents for gas, Engine endpoints or genesis/configuration.

---

## 13. JSON-RPC surfaces

XGR Chain exposes two public RPC categories.

### 13.1 Standard Ethereum-compatible RPC

Used by wallets, explorers, scripts and infrastructure:

```text
eth_*
net_*
web3_*
```

Canonical document:

- `XGRCHAIN_Ethereum_JSON_RPC_Reference.md`

### 13.2 XDaLa Engine RPC

Used by validation/orchestration clients:

```text
xgr_*
```

Canonical document:

- `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md`

The standard Ethereum RPC and the XDaLa Engine RPC must not be mixed into a single ambiguous reference.

---

## 14. XDaLa and XRC standards

XGR Chain provides the settlement/execution layer used by XDaLa and XRC smart contracts.

XDaLa and XRC behavior is specified in separate documents:

| Document | Purpose |
|---|---|
| `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md` | Engine RPC interface |
| `XDaLa_Permit_Catalog.md` | EIP-712 permit types |
| `xgr_encryptionGrants.md` | Grant and encryption flows |
| `XRC-137_Rule_Document_Spec.md` | Rule document format |
| `XRC-137_Smart_Contract_Standard.md` | Rule contract standard |
| `XRC-729_Smart_Contract_Standard.md` | Orchestration contract standard |

The chain spec does not define XDaLa internals.

---

## 15. Explicit non-goals / removed legacy scopes

The following legacy Polygon Edge / Supernet concepts are not part of the current XGR Chain public chain specification:

| Legacy concept | Status in XGR Chain docs |
|---|---|
| Polygon Supernets product architecture | Not part of XGR specification |
| Polygon CDK positioning | Not part of XGR specification |
| Rootchain / childchain bridge docs | Not part of current XGR Chain docs |
| ERC20/ERC721/ERC1155 predicate bridge docs | Not part of current XGR Chain docs |
| State sender / state receiver bridge flow | Not part of current XGR Chain docs |
| Checkpoint manager bridge flow | Not part of current XGR Chain docs |
| PolyBFT bridge/checkpoint flow | Removed / not canonical |
| MATIC-specific staking docs | Not part of XGR Chain docs |

---

## 16. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Introduction.md` | High-level chain and architecture overview |
| `XGRCHAIN_Consensus_IBFT.md` | IBFT finality and consensus flow |
| `XGRCHAIN_Genesis_and_Configuration.md` | Genesis and runtime configuration |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Standard Ethereum-compatible RPC |
| `XRC-GAS_Gas_Price_Behavior.md` | Gas and fee behavior |
| `XGRCHAIN_Staking_PoS_Model.md` | Upcoming staking and weighted voting-power model |
| `XGRCHAIN_Staking_PoS_Endpoint_Reference.md` | Upcoming staking/PoS RPC reference |
