# XGR Encryption & Grants — Developer Guide (XRC-137 + XRC-563)

> This document explains the end-to-end encryption model used by XGR for rules (XRC-137) and logs, the on-chain Grants/Key registry (standardized as **XRC-563**), the JSON-RPC surface, cryptography, gas/cost accounting, and the operational flows for encrypting, decrypting, granting, revoking and sweeping. It’s designed to be exhaustive and implementation-agnostic (no Go code required).

---

## High-level overview

- **What is protected?**
  - **XRC-137** rule payloads (the “contracted rules JSON”) and **engine-emitted logs**.
- **How is it protected?**
  - A random **DEK** (32 bytes) encrypts the data with **AES-GCM-256**.
  - The DEK is wrapped per-recipient as an **EncDEK** using **ECDH(P-256) + HKDF-SHA256 → AES-GCM-256**.
- **Where are keys and grants kept?**
  - **XRC-563 (Grants/Key Registry)** smart-contract:
    - Keeps a per-owner **Read-Public-Key** (SEC1 P-256).
    - Stores **grants**: `(RID, recipient) → EncDEK + rights + expiry`.
    - Exposes view functions for reading and pricing, and mutations for upserting/removing.
- **Two scopes** (context for key derivation and authorization):
  - **Scope 1 (OWNER)** – protects a rule’s encrypted XRC-137 (the owner’s domain).
  - **Scope 2 (RID)** – protects an individual *log bundle* emitted by the engine for a given rule RID.

---

## Cryptography (one scheme)

### Building blocks
- **Curve:** NIST P-256 (ECDH).
- **KDF:** HKDF with SHA-256.
- **Symmetric:** AES-GCM-256 (12-byte IV, 16-byte tag).
- **Data key (DEK):** 32 bytes, randomly generated.
- **Context string (HKDF “info”):**
  ```
  "XGR|v=1|scope=<S>|rid=<RID-hex>|alg=<n>"
  ```
  where:
  - `S` ∈ {1,2} is the scope (OWNER or RID),
  - `RID-hex` is the 32-byte RID in lowercase hex without 0x,
  - `n = 3` (identifier for P-256/HKDF-SHA256/AES-GCM).

> The HKDF **salt** is included in the `EncDEK` (per-wrap randomness). The IV is per-wrap for AES-GCM.

### EncDEK tuple (on-chain ABI)
A single wrapped DEK is encoded as:

| Field     | Type      | Meaning                                            |
|-----------|-----------|----------------------------------------------------|
| `alg`     | `uint8`   | `3` (P-256/HKDF-SHA256/AES-GCM)                    |
| `kemMode` | `uint8`   | `4` (uncompressed SEC1 65-B ephemeral public key)  |
| `kemX`    | `bytes32` | X coordinate of ephemeral pubkey                   |
| `kemY`    | `bytes32` | Y coordinate of ephemeral pubkey                   |
| `salt`    | `bytes16` | HKDF salt                                          |
| `iv`      | `bytes12` | AES-GCM IV                                         |
| `ct`      | `bytes32` | DEK ciphertext                                     |
| `tag`     | `bytes16` | AES-GCM tag                                        |

> To unwrap, a recipient uses their **Read-Private-Key** (on the client/device) + the writer’s ephemeral public key from the EncDEK to perform ECDH, then HKDF with the *exact* `scope` and `rid` context to get the KEK for AES-GCM decryption of the DEK.

---

## Data formats

### XGR1 encrypted payload (for rules and logs)
- **Format:** textual envelope `XGR1.AESGCM256.<reserved>.<base64>`.
- **Body (`base64`) layout:** `nonce(12B) || ciphertext || tag(16B)`.
- **Plaintext:** canonical JSON (rule) or log bundle.

## XRC-137 on-chain storage of `suite` and `rid`

- The **XRC-137** rule contract **persists** the encryption **`suite`** (e.g., `"AESGCM256"`) and the **`rid`** (bytes32) **alongside the encrypted blob**.
- The contract’s read path typically exposes a view (e.g., `encrypted()`) that returns **`(rid, suite)`** for the committed rule, allowing indexers and clients to resolve the correct RID and cipher suite.
- **Writers must store all three fields** when committing a new encrypted rule version:
  1) `blob` (the `XGR1` envelope), 2) `suite` (string identifier), 3) `rid` (bytes32).
- Persisting `rid` on-chain binds the encrypted content to its identity and aligns the grants lookup (`getGrantByRID(rid, who)`) with rule metadata.

