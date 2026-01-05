# XRC-729 Orchestration and Session Manager
Public specification for orchestration semantics in xDaLa.

This document describes how **XRC-729** (the orchestration smart contract) defines an orchestration graph and how the **xDaLa Session Manager** executes that graph, including **spawns**, **joins**, and **kill-as-soon-as-possible (ASAP)** behavior.

---

## 1. Scope and goals

### 1.1 What this document is
- A **public, buildable specification** for the orchestration structure and its execution semantics.
- A reference for integrators who want deterministic reasoning about *what the manager does* when it runs an orchestration defined by **XRC-729**.

### 1.2 What this document is not
- Not a node-operations handbook (deployment, monitoring, tuning).
- Not an internal implementation manual.

### 1.3 Key design goals
1. **Auditability**: the orchestration graph is sourced **exclusively** from the **XRC-729** smart contract.
2. **Deterministic semantics** (given an execution trace): step outcomes, spawn rules, and join behavior are precisely defined.
3. **Parallelism**: the manager may run steps concurrently; joins provide explicit synchronization points.
4. **Failover-friendly execution**: execution state is represented as a session runtime state that can be resumed.

---

## 2. Relationship between XRC-729 and XRC-137

- **XRC-729** defines **the orchestration graph**: which steps exist and how they connect (spawns, joins, flow control).
- **XRC-137** defines **step semantics**: how a step evaluates inputs (payload + reads), checks rules, produces outcomes, and optionally triggers an execution.

The manager executes an orchestration step by:
1. Loading the orchestration graph from **XRC-729**.
2. For each step, loading the referenced **XRC-137 rule document/contract**.
3. Running the step according to the XRC-137 semantics.
4. Applying orchestration actions (spawn, join, kill policy) defined by the orchestration graph.

---

## 3. Terminology

### 3.1 Orchestration
A directed graph of **steps**. Each step references an XRC-137 rule/contract and defines branch behavior (what to spawn after valid/invalid).

### 3.2 Step
A named node in the orchestration graph (e.g., `"A1"`, `"G1"`, `"J1"`). A step has:
- `rule`: the referenced XRC-137 rule/contract address
- `onValid`, `onInvalid`: branch actions (spawns, joins)

### 3.3 Session
A runtime execution instance of an orchestration for a specific:
- **Root Process ID** (“root pid”)
- orchestration id
- owner/context

A session tracks the current state of each process instance (which step it is in, whether it is waiting/running/done/aborted, etc.).

### 3.4 Process instance
A single execution thread within the session (one branch). A process instance moves through steps over time.

### 3.5 Spawn
Creating a new child process instance from a step branch.

### 3.6 Join
A synchronization primitive where a **join target step** waits until **K-of-N** “from” conditions are satisfied by processes in a specific **join scope**.

---

## 4. Orchestration structure (from XRC-729)

An orchestration document is conceptually:

```jsonc
{
  "id": "my_orchestration",
  "structure": {
    "A1": {
      "rule": "0x...XRC137_A",
      "onValid": { "spawns": ["G1"], "join": { /* ... */ } },
      "onInvalid": { /* ... */ }
    },
    "G1": { "rule": "0x...XRC137_G", "onValid": {}, "onInvalid": { "spawns": ["E1"] } },
    "E1": { "rule": "0x...XRC137_E", "onValid": { "spawns": ["Z1"] }, "onInvalid": {} },
    "J1": { "rule": "0x...XRC137_J", "onValid": { "spawns": ["Z1"] }, "onInvalid": {} },
    "Z1": { "rule": "0x...XRC137_Z" }
  }
}
```

### 4.1 Step object
| Field | Type | Required | Meaning |
|---|---|---:|---|
| `rule` | string (address) | yes | XRC-137 contract address for this step |
| `onValid` | object | no | Branch actions if step evaluates valid |
| `onInvalid` | object | no | Branch actions if step evaluates invalid |

### 4.2 Branch object
| Field | Type | Required | Meaning |
|---|---|---:|---|
| `spawns` | array of strings | no | List of step ids to spawn as child processes |
| `join` | object | no | Join declaration (only meaningful on a branch) |

