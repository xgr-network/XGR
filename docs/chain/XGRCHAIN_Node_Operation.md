# XGR Chain — Node Operation

**Document ID:** XGRCHAIN-NODE-OPERATION  
**Last updated:** 2026-05-03  
**Audience:** Node operators, validators, RPC operators, infrastructure engineers  
**Implementation status:** Public baseline operator guidance for versioned `xgr-network/xgr-node` releases  
**Source of truth:** Public `xgr-network/xgr-node` releases, published XGR Chain configuration, and official XGR Network operator announcements

---

## 1. Scope

This document describes how to build, install, configure, start, monitor, secure, back up, and upgrade an XGR Chain node.

It is written for operators using the public node implementation:

```text
https://github.com/xgr-network/xgr-node
```

The examples in this document use the public stable release model, with `v1.1.1` as the current baseline example.

This document covers:

- public release selection
- build prerequisites
- building the node binary
- recommended installation layout
- node roles
- hardware guidance
- genesis and configuration usage
- data directory handling
- key material handling
- full node startup
- validator node startup
- RPC node startup
- network ports
- P2P configuration
- runtime flags
- JSON-RPC checks
- validator health checks
- logging
- metrics
- systemd operation
- backups
- upgrades
- security
- troubleshooting
- public documentation boundaries

This document does **not** define:

- network-defining genesis values
- chain economics
- staking activation rules
- consensus theory
- XDaLa endpoint semantics
- application-layer contract standards

Use the dedicated XGR documentation for those topics.

---

## 2. Public repository and release model

The public node repository is:

```text
https://github.com/xgr-network/xgr-node
```

Operators should use versioned releases or tags for production deployments.

Current public baseline example:

```text
v1.1.1
```

Release example:

```text
https://github.com/xgr-network/xgr-node/releases/tag/v1.1.1
```

Production operators should not run arbitrary development commits. Use only:

- official release tags
- official release artifacts
- explicitly announced operator builds

Recommended release policy:

| Environment | Recommended source |
|---|---|
| Production validator | Official release tag or official release artifact |
| Production RPC node | Official release tag or official release artifact |
| Staging node | Same release candidate or tag intended for production |
| Local testing | Public release tag or documented public test release |

Before upgrading production infrastructure:

1. Read the official release notes.
2. Confirm the expected release tag.
3. Confirm the published chain configuration.
4. Test the release on a non-critical node.
5. Coordinate validator upgrades if the release contains consensus or hardfork changes.

---

## 3. Public baseline responsibilities

The public node repository provides the baseline node implementation for:

- EVM execution
- consensus networking
- standard Ethereum JSON-RPC interface
- configuration and genesis tooling
- node process operation
- P2P networking
- txpool handling
- local storage
- metrics and logging hooks

The public node repository is not the place where operators should invent network parameters.

Network-defining parameters must come from:

- published XGR Chain configuration
- official release notes
- official XGR Network operator announcements
- public XGR documentation

---

## 4. Build prerequisites

For source builds, install:

| Dependency | Purpose |
|---|---|
| Git | Clone the public node repository and fetch release tags |
| Go | Build the node binary |
| Linux build tools | Native compilation support |
| ca-certificates / curl | Fetch release metadata and perform operational checks |
| systemd | Recommended process supervision on Linux servers |

For the public `v1.1.1` baseline, the module declares:

```text
go 1.23.4
toolchain go1.23.11
```

Check your local Go installation:

```bash
go version
```

Recommended production build environment:

```text
Linux server
Go 1.23.x compatible with the selected release
Clean checkout of the selected release tag
No uncommitted local code changes
```

---

## 5. Clone and build from public release

Clone the public repository:

```bash
git clone https://github.com/xgr-network/xgr-node.git
cd xgr-node
```

Fetch release tags:

```bash
git fetch --tags
```

Check out the selected release:

```bash
git checkout v1.1.1
```

Confirm the selected revision:

```bash
git status
git describe --tags --always
```

Confirm the module path and Go version:

```bash
head -n 20 go.mod
```

Build the node binary:

```bash
go build -o xgrchain .
```

Check the binary:

```bash
./xgrchain version
```

If the release publishes official binary artifacts, operators may use those instead of building from source. In that case, verify the artifact source and checksum before installation.

---

## 6. Recommended installation layout

Recommended production layout:

```text
/opt/xgr/bin/xgrchain        Node binary
/etc/xgr/genesis.json        Published XGR Chain genesis/config file
/etc/xgr/node.env            Optional environment file for service configuration
/var/lib/xgr/node            Node data directory
/var/log/xgr/                Node logs, if file logging is used
```

Create a dedicated system user:

```bash
sudo useradd --system --home /var/lib/xgr --shell /usr/sbin/nologin xgr
```

Create directories:

```bash
sudo install -d -m 0755 /opt/xgr/bin
sudo install -d -m 0755 /etc/xgr
sudo install -d -m 0750 -o xgr -g xgr /var/lib/xgr
sudo install -d -m 0700 -o xgr -g xgr /var/lib/xgr/node
sudo install -d -m 0750 -o xgr -g xgr /var/log/xgr
```

Install the binary:

```bash
sudo install -m 0755 ./xgrchain /opt/xgr/bin/xgrchain
```

Install the published genesis file:

```bash
sudo install -m 0644 ./genesis.json /etc/xgr/genesis.json
```

Do not edit the genesis file locally for a production network unless XGR Network has published a new configuration or an explicit operator instruction.

---

## 7. Node roles

XGR Chain infrastructure can be operated in different roles.

### 7.1 Validator node

A validator participates in consensus and signs blocks.

Validator node characteristics:

- holds validator signing material
- runs with sealing enabled
- requires stable P2P connectivity
- should not expose public JSON-RPC directly
- should run on hardened infrastructure
- should be monitored continuously

Recommended exposure:

| Interface | Exposure |
|---|---|
| P2P | Public or allowlisted, depending on network topology |
| JSON-RPC | Localhost or private management network only |
| gRPC | Localhost only |
| Metrics | Localhost, VPN, or monitoring network only |

### 7.2 Full node

A full node follows the chain and verifies blocks, but does not sign blocks.

Full node characteristics:

- does not require validator signing material
- must explicitly disable sealing
- maintains local chain state
- can serve internal RPC traffic
- can be used for monitoring, indexing, redundancy, or application backends

Important:

```text
The current server default enables sealing. Non-validator full nodes must use --seal=false.
```

### 7.3 RPC node

An RPC node is a full node configured to serve JSON-RPC traffic.

RPC node characteristics:

- should not hold validator signing material
- should not sign blocks
- must explicitly disable sealing
- should be placed behind a reverse proxy or load balancer
- should use rate limits
- should restrict dangerous namespaces
- should enforce batch and block-range limits

Important:

```text
RPC nodes must use --seal=false unless they are intentionally operated as validators, which is not recommended for public RPC infrastructure.
```

### 7.4 Bootnode

A bootnode helps other nodes discover peers.

Bootnode characteristics:

- provides stable P2P identity and addressability
- does not need validator signing material
- should have stable uptime and network reachability
- should not expose public JSON-RPC unless also intentionally operated as an RPC node

---

## 8. Hardware guidance

Actual requirements depend on transaction volume, block size, RPC load, log retention, and indexing requirements.

| Role | CPU | RAM | Storage | Network |
|---|---:|---:|---:|---|
| Validator | 4+ cores | 8–16 GB | 200 GB+ SSD/NVMe | Stable low-latency uplink |
| Full node | 4+ cores | 8–16 GB | 200 GB+ SSD/NVMe | Stable broadband/uplink |
| RPC node | 8+ cores | 16–32 GB | 500 GB+ SSD/NVMe | High-throughput uplink |
| Bootnode | 2–4 cores | 4–8 GB | 100 GB+ SSD | Stable public reachability |

Recommended production baseline:

```text
8 CPU cores
16 GB RAM
1 TB NVMe
Linux server OS
Stable public IP or stable DNS
NTP time synchronization
```

Operational notes:

- Use SSD or NVMe storage.
- Avoid slow HDD-backed data directories.
- Keep at least 25–30% free disk headroom.
- Monitor disk growth and log growth.
- Use time synchronization.
- Avoid colocating validator keys with public RPC workloads.
- Avoid running multiple production nodes from the same data directory.

---

## 9. Genesis and chain configuration

The public node software and the chain configuration are separate concerns.

The public node repository provides:

- EVM execution
- consensus networking
- standard JSON-RPC interface
- genesis/configuration tooling

The network-defining chain configuration is maintained in the XGR documentation/project repository and official XGR Network operator announcements.

Operators must use the published XGR Chain configuration for the target network.

Typical production path:

```text
/etc/xgr/genesis.json
```

Start commands should reference that file explicitly:

```bash
--chain /etc/xgr/genesis.json
```

Do not generate an ad-hoc genesis for a public network node.

Do not change:

- chain ID
- initial validator set
- consensus parameters
- fork activation settings
- premine or allocation values
- gas configuration
- bootnodes

unless the change is part of a published XGR Network configuration update.

---

## 10. Data directory

The data directory stores node state.

Recommended path:

```text
/var/lib/xgr/node
```

Rules:

- one data directory per node
- never share a data directory between two running node processes
- do not delete the data directory unless you intend to resync or restore
- ensure the node user owns the directory
- keep the directory off slow or unreliable storage
- back up key material separately from chain data

Set ownership:

```bash
sudo chown -R xgr:xgr /var/lib/xgr/node
sudo chmod 0700 /var/lib/xgr/node
```

For full nodes and RPC nodes, chain data can usually be rebuilt by resyncing.

For validator nodes, key material is critical and must be backed up securely.

---

## 11. Key material

XGR Chain nodes use key material depending on node role.

Typical key categories:

| Key material | Required for | Notes |
|---|---|---|
| P2P node identity | All networked nodes | Identifies the node in the P2P network |
| Validator signing key | Validator nodes | Used for consensus participation |
| Account keys | Operational accounts | Should not be stored on public RPC nodes |

Validator key rules:

- keep validator keys off public RPC nodes
- restrict filesystem permissions
- use a dedicated service user
- avoid interactive shell access to validator machines
- keep encrypted offline backups
- test recovery before production use
- rotate infrastructure credentials independently from chain keys
- never paste validator private keys into tickets, chats, logs, dashboards, or public docs

Recommended permissions:

```bash
sudo chown -R xgr:xgr /var/lib/xgr/node
sudo chmod -R go-rwx /var/lib/xgr/node
```

If an external secret manager is used, configure it according to the public release documentation and test node restart and recovery behavior before relying on it in production.

---

## 12. Address and URL syntax

Server bind flags use `host:port` syntax.

Examples:

```text
--jsonrpc 127.0.0.1:8545
--grpc-address 127.0.0.1:9632
--libp2p 0.0.0.0:1478
--prometheus 127.0.0.1:9090
```

Do not pass an HTTP URL to the server bind flag:

```text
Wrong for server flag:
--jsonrpc http://127.0.0.1:8545
```

Use HTTP URLs only for clients such as `curl`:

```text
Correct for curl:
http://127.0.0.1:8545
```

This distinction matters because the node process resolves bind addresses as TCP addresses.

---

## 13. Full node startup example

A full node follows the chain but does not sign blocks.

Important:

```text
The current server default enables sealing. A non-validator full node must explicitly use --seal=false.
```

Example:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --log-level INFO \
  --log-to /var/log/xgr/node.log
```

Replace:

```text
<PUBLIC_IP>
```

with the node's externally reachable IP address if needed.

If the node is behind DNS, use the release-supported DNS option instead of a raw IP where appropriate.

Full node checklist:

- correct release tag
- correct published genesis file
- unique data directory
- reachable P2P port
- sealing explicitly disabled with `--seal=false`
- sufficient peer count
- local JSON-RPC health check succeeds
- node height follows the network

---

## 14. Validator node startup example

A validator signs blocks and participates in consensus.

The server default enables sealing, but validator examples should still pass `--seal=true` explicitly for clarity.

Example:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=true \
  --log-level INFO \
  --log-to /var/log/xgr/validator.log
```

Validator checklist:

- validator key material is present
- validator key material belongs to the intended validator
- key permissions are restricted
- system clock is synchronized
- P2P connectivity is stable
- node is not exposing public JSON-RPC directly
- node reaches current chain height
- consensus logs show normal participation
- no repeated signer errors
- no repeated round-change loops
- no disk pressure
- service restarts cleanly

Do not run validator signing material on a public RPC endpoint.

---

## 15. RPC node startup example

An RPC node serves JSON-RPC traffic and should not be a validator.

Important:

```text
The current server default enables sealing. A public or internal RPC-only node must explicitly use --seal=false.
```

Example internal bind:

```bash
/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --json-rpc-batch-request-limit 20 \
  --json-rpc-block-range-limit 1000 \
  --log-level INFO \
  --log-to /var/log/xgr/rpc.log
```

Expose public RPC through a reverse proxy, not by binding the node directly to the public internet unless that is explicitly intended and secured.

Recommended public RPC architecture:

```text
Internet
  -> TLS reverse proxy / load balancer
  -> rate limiting
  -> RPC node on localhost or private network
```

RPC node checklist:

- no validator signing material
- sealing explicitly disabled with `--seal=false`
- JSON-RPC protected by reverse proxy or firewall
- TLS handled by proxy
- CORS configured intentionally
- batch limits configured
- block-range limits configured
- debug endpoints not exposed publicly
- request volume monitored
- node height monitored
- error rate monitored

---

## 16. Network ports

Default or common operational ports:

| Interface | Typical port | Recommended exposure |
|---|---:|---|
| libp2p | 1478 | Public or allowlisted |
| JSON-RPC | 8545 | Localhost/private; public only behind proxy |
| gRPC | 9632 | Localhost/private only |
| Prometheus metrics | operator-defined | Localhost/VPN/monitoring network only |

Example firewall policy for a validator:

| Port | Source | Action |
|---:|---|---|
| P2P port | validator peers / network peers | allow |
| JSON-RPC | localhost / management network | allow |
| gRPC | localhost only | allow |
| SSH | admin IPs only | allow |
| Metrics | monitoring network only | allow |
| Everything else | public internet | deny |

Notes:

- `--libp2p 0.0.0.0:1478` is appropriate when the node should accept external peer connections.
- `--jsonrpc 127.0.0.1:8545` is recommended for validator nodes and internal-only RPC.
- Public RPC should normally be exposed through a reverse proxy.
- `--grpc-address 127.0.0.1:9632` should remain local unless a private operator network explicitly requires otherwise.

---

## 17. P2P configuration

Relevant P2P runtime options include:

| Flag | Purpose |
|---|---|
| `--libp2p` | P2P listen address |
| `--nat` | External IP address advertised to peers |
| `--dns` | DNS name advertised to peers |
| `--no-discover` | Disable peer discovery |
| `--max-peers` | Maximum total peers |
| `--max-inbound-peers` | Maximum inbound peers |
| `--max-outbound-peers` | Maximum outbound peers |

Use:

```bash
/opt/xgr/bin/xgrchain server --help
```

to verify exact flag availability for the installed release.

P2P recommendations:

- use stable IPs or DNS for validators and bootnodes
- keep P2P reachable according to the published network configuration
- do not overload validators with excessive inbound peers
- monitor peer count and peer churn
- avoid frequent validator restarts
- ensure cloud firewall and host firewall agree
- ensure NAT configuration matches the advertised address

Symptoms of P2P problems:

- low or zero peer count
- node height stuck behind network height
- repeated disconnects
- consensus round changes
- validator misses expected participation
- bootnode unreachable

---

## 18. Runtime flags

Always confirm the active release flags with:

```bash
/opt/xgr/bin/xgrchain server --help
```

### 18.1 Core flags

| Flag | Purpose |
|---|---|
| `--chain` | Path to the genesis/config file |
| `--data-dir` | Node data directory |
| `--config` | CLI configuration file |
| `--seal` | Enable or disable block sealing. The current server default is `true`; non-validator full/RPC nodes must explicitly use `--seal=false`. |
| `--restore` | Restore from archive data during initialization |
| `--log-level` | Console log level |
| `--log-to` | Write logs to a file |

### 18.2 RPC flags

| Flag | Purpose |
|---|---|
| `--jsonrpc` | JSON-RPC listen address in `host:port` form |
| `--grpc-address` | gRPC listen address in `host:port` form |
| `--access-control-allow-origins` | CORS origins for JSON-RPC |
| `--json-rpc-batch-request-limit` | Maximum JSON-RPC batch size |
| `--json-rpc-block-range-limit` | Maximum block range for range-based RPC queries |
| `--concurrent-requests-debug` | Concurrency limit for debug endpoints |
| `--websocket-read-limit` | Maximum WebSocket read size |

### 18.3 Networking flags

| Flag | Purpose |
|---|---|
| `--libp2p` | P2P listen address in `host:port` form |
| `--nat` | External IP address advertised to peers |
| `--dns` | DNS name advertised to peers |
| `--no-discover` | Disable peer discovery |
| `--max-peers` | Maximum total peer count |
| `--max-inbound-peers` | Maximum inbound peer count |
| `--max-outbound-peers` | Maximum outbound peer count |

### 18.4 Txpool and gas-related flags

