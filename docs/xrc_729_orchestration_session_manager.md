# XRC‑729 Orchestrations & Manager Semantics — Enterprise Guide (Draft v1.0)

> **Scope.** This document defines the high‑level logic and expected behaviour of the XRC‑729 orchestration format and the Session Manager that interprets it. It is written for a **closed‑source enterprise** setting: we describe *interfaces, lifecycle and semantics* only — **no code excerpts**. JSON examples are included where helpful because JSON is the external authoring format for orchestrations and test fixtures.

> **Audience.** Platform engineers, protocol integrators, QA, and product leads. It assumes familiarity with asynchronous workflow systems, smart‑contract registries, and RPC.

---

## 0)
 Executive summary

- **XRC‑729** is the *on‑chain registry interface* (and content‑addressable storage) for orchestrations. It is the **single source of truth** for what the engine is allowed to execute.
- The **Session Manager** is the deterministic runtime layer between client RPC and the core engine. It
  - creates session processes, schedules steps and applies **Join rules**,
  - treats Join inputs as pure **`from`‑based expectations** (no labels anymore) with required `when` ∈ {`valid`,`invalid`,`any`},
  - enforces **`waitOnJoin` policies** (`kill` | `drain`) via *Dispatch* and *Spawn* gates,
  - promotes targets when **k‑of‑n** joins are satisfied and aborts targets early when they become **unfulfillable**,
  - delivers producer results into a **Join Inbox** (per‑step payload map) and deterministically merges them into the target payload.
- Orchestrations are registered as JSON strings in XRC‑729 and retrieved via `getOSTC(id)`. The engine parses them into an internal `Orchestration` structure and validates a canonical hash before execution.
- The manager operates per `(owner, rootPid)` with a root actor and a sliding window of concurrent validations (lease tokens, claim mechanics).
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

## 3)
 XRC‑729 orchestration JSON (authoring model)

An orchestration is a **directed step graph** with declarative follow‑up branches. The JSON stored in the XRC‑729 contract maps 1:1 to the `canvasOrch` type in Go.

### 3.1 Top‑level

```json
{
  "id": "my_orchestration",
  "structure": { /* map of stepId → Step */ }
}
```

- `id`: free identifier (assigned by the authoring tool).
- `structure`: map from `stepId` → step definition (see 3.2).

### 3.2 Step

```json
{
  "rule": "${addr:CONTRACT_ALIAS}",
  "onValid":  Branch?,
  "onInvalid": Branch?
}
```

- `rule` (required) – reference to the XRC‑137 rule contract (e.g. via `${addr:…}` alias).
- `onValid` – branch to execute when the rule returns `valid == true`.
- `onInvalid` – branch to execute when the rule returns `valid == false`.

Both branches are optional. A step without branches is a leaf without follow‑ups.

### 3.3 Branch (spawns + join)

The branch type (`Branch`) corresponds to `canvasBranch` in Go and contains only:

```json
{
  "spawns": [ "B1", "C1" ],
  "join": {
    "joinid": "J1",
    "mode": "any",
    "waitonjoin": "kill",
    "from": [
      { "node": "B1", "when": "valid" },
      { "node": "C1", "when": "any" }
    ]
  }
}
```

- `spawns` – list of step IDs to start as **producers**.
- `join` – optional **join target**:
  - `joinid` – step ID of the target that will aggregate producer outputs.
  - `mode` – join mode (`"any"`, `"all"` or object, see 3.6).
  - `waitonjoin` – policy `kill|drain` (see 3.7).
  - `from[]` – list of expected producer steps (see 3.5).

**Important:**

- There is **no `continue` structure anymore**. The join target is specified exclusively via `join.joinid`.
- All producers are declared via `spawns[]` and are implicitly linked to the join target of the same branch (if present).

### 3.4 Spawns (producers)

```json
"spawns": [ "B1", "C1", "D1" ]
```

Each entry is a **step ID**:

- For every entry the manager creates a new process record (producer).
- All producers of the same branch together form the **join scope** of that branch.