---

## XRC-563 (Grants/Key Registry) — Contract interface

> *Naming note:* the current Grants contract standardizes to **XRC-563**.

### Key registry
- `registerReadKey(bytes pubkey)`  
  Registers the owner’s Read-Public-Key (SEC1 P-256; 65-byte uncompressed recommended).
- `getReadKey(address owner) view returns (bytes pubkey)`  
  Returns the owner’s registered key (empty if none).
- `clearReadKey()`  
  Deletes the caller’s Read-Public-Key.

### Grants (core getters)
- `getGrantByRID(bytes32 rid, address rcpt) view returns (EncDEK enc, uint8 rights, uint64 expireAt)`  
  Lookup for *(RID, recipient)* within the current scope of that RID (scope is bound to the RID on write; callers don’t pass it here).
- `ridMeta(bytes32 rid) view returns (address ref, uint8 scope)`  
  Returns the *ref namespace (rule contract)* and the *scope* the RID is bound to.
- `ridRecipients(bytes32 rid) view returns (address[] recipients)`  
  Enumerates all recipients known for that RID.

### Grants (enumeration by owner)
- `grantsCount(address owner) view returns (uint256)`  
- `grantAt(address owner, uint256 index) view returns (ref, rid, scope, rights, expireAt, EncDEK enc)`

### Grants (pricing and maintenance)
- `quoteGrantCost(bytes32 rid, address rcpt, uint64 expireAt) view returns (uint256 feeWei, uint64 pricePerDay, uint64 maxDays)`  
  Price for writing/updating a single recipient grant until `expireAt`. (Setting `rights=0` is free.)
- `sweepRID(bytes32 rid, uint256 max) returns (uint256 removed)`  
  Removes expired / revoked (rights=0) recipients from the `rid → [recipients]` index; bounded by `max` to limit gas.

### Grants (mutation)
- `upsertGrantsBatch(address ref, bytes32 rid, uint8 scope, address[] rcpts, EncDEK[] encs, uint8[] rightsArr, uint64[] expireAtArr)`  
  Creates or updates grants in one shot.  
  **Rules:**
  - All arrays must have equal length `N ≥ 1`.
  - **Value:** attach `Σ feeWei` for entries where `rights > 0` (sum of `quoteGrantCost(...)` per recipient).
  - **Revoke:** set `rights = 0` (no fee, grant becomes inert and will be swept later).
  - The first writer for a new `rid` may be given `MANAGE` automatically for the first RID entry by policy (owner bootstrap).  **This first grant is permissionless** (see details below).

### Rights bitmask (uint8)
- `READ = 1`, `WRITE = 2`, `MANAGE = 4`.  
  Typical owner grant is `READ|WRITE` for rules; `MANAGE` governs sub-grants and maintenance.

---

## Scopes (why there are two)

- **Scope 1 (OWNER):** binds encryption to the *rule owner domain*. Used for **XRC-137** rules. The EncDEK is derived with `scope=1`, so only the owner key material can unwrap the rule DEK.
- **Scope 2 (RID):** binds encryption to a *specific rule RID*. Used for **engine-emitted logs**. The EncDEK is derived with `scope=2`, isolating each RID’s log stream.

This split lets you keep a stable, owner-bound secret for rule content while rotating distinct, RID-bound secrets for logs.

---

## End-to-end flows

### 1) Registering a Read-Public-Key (one-time per owner)
1. Generate a P-256 keypair; keep the private key local (device/secure storage).
2. Call `registerReadKey(pubkey)` to publish the SEC1 public key on-chain.
3. Wallet signs and sends; after confirmation, other parties can wrap DEKs for you.

> **Tip:** Vendor tooling should verify that a recipient has a registered key (`getReadKey`) before attempting to grant to them.

---

### 2) Encrypting and committing an **XRC-137** rule (Scope 1)

**Inputs:** rule contract address `ref`, canonical rule JSON.

**Process:**
1. Create random **DEK**; encrypt JSON with **AES-GCM-256** → **XGR1** blob.
2. Compute or retrieve the **RID** for this encrypted rule instance (the contract exposes an `encrypted()` view returning `(rid, suite)` after commit).
3. Derive HKDF **info** with `scope=1` and that RID.
4. Wrap the DEK for the **owner**:
   - Fetch owner’s Read-Public-Key from `getReadKey(owner)`.
   - Perform ECDH(P-256), HKDF-SHA256(info, salt), AES-GCM-256 → **EncDEK**.
