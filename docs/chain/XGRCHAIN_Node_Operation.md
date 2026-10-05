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

- installing the official `xgr-node v3.1.1` release binary,
- verifying the published release artifact,
- optionally building the same release from source,
- installing the canonical mainnet genesis,
- starting full nodes,
- starting RPC nodes,
- configuring systemd,
- understanding role-critical runtime flags,
- understanding optional runtime flags and their defaults,
- exposing HTTP and WebSocket JSON-RPC safely,
- enabling Prometheus telemetry,
- operating the Online State Trie Sweeper,
- choosing a historical-state retention profile,
- monitoring node health,
- recovering from storage problems,
- production RPC security,
- troubleshooting.

This document does **not** define the validator lifecycle, delegated PoS onboarding, staking, delegation, activation/deactivation, unstaking or withdrawal procedures.

Those protocol and staking topics are documented separately in the Chain consensus and PoS documentation.

The examples in this runbook intentionally use only the flags required for the demonstrated deployment role. Optional tuning flags and software defaults are documented separately instead of being repeated in every command.

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

A node using an incompatible network-defining configuration is not participating in the same XGRChain mainnet.

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

Do not document or assume:

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

Do not modify network-defining mainnet fields such as:

```text
chain ID
fork schedule
IBFT configuration
PoS activation
initial allocation
protocol addresses
```

---

## 8. Runtime configuration philosophy

The command examples in this document use only:

1. deployment-path flags,
2. role-critical interface flags,
3. role-critical consensus behavior,
4. explicitly enabled optional features.

Values that already match the software defaults are not repeated merely for completeness.

This avoids accidentally pinning an old default into a long-lived systemd unit after a future software upgrade.

For example, the following `v3.1.1` values are already built-in defaults and do not need to be repeated in a standard RPC command:

```text
JSON-RPC batch request limit: 20
JSON-RPC block range limit:   1000
debug concurrency limit:      32
WebSocket read limit:         8192 bytes
log level:                    INFO
```

---

## 9. Role-critical overrides used in the examples

Some defaults are intentionally overridden for normal public full-node or RPC infrastructure.

| Setting | `v3.1.1` behavior/default | Runbook choice | Reason |
| --- | --- | --- | --- |
| P2P bind | localhost on port `1478` | `0.0.0.0:1478` | accept external XGRChain peers |
| JSON-RPC bind | all interfaces on port `8545` | `127.0.0.1:8545` | do not expose raw node RPC directly |
| gRPC bind | localhost on port `9632` | `127.0.0.1:9632` | keep operator gRPC private |
| sealing | `true` | `false` | non-validator nodes must not seal |

For non-validator infrastructure, make:

```text
--seal=false
```

explicit.

For production RPC infrastructure, make the loopback JSON-RPC bind explicit even though the software has its own default.

---

## 10. Start a normal public full node

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

No explicit `--nat` flag is required when the host's normal advertised interface addresses are already correct for P2P connectivity.

---

## 11. Full-node systemd service

```bash
sudo tee /etc/systemd/system/xgr-node.service >/dev/null <<'EOF_SERVICE'
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
EOF_SERVICE
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

The node logs to standard output by default, so systemd/journald can capture the logs without requiring `--log-to`.

---

## 12. Start an RPC node

The node process itself does not need a different set of consensus flags merely because the infrastructure is used as an RPC service.

Minimal RPC-node example:

```bash
sudo -u xgr /opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false
```

Public service exposure should normally be:

```text
Internet
   ↓
TLS / WSS reverse proxy or RPC gateway
   ↓
rate limiting / abuse protection
   ↓