---

## 5. Execution model (high-level)

At runtime, the manager repeatedly:
1. Finds process instances in **WAITING** state whose “wake time” is due.
2. Leases one and moves it to **RUNNING**.
3. Executes its current step (XRC-137 evaluation + optional execution).
4. Transitions the process instance:
   - to another WAITING step (if it continues), or
   - to DONE / ABORTED (terminal), depending on orchestration semantics.
5. Applies branch actions: spawns and joins.

Parallelism is allowed: multiple process instances may be RUNNING simultaneously.

---

## 6. Joins

Joins are the most subtle orchestration feature. This section defines them precisely.

### 6.1 Join declaration
A join is declared **on a branch** (`onValid` or `onInvalid`) of some step, and it references a **join target step** by id.

Example:

```jsonc
"onValid": {
  "spawns": ["G1", "H1", "I1"],
  "join": {
    "joinid": "J1",
    "mode": "kofn",
    "k": 2,
    "waitonjoin": "kill",
    "from": [
      { "node": "G1", "when": "valid" },
      { "node": "H1", "when": "valid" },
      { "node": "I1", "when": "any" }
    ]
  }
}
```

### 6.2 Join fields
| Field | Type | Required | Meaning |
|---|---|---:|---|
| `joinid` | string | yes | Step id of the join target (must exist in `structure`) |
| `mode` | string | yes | `"any"`, `"all"`, or `"kofn"` |
| `k` | integer | required if `mode="kofn"` | Required number of satisfied `from` conditions |
| `waitonjoin` | string | yes | `"kill"` or `"drain"` |
| `from` | array | yes | Producer definitions: which nodes and which outcome state qualifies |

### 6.3 `from` entries
| Field | Type | Required | Meaning |
|---|---|---:|---|
| `node` | string | yes | Step id that may contribute to the join |
| `when` | string | yes | `"valid"`, `"invalid"`, or `"any"` |

Interpretation:
- A producer contributes to the join **only** if it reaches `node` and its evaluation matches `when`.
- `when="any"` accepts both valid and invalid outcomes.

---

## 7. Join scopes and join groups (critical)

### 7.1 Why scopes exist
Without scoping, in a complex orchestration with nested joins or repeated step ids across branches, a join target could incorrectly consume deliveries from an unrelated branch.

xDaLa prevents this by using **join scopes**, implemented as **join groups**.

### 7.2 The join group concept
When a branch declares a join:
- xDaLa creates a **fresh join group** for that join instance.
- The **join target** expects deliveries **only** from that fresh join group.
- Producers spawned under that join belong to that join group.

This creates a strict boundary:

> A join target can only consume inputs from the join group that was created for its current join instance.

### 7.3 Two group identifiers
At runtime, each process instance carries two relevant identifiers:

- **JoinGroupID**: the group the process belongs to (its “current scope”).
- **JoinFromGroupID** (join targets): the group from which the join target accepts deliveries.

Key point:
- The **join target step** itself stays in the *parent* scope (it belongs to the same JoinGroupID as its parent branch).
- But it accepts join deliveries from the *child* join group (JoinFromGroupID), i.e., from the producer set created by the join declaration.

This separation allows nested joins without collisions.

### 7.4 Example: Nested joins, join scopes, and non-deterministic kills (ASAP)

This example shows **two joins in series** and explains why **producer scoping matters**.

Key rule to remember:

- A join creates a **fresh producer join group** (call it `G#N`).
- **All spawns in the same branch that declares the join** are treated as the join’s *producers* and are associated to that `G#N`.
- The join target will accept deliveries **only** from producers that carry that same `G#N` (`JoinFromGroupID = G#N`).

If you declare a join that references producers which were spawned **earlier**, those producers are typically in a **different join group**, and the join would become **unfulfillable**.

#### Orchestration JSON

