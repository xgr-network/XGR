XGR Encryption & Grants — Developer Guide (XRC-137 + XRC-563)

This document explains the end-to-end encryption model used by XGR for rules (XRC-137) and logs, the on-chain Grants/Key registry (standardized as XRC-563), the JSON-RPC surface, cryptography, gas/cost accounting, and the operational flows for encrypting, decrypting, granting, revoking and sweeping. It’s designed to be exhaustive and implementation-agnostic (no Go code required).

High-level overview

What is protected?

XRC-137 rule payloads (the “contracted rules JSON”) and engine-emitted logs.

How is it protected?

A random DEK (32 bytes) encrypts the data with AES-GCM-256.

The DEK is wrapped per-recipient as an EncDEK using ECDH(P-256) + HKDF-SHA256 → AES-GCM-256.

Where are keys and grants kept?

XRC-563 (Grants/Key Registry) smart-contract:

Keeps a per-owner Read-Public-Key (SEC1 P-256).

Stores grants: (RID, recipient) → EncDEK + rights + expiry.

Exposes view functions for reading and pricing, and mutations for upserting/removing.

Two scopes (context for key derivation and authorization):

Scope 1 (OWNER) – protects a rule’s encrypted XRC-137 (the owner’s domain).

Scope 2 (RID) – protects an individual log bundle emitted by the engine for a given rule RID.

Cryptography (one scheme)
Building blocks

Curve: NIST P-256 (ECDH).

KDF: HKDF with SHA-256.

Symmetric: AES-GCM-256 (12-byte IV, 16-byte tag).

Data key (DEK): 32 bytes, randomly generated.

Context string (HKDF “info”):

"XGR|v=1|scope=<S>|rid=<RID-hex>|alg=<n>"


where:

S ∈ {1,2} is the scope (OWNER or RID),

RID-hex is the 32-byte RID in lowercase hex without 0x,

n = 3 (identifier for P-256/HKDF-SHA256/AES-GCM).

The HKDF salt is included in the EncDEK (per-wrap randomness). The IV is per-wrap for AES-GCM.

EncDEK tuple (on-chain ABI)

A single wrapped DEK is encoded as:

Field	Type	Meaning
alg	uint8	3 (P-256/HKDF-SHA256/AES-GCM)
kemMode	uint8	4 (uncompressed SEC1 65-B ephemeral public key)
kemX	bytes32	X coordinate of ephemeral pubkey
kemY	bytes32	Y coordinate of ephemeral pubkey
salt	bytes16	HKDF salt
iv	bytes12	AES-GCM IV
ct	bytes32	DEK ciphertext
tag	bytes16	AES-GCM tag

To unwrap, a recipient uses their Read-Private-Key (on the client/device) + the writer’s ephemeral public key from the EncDEK to perform ECDH, then HKDF with the exact scope and rid context to get the KEK for AES-GCM decryption of the DEK.

Data formats
XGR1 encrypted payload (for rules and logs)

Format: textual envelope XGR1.AESGCM256.<reserved>.<base64>.

Body (base64) layout: nonce(12B) || ciphertext || tag(16B).

Plaintext: canonical JSON (rule) or log bundle.

XRC-563 (Grants/Key Registry) — Contract interface

Naming note: the current Grants contract standardizes to XRC-563.

Key registry

registerReadKey(bytes pubkey)
Registers the owner’s Read-Public-Key (SEC1 P-256; 65-byte uncompressed recommended).

getReadKey(address owner) view returns (bytes pubkey)
Returns the owner’s registered key (empty if none).

clearReadKey()
Deletes the caller’s Read-Public-Key.

Grants (core getters)

getGrantByRID(bytes32 rid, address rcpt) view returns (EncDEK enc, uint8 rights, uint64 expireAt)
Lookup for (RID, recipient) within the current scope of that RID (scope is bound to the RID on write; callers don’t pass it here).

ridMeta(bytes32 rid) view returns (address ref, uint8 scope)
Returns the ref namespace (rule contract) and the scope the RID is bound to.

ridRecipients(bytes32 rid) view returns (address[] recipients)
Enumerates all recipients known for that RID.

Grants (enumeration by owner)

grantsCount(address owner) view returns (uint256)

grantAt(address owner, uint256 index) view returns (ref, rid, scope, rights, expireAt, EncDEK enc)

Grants (pricing and maintenance)

quoteGrantCost(bytes32 rid, address rcpt, uint64 expireAt) view returns (uint256 feeWei, uint64 pricePerDay, uint64 maxDays)
Price for writing/updating a single recipient grant until expireAt. (Setting rights=0 is free.)

sweepRID(bytes32 rid, uint256 max) returns (uint256 removed)
Removes expired / revoked (rights=0) recipients from the rid → [recipients] index; bounded by max to limit gas.