127.0.0.1:8545
```

Do not expose the raw node JSON-RPC listener directly to the public Internet unless that is an intentional and separately secured design.

Do not place validator private keys on public RPC infrastructure.

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

WebSocket subscriptions are available through the same JSON-RPC listener under:

```text
/ws
```

For public service, terminate TLS at the gateway and expose provider-specific HTTPS/WSS endpoints from there.

The node also supports:

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

## 14. Operationally relevant optional runtime flags

The following table documents commonly relevant optional settings for full-node and RPC operators.

It is not intended to replace `xgrchain server --help`.

### Networking

| Flag | `v3.1.1` default | Use |
| --- | --- | --- |
| `--nat <PUBLIC_IP>` | not set | Override the P2P address advertised to peers when the externally reachable IPv4 address differs from the host addresses |
| `--dns <MULTIADDR>` | not set | Advertise a DNS-based P2P address instead of a normal host address |
| `--max-peers` | `40` | Override total peer capacity |
| `--max-inbound-peers` | `32` | Override inbound peer capacity |
| `--max-outbound-peers` | `8` | Override outbound peer capacity |

`--nat` does not configure NAT or port forwarding.

It only tells libp2p which IPv4 address should be advertised to other peers.

Example:

```bash
--nat 203.0.113.10
```

With P2P port `1478`, the advertised multiaddress becomes conceptually:

```text
/ip4/203.0.113.10/tcp/1478
```

If the node already has the correct public address on its host interfaces and peers can reach it normally, `--nat` is not required.

### JSON-RPC and WebSocket

| Flag | `v3.1.1` default | Use |
| --- | ---: | --- |
| `--json-rpc-batch-request-limit` | `20` | Maximum number of calls accepted in a JSON-RPC batch |
| `--json-rpc-block-range-limit` | `1000` | Maximum block range for requests using `fromBlock` / `toBlock`, such as `eth_getLogs` |
| `--concurrent-requests-debug` | `32` | Maximum concurrent debug endpoint requests |
| `--websocket-read-limit` | `8192` bytes | Maximum WebSocket message size read from a peer |
| `--access-control-allow-origins` | `*` | Override JSON-RPC CORS origins |

The standard examples do not repeat these flags because they already equal the `v3.1.1` defaults.

The batch and block-range limits can be changed by operators according to their public RPC service policy.

The node CLI documents value `0` as disabling the batch-request limit and block-range limit respectively.

### Monitoring

| Flag | `v3.1.1` default | Use |
| --- | --- | --- |
| `--prometheus <ADDR>` | disabled | Enable Prometheus HTTP telemetry listener |
| `--metrics-interval` | `8s` | Override metrics generation interval |

Recommended local-only example:

```bash
--prometheus 127.0.0.1:5001
```

Keep Prometheus private unless there is a deliberate monitoring-network design.

### Logging

| Flag | `v3.1.1` default | Use |
| --- | --- | --- |
| `--log-level` | `INFO` | Override log verbosity |
| `--log-to <PATH>` | stdout | Write node logs to a file instead of standard output |

For systemd deployments, leaving logs on stdout and using journald is a valid production setup.

### State retention

| Flag | `v3.1.1` default | Use |
| --- | --- | --- |
| `--trie-sweeper` | `false` | Enable online historical-state trie garbage collection |
| `--trie-sweeper-retain-blocks` | `10000` | Number of latest canonical state roots retained when sweeper is enabled |
| `--trie-sweeper-interval` | `6h` | Interval between completed sweeper cycles |

For a bounded-history node using the defaults, only:

```text
--trie-sweeper
```

needs to be added.

---

## 15. Prometheus telemetry

Prometheus telemetry is optional.

Example:

```bash
sudo -u xgr /opt/xgr/bin/xgrchain server \
  --chain /etc/xgr/genesis.json \
  --data-dir /var/lib/xgr/node \
  --libp2p 0.0.0.0:1478 \
  --jsonrpc 127.0.0.1:8545 \
  --grpc-address 127.0.0.1:9632 \
  --seal=false \
  --prometheus 127.0.0.1:5001
```

Keep the telemetry listener private unless there is a deliberate monitoring-network design.

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

## 16. Basic node checks

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

A healthy process alone is not sufficient.

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

---

## 17. Production RPC quick reference

| Item | Production baseline |
| --- | --- |
| Node release | `xgr-node v3.1.1` |
| Release commit | `1a4844b311fb856cb8c2303a40fa8aa69b560544` |
| Recommended install | official checksum-verified release binary |
| Chain ID | `1643` / `0x66b` |
| Native asset | XGR |
| Public P2P | `1478/tcp` |
| Local HTTP JSON-RPC | `http://127.0.0.1:8545/` |
| Local WebSocket RPC | `ws://127.0.0.1:8545/ws` |
| Local gRPC | `127.0.0.1:9632` |
| Optional local Prometheus | `127.0.0.1:5001` |
| RPC sealing | explicit `--seal=false` |
| Public RPC exposure | TLS/WSS reverse proxy or RPC gateway |
| Public validator keys on RPC node | never |
| Archive state | Trie Sweeper disabled |
| Bounded historical state | Trie Sweeper enabled |
| Default bounded retention | `10000` blocks |
| Default sweep interval | `6h` |

