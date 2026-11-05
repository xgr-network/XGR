# XGRChain v3.5.0 — BLS possession, migration and activated Mainnet fork

**Updated:** 2026-11-05. Node release: [v3.5.0](https://github.com/xgr-network/xgr-node/releases/tag/v3.5.0). Source/tag commit: `b3717a44b5ec5faa19fabdd88bd4b91f54659983`. Previous release: v3.4.3. This is the current staking/consensus delta; earlier dated references remain historical evidence, not a substitute for this activation record.

## Release and activation record

| Item | Value |
| --- | --- |
| Mainnet chain ID | `1643` |
| Testnet chain ID | `1879` |
| Single fork key | `params.forks.stakingBlsPoP.block` |
| Mainnet activation, inclusive | **12,586,649** |
| Testnet activation, inclusive | **6,613,834** |
| Mainnet proven migration keys | **5** |
| Testnet proven migration keys | **4** |
| Staking system contract | `0x0000000000000000000000000000000000001001` |
| Mainnet manifest digest | `0x98803459ccdbbf1a8b89d8c44c95081661ebdeb3e037eb0c144126e74ec5d735` |
| Testnet manifest digest | `0x8701173709e17f821fa7eefc21a15efef2942340145c1bd889171b5654531824` |
| Staking runtime SHA-256 | `120acc0e54f2af48adcb1518186f39d9a93244a52087927cdf554e7c8cf3f864` |
| Linux AMD64 binary | `xgrchain-v3.5.0-linux-amd64` |
| Binary SHA-256 | `e11e4398cb0e7757fc2b788f1dde177bd00758329ec52bbc1579f8655604e96e` |
| Published build toolchain | `go1.23.12 linux/amd64` |

Release assets `commit.txt`, `version.txt`, `toolchain.txt` and `sha256sums.txt` were retrieved and checked against published metadata. The source validation used Go 1.23.11; the published binary records Go 1.23.12. A local reproduction need not have the same binary checksum unless its complete build inputs also match.

The previously activated `securityAccounting` gate at Mainnet block 12,186,213 is unchanged. It is not a second gate for this release.

## What possession proves

A proof of possession (PoP) is a BLS signature proving that the validator controls the private key corresponding to its submitted BLS public key. The wallet/ECDSA key authorizing the staking transaction and the BLS consensus key are distinct secrets, even when both are stored in the same datadir.

The registration proof is bound to the domain `XGR_STAKING_BLS_POP_V1`, chain ID, staking contract address, validator address, public-key hash and current nonce. Another validator, chain, contract or registration nonce cannot reuse it. The verifier uses the existing BLS12-381 precompile at `0x2040`; consensus seal encodings remain unchanged.

PoP is required when a key is registered or rotated. Validators do not generate a new PoP for each block. Post-fork consensus admits only proven keys in normal selection, fallbacks and cached signing sets. The legacy one-argument `registerBLSPublicKey(bytes)` reverts after activation; registration uses `registerBLSPublicKey(bytes,bytes)`.

## Existing-validator migration and storage

Existing validators generated genuine nonce-zero proofs locally. Every proof was independently verified; no existing key was grandfathered merely because it was already staked. Before activation, the manifest had exact coverage of the registered key inventory and all keys in the canonical signing snapshot, including any historical keys needed by that snapshot. A quorum-only subset is insufficient for this implementation.

One gate jointly activates runtime replacement, deterministic migration, the new registration interface and strict consensus admission. The shared pre-transaction hook executes before user transactions in proposal and block import. At the activation height, validator lookup uses the parent-derived snapshot and verifies migration against that parent view; proposed post-state cannot establish its own signing authority. ParentCommittedSeals use the rules for the parent's signed height, keeping pre-fork history verifiable. Missing/mismatched manifest coverage fails closed; quorum is not silently reduced.

Existing contract storage slots 0–10 and both pre-existing struct layouts are retained. Appended slots are:

| Slot | Added state |
| --- | --- |
| 11 | Verified address/public-key-hash history |
| 12 | Registration nonces by validator |
| 13 | Migration manifest digest |

Migration sets a verification flag only for a successfully checked proof and consumes nonce zero, leaving nonce one. Stakes, delegations, weights, activation metadata and historical records remain under the existing contract and addresses. No funds are moved and no restaking, manual delegation migration or wallet signing is required for the fork migration. Normal withdrawals and claims do not require a new possession proof.

## Canonical genesis and restarts

Use the [activated Mainnet genesis configuration](../../genesis/mainnet/genesis.json). The initial header, allocations and original parameter order are preserved; only `params.forks.stakingBlsPoP` and `params.stakingBlsPoPMigration` were added.

`stakingBlsPoPMigration.manifest` is the exact canonical manifest JSON encoded as a JSON **string**, accompanied by `digest`. It contains public addresses, keys and signatures only. The canonical ordering within that string is protocol-defined; arbitrary reformatting invalidates its digest.

There is no separate runtime manifest file to put in the datadir. Keep the complete activated genesis file for every restart and fresh sync, because nodes independently verify the public evidence at startup and when replaying the fork. The on-chain PoP status does not eliminate the historical configuration requirement.

The activation height is already part of Mainnet history. Do not reschedule it, remove it, change its manifest or regenerate migration proofs to repair a node. Use the identical canonical configuration and v3.5.0 or a compatible later node. Preserve the existing datadir and signing keys. A database reset is not part of the normal upgrade procedure.

## Install and verify the release

```sh
mkdir -p "$HOME/xgr-v3.5.0"
cd "$HOME/xgr-v3.5.0"
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.5.0/xgrchain-v3.5.0-linux-amd64
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.5.0/sha256sums.txt
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.5.0/commit.txt
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.5.0/version.txt
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.5.0/toolchain.txt
sha256sum -c sha256sums.txt
chmod +x xgrchain-v3.5.0-linux-amd64
./xgrchain-v3.5.0-linux-amd64 version
```

Before replacing an installed executable, verify the checksum and version, retain a backup, and follow the service's existing installation/restart procedure. A pre-v3.5.0 binary is not a valid post-activation rollback.

## Joining a new validator: automatic PoP

With an existing funded local ECDSA/BLS identity and v3.5.0:

```sh
xgrchain ibft join \
  --data-dir "$HOME/xgrchain/data" \
  --jsonrpc https://rpc.xgr.network
```

Use an operator-controlled RPC where appropriate. Default self-stake target is 200,000 XGR; the account also needs gas. The CLI stakes a missing delta first, detects the exact deployed staking runtime, queries the live chain ID and nonce, generates the PoP from the local BLS secret and submits the new registration. Unknown runtime code is rejected. A failed PoP registration never falls back to a proofless call. If staking succeeded but registration failed, inspect state/receipts and rerun with the same identity rather than creating new keys.

A migrated validator whose key is already registered does not need to join again. A new validator does not edit the fork manifest or genesis. Successful registration is separate from normal active/epoch selection and the effective total-support threshold (2,000,000 XGR under current contract rules). Inspect the transaction receipt and validator state; a submission hash or optimistic CLI eligibility field alone is insufficient.

The old CLI cannot register a key through the retired one-argument selector. Use v3.5.0 or a compatible later CLI.

## Proof tools and independent verification

The following command is the historical migration-proof workflow, not the normal post-fork join workflow:

```sh
xgrchain ibft bls-pop proof \
  --data-dir "$HOME/xgrchain/data" \
  --chain-id 1643 \
  --out "$HOME/mainnet-bls-pop.json"
```

It exports public evidence only, does not submit a transaction, and refuses to overwrite an existing output. Testnet proofs use chain ID 1879 and are invalid on Mainnet. Private secrets remain local.

To independently verify the embedded Mainnet manifest without changing anything on-chain:

```sh
python3 - <<'PY'
import json
from pathlib import Path
config = json.loads(Path('genesis.json').read_text())
Path('manifest-for-verification.json').write_text(
    config['params']['stakingBlsPoPMigration']['manifest']
)
PY
xgrchain ibft bls-pop verify \
  --chain-id 1643 \
  --activation-height 12586649 \
  --manifest manifest-for-verification.json
```

Expected digest: `0x98803459ccdbbf1a8b89d8c44c95081661ebdeb3e037eb0c144126e74ec5d735`. This offline command verifies proofs, canonical encoding and digest; it does not independently establish parent-state inventory or signing-snapshot coverage. Runtime verification additionally checks those state-dependent requirements. `assemble` and `configure` prepare new-network candidates; do not use them to select another height for this already activated Mainnet fork.

## Validation and observed rollout

The release's [security validation](https://github.com/xgr-network/xgr-node/blob/XGR3.0/docs/security/v3.5.0-validation.md) covers an independent isolated legacy forgery reproduction, ordinary-signature controls, wrong key/address/chain/proof/nonce rejection, on-chain admission and rotation, replay, append-only storage/bytecode reproduction, cached sets, parent seals, fund exits and four-validator fork/restart/fresh-sync behavior. Source command: `bash scripts/validate-v3.5.0.sh`. Attack regressions ran only on isolated infrastructure.

The reporter independently tested the original PoC against the fixed candidate and reported the issue addressed without identifying a new patch bug. That is a targeted review, not an unrestricted audit certificate. The Testnet operator also reported a fresh sync across activation with identical block hashes.

Read-only Mainnet observations on 2026-11-05 established:

- Frozen legacy runtime at block 12,586,648; exact reviewed PoP runtime at 12,586,649.
- Matching manifest digest, all five possession flags true and all five nonces one.
- Existing direct storage slots 0–10, registered keys/addresses and queried validator stake/pool/delegation values unchanged across the migration block. This observation is not a byte-by-byte enumeration of every mapping entry.
- A five-key canonical snapshot for epoch 12,588 after the boundary at 12,587,000; every snapshot key is covered by the verified proofs.
- Correct parent linkage and two-second block timestamps for 12,586,999 through 12,587,002.

[Machine-readable verification record](releases/v3.5.0-mainnet-verification.json). These observations describe the queried Mainnet RPC's canonical view, not independent attestations of every installed host or completion of a fresh Mainnet sync. No production exploit transaction was submitted for verification.

## Interchain and disclosure boundaries

XITA/Direct-BLS and Registry V3 possession remain separate security domains. Their signature formats and deployment identities are unchanged by this staking fix; a staking PoP cannot substitute for Registry V3 membership evidence. Node v3.5.0 does not imply new Interchain router contracts or new XRC interface versions.

An explicit local `interchainRuntimeDisabled: true` setting exists for isolated node tests and prevents external worker construction. It is unset in normal production operation and is not another fork gate.

Advisory publication, CVE handling and reporter rewards remain separately coordinated actions. Updating documentation does not publish or close the advisory, send a reporter message or transfer a reward.