5. Persist on-chain:
   - Commit the **XGR1** blob **and persist `suite` and `rid`** to the XRC-137 contract (per that contract’s write method; contracts typically also expose a view such as `encrypted()` returning `(rid, suite)`).
   - Upsert the owner’s grant for `rid` with `scope=1` via `upsertGrantsBatch` (arrays of length 1).

> **RPC-centric clarification (authoritative path):**  
> While the cryptographic steps above describe the inner mechanics, **in practice you should use the JSON-RPC** to perform the preparation for encrypted rules:
>
> 1. Call **`xgr_encryptXRC137({ address: ref, owner, json, grantExpireAt })`**.  
>    This RPC performs the encryption, constructs the owner’s EncDEK for **scope=1**, computes/assigns the **RID**, and returns `{ rid, suite, blob, updateTx[] }` where each `updateTx` contains the grants contract call and the **fee** (value) derived from `quoteGrantCost`.
> 2. Commit the returned **XGR1** `blob` **and write `suite` + `rid`** to your **XRC-137** contract using its write method for rules.  
> 3. Either submit the returned `updateTx[]` as-is, or invoke a helper (e.g., **`xgr_upsertGrant`**) to write the **first grant** for this **RID**.
>
> **Permissionless first grant:** The **first grant for a new RID** can be submitted **permissionlessly**. This is safe because the **RID is unique and not guessable/predictable** before the ciphertext exists; the contract may also bootstrap `MANAGE` to the first RID entry by policy. This enables unattended pipelines (e.g., your backend) to finalize the owner’s grant right after rule encryption without prior on-chain state.

**Costing:**
- Before sending, call `quoteGrantCost(rid, owner, expireAt)` and attach `feeWei` as `tx.value`.
- If you are sending the grant and a separate engine operation together, budget gas/fees accordingly (see “Gas reimbursement”).

**Decrypt later:**
- Owner looks up `getGrantByRID(rid, owner)` → `EncDEK`.
- Unwrap DEK locally (P-256/HKDF/AES-GCM) with `scope=1`, then decrypt the **XGR1** blob to plaintext JSON.

---

### 3) Engine-encrypted **logs** (Scope 2)

When a step runs on the engine for a rule with encryption enabled:
1. The engine collects the *log bundle* (payload, apiSaves, contractSaves).
2. It creates a new **DEK** and encrypts the bundle to **XGR1**.
3. It computes `RID` (the rule’s RID) and derives HKDF `info` with `scope=2`.
4. It **wraps the DEK for the owner only** (EncDEK), and **prepares** the corresponding grant write *(see the ordering rule below)*.
5. It emits an `EngineExtrasV2(gasUsed, extrasJSON)` event where `extrasJSON.engineEncrypted` minimally contains:
   - `rid` (0x…32 bytes),
   - `suite` (e.g., `"AESGCM256"`),
   - `blob` (the XGR1 string).
6. **Ordering & safety:**  
   The engine **first** computes the required wrap gas and validates budget *(including gas to write the pending grant)*. **Only if** all checks pass, it:
   - sends the grants upsert transaction (owner’s grant, `scope=2`), **then**
   - calls the precompile to wrap and execute the step with the computed `wrapGas`.

> **RPC-centric flow for log decryption:**  
> Clients should not reconstruct steps manually. Instead:
> 1. Discover encrypted log metadata via **`xgr_getEncryptedLogInfo({ txHash, owner })`** to obtain `{ rid, blob }` (and the rule contract address).  
> 2. Fetch the EncDEK with **`getGrantByRID(rid, owner)`** on **XRC-563** (or use a convenience endpoint like `xgr_getGrantsByRID`).  
> 3. Unwrap the DEK with **scope=2** and decrypt the **XGR1** `blob`.  
>
> Engine-side encryption, fee quoting, gas budgeting, and the **ordering** (grant TX → precompile call) are handled automatically by the engine. The client only needs to resolve `{ rid, blob }` and read the owner’s grant to decrypt.

**Decrypt later:**
- Read the owner’s `EncDEK` with `getGrantByRID(rid, owner)`.
- Unwrap DEK with `scope=2`.
- Decrypt the `XGR1` blob from `EngineExtrasV2`.

---

### 4) Granting access to another recipient

**Scenario:** The owner wants a collaborator to decrypt a rule or its logs.

