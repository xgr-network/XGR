# Interchain CLI reference

[Documentation index](README.md). Source: public xgr-node `command/ibft/interchain/`. The command family is separate from ordinary node/server/staking CLI.

## Invocation

Inherited `--grpc-address` is accepted by the IBFT command family; these local Interchain control commands use their data-directory queues/secrets as described below. It does not override compiled source-chain RPC policy.

All commands below use the `xgrchain ibft interchain` prefix. `--json` selects machine-readable command output; read the returned error as well as the process result. The local data-directory commands communicate with the running worker through its storage/queue model; supplying a different directory does not select another chain RPC. Public transfer users do not need a validator data directory or a validator BLS key.

### `bootstrap-proof`

Creates a possession/bootstrap proof from an existing validator ECDSA/BLS identity. It reads secrets and signs the bootstrap payload locally; it does not register a token route or broadcast a destination deployment.

| Flag | Type/default | Requirement and meaning |
| --- | --- | --- |
| `--data-dir` | string, empty | Local secrets-manager directory; mutually exclusive with `--config` |
| `--config` | string, empty | Cloud secrets-manager configuration; exactly one of these two is required |
| `--origin-chain-id` | uint64, 0 | Required nonzero XGR origin chain identity |
| `--destination-domain` | uint32, 0 | Required nonzero destination domain |
| `--json` | boolean, false | Structured output |

```sh
xgrchain ibft interchain bootstrap-proof \
  --data-dir /ABS/VALIDATOR_DATA \
  --origin-chain-id 1643 --destination-domain 8453 --json
```

Result fields: `validator` (ECDSA address), `originChainId`, `destinationDomain`, `blsPublicKey` (compressed public key), `blsPublicKeyEIP2537`, `payload` and `possessionProof` (EIP-2537 representation). The payload binds identity and target domain. Both secret keys must already exist; missing/unparseable secrets or failed key conversion produce an error. The output contains public proof material, not private keys. Verify it against the intended destination Registry bootstrap interface before use.

### `set-active`

Requests activation/deactivation of this validator on an already configured destination. This is validator membership management, not permission to create asset routes. The worker validates canonical XGR eligibility, collects membership quorum, sends the destination transaction where needed and checks final state.

| Flag | Type/default | Meaning |
| --- | --- | --- |
| `--data-dir` | string, empty | Required running validator directory |
| `--chain` | string, empty | Required configured destination name, e.g. `base` or `arbitrum` |
| `--active` | string, empty | Required explicit `true` or `false`; no implicit default |
| `--timeout` | duration, `2m` | Positive wait for quorum, receipt and final-state verification |
| `--json` | boolean, false | Structured output |

```sh
xgrchain ibft interchain set-active \
  --chain base --active true --data-dir /ABS/VALIDATOR_DATA --timeout 2m --json
xgrchain ibft interchain set-active \
  --chain base --active false --data-dir /ABS/VALIDATOR_DATA --timeout 2m --json
```

Result fields: `validator`, normalized `chain`, `requestedActive`, `finalActive`, `changed`, `setId`, optional `transactionHash`, `destinationCommitted`. A matching pre-existing state can return `changed:false` without a new destination transaction. A timeout is not proof that no transaction was sent: inspect destination state and worker outcome before retrying. Reject empty directory/chain, unspecified or invalid active string and nonpositive timeout.

### `fee create`

Builds a positive, source-native fee proposal for the entire configured source chain. Creation **does not sign approval**. The command reads current destination membership set and confirmed source fee nonce, constructs the proposal and queues it to the worker.

| Flag | Type/default | Meaning |
| --- | --- | --- |
| `--data-dir` | string, empty | Required running validator directory |
| `--source` | string, empty | Required configured source-chain name |
| `--fee-wei` | decimal string, empty | Required positive uint256 in the source native currency's smallest unit |
| `--nonce` | uint64, `0` | `0` auto-detects confirmed nonce+1; explicit value must equal the next nonce |
| `--ttl` | duration, `5m` | Positive proposal lifetime, maximum `10m` |
| `--timeout` | duration, `2m` | Worker response wait |
| `--json` | boolean, false | Structured output |

