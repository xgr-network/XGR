# XGR Encryption & Grants Reference

Version: 2.0  
Last updated: 2025-01-06

This document specifies the encryption model and grants system used by XGR for protecting rule documents (XRC-137) and engine-emitted logs.  
It is written for **developers** integrating with XDaLa and **clients** that need to encrypt, decrypt, or manage access to protected content.

---

## Table of contents

1. Overview  
2. Architecture changes (v2)  
3. Cryptographic primitives  
4. Data formats  
5. Scopes and RID  
6. Key registry (XRC-563)  
7. Grants storage (database)  
8. Encryption flows  
9. Decryption flows  
10. JSON-RPC endpoints  
11. Grant fee accounting  

---

## 1. Overview

### What is protected?

| Content | Description | Scope |
|---------|-------------|-------|
| XRC-137 rules | Rule document JSON (contracted rules) | 1 (session/prepare) |
| Engine logs | Log bundles (payload, apiSaves, contractSaves) | 2 (log) |

### How is it protected?

1. A random **DEK** (Data Encryption Key, 32 bytes) encrypts content with **AES-GCM-256**
2. The DEK is wrapped per-recipient as **EncDEK** using **ECDH(P-256) + HKDF-SHA256 + AES-GCM-256**
3. Wrapped DEKs and access rights are stored in the **grants database**

### Where are keys and grants stored?

| Component | Storage | Purpose |
|-----------|---------|---------|
| Read public keys | On-chain (XRC-563) | P-256 public keys for DEK wrapping |
| Grants | PostgreSQL (`xgr.grants`) | Access rights + wrapped DEKs |
| Encrypted blobs | On-chain (XRC-137) or logs | Ciphertext |

---

## 2. Architecture changes (v2)

### Previous architecture (v1)

- Grants stored **on-chain** in XRC-563 contract
- `upsertGrantsBatch()` contract call for each grant
- Gas costs for every grant operation

### Current architecture (v2)

- Grants stored **off-chain** in PostgreSQL database
- Only **read public keys** remain on-chain (XRC-563)
- Grant operations are **gasless** (no chain transactions)
- Annual fee model for grant storage

| Operation | v1 (on-chain) | v2 (database) |
|-----------|---------------|---------------|
| Register read key | Chain TX | Chain TX (unchanged) |
| Create grant | Chain TX + gas | RPC call (gasless) |
| Query grants | Chain call | RPC call |
| Revoke grant | Chain TX + gas | RPC call (gasless) |

---

## 3. Cryptographic primitives

### Algorithm suite

| Component | Algorithm | Parameters |
|-----------|-----------|------------|
| Key agreement | ECDH | NIST P-256 |
| Key derivation | HKDF | SHA-256 |
| Symmetric encryption | AES-GCM | 256-bit key, 12-byte IV, 16-byte tag |
| DEK | Random | 32 bytes |

### HKDF info string (v2)

```
XGR|v=2|scope=<S>|rid=<RID-hex>
```

| Field | Description |
|-------|-------------|
| `v` | Version (always `2`) |
| `scope` | 1 (session/prepare) or 2 (log) |
| `rid` | 32-byte RID in lowercase hex (no `0x` prefix) |

**Note:** v2 removes the `alg` field from the info string. Algorithm is implicit (P-256/HKDF-SHA256/AES-GCM).

### EncDEK structure

The wrapped DEK is encoded as a binary blob or hex string:

| Field | Size | Description |
|-------|------|-------------|
| `kemMode` | 1 byte | `0x04` (SEC1 uncompressed) |
| `kemX` | 32 bytes | Ephemeral public key X coordinate |
| `kemY` | 32 bytes | Ephemeral public key Y coordinate |
| `salt` | 16 bytes | HKDF salt |
| `iv` | 12 bytes | AES-GCM IV |
| `ct` | 32 bytes | Encrypted DEK |
| `tag` | 16 bytes | AES-GCM tag |

**Total:** 141 bytes

