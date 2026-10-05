# XGR Chain — Node Operation & RPC Runbook

**Document ID:** XGRCHAIN-NODE-OPERATION  
**Last updated:** 2026-10-05  
**Audience:** Node operators, RPC operators, infrastructure engineers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Operating mode:** Standalone public XGRChain full node / RPC infrastructure

---

## 1. Purpose

This document is the practical operations runbook for standalone XGRChain full nodes and RPC infrastructure.

It covers:

- installing `xgr-node v3.1.1`,
- verifying release artifacts,
- building from source,
- installing the canonical mainnet genesis,
- starting full nodes,
- starting RPC nodes,
- configuring systemd,
- exposing HTTP and WebSocket JSON-RPC safely,
- enabling local Prometheus telemetry,
- operating the Online State Trie Sweeper,
- choosing a historical-state retention profile,
- monitoring node health,
- recovering from storage problems,
- production RPC security,
- troubleshooting.

This document does **not** define the validator lifecycle, delegated PoS onboarding, staking, delegation, activation/deactivation, unstaking or withdrawal procedures.

Those protocol and staking topics are documented separately in the Chain consensus and PoS documentation.

This document is intentionally operational.

---

## 2. Current release

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

The public node can run standalone.

Normal XGRChain operation does not require a private XDaLa or xgrEngine repository.

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

Do not edit the published genesis locally for mainnet operation.

---

## 4. Suggested filesystem layout

```text
/opt/xgr/bin/xgrchain
/etc/xgr/genesis.json

/var/lib/xgr/node

/var/log/xgr
```

Create user and directories:

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

## 5. Install the published `v3.1.1` binary

For Linux AMD64:

```bash
curl -fL \
  https://github.com/xgr-network/xgr-node/releases/download/v3.1.1/xgrchain-v3.1.1-linux-amd64 \
  -o xgrchain
```

Verify:

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

For production installation, prefer the published release artifact or an equivalently reproducible build.

---

## 6. Build `v3.1.1` from source

Prerequisites:

```bash
sudo apt-get update
sudo apt-get install -y \
  git \
  curl \
  ca-certificates \
  build-essential \
  make
```

The release declares:

```text
go 1.23.4
toolchain go1.23.11
```

Clone:

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

For a versioned source build use the repository build target:

```bash
make -f scripts/Makefile build
```

This embeds:

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

---

## 7. Install canonical mainnet genesis

```bash
sudo curl -fsSL \
  https://raw.githubusercontent.com/xgr-network/XGR/main/genesis/mainnet/genesis.json \
  -o /etc/xgr/genesis.json
```

Permissions:

```bash
sudo chown root:root /etc/xgr/genesis.json
sudo chmod 0644 /etc/xgr/genesis.json
```

Do not modify:

```text
chainID
fork schedule
IBFT configuration
PoS activation
initial allocation
protocol addresses
```

on a node intended to join mainnet.

---

## 8. Placeholder conventions

| Placeholder | Meaning |
| --- | --- |
| `<PUBLIC_IP>` | Public IPv4 address |
| `<NODE_DATA_DIR>` | Full/RPC node data directory |

Important distinction:

Server bind:

```text
--jsonrpc 127.0.0.1:8545
```

Client URL:

```text
http://127.0.0.1:8545
```

Do not use:

```text
http://127.0.0.1:8545
```

as a server bind address.

---

## 9. Start a normal full node

A non-validator node must explicitly disable sealing.

```bash
sudo -u xgr /opt/xgr/bin/xgrchain server \
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

Important:

```text
--seal=false
```

should be explicit for non-validator infrastructure.

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
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --log-level INFO \
  --log-to /var/log/xgr/node.log
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
EOF
```

Replace:

```text
<PUBLIC_IP>
```

then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now xgr-node
```

Check:

```bash
systemctl status xgr-node
journalctl -u xgr-node -n 100 --no-pager
```

---

## 11. Start an RPC node

Recommended local node bind:

```bash
sudo -u xgr /opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --prometheus 127.0.0.1:5001 \
  --seal=false \
  --json-rpc-batch-request-limit 20 \
  --json-rpc-block-range-limit 1000 \
  --concurrent-requests-debug 32 \
  --websocket-read-limit 8192 \
  --log-level INFO \
  --log-to /var/log/xgr/rpc.log
```

Public exposure should normally be:

```text
Internet
   ↓
TLS reverse proxy / RPC gateway
   ↓
rate limiting / abuse protection
   ↓
