# XGR Compile — How to compile your contract

This guide explains what the **Compile** panel does, how to run a compile, and what each output means. It also shows how the **4‑step flow** works (Wallet → Compile → Deploy → Update), so you always know **what’s next**.

---

## Where Compile sits in the flow

The Builder UI guides you through these steps (right side icons): **Wallet → Compile → Deploy → Update**.  
The next active step is highlighted; completed steps are marked with a check.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/builder-flow.png) — Flow with four steps; **Compile** is the second step. The line turns green as you complete steps.

---

## 1) Requirements

- **Wallet connected** (first step of the flow) — otherwise Compile may be **blocked** by validation.  
- A **valid model** (no blocking errors). The Compile button is disabled if validation reports blocking issues.

---

## 2) Run a compile

Open the **Compile** panel and click **Compile**. While compiling you see *Compiling…*. After success the compact flag shows **✓ Compiled**.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/compile-panel.png) — Compile panel with the **Compile** button on the right and a compact **✓ Compiled** success flag on top once done.

---

## 3) Show details & outputs

Use **Show details** to reveal the artifacts. You can **Copy** or **Download** each section.

- **Model (JSON)** — the normalized builder configuration used for artifacts  
- **Wrapper (Solidity)** — generated wrapper source for quick deploys/tests in EVM tools  
- **ABI** — contract interface in JSON (for SDKs, frontends, scripts)  
- **Bytecode** — hex-encoded contract bytecode

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/compile-details.png) — Details view with four sections, each offering **Copy** and **Download** actions. The wrapper is rendered with Solidity syntax highlighting.

---

## 4) After compile: next steps

- **Deploy** — 3rd step of the flow. Requires **Wallet connected** and **Compiled**.  
- **Update Rule** — 4th step. Requires a **deployed address** and supports **encrypted** updates if your Read‑Key is verified.

**Tip:** You can reopen **Show details** later to re‑copy or re‑download artifacts at any time.

---

## Troubleshooting

- **Compile button disabled** → fix validation errors in the Builder (payload, rules, reads, APIs).  
- **No outputs in details** → compile again; outputs only appear after a successful compile.  
- **Wrapper looks unstyled** → that is expected; the code preview uses a compact theme for readability.

---

## About the compiler (XGR Hardhat service)

- The **Compile** action runs against XGR’s managed **Hardhat** service.  
- Your model is converted to Solidity and compiled **server-side** (no on-chain transaction required).  
- The service uses a **pinned toolchain** (Hardhat/solc) for **deterministic builds** across environments.  
- Outputs (**Wrapper**, **ABI**, **Bytecode**) are returned to the UI and can be copied or downloaded.

### Security & privacy

- Compile does **not** require your wallet to sign or spend gas; it only needs a connected wallet to validate the environment/chain.  
- No private keys leave your browser. Only the generated **source/model** is sent to the compiler for artifact generation.  
- Artifacts are kept **ephemeral** on the service side (stateless build job) and shown locally in the panel.


---

_Last updated: 2025-10-19_
