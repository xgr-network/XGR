# XGRChain complete CLI reference — v3.4.0

This reference captures every registered application command and its help/flags from a fresh build of the public node source at `418926f90f9b85af66f4ea4b0cc060dce6cdc862` (v3.4.0 execution code plus documentation merge). Help was invoked only; no command body or node service was run. Defaults below are software defaults, not recommended production settings.

## Command roles

| Family | Purpose and operational effect |
| --- | --- |
| server / export | Start the node or export server configuration; review data/genesis/RPC/storage flags |
| genesis | Create a chain definition; does not upgrade a running canonical network |
| secrets init/generate/output | Initialize/configure/read public identity; protect existing secrets and do not overwrite live identities |
| ibft status/snapshot/candidates/validators | Operator inspection; use the correct gRPC endpoint |
| ibft join/stake/unstake/withdraw/setactive/poolconfig | Validator/staking transactions; review account, chain, amounts, gas and resulting receipt |
| ibft propose/switch/quorum | Consensus configuration workflows; follow network governance and fork instructions |
| ibft interchain | Bootstrap proof, membership, source fee governance and storage diagnostics; detailed semantic reference below |
| peers | Inspect or add node network peers |
| txpool | Inspect transaction pool |
| status / monitor | Node status and event monitoring |
| backup / regenesis | Export/transform chain data; destination and retained state requirements apply |
| version / license | Build/version and license attribution |

Use [node operations](XGRCHAIN_Node_Operation.md), [staking model](XGRCHAIN_Staking_PoS_Model.md), [genesis](XGRCHAIN_Genesis_and_Configuration.md) and [Interchain CLI semantics](../interchain/XGR_INTERCHAIN_CLI.md) alongside this exact command surface. A successful submission hash is not confirmed execution. Some commands report errors through their outputter, so inspect structured `error` as well as process exit.

## Global flags

`--json` selects machine-readable output. Inherited flags are shown in each help block; in particular `--grpc-address` is an operator endpoint flag, not an arbitrary Interchain source-chain selection. `--help` does not execute a command. Shell completion is provided by Cobra via `completion <shell>`.

## Command index

- `xgrchain`
- `xgrchain backup`
- `xgrchain genesis`
- `xgrchain genesis predeploy`
- `xgrchain ibft`
- `xgrchain ibft candidates`
- `xgrchain ibft interchain`
- `xgrchain ibft interchain bootstrap-proof`
- `xgrchain ibft interchain fee`
- `xgrchain ibft interchain fee approve`
- `xgrchain ibft interchain fee create`
- `xgrchain ibft interchain fee execute`
- `xgrchain ibft interchain set-active`
- `xgrchain ibft interchain storage-status`
- `xgrchain ibft join`
- `xgrchain ibft pool-config`
- `xgrchain ibft propose`
- `xgrchain ibft quorum`
- `xgrchain ibft set-active`
- `xgrchain ibft snapshot`
- `xgrchain ibft stake`
- `xgrchain ibft status`
- `xgrchain ibft switch`
- `xgrchain ibft unstake`
- `xgrchain ibft validators`
- `xgrchain ibft withdraw`
- `xgrchain license`
- `xgrchain monitor`
- `xgrchain peers`
- `xgrchain peers add`
- `xgrchain peers list`
- `xgrchain peers status`
- `xgrchain regenesis`
- `xgrchain regenesis getroot`
- `xgrchain regenesis history`
- `xgrchain secrets`
- `xgrchain secrets generate`
- `xgrchain secrets init`
- `xgrchain secrets output`
- `xgrchain server`
- `xgrchain server export`
- `xgrchain status`
- `xgrchain txpool`
- `xgrchain txpool status`
- `xgrchain txpool subscribe`
- `xgrchain version`

## `xgrchain`

