# XGR & XDaLa — Deterministic Process Execution on EVM-Compatible Infrastructure

**Document ID:** XGR-GENERAL-OVERVIEW  
**Last updated:** 2026-08-15  
**Audience:** Developers, integrators, partners, technical readers  
**Implementation status:** Mainnet / active development  
**Sources of truth:** `XGR`, `xgrEngine`, `xgr-node`

> **One-liner**
>
> **XGRChain** provides EVM-compatible execution. **XDaLa** adds a deterministic process engine that executes XRC-defined multi-step workflows, integrates external data and contract state, and produces auditable execution evidence.

---

## TL;DR

Smart contracts are powerful, but many real processes are not:

```text
one transaction → one contract → done
```

They are:

- multi-step,
- conditional,
- asynchronous,
- parallel,
- dependent on external data,
- dependent on other smart-contract state,
- subject to approvals and permissions,
- potentially privacy-sensitive,
- required to remain auditable.

Traditional architectures often implement those requirements with a combination of:

- smart contracts,
- backend services,
- databases,
- queues,
- schedulers,
- webhooks,
- bots.

XDaLa provides a process layer for these workflows while retaining EVM-compatible execution.

The core model is:

```text
XRC-137 = rule
XRC-729 = process graph
XDaLa   = process execution
XGRChain = blockchain execution and settlement
```

---

# 1. The problem XDaLa addresses

A blockchain transaction is an atomic state transition.

A business process is usually a graph.

Typical requirements include:

- valid and invalid business branches,
- waiting and resuming,
- external input,
- retries,
- parallel execution,
- deterministic joins,
- contract-state reads,
- HTTP API reads,
- controlled execution,
- selective data visibility,
- auditable process history.

Without a process layer, much of this orchestration normally lives outside the blockchain.

That creates a split between:

```text
on-chain execution
```

and:

```text
off-chain process logic
```

XDaLa provides an explicit execution model for that process logic.

---

# 2. What XDaLa is

XDaLa is a process engine integrated with XGRChain.

It executes workflows described through XRC standards.

A workflow can:

- validate typed input,
- read smart-contract state,
- obtain data from external APIs,
- evaluate expressions,
- choose deterministic business branches,
- execute smart-contract calls,
- spawn parallel branches,
- wait,
- resume,
- join process branches,
- carry payload data between steps,
- apply encryption and access policies,
- produce structured execution evidence.

The process definition is anchored in on-chain XRC contracts.

The XDaLa engine executes the process and maintains the runtime session state required for orchestration.

---

# 3. Important architecture boundary

XDaLa must not be described as if every part of a workflow were an EVM transaction or as if all process state were stored directly inside smart contracts.

The architecture separates responsibilities.

```text
XRC-137 / XRC-729 contracts
        │
        │ process definitions
        ▼
     XDaLa Engine
        │
        │ session execution
        │ external reads
        │ orchestration
        │ process state
        ▼
     XGRChain
        │
        │ EVM execution
        │ transactions
        │ contract state
        ▼
 execution evidence / Explorer
```

XRC contracts provide auditable on-chain definitions.

XDaLa provides the process runtime.

XGRChain provides EVM-compatible blockchain execution and settlement.

This separation is intentional.

---

# 4. Transaction versus session

## Traditional EVM model

```text
User
  ↓
Transaction
  ↓
Smart contract
  ↓
Result
```

## XDaLa model

```text
User / Agent / System
        ↓
   Session Start
        ↓
   XDaLa Session
        ↓
   Process Graph
   ├── Step
   ├── Branch
   ├── Spawn
   ├── Wait
   ├── Wake
   ├── Join
   └── Execution
        ↓
   XGRChain / external data / contract state
```

A session is a persistent process execution context.

A session can:

- execute immediately,
- enter a waiting state,
- resume later,
- create child processes,
- combine branch results,
- perform controlled EVM calls,
- terminate successfully or with an explicit process error.

A session is identified by its owner and session ID.

The pair:

```text
owner + sessionId
```

is the relevant session identity.

A `sessionId` must not be assumed to be globally unique by itself.