| Flag | Purpose |
|---|---|
| `--price-limit` | Minimum gas price or effective price accepted into the transaction pool |
| `--max-slots` | Maximum txpool slots |
| `--max-enqueued` | Maximum queued transactions per account |
| `--block-gas-target` | Target block gas behavior where supported by the release |

Gas and fee semantics are chain-specific. Use the dedicated gas behavior document for fee model details.

### 18.5 Metrics flags

| Flag | Purpose |
|---|---|
| `--prometheus` | Prometheus metrics listen address in `host:port` form |
| `--metrics-interval` | Interval for metrics generation where supported |

### 18.6 Compatibility flags

The binary may still expose compatibility flags that are not part of standard public XGR Chain node operation.

Examples include:

| Flag | Public operator status |
|---|---|
| `--relayer` | Compatibility flag. Do not use unless an official XGR Network operator announcement explicitly requires it. |
| `--num-block-confirmations` | Compatibility flag. Do not use for standard XGR Chain operation unless explicitly required by an official operator instruction. |

Do not treat compatibility flags as recommended production configuration.

---

## 19. Config file usage

The server supports a CLI config file through:

```bash
--config /etc/xgr/node.yaml
```

Supported extensions:

```text
.json
.hcl
.yaml
.yml
```

Config file settings override the corresponding command-line values where supported.

Minimal non-validator full node config example:

```yaml
chain_config: /etc/xgr/genesis.json
data_dir: /var/lib/xgr/node
seal: false
log_level: INFO
log_to: /var/log/xgr/node.log
jsonrpc_addr: 127.0.0.1:8545
grpc_addr: 127.0.0.1:9632

network:
  libp2p_addr: 0.0.0.0:1478
  nat_addr: <PUBLIC_IP>
  no_discover: false
  max_peers: 40

tx_pool:
  price_limit: 0
  max_slots: 4096
  max_account_enqueued: 128

json_rpc_batch_request_limit: 20
json_rpc_block_range_limit: 1000
concurrent_requests_debug: 32
web_socket_read_limit: 8192
metrics_interval: 8s
```

Minimal validator config example:

```yaml
chain_config: /etc/xgr/genesis.json
data_dir: /var/lib/xgr/node
seal: true
log_level: INFO
log_to: /var/log/xgr/validator.log
jsonrpc_addr: 127.0.0.1:8545
grpc_addr: 127.0.0.1:9632

network:
  libp2p_addr: 0.0.0.0:1478
  nat_addr: <PUBLIC_IP>
  no_discover: false
  max_peers: 40

tx_pool:
  price_limit: 0
  max_slots: 4096
  max_account_enqueued: 128

json_rpc_batch_request_limit: 20
json_rpc_block_range_limit: 1000
concurrent_requests_debug: 32
web_socket_read_limit: 8192
metrics_interval: 8s
```

Start with config file:

```bash
/opt/xgr/bin/xgrchain server --config /etc/xgr/node.yaml
```

Configuration rules:

- For full/RPC nodes, set `seal: false`.
- For validator nodes, set `seal: true`.
- Use `host:port` syntax for bind addresses.
- Do not use HTTP URL syntax in bind address fields.
- Keep the published genesis file immutable unless an official update is announced.
- Avoid mixing config-file values and command-line values unless intentionally overriding.

---

## 20. JSON-RPC checks

The following checks assume JSON-RPC is bound locally:

```text
http://127.0.0.1:8545
```

### 20.1 Check client version

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
```

### 20.2 Check chain ID

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
```

The returned chain ID must match the published XGR Chain configuration for the target network.

### 20.3 Check latest block number

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Run repeatedly to verify block height progression.

### 20.4 Check peer count

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

A persistently low peer count indicates P2P, firewall, bootnode, NAT, or network configuration issues.