```text
XGRChain is a framework for building Ethereum-compatible Blockchain networks

Usage:
   [command]

Available Commands:
  backup      Create blockchain backup file by fetching blockchain data from the running node
  completion  Generate the autocompletion script for the specified shell
  genesis     Generates the genesis configuration file with the passed in parameters
  help        Help about any command
  ibft        Top level IBFT command for interacting with the IBFT consensus. Only accepts subcommands.
  license     Returns XGRChain license and dependency attributions
  monitor     Starts logging block add / remove events on the blockchain
  peers       Top level command for interacting with the network peers. Only accepts subcommands.
  regenesis   Copies trie for specific block to a separate folder
  secrets     Top level SecretsManager command for interacting with secrets functionality. Only accepts subcommands.
  server      The default command that starts the XGRChain client, by bootstrapping all modules together
  status      Returns the status of the XGRChain client
  txpool      Top level command for interacting with the transaction pool. Only accepts subcommands.
  version     Returns the current XGRChain version

Flags:
  -h, --help   help for this command
      --json   get all outputs in json format (default false)

Use " [command] --help" for more information about a command.
```

## `xgrchain backup`

```text
Create blockchain backup file by fetching blockchain data from the running node

Usage:
   backup [flags]

Flags:
      --from string           the beginning height of the chain in backup (default "0")
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
  -h, --help                  help for backup
      --out string            the export path for the backup
      --to string             the end height of the chain in backup

Global Flags:
      --json   get all outputs in json format (default false)
```

## `xgrchain genesis`

```text
Generates the genesis configuration file with the passed in parameters

Usage:
   genesis [flags]
   genesis [command]

Available Commands:
  predeploy   Specifies the contract to be predeployed on chain start

Flags:
      --base-fee-config string          initial base fee(in wei), base fee elasticity multiplier, and base fee change denominator
                                                (provided in the following format: [<baseFee>][:<baseFeeEM>][:<baseFeeChangeDenom>]).
                                                BaseFeeChangeDenom represents the value to bound the amount the base fee can change between blocks.
                                                Default BaseFee is 1 Gwei, BaseFeeEM is 2 and BaseFeeChangeDenom is 8.
                                                Note: BaseFee, BaseFeeEM, and BaseFeeChangeDenom should be greater than 0. (default "1000000000:2:8")
      --block-gas-limit uint            the maximum amount of gas used by all transactions in a block (default 5242880)
      --block-time duration             the predefined period which determines block creation frequency (default 2s)
      --bootnode stringArray            multiAddr URL for p2p discovery bootstrap. This flag can be used multiple times
      --burn-contract string            the burn contract block and address (format: <block>:<address>[:<burn destination>])
      --chain-id uint                   the ID of the chain (default 100)
      --consensus string                the consensus protocol to be used (default "ibft")
      --dir string                      the directory for the XGRChain genesis data (default "./genesis.json")
      --epoch-size uint                 the epoch size for the chain (default 100000)
  -h, --help                            help for genesis
      --ibft-validator-type string      the type of validators in IBFT (default "bls")
      --macro-epoch-micro-factor uint   PoS macro epoch factor in micro epochs (required in PoS mode)
      --max-validator-count uint        the maximum number of validators in the validator set for PoS (default 9007199254740990)
      --micro-epoch-size uint           PoS micro epoch size (required in PoS mode)
      --min-validator-count uint        the minimum number of validators in the validator set for PoS (default 1)
      --name string                     the name for the chain (default "xgrchain")
      --pos                             the flag indicating that the client should use Proof of Stake IBFT. Defaults to Proof of Authority if flag is not provided or false
      --premine stringArray             the premined accounts and balances (format: <address>[:<balance>]). Default premined balance: 1000000000000000000000000
      --validators stringArray          validators defined by user
      --validators-path string          root path containing validators secrets (default "./")
      --validators-prefix string        folder prefix names for validators secrets (default "test-chain-")

Global Flags:
      --json   get all outputs in json format (default false)

Use " genesis [command] --help" for more information about a command.
```