Internally this scope is marked via `JoinGroupID` / `JoinFromGroupID` on target and producers; the JSON does not need to care about these fields.

### 3.5 Join item (`from`)

Join items are configured via `from[]` and are **purely step‑based**:

```json
{
  "node": "B1",
  "when": "valid"
}
```

- `node` (required) – step ID of an expected producer.
- `when` – `"valid" | "invalid" | "any" | "both"`:
  - `""` or `"both"` is normalized to `"any"` internally.
  - `"any"` accepts both `valid` and `invalid` results.
  - `"valid"` / `"invalid"` filter accordingly.

There are **no `label` fields anymore**. Each join contribution is identified solely by the step ID (`node`).

### 3.6 Mode

`mode` controls how many expected contributions must arrive before the join is considered satisfied. It supports two forms (string or object).

**String form**

```json
"any"
```

or

```json
"all"
```

- `"any"` ⇒ `k = 1`
- `"all"` ⇒ `k = n` (number of entries in `from[]`).

**Object form (k‑of‑n)**

```json
{ "kofn": 2 }
```

or synonymously

```json
{ "k": 2 }
```

- `"kofn"` / `"k"` specify an explicit threshold `k`.
- `1 ≤ k ≤ n` is validated at authoring time / in the parser.

### 3.7 Policy: `waitonjoin`

```json
"waitonjoin": "kill"
```

- **`kill`** – once the join is decided (either satisfied or unfulfillable),
  - the manager promotes the target and
  - terminates waiting producers in the join scope that could still reach a missing expected step,
  - blocks new spawns of producers in the same scope.
- **`drain`** – producers may continue and progress to independent steps; spawns remain allowed.

The `kill` / `drain` distinction only affects:

- the dispatch gate (promotion of producers),
- the spawn gate (creation of new producers),
- optional kill behavior for still‑waiting producers after the join has completed.
## 4)
 Manager semantics (runtime)

### 4.1 Process lifecycle

States: `waiting` → `running` → `done` (terminal) or `aborted` (terminal). `paused` is an external flag and prevents promotion.

- **Promotion** = `waiting` → `running` when  
  1. `NextWakeAt` is reached, and  
  2. the **dispatch gate** allows it (see 4.3).
- **Creation** of children happens as a reaction to a `ValidateSingleStep` result:
  - optional **join target** (from `res.Join`),
  - 0..n **producers** (from `res.Spawns`).
  New processes always start in state `waiting`.
- **Delivery** happens when a producer transitions to a terminal state and the **delivery guard** allows sending a contribution to its join target (see 4.4).

The validation itself (`ValidateSingleStep`) runs in worker goroutines; applying the results (spawn, delivery, promotion) happens sequentially in the root‑actor loop.

### 4.2 Roles

- **Join target** – process created from `res.Join`:
  - `JoinExpect[]` – list of expected producer steps (step IDs).
  - `JoinRequireWhen{stepId→when}` – optional filter per expected step: `"valid" | "invalid" | "any"`.
  - `JoinK` – threshold `k` (k‑of‑n semantics).
  - `JoinPolicy` – `"kill"` or `"drain"`.
  - `JoinInbox{stepId→piece}` – delivered payload pieces per expected step.
  - `JoinFromSeen{stepId→stepId}` – markers for which steps have actually delivered.
  - `JoinFail{stepId→reason}` – documents expected steps that are definitively failed (e.g. `aborted`).
  - `JoinClosed`, `JoinClosedAt` – status / timestamp of join completion.
  - `JoinFromGroupID` – scope ID from which producers may deliver (internally generated).
- **Producer** – process created from `res.Spawns`:
  - `JoinGroupID` – scope ID referring to the join target this producer can contribute to.
  - `LastEvalStep` / `LastStep` – step that was evaluated last (used as `fromStep`).
  - `LastEvalValid` – boolean deriving the `when` (`valid` / `invalid`).

Each producer belongs to at most one join scope (via `JoinGroupID`).

### 4.3 Gates: dispatch & spawn