127.0.0.1:8545
```

Do not place validator private keys on public RPC infrastructure.

---

## 12. JSON-RPC HTTP and WebSocket

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

WebSocket subscriptions are therefore available through the same JSON-RPC listener under `/ws`.

For public service, terminate TLS at the gateway and expose provider-specific HTTPS/WSS endpoints from there.

The node supports the CORS runtime option:

```text
--access-control-allow-origins
```

CORS is not a substitute for gateway authentication, rate limiting or abuse protection.

Public RPC operators should enforce their production policy at the reverse proxy / API gateway layer.

---

## 13. Prometheus telemetry

Prometheus telemetry is optional.

Example local-only bind:

```text
--prometheus 127.0.0.1:5001
```

Keep the telemetry listener private unless there is a deliberate monitoring-network design.

The metrics listener should not be exposed publicly merely because the JSON-RPC service is public.

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

## 14. Basic node checks

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

Synced:

```text
false
```

Peers:

```bash
curl -s http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"net_peerCount","params":[]}'
```

A healthy process alone is not sufficient.

Production health checks should confirm:

```text
correct chain ID
+
advancing block height
+
not syncing
+
useful peer connectivity
```

---

## 15. Production RPC quick reference

| Item | Production baseline |
| --- | --- |
| Node release | `xgr-node v3.1.1` |
| Release commit | `1a4844b311fb856cb8c2303a40fa8aa69b560544` |
| Chain ID | `1643` / `0x66b` |
| Native asset | XGR |
| P2P | `1478/tcp` |
| Local HTTP JSON-RPC | `http://127.0.0.1:8545/` |
| Local WebSocket RPC | `ws://127.0.0.1:8545/ws` |
| Local gRPC | `127.0.0.1:9632` |
| Optional local Prometheus | `127.0.0.1:5001` |
| RPC sealing | `--seal=false` |
| Public RPC exposure | TLS reverse proxy / RPC gateway |
| Public validator keys on RPC node | Never |
| Archive state | Trie Sweeper disabled |
| Bounded historical state | Trie Sweeper enabled with explicit retention |

For a third-party RPC provider, the minimum deployment decision is:

```text
archive RPC
```

or:

```text
bounded-history RPC
```

depending on the historical-state guarantees the provider intends to offer.

---

## 16. Hardware and capacity planning

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

# State Growth Control / Trie Pruning

## 17. Online State Trie Sweeper

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

---

## 18. Trie Sweeper flags

```text
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Defaults:

| Setting | Default |
| --- | ---: |
| Sweeper enabled | `false` |
| Retention | `10,000` blocks |
| Interval | `6h` |

When enabled:

```text
retain blocks > 0
interval > 0
```

are required.

---

## 19. Bounded-history full-node profile

A typical bounded-history configuration:

```bash
sudo -u xgr /opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --trie-sweeper \
  --trie-sweeper-retain-blocks 10000 \
  --trie-sweeper-interval 6h
```

At the nominal two-second block target:

```text
10,000 blocks ≈ 5 hours 33 minutes
```

This is only an approximate wall-clock duration.

Retention is measured in blocks.

---

## 20. Longer-history RPC profile

For infrastructure requiring more historical state:

```text
--trie-sweeper-retain-blocks 100000
```

At nominal block timing this corresponds to roughly:

```text
55 hours 33 minutes
```

of recent canonical state.

Actual elapsed time varies with real block production.

A larger retention window requires more disk.

---

## 21. Archive-style profile

If the node must support arbitrary historical EVM-state queries:

```text
leave Trie Sweeper disabled
```

Do not enable pruning on an archive-style endpoint.

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

An RPC provider should document whether its public endpoint is archive-capable or bounded-history.

---

## 22. What the Trie Sweeper deletes

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

Therefore an old block may remain queryable while its historical EVM state is no longer available.

---

## 23. First-sweep behavior

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

This protects state around startup and sweep-generation boundaries.

Operators should not interpret the lack of an immediate sweep after process start as a failure.

---

## 24. Sweep cycle

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

## 25. Trie GC work directory

Working data is stored below:

```text
<data-dir>/trie-gc
```

For example:

```text
/var/lib/xgr/node/trie-gc
```

Marker metadata:

```text
<data-dir>/trie-gc/marks
```

The marker database is garbage-collection working state.

It is rebuilt when required and is not canonical blockchain state.

---

## 26. Trie Sweeper logging

Initialization logs include values such as:

```text
retainBlocks
interval
trackingFromBlock
workDir
```

Sweep selection includes:

```text
fromBlock
toBlock
roots
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