Grants (mutation)

upsertGrantsBatch(address ref, bytes32 rid, uint8 scope, address[] rcpts, EncDEK[] encs, uint8[] rightsArr, uint64[] expireAtArr)
Creates or updates grants in one shot.
Rules:

All arrays must have equal length N ≥ 1.

Value: attach Σ feeWei for entries where rights > 0 (sum of quoteGrantCost(...) per recipient).

Revoke: set rights = 0 (no fee, grant becomes inert and will be swept later).

The first writer for a new rid may be given MANAGE implicitly by policy (owner bootstrap).

Rights bitmask (uint8)

READ = 1, WRITE = 2, MANAGE = 4.
Typical owner grant is READ|WRITE for rules; MANAGE governs sub-grants and maintenance.

Scopes (why there are two)

Scope 1 (OWNER): binds encryption to the rule owner domain. Used for XRC-137 rules. The EncDEK is derived with scope=1, so only the owner key material can unwrap the rule DEK.

Scope 2 (RID): binds encryption to a specific rule RID. Used for engine-emitted logs. The EncDEK is derived with scope=2, isolating each RID’s log stream.

This split lets you keep a stable, owner-bound secret for rule content while rotating distinct, RID-bound secrets for logs.

End-to-end flows
1) Registering a Read-Public-Key (one-time per owner)

Generate a P-256 keypair; keep the private key local (device/secure storage).

Call registerReadKey(pubkey) to publish the SEC1 public key on-chain.

Wallet signs and sends; after confirmation, other parties can wrap DEKs for you.

Tip: Vendor tooling should verify that a recipient has a registered key (getReadKey) before attempting to grant to them.

2) Encrypting and committing an XRC-137 rule (Scope 1)

Inputs: rule contract address ref, canonical rule JSON.

Process:

Create random DEK; encrypt JSON with AES-GCM-256 → XGR1 blob.

Compute or retrieve the RID for this encrypted rule instance (the contract exposes an encrypted() view returning (rid, suite) after commit).

Derive HKDF info with scope=1 and that RID.

Wrap the DEK for the owner:

Fetch owner’s Read-Public-Key from getReadKey(owner).

Perform ECDH(P-256), HKDF-SHA256(info, salt), AES-GCM-256 → EncDEK.

Persist on-chain:

Commit the XGR1 blob to the XRC-137 contract (per that contract’s write method).

Upsert the owner’s grant for rid with scope=1 via upsertGrantsBatch (arrays of length 1).

Costing:

Before sending, call quoteGrantCost(rid, owner, expireAt) and attach feeWei as tx.value.

If you are sending the grant and a separate engine operation together, budget gas/fees accordingly (see “Gas reimbursement”).

Decrypt later:

Owner looks up getGrantByRID(rid, owner) → EncDEK.

Unwrap DEK locally (P-256/HKDF/AES-GCM) with scope=1, then decrypt the XGR1 blob to plaintext JSON.

3) Engine-encrypted logs (Scope 2)

When a step runs on the engine for a rule with encryption enabled:

The engine collects the log bundle (payload, apiSaves, contractSaves).

It creates a new DEK and encrypts the bundle to XGR1.

It computes RID (the rule’s RID) and derives HKDF info with scope=2.

It wraps the DEK for the owner only (EncDEK), and prepares the corresponding grant write (see the ordering rule below).

It emits an EngineExtrasV2(gasUsed, extrasJSON) event where extrasJSON.engineEncrypted minimally contains:

rid (0x…32 bytes),

suite (e.g., "AESGCM256"),

blob (the XGR1 string).

Ordering & safety:
The engine first computes the required wrap gas and validates budget (including gas to write the pending grant). Only if all checks pass, it:

sends the grants upsert transaction (owner’s grant, scope=2), then

calls the precompile to wrap and execute the step with the computed wrapGas.

Decrypt later:

Read the owner’s EncDEK with getGrantByRID(rid, owner).

Unwrap DEK with scope=2.

Decrypt the XGR1 blob from EngineExtrasV2.

4) Granting access to another recipient

Scenario: The owner wants a collaborator to decrypt a rule or its logs.

Ensure the recipient has registered a Read-Public-Key (getReadKey(rcpt)).

Owner rewraps the rule/log DEK for rcpt using scope and rid:

Perform P-256 ECDH with recipient pubkey (ephemeral sender key),

HKDF-SHA256(info),

AES-GCM-256 to produce an EncDEK for rcpt.

Submit:

upsertGrantsBatch(ref, rid, scope, [rcpt], [enc], [rights], [expireAt])

Attach value = quoteGrantCost(rid, rcpt, expireAt).feeWei.

Recipient can now read:

getGrantByRID(rid, rcpt) → unwrap DEK → decrypt XGR1.