1. Ensure the recipient has registered a Read-Public-Key (`getReadKey(rcpt)`).
2. Owner **rewraps** the rule/log DEK for `rcpt` using `scope` and `rid`:
   - Perform P-256 ECDH with recipient pubkey (ephemeral sender key),
   - HKDF-SHA256(info),
   - AES-GCM-256 to produce an **EncDEK** for `rcpt`.
3. Submit:
   - `upsertGrantsBatch(ref, rid, scope, [rcpt], [enc], [rights], [expireAt])`
   - Attach `value = quoteGrantCost(rid, rcpt, expireAt).feeWei`.
   - Or call a helper RPC such as **`xgr_upsertGrant`** that performs quoting and submission for you.
4. Recipient can now read:
   - `getGrantByRID(rid, rcpt)` → unwrap DEK → decrypt **XGR1**.

**Revoke:** call `upsertGrantsBatch(...)` with `rights = 0` (no value needed). It’s free and leaves a tombstone which the sweeper can remove.

---

### 5) Sweeper (maintenance)

- Call `sweepRID(rid, max)` to prune the `rid → [recipients]` index by removing entries that are **expired** or **rights=0**.
- This keeps iteration costs predictable and storage clean.
- Choose `max` conservatively to stay within gas limits; repeat if needed.

---

## Gas reimbursement & safety

### Why budgeting matters
The engine may have to pay two things during validation:
1. **Grant write cost** (in **value** for XRC-563, proportional to days until expiry), and
2. **Transaction gas** (both for the grant write and for the engine precompile call).

To ensure the engine is not left out-of-pocket, its wrapper **includes an extra gas budget** that matches the external cost of writing the pending grant.

### How budgeting works (deterministic & fail-closed)
1. **Quote the fee**: call `quoteGrantCost(rid, owner, expireAt)` → `feeWei`.
2. **Convert fee to gas units**: divide by the session **gasPriceWei**, use ceiling:  
   `extraGasFee = ceil(feeWei / gasPriceWei)`.
3. **Estimate grant gas** (non-value component): simulate `upsertGrantsBatch` with the prepared calldata to get `extraGasGrant`.
4. **Sum & add**: `extra = extraGasFee + extraGasGrant`; increase the engine’s `validationGas` by `extra`.
5. **Compute wrap gas** from payload size and `validationGas`; **reject** if it exceeds `MAX_WRAP_GAS`.  
   *If rejected*, **do not** send the grant (fail-closed: nothing gets written).
6. **Send order**:
   - First write the pending **grant** (attach `feeWei`).
   - Then invoke the engine precompile with the validated `wrapGas`.

**Invariants:**
- No grant is written if the wrapper would fail (e.g., *“wrap gas too large exceeds MAX_WRAP_GAS”*).
- Refund logic in the precompile accounts for the engine’s `validationGas`, which now includes the grant overhead — keeping the engine whole.

**Common error:** *“fee underpaid”* on grant write means the caller forgot to attach `value = quoteGrantCost(...).feeWei` (or attached too little). Always quote **per recipient** and sum when batching.

---

## JSON-RPC surface (typical endpoints)

> Exact field names may vary by deployment; the shapes below illustrate the intent. All calls are positional **with a single object** unless noted.

### Core discovery
- `xgr_getCoreAddrs()` →  
  `{ "engineEOA": "0x…", "grants": "0x…", "precompile": "0x…", "chainId": "0x…" }`

### XRC-137 encryption lifecycle
> **Commit contract state:** When applying the result of `xgr_encryptXRC137`, your XRC-137 write **must** persist all three fields — `blob`, `suite`, and `rid` — so that subsequent calls (e.g., `encrypted()` views and indexers) can reliably resolve metadata and match grants by RID.

- `xgr_encryptXRC137({ address, owner, json, grantExpireAt })` →  
  - Encrypts the rule JSON, prepares the owner EncDEK, and returns hints for committing.
  - Response contains:
    - `rid` (bytes32 hex), `suite` (e.g. `"AESGCM256"`), `blob` (`XGR1...`),
    - `updateTx[]` (hints to set owner grant; includes `value` derived from `quoteGrantCost`),
    - `didWork`/`reason`.
- Commit the rule on the XRC-137 contract (not shown here) **and persist `rid` + `suite`**.
- Owner writes grant via on-chain call (directly or via a helper endpoint).
- `xgr_getXRC137Meta({ address, owner, scope:"1" })` →  
  `{ "rid": "0x…", "suite": "AESGCM256", "blob": "XGR1.…", "encDEK": <EncDEK> }`