### 20.5 Check syncing state

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_syncing","params":[]}'
```

Expected values:

| Result | Meaning |
|---|---|
| `false` | Node is not currently syncing |
| object | Node reports sync progress |

A node can return `false` either because it is fully synced or because it has no useful peers. Check block height and peer count together.

---

## 21. Validator health checks

Validator health should be checked at several layers.

### 21.1 Process health

```bash
systemctl status xgr-node
```

or:

```bash
ps aux | grep xgrchain
```

### 21.2 Log health

Check recent logs:

```bash
journalctl -u xgr-node -n 200 --no-pager
```

or, if file logging is used:

```bash
tail -n 200 /var/log/xgr/validator.log
```

Watch for:

- repeated startup failures
- signer/key errors
- repeated peer disconnects
- repeated consensus round changes
- block production stalls
- database errors
- out-of-disk errors
- out-of-memory kills
- RPC overload
- system clock warnings

### 21.3 Chain height health

Compare local height with a trusted reference RPC, explorer, or monitoring source.

Local:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

The validator should not remain behind the network tip under normal conditions.

### 21.4 P2P health

Check peer count:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

Low peer count can prevent a validator from participating reliably.

### 21.5 System health

Check CPU, memory, disk, and file descriptors:

```bash
top
df -h
free -h
ulimit -n
```

Recommended monitoring alerts:

| Signal | Alert condition |
|---|---|
| Process down | Immediate |
| Block height stalled | Immediate for validators |
| Peer count too low | Warning / critical depending on threshold |
| Disk usage > 80% | Warning |
| Disk usage > 90% | Critical |
| Memory pressure | Warning |
| Repeated restarts | Critical |
| High RPC error rate | Warning / critical |
| Consensus round churn | Critical for validators |

---

## 22. Logging

Recommended production log level:

```text
INFO
```

Use `DEBUG` only for short troubleshooting windows. Debug logging can be noisy and may increase disk usage.

File logging example:

```bash
--log-level INFO \
--log-to /var/log/xgr/node.log
```

systemd journal example:

```bash
journalctl -u xgr-node -f
```

Recommended log practices:

- centralize logs from production nodes
- rotate file logs
- alert on repeated errors
- avoid logging secrets
- avoid long-term DEBUG logging
- keep validator logs available for incident review
- correlate logs with block height and peer count

Example logrotate configuration:

```text
/var/log/xgr/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
}
```

---

## 23. Metrics

If the release supports Prometheus metrics, enable them on a private interface:

```bash
--prometheus 127.0.0.1:9090
```

Do not expose metrics publicly without authentication and network restrictions.

Recommended metrics to monitor:

| Area | Signals |
|---|---|
| Chain | block height, block time, sync state |
| Consensus | round changes, proposer activity, sealing errors |
| P2P | peer count, disconnects, inbound/outbound peers |
| RPC | request count, error count, latency, batch usage |
| Txpool | pending transactions, queued transactions |
| Host | CPU, memory, disk, file descriptors, network IO |
| Process | restarts, uptime, exit codes |

For validators, consensus and block progression metrics are critical.

For public RPC nodes, latency, error rate, request volume, and resource saturation are critical.

---

## 24. systemd service

Recommended service name:

```text
xgr-node
```

### 24.1 Full node or RPC node service

For a non-validator full node or RPC node, sealing must be explicitly disabled.

Example:

```ini
[Unit]
Description=XGR Chain Node
After=network-online.target
Wants=network-online.target

[Service]
User=xgr
Group=xgr
Type=simple
ExecStart=/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --log-level INFO
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
WorkingDirectory=/var/lib/xgr
ReadWritePaths=/var/lib/xgr /var/log/xgr
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
```

### 24.2 Validator service

For a validator, sealing should be explicitly enabled.

Example:

```ini
[Unit]
Description=XGR Chain Validator
After=network-online.target
Wants=network-online.target

