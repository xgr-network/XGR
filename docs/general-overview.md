# XGR Chain & XDaLa — Overview (corrected, enterprise tone)

> **Purpose**  
> Provide an executive yet technically accurate introduction to **XGR** (the EVM chain) and **XDaLa** (the rule‑ and process‑layer). This document explains *why* you use it, the *core specs* (XRC‑137 / XRC‑729 / XRC‑563), how the runtime behaves (sessions, wakes, joins), and links to deeper guides.

---

## 0) Why XDaLa (business value & when to use it)

Complex processes are rarely a single transaction. They are **multi‑step**, sometimes **parallel**, depend on **external data**, and carry **privacy & compliance** requirements. On typical chains, teams glue this together with keepers, crons, queues, webhooks, and private databases — fragile to operate and hard to audit.

**XDaLa** adds a **deterministic process layer** on a standard EVM chain so you can describe, run, and audit business flows end‑to‑end:

- **Deterministic orchestration** of parallel/conditional steps with **joins (any/all/k‑of‑n)** and **time** via `waitSec`.
- **Asynchronous, instance‑based sessions** (one process tree per session) with deterministic wake scheduling and back‑pressure.
- **External data inputs** (contract reads + HTTP APIs) merged into a single input map for rules.
- **Governed privacy** with per‑artifact encryption and grants (XRC‑563).
- **Budgetable validation** (structural Validation Gas) separate from EVM gas.
- **100% EVM‑compatible** — no custom tx types; wallets and SDKs continue to work.

**Where it shines (illustrative use cases):**  
- **ISO 20022 settlement**: Validate structured payment data off‑chain; encrypt rule & logs; orchestrate FX, AML, and settlement legs with joins; execute on‑chain transfers only when all pre‑conditions are valid.  
- **Trading process**: Order checks → risk limits → venue selection (parallel quotes) → join on best quote → execute; retries via `waitSec`, no external schedulers.  
- **Logistics workflow**: Shipment creation → parallel track & trace providers → join on k‑of‑n confirmations → customs clearance → release; sensitive logs encrypted per recipient.

> **Figure 1 placeholder** — *“XDaLa at a glance”*: Session payload → **XRC‑137** rule (reads/APIs → expressions → outcomes `onValid`/`onInvalid` with `payload`/`waitSec`/optional `execution`) → **XRC‑729** orchestration (spawn/join policy) → receipts/logs (**XRC‑563** grants).

---

## 1) The specs at a glance (JSON as the contract)