Revoke: call upsertGrantsBatch(...) with rights = 0 (no value needed). It’s free and leaves a tombstone which the sweeper can remove.

5) Sweeper (maintenance)

Call sweepRID(rid, max) to prune the rid → [recipients] index by removing entries that are expired or rights=0.

This keeps iteration costs predictable and storage clean.

Choose max conservatively to stay within gas limits; repeat if needed.

Gas reimbursement & safety
Why budgeting matters

The engine may have to pay two things during validation:

Grant write cost (in value for XRC-563, proportional to days until expiry), and

Transaction gas (both for the grant write and for the engine precompile call).

To ensure the engine is not left out-of-pocket, its wrapper includes an extra gas budget that matches the external cost of writing the pending grant.

How budgeting works (deterministic & fail-closed)

Quote the fee: call quoteGrantCost(rid, owner, expireAt) → feeWei.

Convert fee to gas units: divide by the session gasPriceWei, use ceiling:
extraGasFee = ceil(feeWei / gasPriceWei).

Estimate grant gas (non-value component): simulate upsertGrantsBatch with the prepared calldata to get extraGasGrant.

Sum & add: extra = extraGasFee + extraGasGrant; increase the engine’s validationGas by extra.

Compute wrap gas from payload size and validationGas; reject if it exceeds MAX_WRAP_GAS.
If rejected, do not send the grant (fail-closed: nothing gets written).

Send order:

First write the pending grant (attach feeWei).

Then invoke the engine precompile with the validated wrapGas.

Invariants:

No grant is written if the wrapper would fail (e.g., “wrap gas too large exceeds MAX_WRAP_GAS”).

Refund logic in the precompile accounts for the engine’s validationGas, which now includes the grant overhead — keeping the engine whole.

Common error: “fee underpaid” on grant write means the caller forgot to attach value = quoteGrantCost(...).feeWei (or attached too little). Always quote per-recipient and sum when batching.

JSON-RPC surface (typical endpoints)

Exact field names may vary by deployment; the shapes below illustrate the intent. All calls are positional with a single object unless noted.

Core discovery

xgr_getCoreAddrs() →
{ "engineEOA": "0x…", "grants": "0x…", "precompile": "0x…", "chainId": "0x…" }

XRC-137 encryption lifecycle

xgr_encryptXRC137({ address, owner, json, grantExpireAt }) →

Encrypts the rule JSON, prepares the owner EncDEK, and returns hints for committing.

Response contains:

rid (bytes32 hex), suite (e.g. "AESGCM256"), blob (XGR1...),

updateTx[] (hints to set owner grant; includes value derived from quoteGrantCost),

didWork/reason.

Commit the rule on the XRC-137 contract (not shown here).

Owner writes grant via on-chain call (directly or via a helper endpoint).

xgr_getXRC137Meta({ address, owner, scope:"1" }) →
{ "rid": "0x…", "suite": "AESGCM256", "blob": "XGR1.…", "encDEK": <EncDEK> }

Log decryption helpers

xgr_getEncryptedLogInfo({ txHash, owner }) →
{ "found": true, "ruleContract": "0x…", "rid": "0x…", "suite": "AESGCM256", "engineEncrypted": { "rid": "0x…", "blob": "XGR1.…" } }
Use it to discover the RID and the XGR1 blob. Then query getGrantByRID(rid, owner) on XRC-563 to fetch the EncDEK.

Grants convenience

xgr_getGrantsByRID({ rid, scope, ref }) → server-side aggregation over ridRecipients + getGrantByRID.

xgr_upsertGrant({ ref, rid, scope, rcpt, rights, expireAt }) → helper around upsertGrantsBatch (attaches value from quoteGrantCost).

Practical recipes
Decrypt a rule (owner)

meta = xgr_getXRC137Meta({ address: ref, owner, scope:"1" }).

grant = getGrantByRID(meta.rid, owner) on XRC-563.

Unwrap DEK with P-256/HKDF-SHA256 using scope=1, rid=meta.rid.

Decrypt meta.blob (XGR1) with DEK to JSON.

Decrypt a log (owner)

info = xgr_getEncryptedLogInfo({ txHash, owner }) to get { rid, blob }.

grant = getGrantByRID(rid, owner).

Unwrap DEK with scope=2; decrypt XGR1 blob.

Grant access to a collaborator

Ensure getReadKey(rcpt) returns a valid P-256 SEC1 key.

Rewrap the DEK (scope+rid) for rcpt → new EncDEK.

fee = quoteGrantCost(rid, rcpt, expireAt).feeWei.

upsertGrantsBatch(ref, rid, scope, [rcpt], [enc], [rights], [expireAt]) with { value: fee }.

Revoke

