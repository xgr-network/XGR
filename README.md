# XGR Network

XGR Network develops XGRChain, an EVM-compatible Layer-1 blockchain focused on deterministic on-chain process execution rather than simple value transfer.

The core technology is XDaLa, a validation-to-execution engine that extends transactions into auditable multi-step workflows by combining on-chain rules, external data sources and smart contract execution.

XGR Network also provides native Interchain infrastructure for transferring XGR between XGRChain and supported external networks.

This repository contains the public specifications, standards and reference documentation for XGR Network.

---

## XGRChain

XGRChain is the EVM-compatible execution and settlement layer of the XGR ecosystem.

Current public chain baseline:

- **xgr-node:** `v3.1.1`
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

## Interchain

XGR Network maintains XGRChain-native Interchain infrastructure for cross-chain XGR transfers.

The first production XGR asset route connects:

- **XGRChain** — chain/domain `1643`
- **Base** — chain/domain `8453`

The route preserves native XGR on XGRChain and represents bridged XGR as wrapped XGR / wXGR on Base.

### XGRChain → Base

```text
native XGR
    │
    │ lock
    ▼
XGR native router
    │
    │ authenticated cross-chain message
    ▼
Base synthetic router
    │
    │ mint
    ▼
wXGR
```

### Base → XGRChain

```text
wXGR
    │
    │ burn
    ▼
Base synthetic router
    │
    │ authenticated cross-chain message
    ▼
XGR native router
    │
    │ unlock
    ▼
native XGR
```

Both directions are deployed and have been validated end-to-end on mainnet.

The public bidirectional bridge is available at:

https://bridge.xgr.network

The official Base wXGR contract is:

```text
0x3b83687d77170d42feddfe221629cc21e771e021
```

The nominal bridge representation is:

```text
1 XGR ↔ 1 wXGR
```

before applicable transaction and routing fees.

XGRChain provides native support for the Interchain security model, including native BLS12-381 verification through the execution precompile:

```text
0x0000000000000000000000000000000000002040
```

XGR Interchain uses:

- Hyperlane-compatible message transport,
- XGR-native validator attestations,
- BLS aggregate signatures,
- destination-specific validator registries,
- Merkle inclusion proofs,
- destination Interchain Security Modules,
- native relayers,
- explicit route and safety controls.

XGRChain consensus and XGR Interchain security are deliberately separate security domains:

```text
XGRChain consensus
≠
XGR Interchain validator quorum
```

The native Interchain worker is outside the weighted-IBFT consensus-critical path.

A remote-chain or relayer failure therefore does not become an XGRChain consensus dependency.

The relayer transports already authorized proof material and pays destination transaction gas.

It is not the trust anchor for transfer validity and cannot create a valid XGR Interchain BLS quorum by itself.

### Public Interchain documentation

The public specification set is maintained under:

```text
docs/interchain/
```

Start with:

- [`docs/interchain/XGR_INTERCHAIN_Overview.md`](docs/interchain/XGR_INTERCHAIN_Overview.md)
- [`docs/interchain/XGR_INTERCHAIN_Security_Model.md`](docs/interchain/XGR_INTERCHAIN_Security_Model.md)
- [`docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md`](docs/interchain/XGR_INTERCHAIN_Asset_Bridge.md)
- [`docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md`](docs/interchain/XGR_INTERCHAIN_Deployment_Reference.md)

These documents define:

- architecture and system boundaries,
- validator membership and quorum,
- BLS attestations,
- Merkle proof verification,
- relayer trust boundaries,
- native XGR and wXGR asset semantics,
- lock/mint and burn/unlock behavior,
- canonical production deployment identities.

Implementation, deployment manifests and operator tooling are maintained in:

https://github.com/xgr-network/xgr-hyperlane

Detailed implementation and operations documentation is maintained separately from the XGRChain node implementation.

Dynamic operational state such as route gates, pause controls, current validator membership, RPC health and relayer process state must be read from live deployment and runtime state.

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

The current Chain documentation targets `xgr-node v3.1.1` unless explicitly marked as historical.

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
xgr-network/xgr-hyperlane
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
- **Current public node release:** `v3.1.1`
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
xgr-node v3.1.1
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
- Public Bridge: https://bridge.xgr.network
- GitHub Organization: https://github.com/xgr-network

### Developer Entry Points

- Specs & Standards: https://github.com/xgr-network/XGR
- Node implementation: https://github.com/xgr-network/xgr-node
- Interchain implementation: https://github.com/xgr-network/xgr-hyperlane
- MCP implementation: https://github.com/xgr-network/xgr-mcp

### Network Tools

- Documentation Hub: https://xgr.network/docs
- XGR Bridge: https://bridge.xgr.network
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