## `xgrchain genesis predeploy`

```text
Specifies the contract to be predeployed on chain start

Usage:
   genesis predeploy [flags]

Flags:
      --artifacts-path string          the path to the contract artifacts JSON
      --chain string                   the genesis file to update (default "./genesis.json")
      --constructor-args stringArray   the constructor arguments, if any
  -h, --help                           help for predeploy
      --predeploy-address string       the address to predeploy to. Must be >= 0x0000000000000000000000000000000000001100 (default "0x0000000000000000000000000000000000001100")

Global Flags:
      --json   get all outputs in json format (default false)
```

## `xgrchain ibft`

```text
Top level IBFT command for interacting with the IBFT consensus. Only accepts subcommands.

Usage:
   ibft [command]

Available Commands:
  candidates  Queries the current set of proposed candidates, as well as candidates that have not been included yet
  interchain  Manage optional XGR interchain validator participation on configured EVM destinations
  join        One-shot PoS validator join: ensure keys, register BLS pubkey, stake required amount
  pool-config Configure validator delegation pool parameters via JSON-RPC
  propose     Proposes a new candidate to be added or removed from the validator set
  quorum      Specify the block number after which quorum optimal will be used for reaching consensus
  set-active  Set validator active flag in staking contract (setActive(bool))
  snapshot    Returns the IBFT snapshot at the latest block number, unless a block number is specified
  stake       Increase stake in the staking contract (payable stake())
  status      Returns the current validator key of the IBFT client
  switch      Add settings in genesis.json to switch IBFT type
  unstake     Request unstake from staking contract (unstake())
  validators  Show staking contract validator set and stake balances
  withdraw    Withdraw unstaked funds from staking contract (withdraw(uint256))

Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
  -h, --help                  help for ibft

Global Flags:
      --json   get all outputs in json format (default false)

Use " ibft [command] --help" for more information about a command.
```

## `xgrchain ibft candidates`

```text
Queries the current set of proposed candidates, as well as candidates that have not been included yet

Usage:
   ibft candidates [flags]

Flags:
  -h, --help   help for candidates

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft interchain`

```text
Manage optional XGR interchain validator participation on configured EVM destinations

Usage:
   ibft interchain [command]

Available Commands:
  bootstrap-proof Create the validator BLS proof required to bootstrap an interchain registry
  fee             Configure a single native validator fee per source chain
  set-active      Activate or deactivate this XGR validator on an interchain destination
  storage-status  Measure persisted ILN quorum, vote, request and governance disk usage

Flags:
  -h, --help   help for interchain

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)

Use " ibft interchain [command] --help" for more information about a command.
```

## `xgrchain ibft interchain bootstrap-proof`

```text
Create the validator BLS proof required to bootstrap an interchain registry

Usage:
   ibft interchain bootstrap-proof [flags]

Flags:
      --config string               cloud secrets manager configuration
      --data-dir string             data directory of the validator secrets manager
      --destination-domain uint32   destination interchain domain
  -h, --help                        help for bootstrap-proof
      --origin-chain-id uint        XGR origin chain ID

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft interchain fee`

```text
Configure a single native validator fee per source chain

Usage:
   ibft interchain fee [command]

Available Commands:
  approve     Explicitly sign a source fee proposal with this validator BLS key
  create      Propose source-chain validator fee without signing it
  execute     Submit a completed source-chain fee quorum on chain

Flags:
  -h, --help   help for fee

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)

Use " ibft interchain fee [command] --help" for more information about a command.
```

## `xgrchain ibft interchain fee approve`

```text
Explicitly sign a source fee proposal with this validator BLS key

Usage:
   ibft interchain fee approve [flags]

Flags:
      --data-dir string      running validator node data directory
  -h, --help                 help for approve
      --proposal-id string   source fee proposal hash
      --timeout duration     worker response timeout (default 2m0s)

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft interchain fee create`