Operators should explicitly monitor:

```text
verifiedHead
verifiedStateRoot
```

after completed sweeps.

---

## 27. Trie Sweeper monitoring

During and after a sweep monitor:

- canonical block progression,
- node synchronization,
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

---

## 28. Trie Sweeper and validators

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

## 29. Disabling pruning

Remove:

```text
--trie-sweeper
```

or configure:

```yaml
trie_sweeper: false
```

This stops future sweep cycles.

It does **not** restore state that has already been removed.

---

## 30. Trie-pruning recovery

If historical state that has already been pruned is required again, disabling the sweeper is not sufficient.

Recovery may require:

- rebuilding the node database,
- resynchronizing the node,
- restoring an appropriate archive-capable backup,
- using another archive-style node as the required data source.

Do not assume deleted trie state will automatically reappear.

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

## 31. Recommended pruning profiles

| Role | Suggested retention approach |
| --- | --- |
| General full node | `10,000` blocks is the software default when enabled |
| Public RPC with some history | Increase retention based on application needs |
| Archive RPC | Sweeper disabled |
| Validator | Optional; enable conservatively and monitor I/O |
| Indexer | Depends on whether indexer needs raw historical state or only blocks/logs |

There is no universal retention value for every deployment.

The correct value depends on historical-state requirements.

---

## 32. Production RPC systemd example with bounded history

Example bounded-history RPC node:

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
  --nat <PUBLIC_IP> \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --prometheus 127.0.0.1:5001 \
  --seal=false \
  --json-rpc-batch-request-limit 20 \
  --json-rpc-block-range-limit 1000 \
  --concurrent-requests-debug 32 \
  --websocket-read-limit 8192 \
  --trie-sweeper \
  --trie-sweeper-retain-blocks 10000 \
  --trie-sweeper-interval 6h \
  --log-level INFO \
  --log-to /var/log/xgr/rpc.log
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
EOF
```

Replace:

```text
<PUBLIC_IP>
```

then:

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
--trie-sweeper-retain-blocks 10000
--trie-sweeper-interval 6h
```

---

## 33. Production security baseline

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
- keep JSON-RPC bound locally or to a controlled private network,
- keep gRPC private,
- keep Prometheus private,
- do not place validator keys on public RPC nodes,
- restrict debug/tracing according to provider policy,
- enforce request and WebSocket limits at the gateway,
- monitor peer count and canonical block progression,
- monitor disk health and free space,
- restrict SSH to administrative sources,
- run the node under a dedicated unprivileged service account.

A public RPC endpoint and a consensus validator are different infrastructure roles.

---

## 34. Troubleshooting

### Node does not start

Check:

```bash
journalctl -u xgr-node -n 200 --no-pager
```

or, for the RPC service:

```bash
journalctl -u xgr-rpc -n 200 --no-pager
```

Common causes:

- wrong `--chain` path,
- missing or inaccessible `--data-dir`,
- filesystem permissions,
- port already in use,
- invalid `--nat` address,
- modified or incompatible genesis,
- invalid runtime flag value.

### Node has no useful peers

Check:

```text
P2P port 1478
public IP / NAT advertisement
cloud firewall
host firewall
bootnode reachability
net_peerCount
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
- local node logs,
- CPU and disk pressure,
- chain configuration,
- comparison with another trusted XGRChain node.

A responsive HTTP server does not prove that the node is following the current canonical head.

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

Verify:

```text
ws://127.0.0.1:8545/ws
```

locally.

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

## 35. Production-readiness checklist

Before considering a standalone XGRChain RPC node production-ready:

- `xgr-node v3.1.1` is installed,
- release artifact or build provenance is verified,
- canonical mainnet genesis is used unchanged,
- chain ID returns `0x66b`,
- block height advances,
- `eth_syncing` reports the expected state,
- peer connectivity is healthy,
- `--seal=false` is explicit,
- HTTP JSON-RPC is reachable locally,
- WebSocket RPC is reachable at `/ws`,
- public RPC is fronted by TLS and gateway controls,
- gRPC is not publicly exposed,
- Prometheus is private if enabled,
- archive versus bounded-history behavior is intentional,
- Trie Sweeper retention is documented if enabled,
- disk capacity and disk latency are monitored,
- logs are monitored,
- service restart behavior is configured,
- no validator signing keys are present on public RPC infrastructure.

---

## 36. Related documentation

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
