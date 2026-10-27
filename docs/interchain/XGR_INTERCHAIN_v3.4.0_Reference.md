# XGR Interchain v3.4.0 technical reference

Baseline: public `xgr-node v3.4.0` and the public `xgr-interchain` Direct-BLS implementation. Contract suffixes such as V315 and registry version 3 describe contract interfaces; they are not node release numbers.

This documentation separates the protocol, the validator implementation and optional applications. Start with the architecture, then follow the reference for the component you operate. A transfer user does not need validator secrets, the XITA website or a managed relay account.

| Document | Contents |
| --- | --- |
| [Architecture](XGR_INTERCHAIN_Overview.md) | Components, multiple assets/routes, hub topology, authorization and transaction flow |
| [Security and wire format](XGR_INTERCHAIN_Security_Model.md) | Exact signing bytes, metadata, receipt verification, current sets, replay and trust boundaries |
| [Assets and permissionless registration](XGR_INTERCHAIN_Asset_Bridge.md) | Asset/route identity, Factory procedures, reciprocal bindings, supply, escrow and native claims |
| [Contract and fee reference](XGR_INTERCHAIN_Contract_Reference.md) | Public calls, results, events, error handling, source fee governance and FeeVault claims |
| [Independent transfer runbook](XGR_INTERCHAIN_v3.4.0_Operations.md) | Quote, approval, wallet dispatch, original receipt, quorum, unsigned recovery, delivery and two-hop transfer |
| [Validator runtime](XGR_INTERCHAIN_Validator_Runtime.md) | Discovery, grouped observation, evidence witnesses, signing/P2P, durable state, cleanup and monitoring |
| [CLI reference](XGR_INTERCHAIN_CLI.md) | Every Interchain subcommand, flags/defaults, output, examples and failure semantics |
| [JSON-RPC reference](XGR_INTERCHAIN_RPC.md) | Every Interchain RPC, request/response fields, progress states and errors |
| [Optional applications and services](XGR_INTERCHAIN_Services.md) | Website, indexer, read proxy, intake, quote, sponsor and onboarding APIs; operating boundaries |
| [Deployment inventory](XGR_INTERCHAIN_Deployment_Reference.md) | Recorded shared contracts and asset representations; receipts, activation heights and route verification |
| [Source map and validation](XGR_INTERCHAIN_Source_Map.md) | Repository/module ownership, reproducible source inventory, test coverage and evidence limits |
| [Release/consensus activation](../chain/XGRCHAIN_v3.4.0_Release_and_Activation.md) | Binary verification and `securityAccounting`; separate from Interchain deployments |

## Operational entry points

- Sending or recovering a transfer: independent transfer runbook, then RPC and security reference.
- Running a validator: validator runtime, CLI, RPC and node release instructions.
- Registering another asset/router pair: assets, contract reference and deployment evidence.
- Running an independent executor: runbook and native-relayer configuration in the services reference.
- Operating XITA: services, deployment inventory and source map. Its listing policy is separate from protocol admission.

The older versioned Interchain URLs redirect readers to these current references. Dated audit evidence remains historical evidence. Source review describes implemented behavior; live transfer completion and network availability require actual chain evidence.