```text
Propose source-chain validator fee without signing it

Usage:
   ibft interchain fee create [flags]

Flags:
      --data-dir string    running validator node data directory
      --fee-wei string     chain-wide validator fee in native smallest units
  -h, --help               help for create
      --nonce uint         expected next source fee nonce; zero auto-detects
      --source string      configured source-chain name, e.g. base
      --timeout duration   worker response timeout (default 2m0s)
      --ttl duration       proposal lifetime, max 10m (default 5m0s)

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft interchain fee execute`

```text
Submit a completed source-chain fee quorum on chain

Usage:
   ibft interchain fee execute [flags]

Flags:
      --data-dir string      local running validator data directory
  -h, --help                 help for execute
      --proposal-id string   v3.1.5 source fee proposal
      --timeout duration     on-chain execution timeout (default 6m0s)

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft interchain set-active`

```text
Queues an interchain membership request to the running XGR validator node. The node validates canonical XGR PoS state, signs with the existing validator BLS key, collects the current interchain quorum, submits the destination transaction, and verifies final state.

Usage:
   ibft interchain set-active [flags]

Examples:
  # Activate this validator for Base
  xgrchain ibft interchain set-active --chain base --active true --data-dir ./data

  # Voluntarily deactivate this validator
  xgrchain ibft interchain set-active --chain base --active false --data-dir ./data

Flags:
      --active string      requested interchain active state: true or false
      --chain string       configured EVM interchain destination name, for example base
      --data-dir string    data directory of the running XGR validator node
  -h, --help               help for set-active
      --timeout duration   maximum time to wait for quorum, destination receipt, and final-state verification (default 2m0s)

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft interchain storage-status`

```text
Measure persisted ILN quorum, vote, request and governance disk usage

Usage:
   ibft interchain storage-status [flags]

Flags:
      --data-dir string   validator node data directory
  -h, --help              help for storage-status

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft join`

```text
One-shot PoS validator join: ensure keys, register BLS pubkey, stake required amount

Usage:
   ibft join [flags]

Examples:
  # Local validator
  xgrchain ibft join --jsonrpc http://127.0.0.1:8545 --data-dir ./data --stake 1000000

  # Remote chain node
  xgrchain ibft join --jsonrpc http://<rpc-host>:8545 --data-dir ./data --stake 1000000

Flags:
      --config string     secrets manager config (cloud)
      --data-dir string   data dir for local secrets manager (validator keys)
      --decimals int      native decimals for XGR (default 18) (default 18)
  -h, --help              help for join
      --init-keys         auto-generate missing ECDSA/BLS keys into secrets manager (default true)
      --init-only         only generate keys and print the validator address (no onchain tx)
      --jsonrpc string    JSON-RPC endpoint (default "http://127.0.0.1:8545")
      --stake string      stake amount in XGR (integer units, default 200,000) (default "200000")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft pool-config`

```text
Updates validator pool configuration by submitting a transaction over the configured JSON-RPC endpoint.

Usage:
   ibft pool-config [flags]

Flags:
      --commission-bps uint          Validator commission in basis points
      --config string                SecretsManager config file (optional)
      --data-dir string              Data directory for local secrets
      --enabled                      Enable or disable delegation pool (default true)
  -h, --help                         help for pool-config
      --init-keys                    Generate missing ECDSA key in data-dir/config
      --jsonrpc string               JSON-RPC endpoint (default "http://127.0.0.1:8545")
      --max-total-delegated string   maximum total delegated stake accepted by this validator pool (default "0")
      --min-delegator-stake string   minimum stake required per delegator; 0 uses global DELEGATOR_MIN_STAKE (default "0")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft propose`

```text
Proposes a new candidate to be added or removed from the validator set

Usage:
   ibft propose [flags]

Flags:
      --addr string   the address of the account to be voted for
      --bls string    the BLS Public Key of the account to be voted for
  -h, --help          help for propose
      --vote string   requested change to the validator set. Possible values: [auth, drop]

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft quorum`

