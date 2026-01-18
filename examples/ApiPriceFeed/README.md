# API Price Feed (Coinbase Spot) — XDaLa Example

This example demonstrates a **continuous, auditable on-chain data ingestion loop** with XDaLa.
It pulls a spot price from a public HTTP API, validates the result, writes it into the session payload, and **self-spawns** to run forever.

> Important: This is an **API-backed feed**, not a cryptographic oracle.
> It is intended as a minimal reference implementation for “external data → validation → auditable state updates”.
> For production-grade price feeds, use signed data / oracle networks / attestation mechanisms.

---

## What it does

Each iteration (“step”) performs:

1. **Fetch** spot price from Coinbase endpoint  
   `GET https://api.coinbase.com/v2/prices/{BASE}-{QUOTE}/spot`

2. **Validate**
   - price must be numeric and `> 0`
   - optional **delta guard**: rejects price jumps larger than `MaxDeltaPct` per step

3. **Update session payload**
   - increments `Seq`
   - updates PrevPrice`
   - sets `Ok = true/false`
   - updates `Error` (empty on success, message on failure)

4. **Wait**
   - `waitSec` controls iteration frequency

5. **Loop**
   - the XRC-729 process spawns the same step again (on valid AND invalid)

---

## Files

examples/ApiPriceFeed/
XRC137json/
ApiPriceFeedStep_CoinbaseSpot.json
XRC729json/
ApiPriceFeedLoop_CoinbaseSpot.json


---

## Payload fields (high level)

- `Base` (string) — e.g. `BTC`
- `Quote` (string) — e.g. `USD`
- `Seq` (int64) — iteration counter
- `PrevPrice` (double) — last accepted price (used for delta guard)
- `MaxDeltaPct` (double) — max allowed relative change per step (e.g. `0.2` = 20%)
- `Ok` (bool) — whether the current step succeeded
- `Error` (string) — error message carried to the next step

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

## Live session (Testnet)

This process is currently running on Testnet:

- https://explorer.testnet.xgr.network/sid/43?from=0x8f6b9eb091d43c2efccfd58a5391dd8bf12f245b

## Run it with XDaLa Workbench (recommended)

1. Open Workbench
   - Testnet: https://xdala.testnet.xgr.network
   - Mainnet: https://xdala.xgr.network

2. Deploy / register the **XRC-137 rule**
   - import: `XRC137json/ApiPriceFeedStep_CoinbaseSpot.json`
   - deploy/register
   - copy the deployed rule address

3. Configure the **XRC-729 loop**
   - open: `XRC729json/ApiPriceFeedLoop_CoinbaseSpot.json`
   - replace the placeholder rule address (e.g. `<ApiPriceFeedStep-Addr>`) with the deployed XRC-137 rule address

4. Deploy / register the **XRC-729 process**

5. Start the process with an initial payload (example)

```json
{
  "Base": "BTC",
  "Quote": "USD",
  "Seq": 0,
  "MaxDeltaPct": 0.2,
  "PrevPrice": 0.0,
  "Ok": false,
  "Error": ""
}