**Dispatch gate (promotion time)**

Controls whether a `waiting` process may move to `running`.

Rules:

- Join targets are **not executed again before the join is closed**:
  - As long as `len(JoinExpect) > 0 && !JoinClosed`, the target remains `waiting`.
- Producers with `JoinGroupID`:
  - If the corresponding join target is **closed** and `JoinPolicy == "kill"`,
    - promotion is blocked, the producer is set to `aborted` and will not be started again.
  - If the target is closed and `JoinPolicy == "drain"`,
    - the producer may continue; the join decision has already been made.

**Spawn gate (creation time)**

Controls whether new producers are created at all.

Rules:

- Producers without `JoinGroupID` are never blocked.
- Producers with `JoinGroupID`:
  - If the corresponding join target is **closed** and `JoinPolicy == "kill"`, the spawn is skipped.
  - With `drain` spawns are allowed.

This guarantees that, once a join with policy `kill` has been decided, no new work is created for that join scope.

### 4.4 Delivery guard & inbox merge

**Delivery pre‑conditions**

For a producer `p` and a join target `t`:

1. `p.RootPid == t.RootPid`.
2. `p.JoinGroupID == t.JoinFromGroupID` (producer belongs to the target’s scope).
3. `p` is terminal (`Status == done|aborted`).

The effective `fromStep` and `when` are determined as follows:

- `fromStep` – prefer `p.LastEvalStep`, fallback to `p.LastStep`.
- `when` – `"valid"` if `LastEvalValid == true`, otherwise `"invalid"`. If `LastEvalValid == nil`, the engine falls back to `"any"` semantics.

**Failure cases**

- If `p.Status == aborted` and `fromStep` is in `JoinExpect`, the manager records `JoinFail[fromStep] = "aborted"`. No payload is delivered, but the join is re‑evaluated.
- If `fromStep` is **not** in `JoinExpect`, no delivery and no fail entry is recorded; the join is still re‑evaluated.

**Successful delivery**

If `fromStep` is in `JoinExpect` and `when` matches the configured condition (`JoinRequireWhen[fromStep] ∈ {"any", when}`):

1. A payload piece `piece` is built:
   - base is `p.ResumePlain` (or `{}`),
   - meta fields `_from` and `_when` are added.
2. `JoinInbox[fromStep] = piece` (if not already present).
3. `JoinFromSeen[fromStep] = fromStep`.
4. Any existing `JoinFail[fromStep]` entry is removed.
5. The target is persisted and `maybePromoteJoinTarget` is invoked.

Actual aggregation of pieces into the target’s `ResumePlain` happens **only on promotion** (see 4.7).

### 4.5 Join promotion & unfulfillable detection

`maybePromoteJoinTarget` decides whether a join target

- should be promoted (join satisfied),
- should abort early (join unfulfillable),
- or should remain open.

**Step 1 – Counters**

- `expect = { stepId | stepId ∈ JoinExpect }`
- `got = number of stepIds in JoinInbox ∩ expect`
- `missing = expect \ JoinInbox`

`k = JoinK`; if `k <= 0`, the engine sets `k = len(expect)`.

**Step 2 – Potential (reachability)**

For each missing `exp ∈ missing`:

- Search all processes `s` in the same root with:
  - `s.Status ∈ {waiting, running}`,
  - `s.JoinGroupID == target.JoinFromGroupID` (same scope).
- For each such producer `s`:
  - If `s.ResumeStep == exp` or
  - `CanReachAny(XRC729, OSTCId, s.ResumeStep → exp, OSTCHash) == true`,
  - then `exp` is potentially satisfiable and added to `potSet`.

**Step 3 – Decision**

- If `got ≥ k` → join satisfied:
  - payload merge (see 4.7),
  - `JoinClosed = true`, `JoinClosedAt = now`.
  - If the target has a `ResumeStep`:
    - if `NextWakeAt > now` → target stays `waiting`,
    - otherwise → target is promoted to `running`.
  - With `JoinPolicy == "kill"` the manager calls `killRemaining` to terminate waiting producers in the scope that could still reach a missing `exp` (if any).
