# XGR Chain — Node Operation & RPC Runbook

**Document ID:** XGRCHAIN-NODE-OPERATION  
**Last updated:** 2026-10-05  
**Audience:** Node operators, RPC operators, infrastructure engineers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`

---

## 1. Purpose

This document is the practical operations runbook for standalone XGRChain full nodes and production RPC infrastructure.

It covers:

- installing the official `xgr-node v3.1.1` release binary,
- verifying the published artifact,
- optionally building the same release from source,
- installing the canonical mainnet genesis,
- starting public full nodes,
- starting production RPC nodes,
- configuring systemd,
- understanding required and optional runtime flags,
- exposing HTTP and WebSocket JSON-RPC safely,
- operating the Online State Trie Sweeper,
- selecting bounded-history or archive-state operation,
- monitoring node health,
- recovering from storage problems,
- production security and troubleshooting.

This document does **not** define the validator lifecycle, delegated PoS onboarding, staking, delegation, activation/deactivation, unstaking or withdrawal.

Those topics are documented separately in the Chain consensus and PoS documentation.

The examples in this runbook intentionally use only the flags required for the demonstrated role. Optional tuning flags and software defaults are documented separately instead of being repeated in every command.

---

## 2. Current production release

Current production baseline:

```text
xgr-node v3.1.1
```

Release commit:

```text
1a4844b311fb856cb8c2303a40fa8aa69b560544
```

Published Linux AMD64 artifact:

```text
xgrchain-v3.1.1-linux-amd64
```

Published artifact SHA-256:

```text
429d18db37e9cdb6eb82b33583880c407701fcf070f1d8f6398ca8c4c7a0c88d
```

The release also publishes:

```text
sha256sums.txt
version.txt
```

For production deployments, the published and checksum-verified `v3.1.1` release binary is the recommended installation method.

Building from source is provided for:

- independent verification,
- auditing,
- development,
- environments that explicitly require self-built artifacts.

Normal standalone XGRChain operation does not require a private XDaLa or xgrEngine repository.

---

## 3. Mainnet identity

Canonical mainnet configuration:

```text
Repository: xgr-network/XGR
Branch:     main
Path:       genesis/mainnet/genesis.json
```

Mainnet parameters:

| Field | Value |
| --- | --- |
| Network | `xgrchain` |
| Chain ID | `1643` |
| Chain ID hex | `0x66b` |
| Native asset | XGR |
| Decimals | `18` |
| P2P port | `1478` |
| IBFT block target | approximately 2 seconds |
| PoS active from | `5446500` |
| Micro epoch | `25` blocks |
| Macro factor | `40` |
| Macro epoch | `1000` blocks |
| Minimum validators | `4` |
| Maximum validators | `25` |

Do not edit the published genesis for mainnet operation.

A node using incompatible network-defining configuration is not participating in the same XGRChain mainnet.

---

## 4. Suggested filesystem layout

```text
/opt/xgr/bin/xgrchain
/etc/xgr/genesis.json

/var/lib/xgr/node

/var/log/xgr
```

Create a dedicated service user and directories:

```bash
sudo useradd \
  --system \
  --home /var/lib/xgr \
  --shell /usr/sbin/nologin \
  xgr || true

sudo install -d -m 0755 /opt/xgr/bin
sudo install -d -m 0755 /etc/xgr

sudo install -d -m 0750 -o xgr -g xgr /var/lib/xgr
sudo install -d -m 0700 -o xgr -g xgr /var/lib/xgr/node
sudo install -d -m 0750 -o xgr -g xgr /var/log/xgr
```

---

## 5. Recommended installation: official `v3.1.1` binary

For Linux AMD64:

```bash
curl -fL \
  https://github.com/xgr-network/xgr-node/releases/download/v3.1.1/xgrchain-v3.1.1-linux-amd64 \
  -o xgrchain