For a third-party RPC provider, the primary storage-policy decision is:

```text
archive RPC
```

or:

```text
bounded-history RPC
```

depending on the historical-state guarantees the provider intends to offer.

---

## 18. Hardware and capacity planning

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

## 19. Online State Trie Sweeper

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

## 20. Trie Sweeper defaults

Relevant flags:

```text
--trie-sweeper
--trie-sweeper-retain-blocks
--trie-sweeper-interval
```

Defaults:

| Setting | Default |
| --- | ---: |
| Sweeper enabled | `false` |
| Retention when enabled | `10,000` blocks |
| Sweep interval | `6h` |

When the default retention and interval are desired, operators only need:

```text
--trie-sweeper
```

There is no need to repeat:

```text
--trie-sweeper-retain-blocks 10000
--trie-sweeper-interval 6h
```

unless the intent is to pin those values explicitly.

---

## 21. Bounded-history full-node profile

Minimal bounded-history example using the software defaults:

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

At the nominal two-second block target:

```text
10,000 blocks ≈ 5 hours 33 minutes
```

This is only an approximate wall-clock duration.

Retention is measured in blocks.

---

## 22. Custom longer-history RPC profile

For infrastructure requiring more historical state, override only the retention value:

```bash
--trie-sweeper \
--trie-sweeper-retain-blocks 100000
```

The sweep interval remains at its `6h` software default unless deliberately overridden.

At nominal block timing:

```text
100,000 blocks ≈ 55 hours 33 minutes
```

of recent canonical state.

Actual elapsed time varies with real block production.

A larger retention window requires more disk.

---

## 23. Archive-style profile

If the node must support arbitrary historical EVM-state queries:

```text
leave Trie Sweeper disabled
```

No additional archive flag is required.

Do not add:

```text
--trie-sweeper
```

to an archive-style endpoint.

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

An RPC provider should document whether its public endpoint is:

```text
archive-capable
```

or:

```text
bounded-history
```

---

## 24. What the Trie Sweeper deletes

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

## 25. First-sweep behavior

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

## 26. Sweep cycle

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

## 27. Trie GC work directory

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

It is rebuilt when required and is not canonical blockchain state.

---

## 28. Trie Sweeper logging

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

## 29. Trie Sweeper monitoring

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

## 30. Trie Sweeper and validators

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

## 31. Disabling pruning

Stop the node and remove:

```text
--trie-sweeper
```

from its runtime configuration.

This stops future sweep cycles.

It does **not** restore state that has already been removed.

---

## 32. Trie-pruning recovery

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

## 33. Recommended retention profiles

| Role | Suggested retention approach |
| --- | --- |
| General full node | default `10,000` blocks when sweeper is enabled |
| Public RPC with some history | increase retention based on application needs |
| Archive RPC | Trie Sweeper disabled |
| Validator | optional; enable conservatively and monitor I/O |
| Indexer | depends on whether the indexer needs raw historical state or only blocks/logs |

There is no universal retention value for every deployment.

The correct value depends on historical-state requirements.

---

## 34. Bounded-history RPC systemd example

This example intentionally relies on the default:

```text
10,000 retained blocks
6h sweep interval
```

and therefore enables only the sweeper itself.

```bash
sudo tee /etc/systemd/system/xgr-rpc.service >/dev/null <<'EOF_SERVICE'
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
EOF_SERVICE
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

For Prometheus, add for example:

```text
--prometheus 127.0.0.1:5001
```

For custom historical retention, add for example:

```text
--trie-sweeper-retain-blocks 100000
```

---

## 35. Production security baseline

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

## 36. Troubleshooting

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

## 37. Production-readiness checklist

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
- archive versus bounded-history behavior is intentional,
- Trie Sweeper retention is documented if enabled,
- disk capacity and disk latency are monitored,
- logs are monitored,
- service restart behavior is configured,
- no validator signing keys are present on public RPC infrastructure.

---

## 38. Related documentation

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
