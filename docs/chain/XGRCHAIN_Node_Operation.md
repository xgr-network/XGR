# XGR Chain — Node Operation

**Document ID:** XGRCHAIN-NODE-OPERATION  
**Last updated:** 2026-05-03  
**Audience:** Node operators, validators, infrastructure engineers, developers  
**Implementation status:** Mixed  
**Source of truth:** `xgrchain`, `scripts/cluster`, `docker/`, `go.mod`

---

## 1. Scope

This document describes how to build, install, configure and operate an XGR Chain node.

It covers:

- hardware requirements
- software prerequisites
- installation options
- building from source
- local IBFT development cluster
- Docker-based local environment
- secrets and validator key material
- node startup
- server/runtime flags
- RPC and health checks
- logging and metrics
- basic operational security

This document does **not** define:

- genesis network parameters
- IBFT consensus theory
- staking / PoS / delegation rules
- XDaLa Engine RPC semantics
- bridge/rootchain/Supernet operations
- PolyBFT operation

Use the dedicated documents for those topics.

---

## 2. Recommended hardware

Minimum and recommended hardware depend on network load, archive retention, transaction volume and RPC exposure.

| Component | Minimum | Recommended |
|---|---:|---:|
| CPU | 4 cores | 8+ cores |
| Memory | 8 GB RAM | 16+ GB RAM |
| Storage | 200 GB SSD | 1 TB+ SSD / NVMe |
| Network | Stable broadband | Dedicated server / gigabit uplink |
| OS | Linux server distribution | Hardened Linux server distribution |

Operational guidance:

- Use SSD/NVMe storage. Avoid slow HDDs.
- Keep enough disk headroom for chain growth, logs and backups.
- Prefer server Linux distributions over desktop environments.
- Keep the OS patched.
- Run validators on stable, low-latency network links.
- Protect validator key material from interactive user accounts and web-facing services.

---

## 3. Software prerequisites

Required for source builds:

| Dependency | Requirement |
|---|---|
| Go | `go 1.23.4` / toolchain `go1.23.11` |
| Git | Required for source checkout |
| C compiler / build tools | Recommended for native builds and dependencies |
| Docker | Required only for Docker/local container setups |
| docker-compose | Required by the local Docker helper |

The current `PoS_3` source uses:

```text
go 1.23.4
toolchain go1.23.11
```

Do not use the old Polygon Edge requirement of Go 1.15–1.19 for current XGR Chain builds.

---

## 4. Installation options

### 4.1 Pre-built release

If a trusted pre-built binary is available, prefer the release artifact and verify checksums before use.

General workflow:

```bash
# Example only: exact file names depend on the release artifact
curl -L -o xgrchain <release-url>
chmod +x xgrchain
./xgrchain version
```

Use only release artifacts published by the XGR Network organization.

### 4.2 Docker image

If a maintained image is available:

```bash
docker pull xgrnetwork/xgrchain:latest
```

Use explicit version tags for production deployments instead of `latest`.

### 4.3 Build from source

Clone and build:

```bash
git clone https://github.com/xgr-network/xgrchain.git
cd xgrchain
go build -o xgrchain .
```

For the `PoS_3` branch:

```bash
git checkout PoS_3
go build -o xgrchain .
```

For race-enabled test binaries:

```bash
go build -race -o artifacts/xgrtestrun .
```

---

## 5. Repository-local Engine behavior

The current source tree is designed to build standalone even if the private Engine module is absent.

The module configuration uses:

```text
replace github.com/xgr-network/xgrEngine => ./xgrEngine
```

For embedded Engine builds, override this replace with the real private Engine module or a Go workspace override and use the required build tags.

Public node-operation documentation should not expose private Engine internals.

---

## 6. Local IBFT development cluster

The repository provides a helper script for a local IBFT test environment:

```bash
./scripts/cluster ibft
```

The script performs the following high-level actions:

1. removes old `test-chain-*` directories and `genesis.json`
2. builds `xgrchain`
3. generates local insecure validator secrets
4. creates a local IBFT genesis
5. starts four local validator nodes

The helper is for development and test environments.

It must not be used unchanged for production validator deployment.

---

## 7. Local cluster ports

The non-Docker local cluster starts four nodes.

Port pattern:

| Node | Data dir | gRPC | libp2p | JSON-RPC |
|---|---|---:|---:|---:|
| 1 | `./test-chain-1` | `:10000` | `:30301` | `:10002` |
| 2 | `./test-chain-2` | `:20000` | `:30302` | `:20002` |
| 3 | `./test-chain-3` | `:30000` | `:30303` | `:30002` |
| 4 | `./test-chain-4` | `:40000` | `:30304` | `:40002` |

The helper uses this server pattern:

```bash
./xgrchain server \
  --data-dir ./test-chain-1 \
  --chain genesis.json \
  --grpc-address :10000 \
  --libp2p :30301 \
  --jsonrpc :10002 \
  --num-block-confirmations 2 \
  --log-level DEBUG
```