```

Verify the artifact:

```bash
echo \
"429d18db37e9cdb6eb82b33583880c407701fcf070f1d8f6398ca8c4c7a0c88d  xgrchain" \
| sha256sum -c -
```

Expected:

```text
xgrchain: OK
```

Install:

```bash
chmod +x xgrchain
sudo install -m 0755 xgrchain /opt/xgr/bin/xgrchain
```

Check:

```bash
/opt/xgr/bin/xgrchain version
```

For normal production operation, prefer this published release artifact over a locally compiled binary.

---

## 6. Alternative installation: build `v3.1.1` from source

The source-build path is optional.

Use it when independent compilation, auditing or an internally controlled build pipeline is required.

Required tooling:

```text
Git
Make
Go compatible with the release toolchain
```

The release declares:

```text
go 1.23.4
toolchain go1.23.11
```

Clone and select the release:

```bash
git clone https://github.com/xgr-network/xgr-node.git
cd xgr-node

git fetch --all --tags
git checkout v3.1.1
```

Verify:

```bash
git describe --tags --exact-match
git rev-parse HEAD
```

Expected:

```text
v3.1.1
```

and:

```text
1a4844b311fb856cb8c2303a40fa8aa69b560544
```

Build using the versioned repository target:

```bash
make -f scripts/Makefile build
```

The build embeds:

- version,
- commit,
- branch,
- build time.

The resulting binary is:

```text
./xgrchain
```

Check:

```bash
./xgrchain version
```

Install:

```bash
sudo install -m 0755 ./xgrchain /opt/xgr/bin/xgrchain
```

Do not assume:

```text
make build
```

as the repository build command unless a root-level Makefile defining that target is added in a future release.

---

## 7. Install the canonical mainnet genesis

Canonical source:

```text
https://github.com/xgr-network/XGR/blob/main/genesis/mainnet/genesis.json
```

Install directly from the canonical repository:

```bash
sudo curl -fsSL \
  https://raw.githubusercontent.com/xgr-network/XGR/main/genesis/mainnet/genesis.json \
  -o /etc/xgr/genesis.json
```

Set permissions:

```bash
sudo chown root:root /etc/xgr/genesis.json
sudo chmod 0644 /etc/xgr/genesis.json
```

Do not modify network-defining fields such as:

```text
chain ID
fork schedule
IBFT configuration
PoS activation
initial allocation
protocol addresses
```

---

## 8. Runtime configuration model

The examples in this document deliberately separate:

```text
role-critical settings
```

from:

```text
optional tuning
```

Values that already match the software defaults are not repeated merely for completeness.

For `v3.1.1`, the following defaults therefore do not need to appear in a normal RPC start command:

| Setting | Default |
| --- | ---: |
| JSON-RPC batch request limit | `20` |
| JSON-RPC block range limit | `1000` |
| Concurrent debug requests | `32` |
| WebSocket read limit | `8192` bytes |
| Log level | `INFO` |

Several role-critical settings are intentionally explicit:

| Setting | Software behavior/default | Runbook choice | Reason |
| --- | --- | --- | --- |
| P2P bind | localhost on `1478` | `0.0.0.0:1478` | accept external XGRChain peers |
| JSON-RPC bind | all interfaces on `8545` | `127.0.0.1:8545` | keep raw node RPC private |
| gRPC bind | localhost on `9632` | `127.0.0.1:9632` | keep operator gRPC private |
| sealing | `true` | `false` | non-validator nodes must not seal |

For non-validator infrastructure, always make:

```text
--seal=false
```

explicit.

---

## 9. Start a normal public full node

Minimal production example:

```bash
sudo -u xgr /opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false
```

This starts a normal non-validator XGRChain node with:

- public P2P,
- local JSON-RPC,
- local gRPC,
- sealing disabled.

No explicit `--nat` flag is required when the host's normal advertised addresses are already correct for P2P connectivity.

---

## 10. Full-node systemd service

```bash
sudo tee /etc/systemd/system/xgr-node.service >/dev/null <<'EOF'
[Unit]
Description=XGRChain Full Node
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
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
WorkingDirectory=/var/lib/xgr
ReadWritePaths=/var/lib/xgr
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
```

Enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now xgr-node
```

Check:

```bash
systemctl status xgr-node
journalctl -u xgr-node -n 100 --no-pager
```

The node logs to standard output by default, so systemd/journald can capture logs without requiring `--log-to`.

---

## 11. Recommended production RPC node