[Service]
User=xgr
Group=xgr
Type=simple
ExecStart=/opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=true \
  --log-level INFO
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
WorkingDirectory=/var/lib/xgr
ReadWritePaths=/var/lib/xgr /var/log/xgr
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
```

Install:

```bash
sudo tee /etc/systemd/system/xgr-node.service >/dev/null < xgr-node.service
sudo systemctl daemon-reload
sudo systemctl enable xgr-node
sudo systemctl start xgr-node
```

Check status:

```bash
systemctl status xgr-node
journalctl -u xgr-node -f
```

---

## 25. Backups

Backups have different criticality depending on node role.

### 25.1 Validator backup priorities

Back up:

- validator key material
- P2P node identity
- service configuration
- genesis/config file
- firewall configuration
- monitoring configuration
- documented recovery procedure

Validator key material is the highest-value backup item.

Do not rely only on full-disk snapshots if they are not encrypted and access-controlled.

### 25.2 Full node and RPC node backups

For non-validator nodes:

- chain data can usually be rebuilt by resyncing
- service configuration should still be backed up
- P2P identity backup is useful but usually less critical than validator keys

### 25.3 Backup rules

- encrypt backups
- store backups off-host
- restrict access
- test restore procedures
- document recovery steps
- do not store plaintext keys in shared folders
- do not include private keys in support requests
- do not commit secrets to Git

---

## 26. Upgrade procedure

Use the official release notes and operator announcements for production upgrades.

Generic binary upgrade flow:

```bash
cd xgr-node
git fetch --tags
git checkout <NEW_RELEASE_TAG>
go build -o xgrchain .
./xgrchain version
```

Install new binary:

```bash
sudo systemctl stop xgr-node
sudo install -m 0755 ./xgrchain /opt/xgr/bin/xgrchain
sudo systemctl start xgr-node
```

Check:

```bash
systemctl status xgr-node
journalctl -u xgr-node -n 200 --no-pager
```

Then verify:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Upgrade checklist:

- release tag confirmed
- release notes reviewed
- binary built or downloaded from official source
- checksum verified if using release artifacts
- keys backed up
- service file backed up
- genesis/config changes reviewed
- staging node tested
- validator rollout coordinated if needed
- monitoring active during restart
- rollback boundary understood

---

## 27. Network upgrades and hardforks

Some upgrades are simple binary replacements.

Other upgrades may activate protocol changes at specific block heights or timestamps.

For network-defining upgrades:

- use only published XGR Network configuration
- coordinate validator rollout
- avoid mixed validator behavior at activation
- monitor chain height and finality closely
- ensure RPC nodes are upgraded before applications depend on new behavior
- do not locally invent fork activation values

Rollback rule:

- Before activation, rolling back to a previous compatible binary may be possible.
- After activation, rollback may be unsafe if the node has processed blocks under new rules.
- Never downgrade validators after a protocol activation unless official instructions say it is safe.

Use the dedicated network upgrade document for detailed hardfork procedure.

---

## 28. Security guidance

### 28.1 Validator security

Validators should be treated as high-value infrastructure.

Recommended controls:

- dedicated server or isolated VM
- dedicated `xgr` system user
- SSH restricted to admin IPs
- key-based SSH only
- no public password login
- firewall enabled
- no public JSON-RPC
- no public gRPC
- validator keys not reused on other machines
- monitoring and alerting enabled
- OS security patches applied
- backups encrypted and access-controlled

### 28.2 RPC security

Public RPC nodes should not hold validator keys.

Recommended controls:

- reverse proxy with TLS
- request rate limits
- CORS restrictions
- batch request limits
- block range limits
- debug namespace not publicly exposed
- txpool/debug/admin-style methods restricted where applicable
- separate RPC nodes from validators
- resource monitoring
- abuse monitoring
- `--seal=false` explicitly set

### 28.3 Filesystem permissions

Recommended ownership:

```bash
sudo chown -R xgr:xgr /var/lib/xgr
sudo chmod -R go-rwx /var/lib/xgr/node
```

Recommended config permissions:

```bash
sudo chown root:root /etc/xgr/genesis.json
sudo chmod 0644 /etc/xgr/genesis.json
```

Secrets should not be world-readable.

### 28.4 Firewall baseline

Example validator firewall posture:

```text
Allow SSH only from admin IPs
Allow P2P according to network topology
Allow metrics only from monitoring network
Deny public JSON-RPC
Deny public gRPC
Deny all other inbound traffic
```

---

## 29. Troubleshooting

### 29.1 Build fails

Check Go version:

```bash
go version
```

Clean module cache only if needed:

```bash
go clean -modcache
go mod download
go build -o xgrchain .
```

Confirm release tag:

```bash
git status
git describe --tags --always
```

### 29.2 Node starts but does not sync

Check:

```bash
systemctl status xgr-node
journalctl -u xgr-node -n 200 --no-pager
```

Then check RPC:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Check peers:

```bash
curl -s -X POST http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

Likely causes:

- wrong genesis/config
- P2P port blocked
- wrong advertised NAT IP
- bootnodes unreachable
- system clock drift
- incompatible release
- corrupted data directory
- insufficient disk space

### 29.3 Peer count is zero

Check:

- host firewall
- cloud firewall
- `--libp2p` listen address
- `--nat` or `--dns` advertisement
- bootnode configuration
- public IP reachability
- DNS resolution
- time synchronization

### 29.4 JSON-RPC is not reachable

Check listen address:

```bash
ss -lntp | grep 8545
```

Check service logs:

```bash
journalctl -u xgr-node -n 100 --no-pager
```

Common causes:

- JSON-RPC bound to localhost
- reverse proxy misconfigured
- firewall blocking access
- service not running
- port collision
- RPC node overloaded
- `--jsonrpc` was passed as an HTTP URL instead of `host:port`

