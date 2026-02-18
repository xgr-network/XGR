# XGR Network

XGR Network develops XGRChain, an EVM compatible blockchain focused on deterministic on chain process execution rather than simple value transfer.

The core technology is XDaLa, a validation to execution engine that extends transactions into auditable multi step workflows by combining on chain rules, external data sources and smart contract execution.

This repository contains public specifications, standards and reference material for XGR Network.

---

## What is XDaLa

XDaLa is a process layer that operates across three stages:

1. Validation  
   Structured rules validate transaction intent, parameters and external conditions.

2. Orchestration  
   Multi step execution paths are defined using permits, limits and triggers.

3. Execution  
   Smart contracts are executed only after successful validation, producing verifiable and auditable outcomes.

XDaLa is designed for use cases that require deterministic behavior, regulatory constraints or controlled execution flows.

---

## Repository Contents

### Specifications

This repository provides public documentation and specifications for XDaLa and related components.

- General overview of the XDaLa process model  
- Endpoint and validation reference  
- Permit and limit definitions  
- Encryption and grant handling  

The current documents include:

- XDaLa general overview  
- XDaLa endpoint reference  
- XDaLa limits specification  
- XDaLa permit catalog  
- XGR encryption and grant model  

All specifications are evolving and subject to versioning.

---

## Privacy and Security Model

XDaLa is privacy first by design.

- Payloads and outputs can be end to end encrypted  
- Decryption remains on the user side using wallet based keys  
- No plaintext sensitive data is required to be stored on chain  
- Validation and execution are separated from data visibility  

This enables auditable processes without compromising data sovereignty.

---

## Intended Audience

This repository is intended for:

- Developers building on EVM compatible blockchains  
- Infrastructure and protocol engineers  
- Teams working on regulated or compliance sensitive workflows  
- Auditors and reviewers evaluating deterministic execution models  

---

## Project Status

- XGRChain: Testnet and mainnet preparation  
- XDaLa: Active specification and implementation phase  
- Standards: Draft and review status  

The repository reflects the public and stable interface of the system.

---

## Contributing

This repository focuses on specifications and reference material.

- Issues may be opened for clarification or discussion  
- Pull requests should be limited to documentation improvements or corrections  

Implementation specific code is maintained in separate internal repositories.

---

## Security

If you discover a potential security issue, please report it responsibly.

Contact: security@xgr.network

---

## Official Links

These are the canonical entry points for the public ecosystem. If you are unsure where to start, begin with the Website and the specs in this repository.

- Website: https://xgr.network
- GitHub Organization: https://github.com/xgr-network

### Developer Entry Points

- Specs & Standards (this repo): https://github.com/xgr-network/XGR
- Node Implementation (xgr-node): https://github.com/xgr-network/xgr-node

### Network Tools

- Documentation Hub: https://xgr.network/docs
- Testnet Faucet: https://faucet.xgr.network
- Explorer: https://explorer.xgr.network

---

## Chain Configuration

Reference chain configuration artifacts live in this repository under `genesis/`.

- **Mainnet genesis:** `genesis/mainnet/genesis.json`

If you are running a local/dev network, prefer generating a fresh genesis via the CLI tooling
rather than hand-editing production genesis files.

## License

Unless stated otherwise, all documentation in this repository is licensed under the Apache License 2.0.