For a normal public RPC service, XGR.Network recommends enabling the Online State Trie Sweeper unless the endpoint is intentionally operated as an archive RPC.

Minimal recommended RPC-node command:

```bash
sudo -u xgr /opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --trie-sweeper
```

With only `--trie-sweeper` specified, `v3.1.1` uses its built-in retention defaults:

```text
10,000 retained canonical state roots
6h sweep interval
```

The `10,000`-block value is a software default, not a universal recommendation for every public RPC provider.

Operators should choose a larger retention window when their RPC service promises deeper historical-state access.

For archive-state service, leave the Trie Sweeper disabled.

Public RPC exposure should normally be:

```text
Internet
   ↓
TLS / WSS reverse proxy or RPC gateway
   ↓
rate limiting / abuse protection
   ↓
127.0.0.1:8545
```

Do not place validator private keys on public RPC infrastructure.

---

## 12. Recommended RPC systemd service

Example bounded-history RPC node using the built-in Trie Sweeper retention defaults:

```bash
sudo tee /etc/systemd/system/xgr-rpc.service >/dev/null <<'EOF'
[Unit]
Description=XGRChain RPC Node
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
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --trie-sweeper
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
WorkingDirectory=/var/lib/xgr
ReadWritePaths=/var/lib/xgr
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
```

Enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now xgr-rpc
```

Check:

```bash
systemctl status xgr-rpc
journalctl -u xgr-rpc -n 100 --no-pager
```

For an archive RPC service, remove:

```text
--trie-sweeper
```

For custom historical-state retention, add for example:

```text
--trie-sweeper-retain-blocks 100000
```

---

## 13. JSON-RPC HTTP and WebSocket

The JSON-RPC listener serves both HTTP JSON-RPC and WebSocket RPC.

With:

```text
--jsonrpc 127.0.0.1:8545
```

the local HTTP endpoint is:

```text
http://127.0.0.1:8545/
```

and the local WebSocket endpoint is:

```text
ws://127.0.0.1:8545/ws
```

For public service, terminate TLS at the gateway and expose provider-specific HTTPS/WSS endpoints from there.

The node supports:

```text
--access-control-allow-origins
```

for CORS behavior.

CORS is not a substitute for:

- gateway authentication,
- rate limiting,
- request filtering,
- abuse protection,
- network-level access control.

---

## 14. Optional networking flags

### `--nat <PUBLIC_IP>`

Default:

```text
not set
```

Use `--nat` only when the externally reachable IPv4 address differs from the addresses the host would normally advertise to libp2p peers.

Example:

```bash
--nat 203.0.113.10
```

With P2P port `1478`, the advertised address becomes conceptually:

```text
/ip4/203.0.113.10/tcp/1478
```

`--nat` does **not** configure NAT or port forwarding.

It only changes the P2P address advertised to peers.

### `--dns <MULTIADDR>`

Default:

```text
not set
```

Use this when a DNS-based P2P advertise address is preferred.

### Peer limits

Built-in defaults:

| Flag | Default |
| --- | ---: |
| `--max-peers` | `40` |
| `--max-inbound-peers` | `32` |
| `--max-outbound-peers` | `8` |

Override these only when the operator intentionally wants a different peer-capacity policy.

---

## 15. Optional RPC and WebSocket tuning

Built-in `v3.1.1` defaults:

| Flag | Default | Meaning |
| --- | ---: | --- |
| `--json-rpc-batch-request-limit` | `20` | maximum number of calls in a JSON-RPC batch |
| `--json-rpc-block-range-limit` | `1000` | maximum block range for `fromBlock` / `toBlock` requests such as `eth_getLogs` |
| `--concurrent-requests-debug` | `32` | maximum concurrent debug endpoint requests |
| `--websocket-read-limit` | `8192` bytes | maximum WebSocket message size read from a peer |
| `--access-control-allow-origins` | `*` | CORS origin policy |

The normal examples omit these flags because their values already equal the software defaults.

The node CLI documents value `0` as disabling the JSON-RPC batch-request limit and block-range limit respectively.

Operators should tune these values according to their public RPC service policy and enforce additional controls at the gateway layer.

---

## 16. Optional Prometheus telemetry

Prometheus telemetry is disabled unless explicitly configured.

Recommended local-only example:

```text
--prometheus 127.0.0.1:5001
```

The metrics generation interval defaults to:

```text
8s
```

and can be overridden with:

```text
--metrics-interval
```

Keep Prometheus private unless there is a deliberate monitoring-network design.

Useful infrastructure monitoring should include at least:

- process availability,
- canonical block progression,
- peer count,
- synchronization state,
- request volume,
- JSON-RPC errors,
- CPU,
- memory,
- disk latency,
- disk throughput,
- free disk space.

---

## 17. Logging

Built-in default log level:

```text
INFO
```

The node writes logs to standard output unless:

```text
--log-to <PATH>
```

is specified.

For systemd deployments, using stdout with journald is a valid production setup.

Example:

```bash
journalctl -u xgr-rpc -f
```

Use `--log-to` only when a separate log file is part of the operator's logging design.

---

## 18. Basic node checks

Client version:

```bash
curl -s http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
```

Chain ID:

```bash
curl -s http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
```

Expected:

```text
0x66b
```

Block height:

```bash
curl -s http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
```

Sync:

```bash
curl -s http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_syncing","params":[]}'
```

A fully synchronized node normally reports:

```text
false
```

Peers:

```bash
curl -s http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