```text
Specify the block number after which quorum optimal will be used for reaching consensus

Usage:
   ibft quorum [flags]

Flags:
      --chain string   the genesis file to update (default "./genesis.json")
      --from uint      the height to switch the quorum calculation
  -h, --help           help for quorum

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft set-active`

```text
Set validator active flag in staking contract (setActive(bool))

Usage:
   ibft set-active [flags]

Flags:
      --config string     SecretsManager config file (optional)
      --data-dir string   Data directory for local secrets (default "./data")
  -h, --help              help for set-active
      --init-keys         Generate missing ECDSA key in data-dir/config
      --insecure          Allow insecure key storage
      --jsonrpc string    JSON-RPC endpoint (default "http://127.0.0.1:8545")
      --value             Set active flag to true/false (default true)

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft snapshot`

```text
Returns the IBFT snapshot at the latest block number, unless a block number is specified

Usage:
   ibft snapshot [flags]

Flags:
  -h, --help          help for snapshot
      --number uint   the block height (number) for the snapshot (default 18446744073709551615)

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft stake`

```text
Increase stake in the staking contract (payable stake())

Usage:
   ibft stake [flags]

Flags:
      --amount string     Stake amount (integer, in token units) (default "0")
      --config string     SecretsManager config file (optional)
      --data-dir string   Data directory for local secrets (default "./data")
      --decimals int      Token decimals (default 18)
  -h, --help              help for stake
      --init-keys         Generate missing ECDSA key in data-dir/config
      --insecure          Allow insecure key storage
      --jsonrpc string    JSON-RPC endpoint (default "http://127.0.0.1:8545")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft status`

```text
Returns the current validator key of the IBFT client

Usage:
   ibft status [flags]

Flags:
  -h, --help   help for status

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft switch`

```text
Add settings in genesis.json to switch IBFT type

Usage:
   ibft switch [flags]

Flags:
      --chain string                 the genesis file to update (default "./genesis.json")
      --deployment string            the height to deploy the contract in PoS
      --from string                  the height to switch the new type
  -h, --help                         help for switch
      --ibft-validator-type string   the type of validators in IBFT (default "bls")
      --max-validator-count string   the maximum number of validators in the validator set for PoS
      --min-validator-count string   the minimum number of validators in the validator set for PoS
      --type string                  the new IBFT type [PoA, PoS]
      --validators stringArray       addresses to be used as IBFT validators, can be used multiple times. Needs to be present if validators-prefix is omitted
      --validators-path string       root path for validator folder directory. Needs to be present if validators is omitted (default "./")
      --validators-prefix string     prefix path for validator folder directory. Needs to be present if validators is omitted (default "test-chain-")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft unstake`

```text
Request unstake from staking contract (unstake())

Usage:
   ibft unstake [flags]

Examples:
# You must deactivate before unstake
xgrchain ibft set-active --value false --jsonrpc http://127.0.0.1:8545 --data-dir ./data --insecure

# Request unstake (withdraw is a separate step)
xgrchain ibft unstake --jsonrpc http://127.0.0.1:8545 --data-dir ./data --insecure

Flags:
      --config string     SecretsManager config file (optional)
      --data-dir string   Data directory for local secrets (default "./data")
  -h, --help              help for unstake
      --init-keys         Generate missing ECDSA key in data-dir/config
      --insecure          Allow insecure key storage
      --jsonrpc string    JSON-RPC endpoint (default "http://127.0.0.1:8545")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft validators`

```text
Show staking contract validator set and stake balances

Usage:
   ibft validators [flags]

Flags:
  -h, --help             help for validators
      --jsonrpc string   JSON-RPC endpoint (default "http://127.0.0.1:8545")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain ibft withdraw`

