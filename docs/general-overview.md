# XGR & XDaLa — The Missing Layer for Deterministic On-Chain Processes

> **One-liner**  
> **XGR** is a fully EVM-compatible chain. **XDaLa** is its differentiator: a deterministic process layer that turns multi-step workflows into first-class, auditable on-chain sessions.

---

## TL;DR (Why you should care)

Smart contracts are powerful — but most real-world flows are **not** single-call problems. They are **multi-step**, **asynchronous**, sometimes **parallel**, often **time-dependent**, and they frequently depend on **external signals** or **selective privacy**.

Today, teams glue this together with off-chain schedulers, queues, databases, keepers, and custom services. That works — but it’s fragile, hard to audit end-to-end, and the “truth” is split across systems.

**XDaLa collapses this complexity into a deterministic, on-chain process model — without breaking EVM compatibility.**

---

## 1) The core problem: chains stop where real processes begin

A transaction is an atomic state transition.  
A business process is a **graph**:

- conditional branching
- retries and waiting
- parallel work streams
- joins (quorum, best-of, all-of)
- external reads (on-chain + off-chain)
- selective visibility and compliance constraints

On typical chains, that “process graph” is implemented *outside* the chain. You get:
- off-chain state machines
- implicit orchestration logic
- race conditions
- partial auditability
- brittle ops

**The blockchain sees fragments. The real process lives elsewhere.**

---

## 2) What XDaLa introduces (in one sentence)

**XDaLa is a deterministic process engine on top of a standard EVM chain — so workflows can be described, executed, paused, resumed, joined, and audited as on-chain sessions.**

Think less “call a contract”, more:

> **advance a process**

---

## 3) The mental model: Transaction vs Session

### Traditional EVM
`User → tx → contract → result`

### With XDaLa
`User → session → process tree → deterministic outcomes (+ optional inner EVM calls)`

A **session** is a living execution context that can:
- run now
- **wait** and continue later (`waitSec`) without new orchestration glue
- **spawn** parallel branches
- **join** results deterministically (any / all / k-of-n)
- incorporate external data (contract reads + HTTP APIs)
- keep artifacts private through explicit grants/encryption

---

## 4) The three building blocks (XRCs)

### 4.1 XRC-137 — Rule (one deterministic step)
An **XRC-137 rule** defines *one step* of a process:

- input schema (typed)
- optional **contractReads** (EVM reads)
- optional **apiCalls** (HTTP → extracted typed values)
- boolean validation rules (expressions)
- two explicit outcomes:
  - `onValid`
  - `onInvalid`

**Key shift:**  
`onInvalid` is *not failure*. It is your **alternative business branch**.

Failures are separate and explicit (e.g., abort/cancel semantics and hard engine errors).

---

### 4.2 XRC-729 — Orchestration (the process graph)
An **orchestration** is a directed graph of step IDs:

- spawns: run steps in parallel
- joins: synchronize on outcomes (`any`, `all`, `k-of-n`)
- wait policies on joins (`kill` or `drain`)
- deterministic merging of producer payloads

Orchestration is **on-chain, auditable, reproducible**.

No hidden scheduler logic. No implicit control flow.

---

### 4.3 XRC-563 — Grants & privacy (per artifact)
XDaLa treats rules and logs as **artifacts** with explicit access control:

- every artifact has a **RID** (resource identifier)
- grants are issued **per RID** and **per scope** (`rule` / `log`)
- encryption is **granular**, not global
- selective disclosure becomes a first-class protocol concept (e.g., “auditor can read logs, not rules”, or vice versa)

---

## 5) Runtime semantics: what actually happens

### 5.1 Instance-based execution (sessions)
Each `(owner, rootPid)` produces a process tree that is executed asynchronously by the session manager:

- promote runnable processes (wake-time reached, dispatch gates ok)
- evaluate exactly one XRC-137 step per run
- pick `onValid` / `onInvalid`
- optionally execute an inner ABI call (normal EVM call)
- emit receipts + log artifacts (optionally encrypted)
- spawn next processes and manage joins

### 5.2 Time becomes native (`waitSec`)
A step outcome can set `waitSec`:
- the process is parked deterministically
- it resumes later without cron jobs, keepers, or bespoke retry logic
- waiting costs no EVM execution gas (only state/log semantics)

### 5.3 Determinism is enforced (not hoped for)
XDaLa’s design assumes adversarial conditions and enforces deterministic boundaries:
- bounded expression complexity (hard caps)
- deterministic evaluation behavior (soft-invalid vs hard error)
- deterministic cost model (“Validation Gas”) separate from EVM gas

Result: processes remain explainable, billable, and auditable.

---

## 6) Where this shines (use-case intuition)

XDaLa is strongest wherever you currently need “off-chain orchestration glue”:

- **Payments & settlement (e.g., ISO-style structured flows)**  
  validate, enrich, encrypt artifacts, join approvals, then execute transfers.

- **Trading / RFQ / risk**  
  run quotes in parallel, join best-of, enforce limits, retry with deterministic waits.

- **Logistics / supply chain**  
  parallel track providers, join k-of-n confirmations, release assets once conditions are met.

- **Enterprise automation**  
  approvals, staged execution, auditable trails — without building a workflow engine off-chain.

The recurring reaction you want from builders is:
> “This is the missing layer between smart contracts and real processes.”

---

## 7) How to start (builder path)

1. **Write a single XRC-137 rule**
   - define 2–5 inputs
   - one or two validation expressions
   - simple `onValid` / `onInvalid` payload outputs

2. **Run it standalone**
   - observe outcome payloads
   - inspect receipts/log artifacts

3. **Add a second step via XRC-729**
   - spawn it from `onValid` (or `onInvalid`)
   - optionally add `waitSec` for retry

4. **Add privacy**
   - enable encryption on logs
   - issue grants for a concrete RID/scope

At that point you’ve already replaced:
- a scheduler
- a queue consumer
- a small workflow service
- and part of your audit log stack

---

## 8) XGR chain foundations (EVM-first, XDaLa additive)

XGR is designed to be **100% EVM-compatible**:
- standard transaction formats
- standard tooling expectations
- JSON-RPC compatibility, plus a small documented XDaLa extension surface

**Testnet example snapshot (genesis-derived):**
- `chainId: 1879`
- IBFT-style PoA finality with a fixed block time (e.g., `blockTime: 2s` in the sample)
- major EVM forks enabled from genesis (e.g., London at block 0 in the sample)
- high block gas limit (e.g., `0x3938700` in the sample)

These parameters can evolve across networks, but the principle stays stable:
> **EVM stays standard. XDaLa adds deterministic process semantics on top.**

---

## 9) The bigger picture

Ethereum made **code** executable on-chain.  
XDaLa makes **processes** executable on-chain.

Not scripts. Not cron jobs. Not keepers. Not glue services.

**Processes.**

---

## Where to go next

- **XRC-137 Rule Documents** — schema, API calls, contract reads, branches, execution
- **Expressions & Templates** — evaluation, determinism, defaults, soft-invalid behavior
- **XRC-729 Orchestration** — spawns, joins, scopes, delivery/merge rules
- **XRC-563 Grants** — encryption, RID/scope, access lifecycle
- **Validation Gas** — deterministic budgeting separate from EVM gas
- **JSON-RPC Extensions** — session lifecycle + permits
- **JSON-RPC Extensions** — session lifecycle + permits