upsertGrantsBatch(…, rights=[0]) (no fee). The sweeper will clean up the index later.

Costs & pricing

Grant pricing is time-based: feeWei = days * pricePerDay (enforced by quoteGrantCost).

maxDays caps the allowed duration; use the view return to validate UX.

Rights changes from non-zero → non-zero may be treated as an update (still priced by remaining/extended time, per contract policy). Right to zero is free.

Security notes & pitfalls

Scope mismatch will produce a KEK that doesn’t match the EncDEK. Always use the correct scope for the content you’re decrypting (1 for rule, 2 for logs).

RID is part of HKDF info, binding keys to the content identity. Use the exact RID (lowercase hex) you retrieved from metadata or events.

No on-chain private keys: the Read-Private-Key never leaves the client. Only public keys are registered on-chain.

“fee underpaid” on upsertGrantsBatch means value didn’t cover the price from quoteGrantCost. Quote per recipient and sum for batches.

Fail-closed engine wrapper: If any budget check fails (including MAX_WRAP_GAS), neither grants nor precompile are executed — avoiding inconsistent side-effects.

Read-key mismatch: Unwrap will raise an AES-GCM authentication failure if the local private key doesn’t match the on-chain public key (wrong seed/import).

Reference (concise)
Contract (XRC-563) essentials

Key registry

registerReadKey(bytes pubkey)

getReadKey(address owner) → bytes

clearReadKey()

Grants

getGrantByRID(bytes32 rid, address rcpt) → (EncDEK, rights, expireAt)

ridMeta(bytes32 rid) → (address ref, uint8 scope)

ridRecipients(bytes32 rid) → address[]

grantsCount(address owner) → uint256

grantAt(address owner, uint256 index) → (ref, rid, scope, rights, expireAt, EncDEK)

quoteGrantCost(bytes32 rid, address rcpt, uint64 expireAt) → (feeWei, pricePerDay, maxDays)

upsertGrantsBatch(address ref, bytes32 rid, uint8 scope, address[] rcpts, EncDEK[] encs, uint8[] rights, uint64[] expireAtArr)

sweepRID(bytes32 rid, uint256 max) → (removed)

EncDEK struct

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

Rights bitmask

READ = 1, WRITE = 2, MANAGE = 4.

Scopes

1 = OWNER (rules, XRC-137)

2 = RID (logs)

JSON-RPC (illustrative)

xgr_getCoreAddrs() → { engineEOA, grants, precompile, chainId }

xgr_encryptXRC137({ address, owner, json, grantExpireAt }) → { rid, suite, blob, updateTx[], didWork, reason }

xgr_getXRC137Meta({ address, owner, scope:"1" }) → { rid, suite, blob, encDEK }

xgr_getEncryptedLogInfo({ txHash, owner }) → { found, ruleContract, rid, suite, engineEncrypted }

(optional helpers) xgr_getGrantsByRID, xgr_upsertGrant

FAQs

Do I need a Read-Key to write a rule?
You need one to grant yourself access to the encrypted content. Without a registered Read-Public-Key, other parties cannot wrap DEKs for you.

Can I share only logs but not rules?
Yes. Use scope=2 for log DEKs; you can keep rule DEKs granted only to the owner.

What happens after expiry?
Decryption may still work with cached EncDEK locally, but on-chain the grant is considered inactive; admins should rely on expireAt as policy. The sweeper cleans up storage.

Implementation checklist

Before encrypting:

Owner has registered Read-Public-Key.

Decide scope (1=rule, 2=log).

Encrypt:

Generate DEK; AES-GCM-256 → XGR1.

Build info = "XGR|v=1|scope=S|rid=…|alg=3".

Wrap DEK → EncDEK.

Persist:

For rules: write XGR1 blob to XRC-137.

For logs: emit EngineExtrasV2 with minimal { rid, suite, blob }.

Grant:

Quote cost per recipient; attach value and upsert.

Engine wrapper (if applicable):

Add ceil(feeWei/gasPrice) + estimateGas(grants write) to validationGas.

Abort early if wrapGas > MAX_WRAP_GAS.

Send grant → precompile call (in that order).

Maintenance:

Run sweepRID(rid, max) periodically.

Glossary

DEK — Data Encryption Key (32-byte secret).

EncDEK — DEK wrapped for a specific recipient and scope using P-256/HKDF/AES-GCM.

RID — 32-byte identifier of an encrypted rule/log namespace.

Scope — Context binding (1=OWNER for rules, 2=RID for logs).

XGR1 — Envelope format for encrypted payloads.

XRC-137 — Rule contract interface that stores the encrypted rule.

XRC-563 — Grants + Read-Key registry contract interface.

Sweeper — Contract function that prunes expired/zero-rights recipients from the rid → [recipients] index.