```text
Withdraw unstaked funds from staking contract (withdraw(uint256))

Usage:
   ibft withdraw [flags]

Examples:
# Partial withdraw from stake (keeps validator in staking contract)
# Preconditions: validator is deactivated and remaining stake after withdraw stays >= MIN_STAKE
xgrchain ibft set-active --value false --jsonrpc http://127.0.0.1:8545 --data-dir ./data --insecure
xgrchain ibft withdraw --amount 1000000 --jsonrpc http://127.0.0.1:8545 --data-dir ./data --insecure

# Full exit uses unstake (transfers full stake and removes validator metadata)
xgrchain ibft unstake --jsonrpc http://127.0.0.1:8545 --data-dir ./data --insecure

Flags:
      --amount string     Withdraw amount (integer, in token units) (default "0")
      --config string     SecretsManager config file (optional)
      --data-dir string   Data directory for local secrets (default "./data")
      --decimals int      Token decimals (default 18)
  -h, --help              help for withdraw
      --init-keys         Generate missing ECDSA key in data-dir/config
      --insecure          Allow insecure key storage
      --jsonrpc string    JSON-RPC endpoint (default "http://127.0.0.1:8545")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain license`

```text
Returns XGRChain license and dependency attributions

Usage:
   license [flags]

Flags:
  -h, --help   help for license

Global Flags:
      --json   get all outputs in json format (default false)
```

## `xgrchain monitor`

```text
Starts logging block add / remove events on the blockchain

Usage:
   monitor [flags]

Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
  -h, --help                  help for monitor

Global Flags:
      --json   get all outputs in json format (default false)
```

## `xgrchain peers`

```text
Top level command for interacting with the network peers. Only accepts subcommands.

Usage:
   peers [command]

Available Commands:
  add         Adds new peers to the peer list, using the peer's libp2p address
  list        Returns the list of connected peers, including the current node
  status      Returns the status of the specified peer, using the libp2p ID of the peer node

Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
  -h, --help                  help for peers

Global Flags:
      --json   get all outputs in json format (default false)

Use " peers [command] --help" for more information about a command.
```

## `xgrchain peers add`

```text
Adds new peers to the peer list, using the peer's libp2p address

Usage:
   peers add [flags]

Flags:
      --addr stringArray   the libp2p addresses of the peers
  -h, --help               help for add

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain peers list`

```text
Returns the list of connected peers, including the current node

Usage:
   peers list [flags]

Flags:
  -h, --help   help for list

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain peers status`

```text
Returns the status of the specified peer, using the libp2p ID of the peer node

Usage:
   peers status [flags]

Flags:
  -h, --help             help for status
      --peer-id string   libp2p node ID of a specific peer within p2p network

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain regenesis`

```text
Copies trie for specific block to a separate folder

Usage:
   regenesis [flags]
   regenesis [command]

Available Commands:
  getroot     returns state root of old chain
  history     run history test

Flags:
  -h, --help                 help for regenesis
      --source-path string   the directory of trie data of old chain
      --stateRoot string     block state root of old chain
      --target-path string   the directory of trie data of trie copy

Global Flags:
      --json   get all outputs in json format (default false)

Use " regenesis [command] --help" for more information about a command.
```

## `xgrchain regenesis getroot`

```text
returns state root of old chain

Usage:
   regenesis getroot [flags]

Flags:
      --block int    Block number of trie snapshot (default -1)
  -h, --help         help for getroot
      --rpc string   the JSON RPC IP address for old chain

Global Flags:
      --json   get all outputs in json format (default false)
```

## `xgrchain regenesis history`

```text
run history test

Usage:
   regenesis history [flags]

Flags:
      --chaindb string   path to chain db
      --from uint        lower bound of regenesis test(default is 0)
  -h, --help             help for history
      --to uint          upper bound of regenesis test(default is head)
      --triedb string    path to trie db

Global Flags:
      --json   get all outputs in json format (default false)
```

