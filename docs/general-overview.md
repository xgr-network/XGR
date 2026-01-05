# XGR & XDaLa — The Missing Layer for Deterministic On-Chain Processes

> **One-liner**  
> **XGR** is a fully EVM-compatible chain. **XDaLa** is its differentiator: a deterministic rule- and process-layer that turns multi-step workflows into first-class, auditable on-chain **sessions**.

---

## TL;DR (Why you should care)

Smart contracts are powerful — but most real workflows are **not** “one transaction and done”. They are:

- multi-step  
- conditional  
- asynchronous (waiting/retries)  
- parallel (multiple branches)  
- dependent on external signals (APIs, other chains)  
- privacy & access controlled (auditors, counterparties, regulators)

On typical chains, teams stitch this together with off-chain schedulers, queues, webhooks, databases, and bots. That works — but the “truth” becomes split across systems, operations get brittle, and auditability becomes partial.

**XDaLa collapses this complexity into deterministic, on-chain process semantics — without breaking EVM compatibility.**

---

## 1) The core problem: chains stop where real processes begin

A transaction is an atomic state transition.  
A business process is a **graph**:

- branching (valid/invalid business paths)  
- retries with time (wait, resume)  
- parallel work streams (spawn)  
- joins (any / all / k-of-n)  
- external reads (contract reads + HTTP APIs)  
- selective visibility of rules and logs  

Today, the orchestration graph typically lives off-chain. That creates:

- hidden process state  
- race conditions  
- implicit logic that cannot be reproduced independently  
- fractured audit trails  

**The chain sees fragments. The real process lives elsewhere.**

---

## 2) What XDaLa introduces (in one sentence)

**XDaLa is a deterministic process engine on top of a standard EVM chain — so workflows can be described, executed, joined, and audited as on-chain sessions.**

Think less “call a contract”, more:

> **advance a process**

---

## 3) Mental model: Transaction vs Session

### Traditional EVM
`User → tx → contract → result`

### With XDaLa
`User → session → process tree → deterministic outcomes (+ optional inner EVM calls)`

A **session** is a living execution context that can:

- run now  
- **wait** deterministically (`waitSec`)  
- spawn parallel branches  
- join results deterministically  
- keep artifacts private via explicit grants/encryption  

---

## 4) The three building blocks (XRCs)

### 4.1 XRC-137 — Rule (one deterministic step)

An **XRC-137 rule document** defines a single step:

- typed input schema (`payload`)  
- optional **contractReads** (EVM `eth_call` reads)  
- optional **apiCalls** (HTTP → extracted typed values)  
- validation rules (`rules[]`)  
- two deterministic outcomes:
  - `onValid`
  - `onInvalid`

**Key shift:**  
`onInvalid` is *not failure*. It is your **alternative business branch**.  
Failure/abort/cancel are separate and explicit.

---

### 4.2 XRC-729 — Orchestration (the process graph)

An orchestration is a graph of steps with explicit runtime semantics:

- **spawns** (parallelism)  
- **joins** with modes: `any`, `all`, `kofn`  
- join policies: `waitonjoin = kill | drain`  
- deterministic merge of producer payloads  

The orchestration is stored **on-chain** in an XRC-729 contract, enabling independent reproduction and audit of the process topology.

---

### 4.3 XRC-563 — Grants & privacy (per artifact)

XDaLa treats rules and logs as **protected artifacts**:

- each artifact has a **RID** (resource identifier)  
- grants are issued **per RID** and **per scope** (`rule` / `log`)  
- encryption is granular (not “all or nothing”)  

This makes selective disclosure (counterparties, auditors, regulators) a first-class protocol concept.

---

## 5) Runtime semantics (what actually happens)

### 5.1 Step execution pipeline (XRC-137)

Each step run follows a deterministic pipeline:

1. parse + validate schema  
2. load typed payload + apply defaults  
3. execute API calls and extract typed values (with defaults)  
4. execute contract reads and save typed outputs (with defaults)  
5. evaluate rules (AND)  
6. choose `onValid` or `onInvalid`  
7. compute outcome payload + optional execution (inner ABI call)  
8. apply grants / retention / encryption policy  
9. apply optional wait (`waitSec`) and finish  

### 5.2 Time semantics (`waitSec`)

Waiting is native:

