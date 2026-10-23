# XGR Network

**Complete Interchain reference:** [XGR Interchain architecture, smart contracts, protocol/fees, governance, CLI, RPC and production operations](docs/interchain/XGR_INTERCHAIN_v3.2.3_Reference.md). `xgr-hyperlane` is retired; the current implementation is `xgr-interchain` and the validator runtime is `xgr-node v3.2.3`.

XGR Network develops XGRChain, an EVM-compatible Layer-1 blockchain focused on deterministic on-chain process execution rather than simple value transfer.

The core technology is XDaLa, a validation-to-execution engine that extends transactions into auditable multi-step workflows by combining on-chain rules, external data sources and smart contract execution.

XGR Network also provides native Interchain infrastructure for transferring XGR between XGRChain and supported external networks.

This repository contains the public specifications, standards and reference documentation for XGR Network.

---

## XGRChain

XGRChain is the EVM-compatible execution and settlement layer of the XGR ecosystem.

Current public chain baseline:

- **xgr-node:** `v3.2.3`
- **Chain ID:** `1643`
- **Native asset:** XGR
- **Mainnet:** live
- **Testnet:** available
- **Execution environment:** EVM compatible
- **Finality protocol:** IBFT
- **Validator model:** delegated PoS with stake- and uptime-weighted voting power
- **Mainnet RPC:** `https://rpc.xgr.network`

The public node implementation is maintained in:

https://github.com/xgr-network/xgr-node

The documentation under `docs/chain/` is maintained against the current public XGRChain node baseline unless a document explicitly describes a historical release.

Documentation index:

https://github.com/xgr-network/XGR/blob/main/docs/INDEX.md

---

## What is XDaLa

XDaLa is a process layer that operates across three stages:

1. **Validation**  
   Structured rules validate transaction intent, parameters and external conditions.

2. **Orchestration**  
   Multi-step execution paths are defined using permits, limits and triggers.

3. **Execution**  
   Smart contracts are executed only after successful validation, producing verifiable and auditable outcomes.

XDaLa is designed for use cases that require deterministic behavior, regulatory constraints or controlled execution flows.

XDaLa is deployed on XGRChain mainnet.

---

## XGR Interchain / XITA

The current XGR Interchain protocol joins supported EVM networks through **XGRChain (1643)**. Base (8453) and Arbitrum (42161) have individually configured deployment infrastructure. Transfers between spokes traverse **two wallet-authorized hops** through XGRChain. There is no direct spoke-to-spoke shortcut.

