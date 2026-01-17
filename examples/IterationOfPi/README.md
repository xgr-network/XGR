# Iteration of Pi (XDaLa Example)

This example demonstrates a **continuous, auditable on-chain compute stream** using XDaLa.
Instead of relying on external inputs, it iteratively approximates **π (Pi)** using a deterministic mathematical series. Every iteration updates state on-chain and can be inspected via explorer logs / receipts.

> Note: This demo is a **deterministic compute feed** (not an external oracle feed).  
> The same execution model can later be connected to real-world inputs (measurements, market prices) via external connectors/attestations.

---

## What it does

The process runs an infinite loop of “Pi iteration steps”:
- It increments an iteration counter (`Iter`)
- Updates the partial sum `S`
- Computes the current approximation `Pi = 4.0 * S`
- Waits for a configurable time (`waitSec`) before the next step
- Spawns the next step (loop)

This produces a **continuous stream of verifiable state updates**.

---

## Math

We use the Leibniz series:

\[
\pi = 4 \cdot \sum_{n=0}^{\infty} (-1)^n \cdot \frac{1}{2n+1}
\]

In this example, `S` stores the running sum and `Pi = 4*S`.

---

## Repository structure