- a process can park itself deterministically (`wakeAt = now + waitSec`)  
- no off-chain scheduling glue is required  
- waiting is not “EVM gas burning”; it is process semantics  

### 5.3 Parallelism + joins are protocol-level

Spawns and joins are not “best effort”; they are defined semantics:

- deliveries are scoped (join groups)  
- join satisfaction is deterministic (any/all/k-of-n)  
- merge order is deterministic  
- late deliveries after join close are ignored  
- joins can become unfulfillable and abort cleanly  

---

## 6) Where this shines (use-case intuition)

XDaLa is strongest wherever you currently build “off-chain orchestration glue”:

- **Payments / settlement (ISO-style structured flows):** validate, enrich, encrypt, join approvals, then execute.  
- **Trading / RFQ / risk:** run quotes in parallel, join best-of, enforce limits, deterministic retries.  
- **Supply chain:** parallel confirmations, join k-of-n, staged releases with private logs.  
- **Enterprise automation:** long approvals, staged execution, auditable trails — without a workflow engine off-chain.  

The expected builder reaction:

> “This is the missing layer between smart contracts and real processes.”

---

## 7) How you use XDaLa (concrete end-to-end flow)

This section is intentionally explicit: **XRC-137 JSON → deploy XRC-137.sol → XRC-729 orchestration → start session via RPC with permit**.

### 7.1 Write an XRC-137 rule JSON (the step definition)

**Minimal “hello step”:**

```json
{
  "payload": {
    "Amount": { "type": "int64" }
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

Notes:

- `payload` declares typed inputs. Defaults make inputs optional.  
- `rules` are boolean expressions (AND).  
- `onValid` / `onInvalid` are business outcomes.  
- You can extend later with `apiCalls`, `contractReads`, `execution`, `grants`, `encryptLogs`, `waitSec`.  

---

### 7.2 Deploy an XRC-137 contract and upload the JSON into it

XRC-137 the contract is an on-chain **container** for one rule JSON (or encrypted XGR1 blob) plus metadata.

**Canonical interface (from the standard):**

```solidity
interface IXRC137 {
  function getRule() external view returns (string memory);
  function setRule(string calldata jsonOrXgr1, bytes32 rid, string calldata suite) external;
  function isEncrypted() external view returns (bool);
  function getEncrypted() external view returns (bytes32 rid, string memory suite);
}
```

**Deploy flow (high level):**

1. Deploy your XRC-137 contract instance (the “rule container”).  
2. Call `setRule(ruleJson, 0x00..00, "")` to store plain JSON  
   - `rid = 0x00..00` and `suite = ""` indicates **not encrypted**.  
3. Verify by calling `getRule()`.  

**Practical tip:** If your JSON is large, upload via tooling (Foundry/Hardhat/ethers) rather than raw CLI to avoid escaping issues.

---

### 7.3 Create an XRC-729 orchestration (the process graph)

An orchestration (“OSTC”) is JSON stored in an XRC-729 registry.

**Minimal single-step orchestration:**

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

Store it under an ID in your XRC-729 contract (the standard recommends `setOSTC(id, json)`).

**Why the hash matters:** sessions can pin the orchestration by `ostcHash` for auditability and determinism.

---

### 7.4 Compute `ostcHash` (Keccak-256 of the UTF-8 JSON)

Your client computes:

- `ostcHash = keccak256(bytes(ostcJsonUtf8))`

Example (ethers v6 shape):

```js
import { keccak256, toUtf8Bytes } from "ethers";

const ostcHash = keccak256(toUtf8Bytes(ostcJson));
```

---

### 7.5 Fetch chain/session primitives via RPC

Before signing permits, fetch:

1) **Core addrs + chainId**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "xgr_getCoreAddrs",
  "params": []
}
```