### EncDEK string format (XGRK2)

```
XGRK2.P256HKDFGCM.<hex-payload>
```

Where `<hex-payload>` is the hex encoding of:
```
writerPub(65) || salt(16) || iv(12) || ct(32) || tag(16)
```

---

## 4. Data formats

### XGR1 encrypted payload

Format: `XGR1.<suite>.<rid-hex>.<base64-payload>`

| Part | Description |
|------|-------------|
| `XGR1` | Magic identifier |
| `suite` | `AESGCM256` |
| `rid-hex` | 32-byte RID as hex (with `0x` prefix) |
| `base64-payload` | Base64-encoded `nonce(12) \|\| ciphertext \|\| tag(16)` |

**Example:**
```
XGR1.AESGCM256.0x8c1a2b53d9e8e1e3a7b3fa90ef0a9f7d0f8be0c9f99fd28d0d7fa9b6b5c3a1b2.SGVsbG8gV29ybGQ=
```

### RID computation (v2)

The RID is computed from the encrypted payload:

```
RID = SHA-256(nonce || ciphertext)
```

This ensures:
- RID is unique per encryption
- RID is content-blind (no information about plaintext)
- RID is reproducible from the blob

---

## 5. Scopes and RID

### Scope definitions

| Scope | Name | Purpose | Typical use |
|-------|------|---------|-------------|
| 1 | Session/Prepare | Protects XRC-137 rule documents | Rule owner encryption |
| 2 | Log | Protects engine-emitted log bundles | Per-execution logs |
| 3 | Field | (Reserved) | Future use |

### RID binding

Each RID is bound to exactly one scope. The scope affects:
- HKDF key derivation (different scope → different KEK)
- Grant lookup (grants are per-RID, per-scope)

---

## 6. Key registry (XRC-563)

The XRC-563 contract manages **read public keys** only. Grants have moved to the database.

### Contract interface

| Function | Description |
|----------|-------------|
| `registerReadKey(bytes pubkey)` | Register caller's P-256 public key |
| `getReadKey(address owner) → bytes` | Get owner's registered public key |
| `clearReadKey()` | Remove caller's public key |

### Public key format

- **Type:** SEC1 uncompressed P-256
- **Length:** 65 bytes
- **Format:** `0x04 || X(32) || Y(32)`

### Registration flow

1. Generate P-256 keypair locally
2. Keep private key secure (never transmitted)
3. Call `registerReadKey(pubkey)` with 65-byte public key
4. After confirmation, others can wrap DEKs for this address

---

## 7. Grants storage (database)

Grants are stored in PostgreSQL table `xgr.grants`.

### Grant record structure

| Field | Type | Description |
|-------|------|-------------|
| `rid` | `char(64)` | RID (hex, no `0x` prefix) |
| `scope` | `smallint` | 1=session, 2=log, 3=field |
| `grantee_addr` | `text` | Recipient address (lowercase) |
| `owner_addr` | `text` | Grant owner address (lowercase) |
| `rights` | `smallint` | Bitmask (1=READ, 2=WRITE, 4=MANAGE) |
| `enc_dek` | `bytea` | Wrapped DEK (141 bytes) |
| `expires_at` | `bigint` | Unix timestamp (0 = no expiry) |
| `is_owner` | `boolean` | True if this is the owner grant |
| `tx_hash` | `text` | Reference transaction (scope=2) |
| `ref_addr` | `text` | Rule contract address (scope=1) |
| `session_id` | `text` | Session ID (scope=2) |

### Rights bitmask

| Bit | Name | Value | Description |
|-----|------|-------|-------------|
| 0 | READ | 1 | Can decrypt content |
| 1 | WRITE | 2 | Can update content |
| 2 | MANAGE | 4 | Can manage sub-grants |

**Common combinations:**
- `7` (READ+WRITE+MANAGE) – Owner
- `1` (READ) – Reader
- `3` (READ+WRITE) – Editor

