# API Price Feed — 3-Source Quorum (XDaLa Example)

This example demonstrates a **robust, auditable on-chain data ingestion loop** with XDaLa using **3 independent price APIs** and a configurable **k-of-n quorum** + **deterministic consensus** aggregation.

It is designed to reduce the impact of:
- single-API outages / glitches
- transient spikes
- outliers from one source

while keeping every decision **traceable and reproducible**.

---

## What it does

Each iteration (“step”) performs:

1) **Fetch** BTC/USD spot price from 3 sources:
   - Coinbase Spot API
   - Bitstamp Ticker API
   - CoinGecko Simple Price API

2) **Quorum gate** (k-of-n)
   - A quorum passes if at least `K` sources agree within tolerance `QuorumTolPct`
   - Agreement is evaluated with a selected metric (here: **relative difference**)

3) **Consensus value**
   - A deterministic consensus price is computed from the inlier set
   - In this example: `agg = "mean"` (smooth,deterministic)

4) **Delta guard** (optional safety)
   - Rejects updates that deviate too strongly from the previously accepted value
   - Controlled by `MaxDeltaPct`

5) **Persist + loop**
   - Writes raw source prices + final consensus back into the payload
   - The orchestration continuously respawns the step

---

## Files & structure


examples/ApiPriceFeed/
README.md

XRC137json/
ApiPriceFeedQuorumStep_3Sources.json

XRC729json/
ApiPriceFeedQuorumLoop.json


---

## Key idea: no PrevPrice (state is `Price`)

This example intentionally does **not** use `PrevPrice`.

Instead:

- **Input payload field** `Price` represents the **previous accepted price** (state carried into the step).
- **Output payload field** `Price` becomes the **new consensus price** (only on valid steps).
- On invalid steps, `Price` is kept unchanged (hold-last-good).

This keeps the payload minimal and avoids duplicated fields showing the same value.

---

## Payload fields

### Configuration
- `Base` / `Quote` (string)  
  Pair label shown in the payload (default: `BTC` / `USD`)

- `K` (int64)  
  Quorum threshold. With 3 sources, `K=2` means **2-of-3**.

- `QuorumTolPct` (double)  
  Tolerance for agreement using the chosen metric.  
  Default: `0.01` (1%)

  With metric `"rel"`, this means: sources are considered consistent if their relative difference is ≤ 1%.

- `MaxDeltaPct` (double)  
  Maximum allowed update step relative to the previous accepted `Price`.  
  Default: `0.2` (20%)

- `waitSec`  
  Set inside `onValid` / `onInvalid`. Controls loop frequency.

### State / outputs
- `Seq` (int64)  
  Iteration counter.

- `Price` (double)  
  Persisted state: last accepted value from the previous step.
  - On valid: updated to the new consensus
  - On invalid: unchanged (hold-last-good)

- `CoinbasePrice`, `BitstampPrice`, `GeckoPrice` (double)  
  Raw prices fetched from each API.

- `DeltaPct` (double)  
  Relative change of the new consensus vs the previous `Price`.

- `Ok` (bool)  
  Step success/failure.

- `Error` (string)  
  Failure reason carried to the next step.

- `Source` (string)  
  Identifier for the step (e.g. `quorum_3api`).

---

## CEL functions used

This example assumes the following deterministic helper functions exist in the XDaLa CEL environment:

### `quorum(values, metric, mode, tol, k) -> bool`
- `values`: list of numeric values (e.g. `[Coinbase, Bitstamp, Gecko]`)
- `metric`: `"rel"` (relative difference)
- `mode`: `"ball"` (inlier set around a candidate; robust for outliers)
- `tol`: tolerance as double
- `k`: required inlier count

### `consensus(values, metric, mode, agg, tol, k) -> double`
- Same arguments as `quorum(...)`, plus:
- `agg`: `"mean"` recommended for robust numeric consensus

### `safeDiv(num, den, fallback) -> double`
- Used to avoid division-by-zero in delta computations

---

## Delta guard without PrevPrice (important)

Because there is no `PrevPrice`, the **previous value is simply the input `[Price]`**.

Define:

- `NEW = consensus([...], "rel", "ball", "mean", QuorumTolPct, K)`
- `OLD = [Price]` (incoming state)

Then:

- `DeltaPct = (OLD == 0.0) ? 0.0 : safeDiv(abs(NEW - OLD), abs(OLD), 0.0)`
- Guard: `(OLD == 0.0) || (DeltaPct <= MaxDeltaPct)`

If your JSON still references `PrevPrice`, replace those references with `[Price]`.

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

## Run it with XDaLa Workbench (recommended: Testnet)

1) Open Workbench:
   - https://xdala.testnet.xgr.network

2) Deploy / register the **XRC-137 rule**
   - import: `XRC137json/ApiPriceFeedQuorumStep_3Sources.json`
   - deploy/register
   - copy the deployed rule address

3) Configure the **XRC-729 loop**
   - open: `XRC729json/ApiPriceFeedQuorumLoop.json`
   - replace `<ApiPriceFeedStep-Addr>` with your deployed XRC-137 rule address

4) Deploy / register the **XRC-729 process**

5) Start with an initial payload:

```json
{
  "Base": "BTC",
  "Quote": "USD",
  "Seq": 0,
  "Price": 0.0,
  "K": 2,
  "QuorumTolPct": 0.01,
  "MaxDeltaPct": 0.2,
  "Ok": false,
  "Error": "",
  "Source": "quorum_3api"
}