### Log decryption helpers
- `xgr_getEncryptedLogInfo({ txHash, owner })` →  
  `{ "found": true, "ruleContract": "0x…", "rid": "0x…", "suite": "AESGCM256", "engineEncrypted": { "rid": "0x…", "blob": "XGR1.…" } }`  
  Use it to discover the `RID` and the `XGR1` blob. Then query `getGrantByRID(rid, owner)` on XRC-563 to fetch the EncDEK.

### Grants convenience
- `xgr_getGrantsByRID({ rid, scope, ref })` → server-side aggregation over `ridRecipients` + `getGrantByRID`.
- `xgr_upsertGrant({ ref, rid, scope, rcpt, rights, expireAt })` → helper around `upsertGrantsBatch` (attaches `value` from `quoteGrantCost`).

---

## Practical recipes

### Encrypt a rule using RPC (owner or backend)
1. Call **`xgr_encryptXRC137({ address: ref, owner, json, grantExpireAt })`** → receive `{ rid, suite, blob, updateTx[] }`.
2. Commit **`blob` + persist `suite` and `rid`** to **XRC-137** (rule write).
3. Submit `updateTx[]` to **XRC-563** (or call **`xgr_upsertGrant`**) to write the **first owner grant** for this **RID** (permissionless, safe due to unpredictable RID).
4. Verify with **`getGrantByRID(rid, owner)`** that the EncDEK is present.

### Decrypt a rule (owner)
1. `meta = xgr_getXRC137Meta({ address: ref, owner, scope:"1" })`.
2. `grant = getGrantByRID(meta.rid, owner)` on XRC-563.
3. Unwrap DEK with P-256/HKDF-SHA256 using `scope=1`, `rid=meta.rid`.
4. Decrypt `meta.blob` (XGR1) with DEK to JSON.

### Decrypt a log (owner)
1. `info = xgr_getEncryptedLogInfo({ txHash, owner })` to get `{ rid, blob }`.
2. `grant = getGrantByRID(rid, owner)`.
3. Unwrap DEK with `scope=2`; decrypt XGR1 blob.

### Grant access to a collaborator
1. Ensure `getReadKey(rcpt)` returns a valid P-256 SEC1 key.
2. Rewrap the DEK (scope+rid) for `rcpt` → new `EncDEK`.
3. `fee = quoteGrantCost(rid, rcpt, expireAt).feeWei`.
4. `upsertGrantsBatch(ref, rid, scope, [rcpt], [enc], [rights], [expireAt])` with `{ value: fee }`.

### Revoke
- `upsertGrantsBatch(…, rights=[0])` (no fee). The sweeper will clean up the index later.

---

## Costs & pricing

- Grant pricing is **time-based**: `feeWei = days * pricePerDay` (enforced by `quoteGrantCost`).
- `maxDays` caps the allowed duration; use the view return to validate UX.
- Rights changes from non-zero → non-zero may be treated as an update (still priced by remaining/extended time, per contract policy). Right to zero is free.

---

## Security notes & pitfalls

- **Scope mismatch** will produce a KEK that doesn’t match the EncDEK. Always use the correct `scope` for the content you’re decrypting (1 for rule, 2 for logs).
- **RID is part of HKDF info**, binding keys to the content identity. Use the exact RID (lowercase hex) you retrieved from metadata or events.
- **No on-chain private keys**: the Read-Private-Key never leaves the client. Only public keys are registered on-chain.
- **“fee underpaid”** on `upsertGrantsBatch` means `value` didn’t cover the price from `quoteGrantCost`. Quote **per recipient** and sum for batches.
- **Fail-closed engine wrapper**: If any budget check fails (including `MAX_WRAP_GAS`), neither grants nor precompile are executed — avoiding inconsistent side-effects.
- **Read-key mismatch**: Unwrap will raise an AES-GCM authentication failure if the local private key doesn’t match the on-chain public key (wrong seed/import).
- **Permissionless first grant (safe by design):** The first upsert for a **new RID** does not require pre-existing rights and can be sent by any party that knows the RID and the intended recipient. This is considered **safe** because RIDs are **unique and not predictable** prior to producing the ciphertext (the RID is bound to the encrypted content). Many deployments also rely on policy that assigns `MANAGE` to the first RID entry, enabling owner bootstrap without race-conditions.

---

## Reference (concise)

### Contract (XRC-563) essentials
- **Key registry**
  - `registerReadKey(bytes pubkey)`
  - `getReadKey(address owner) → bytes`
  - `clearReadKey()`