- **Code and deployments:** [xgr-interchain](https://github.com/xgr-network/xgr-interchain), the current repository. The predecessor `xgr-hyperlane` has been retired.
- **Node/validator runtime:** [xgr-node v3.2.3](https://github.com/xgr-network/xgr-node/releases/tag/v3.2.3).
- **Protocol reference:** [current architecture, routes, token models, validation, security, contracts and operations](docs/interchain/XGR_INTERCHAIN_v3.2.3_Reference.md).
- **Validator operations:** [CLI, RPC, full Merkle replica, quorum and health reference](https://github.com/xgr-network/xgr-node/blob/XGR3.0/docs/ILN_V323_OPERATOR_REFERENCE.md).
- **Relayer and independent delivery:** [complete audited relayer/proof observer and recovery manual](docs/interchain/XGR_INTERCHAIN_Relayer_Reference.md).
- **Direct noncommercial transfers:** [user-signed ILNGateway and destination Mailbox calls without XITA fee adapter or managed relayer](docs/interchain/XGR_INTERCHAIN_v3.2.3_Operations.md).

Each source ILNGateway collects the native protocol validator fee, invokes an asset-specific guarded router (native collateral / ERC-20 collateral / synthetic), allocates the fee to a per-route FeeVault and dispatches a canonical Mailbox message. Validators independently reconstruct the confirmed Merkle root and message inclusion, validate source fee allocation and aggregate 2/3 BLS signatures. The destination ISM authorizes the original message; any gas-paying executor may submit `Mailbox.process`. The optional commercial XITAExecutionGateway and gas sponsor are separate from protocol validity.

**Do not use obsolete deployment addresses from the v3.1.1 bridge documentation.** Current chain and token routers and route receipts live under [xgr-interchain deployments](https://github.com/xgr-network/xgr-interchain/tree/main/deployments). The XGR asset representation on Base is recorded in `deployments/assets/a7/XGR/representations.json`; verify live bytecode and registry before funding.

XITA's website is [xita.xgr.network](https://xita.xgr.network). Website availability is not evidence of a completed or safe source/destination transaction. Native gas, wallet authorizations, current on-chain route bindings and validator quorum must all be checked independently.

---

## AI and MCP Access

The XGR MCP Gateway is the AI-native access layer to the XGR stack.

It exposes XGRChain data, XDaLa sessions, Explorer evidence, XRC standards, schemas and authoring knowledge as semantic Model Context Protocol tools.

MCP-compatible agents can:

- inspect deployed workflows,
- search chain and session evidence,
- inspect bounded native-XGR address relation graphs,
- progressively expand address relations,
- trace indexed transaction relationships,
- model native XGR value provenance,
- inspect the transactions behind a graph relation,
- inspect historical XDaLa Session Start payload values,
- draft and validate XDaLa process bundles,
- prepare human-in-the-loop handoffs for local wallet signing,
- discover live XGR purchase options,
- create mainnet XGR purchase reservations for an exact XGR amount or a maximum USDC/USDT budget,
- request a fixed native-XGR starter-gas grant for an eligible low-balance address where the service is enabled.

The optional purchase tools are mainnet services with deployment-controlled availability.

A purchase tool may create a real off-chain order and reserve XGR inventory. The purchase workflow does not hold payment private keys and does not send USDC or USDT. Payment remains an external wallet action based on the exact structured payment instruction returned by the tool.

The optional starter-gas service is a deliberately narrow exception to the gateway's normal no-signing model. It may use one dedicated server-controlled service wallet solely to send fixed native XGR starter-gas grants.

The gateway never requests, receives, stores or controls user or third-party private keys and cannot sign on behalf of users.

User deployment, Session Start and contract-call transactions remain under the control of the user's wallet, signer or custody setup.

- Mainnet MCP: https://mcp.xgr.network/mcp
- Testnet MCP: https://mcp.testnet.xgr.network/mcp
- MCP documentation: https://xgr.network/docs/mcp_overview/

---

## Repository Contents

### Documentation Index

The complete public documentation index is maintained at:

```text
docs/INDEX.md
```

It provides the entry points for:

- XGRChain,
- XDaLa,
- XRC standards,
- MCP,
- XGR Interchain,
- UI documentation.

### XGRChain

The `docs/chain/` section contains the public technical documentation for XGRChain, including:

- chain architecture and specification,
- IBFT consensus,
- delegated PoS validator and staking behavior,
- genesis and chain configuration,
- node operation,
- peer-to-peer networking,
- state storage and retention,
- Ethereum-compatible JSON-RPC,
- XGR-specific operator RPC methods,
- gas-price and fee behavior,
- access-control boundaries,
- network upgrades and hardfork procedures.

The current Chain documentation targets `xgr-node v3.2.3` unless explicitly marked as historical.

### XGR Interchain

The `docs/interchain/` section contains the public technical specification for XGR Interchain, including:

- architecture overview,
- security model,
- validator and quorum boundaries,
- BLS verification,
- native XGR and wXGR asset behavior,
- lock/mint and burn/unlock semantics,
- canonical mainnet deployment references.

Implementation-specific deployment and operator material remains in:

```text
xgr-network/xgr-interchain
```

### XDaLa Specifications

This repository provides public documentation and specifications for XDaLa and related components.

The current documents include:

- XDaLa general overview,
- XDaLa endpoint reference,
- XDaLa limits specification,
- XDaLa permit catalog,
- XGR encryption and grant model,
- XRC-137 rule and smart-contract specifications,
- XRC-729 orchestration specification,
- XGR MCP Gateway reference.

### User Interface and Operations

The repository also contains reference documentation for XGR development and operations interfaces, including:

- Builder137,
- Builder729,
- XDaLa session management,
- rule-executor management,
- testing and validation workflows.

Specifications and interfaces may evolve independently and are subject to their respective versioning.

---

## Privacy and Security Model

XDaLa is designed to support privacy-preserving execution.

- Payloads and outputs can be end-to-end encrypted.
- Decryption can remain on the user side using wallet-based keys.
- Plaintext sensitive data does not need to be stored on-chain.
- Validation and execution can be separated from data visibility.

This enables auditable processes while preserving data-sovereignty boundaries.

XGR Interchain uses a separate security model based on:

- authenticated cross-chain messages,
- destination-specific XGR Interchain validator sets,
- BLS quorum attestations,
- Merkle inclusion proofs,
- destination-side security modules,
- explicit asset locking, minting, burning and unlocking.

The relayer is not the trust anchor for message validity.

XGRChain consensus authority, XDaLa permissions, MCP service authority and XGR Interchain authority are separate security domains.

---

## Intended Audience

This repository is intended for:

- developers building on EVM-compatible blockchains,
- node and validator operators,
- infrastructure and protocol engineers,
- teams working on regulated or compliance-sensitive workflows,
- agent builders integrating the XGR MCP Gateway,
- Interchain integrators,
- wallet and exchange integrators,
- auditors and reviewers evaluating deterministic execution and cross-chain security models.

---

## Project Status

- **XGRChain:** Mainnet
- **Current public node release:** `v3.2.3`
- **Consensus:** Mainnet — IBFT finality with delegated PoS validator participation
- **State Growth Control:** Mainnet — Online State Trie Sweeper available for configurable historical-state retention and reclamation of unreachable trie/code data
- **XDaLa:** Mainnet
- **MCP Gateway:** Mainnet
- **MCP chain, transaction, session, XRC, evidence, validation, diagram and handoff tools:** Mainnet
- **MCP native-XGR relation graph and value-flow tools:** Mainnet
- **MCP XDaLa start-payload history tools:** Mainnet
- **Mainnet XGR purchase tools:** Mainnet
- **Native XGR starter-gas service:** Mainnet
- **XGR Interchain:** Mainnet — XGRChain ↔ Base bidirectional bridge deployed, validated and publicly available
- **wXGR on Base:** Mainnet
- **XRC standards:** Mainnet specifications for deployed XGR functionality

The repository reflects the public and stable mainnet interfaces of the XGR ecosystem.

---

## Versioning

XGR components use independent but coordinated versioning.

The current XGRChain documentation baseline is:

```text
xgr-node v3.2.3
```

This version applies to the public node and the Chain documentation describing that node baseline.

XDaLa, XRC standards, MCP services, user interfaces and Interchain infrastructure may evolve independently and therefore retain their own specification, interface or deployment versioning where required.

A new `xgr-node` release does not automatically imply:

- a new mainnet genesis,
- a hardfork,
- a new Interchain deployment,
- a new XDaLa version,
- a new XRC specification version.

Likewise, an Interchain deployment or runtime update does not automatically imply a new XGRChain node release.

---

## Contributing

This repository focuses on specifications and reference material.

- Issues may be opened for clarification or discussion.
- Pull requests should be limited to documentation improvements or corrections.

Implementation-specific code is maintained in separate repositories.

---

## Security

If you discover a potential security issue, please report it responsibly.

Contact:

```text
security@xgr.network
```

Do not publish:

- wallet or validator private keys,
- seed phrases,
- keystore passwords,
- production credentials,
- private RPC credentials,
- Interchain validator signing credentials,
- relayer signing credentials,
- internal infrastructure secrets.

---

## Official Links

These are the canonical entry points for the public ecosystem.

- Website: https://xgr.network
- Public Bridge: https://xita.xgr.network
- GitHub Organization: https://github.com/xgr-network

### Developer Entry Points

- Specs & Standards: https://github.com/xgr-network/XGR
- Node implementation: https://github.com/xgr-network/xgr-node
- Interchain implementation: https://github.com/xgr-network/xgr-interchain
- MCP implementation: https://github.com/xgr-network/xgr-mcp

### Network Tools

- Documentation Hub: https://xgr.network/docs
- XGR Bridge: https://xita.xgr.network
- Testnet Faucet: https://faucet.xgr.network
- Explorer: https://explorer.xgr.network

### MCP

- MCP Gateway Mainnet: https://mcp.xgr.network/mcp
- MCP Gateway Testnet: https://mcp.testnet.xgr.network/mcp
- MCP Overview: https://xgr.network/docs/mcp_overview/
- MCP Tool Reference: https://xgr.network/docs/mcp_tools/

---

## Chain Configuration

Reference chain-configuration artifacts live in this repository under `genesis/`.

- **Mainnet genesis:** `genesis/mainnet/genesis.json`

For local or development networks, prefer generating a fresh genesis through the node CLI tooling rather than manually modifying production genesis files.

---

## License

Unless stated otherwise, all documentation in this repository is licensed under the Apache License 2.0.