```json
{
  "id": "nested_join_example",
  "structure": {
    "A1": {
      "rule": "${addr:XRC137_A}",
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

    "G1": { "rule": "${addr:XRC137_G}" },
    "H1": { "rule": "${addr:XRC137_H}" },

    "J1": {
      "rule": "${addr:XRC137_J1}",
      "onValid": {
        "spawns": ["P1", "Q1"],
        "join": {
          "joinid": "J2",
          "mode": "all",
          "waitonjoin": "kill",
          "from": [
            { "node": "P1", "when": "valid" },
            { "node": "Q1", "when": "valid" }
          ]
        }
      }
    },

    "P1": { "rule": "${addr:XRC137_P}" },
    "Q1": { "rule": "${addr:XRC137_Q}" },

    "J2": {
      "rule": "${addr:XRC137_J2}",
      "onValid": { "spawns": ["Z1"] }
    },

    "Z1": { "rule": "${addr:XRC137_Z}" }
  }
}
```

#### Walk-through (who spawns whom, and which join group they are in)

1. `A1` finishes with `onValid`.
2. `A1.onValid` declares join `J1` and spawns `G1` and `H1` **in the same branch**.

3. Declaring join `J1` creates a fresh producer group **G#1**:
   - `G1.JoinGroupID = G#1`
   - `H1.JoinGroupID = G#1`
   - Join target `J1` is opened with `JoinFromGroupID = G#1` and will only accept deliveries from `G#1`.

4. `G1` and `H1` run concurrently.
   - When either of them completes with `when="valid"`, it **delivers** to `J1`.
   - The manager will only route this delivery to join targets where `JoinFromGroupID` matches the producer’s `JoinGroupID` (here: `G#1`).

5. `J1.mode = "any"`:
   - As soon as *one* of `{G1(valid), H1(valid)}` arrives, the join condition is satisfied.
   - `J1` is released and scheduled to execute.

6. `waitOnJoin = "kill"` on `J1`:
   - The manager will emit kill intents for the remaining producers in this join (e.g., `H1` if `G1` already satisfied the join).
   - **Important:** kills are **ASAP** and therefore **not deterministic** in timing.
     - A “killed” producer might still run for a short time, might even finish, or might deliver a result racing with the kill.
     - Late deliveries that arrive after the join has already been satisfied are **ignored** for that join.

7. `J1` executes `onValid`.

8. `J1.onValid` declares a second join `J2` **and** spawns `P1` and `Q1` **in the same branch**.

9. Declaring join `J2` creates a fresh producer group **G#2**:
   - `P1.JoinGroupID = G#2`
   - `Q1.JoinGroupID = G#2`
   - Join target `J2` is opened with `JoinFromGroupID = G#2`.

10. `P1` and `Q1` run concurrently and deliver to `J2` (only accepted from `G#2`).

11. `J2.mode = "all"`:
   - `J2` is released only after **both** `{P1(valid), Q1(valid)}` have delivered (within group `G#2`).

12. `J2` executes and spawns `Z1`.

#### Why this example is satisfiable (and the common pitfall)

- `P1` and `Q1` must be spawned in the same branch where join `J2` is declared, so they receive `JoinGroupID = G#2`.
- If `P1` and `Q1` were spawned earlier (e.g., by `G1`/`H1`), they would inherit `JoinGroupID = G#1`.
  In that case, `J2` would still expect `JoinFromGroupID = G#2`, would reject deliveries from `G#1`, and the join would never complete.

That is the operational meaning of **join scopes**: each join has its own producer group, and join targets only accept deliveries from that exact group.


## 8. Join delivery and selection semantics

### 8.1 Delivery trigger
A join delivery is considered whenever a producer process instance reaches a step that could satisfy a join’s `from.node`, and its outcome matches `from.when`.

Delivery is addressed to a join target that:
1. Is in the same session/root context, and
2. Has a JoinFromGroupID that matches the producer’s JoinGroupID, and
3. Is currently open (not closed).

### 8.2 What is delivered
The join target receives a **payload snapshot** of the producer at that moment (a plain key-value object).

Each producer may deliver **at most once** to the join target (per join instance).

### 8.3 Selection order is deterministic by `from` list
When the join target becomes eligible to proceed, it selects producers in the order defined by the `from` list.

- `mode="any"` is equivalent to `k=1`
- `mode="all"` is equivalent to `k=len(from)`
- `mode="kofn"` uses the explicit `k`