- **Grants**
  - `getGrantByRID(bytes32 rid, address rcpt) → (EncDEK, rights, expireAt)`
  - `ridMeta(bytes32 rid) → (address ref, uint8 scope)`
  - `ridRecipients(bytes32 rid) → address[]`
  - `grantsCount(address owner) → uint256`
  - `grantAt(address owner, uint256 index) → (ref, rid, scope, rights, expireAt, EncDEK)`
  - `quoteGrantCost(bytes32 rid, address rcpt, uint64 expireAt) → (feeWei, pricePerDay, maxDays)`
  - `upsertGrantsBatch(address ref, bytes32 rid, uint8 scope, address[] rcpts, EncDEK[] encs, uint8[] rights, uint64[] expireAtArr)`
  - `sweepRID(bytes32 rid, uint256 max) → (removed)`

**EncDEK struct**
```
struct EncDEK {
  uint8   alg;      // 3
  uint8   kemMode;  // 4 (uncompressed)
  bytes32 kemX;
  bytes32 kemY;
  bytes16 salt;     // HKDF salt
  bytes12 iv;       // AES-GCM IV
  bytes32 ct;       // DEK ciphertext
  bytes16 tag;      // AES-GCM tag
}
```

### Rights bitmask
- `READ = 1`, `WRITE = 2`, `MANAGE = 4`.

### Scopes
- `1` = OWNER (rules, XRC-137)
- `2` = RID (logs)

### JSON-RPC (illustrative)
- `xgr_getCoreAddrs() → { engineEOA, grants, precompile, chainId }`
- `xgr_encryptXRC137({ address, owner, json, grantExpireAt }) → { rid, suite, blob, updateTx[], didWork, reason }`
- `xgr_getXRC137Meta({ address, owner, scope:"1" }) → { rid, suite, blob, encDEK }`
- `xgr_getEncryptedLogInfo({ txHash, owner }) → { found, ruleContract, rid, suite, engineEncrypted }`
- (optional helpers) `xgr_getGrantsByRID`, `xgr_upsertGrant`

---

## FAQs

- **Do I need a Read-Key to write a rule?**  
  You need one to **grant** yourself access to the encrypted content. Without a registered Read-Public-Key, other parties cannot wrap DEKs for you.
- **Can I share only logs but not rules?**  
  Yes. Use **scope=2** for log DEKs; you can keep rule DEKs granted only to the owner.
- **What happens after expiry?**  
  Decryption *may* still work with cached EncDEK locally, but on-chain the grant is considered inactive; admins should rely on `expireAt` as policy. The sweeper cleans up storage.

---

## Implementation checklist

1. **Before encrypting:**
   - Owner has registered Read-Public-Key.
   - Decide scope (1=rule, 2=log).
2. **Encrypt:**
   - Generate DEK; AES-GCM-256 → XGR1.
   - Build `info = "XGR|v=1|scope=S|rid=…|alg=3"`.
   - Wrap DEK → EncDEK.
3. **Persist:**
   - For rules: write XGR1 blob to XRC-137 **and store `suite` + `rid`**.
   - For logs: emit `EngineExtrasV2` with minimal `{ rid, suite, blob }`.
4. **Grant:**
   - Quote cost per recipient; attach `value` and upsert.
5. **Engine wrapper (if applicable):**
   - Add `ceil(feeWei/gasPrice) + estimateGas(grants write)` to `validationGas`.
   - Abort early if `wrapGas > MAX_WRAP_GAS`.
   - Send grant → precompile call (in that order).
6. **Maintenance:**
   - Run `sweepRID(rid, max)` periodically.

---

## Glossary

- **DEK** — Data Encryption Key (32-byte secret).
- **EncDEK** — DEK wrapped for a specific recipient and scope using P-256/HKDF/AES-GCM.
- **RID** — 32-byte identifier of an encrypted rule/log namespace.
- **Scope** — Context binding (1=OWNER for rules, 2=RID for logs).
- **XGR1** — Envelope format for encrypted payloads.
- **XRC-137** — Rule contract interface that stores the encrypted rule.
- **XRC-563** — Grants + Read-Key registry contract interface.
- **Sweeper** — Contract function that prunes expired/zero-rights recipients from the `rid → [recipients]` index.

---

# Addendum — Publication & Expansion (added content only)

## Document versioning & publication