---

# 5. Core building blocks

## 5.1 XRC-137 — Rule document

An XRC-137 rule defines the behavior of one process step.

A rule can define:

- typed input fields through `payload`,
- smart-contract reads through `contractReads`,
- external HTTP calls through `apiCalls`,
- extracted typed values,
- validation expressions through `rules[]`,
- output payloads,
- valid and invalid branches,
- optional contract execution,
- grants and encryption behavior,
- optional waiting behavior.

Conceptually:

```text
input
  ↓
contract reads
  ↓
API calls
  ↓
rules
  ↓
valid / invalid
  ↓
output + optional execution
```

`onInvalid` is not automatically an engine failure.

It is a normal deterministic business branch.

For example:

```text
KYC valid
    ↓
onValid
```

and:

```text
KYC not valid
    ↓
onInvalid
```

are both valid process outcomes.

Hard engine errors, malformed rules and abort conditions are separate from business-level invalid results.

---

## 5.2 XRC-137 contract

The XRC-137 smart contract stores the rule definition on-chain.

The current contract stores:

- rule JSON or an encrypted XGR1 representation,
- contract owner,
- executor metadata,
- encryption metadata,
- rule hash,
- rule version,
- schema version.

Relevant current read surfaces include:

```text
getRule()
getNameXRC()
isEncrypted()
encrypted()
getRuleHash()
getRuleVersion()
getExecutorList()
isExecutor()
owner()
schemaVersion()
```

Rule updates are owner-controlled.

Current mutation paths include:

```text
updateRule(...)
setRuleAndEncrypted(...)
```

The XDaLa engine treats the deployed XRC-137 contract as the authoritative runtime source for that rule.

---

## 5.3 XRC-729 — Orchestration

XRC-729 defines the process graph.

An orchestration contains steps and their relationships.

It can define:

- entry steps,
- XRC-137 rule references,
- valid branches,
- invalid branches,
- spawns,
- joins,
- process transitions.

The orchestration is stored as JSON in an XRC-729 registry contract.

Conceptually:

```text
A
├── valid   → B
└── invalid → C
```

or:

```text
A
├── spawn → B
├── spawn → C
└──────────────┐
               ↓
              JOIN
               ↓
               D
```

---

## 5.4 XRC-729 contract

The current XRC-729 contract stores:

- OSTC JSON documents,
- OSTC IDs,
- OSTC hashes,
- OSTC versions,
- update timestamps,
- owner information,
- executor information,
- schema metadata.

The contract supports:

```text
getOSTC(...)
setOSTC(...)
deleteOSTC(...)
getAllOSTC()
hasOSTC(...)
getExecutorList()
isExecutor(...)
owner()
```

The contract additionally emits structured indexing events used by Explorer and MCP tooling.

The deployed XRC-729 contract is the authoritative runtime source for the orchestration.

---

## 5.5 XRC-563 — Encryption and grants

XDaLa supports protected rule and execution artifacts.

The privacy model uses:

- encryption,
- resource identifiers,
- read keys,
- grants,
- explicit access boundaries.

The objective is selective disclosure rather than making every process artifact globally readable.

Typical recipients may include:

- process participants,
- counterparties,
- auditors,
- regulated institutions,
- authorized reviewers.

Encryption and grants are covered separately in:

```text
xgr_encryptionGrants.md
```

---

# 6. XDaLa runtime semantics

## 6.1 Step execution pipeline

The current execution order is conceptually:

```text
1. Load and parse XRC-137
2. Validate rule structure and limits
3. Load typed payload
4. Apply declared defaults
5. Execute contractReads
6. Save typed contract-read values
7. Execute apiCalls
8. Extract typed API values
9. Evaluate rules
10. Select onValid or onInvalid
11. Build outcome payload
12. Resolve optional execution
13. Apply process/orchestration semantics
14. Persist session state and execution evidence
```

The ordering:

```text
contractReads → apiCalls
```

is significant.

Later expressions can consume values produced by earlier stages.

---

## 6.2 Expressions

XDaLa expressions can reference values through placeholders such as:

```text
[Amount]
[FetchedPrice]
[ContractBalance]
```

Expressions are evaluated using the XDaLa expression layer.

Rules in:

```text
rules[]
```

are combined as validation conditions.

Detailed expression syntax, types, limits and evaluation semantics are defined in:

```text
xgr_expression_evaluation_developer_guide.md
XRC-137_Rule_Document_Spec.md
XDaLa_Limits.md
```

---

## 6.3 Waiting

A branch may define:

```text
waitSec
```

A process can therefore enter a persistent waiting state.

Waiting is process semantics.

It does not mean that an EVM transaction continuously consumes gas while the process waits.

A waiting process may later continue through:

- its configured wake time,
- an explicitly authorized wake-up,
- internal process behavior.

---

## 6.4 Wake-up

Waiting processes may be explicitly woken through the XGR RPC layer.

The current engine supports signed control permits with actions:

```text
wake
kill
```

Control permit variants include:

```text
ControlPermit
ControlPermitV2
```

`ControlPermitV2` adds an explicit `runner` field for delegated control scenarios.

Wake-up authorization is enforced by the engine.

A wake request does not bypass the workflow's authorization rules.

The exact permit structures and authorization semantics are defined in:

```text
XDaLa_Permit_Catalog.md
XDaLa_XGR_Endpoint_Reference.md
```

---

## 6.5 Parallel execution

XRC-729 can spawn multiple branches.

Example:

```text
A
├── B
├── C
└── D
```

These processes can progress independently.

This allows workflows such as:

- parallel data acquisition,
- parallel approvals,
- multiple external confirmations,
- parallel risk checks,
- competing quotes.

---

## 6.6 Joins

Parallel branches can converge through deterministic joins.

Supported orchestration concepts include:

```text
any
all
kofn
```

Join behavior is explicitly defined in the OSTC.

Join processing includes deterministic:

- producer scoping,
- satisfaction checks,
- result merging,
- completion handling.

Late deliveries to a closed join do not reopen an already completed join.

A join that can no longer satisfy its required condition may terminate according to engine semantics rather than remain indefinitely unresolved.

---

# 7. Example XRC-137 rule

A minimal rule:

```json
{
  "payload": {
    "Amount": {
      "type": "int64"
    }
  },
  "rules": [
    "[Amount] > 0"
  ],
  "onValid": {
    "payload": {
      "result": "ok",
      "amount": "[Amount]"
    }
  },
  "onInvalid": {
    "payload": {
      "result": "invalid",
      "reason": "Amount must be > 0"
    }
  }
}
```

The rule declares:

```text
Amount
```

as a typed input.

The expression:

```text
[Amount] > 0
```

determines the business branch.

A positive value produces:

```text
onValid
```

otherwise:

```text
onInvalid
```

Defaults declared by the payload schema can make fields optional at runtime.

---

# 8. Adding contract reads

An XRC-137 step can read state from EVM contracts before evaluating its rules.

Conceptually:

```text
contractReads
    ↓
eth_call
    ↓
typed saved values
    ↓
rules / APIs / output
```

This allows rules to depend on:

- token balances,
- contract state,
- registry state,
- external EVM contract values,
- state on configured EVM-compatible chains.

Contract reads are read operations.

They do not by themselves mutate contract state.

---

# 9. Adding external APIs

An XRC-137 rule can obtain data from external HTTP APIs.

Conceptually:

```text
request
   ↓
external API
   ↓
response
   ↓
extractMap
   ↓
typed XDaLa values
```

This allows workflows to incorporate data such as:

- prices,
- external status information,
- identity or compliance results,
- logistics data,
- enterprise API data,
- market data.

External API data is external evidence.

The process logic can deterministically handle the values returned to the engine, but the external data source itself is outside blockchain consensus.

That distinction is important.

---

# 10. Optional smart-contract execution

An XRC-137 outcome may define an execution block.

This allows a validated process step to trigger an EVM contract call after its conditions have been evaluated.

Conceptually:

```text
payload
   ↓
reads
   ↓
API data
   ↓
validation
   ↓
valid branch
   ↓
EVM execution
```

