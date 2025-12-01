# XGR Chain & XDaLa — General Overview (v4, corrected + chain foundations)

> **Purpose**  
> Provide an executive yet technically accurate introduction to **XGR** (the EVM chain) and **XDaLa** (the rule- and process-layer). This document explains **why** you use it, the **core specs** (XRC‑137 / XRC‑729 / XRC‑563), how the **runtime** behaves (sessions, wakes, joins), essential **chain foundations**, and links to deeper guides.

---

## 0) Why XDaLa (business value & when to use it)

Complex processes are rarely a single transaction. They are **multi‑step**, sometimes **parallel**, depend on **external data**, and carry **privacy & compliance** requirements. On typical chains, teams stitch this together with keepers, crons, queues, webhooks, and private databases — fragile to operate and hard to audit.

**XDaLa** adds a **deterministic process layer** on a standard EVM chain so you can describe, run, and audit business flows end‑to‑end:

- **Deterministic orchestration** of parallel/conditional steps with **joins (any/all/k‑of‑n)** and **time** via `waitSec`.
- **Asynchronous, instance‑based sessions** (one process tree per session) with deterministic wake scheduling and back‑pressure.
- **External data inputs** (contract reads + HTTP APIs) merged into a single input map for rules.
- **Governed privacy** with per‑artifact encryption and grants (XRC‑563).
- **Budgetable validation** (structural Validation Gas) separate from EVM gas.
- **100% EVM‑compatible** — no custom tx types; wallets and SDKs continue to work.

**Where it shines (illustrative use cases):**  
- **ISO 20022 settlement**: Validate structured payment data; encrypt rule & logs; orchestrate FX, AML, and settlement with joins; execute on‑chain transfers only when pre‑conditions are valid.  
- **Trading process**: Order checks → risk limits → venue quotes (parallel) → join best quote → execute; retries via `waitSec`, keine externen Scheduler.  
- **Logistics workflow**: Shipment creation → parallel track & trace providers → join on k‑of‑n confirmations → customs clearance → release; sensitive logs encrypted per recipient.

> **Figure 1 (optional): XDaLa at a glance** — Session payload → **XRC‑137** rule (reads/APIs → expressions → outcomes `onValid` / `onInvalid` with `payload` / `waitSec` / optional `execution`) → **XRC‑729** orchestration (spawn/join policy) → receipts/logs (**XRC‑563** grants).  
> You can embed the SVG we generated: `xgr_order_process_colored.svg`

---

## 1) Chain foundations (XGR)

**Consensus & finality.** **IBFT** gives fast, deterministic finality with proposer rotation. Downstream systems do not need probabilistic reorg handling.

**Execution.** **Standard EVM**; XDaLa is additive — we do **not** introduce new transaction formats. Outcomes may include a normal ABI call (“innerCall”).

**RPC surface.** Ethereum JSON‑RPC plus a small, documented set of XDaLa endpoints for **session lifecycle**, **rule/orchestration metadata**, and **introspection**. Existing tools remain compatible.

**State & receipts.** State is Merkleized; receipts/logs capture the **lifecycle** of XDaLa processes for audit and replay. Sensitive content can be encrypted (see XRC‑563).

**Node roles.** Validators (governance + signing), Full Nodes (RPC, data services), Observers/Analytics (index receipts/XDaLa events).

**Operational stance.** TLS at the edge; authentication and rate limits; documented state‑retention policy per SLA/audit (no blanket snapshot/pruning guidance here).

---

## 2) The specs at a glance (JSON as the contract)

