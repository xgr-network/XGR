# XGR Chain — Node Operation & Validator Runbook

**Document ID:** XGRCHAIN-NODE-OPERATION  
**Last updated:** 2026-10-03  
**Audience:** Node operators, validator operators, RPC operators, infrastructure engineers  
**Release baseline:** `xgr-node v3.1.1`  
**Release commit:** `1a4844b311fb856cb8c2303a40fa8aa69b560544`  
**Mainnet genesis source:** `xgr-network/XGR`, branch `main`, `genesis/mainnet/genesis.json`  
**Node implementation:** `xgr-network/xgr-node`  
**Operating mode:** Standalone public XGRChain node

---

## 1. Purpose

This document is the practical operations runbook for XGRChain.

It covers:

- installing `xgr-node v3.1.1`,
- verifying release artifacts,
- building from source,
- installing the canonical mainnet genesis,
- starting full nodes,
- starting RPC nodes,
- configuring systemd,
- operating the Online State Trie Sweeper,
- choosing a historical-state retention profile,
- monitoring and recovering from storage problems,
- preparing validator infrastructure,
- generating validator keys,
- joining delegated PoS,
- configuring delegation,
- activating/deactivating validators,
- staking,
- unstaking,
- withdrawing,
- optional interchain-validator participation,
- health checks,
- security,
- troubleshooting.

This document is intentionally operational.

Protocol details belong in the specialized Chain documentation.

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
/var/lib/xgr/validator

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
sudo install -d -m 0700 -o xgr -g xgr /var/lib/xgr/validator
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
| `<VALIDATOR_ADDRESS>` | Validator ECDSA address |
| `<NODE_DATA_DIR>` | Normal/full node data directory |
| `<VALIDATOR_DATA_DIR>` | Validator data directory |
| `<STAKE_XGR>` | Amount in whole XGR units |

Important distinction:

Server bind:

```text
--jsonrpc 127.0.0.1:8545
```

Client URL:

```text
--jsonrpc http://127.0.0.1:8545
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
TLS reverse proxy / gateway
   ↓
rate limiting
   ↓
127.0.0.1:8545
```

Do not place validator private keys on public RPC infrastructure.

---

## 12. Basic node checks

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

---

# State Growth Control / Trie Pruning

## 13. Online State Trie Sweeper

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

## 14. Trie Sweeper flags

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

## 15. Bounded-history full-node profile

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

## 16. Longer-history RPC profile

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

## 17. Archive-style profile

If the node must support arbitrary historical EVM-state queries:

```text
leave trie sweeper disabled
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

---

## 18. What the Trie Sweeper deletes

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

## 19. First-sweep behavior

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

## 20. Sweep cycle

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

## 21. Trie GC work directory

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

## 22. Trie Sweeper logging

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

## 23. Trie Sweeper monitoring

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

## 24. Trie Sweeper and validators

The Trie Sweeper is technically consensus-independent and can operate on validator nodes.

However, validators are latency-sensitive infrastructure.

If enabling the sweeper on a validator:

- monitor disk I/O carefully,
- ensure the storage subsystem has sufficient headroom,
- verify block progression,
- monitor round participation,
- monitor sweep duration.

An RPC/full node is generally a safer place to evaluate pruning behavior before applying an aggressive retention profile to consensus infrastructure.

---

## 25. Disabling pruning

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

## 26. Trie-pruning recovery

If historical state that has already been pruned is required again, disabling the sweeper is not sufficient.

Recovery may require:

- rebuilding the node database,
- resynchronizing the node,
- restoring an appropriate archive-capable backup,
- using another archive-style node as the required data source.

Do not assume deleted trie state will automatically reappear.

If a sweep reports an integrity problem:

1. preserve logs,
2. stop using the node as an authoritative RPC/validator source,
3. verify disk and database health,
4. compare canonical head with trusted nodes,
5. rebuild or resynchronize if state integrity cannot be established.

The complete storage design is documented in:

```text
XGRCHAIN_State_Storage_and_Retention.md
```

---

## 27. Recommended pruning profiles

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

## 28. systemd example with Trie Sweeper

Example bounded-history full node:

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
  --trie-sweeper \
 