## `xgrchain secrets`

```text
Top level SecretsManager command for interacting with secrets functionality. Only accepts subcommands.

Usage:
   secrets [command]

Available Commands:
  generate    Initializes the secrets manager configuration in the provided directory.
  init        Initializes private keys for the XGRChain (Validator + Networking) to the specified Secrets Manager
  output      Outputs validator key address and public network key from the provided Secrets Manager

Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
  -h, --help                  help for secrets

Global Flags:
      --json   get all outputs in json format (default false)

Use " secrets [command] --help" for more information about a command.
```

## `xgrchain secrets generate`

```text
Initializes the secrets manager configuration in the provided directory.

Usage:
   secrets generate [flags]

Flags:
      --dir string          the directory for the secrets manager configuration file (default "./secretsManagerConfig.json")
      --extra string        Specifies the extra fields map in string format 'key1=val1,key2=val2'
  -h, --help                help for generate
      --name string         the name of the node for on-service record keeping
      --namespace string    the namespace for the service (default "admin")
      --server-url string   the server URL for the service
      --token string        the access token for the service
      --type string         the type of the secrets manager. Available types: hashicorp-vault, aws-ssm and gcp-ssm (default "hashicorp-vault")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain secrets init`

```text
Initializes private keys for the XGRChain (Validator + Networking) to the specified Secrets Manager

Usage:
   secrets init [flags]

Flags:
      --bls               the flag indicating whether new BLS key is created (default true)
      --config string     the path to the SecretsManager config file, if omitted, the local FS secrets manager is used
      --data-dir string   the directory for the XGRChain data if the local FS is used
      --ecdsa             the flag indicating whether new ECDSA key is created (default true)
  -h, --help              help for init
      --insecure          the flag indicating should the secrets stored on the local storage be encrypted
      --network           the flag indicating whether new Network key is created (default true)
      --num int           the flag indicating how many secrets should be created, only for the local FS (default 1)

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain secrets output`

```text
Outputs validator key address and public network key from the provided Secrets Manager

Usage:
   secrets output [flags]

Flags:
      --bls               output only the BLS public key from the provided secrets manager
      --config string     the path to the SecretsManager config file, if omitted, the local FS secrets manager is used
      --data-dir string   the directory for the XGRChain data if the local FS is used
  -h, --help              help for output
      --node-id           output only the node id from the provided secrets manager
      --validator         output only the validator key address from the provided secrets manager

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain server`

