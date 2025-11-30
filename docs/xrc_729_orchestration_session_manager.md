# XRC‑729 Orchestrations & Manager Semantics — Enterprise Guide (Draft v1.0)

> **Scope.** This document defines the high‑level logic and expected behaviour of the XRC‑729 orchestration format and the Session Manager that interprets it. It is written for a **closed‑source enterprise** setting: we describe *interfaces, lifecycle and semantics* only — **no code excerpts**. JSON examples are included where helpful because JSON is the external authoring format for orchestrations and test fixtures.

> **Audience.** Platform engineers, protocol integrators, QA, and product leads. It assumes familiarity with asynchronous workflow systems, smart‑contract registries, and RPC.

---

## 0) Executive summary

- **XRC‑729** is the *on‑chain registry* (and content‑addressable index) for orchestration specifications. It persists step graphs (“orchestrations”) and their integrity hashes. It is the **source of truth** for what the engine may execute.
- The **Session Manager** is the *deterministic runtime layer* between client RPC and the core engine. It:
  - Creates session processes, schedules steps, applies **Join** rules (`label`, optional `from`, required `when` ∈ {`valid`,`invalid`,`any`}),
  - Enforces **waitOnJoin** policies (`kill` | `drain`) via *Dispatch* and *Spawn* gates,
  - Promotes targets when **k‑of‑n** joins are satisfied; aborts targets early when they become **unfulfillable**,
  - Delivers producer results into a **Join Inbox** and merges outputs into target payloads deterministically.
- **Design principles:** lean & auditable state machine, single place for policy, minimal persisted state, deterministic PIDs, backloops supported, and clear failure modes.

---

## 1) Relationship: XRC‑729 ↔ Manager ↔ Core

**XRC‑729 (on‑chain):**
- Stores orchestration metadata and integrity (hash) per `(ostcId, stepId)` and/or content key.
- Emits events on register/update for off‑chain consumers to cache/verify.
- Provides read‑only views to fetch orchestration definitions and their hashes.

**Manager (off‑chain runtime):**
- Accepts RPC to enqueue sessions, list/inspect, pause/kill.
- For each to‑be‑executed `stepId`, it calls *Ensure Orchestration* (conceptual) to fetch/validate the definition from XRC‑729 and verify hash consistency.
- Drives process lifecycles, interprets join semantics, and produces durable audit trails (proc_rt + proc_steps).

**Core/Engine:**
- Executes a single step with provided inputs (payload), permitting rules, and orchestration context. Returns `FinalResult` (valid/invalid), `NextPayload`, optional `OutputPayload`, and follow‑up intents (`Continue`, `Spawns`).

> **Invariant:** Every runtime decision that depends on orchestration structure originates in XRC‑729. Manager validates that what it is about to run exists in XRC‑729 **and** matches the expected hash.

---

## 2) RPC surface (high level)

This section lists the **external RPCs** conceptually exposed by the platform. Names are indicative (adapt to actual deployment). Bodies are shown as JSON for clarity — not as code.

### 2.1 Enqueue a root session
- **Method:** `xgr.enqueue`
- **Purpose:** Create or reuse a *root process* `(owner, rootPid)` and schedule its first step.
- **Request (JSON):**
```json
{
  "owner": "0x…",                      
  "rootPid": "5329",                   
  "xrc729": "0xXRC729…",               
  "ostcId": "…",                       
  "ostcHash": "…",                     
  "engineEOA": "0x…",                  
  "ethRPCURL": "https://…",            
  "permit": { "chainId": 1, "nonce": "…", "sig": "…" },
  "init": {
    "stepId": "A1",                    
    "payload": { "User": "alice" }   
  }
}
```
- **Response (JSON):**
```json
{ "ack": "queued" }
```
Notes: `ack` can be `queued | already_queued | paused | scheduled` depending on store state and timing.