This creates the core XDaLa loop:

```text
validate → decide → execute
```

rather than merely:

```text
execute transaction
```

---

# 11. End-to-end workflow

The normal lifecycle is:

```text
XRC-137 rule
      ↓
deploy XRC-137
      ↓
XRC-729 orchestration
      ↓
deploy / configure XRC-729
      ↓
Session Permit
      ↓
Session Start
      ↓
XDaLa execution
      ↓
wait / spawn / join / execute
      ↓
execution evidence
```

---

## 11.1 Create the XRC-137 rule

Write the rule JSON.

Validate it against:

- the current XRC-137 specification,
- hard limits,
- expression rules,
- authoring rules.

For agent-assisted authoring, the XGR MCP exposes canonical schemas and validators.

---

## 11.2 Deploy XRC-137

The current XRC-137 contract accepts the initial rule JSON through its constructor.

Conceptually:

```solidity
constructor(string memory _json)
```

A plaintext deployment initializes the contract with the rule JSON.

Later plaintext updates use:

```text
updateRule(...)
```

Encrypted rule updates use the encryption-aware path:

```text
setRuleAndEncrypted(...)
```

After deployment, verify the actual runtime contract using:

```text
getRule()
getRuleHash()
getRuleVersion()
isEncrypted()
```

Do not assume a locally stored copy still matches the deployed runtime.

---

## 11.3 Create the XRC-729 orchestration

Example single-step OSTC:

```json
{
  "id": "hello_xdala",
  "structure": {
    "S1": {
      "rule": "0x<your_XRC137_rule_contract_address>",
      "onValid": {},
      "onInvalid": {}
    }
  }
}
```

The current XRC-729 contract can receive initial OSTCs and executors during deployment or be populated later through:

```text
setOSTC(...)
```

The orchestration references deployed XRC-137 contracts.

---

## 11.4 OSTC hash

XRC-729 tracks a hash of each stored orchestration.

The hash is based on:

```text
keccak256(bytes(ostcJson))
```

Equivalent ethers v6 calculation:

```js
import { keccak256, toUtf8Bytes } from "ethers";

const ostcHash = keccak256(toUtf8Bytes(ostcJson));
```

The hash allows a Session Permit to bind execution to a specific orchestration representation.

---

## 11.5 Obtain session primitives

Before creating the Session Permit, clients can obtain the current chain configuration through:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "xgr_getCoreAddrs",
  "params": []
}
```

The next root session ID can be requested through:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "xgr_getNextProcessId",
  "params": [
    {
      "from": "0x<signer>"
    }
  ]
}
```

The returned value is used as the root `sessionId`.

---

## 11.6 Session Permit

Session Start uses an EIP-712 signed Session Permit.

Core permit data includes:

```text
from
ostcId
ostcHash
sessionId
maxTotalGas
expiry
```

The actual permit schema must follow:

```text
XDaLa_Permit_Catalog.md
```

The configured chain ID must match the connected XGRChain network.

The engine verifies the EIP-712 signature before accepting the request.

---

## 11.7 Session Start authority

The current engine does **not** enforce an owner-only Session Start model.

The signer must be authorized by the deployed XRC-729 contract.

Current authorization accepts:

```text
XRC-729 owner
```

or:

```text
authorized XRC-729 executor
```

where supported by the deployed contract.

This allows controlled delegated execution without giving executors permission to modify the orchestration itself.

Contract mutation and process execution authority are separate concerns.

---

## 11.8 Start the session

The main XDaLa RPC entry point is:

```text
xgr_validateDataTransfer
```

Example:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "xgr_validateDataTransfer",
  "params": [
    {
      "stepId": "S1",
      "payload": {
        "Amount": 42
      },
      "permit": {
        "...": "signed SessionPermit"
      },
      "orchestration": "0x<your_XRC729_contract_address>"
    }
  ]
}
```

Before the session is enqueued, the engine performs preflight checks including:

- permit verification,
- orchestration address validation,
- start authority,
- expected session ID,
- OSTC hash format,
- orchestration loading,
- XRC-729 hard-limit validation.

A failed preflight does not create a valid running session.

---

## 11.9 Wake a waiting process

A waiting process can be explicitly resumed through:

```text
xgr_wakeUpProcess
```

Example PID-targeted request:

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "xgr_wakeUpProcess",
  "params": [
    {
      "processId": "123:2",
      "payload": {
        "X": 1
      },
      "permit": {
        "...": "signed ControlPermit with action='wake'"
      }
    }
  ]
}
```