Production health checks should confirm:

```text
correct chain ID
+
advancing block height
+
expected sync state
+
useful peer connectivity
```

A responsive HTTP server alone does not prove that the node is following the current canonical head.

---

## 19. Hardware and capacity planning

XGR.Network does not publish a fixed CPU, RAM or disk minimum for every production workload.

Capacity depends on:

- archive versus bounded-history operation,
- RPC traffic,
- batch-request volume,
- historical-state usage,
- tracing/debug workload,
- peer topology,
- disk performance,
- expected growth.

Operators should size infrastructure from observed production metrics rather than treating an arbitrary static machine size as a protocol requirement.

For production RPC infrastructure, monitor:

- CPU saturation,
- memory pressure,
- disk latency,
- disk throughput,
- LevelDB behavior,
- free disk capacity,
- synchronization lag,
- request latency,
- request error rate.

Fast local SSD/NVMe-class storage is operationally preferable for latency-sensitive high-volume infrastructure, but no universal hardware minimum is defined by this document.

---

# State Retention / Trie Sweeper

## 20. Recommended state-retention policy

For normal production RPC nodes:

```text
Trie Sweeper enabled
```

is recommended unless the endpoint is intentionally operated as an archive RPC.

For archive RPC nodes:

```text
Trie Sweeper disabled
```

is required in order to retain unrestricted historical EVM state.

The correct bounded-history retention value depends on the service level promised by the RPC operator.

The built-in `10,000`-block retention is a software default, not a universal production recommendation.

---

## 21. Online State Trie Sweeper

`xgr-node` includes an online state-trie garbage collector called the:

```text
Online State Trie Sweeper
```

It was introduced in `v2.1.0` and remains available in `v3.1.1`.

The feature reclaims obsolete historical EVM-state trie and contract-code data while the node remains online.

It is:

```text
local storage policy
```

not:

```text
consensus pruning
```

It does not change:

- canonical state roots,
- blocks,
- transaction execution,
- consensus,
- validator selection,
- staking,
- receipts,
- logs,
- genesis.

Relevant flags:

```text
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Built-in defaults:

| Setting | Default |
| --- | ---: |
| Sweeper enabled | `false` |
| Retention when enabled | `10,000` blocks |
| Sweep interval | `6h` |

If the default retention and interval are desired, only:

```text
--trie-sweeper
```

needs to be specified.

---

## 22. Retention profiles

### Default bounded-history profile

```text
--trie-sweeper
```

uses:

```text
10,000 retained canonical state roots
6h sweep interval
```

At the nominal two-second block target:

```text
10,000 blocks ≈ 5 hours 33 minutes
```

This is only an approximate wall-clock duration.

Retention is measured in blocks.

### Longer-history profile

Example:

```text
--trie-sweeper
--trie-sweeper-retain-blocks 100000
```

At nominal block timing:

```text
100,000 blocks ≈ 55 hours 33 minutes
```

of recent canonical state.

Actual elapsed time varies with real block production.

A larger retention window requires more disk.

### Archive profile

Do not enable:

```text
--trie-sweeper
```

An archive-style node may be required for historical:

```text
eth_getBalance
eth_getTransactionCount
eth_getCode
eth_getStorageAt
eth_call
```

against old block heights.

Block history and state history are different.

An old block can remain queryable even when the historical EVM state associated with that height has already been removed.

---

## 23. What the Trie Sweeper deletes

The sweeper identifies recent canonical state roots and marks state reachable from them.

Potentially reclaimable data includes:

- obsolete trie nodes,
- historical contract-code entries no longer reachable from retained state.

It does **not** delete normal canonical:

- block headers,
- block bodies,
- transactions,
- receipts,
- logs.

---

## 24. First-sweep behavior and sweep cycle

The first sweep intentionally does not begin immediately at process startup.

Sequence:

```text
node starts
    ↓
trie write tracking enabled
    ↓
current canonical head recorded
    ↓
wait for at least one canonical head advance
    ↓
first sweep starts
```

A sweep conceptually performs:

```text
select retained canonical roots
        ↓
mark reachable trie/code data
        ↓
protect concurrent write generations
        ↓
scan database
        ↓
recheck candidates
        ↓
delete unreachable data
        ↓
compact affected LevelDB ranges
        ↓
capture fresh canonical head
        ↓
verify current state root
```

The final state-root verification is an important integrity check.

---

## 25. Trie Sweeper work directory and logging

Working data is stored below:

```text
<data-dir>/trie-gc
```

For the standard layout:

```text
/var/lib/xgr/node/trie-gc
```

Marker metadata:

```text
<data-dir>/trie-gc/marks
```

The marker database is garbage-collection working state.

It is not canonical blockchain state.

Initialization logs include values such as:

```text
retainBlocks
interval
trackingFromBlock
workDir
```

Completed sweep statistics include:

```text
generation
roots
marked
scanned
deleted
retained
skipped
duration
verifiedHead
verifiedStateRoot
```

Operators should monitor:

```text
verifiedHead
verifiedStateRoot
```

after completed sweeps.

---

## 26. Trie Sweeper monitoring and recovery

During and after a sweep monitor:

- canonical block progression,
- synchronization,
- peer count,
- CPU,
- memory,
- disk latency,
- disk throughput,
- free disk space,
- LevelDB compaction activity,
- sweep duration,
- sweep errors,
- `verifiedHead`,
- `verifiedStateRoot`.

A sweep may take significant time on a large database.

This is not automatically abnormal.

If historical state that has already been pruned is required again, disabling the sweeper is not sufficient.

Recovery may require:

- rebuilding the node database,
- resynchronizing the node,
- restoring an appropriate archive-capable backup,
- using another archive-style node as the required data source.

If a sweep reports an integrity problem:

1. preserve logs,
2. stop using the node as an authoritative RPC source,
3. verify disk and database health,
4. compare canonical head with trusted nodes,
5. rebuild or resynchronize if state integrity cannot be established.

The complete storage design is documented in:

```text
XGRCHAIN_State_Storage_and_Retention.md
```

---

## 27. Trie Sweeper and validators

The Trie Sweeper is technically consensus-independent and can operate on validator nodes.

However, validators are latency-sensitive infrastructure.

If enabling the sweeper on a validator:

- monitor disk I/O carefully,
- ensure the storage subsystem has sufficient headroom,
- verify block progression,
- monitor round participation,
- monitor sweep duration.

An RPC/full node is generally a safer place to evaluate pruning behavior before applying an aggressive retention profile to consensus infrastructure.

Detailed validator operation is outside the scope of this runbook.

---

## 28. Production security baseline

Public RPC infrastructure should normally use the following separation:

```text
public Internet
      ↓
TLS / WSS termination
      ↓
RPC gateway / reverse proxy
      ↓
rate limiting / abuse controls
      ↓