```text
The default command that starts the XGRChain client, by bootstrapping all modules together

Usage:
   server [flags]
   server [command]

Available Commands:
  export      export default-config.yaml file with default parameters that can be used to run the server

Flags:
      --access-control-allow-origins stringArray   the CORS header indicating whether any JSON-RPC response can be shared with the specified origin (default [*])
      --block-gas-target string                    the target block gas limit for the chain. If omitted, the value of the parent block is used (default "0x0")
      --chain string                               the genesis file used for starting the chain (default "./genesis.json")
      --concurrent-requests-debug uint             maximal number of concurrent requests for debug endpoints (default 32)
      --config string                              the path to the CLI config. Supports .json, .hcl, .yaml, .yml
      --data-dir string                            the data directory used for storing XGRChain client data
      --dns string                                 the host DNS address which can be used by a remote peer for connection
      --grpc-address string                        the GRPC interface (default "127.0.0.1:9632")
  -h, --help                                       help for server
      --json-rpc-batch-request-limit uint          max length to be considered when handling json-rpc batch requests, value of 0 disables it (default 20)
      --json-rpc-block-range-limit uint            max block range to be considered when executing json-rpc requests that consider fromBlock/toBlock values (e.g. eth_getLogs), value of 0 disables it (default 1000)
      --jsonrpc string                             the JSON-RPC interface (default "http://0.0.0.0:8545")
      --libp2p string                              the address and port for the libp2p service (default "127.0.0.1:1478")
      --log-level string                           the log level for console output (default "INFO")
      --log-to string                              write all logs to the file at specified location instead of writing them to console
      --max-enqueued uint                          maximum number of enqueued transactions per account (default 128)
      --max-inbound-peers int                      the client's max number of inbound peers allowed (default 32)
      --max-outbound-peers int                     the client's max number of outbound peers allowed (default 8)
      --max-peers int                              the client's max number of peers allowed (default 40)
      --max-slots uint                             maximum slots in the pool (default 4096)
      --metrics-interval duration                  the interval (in seconds) at which special metrics are generated. a value of zero means the metrics are disabled (default 8s)
      --nat string                                 the external IP address without port, as can be seen by peers
      --no-discover                                prevent the client from discovering other peers
      --num-block-confirmations uint               minimal number of child blocks required for the parent block to be considered final (default 64)
      --price-limit uint                           the minimum gas price limit to enforce for acceptance into the pool (default 0)
      --prometheus string                          the address and port for the prometheus instrumentation service (address:port). If only port is defined (:port) it will bind to 0.0.0.0:port
      --relayer                                    start the state sync relayer service
      --restore string                             the path to the archive blockchain data to restore on initialization
      --seal                                       the flag indicating that the client should seal blocks (default true)
      --secrets-config string                      the path to the SecretsManager config file. Used for Hashicorp Vault. If omitted, the local FS secrets manager is used
      --trie-sweeper                               enable the online immutable-trie mark-and-sweep garbage collector
      --trie-sweeper-interval duration             interval between completed trie sweeper cycles (default 6h0m0s)
      --trie-sweeper-retain-blocks uint            number of latest canonical state roots retained by the trie sweeper (default 10000)
      --websocket-read-limit uint                  maximum size in bytes for a message read from the peer by websocket (default 8192)

Global Flags:
      --json   get all outputs in json format (default false)

Use " server [command] --help" for more information about a command.
```

## `xgrchain server export`

```text
export default-config.yaml file with default parameters that can be used to run the server

Usage:
   server export [flags]

Flags:
  -h, --help          help for export
      --type string   file type of exported config file (yaml or json) (default "yaml")

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
      --jsonrpc string        the JSON-RPC interface (default "http://0.0.0.0:8545")
```

## `xgrchain status`

```text
Returns the status of the XGRChain client

Usage:
   status [flags]

Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
  -h, --help                  help for status

Global Flags:
      --json   get all outputs in json format (default false)
```

## `xgrchain txpool`

```text
Top level command for interacting with the transaction pool. Only accepts subcommands.

Usage:
   txpool [command]

Available Commands:
  status      Returns the number of transactions in the transaction pool
  subscribe   Logs specific TxPool events

Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
  -h, --help                  help for txpool

Global Flags:
      --json   get all outputs in json format (default false)

Use " txpool [command] --help" for more information about a command.
```

## `xgrchain txpool status`

```text
Returns the number of transactions in the transaction pool

Usage:
   txpool status [flags]

Flags:
  -h, --help   help for status

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain txpool subscribe`

```text
Logs specific TxPool events

Usage:
   txpool subscribe [flags]

Flags:
      --added             should subscribe to added events
      --demoted           should subscribe to demoted events
      --dropped           should subscribe to dropped events
      --enqueued          should subscribe to enqueued events
  -h, --help              help for subscribe
      --promoted          should subscribe to promoted events
      --pruned-enqueued   should subscribe to pruned enqueued tx events in the TxPool
      --pruned-promoted   should subscribe to pruned promoted tx events in the TxPool

Global Flags:
      --grpc-address string   the GRPC interface (default "127.0.0.1:9632")
      --json                  get all outputs in json format (default false)
```

## `xgrchain version`

```text
Returns the current XGRChain version

Usage:
   version [flags]

Flags:
  -h, --help   help for version

Global Flags:
      --json   get all outputs in json format (default false)
```