The engine currently supports two wake targeting modes:

```text
specific processId
```

or:

```text
signed permit.message.stepId
```

The two modes are intentionally distinct.

Wake-up authorization is verified before waiting process state is changed.

---

# 12. Parallel spawn and join example

Example process:

```text
A1
├── G1
└── H1
     ↓
    J1
```

Illustrative OSTC:

```json
{
  "id": "parallel_demo",
  "structure": {
    "A1": {
      "rule": "0x<addr_A1>",
      "onValid": {
        "spawns": [
          "G1",
          "H1"
        ],
        "join": {
          "joinid": "J1",
          "mode": "any",
          "waitonjoin": "kill",
          "from": [
            {
              "node": "G1",
              "when": "valid"
            },
            {
              "node": "H1",
              "when": "valid"
            }
          ]
        }
      }
    },
    "G1": {
      "rule": "0x<addr_G1>"
    },
    "H1": {
      "rule": "0x<addr_H1>"
    },
    "J1": {
      "rule": "0x<addr_J1>"
    }
  }
}
```

The join consumes results belonging to its defined producer scope.

Unrelated branch deliveries must not be mixed into that join.

---

# 13. Typical use cases

XDaLa is designed for workflows where execution depends on more than one isolated transaction.

Examples include:

## Payments and settlement

```text
input
  ↓
validation
  ↓
external information
  ↓
approvals
  ↓
execution
```

ISO 20022-style structured payment flows are one possible application.

ISO 20022 is not the architectural core of XDaLa.

---

## Compliance workflows

Examples:

- KYC/KYB process steps,
- sanctions or policy checks,
- approval chains,
- regulatory evidence,
- controlled execution after successful checks.

---

## Financial processes

Examples:

- RFQ workflows,
- pricing checks,
- risk limits,
- parallel quotes,
- multi-party approvals,
- settlement triggers.

---

## Enterprise workflows

Examples:

- departmental approvals,
- controlled contract execution,
- notarial processes,
- evidence-driven workflows,
- multi-stage automation.

---

## Supply-chain processes

Examples:

- parallel confirmations,
- external API evidence,
- delivery state,
- staged releases,
- k-of-n approval conditions.

---

# 14. Privacy model

Public blockchain execution and confidential business information have different requirements.

XDaLa therefore supports encrypted process artifacts and controlled access.

The objective is:

```text
verifiable process execution
+
controlled data visibility
```

rather than:

```text
all process data must be public
```

Sensitive process content does not need to be exposed as plaintext merely because a workflow interacts with a blockchain.

The detailed encryption and grant model is defined separately.

---

# 15. Auditability

XDaLa separates several evidence layers:

```text
deployed XRC definitions
```

```text
XDaLa session state and receipts
```

```text
XGRChain transactions and contract state
```

```text
Explorer-indexed execution evidence
```

This allows an auditor or agent to distinguish:

- what process was defined,
- which rule version was deployed,
- which orchestration version was used,
- what transaction occurred,
- which session executed,
- which process branch was selected,
- which external or contract-derived values influenced execution.

External evidence remains external evidence.

A blockchain cannot make an external HTTP source inherently trustworthy.

XDaLa instead makes its use inside the process explicit and auditable.

---

# 16. XGR MCP

The XGR MCP Gateway provides the agent-native interface to the XGR ecosystem.

Public endpoints:

```text
Mainnet:
https://mcp.xgr.network/mcp

Testnet:
https://mcp.testnet.xgr.network/mcp
```

Through MCP, compatible agents can:

- inspect XGRChain state,
- inspect transactions,
- inspect XDaLa sessions,
- inspect XRC contracts,
- inspect process graphs,
- inspect historical execution evidence,
- inspect native XGR address relations and value flow,
- retrieve XRC schemas and authoring rules,
- validate XDaLa artifacts,
- prepare deployment handoffs,
- prepare Session Start handoffs,
- use optional XGR purchase services,
- use optional Starter Gas.

MCP does not replace XDaLa.

It is an access and tooling layer over the XGR/XDaLa infrastructure.

Detailed MCP behavior is documented under:

```text
docs/mcp/
```

---

# 17. Network identifiers

Current XGR network chain IDs are:

| Network | Chain ID |
|---|---:|
| XGRChain Mainnet | `1643` |
| XGRChain Testnet | `1879` |
| XGRChain Devnet | `1887` |

Mainnet uses IBFT deterministic finality.

Validator participation transitioned from the initial PoA phase to delegated PoS at:

```text
block 5,446,500
```

The chain-level documentation and published Mainnet genesis are authoritative for:

- consensus configuration,
- fork activation,
- validator configuration,
- PoS parameters,
- bootnodes,
- gas configuration,
- protocol addresses.

Do not use this general overview as the canonical chain configuration source.

See:

```text
docs/chain/
genesis/mainnet/genesis.json
```

---

# 18. Separation of gas models

XDaLa uses concepts that must not be confused.

## EVM gas

Pays for blockchain transaction execution.

## ValidationGas

Models XDaLa validation and processing work.

ValidationGas is not EVM gas.

It covers operations such as:

- payload processing,
- expressions,
- contract reads,
- API processing,
- outcome construction,
- execution preparation.

The detailed cost model is defined in:

```text
XRC-137_Validation_Gas.md
```

---

# 19. Security model

The system separates:

```text
process definition authority
process execution authority
wallet signing authority
data access authority
```

These are not interchangeable.

For example:

- an XRC-729 executor may be allowed to start a process without being allowed to modify the orchestration,
- a wallet may have sufficient XGR for gas but no workflow authority,
- an address may have workflow authority but insufficient XGR,
- a user may receive access to encrypted evidence without receiving ownership of the underlying XRC contract.

This separation is fundamental to the XDaLa security model.

---

# 20. Recommended developer path

For a new integration:

```text
1. Understand XRC-137
2. Understand XRC-729
3. Create a simple rule
4. Validate the rule
5. Deploy XRC-137
6. Create the orchestration
7. Validate the process graph
8. Deploy XRC-729
9. Read the deployed runtime back
10. Resolve Session Start authority
11. Obtain the next session ID
12. Sign the Session Permit
13. Start the XDaLa session
14. Inspect session and receipt evidence
15. Add APIs, reads, waits, joins and execution only as required
```

For agent-based integrations, use the XGR MCP knowledge and validation tools before preparing deployment or Session Start handoffs.

---

# 21. Where to go next

## XRC-137

```text
XRC-137_Rule_Document_Spec.md
XRC-137_Smart_Contract_Standard.md
XRC-137_Validation_Gas.md
```

## XRC-729

```text
XRC-729_Smart_Contract_Standard.md
xrc_729_orchestration_session_manager.md
```

## XDaLa

```text
XDaLa_XGR_Endpoint_Reference.md
XDaLa_Permit_Catalog.md
XDaLa_Limits.md
XDaLa_Agent_Authoring_Rules.md
xgr_expression_evaluation_developer_guide.md
```

## Encryption and grants

```text
xgr_encryptionGrants.md
```

## XGRChain

```text
docs/chain/
```

## XGR MCP

```text
docs/mcp/
```

---

# 22. Core repositories

Public specifications and contracts:

```text
https://github.com/xgr-network/XGR
```

XGRChain node:

```text
https://github.com/xgr-network/xgr-node
```

XDaLa engine:

```text
https://github.com/xgr-network/xgrEngine
```

XGR MCP:

```text
https://github.com/xgr-network/xgr-mcp
```

---

If Ethereum introduced programmable value, XDaLa extends the model toward programmable processes:

```text
define
→ validate
→ orchestrate
→ execute
→ verify
```