- **XRC‑137 — Rule (one step, canonical JSON)**  
  Declares inputs, optional **contractReads** and **apiCalls**, **validate expressions**, and two outcome branches **`onValid`**/**`onInvalid`** with `payload` mapping, **`waitSec`**, optional `execution`, and logging policy. **`onInvalid` ist *nicht* Failure**; es ist der **alternative Business‑Pfad**, wenn die Validate‑Regeln false ergeben. *Failure handling ist separat* (siehe §4.4).  
  _Deep dive: `docs/xDaLa/xrc_137_spec.md`_

- **XRC‑729 — Orchestration (graph, canonical JSON)**  
  Deklariert den Step‑Graph (IDs), branch‑spezifische **spawns**, optionale **joins** mit Modus **any/all/k‑of‑n**, und die **waitOnJoin**‑Policy (`kill` oder `drain`). Targets **mergen** Producer‑Payloads deterministisch.  
  _Deep dive: `docs/xDaLa/xrc_729_orchestration_session_manager.md`_

- **XRC‑563 — Grants (encryption & access, per‑artifact)**  
  Jedes **Rule‑Artefakt (XRC‑137)** und jedes **Log‑Artefakt** besitzt **einen eigenen RID (Resource Identifier)**. Grants werden **pro RID** und zusätzlich nach **Scope** (`rule` oder `log`) vergeben. Entschlüsselung erfordert **Match von RID und Scope**; so wird festgelegt, wer eine konkrete Regel bzw. ein konkretes Log lesen darf.  
  _Deep dive: `docs/xDaLa/xgr_encryptionGrants.md`_

> **Why JSON?** Human‑readable, diff‑able artifacts improve reviews, CI, and change governance. **XRC‑137** und **XRC‑729** sind geschäftslesbar und maschinenverarbeitbar, versions‑gepinnt via Hash.

---

## 3) Runtime model (sessions, wakes, joins)

### 3.1 Session Manager (instance‑based, asynchronous)
Jedes `(owner, rootPid)` läuft als **eigener Prozesstree**:
- **Promote** Prozesse, wenn **wake time** erreicht ist und Dispatch‑Gates es erlauben.
- **Evaluate** den referenzierten **XRC‑137** genau einmal je Run: Inputs mergen (Session‑Payload + Reads + APIs), `isValid` berechnen, dann **`onValid`** **oder** **`onInvalid`** wählen.
- **Spawn** Producer‑Steps entsprechend Branch; **deliver** Producer‑Ergebnisse in das per‑Target **Join Inbox**; **close** Joins, wenn **any/all/k‑of‑n** erfüllt oder unerfüllbar ist; **merge** Payloads deterministisch.
- **Back‑pressure**: Sliding Window für parallele Validierungen — ein „langsamer“ Nutzer blockiert andere nicht.

### 3.2 Time semantics (`waitSec`)
- Jede Branch kann **`waitSec`** (relative Sekunden) setzen. Der Manager berechnet `wakeAt = now + waitSec`. Schlafen kostet **kein** EVM‑Gas; Fortsetzung ohne weitere Signatur.

### 3.3 Data fusion (inputs for expressions)
- **Session‑Payload** (Client), **contractReads** (typisierte ABI‑Aufrufe), und **apiCalls** (JSON) werden zu einer **einheitlichen Input‑Map** gemerged; die Validate‑Expressions laufen darauf.

### 3.4 Failure handling (separate from `onInvalid`)
- **Typed rule actions** (z. B. `abortStep`, `cancelSession`) werden **nach** `isValid` bewertet und können einen **Step beenden** oder eine **Session abbrechen** — unabhängig vom gewählten Business‑Branch.  
- **Engine/runtime errors** (z. B. fehlende Defaults, wo Pflicht) failen den Step gemäß Engine‑Policy.  
- **Wichtig:** `onInvalid` bleibt **rein fachlich** der Alternativ‑Pfad; Failure ≠ `onInvalid`.

---

## 4) End‑to‑end: **permanenter Order‑to‑Ship‑Prozess** (unendlicher Bestelleingang)

**Ziel:** Ein **dauerhaft laufender** Prozess, der Bestellungen asynchron verarbeitet. **OrderIntake** wird durch neue Kundendaten **gewaked**, prüft diese, stößt Folge‑Schritte an — und **arming** gleichzeitig den **nächsten Intake** (sowohl bei `valid` als auch `invalid`).

1. **O · OrderIntake (XRC‑137)**  
   - **Inputs:** `orderId`, Kundendaten, Warenkorb.  
   - **Validate:** Struktur/Kundenstatus plausibel?  
   - **onValid:** spawn **PaymentCheck** und **StockAllocation**; **zusätzlich**: spawn **neuen O** und setze `waitSec=0` (bereits „wartend“ auf das nächste Wake).  
   - **onInvalid:** spawn **NotifyCustomer**; **zusätzlich**: spawn **neuen O** und setze `waitSec=0`.  
   - **LogTX (+ optional innerCall)**

2. **P · PaymentCheck (XRC‑137)**  
   - **ContractReads (EVM, beliebige Chain):** Zahlungseingang, Escrow‑Balance.  
   - **API (PSP JSON):** Status/Chargeback‑Risiko (mit Defaults).  
   - **onInvalid:** `waitSec=600` (Retry ohne neue Signatur).  
   - **LogTX (+ optional innerCall)**

3. **SA · StockAllocation (XRC‑137)**  
   - **API (WMS/ERP):** Verfügbarkeit reservieren.  
   - **onInvalid:** `waitSec=300` (Retry/Backorder).  
   - **LogTX (+ optional innerCall)**

4. **J1 · Join (mode: all(2/2), waitOnJoin=kill)**  
   - Wartet auf P & SA; **merge** deren Payloads; fährt deterministisch fort.

5. **S · Shipping (XRC‑137)**  
   - **Execution:** `issueShipment(...)` (ABI‑Call).  
   - **LogTX (+ optional innerCall)**

**Eigenschaften:**  
- **Unendlicher Intake**: O spawnt sich **immer** selbst neu und wartet auf das nächste Wake (nächster Auftrag).  
- **Asynchron, gas‑sparend:** Wartezeiten (`waitSec`) kosten kein EVM‑Gas; Fortsetzung ohne neue Signatur.  
- **Deterministische Joins:** all(2/2); frühzeitige Abbrüche, falls unerfüllbar.  
- **Privacy by design:** Regeln + Logs pro Artefakt verschlüsselbar; Grants pro **RID & Scope**.

> Hinweis: Das Diagramm „OrderPipeline_v1“ (farbig, mit Symbolen) liegt separat vor: `xgr_order_process_colored.svg` / `.png`.

---

## 5) Comparison (typical approach vs. XDaLa)

| Challenge | Typical chain + schedulers | XDaLa on XGR |
|---|---|---|
| Alternate path vs. failure | Oft vermischt | **`onInvalid` = Business‑Pfad**, **Failure separat** |
| Parallelism & joins | Eigene Jobs; Race Conditions | Native **spawn/join** mit **any/all/k‑of‑n** |
| Waiting/timing | Crons, Polling | **`waitSec`** + deterministisches Wake |
| External data | Ad‑hoc, Hidden State | **Reads + APIs** → eine Input‑Map |
| Privacy | Uneinheitlich | **Pro‑Artefakt RID + Scope** (`rule`/`log`) |
| Auditability | Verteilte Logs | Receipts + Log‑Artefakte; Hash‑pinned JSON |
| Cost predictability | Opaque | **Validation Gas** (strukturell) + EVM (nur Execution) |

---

## 6) Operations (concise launch guidance)
- **Governance/Validators:** Quorum pflegen; Signer‑Participation monitoren; Membership‑Changes geplant.  
- **RPC posture:** TLS am Edge; Auth; Rate Limits; Latenz/Errors Base + XDaLa beobachten.  
- **Privacy/Retention:** Grants/Read‑Keys wie Secrets behandeln; `logExpireDays` per Policy.  
- **Observability:** Receipts + XDaLa‑Events indexieren; Validation‑Gas‑Verteilungen beobachten.  
- **Backups:** Orchestration JSON (by hash), verschlüsselte Rules, Grants‑Metadaten; Restore‑Tests in Staging.  
- **State retention:** Snapshot/Pruning per SLA/Audit dokumentieren (keine Pauschal‑Empfehlung hier).

---

## 7) Key terms
- **Session** — Laufende Instanz `(owner, rootPid)` einer Orchestration.  
- **Process** — Token, das einen Rule‑Step ausführt (`waiting → running → done/aborted`).  
- **Join target** — Aggregiert Producer‑Ergebnisse; Modus **any/all/k‑of‑n**.  
- **`onValid` / `onInvalid`** — Alternative **Business‑Branches**; **nicht** Failure.  
- **Failure handling** — Typed rule actions (`abortStep`, `cancelSession`) und Engine/Runtime‑Fehler; getrennt von Branches.  
- **RID (Resource Identifier)** — Einzigartige Kennung **pro Rule‑Artefakt und pro Log‑Artefakt**. Grants sind **pro RID** und nach **Scope** (`rule`/`log`) vergeben. Entschlüsselung erfordert **Match** beider.

---

## 8) Where to go next
- **Rules (XRC‑137)** — JSON anatomy, expressions, outcomes, logging, `waitSec`. → `docs/xDaLa/xrc_137_spec.md`  
- **Orchestrations (XRC‑729)** — spawns, joins (any/all/k‑of‑n), `waitOnJoin`, delivery & merge semantics. → `docs/xDaLa/xrc_729_orchestration_session_manager.md`  
- **Grants (XRC‑563)** — RID, scopes (`rule`/`log`), grants lifecycle. → `docs/xDaLa/xgr_encryptionGrants.md`  
- **Validation Gas** — weights, wait surcharge, budgeting patterns. → `docs/xDaLa/XRC‑137_Validation_Gas.md`  
- **Session transactions & RPC** — permits, budgets, lifecycle. → `docs/xDaLa/xDaLa_sessionTransaction.md`