The join target proceeds once it can select **K** entries from the `from` list whose deliveries exist **and** satisfy the `when` constraint.

### 8.4 Merge semantics
The join target constructs an input payload by merging selected producer payloads in `from` order.

If multiple producers provide the same key, **later merges overwrite earlier keys** (because the merge is applied in a sequence).

Practical implication:
- To avoid ambiguity, designs should minimize overlapping key names across producer payloads unless overwriting is intended.

### 8.5 Join closes
Once the join target can select K producers:
- the join is marked **closed**, and
- the join target becomes runnable again (it can proceed to execute its own step rule).

From this point on, additional producer deliveries are ignored for this join instance.

---

## 9. When joins become impossible (unfulfillable joins)

A join can be aborted as **unfulfillable** if it becomes impossible to satisfy the required K-of-N conditions.

Typical reasons:
- Too many producers terminated (DONE/ABORTED) without delivering a qualifying outcome.
- Producers are in steps that can no longer reach the required `from.node` steps (based on reachability in the orchestration graph).
- A producer reaches the `from.node` step but with an outcome that does not match `when` and it cannot reach it again.

The manager may use **reachability analysis** (based on the orchestration graph) to decide whether remaining processes can still satisfy missing expectations.

If the join becomes unfulfillable, the join target transitions to **ABORTED**.

---

## 10. `waitonjoin` policies and the “ASAP kill” behavior

### 10.1 `waitonjoin="drain"`
- The join target proceeds as soon as it has enough deliveries.
- Other producers are **not actively aborted**.
- Producers may continue running to completion.
- Their results do not affect the already-closed join.

This is the “let the parallel work finish” policy.

### 10.2 `waitonjoin="kill"` (ASAP, non-deterministic timing)
- As soon as the join target closes (has K deliveries), the manager **attempts** to abort remaining join producers.

Important nuance:

> The kill is **ASAP** (as soon as the manager observes the join close), but not strictly deterministic in timing, because execution is parallel.

Concretely:
- Producers that are still in **WAITING** state can be aborted immediately.
- Producers already in **RUNNING** state may not be aborted (they may finish anyway).
- Therefore, which exact subset gets aborted can vary with scheduling and timing.

Even with this non-determinism:
- Safety is preserved: the join is closed; further deliveries do not change the join result.
- Auditability is preserved: the join result is determined by the selected producers and the join mode.

### 10.3 What “kill” means semantically
“Kill” means:
- “Stop spending resources on producers that are no longer needed for this join.”

It does **not** mean:
- “All remaining branches are guaranteed to terminate instantly.”

---

## 11. Join lifecycle summary (step-by-step)

1. A branch declares a join to target `J`.
2. xDaLa creates a fresh join group for the join’s producers.
3. The join target is created/opened and configured with:
   - required K (derived from mode/k)
   - required `from` list
   - JoinFromGroupID (the fresh group)
4. Producers run; qualifying producers deliver payload snapshots to the join target.
5. When the join target can select K producers:
   - it merges payloads in `from` order
   - it closes
   - it becomes runnable to execute its own XRC-137 step
6. If `waitonjoin="kill"`, remaining waiting producers in that join group are aborted ASAP.
7. If the join becomes impossible, the join target aborts.

---

## 12. Practical guidance for orchestration authors

- Prefer explicit naming conventions for keys to avoid merge overwrites in joins.
- Use `mode="kofn"` when partial completion is acceptable and you want resilience to individual branch failure.
- Use `waitonjoin="kill"` for cost control; expect ASAP behavior, not perfectly synchronized termination.
- Avoid deeply nested joins unless needed; when you do nest, rely on join scoping to maintain correctness.

---

## 13. Appendix: minimal join example

```jsonc
"A1": {
  "rule": "0x...A",
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
"J1": {
  "rule": "0x...J",
  "onValid": { "spawns": ["Z1"] },
  "onInvalid": {}
}
```

Semantics:
- Spawn `G1` and `H1` in parallel.
- Proceed to `J1` as soon as the first of them completes valid.
- Abort the still-waiting remainder ASAP (if applicable).
