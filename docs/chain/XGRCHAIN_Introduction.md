# XGR Chain — Introduction

**Document ID:** XGRCHAIN-INTRO  
**Status:** Draft  
**Last updated:** 2026-02-07  
**Audience:** Developers, node operators, auditors

---

## What is XGR Chain?

**XGR Chain** (chain name: `xgrchain`) is an **EVM-compatible** blockchain network built using **Polygon Edge** as the base client stack.

Two important clarifications:

1) **Bootstrap chain (not a fork):**  
XGR Chain starts from a **custom genesis block** and a clean state (block `0`).  
It does **not** inherit state or history from Ethereum mainnet (or any other chain). In other words, it is a **new network** with its own validator set, chain ID and parameters.

2) **Open chain code vs. closed Engine:**  
The **chain client / protocol implementation** is intended to be made public (open source).  
The **Engine** component remains **closed source**. Where protocol-relevant parameters are controlled by governance, the chain uses an **on-chain registry contract** (see *EngineRegistry*) so that network behavior remains **verifiable on-chain** even if some off-chain components are closed.

---

## Quick facts (from `genesis.json`)

| Parameter | Value |
|---|---|
| Network name | `xgrchain` |
| Chain ID | `1643` |
| Client basis | Polygon Edge (EVM-compatible) |
| Consensus | IBFT (Istanbul BFT), **PoA** |
| Validator signature scheme | **BLS** (validator_type = `bls`) |
| Block time | ~2.0 s |
| Epoch size | 500 blocks |
| Block gas limit (genesis) | 60,000,000 |
| Bootnodes | 1 |

---

## Where to start

This documentation set is split into:

- **Chain Spec** — a normative overview of the network parameters and protocol choices  
- **IBFT Consensus** — how finality and validator-based consensus work on XGR Chain  
- **Genesis & Network Configuration** — how genesis is structured and which parameters matter  
- **Gas & Fees** — described in **`XRC-GAS_Gas_Price_Behavior.md`** (already present)

---

## Glossary

- **Bootstrap chain:** a new network started from a genesis block (no inherited history).
- **Chain ID:** the EIP-155 chain identifier used in transaction signing to prevent replay attacks.
- **IBFT:** Istanbul Byzantine Fault Tolerance, a PBFT-family consensus protocol with immediate finality.
- **PoA:** Proof-of-Authority; validators are permissioned entities.
- **BLS validators:** validators identified by an ECDSA address but using BLS keys for aggregated commit seals.
- **EngineRegistry:** an on-chain configuration registry contract used to store governance-controlled parameters such as `minBaseFee`.

---

## Out of scope

This chain documentation intentionally does **not** document the closed-source **Engine** implementation internals.  
Where the Engine affects consensus-critical or fee-critical behavior, the chain will reference **on-chain parameters** that are independently verifiable.