- If `got + |potSet| < k` → join unfulfillable:
  - target is set to `aborted`, `JoinClosed = true`, `JoinClosedAt = now`.
  - With `JoinPolicy == "kill"` the manager again calls `killRemaining` for matching producers.
- Otherwise the join stays **open**:
  - neither status nor `JoinClosed` are changed.

### 4.6 Backloops

Backloops (producers jumping back to their own or each other’s steps) are explicitly supported:

- As long as there exists a producer in the scope that can reach a **missing** expected step `exp`
  (`CanReachAny(…, s.ResumeStep → exp)`), `exp` is considered potentially satisfiable.
- This prevents the join from being incorrectly classified as unfulfillable simply because the producer is not yet at `exp`.

The `kill` policy only applies **after join completion** (see 4.5). Backloops before completion are not affected.

### 4.7 Payload merge semantics

When a join is satisfied, all payload pieces from `JoinInbox` are merged into the target’s `ResumePlain`:

- Each `piece` is a `map[string]any`.
- Meta fields `_from` and `_when` are ignored.
- All other keys are merged *flat* into the target (**last‑write‑wins**; later pieces overwrite earlier ones).

There is no special handling for `{ "data": {…} }` shapes – merge semantics are intentionally simple.

### 4.8 Determinism and PIDs

- PIDs have the form `"<rootPid>:<iter>"`. `iter` is monotonically allocated per root actor (`alloc()`).
- `createUnique` ensures that, in case of collisions (e.g. multi‑node deployment), a new iteration/PID is rolled until the insert succeeds.

This yields deterministic, monotonically increasing PIDs per root scope while safely handling contention.
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

## 6)
 End‑to‑end examples (JSON + expected behaviour)

Each example shows an excerpt of the orchestration JSON (authoring format from 3) and describes the expected runtime behaviour. The examples are **logic‑only** and suitable for QA tests.

### 6.1 ANY + `drain`, single producer expected, delivers wrong `when`

**Orchestration**

```json
{
  "id": "OrderFlow_v1",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawns": [ "D1" ],
        "join": {
          "joinid": "J1",
          "mode": "any",
          "waitonjoin": "drain",
          "from": [
            { "node": "D1", "when": "valid" }
          ]
        }
      }
    },
    "D1": {
      "rule": "${addr:XRC137_D}"
    },
    "J1": {
      "rule": "${addr:XRC137_J}"
    }
  }
}
```

**Behaviour**

- `A1` starts and returns `valid`.
- Branch `onValid`:
  - spawns a producer on `D1`,
  - creates join target `J1` with `mode = "any"` (`k=1`), expecting a `valid` contribution from `D1`.
- Assume `D1` returns `invalid`:
  - delivery guard checks `when`:
    - expected `"valid"`, got `"invalid"` → no entry in `JoinInbox["D1"]`.
  - `got = 0`, `missing = {"D1"}`, `potSet` contains `D1` (producer can still reach its step, e.g. via backloop) → join remains open.
- If `D1` eventually becomes `aborted`:
  - `JoinFail["D1"] = "aborted"`,
  - no producer in the scope can reach `D1` anymore → `potSet = ∅`,
  - `got + |potSet| = 0 < k=1` → join becomes `aborted` (unfulfillable).

Policy `drain` means that other producers (if present) would be allowed to continue; in this minimal example there are none.

### 6.2 ALL + `kill`, two producers, one fails

**Orchestration**

```json
{
  "id": "ParallelEnrichment_v1",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawns": [ "B1", "E1" ],
        "join": {
          "joinid": "J1",
          "mode": "all",
          "waitonjoin": "kill",
          "from": [
            { "node": "B1", "when": "any" },
            { "node": "E1", "when": "valid" }
          ]
        }
      }
    },
    "B1": { "rule": "${addr:XRC137_B}" },
    "E1": { "rule": "${addr:XRC137_E}" },
    "J1": { "rule": "${addr:XRC137_J}" }
  }
}
```