---

## 8. Docker local environment

The repository contains a Docker-based local IBFT environment.

Prerequisites:

- Docker
- docker-compose

Start:

```bash
export EDGE_CONSENSUS=ibft
docker-compose -f docker/local/docker-compose.yml up -d --build
```

or via helper:

```bash
./scripts/cluster ibft --docker
```

Stop:

```bash
./scripts/cluster ibft --docker stop
```

Destroy containers and volumes:

```bash
./scripts/cluster ibft --docker destroy
```

This environment is for local development and testing. Do not treat it as a production deployment template.

---

## 9. Secrets and key material

XGR Chain nodes require node and validator key material depending on their role.

For a local insecure development setup:

```bash
./xgrchain secrets init --insecure --data-dir test-chain- --num 4
```

This generates local test directories:

```text
test-chain-1
test-chain-2
test-chain-3
test-chain-4
```

Generated secrets include:

| Secret | Purpose |
|---|---|
| network key | libp2p node identity |
| validator ECDSA key | validator/account identity |
| validator BLS key | IBFT BLS consensus sealing |

To inspect existing local secrets:

```bash
./xgrchain secrets output --data-dir test-chain-1
```

### Production warning

Do not use `--insecure` in production.

Production validators should use hardened secret storage and strict filesystem permissions. If an external secret manager is used, configure it explicitly and test recovery procedures before going live.

---

## 10. Manual node startup

Basic server command:

```bash
./xgrchain server \
  --data-dir ./node-data \
  --chain ./genesis.json \
  --grpc-address 127.0.0.1:9632 \
  --libp2p 0.0.0.0:1478 \
  --jsonrpc 127.0.0.1:8545 \
  --seal \
  --log-level INFO
```

Validator nodes generally require:

- valid genesis file
- initialized data directory
- validator key material
- reachable p2p networking
- stable clock
- enough peer connectivity to reach IBFT quorum

Non-validator full/RPC nodes should not run with validator signing material.

---

## 11. Server/runtime flags

The following flags are relevant for node operation. Exact availability may differ by branch/build; always verify with:

```bash
./xgrchain server --help
```

### 11.1 Core flags

| Flag | Purpose |
|---|---|
| `--chain` | Path to genesis file |
| `--data-dir` | Node data directory |
| `--config` | Path to CLI config file |
| `--seal` | Enable block sealing/validation behavior |
| `--restore` | Restore from archive data on initialization |
| `--log-level` | Console log level |
| `--log-to` | Write logs to file |

### 11.2 RPC and API flags

| Flag | Purpose |
|---|---|
| `--jsonrpc` | JSON-RPC listen address |
| `--grpc-address` | gRPC listen address |
| `--access-control-allow-origins` | CORS origins for JSON-RPC |
| `--json-rpc-batch-request-limit` | Maximum JSON-RPC batch size |
| `--json-rpc-block-range-limit` | Maximum block range for range queries such as `eth_getLogs` |
| `--concurrent-requests-debug` | Concurrency limit for debug endpoints |
| `--websocket-read-limit` | Maximum WebSocket read size |

### 11.3 Networking flags

| Flag | Purpose |
|---|---|
| `--libp2p` | libp2p listen address |
| `--nat` | External IP address advertised to peers |
| `--dns` | DNS name advertised to peers |
| `--no-discover` | Disable peer discovery |
| `--max-peers` | Maximum total peers |
| `--max-inbound-peers` | Maximum inbound peers |
| `--max-outbound-peers` | Maximum outbound peers |

### 11.4 Metrics and observability flags

| Flag | Purpose |
|---|---|
| `--prometheus` | Prometheus instrumentation listen address |
| `--metrics-interval` | Interval for special metric generation |

### 11.5 Gas / txpool flags

| Flag | Purpose |
|---|---|
| `--block-gas-target` | Target block gas limit adjustment behavior |
| `--price-limit` | Minimum gas price/effective price accepted into txpool |
| `--max-slots` | Maximum txpool slots |
| `--max-enqueued` | Maximum enqueued transactions per account |

### 11.6 Legacy / non-canonical flags

Some old Polygon Edge documentation referenced flags such as:

| Flag | XGR documentation status |
|---|---|
| `--relayer` | Legacy bridge/state-sync related; not part of current public XGR Chain operation docs |
| `--num-block-confirmations` | May be useful in local/test helpers; rootchain-finality meaning is legacy |
| bridge allow/block list flags | Legacy / not part of current XGR Chain docs |
| rootchain tracker flags | Legacy / not part of current XGR Chain docs |

Do not use old bridge/rootchain flags as production XGR Chain guidance unless the specific feature is reintroduced and documented.

---

## 12. Basic RPC checks

Check latest block number:

```bash
curl -s -X POST http://127.0.0.1:10002 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Check chain ID:

```bash
curl -s -X POST http://127.0.0.1:10002 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
```

Check peer count:

```bash
curl -s -X POST http://127.0.0.1:10002 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

