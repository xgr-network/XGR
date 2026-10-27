# XGRChain v3.4.0 — release, consensus activation and operations

**Updated:** 2026-10-27. This document supplements the detailed chain, gas, IBFT and operator references. Source authority is [xgr-node v3.4.0](https://github.com/xgr-network/xgr-node/tree/v3.4.0), release commit `cbe6f8a4ae1718429a9924dcf87f0d28591d74e1`.

## Release and deployment evidence

The [v3.4.0 release](https://github.com/xgr-network/xgr-node/releases/tag/v3.4.0) provides the Linux AMD64 binary, `version.txt`, `commit.txt`, `toolchain.txt` and `sha256sums.txt`. The network operator reports Testnet and Mainnet rollout. This statement is not an independent inventory of every participating node or completion certificate for a fresh historical sync.

| Item | Value |
| --- | --- |
| Release | `v3.4.0` |
| Mainnet chain ID | `1643` |
| Testnet chain ID | `1879` |
| Mainnet security-accounting fork | `12,186,213`, inclusive |
| Binary | `xgrchain-v3.4.0-linux-amd64` |
| Binary SHA-256 | `c4b41557ee957f1a1e6487aa7701ae593ae2e657a911a4761627f728a61be85e` |

The activation height above is read from this repository's canonical Mainnet genesis, not inferred from the release number. Testnet has an independent schedule; do not copy Mainnet activation heights to another network. Installation and activation are distinct.

## Common fork and historical compatibility

The optional fork key is `params.forks.securityAccounting.block`. Its value is a numeric block height. Before H, the historical execution rules remain in effect; at H and afterward the new rules apply. Omission disables these rules at every height. The ordinary all-forks-enabled generator does not implicitly schedule this optional security fork.

Canonical Mainnet fragment:

```json
"securityAccounting": {
  "block": 12186213
}
```

New Mainnet nodes must use the published historical schedule from genesis when replaying the chain. They must not move H to their installation date. For a newly planned network upgrade choose a future coordinated height; never retroactively change an existing canonical schedule, chain ID, allocation or consensus identity. Validators, full nodes and replay nodes require the same effective schedule.

## Consensus changes

1. **System transaction authorization:** the activated IBFT proposal and finalized-block paths accept only the canonical protocol marker at the permitted mature PoS epoch boundary, with exact encoding/identity and permitted block-body placement. Arbitrary externally constructed StateTx calls are rejected.
2. **Value conservation:** a StateTx without an upfront gas debit receives no normal gas refund or fee split. This accounting defense is gated with authorization.
3. **BaseFee:** producer and verifier use the checked, deterministic calculation from the committed parent state. Missing/corrupt trie inputs fail verification instead of silently becoming a zero/default value; defined registry-absence/configuration fallback cases retain their deterministic meaning. The checked arithmetic avoids utilization-threshold overflow.
4. **Transaction-local SSTORE original state:** the immutable account radix is pinned at each transaction entry, so earlier writes in the same block cannot leave the next transaction reading a stale original value. The implementation avoids scanning every modified account at each transaction boundary.
5. **Refund invariants:** active accounting checks underflow and overflow, journals the error state so nested reverts restore it, and rejects an unreverted accounting violation before refund application.

These changes do not introduce a separate EIP-3529 refund schedule, replace IBFT/PoS, or require redeployment of Interchain token routers. Thanks to **ngjupeng** for both reports, the initial corrections and regression tests; the integrated release adds coordinated activation, consensus checks and expanded coverage.

## Install and verify

Download into a staging directory, leaving the currently running binary intact:

```sh
mkdir -p xgr-v3.4.0
cd xgr-v3.4.0
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.4.0/xgrchain-v3.4.0-linux-amd64
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.4.0/sha256sums.txt
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.4.0/version.txt
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.4.0/commit.txt
curl -fLO https://github.com/xgr-network/xgr-node/releases/download/v3.4.0/toolchain.txt
sha256sum -c sha256sums.txt
chmod +x xgrchain-v3.4.0-linux-amd64
./xgrchain-v3.4.0-linux-amd64 version
```

Check version and commit against the release, preserve the verified manifests, and obtain the canonical network genesis independently. Checksums detect mismatch with the published artifacts; they do not prove independent reproducible builds or authenticate a compromised distribution channel.

For source builds check out the exact tag in the public repository. The release workflow derives the versioning package from `go list -m` and verifies embedded version/commit output. Use the workflow or repository build instructions; do not assume a binary filename proves its source revision.

## Rollout, backup and replay

For validator maintenance, record the actual running binary, effective configuration and active voting power. Take a consistent data-directory backup (stop the node or use a verified storage snapshot procedure), protect signing secrets separately, and test restoration. Avoid running a restored duplicate with the same validator identity concurrently.

Before a future scheduled fork, distribute the same binary/schedule with sufficient lead time and confirm effective quorum, rather than merely counting hosts. During and after activation compare block hashes, state roots, receipt roots and gas at H−1/H/H+1 and adjacent epoch boundaries, including transactions that exercise the changed rules. Run an independently syncing **non-sealing** node from genesis through the fork. Successful unaffected blocks do not prove compatibility for affected accounting transactions.

The release's tests include pre/post-gate regressions, checked-state failures, same-block storage/refund cases and a four-validator fork-boundary E2E. The full release workflow runs all non-E2E Go packages without short mode, separate E2E, EEST under legacy and activated accounting configurations, and historical ForkGate before publication. Test-declared skips and EEST selection filters remain explicit evidence limits; this is not a claim of every possible fixture or network scenario passing.

After activation do not independently roll a node back to legacy execution or change past fork heights. Diagnose against canonical finalized history and coordinate any subsequent consensus repair. Running an older configuration can disagree when an affected transaction executes, even if ordinary blocks appeared compatible.

## Interchain independence

The optional Interchain worker is separate from weighted IBFT consensus. Direct-BLS message validation, public route registration and replaceable delivery remain as described in the [current technical reference](../interchain/XGR_INTERCHAIN_v3.4.0_Reference.md). A relay/RPC outage affects Interchain availability; it does not authorize changes to block accounting or bypass destination authorization.