### Unique constraint

Primary key: `(rid, grantee_addr, scope)`

---

## 8. Encryption flows

### Flow 1: Encrypting an XRC-137 rule (Scope 1)

```
1. Input: rule JSON, owner address, rule contract address

2. Generate DEK (32 random bytes)

3. Encrypt JSON with AES-GCM-256:
   - Generate random nonce (12 bytes)
   - ciphertext = AES-GCM-256(DEK, nonce, JSON)
   - blob = "XGR1.AESGCM256.<rid>.<base64(nonce||ct||tag)>"

4. Compute RID:
   - RID = SHA-256(nonce || ciphertext)

5. Wrap DEK for owner:
   - Fetch owner's read public key from XRC-563
   - Generate ephemeral P-256 keypair
   - shared = ECDH(ephemeralPriv, ownerPub)
   - info = "XGR|v=2|scope=1|rid=<rid-hex>"
   - KEK = HKDF-SHA256(shared, salt, info)
   - encDEK = AES-GCM-256(KEK, iv, DEK)

6. Store grant in database:
   - rid, scope=1, grantee=owner, rights=7, enc_dek, expires_at

7. Commit blob to XRC-137 contract
```

### Flow 2: Encrypting engine logs (Scope 2)

```
1. Input: log bundle (payload, apiSaves, contractSaves), owner address

2. Generate DEK (32 random bytes)

3. Encrypt bundle with AES-GCM-256:
   - bundle = JSON.stringify({payload, apiSaves, contractSaves})
   - blob = "XGR1.AESGCM256.<rid>.<base64(...)>"

4. Compute RID from encrypted payload

5. Wrap DEK for owner:
   - info = "XGR|v=2|scope=2|rid=<rid-hex>"
   - (same ECDH/HKDF/AES-GCM flow as above)

6. Store grant in database:
   - rid, scope=2, grantee=owner, rights=7, enc_dek, tx_hash, session_id

7. Return encrypted blob in engine response (extras.engineEncrypted)
```

---

## 9. Decryption flows

### Flow: Decrypting with grant

```
1. Input: XGR1 blob, grantee address

2. Parse blob:
   - Extract rid, suite, nonce, ciphertext, tag

3. Lookup grant:
   - Query xgr.grants for (rid, grantee, scope)
   - Verify rights include READ (bit 0)
   - Verify not expired (expires_at = 0 OR expires_at > now)

4. Unwrap DEK:
   - Parse enc_dek (kemX, kemY, salt, iv, ct, tag)
   - Reconstruct ephemeral public key
   - shared = ECDH(granteePriv, ephemeralPub)
   - info = "XGR|v=2|scope=<scope>|rid=<rid-hex>"
   - KEK = HKDF-SHA256(shared, salt, info)
   - DEK = AES-GCM-256-Open(KEK, iv, ct||tag)

5. Decrypt content:
   - plaintext = AES-GCM-256-Open(DEK, nonce, ciphertext||tag)
```

---

## 10. JSON-RPC endpoints

### `xgr_manageGrants`

Creates or updates grants for a specific RID/scope.

**Request:**
```json
{
  "rid": "0x8c1a2b53...",
  "scope": 2,
  "owner": "0xF39F...",
  "entries": [
    {
      "grantee": "0x3C44...",
      "rights": 1,
      "expireAt": 1767225600,
      "encDEK": "XGRK2.P256HKDFGCM.04..."
    }
  ],
  "permit": { "...": "xdalaPermit" },
  "refAddr": "0xABCD...",
  "sessionId": "123"
}
```

**Response:**
```json
{
  "upserted": 1
}
```

### `xgr_listGrants`

Lists grants visible to the caller.

**Request:**
```json
{
  "scope": 2,
  "rid": "0x8c1a2b53...",
  "validAt": 1700000000,
  "limit": 100,
  "permit": { "...": "xdalaPermit" }
}
```