- **Document ID:** `XGR-ENC-GRNTS`  
- **Versioning:** semantic, `MAJOR.MINOR.PATCH` (breaking/compatible/clarification-only).  
- **Header block:** include `Doc-ID`, `Version`, `Date`, `Target Chain(s)`, `Contract Standard (XRC-563)`.  
- **Distribution:** publish as Markdown (this file), plus generated HTML/PDF; host under `/docs/security/xgr-encryption/` with a changelog.  
- **Status labels:** `DRAFT`, `RC`, `STABLE`.  

## Normative requirements (MUST / SHOULD)

**Keys**
- Operators **MUST** register a SEC1 uncompressed P-256 public key before expecting to receive grants.  
- Clients **MUST** verify `getReadKey(who)` returns exactly 65 bytes.  
- Private keys **MUST NOT** leave the client/device.

**Encapsulation**
- Wrapping **MUST** use P-256 ECDH, HKDF-SHA256 with `info = "XGR|v=1|scope=<S>|rid=<RID>|alg=3"`, and AES-GCM-256 for the DEK.  
- `scope` **MUST** be `1` for rules and `2` for logs.  
- `rid` in HKDF `info` **MUST** match the RID in the XGR1 header and the grants lookup.

**Grants**
- Writers **MUST** call `quoteGrantCost` per recipient and attach `value = Σ feeWei` to `upsertGrantsBatch`.  
- Revocation **MUST** be performed by setting rights to `0` (no fee).  
- Index maintenance **SHOULD** call `sweepRID` periodically with bounded `max`.

**Engine budgeting**
- The engine **MUST** convert `feeWei` to `extraGasFee = ceil(feeWei/gasPriceWei)` and **MUST** add `extraGasGrant = estimateGas(upsertGrantsBatch)` to `validationGas`.  
- The engine **MUST** refuse to proceed if `wrapGas > MAX_WRAP_GAS`.  
- The engine **MUST** send the grants TX **before** invoking the precompile, only after budget checks pass.

**Security**
- Implementations **MUST** treat missing EncDEK (e.g., `alg==0`) as “no grant”.  
- Clients **MUST** fail closed on AES-GCM authentication failure.  
- Tooling **SHOULD** avoid caching decrypted plaintext beyond session needs.

## Expanded JSON-RPC examples (request/response)

### `xgr_getCoreAddrs()`
**Request**
```json
{}
```
**Response**
```json
{
  "engineEOA":    "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
  "grants":       "0x1111111111111111111111111111111111111111",
  "precompile":   "0x00000000000000000000000000000000000000F1",
  "chainId":      "0x45B"
}
```

### `xgr_encryptXRC137`
**Request**
```json
{
  "address": "0xABCD00000000000000000000000000000000ABCD",
  "owner":   "0xF39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "json":    "{\"version\":1,\"rules\":[{\"if\":\"x>0\",\"then\":\"ok\"}]}",
  "grantExpireAt": 1767225600
}
```
**Response (excerpt)**
```json
{
  "didWork": true,
  "rid":  "0x8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2",
  "suite":"AESGCM256",
  "blob": "XGR1.AESGCM256.0x8c1a...b2.b64(YWJj....)",
  "updateTx": [
    {
      "to":    "0x1111111111111111111111111111111111111111",
      "data":  "0x5e954e2c...",
      "value": "0x0de0b6b3a7640000"
    }
  ],
  "reason": "ok"
}
```

### `xgr_getXRC137Meta`
**Request**
```json
{ "address":"0xABCD00000000000000000000000000000000ABCD", "owner":"0xF39F...", "scope":"1" }
```
**Response**
```json
{
  "rid":   "0x8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2",
  "suite": "AESGCM256",
  "blob":  "XGR1.AESGCM256.0x8c1a...b2.b64(...)",
  "encDEK": "0x03 04 <kemX> <kemY> <salt> <iv> <ct> <tag>"
}
```

### `xgr_getEncryptedLogInfo`
**Request**
```json
{ "txHash":"0xdea...f00", "owner":"0xF39F..." }
```
**Response**
```json
{
  "found": true,
  "ruleContract": "0xABCD00000000000000000000000000000000ABCD",
  "rid":   "0x8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2",
  "suite": "AESGCM256",
  "engineEncrypted": {
    "rid":  "0x8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2",
    "blob": "XGR1.AESGCM256.0x8c1a...b2.b64(...)"
  }
}
```

### `xgr_upsertGrant`
**Request**
```json
{
  "ref":   "0xABCD00000000000000000000000000000000ABCD",
  "rid":   "0x8c1a...a1b2",
  "scope": 2,
  "rcpt":  "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
  "rights": 3,
  "expireAt": 1767225600
}
```
**Response**
```json
{ "sent": true, "txHash": "0x38f...abc" }
```

