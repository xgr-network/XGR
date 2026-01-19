# API Price Feed — 3-Source Quorum (XDaLa Example)

This example demonstrates a **robust, auditable on-chain data ingestion loop** with XDaLa using **3 independent APIs** and a **2-of-3 quorum** mechanism.

Compared to a single-source feed, this pattern reduces outliers, API glitches, and transient pricing anomalies — while keeping every decision **traceable**.

---

## What it does

Each iteration (“step”) performs:

1. **Fetch** the same BTC/USD spot price from 3 sources:
   - Coinbase Spot API
   - Bitstamp Ticker API
   - CoinGecko Simple Price API

2. **Quorum check (2-of-3)**
   - Any two sources must be within a configurable tolerance `QuorumTolPct`
   - The “winning pair” is recorded as `QuorumPair`

3. **Consensus price**
   - `ConsensusPrice` is the average of the winning pair

4. **Delta guard (optional safety)**
   - Rejects consensus updates that deviate too much from the last accepted value `PrevPrice`
   - Controlled by `MaxDeltaPct`

5. **Persist + loop**
   - Writes all source prices + consensus into the payload
   - Self-spawns continuously (on valid and on invalid)

---

## Files

examples/ApiPriceFeedQuorum/
XRC137json/
ApiPriceFeedQuorumStep_3Sources.json
XRC729json/
ApiPriceFeedQuorumLoop.json


---

## Payload fields (high level)

**Configuration**
- `Base` / `Quote` (string) — shown as pair label (default: BTC/USD)
- `QuorumTolPct` (double) — quorum tolerance (default: `0.01` = 1%)
- `MaxDeltaPct` (double) — max allowed change vs last accepted value (default: `0.2` = 20%)
- `waitSec` — step frequency (set inside `onValid`/`onInvalid`)

**State / outputs**
- `Seq` (int64) — iteration counter
- `PrevPrice` (double) — last accepted consensus price (persisted to next step)
- `CoinbasePrice`, `BitstampPrice`, `GeckoPrice` (double) — raw fetched values
- `ConsensusPrice` (double) — accepted price if quorum passes
- `QuorumPair` (string) — which pair matched (`CB`, `CG`, `BG`)
- `DeltaPct` (double) — relative change vs `PrevPrice`
- `Ok` (bool) — success/failure for the step
- `Error` (string) — failure reason (carried to next step)

---

## Network configuration

### Mainnet (XGRChain)
- ChainID: `1643`
- RPC:
  - `https://rpc.xgr.network`
  - `https://rpc1.xgr.network`
  - `https://rpc2.xgr.network`
- Explorer: `https://explorer.xgr.network`
- Workbench: `https://xdala.xgr.network`

### Testnet (XGRChain)
- ChainID: `1879`
- RPC: `https://rpc.testnet.xgr.network`
- Explorer: `https://explorer.testnet.xgr.network`
- Workbench: `https://xdala.testnet.xgr.network`
- Faucet (testnet only): `https://faucet.xgr.network/`

---

## Run it with XDaLa Workbench

1. Open Workbench (Testnet recommended)
   - https://xdala.testnet.xgr.network

2. Deploy / register the **XRC-137 rule**
   - import: `XRC137json/ApiPriceFeedQuorumStep_3Sources.json`
   - deploy/register
   - copy the deployed rule address

3. Configure the **XRC-729 loop**
   - open: `XRC729json/ApiPriceFeedQuorumLoop.json`
   - replace `<ApiPriceFeedStep-Addr>` with your deployed XRC-137 rule address

4. Deploy / register the **XRC-729 process**

5. Start with an initial payload:

```json
{
  "Base": "BTC",
  "Quote": "USD",
  "Seq": 0,
  "PrevPrice": 0.0,
  "QuorumTolPct": 0.01,
  "MaxDeltaPct": 0.2,
  "Ok": false,
  "Error": ""
}