### 2.2 List sessions
- **Method:** `xgr.listSessions`
- **Purpose:** Inspect processes for an owner and/or root. Sorting and paging are server‑side.
- **Request:**
```json
{
  "owner": "0x…",
  "rootPid": "5329",           
  "limit": 100,
  "sort": {"by": ["rootPid:desc", "iter:asc"]}
}
```
- **Response (excerpt):**
```json
{
  "items": [
    {
      "pid": "5329:1",
      "parentPid": null,
      "iter": 1,
      "status": "done|waiting|running|aborted|paused",
      "resumeStep": "A1",
      "lastStep": "A1",
      "join": {   
        "expect": ["b","c"],
        "policy": "kill|drain",
        "k": 2,
        "inbox": {"b": {...}},
        "closed": false
      },
      "updatedAt": 1730803196
    }
  ]
}
```

### 2.3 Kill / Pause / Resume
- **Methods:** `xgr.kill`, `xgr.pause`, `xgr.resume`
- **Purpose:** Control a process lifecycle. Kill uses durable `killedAt` and transitions to `aborted`.
- **Request:**
```json
{ "owner": "0x…", "pid": "5329:7" }
```
- **Response:**
```json
{ "ok": true }
```

### 2.4 Put / Get Orchestration (XRC‑729 gateway)
> In production, writes go on‑chain; reads verify against the on‑chain hash. This RPC abstracts those flows for clients.
- **Put (JSON):**
```json
{
  "xrc729": "0xXRC729…",
  "ostcId": "OrderFlowV1",
  "stepId": "A1",
  "orchestration": { … full JSON as in §3 … }
}
```
- **Get (JSON):**
```json
{ "xrc729": "0xXRC729…", "ostcId": "OrderFlowV1", "stepId": "A1" }
```
- **Response (JSON):**
```json
{
  "hash": "0x…",
  "orchestration": { … }
}
```

---

## 3) XRC‑729 orchestration JSON (authoring model)

An orchestration is a **directed step graph** with declarative *follow‑ups*.

### 3.1 Top‑level
```json
{
  "id": "my_orchestration",
  "structure": { /* map of stepId → Step */ }
}
```

### 3.2 Step
```json
{
  "rule": "${addr:CONTRACT_ALIAS}",
  "payload": { /* schema hints, optional */ },
  "onValid":  { "continue": Continue?, "spawn": Spawn[]? },
  "onInvalid":{ "continue": Continue?, "spawn": Spawn[]? }
}
```

### 3.3 Continue (target)
```json
{
  "stepId": "J1",
  "join": [ JoinItem, … ],
  "mode": { "kind": "all|any", "k": 2 },
  "waitOnJoin": "kill|drain"
}
```
- When `join` is absent → immediate continue to `stepId`.
- When `join` is present → `stepId` becomes a **Join Target** (initially `waiting`) that will **promote** to `running` only when k‑of‑n expectations are met.

### 3.4 Spawn (producers)
```json
{ "label": "b", "stepId": "B1" }
```
Each spawn becomes a *producer* bound to the target created by the sibling Continue (if any).

### 3.5 Join item
```json
{ "label": "b", "from": "B1", "when": "valid|invalid|any" }
```
Semantics:
- **label** — name that binds producers to expectations.
- **from** *(optional)* — restricts acceptable *originating step*; otherwise any step can deliver under the label.
- **when** *(required)* — matches the producer’s *evaluation* outcome (`valid`/`invalid`) — **not** its terminal status.

### 3.6 Mode
```json
{ "kind": "all|any", "k": 2 }
```
- `any` ⇒ `k=1` if not specified.
- `all` ⇒ `k=n` (number of listed `join` items) if not specified.
- Explicit `k` overrides both – general **k‑of‑n**.

### 3.7 Policy: `waitOnJoin`
- **kill** — when the join target promotes or closes, **stop all live producers** for that join (and block their further continues).
- **drain** — let producers finish naturally; they can continue to unrelated steps.

---

## 4) Manager semantics (runtime)

### 4.1 Process lifecycle
States: `waiting` → `running` → `done` (terminal) or `aborted` (terminal). `paused` is an external flag that prevents promotion.

- **Promotion** = `waiting` → `running` when (i) `NextWakeAt` elapsed and (ii) **Dispatch Gate** allows it (see §4.3).
- **Creation** of children occurs in response to a parent’s executed step (engine result): one **target** (from `continue`) and zero or more **producers** (from `spawn`). New children start as `waiting`.
- **Delivery** occurs when a **producer** reaches a terminal state and the **Delivery Guard** allows writing into the target’s join inbox (see §4.4).