127.0.0.1:8545
```

Recommended boundaries:

- expose P2P only where required for peer connectivity,
- keep JSON-RPC bound to loopback or a controlled private network,
- keep gRPC private,
- keep Prometheus private,
- do not place validator keys on public RPC nodes,
- restrict debug/tracing according to provider policy,
- enforce request and WebSocket limits at the gateway as needed,
- monitor peer count and canonical block progression,
- monitor disk health and free space,
- restrict SSH to administrative sources,
- run the node under a dedicated unprivileged service account.

A public RPC endpoint and a consensus validator are different infrastructure roles.

---

## 29. Troubleshooting

### Node does not start

Check:

```bash
journalctl -u xgr-node -n 200 --no-pager
```

or:

```bash
journalctl -u xgr-rpc -n 200 --no-pager
```

Common causes:

- wrong `--chain` path,
- missing or inaccessible `--data-dir`,
- filesystem permissions,
- port already in use,
- invalid optional `--nat` address,
- modified or incompatible genesis,
- invalid runtime flag value.

### Node has no useful peers

Check:

```text
P2P port 1478
host firewall
cloud firewall
public routing
bootnode reachability
net_peerCount
```

If the host is behind NAT or its automatically advertised address is not externally reachable, consider:

```text
--nat <PUBLIC_IP>
```

The dedicated networking document contains the detailed P2P troubleshooting model:

```text
XGRCHAIN_Networking_P2P.md
```

### RPC responds but block height is stale

Check:

- `eth_blockNumber`,
- `eth_syncing`,
- `net_peerCount`,
- node logs,
- CPU and disk pressure,
- chain configuration,
- comparison with another trusted XGRChain node.

### Historical state query fails

Determine whether the endpoint is:

```text
archive
```

or:

```text
bounded-history
```

If the required historical state was already removed by the Trie Sweeper, disabling pruning does not restore it.

Rebuild, resynchronize or use an archive-capable source.

### WebSocket connection fails

Verify locally:

```text
ws://127.0.0.1:8545/ws
```

For public WSS access, also verify:

- reverse-proxy WebSocket upgrade handling,
- TLS configuration,
- gateway timeout policy,
- provider-side connection limits.

### Prometheus is unavailable

Verify that the node was started with an explicit telemetry bind such as:

```text
--prometheus 127.0.0.1:5001
```

and that the monitoring process can reach that private listener.

---

## 30. Production-readiness checklist

Before considering a standalone XGRChain RPC node production-ready:

- `xgr-node v3.1.1` is installed,
- the official release artifact or equivalent build provenance is verified,
- canonical mainnet genesis is used unchanged,
- chain ID returns `0x66b`,
- block height advances,
- `eth_syncing` reports the expected state,
- peer connectivity is healthy,
- `--seal=false` is explicit,
- HTTP JSON-RPC is intentionally bound,
- WebSocket RPC is reachable at `/ws`,
- public RPC is fronted by TLS/WSS and gateway controls,
- gRPC is not publicly exposed,
- Prometheus is private if enabled,
- bounded-history versus archive behavior is intentional,
- Trie Sweeper retention is documented when enabled,
- disk capacity and disk latency are monitored,
- logs are monitored,
- service restart behavior is configured,
- no validator signing keys are present on public RPC infrastructure.

---

## 31. Related documentation

Use the specialized Chain documents for additional detail:

```text
XGRCHAIN_Networking_P2P.md
XGRCHAIN_Ethereum_JSON_RPC_Reference.md
XGRCHAIN_Node_Operator_RPC_Reference.md
XGRCHAIN_State_Storage_and_Retention.md
XGRCHAIN_Access_Control_and_Permission_Boundaries.md
XGRCHAIN_Network_Upgrade_and_Hardfork_Process.md
XGRCHAIN_Consensus_IBFT.md
XGRCHAIN_Staking_PoS_Model.md
XGRCHAIN_Staking_PoS_Endpoint_Reference.md
```

For a third-party RPC operator, the primary operational path is:

```text
Node Operation & RPC Runbook
        ↓
Networking & P2P
        ↓
Ethereum JSON-RPC Reference
        ↓
Node Operator RPC Reference
        ↓
State Storage & Retention
        ↓
Access Control
```

This runbook is sufficient to deploy and operate a standalone XGRChain `v3.1.1` full/RPC node without validator participation.