```sh
# Example amount only: 1,000,000,000 wei. Select the intended economic fee yourself.
xgrchain ibft interchain fee create \
  --source base --fee-wei 1000000000 --ttl 5m \
  --data-dir /ABS/VALIDATOR_DATA --json
```

The proposal binds `sourceChainId`, `sourceDomain`, source Registry, current `setId`, next `nonce`, Unix `validUntil` and `validatorFeeWei`. Result: `proposalId`, `approved` and `quorum`. `approved:false` is expected from unsigned creation. Errors include invalid/zero/out-of-range fee, invalid TTL, missing chain bindings, unreadable membership/nonce, explicit nonce mismatch and nonce exhaustion. Do not interpret the example amount as the deployed current fee.

### `fee approve`

Explicitly approves an existing source-fee proposal with this validator's BLS key. This is the signing step and must follow inspection of the actual proposal's source, Registry, set, nonce, expiry and amount.

| Flag | Type/default | Meaning |
| --- | --- | --- |
| `--data-dir` | string, empty | Required running validator directory |
| `--proposal-id` | 0x-prefixed bytes32, empty | Required nonzero 32-byte proposal hash |
| `--timeout` | duration, `2m` | Worker response wait |
| `--json` | boolean, false | Structured output |

```sh
xgrchain ibft interchain fee approve \
  --proposal-id "$PROPOSAL_ID" --data-dir /ABS/VALIDATOR_DATA --json
```

Result: `proposalId`, `approved`, `quorum`. One approval is not a completed 2/3 quorum. Invalid hash syntax, zero hash, missing local storage/proposal, ineligible identity or worker validation failure is an error. This command does not create or approve a route registration.

### `fee execute`

Submits an existing completed source-fee quorum on chain and confirms the resulting nonce. It does not sign another validator's vote and does not create routes.

| Flag | Type/default | Meaning |
| --- | --- | --- |
| `--data-dir` | string, empty | Required local running validator directory |
| `--proposal-id` | nonzero bytes32, empty | Existing completed source-fee proposal |
| `--timeout` | positive duration, `6m` | On-chain execution wait |
| `--json` | boolean, false | Structured output |

```sh
xgrchain ibft interchain fee execute \
  --proposal-id "$PROPOSAL_ID" --data-dir /ABS/VALIDATOR_DATA --timeout 6m --json
```

Result: `proposalId`, `transactionHash`, confirmed `nonce`. The source Registry rejects an invalid quorum, wrong current set, stale/nonconsecutive nonce, expired proposal, wrong binding or invalid fee. Execution requires source-chain availability and transaction gas. After a timeout inspect the canonical transaction/nonce before another submission.

### `storage-status`

Read-only offline measurement of persisted Interchain state. It does not enqueue work, sign, delete files, rebuild proofs or contact a destination.

| Flag | Type/default | Meaning |
| --- | --- | --- |
| `--data-dir` | string, empty | Required node directory to inspect |
| `--json` | boolean, false | Structured measurement |

```sh
xgrchain ibft interchain storage-status --data-dir /ABS/VALIDATOR_DATA --json
```

The result reports persisted file/byte totals and attestation, local-vote, quorum-request and governance categories. A missing directory/file permission failure is not an empty healthy database. Size measurements do not prove source finality, quorum completeness, delivery or a recoverable backup.


## Storage result schema

`storage-status --json` reports `baseDir`, `totalFiles`, `totalBytes`, `attestationFiles`, `localVoteFiles`, `requestFiles`, `governanceFiles`, `otherFiles`. It walks regular files under `<data-dir>/interchain`; symlinks and nonregular entries are not counted as regular data. The category totals are file counts; only `totalBytes` is the aggregate byte count.

## Node-wide CLI

For all other node subcommands and flags use the [complete source-derived node CLI inventory](../chain/XGRCHAIN_CLI_Reference.md) and the existing [node operations runbook](../chain/XGRCHAIN_Node_Operation.md). `ibft interchain --help` is the executable entry point; do not infer older route-admission commands from historical prose.