### 4.2 Roles
- **Join target**: the process created by a `continue` that includes `join`. It has:
  - `JoinExpect[]`, `JoinExactFrom{label→stepId}`, `JoinRequireWhen{label→when}`,
  - `JoinK`, `JoinMode`, `JoinPolicy` (`kill|drain`),
  - `JoinInbox{label→piece}`, `JoinFromSeen{label→stepId}`, `JoinFail{label→reason}`,
  - `JoinClosed` flag once the join is closed (either by satisfaction or early abort).
- **Producer**: a process created by a `spawn` and bound to a target with a `JoinLabel`.

### 4.3 Gates (single point of policy)
- **Dispatch Gate (promotion‑time):**
  - Blocks join targets until their join is **closed** (by promotion decision) to avoid premature execution.
  - For producers targeting a **closed** join:
    - If policy is `kill` **and** producer’s label is part of the join, promotion is **blocked** and the producer is terminated (`aborted`).
    - If policy is `drain`, promotion is **allowed** (no fake `done`).
- **Spawn Gate (creation‑time):**
  - If a spawn would create a producer for a **closed** join, and the label belongs to that join, the spawn is **skipped**.

> Together, the two gates ensure no further work is issued against a join that is already decided.

### 4.4 Delivery Guard & Inbox merge
- Delivery requires: same `rootPid`, expected `label`, and (if present) `from` match.
- **`when`** is derived from *evaluation* (`valid/invalid`), not from terminal status.
- On successful delivery: write `piece` into `JoinInbox[label]` and record `JoinFromSeen[label] = fromStep`.
- On mismatch: record `JoinFail[label] = reason`.
- When `count(inbox) ≥ k`, the target is **closed**, payloads are merged into `ResumePlain`, and promotion is scheduled.

### 4.5 Unfulfillable detection
A waiting, open join becomes **aborted** when its success becomes impossible.

**Algorithm sketch (per target):**
1. Let `expect = [labels…]`, `got = count(labels delivered)`, `k = JoinK`.
2. For each missing `label`:
   - If there is a **live producer** (waiting/running) with that `JoinLabel` → still possible.
   - Otherwise increase `impossibleCount`.
3. If `got + (missing - impossibleCount) < k` → **abort** target and **close** join.

> This applies uniformly, independent of `any`/`all`/`k‑of‑n`, presence of `from`, and `kill/drain`.

### 4.6 Backloops
- A producer may `continue` to *itself* (or to another producer) to try again. While any such producer remains **live**, the target is **not** considered unfulfillable.
- `kill` policy does **not** interfere with backloops **before** the join is closed.

### 4.7 Payload merge semantics
- Join pieces are merged into the target’s `ResumePlain` as a **flat, last‑write‑wins** map.
- If a piece has the special shape `{ "data": {…} }` it is unwrapped so only `data`’s keys are merged.

### 4.8 Determinism and PIDs
- PIDs are of the form `rootPid:iter`. `iter` increases monotonically per root.
- **Threads:** a spawn starts a new thread (its `threadId = pid`), while a continue keeps the same thread.

---

## 5) XRC‑729 contract: conceptual functions & data

> This section explains **what XRC‑729 provides functionally** — not source. Names are indicative; actual interfaces may vary per deployment. The goal is to clarify how the Manager *relies on* XRC‑729.

- **Register Orchestration**
  - *Purpose:* Persist orchestration content for `(ostcId, stepId)` and compute/emit its hash.
  - *Inputs:* `ostcId`, `stepId`, `content`, optional `meta`.
  - *Outputs:* `hash` and an event with indexed identifiers for off‑chain consumers.
  - *Notes:* Updates either version old entries or requires new ids (policy‑dependent).

- **Get Orchestration**
  - *Purpose:* Read orchestration content by `(ostcId, stepId)`.
  - *Outputs:* `content`, `hash`, and *version* if present.

- **Hash Of**
  - *Purpose:* Return the canonical content hash for `(ostcId, stepId)` for quick verification.

- **Enumerate / Exists**
  - *Purpose:* Optional admin views (e.g., list stepIds for an ostcId).