**Response:**
```json
{
  "items": [
    {
      "id": 1,
      "rid": "8c1a2b53...",
      "scope": 2,
      "grantee": "0x3c44...",
      "owner": "0xf39f...",
      "rights": 1,
      "encDEK": "0x04...",
      "expiresAt": 1767225600,
      "isOwner": false,
      "txHash": "0xdea...",
      "refAddr": "0xabcd...",
      "sessionId": "123"
    }
  ],
  "nextCursor": 0
}
```

### `xgr_getGrantFeePerYear`

Returns the annual grant storage fee.

**Request:** (no parameters)

**Response:**
```json
{
  "wei": "0x0de0b6b3a7640000"
}
```

### `xgr_getXRC137Meta`

Returns encrypted rule metadata for a given owner.

**Request:**
```json
{
  "address": "0xABCD...",
  "owner": "0xF39F...",
  "scope": 1
}
```

**Response:**
```json
{
  "rid": "0x8c1a2b53...",
  "blob": "XGR1.AESGCM256.0x8c1a....<base64>",
  "encDEK": "XGRK2.P256HKDFGCM.04...",
  "exp": 1767225600
}
```

### `xgr_encryptXRC137`

Encrypts a rule document and prepares owner grant.

**Request:**
```json
{
  "address": "0xABCD...",
  "owner": "0xF39F...",
  "json": "{...rule document...}",
  "grantExpireAt": 1767225600
}
```

**Response:**
```json
{
  "rid": "0x8c1a2b53...",
  "suite": "AESGCM256",
  "blob": "XGR1.AESGCM256.0x8c1a....<base64>",
  "ownerEncDEK": "XGRK2.P256HKDFGCM.04..."
}
```

### `xgr_getEncryptedLogInfo`

Extracts encryption metadata from a transaction.

**Request:**
```json
{
  "txHash": "0xdea..."
}
```

**Response:**
```json
{
  "found": true,
  "ruleContract": "0xABCD...",
  "suite": "AESGCM256",
  "rid": "0x8c1a2b53...",
  "hkdfSeedHash": "0x..."
}
```

---

## 11. Grant fee accounting

### Fee model

Grants incur an **annual storage fee** rather than per-operation gas costs.

| Parameter | Source | Default |
|-----------|--------|---------|
| `grant_fee_per_year_wei` | `xgr.const` table | 1 XGR (10^18 wei) |

### Fee calculation

```
fee = ceil(grantFeePerYear × seconds / 31536000)
```

Where `seconds` is the grant duration in seconds.

### Billing

Grant fees are collected via the `GrantFeeSeconds` and `GrantFeePerYearWei` fields in engine calls. The engine transfers fees from the user to the engine EOA during execution.

---

## Appendix A: Migration from v1

### Breaking changes

| Change | Impact |
|--------|--------|
| HKDF info string | v1 grants cannot decrypt v2 content |
| Grant storage | On-chain grants (v1) are deprecated |
| `alg` field removed | Simplified to single algorithm |

### Compatibility

- v1 encrypted content with v1 grants continues to work
- New content uses v2 format
- Read keys remain on-chain (no migration needed)

---

## Appendix B: Security considerations

### Fail-closed design

The engine removes plaintext from logs **before** encryption. If encryption fails, no plaintext is exposed.

```go
// FAIL-CLOSED: Clear plaintext from meta BEFORE encryption
spec.PayloadAll = nil
spec.APISaves = nil
spec.ContractSaves = nil
```

### Key hygiene

| Key type | Storage | Rotation |
|----------|---------|----------|
| Read private key | User device only | User-controlled |
| Read public key | On-chain (XRC-563) | Via `clearReadKey` + `registerReadKey` |
| DEK | Never stored raw | Per-encryption |
| Engine read key | Environment variable | Operator-controlled |

### Grant expiration

- Grants with `expires_at > 0` automatically become invalid after expiration
- Query filters should use `validAt` parameter to exclude expired grants
- Expired grants can be cleaned up via maintenance jobs