2) **Next root session id**

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "xgr_getNextProcessId",
  "params": [
    { "from": "0x<your_eoa>" }
  ]
}
```

Use the returned id as `sessionId` (root pid) in your SessionPermit.

---

### 7.6 Sign a SessionPermit (EIP-712 typed data)

A **SessionPermit** authorizes starting/continuing a session under a specific orchestration.

Core fields (conceptually):

- `from` (EOA signer)  
- `ostcId`  
- `ostcHash`  
- `sessionId`  
- `maxTotalGas`  
- `expiry`  

**Authority rule (high level):** the engine enforces that the signer matches the on-chain **owner of the orchestration registry** (XRC-729 owner), so session execution authority is explicit and auditable.

**Typed data (shape):**

```json
{
  "domain": {
    "name": "XDaLa SessionPermit",
    "version": "1",
    "chainId": 1879
  },
  "primaryType": "SessionPermit",
  "types": {
    "EIP712Domain": [
      { "name": "name", "type": "string" },
      { "name": "version", "type": "string" },
      { "name": "chainId", "type": "uint256" }
    ],
    "SessionPermit": [
      { "name": "from", "type": "address" },
      { "name": "ostcId", "type": "string" },
      { "name": "ostcHash", "type": "bytes32" },
      { "name": "sessionId", "type": "uint256" },
      { "name": "maxTotalGas", "type": "uint256" },
      { "name": "expiry", "type": "uint256" }
    ]
  },
  "message": {
    "from": "0x<your_eoa>",
    "ostcId": "hello_xdala",
    "ostcHash": "0x<keccak256>",
    "sessionId": "1",
    "maxTotalGas": "5000000",
    "expiry": 1760000000
  }
}
```

You typically sign this via `eth_signTypedData_v4` in your wallet.

---

### 7.7 Start/advance the session via `xgr_validateDataTransfer`

This is the main entry point: you submit a step execution request for a session.

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "xgr_validateDataTransfer",
  "params": [
    {
      "stepId": "S1",
      "payload": { "Amount": 42 },
      "permit": { "...": "SessionPermit object including signature" },
      "orchestration": "0x<your_XRC729_contract_address>"
    }
  ]
}
```

Typical response shape:

- which process ran  
- `finalResult` (valid/invalid at rule level)  
- executed step receipts  
- sanitized payload (defaults applied)  
- `outputPayload` (branch payload)  

From here, the orchestration determines what gets spawned next, what waits, what joins, etc.

---

### 7.8 Wake waiting processes (optional, when your flow requires it)

If a process is waiting (e.g., it parked itself via `waitSec` or is waiting for external input), clients can explicitly wake it via the wake endpoint using a signed control permit.

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "xgr_wakeUpProcess",
  "params": [
    {
      "processId": "123:2",
      "payload": { "X": 1 },
      "permit": { "...": "ControlPermit(action='wake') object including signature" }
    }
  ]
}
```

---

## 8) A slightly more “real” example (parallel spawn + join)

**Orchestration idea:**

- Step `A1` spawns `G1` and `H1` in parallel  
- Join `J1` proceeds once **any** producer is valid  

Illustrative snippet:

```json
{
  "id": "parallel_demo",
  "structure": {
    "A1": {
      "rule": "0x<addr_A1>",
      "onValid": {
        "spawns": ["G1", "H1"],
        "join": {
          "joinid": "J1",
          "mode": "any",
          "waitonjoin": "kill",
          "from": [
            { "node": "G1", "when": "valid" },
            { "node": "H1", "when": "valid" }
          ]
        }
      }
    },
    "G1": { "rule": "0x<addr_G1>" },
    "H1": { "rule": "0x<addr_H1>" },
    "J1": { "rule": "0x<addr_J1>" }
  }
}
```

Key property: join scoping ensures `J1` only consumes deliveries from the correct producer group (no accidental cross-branch mixing).

---

## 9) Testnet chain parameters (based on your sample genesis)

If you are targeting your current testnet genesis snapshot:

- `chainId = 1879`  
- IBFT PoA with `validator_type = bls`  
- major forks enabled from genesis (e.g., London at block 0)  
- engine registry address configured (`engineRegistryAddress` present)  

This is useful for wallets and EIP-712 domain `chainId`, and for aligning expectations around finality and RPC compatibility.

---

## 10) Where to go next

- **XRC-137 Rule Documents** — schema, contract reads, API calls, branch semantics  
- **Expressions** — templates vs CEL evaluation, defaults, soft-invalid vs hard errors  
- **XRC-729 Orchestration** — spawn/join semantics, scoping, delivery/merge rules  
- **XRC-563 Grants** — RID/scope, encryption, lifecycle  
- **Validation Gas** — deterministic budgeting separate from EVM gas  
- **JSON-RPC Extensions** — session lifecycle, permits, control endpoints  

If Ethereum was about *programmable value*,  
**XDaLa is about programmable processes.**
