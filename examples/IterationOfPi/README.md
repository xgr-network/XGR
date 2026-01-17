
---

## XRC-137 rule step

File: `XRC137json/Iterationstep.json`

State fields:
- `Iter` (int64): iteration counter
- `S` (double): partial sum
- `Pi` (double): current Pi approximation

Update formulas executed on each valid step:
- `Iter = [Iter] + 1`
- `S = [S] + pow(-1.0, double([Iter])) / (2.0*double([Iter]) + 1.0)`
- `Pi = 4.0 * [S]`

Timing:
- `waitSec: 3600` (1 hour per iteration). Reduce this for faster demos.

---

## XRC-729 process loop

File: `XRC729json/IterationOfPi.json`

This process defines a structure with one step (`PiIterationStep`) that:
- executes the XRC-137 rule contract
- on valid execution, spawns itself again

**Important:** Replace `<Iterationstep-Addr>` with the deployed XRC-137 rule contract address.

---

## Network configuration

### Mainnet (XGRChain)
- ChainID: `1643`
- RPC:
  - `https://rpc.xgr.network`
  - `https://rpc1.xgr.network`
  - `https://rpc2.xgr.network`
- Explorer: `https://explorer.xgr.network`

### Testnet (XGRChain)
- ChainID: `1879`
- RPC: `https://rpc.testnet.xgr.network`
- Explorer: `https://explorer.testnet.xgr.network`
- Faucet (testnet only): `https://faucet.xgr.network/`

---

## How to run (high level)

Steps:
1. Deploy / register the XRC-137 rule for `Iterationstep.json`
2. Update `IterationOfPi.json` to set `rule` = the deployed rule address
3. Deploy / register the XRC-729 process
4. Start the process with an initial payload, e.g.:
   - `Iter = 0`
   - `S = 0.0`
   - `Pi = 0.0`
5. Observe iterations in the explorer and watch `Pi` converge over time

---

## Suggested demo settings

For video demos:
- set `waitSec` to `3` or `5`

For a long-running “continuous stream”:
- `waitSec = 60` or `3600`

---

## Why this example matters

The Pi iteration is intentionally simple, but it demonstrates:
- stateful execution
- deterministic processing
- repeatable looping workflows
- auditable outputs

A clean proof of “continuous, auditable on-chain processing” without external dependencies.