**Manager dependency:**
- Before running any `stepId`, Manager **ensures** the orchestration is known and unmodified: it retrieves `hash` from XRC‑729 and cross‑checks the cached content. If hashes diverge, execution is aborted with a registry mismatch.

---

## 6) End‑to‑end examples (JSON + expected behaviour)

Each example shows the orchestration JSON snippet followed by expected runtime behaviour (narrative). These are **logic‑only** examples suitable for QA.

### 6.1 ANY with `drain`, single producer expected but fails
**Orchestration**
```json
{
  "id": "my_orchestration",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawn": [ { "label": "bad", "stepId": "D1" } ],
        "continue": {
          "stepId": "J1",
          "join": [ { "label": "bad", "when": "valid", "from": "D1" } ],
          "mode": { "kind": "any" },
          "waitOnJoin": "drain"
        }
      }
    },
    "D1": { "rule": "${addr:XRC137_D}", "onInvalid": { "spawn": [ { "label": "escape", "stepId": "E1" } ] } },
    "E1": { "rule": "${addr:XRC137_E}", "onValid": { "continue": { "stepId": "Z1" } } },
    "J1": { "rule": "${addr:XRC137_J}", "onValid": { "continue": { "stepId": "Z1" } } },
    "Z1": { "rule": "${addr:XRC137_Z}" }
  }
}
```
**Expected:**
- `D1` runs and evaluates **invalid**, so it does **not** deliver to `J1` (requires `valid`).
- `E1` may run (spawned by `D1`’s invalid path), but is **not** part of the join and does not affect `J1`.
- No other producers exist; join becomes **unfulfillable** ⇒ `J1` transitions to **aborted** (closed).

### 6.2 ALL with nested producers; `B1` + `E1` required
**Orchestration**
```json
{
  "id": "my_orchestration",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawn": [ { "label": "b", "stepId": "B1" }, { "label": "c", "stepId": "C1" } ],
        "continue": {
          "stepId": "J1",
          "join": [
            { "label": "b", "when": "valid", "from": "B1" },
            { "label": "e", "when": "valid", "from": "E1" }
          ],
          "mode": { "kind": "all" },
          "waitOnJoin": "drain"
        }
      }
    },
    "B1": { "rule": "${addr:XRC137_B}", "onValid": { "continue": { "stepId": "Z1" } } },
    "C1": { "rule": "${addr:XRC137_C}", "onValid": { "spawn": [ { "label": "d", "stepId": "D1" }, { "label": "e", "stepId": "E1" } ] } },
    "D1": { "rule": "${addr:XRC137_D}", "onValid": { "continue": { "stepId": "Z1" } } },
    "E1": { "rule": "${addr:XRC137_E}", "onValid": { "continue": { "stepId": "Z1" } } },
    "J1": { "rule": "${addr:XRC137_J}", "onValid": { "continue": { "stepId": "Z1" } } },
    "Z1": { "rule": "${addr:XRC137_Z}" }
  }
}
```
**Expected:**
- `B1` delivers when **valid**.
- `C1` spawns `E1`; `E1` delivers when **valid**.
- `J1` promotes only when **both** deliveries are present; otherwise it stays open while `E1` (or any backloop) is live. If `E1` becomes impossible and no backloops remain, `J1` is **aborted**.

### 6.3 K‑of‑N with `kill` and a backlooping producer
**Orchestration**
```json
{
  "id": "my_orchestration",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawn": [
          { "label": "g", "stepId": "G1" },
          { "label": "b", "stepId": "B1" },
          { "label": "c", "stepId": "C1" }
        ],
        "continue": {
          "stepId": "J1",
          "join": [
            { "label": "g", "when": "valid", "from": "G1" },
            { "label": "b", "when": "valid", "from": "B1" },
            { "label": "c", "when": "valid", "from": "C1" }
          ],
          "mode": { "k": 2 },
          "waitOnJoin": "kill"
        }
      }
    },
    "G1": { "rule": "${addr:XRC137_G}", "onInvalid": { "continue": { "stepId": "G1" } } },
    "B1": { "rule": "${addr:XRC137_B}" },
    "C1": { "rule": "${addr:XRC137_C}" },
    "J1": { "rule": "${addr:XRC137_J}" }
  }
}
```
**Expected:**
- `G1` may loop `invalid → invalid → valid`. While it loops, `J1` stays open (not unfulfillable).
- Once any **two** labels deliver `valid`, `J1` closes and promotes. **`kill`** then terminates any still‑live producers bound to this join.