Correct server flag:

```bash
--jsonrpc 127.0.0.1:8545
```

Correct client URL:

```text
http://127.0.0.1:8545
```

### 29.5 Full node or RPC node unexpectedly tries to seal

Cause:

```text
The current server default enables sealing.
```

Fix:

```bash
--seal=false
```

For config files:

```yaml
seal: false
```

This is mandatory for non-validator full nodes and RPC-only nodes.

### 29.6 Validator is running but not participating

Check:

- `--seal=true` is set
- validator key material is present
- validator key belongs to the expected validator
- node is synced
- node has enough peers
- node has correct genesis/config
- node release matches the expected network version
- logs do not show signer errors
- system clock is synchronized
- validator is part of the active validator set according to the published network state

### 29.7 Disk usage is high

Check:

```bash
df -h
du -sh /var/lib/xgr/node
du -sh /var/log/xgr
```

Actions:

- rotate logs
- increase disk capacity
- move data directory to larger SSD/NVMe storage
- prune only if the release and network operating procedure explicitly support it
- avoid emergency deletion of database files

### 29.8 Transactions are rejected

Check:

- account balance
- nonce
- chain ID
- gas limit
- effective gas price
- txpool limits
- RPC endpoint health
- whether the node is synced
- whether the transaction type is supported by the release

For XGR-specific gas behavior, use the dedicated gas price behavior document.

### 29.9 `data directory not defined`

Cause:

```text
The server requires a non-empty data directory.
```

Fix:

```bash
--data-dir /var/lib/xgr/node
```

or in config:

```yaml
data_dir: /var/lib/xgr/node
```

### 29.10 Invalid bind address

Server bind flags require `host:port`.

Correct:

```bash
--jsonrpc 127.0.0.1:8545
--grpc-address 127.0.0.1:9632
--libp2p 0.0.0.0:1478
```

Wrong for bind flags:

```bash
--jsonrpc http://127.0.0.1:8545
```

Use the HTTP URL only from clients such as `curl`.

---

## 30. Operator checklist

Before starting a production node:

- selected public release tag is confirmed
- binary version is checked
- genesis/config file is from published XGR source
- data directory exists and is unique
- file permissions are restricted
- P2P address is reachable where required
- JSON-RPC binding is intentional
- gRPC binding is not public
- validator nodes use `--seal=true`
- non-validator full/RPC nodes use `--seal=false`
- validator key material is backed up
- public RPC nodes do not contain validator key material
- firewall is configured
- systemd service is enabled
- logs are monitored
- disk usage is monitored
- peer count is monitored
- block height is monitored
- upgrade and rollback procedure is documented

---

## 31. Public documentation boundaries

This public node-operation document intentionally describes only public operator workflows.

It does not document:

- unpublished development branches
- unpublished repository paths
- unpublished implementation details
- local test harnesses
- internal deployment scripts
- engine internals
- deprecated bridge/rootchain operator flows
- old Supernet operation procedures
- old PolyBFT operator flows

If a feature is not part of a public release or official operator announcement, it should not be treated as production operator guidance.

Upcoming or preview functionality must be documented as such in its dedicated document and must not be presented as active in the current public baseline release.

---

## 32. Related documents

| Document | Purpose |
|---|---|
| `XGRCHAIN_Introduction.md` | High-level XGR Chain overview |
| `XGRCHAIN_Chain_Spec.md` | Chain-level protocol specification |
| `XGRCHAIN_Genesis_and_Configuration.md` | Published genesis and network configuration guidance |
| `XGRCHAIN_Consensus_IBFT.md` | IBFT consensus behavior and finality model |
| `XGRCHAIN_Ethereum_JSON_RPC_Reference.md` | Standard Ethereum-compatible JSON-RPC reference |
| `XGRCHAIN_Node_Operator_RPC_Reference.md` | Operator-oriented RPC and node inspection reference |
| `XGRCHAIN_Networking_P2P.md` | P2P networking and peer configuration |
| `XGRCHAIN_Access_Control_and_Permission_Boundaries.md` | RPC, validator, contract, and permission boundaries |
| `XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md` | Release rollout and hardfork coordination |
| `XRC-GAS_Gas_Price_Behavior.md` | XGR gas price and fee behavior |
| `XGRCHAIN_Staking_PoS_Model.md` | Staking model documentation where applicable |
| `XGRCHAIN_Staking_PoS_Endpoint_Reference.md` | Staking endpoint reference where applicable |