### `xgr_getGrantsByRID`
**Request**
```json
{ "rid":"0x8c1a...a1b2", "scope":2, "ref":"0xABCD..." }
```
**Response (excerpt)**
```json
{
  "rid": "0x8c1a...a1b2",
  "recipients": [
    {
      "rcpt": "0xF39F...",
      "rights": 3,
      "expireAt": 1767225600,
      "encDEK": "0x03 04 <kemX> <kemY> <salt> <iv> <ct> <tag>"
    }
  ]
}
```

## Contract call examples (ABI shapes)

### `getGrantByRID`
```
inputs:  (bytes32 rid, address rcpt)
returns: (EncDEK enc, uint8 rights, uint64 expireAt)
```
**Sample values**  
`rid = 0x8c1a2b53…a1b2`  
`rcpt = 0xF39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

### `quoteGrantCost`
```
inputs:  (bytes32 rid, address rcpt, uint64 expireAt)
returns: (uint256 feeWei, uint64 pricePerDay, uint64 maxDays)
```
**Expected**: `feeWei > 0` if `rights > 0`; `feeWei = 0` for revocation (rights=0).

### `upsertGrantsBatch`
```
inputs:
  address   ref,
  bytes32   rid,
  uint8     scope,
  address[] rcpts,
  EncDEK[]  encs,
  uint8[]   rightsArr,
  uint64[]  expireAtArr
value: Σ quoteGrantCost(rid, rcpt[i], expireAt[i]).feeWei for rightsArr[i] > 0
```

## Format-level test vectors (illustrative)

> The following are **format/shape** test vectors for parsers and serializers; they are not cryptographically linked and will not decrypt to meaningful plaintext. Use them to validate ABI/JSON parsing, XGR1 framing, and EncDEK field handling.

**HKDF info strings**
```
Scope 1: "XGR|v=1|scope=1|rid=8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2|alg=3"
Scope 2: "XGR|v=1|scope=2|rid=8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2|alg=3"
```

**EncDEK (hex, concatenated as fields)**
```
alg      : 03
kemMode  : 04
kemX     : 0x8f1e2d3c4b5a69788796a5b4c3d2e1f0aa55aa55aa55aa55aa55aa55aa55aa5
kemY     : 0x19e2d3c4b5a69788796a5b4c3d2e1f0aa55aa55aa55aa55aa55aa55aa55aa551
salt     : 0x11223344556677889900aabbccddeeff
iv       : 0x000102030405060708090a0b
ct       : 0xaabbccddeeff00112233445566778899aabbccddeeff001122334455667788
tag      : 0x0102030405060708090a0b0c0d0e0f10
```

**XGR1 envelope (structure)**
```
XGR1.AESGCM256.0x8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2.
BASE64( 0x000102030405060708090a0b || 0xaabbcc...7788 || 0x0102030405060708090a0b0c0d0e0f10 )
```

## Documentation packaging (ready-to-publish)

**Suggested structure (Docsify/Sphinx friendly):**
```
/docs
  /xgr-encryption
    index.md                 # overview + ToC
    cryptography.md          # suite, EncDEK, XGR1, HKDF info
    xrc-563.md               # contract interface (keys, grants, sweep, pricing)
    xrc-137.md               # rule lifecycle, scope 1
    engine-logs.md           # scope 2 flow, extras, reimbursement
    rpc.md                   # JSON-RPC, request/response, errors
    ops.md                   # maintenance, sweeper, monitoring
    security.md              # threat model, fail-closed, key hygiene
    changelog.md
```

**Front-matter example:**
```yaml
---
doc_id: XGR-ENC-GRNTS
version: 1.0.2
status: STABLE
updated: 2025-10-10
contracts:
  - XRC-137
  - XRC-563
---
```

## Changelog (seed)
- **1.0.2** – clarify that **XRC-137 stores `suite` and `rid`** along with the encrypted blob, integrate this into the Scope‑1 flow, RPC recipes, and JSON‑RPC lifecycle notes.  
- **1.0.1** – add RPC-centric end-to-end flows and clarify **permissionless first grant** for a new RID (safe by design due to non-predictable RID).  
- **1.0.0** – initial stable publication; single crypto suite (P-256/HKDF-SHA256/AES-GCM), two scopes (1=owner, 2=rid), grants registry as XRC-563, deterministic engine budgeting and ordering.