- **XRC‑137 — Rule (one step, canonical JSON):** Declares inputs, optional **contractReads** and **apiCalls**, **validate expressions**, and two outcome branches **`onValid`**/**`onInvalid`** with `payload` mapping, **`waitSec`**, optional `execution`, and logging policy. **`onInvalid` is *not* failure**; it is the **alternate path** when the validate expressions evaluate to false. *Failure handling is separate* (see §3.4).  
  _Deep dive: `docs/xDaLa/xrc_137_spec.md`_

- **XRC‑729 — Orchestration (graph, canonical JSON):** Declares the step graph (IDs), branch‑specific **spawns**, optional **joins** with mode **any/all/k‑of‑n**, and a **waitOnJoin** policy (`kill` or `drain`). Targets deterministically **merge** producer payloads.  
  _Deep dive: `docs/xDaLa/xrc_729_orchestration_session_manager.md`_

- **XRC‑563 — Grants (encryption & access, per‑artifact):** Each **rule (XRC‑137)** and each **log bundle** is an individual **artifact** with its **own RID (Resource Identifier)**. Grants are issued **per RID** *and* **by scope** (scope ∈ {`rule`, `log`}). Decryption requires that both **RID** *and* **scope** match; this governs who can read a specific rule or a specific log bundle.  
  _Deep dive: `docs/xDaLa/xgr_encryptionGrants.md`_

> **Why JSON?** Human‑readable, diff‑able artifacts support code review, CI/CD, and version pinning by hash. Both XRC‑137 and XRC‑729 are designed to be business‑legible and machine‑consumable.

---

## 2) Runtime model (sessions, wakes, joins)

### 2.1 Session Manager (instance‑based, asynchronous)
Every `(owner, rootPid)` runs as its **own process tree**:
- **Promote** processes when **wake time** is reached and dispatch rules allow it.
- **Evaluate** the referenced **XRC‑137** exactly once per run: merge inputs (session payload + reads + APIs), compute `isValid`, then select **`onValid`** **or** **`onInvalid`**.
- **Spawn** producer steps according to the chosen branch; **deliver** producer results into a per‑target **Join Inbox**; **close** joins when **any/all/k‑of‑n** is satisfied or becomes unfulfillable; **merge** payloads deterministically.
- **Back‑pressure**: the manager uses a sliding window of concurrent validations so slow sessions do not block others.

### 2.2 Time semantics (`waitSec`)
- Each branch may specify **`waitSec`** (relative seconds). The manager computes `wakeAt = now + waitSec`. Sleeping consumes **no** EVM gas; the process resumes without further signatures.

### 2.3 Data fusion (inputs for expressions)
- **Session payload** (client‑supplied), **contractReads** (typed ABI), and **apiCalls** (JSON) are merged into one input map. Validate expressions run over this map.

### 2.4 Failure handling (separate from `onInvalid`)
- **Typed rule actions** (e.g., `abortStep`, `cancelSession`) may be attached to a rule. They are evaluated **after** `isValid` and can **stop a step** or **cancel a session** without changing the **valid/invalid** decision.  
- **Engine/runtime errors** (e.g., missing defaults where required) fail the step per engine policy.  
- Neither case relies on or redefines **`onInvalid`**; **`onInvalid` remains the alternate “business branch”** when the validate expressions do not pass.

---

## 3) End‑to‑end example (ISO 20022 settlement)

1. **Rule (XRC‑137) “ValidateISO20022Payment”**  
   - **Payload**: payment fields (payer/payee, amount, currency, refs).  
   - **API**: sanction screening → `sanctionScore` (default 0).  
   - **Read**: issuer limits → `limitWei` (default 0).  
   - **Validate**: structural checks + `sanctionScore >= 80` + `amount <= limitWei`.  
   - **onValid**: `payload` normalized; `waitSec: 0`; `execution`: call settlement contract.  
   - **onInvalid**: `payload` contains reason; `waitSec: 1800` to park for manual remediation; **not a failure**.

2. **Orchestration (XRC‑729) “PaymentFlow_v1”**  
   - From `ValidateISO20022Payment` (valid): **spawn** `AMLCheck` and `FXQuote`; **join** at `PrepareSettlement` with **all(2/2)** and `waitOnJoin: kill`.  
   - From `onInvalid`: **spawn** `NotifyPayer` (no join).  
   - Join merges producer payloads and proceeds to settlement prep.

3. **Grants (XRC‑563)**  
   - **Rule** artifact and **log** artifacts are published **encrypted**.  
   - Recipient banks receive **grants per RID** with **scope**=`rule` or `log` as appropriate.  
   - Explorers display metadata; decrypting requires a matching grant.

Result: a reproducible, auditable flow with deterministic joins and privacy by construction.

---

## 4) Comparison (typical approach vs. XDaLa)

| Challenge | Typical chain + schedulers | XDaLa on XGR |
|---|---|---|
| Alternate path vs. failure | Often conflated; “error path” hard‑coded | **`onInvalid` = alternate business path**; **failure handling separate** |
| Parallelism & joins | Custom jobs; race conditions | First‑class **spawn/join** with **any/all/k‑of‑n** |
| Waiting/timing | Crons, polling | **`waitSec`** + deterministic wake scheduling |
| External data | Ad‑hoc connectors, hidden state | **Reads + APIs** merged into one input map |
| Privacy | Ad‑hoc encryption, unclear scope | **Per‑artifact RID + scope** (`rule`/`log`) via XRC‑563 |
| Auditability | Distributed logs | Receipts + log artifacts; hash‑pinned JSON |
| Cost predictability | Opaque | **Validation Gas** (structural) + EVM gas (execution only) |

---

## 5) Operations (concise launch guidance)
- **Governance & validators**: maintain quorum; monitor signer participation; plan controlled membership changes.  
- **RPC posture**: TLS at the edge; authentication; rate limits; monitor base and XDaLa RPC latency/error.  
- **Privacy & retention**: treat grants/read keys as sensitive; set `logExpireDays` per policy.  
- **Observability**: index receipts and lifecycle events; monitor Validation‑Gas distributions.  
- **Backups**: orchestration JSON (by hash), encrypted rules, grants metadata; verify restores in staging.  
- **State retention**: document pruning/snapshot policies per SLA/audit in your ops runbook (no blanket recommendation here).

---

## 6) Key terms
- **Session** — One running instance `(owner, rootPid)` of an orchestration.  
- **Process** — A token executing a rule step (`waiting → running → done/aborted`).  
- **Join target** — A step that aggregates producer results; mode **any/all/k‑of‑n**.  
- **`onValid` / `onInvalid`** — Alternate **business** branches; **not** failure handling.  
- **Failure handling** — Typed rule actions (`abortStep`, `cancelSession`) and engine/runtime errors; separate from branches.  
- **RID (Resource Identifier)** — Unique identifier **per rule artifact and per log artifact**. Grants are issued **per RID** and **by scope** (`rule` or `log`). Decryption requires matching **RID** and **scope**.

---

## 7) Where to go next
- **Rules (XRC‑137)** — JSON anatomy, expressions, outcomes, logging, `waitSec`. → `docs/xDaLa/xrc_137_spec.md`  
- **Orchestrations (XRC‑729)** — spawns, joins (any/all/k‑of‑n), `waitOnJoin`, delivery & merge semantics. → `docs/xDaLa/xrc_729_orchestration_session_manager.md`  
- **Grants (XRC‑563)** — RID, scopes (`rule`/`log`), grants lifecycle. → `docs/xDaLa/xgr_encryptionGrants.md`  
- **Validation Gas** — weights, wait surcharge, budgeting patterns. → `docs/xDaLa/XRC-137_Validation_Gas.md`  
- **Session transactions & RPC** — permits, budgets, lifecycle. → `docs/xDaLa/xDaLa_sessionTransaction.md`
