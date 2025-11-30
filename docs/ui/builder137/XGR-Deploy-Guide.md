# XGR Deploy — How to deploy your contract

This guide explains the **Deploy** panel (step **3 of 4** in the flow: Wallet → Compile → **Deploy** → Update). It covers **plain deploy** and the optional **encrypted deploy** including Read‑Key requirements, expiry, and the on-chain steps.

---

## Where Deploy sits in the flow

The Builder shows your progress on the right: **Wallet → Compile → Deploy → Update**. Deploy becomes **active** once Wallet is connected and the model has been **compiled**.

**What you see** 
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/deploy-panel-builder-flow-deploy.png) — Flow with four steps; **Deploy** is highlighted when Wallet (1) and Compile (2) are done.

---

## 1) Requirements

- **Wallet connected** (step 1) 
- **Compiled** model (step 2) 
 If a requirement is missing, the Deploy button is disabled and a short hint is shown under the button.

**What you see** 
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/deploy-panel.png) — Deploy panel with **Deploy** button (right), toggle **Encrypt after deploy**, and a compact hint line when something is missing.

---

## 2) Plain deploy (no encryption)

Click **Deploy**. Your wallet opens and asks to **send the deploy transaction**. After confirmation you’ll see:
- **Tx** (with explorer link and copy button) 
- **Contract** address (with copy button) 
- **Network** label 
- A collapsible **Receipt**

**What you see** 
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/deploy-result.png) — Result box with the transaction hash and the deployed **Contract** address.

---

## 3) Encrypted deploy (one‑click flow)

Turn on **Encrypt after deploy** to store the rule **encrypted** right after an empty deploy. This requires a **verified Read‑Key** and runs four steps in sequence (automatically):

1. **Deploy empty contract** (no JSON on-chain yet) 
2. **Prepare encryption** off-chain (creates `rid`, `suite`, encrypted `blob`) 
3. **Commit owner grants** on-chain (sends `updateTx[]`) 
4. **Persist encrypted rule** on the contract (`blob/suite/rid`)

See **Encryption & Grants** → https://xgr.network/docs.html#xrc563

You can set an **Expiry time** (Years/Days). That controls the **grant expiry** of the owner permits used for reading.

**What you see** 
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/deploy-encrypt-open.png) — Encrypt mode enabled: a **Read‑Key status pill**, **Manage Read‑Key** button, **Refresh**, **Expiry time** inputs, and a mini **Encrypted flow** checklist that turns **✓** per step and shows a live status text.

> **Read‑Key required:** If encryption is enabled, the button is disabled until a valid Read‑Key is **verified**. You can open **Manage Read‑Key** to create/import a local key and register it on‑chain.

---

## 4) Receipt details

Use **Show details** to open the raw receipt (JSON) for inspection or support.

**What you see** 
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/deploy-receipt.png) — Receipt details with the full JSON.

---

## How it works (under the hood)

- **Deploy flow** builds a wrapper from your model, compiles it, connects your wallet, sends the tx and waits for the receipt. 
- **Deploy panel** renders the button states, result section, explorer links, copy actions, and the encrypted‑flow checklist with live status. 
- The **flow UI** (right dock) shows Wallet/Compile/Deploy/Update with the proper **active / done / blocked** logic. 
- **Encrypted deploy** uses the encryption engine: off‑chain **prepare**, on‑chain **grants**, then **persist** on the contract. The hook exposes `rid`, `hintTxHashes`, `persistHash` and a status `phase`. 

### Security & privacy (encryption)
- Your wallet must be connected; encryption steps are on‑chain and require explicit approval in your wallet. 
- The **Read‑Key** is managed locally; registration uses standard on‑chain transactions. 
- The grant **expiry** equals `(years * 365 + days) * 86400` seconds (UTC). The UI writes the expiry into the encrypted‑deploy call. 

---

## FAQ

**Do I need encryption?** 
No. If you leave **Encrypt after deploy** off, the contract is deployed normally and you can later use **Update** to push rules (plain or encrypted). 

**Why is the Deploy button disabled when encryption is on?** 
Because the **Read‑Key must be verified** first. Open **Manage Read‑Key** and follow the instructions. 

**Can I see all tx hashes of the encrypted run?** 
Yes. The result box lists the primary deploy tx plus every **grant** and the **persist** tx with explorer links. 

---

_Last updated: 2025-10-19_

---

## Plain vs. Encrypted deploy (and how expiry works)

You can deploy **without encryption** (plain) or **with encryption**:

- **Plain deploy**: A normal deploy that writes the contract to chain. No encrypted rule is stored yet. You can later use **Update** to push a rule (plain or encrypted).
- **Encrypted deploy**: Toggle **Encrypt after deploy** before clicking **Deploy**. This runs a one‑click sequence:
 1) Deploy the empty rule contract 
 2) Encrypt your rule off‑chain (creates **RID**, **suite**, encrypted **blob**) 
 3) Write an **owner grant** on the Grants/Key Registry (XRC‑563) with an **expiry** 
 4) Persist **blob + suite + rid** on your rule contract (XRC‑137)

See **Encryption & Grants** → https://xgr.network/docs.html#xrc563

**Expiry controls how long your decryption right remains valid.** 
When you choose *Years/Days* in the UI, we compute an **expireAt** timestamp and store it with your owner grant on XRC‑563. Until that time, your wallet (with your local Read‑Key) can unwrap the content key and decrypt the rule. After **expiry**, the grant is **inactive** and clients will refuse to decrypt by policy. You can extend access by writing a new grant (e.g., via Update).

> Note: Technically, an old device that cached the encrypted key could still try to decrypt after expiry, but apps and indexers rely on the on‑chain **expireAt** policy and will treat the grant as expired. A periodic **sweeper** also removes expired entries from the index for predictable costs.
