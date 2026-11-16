# XGRChain v3.5.1 — current node maintenance release and operator reference

**Current public node release:** [v3.5.1](https://github.com/xgr-network/xgr-node/releases/tag/v3.5.1) (15 November 2026).  
**Source / release commit:** `723ff829d7380a29a116fd2f29c3b808ec073c0d` on `xgr-network/xgr-node` (`XGR3.0`).  
**Previous consensus/PoP release:** [v3.5.0](./XGRCHAIN_v3.5.0_Release_and_Activation.md).  
**Scope:** F-20 Direct-BLS local vote recovery only; **no new fork or activation height**, no changes to consensus, PoP, staking, Ethereum execution, the existing genesis, contract addresses or on-chain Direct-BLS message format.

## What changed in v3.5.1

Previously an obsolete, locally signed validator-set vote could be retired too early if successor signing returned without a durable, exact replacement record. v3.5.1 requires a replacement from the same signer for the same authenticated route/message with the **current destination validator-set ID**, persisted in the local journal and synchronized to storage (signed-file and containing directory `fsync`) before the old vote is removed. Missing, ineligible, altered or non-durable successor records fail closed. No automatic transfer execution or replacement of a user's wallet transaction is introduced.

Implementation: [node PR #91](https://github.com/xgr-network/xgr-node/pull/91), [release notes](https://github.com/xgr-network/xgr-node/blob/XGR3.0/RELEASE_NOTES_v3.5.1.md) and [GitHub release assets](https://github.com/xgr-network/xgr-node/releases/tag/v3.5.1). The release is a guarded **light release**, not a repetition of the entire EEST/full-network test matrix.

## Canonical chain and migration remain unchanged

| Item | Current value |
| --- | --- |
| Mainnet chain ID | `1643` |
| Testnet chain ID | `1879` |
| Current public node release | `v3.5.1` |
| Release commit | `723ff829d7380a29a116fd2f29c3b808ec073c0d` |
| Mainnet activated `stakingBlsPoP` gate | Block `12,586,649` (5 November 2026), **unchanged from v3.5.0** |
| Testnet activated `stakingBlsPoP` gate | Block `6,613,834`, **unchanged from v3.5.0** |
| Staking system contract | `0x0000000000000000000000000000000000001001`, unchanged |
| Mainnet genesis source | [`genesis/mainnet/genesis.json`](../../genesis/mainnet/genesis.json), unchanged |
| Interchain protocol and V315/V2 contract versions | Independently versioned; **not renamed to v3.5.1** |

The [v3.5.0 activation reference](./XGRCHAIN_v3.5.0_Release_and_Activation.md) remains authoritative for the original PoP migration and fork activation. Historical v3.4.0 and v3.5.0 runbooks are preserved as evidence; do not interpret their older version stamps as the latest binary.

## Linux AMD64 release verification

Download all files **from the official v3.5.1 release** into a clean directory and verify:

```sh
sha256sum -c sha256sums.txt
cat version.txt
cat commit.txt
```

The expected version is `v3.5.1`; `commit.txt` must equal `723ff829d7380a29a116fd2f29c3b808ec073c0d`. The `sha256sums.txt` manifest checks the downloaded `xgrchain-v3.5.1-linux-amd64` binary; inspect `toolchain.txt` for build provenance. Do **not** assume that a GitHub release establishes which binary is running on a particular node.

## Operator update (no genesis or BLS-PoP re-migration)

1. Preserve a verified prior binary and all persistent validator, signer and Direct-BLS vote journals. Inspect expected binary hashes before install.
2. Roll nodes one at a time subject to actual validator quorum and availability requirements. Keep the **existing activated Mainnet genesis**; do not regenerate it, edit PoP manifests or restake.
3. After each restart verify the process version, actual running binary hash, chain ID, sync progress, blocks, validator quorum, Direct-BLS worker and local recovery evidence. Record the checked endpoint/host and time; an RPC client version string alone is not full binary attestation.
4. If validation fails, follow the existing per-node rollback procedure without deleting signer/vote evidence or mutating canonical chain data.

**Documentation boundary:** `xgr-node v3.5.1` is the node release. `xgr-interchain` runs its own separately deployed service commit, including post-audit sponsor/Creator changes. Updating the public node release reference does not imply any of those optional services have been redeployed or independently audited. No Solana availability is implied.