**Behaviour**

- `A1.valid` starts producers `B1` and `E1` and creates `J1`.
- Join expects:
  - any result from `B1` (`when = any`),
  - a `valid` result from `E1`,
  - `mode = "all"` → `k = 2`.
- Scenario:
  - `B1` finishes (`valid` or `invalid` – both are accepted) → `JoinInbox["B1"]` is filled.
  - `E1` hits a hard failure and becomes `aborted`.
- Consequence:
  - `got = 1` (only `B1`), `missing = {"E1"}`.
  - No producer in the scope can reach `E1` anymore (assuming no backloops) → `potSet = ∅`.
  - `got + |potSet| = 1 < k = 2` → join becomes `aborted`.
  - Policy `kill`:
    - `killRemaining` terminates waiting producers in the scope that could still reach a missing `exp`.
    - In this example no relevant producers remain after join abort.

### 6.3 k‑of‑n with backloop, `kill`

**Orchestration**

```json
{
  "id": "KofN_Backloop_v1",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawns": [ "B1" ],
        "join": {
          "joinid": "J1",
          "mode": { "k": 2 },
          "waitonjoin": "kill",
          "from": [
            { "node": "B1", "when": "valid" },
            { "node": "C1", "when": "valid" }
          ]
        }
      }
    },
    "B1": {
      "rule": "${addr:XRC137_B}",
      "onValid": {
        "spawns": [ "C1" ]
      }
    },
    "C1": {
      "rule": "${addr:XRC137_C}",
      "onValid": {
        "spawns": [ "B1" ]
      }
    },
    "J1": { "rule": "${addr:XRC137_J}" }
  }
}
```

*(Simplified: `B1` and `C1` form a backloop.)*

**Behaviour**

- `A1.valid`:
  - spawns `B1`,
  - creates join `J1` with `from = [B1,C1]`, `k=2`, `waitonjoin="kill"`.
- `B1.valid`:
  - delivers into `JoinInbox["B1"]`,
  - spawns `C1`.
- `C1.valid`:
  - delivers into `JoinInbox["C1"]`,
  - join now has `got = 2`, `k = 2` → satisfied.
- Join promotion:
  - `JoinClosed = true`, payload from `B1` and `C1` is merged into `J1.ResumePlain`,
  - `J1` is set to `waiting` or `running` depending on `NextWakeAt`,
  - policy `kill`:
    - `killRemaining` terminates any waiting producers in the scope that could still reach a missing `exp`;
    - here there are no missing `exp`, so no additional kill happens.

The backloop does not affect the join result as long as the expected steps `B1` and `C1` are reached in any order.

### 6.4 Filter on `when` (valid vs invalid)

**Orchestration**

```json
{
  "id": "WhenFilter_v1",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
      "onValid": {
        "spawns": [ "B1", "C1" ],
        "join": {
          "joinid": "J1",
          "mode": "any",
          "waitonjoin": "drain",
          "from": [
            { "node": "B1", "when": "valid" },
            { "node": "C1", "when": "invalid" }
          ]
        }
      }
    },
    "B1": { "rule": "${addr:XRC137_B}" },
    "C1": { "rule": "${addr:XRC137_C}" },
    "J1": { "rule": "${addr:XRC137_J}" }
  }
}
```

**Behaviour**

- `A1.valid` starts `B1` and `C1`; join `J1` expects:
  - a `valid` result from `B1`,
  - an `invalid` result from `C1`,
  - `mode = "any"` → `k=1`.
- Scenario 1:
  - `B1.valid` → `JoinInbox["B1"]` is filled, join is already satisfied (`got=1≥k`) even if `C1` later produces any result.
- Scenario 2:
  - `B1.invalid`, `C1.invalid`:
    - contribution from `B1` is discarded because `when="valid"`,
    - contribution from `C1` is accepted (`when="invalid"`),
    - join is satisfied via `C1`.

Policy `drain` allows both producers to continue independently of the join outcome or spawn further work.
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