### 6.4 `from` filtering
```json
{
  "id": "my_orchestration",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawn": [ { "label": "x", "stepId": "X1" } ],
        "continue": {
          "stepId": "J1",
          "join": [ { "label": "x", "from": "X2", "when": "valid" } ],
          "mode": { "kind": "any" },
          "waitOnJoin": "drain"
        }
      }
    },
    "X1": { "rule": "${addr:XRC137_X}", "onValid": { "continue": { "stepId": "X2" } } },
    "X2": { "rule": "${addr:XRC137_X2}" },
    "J1": { "rule": "${addr:XRC137_J}" }
  }
}
```
**Expected:** Only a delivery **from** `X2` (not from `X1`) can satisfy label `x`.

> **More examples** should be added to the internal knowledge base mirroring your current test suite (e.g., `xrc729_deep_any_k1_kill__b1_vs_c2__happy`, backloop + unrelated spawns, etc.).

---

## 7) Persistence model (auditability)

- **proc_rt** (runtime view): the latest state per process.
- **proc_steps** (append‑only): history of executed steps (IDs, owner, timestamps) sufficient to reconstruct the graph.
- Minimal duplication; payload history is not stored beyond what is required for deterministic replay and audit policies.

**Garbage collection:** terminal processes are removed after TTL (config `XGR_SESSION_TTL_SECS`), except where retention policies require longer audit windows.

---

## 8) Operational concerns & SLOs

- **Deterministic promotion:** Gate checks are idempotent; promotion contains no randomness.
- **Concurrency control:** Per‑root cap (configurable); join‑creating steps bypass the cap to avoid deadlocks.
- **External kill:** `killedAt` is authoritative; the next scheduler pass marks processes aborted and respects that timestamp for ordering and retention.
- **Fairness among producers:** Spawn gate prevents creating work against a closed join; dispatch gate prevents promoting it.

---

## 9) Troubleshooting playbook (logic)

Symptoms → Root causes → Checks:
- **Join stuck in `waiting`:**
  - Missing deliveries, `from` mismatch, `when` mismatch, or backloop still live.
  - Check `JoinInbox`, `JoinFail`, and live producers per label; if no live producers and `got + potential < k`, target should **abort** (verify scheduler pass).
- **Producer keeps looping despite `kill`:**
  - Join might not be **closed** yet (k‑of‑n not met). `kill` applies on *closure* or at dispatch once closed.
- **Delivery never recorded:**
  - Producer terminal but `LastEvalValid`/`ResultValid` mismatched requested `when`.
  - `from` did not match; verify `JoinFromSeen[label]`.

---

## 10) Glossary

- **Orchestration** — JSON spec stored in XRC‑729 describing step graph and follow‑ups.
- **Target** — process created by a `continue` with `join`; it waits for deliveries.
- **Producer** — process created by `spawn` that can deliver into a target under a label.
- **Promotion** — `waiting → running` transition when a join closes and/or timer elapses.
- **Delivery** — writing a producer’s piece into a target’s join inbox.
- **Policy** — `waitOnJoin ∈ {kill, drain}`.
- **Unfulfillable** — condition where reaching `k` deliveries is impossible with remaining live producers.

---

## 11) Compliance & audit notes

- Decisions are driven by **data** (join inbox, live producers) and recorded as state transitions; no opaque heuristics.
- Manager never fabricates `done` without running work.
- All closures (promotion/abort) are timestamped; kill effects on producers are explicit.

---

## 12) Appendix — Minimal authoring checklist

- For every `join` item, decide whether you need `from` and which `when` is appropriate.
- Choose `mode` carefully; prefer explicit `{ "k": n }` when not strictly `all`/`any`.
- Select `waitOnJoin` (`kill` for competitive races, `drain` for independent enrichment flows).
- Confirm backloops have clear termination conditions or explicit guards.

---

**End of document.**