Check syncing state:

```bash
curl -s -X POST http://127.0.0.1:10002 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_syncing","params":[]}'
```

---

## 13. Validator and IBFT checks

IBFT-related CLI commands may include:

```bash
./xgrchain ibft status
./xgrchain ibft snapshot
./xgrchain ibft candidates
./xgrchain ibft quorum
```

Exact command availability depends on the branch/build.

Use:

```bash
./xgrchain ibft --help
```

for the active command list.

For current PoS/staking branch functionality, use the dedicated staking/PoS documentation once finalized. Do not mix in old rootchain/Supernet staking flows.

---

## 14. PoS overview endpoint note

Some current development branches expose PoS/staking monitoring endpoints such as:

```text
eth_getPosValidatorsOverview
eth_getPosValidatorDelegators
```

These are not standard Ethereum JSON-RPC endpoints and should be documented in:

```text
XGRCHAIN_Staking_PoS_Endpoint_Reference.md
```

Do not document deprecated beacon/recovery behavior as active node operation.

---

## 15. Logging

Recommended log practices:

- Use `INFO` for normal production operation.
- Use `DEBUG` for local troubleshooting only.
- Write logs to files or a central log collector for validator nodes.
- Monitor repeated round changes, peer disconnects, txpool errors and signer errors.
- Rotate logs to avoid disk exhaustion.

Example:

```bash
./xgrchain server \
  --data-dir ./node-data \
  --chain ./genesis.json \
  --jsonrpc 127.0.0.1:8545 \
  --libp2p 0.0.0.0:1478 \
  --log-level INFO \
  --log-to ./xgrchain.log
```

---

## 16. Metrics

If Prometheus metrics are enabled:

```bash
./xgrchain server \
  --data-dir ./node-data \
  --chain ./genesis.json \
  --prometheus 0.0.0.0:9090
```

Operators should monitor at least:

- block height progression
- peer count
- consensus round changes
- block proposal timing
- transaction pool size
- RPC latency/error rate
- disk usage
- memory usage
- CPU usage
- open file descriptors
- validator signing errors

---

## 17. Network security

Recommended production practices:

- Do not expose validator gRPC publicly.
- Restrict JSON-RPC access by firewall or reverse proxy.
- Do not expose debug endpoints publicly.
- Do not keep validator keys on public RPC-only nodes.
- Keep p2p ports reachable only as needed.
- Use systemd or equivalent process supervision.
- Apply OS security updates.
- Use separate users for node processes.
- Back up validator keys securely.
- Test key recovery before mainnet operation.
- Monitor disk usage and log growth.

---

## 18. Public RPC exposure

For public JSON-RPC infrastructure:

- prefer dedicated non-validator RPC nodes
- rate-limit public endpoints
- restrict debug/txpool namespaces
- use TLS termination at a reverse proxy
- configure CORS intentionally
- set JSON-RPC batch and block-range limits
- monitor RPC abuse and resource saturation

Relevant public RPC docs:

- `XGRCHAIN_Ethereum_JSON_RPC_Reference.md`
- `XDaLa_Engine_JSON_RPC_Endpoint_Reference.md`

---

## 19. Local development workflow

A compact local development flow:

```bash
git clone https://github.com/xgr-network/xgrchain.git
cd xgrchain
git checkout PoS_3
go build -o xgrchain .
./scripts/cluster ibft
```

In another terminal:

```bash
curl -s -X POST http://127.0.0.1:10002 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Stop the foreground cluster with `Ctrl+C`.

For Docker:

```bash
./scripts/cluster ibft --docker
./scripts/cluster ibft --docker stop
./scripts/cluster ibft --docker destroy
```

---

## 20. Explicit legacy exclusions

The following old Polygon Edge / Supernet operation topics are not part of this XGR Chain node-operation document:

- rootchain setup
- childchain bridge setup
- rootchain validator allowlisting
- `CustomSupernetManager`
- rootchain `StakeManager`
- WMATIC staking
- bridge relayer operation
- state sync relayer operation
- checkpoint manager operation
- ERC predicate deployment
- PolyBFT bridge/checkpoint flow
- Beacon recovery logic

If any of those features are intentionally reintroduced in XGR, they must receive separate XGR-specific documentation.

---

## 21. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Introduction.md` | High-level architecture |
| `XGRCHAIN_Chain_Spec.md` | Chain-level protocol specification |
| `XGRCHAIN_Genesis_and_Configuration.md` | Mainnet genesis and network-defining configuration |
| `XGRCHAIN_Consensus_IBFT.md` | IBFT consensus behavior |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Public Ethereum-compatible RPC |
| `XRC-GAS_Gas_Price_Behavior.md` | Gas and fee behavior |
| `XGRCHAIN_Staking_PoS_Model.md` | Upcoming staking/PoS model |
| `XGRCHAIN_Staking_PoS_Endpoint_Reference.md` | Upcoming staking/PoS RPC reference |
