# XGR Update Rule — How to update an existing contract

This guide explains the **Update Rule** panel (step **4 of 4** in the flow: Wallet → Compile → Deploy → **Update**). You can update a contract that you’ve just deployed, one you opened from the **Contract Manager**, or overwrite a contract by pasting its on-chain address.

---

## Where Update sits in the flow

The Builder shows your progress on the right: **Wallet → Compile → Deploy → Update**. Update becomes **active** once Wallet is connected, the model is **compiled**, and you’ve selected a **contract address** (from Deploy result or Contract Manager).

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/update-panel-flow.png) — Flow with four steps; **Update** is highlighted when steps 1–3 are done or a contract address is provided.

---

## 1) Requirements

- **Wallet connected** (step 1)  
- **Compiled** model (step 2)  
- A **valid contract address** (`0x…`) to update

If a requirement is missing, the Update button is disabled and a short hint is shown under the button.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/update-panel.png) — Update panel with **Update Rule** button (right), **Encrypt** toggle, **Expiry** inputs (if Encrypt is on), **Read‑Key** status/manager, and the **contract address** input.

---

## 2) Plain vs. Encrypted update

You can write your rule **in plain** (no encryption) or **encrypted**:

- **Plain update**: Sends the JSON rule directly to the contract (no grants, no encryption).  
- **Encrypted update**: Toggle **Encrypt** before hitting **Update Rule**. The app runs a one‑click sequence:
  1) **Prepare encryption** off‑chain (creates **RID**, **suite**, encrypted **blob**)  
  2) **Commit owner grants** on‑chain (sends `updateTx[]`)  
  3) **Persist** `blob/suite/rid` on your rule contract

**Expiry** controls for how long your decryption right remains valid. In the UI you set *Years/Days* → this becomes an on‑chain **expireAt** in the Grants Registry. Until that time, a wallet with your verified **Read‑Key** can unwrap the key and decrypt. After **expiry**, the grant is **inactive** and apps/indexers will refuse decryption by policy (you can later extend with a new grant via Update).  
See **Encryption & Grants** → https://xgr.network/docs.html#xrc563

**What you see (Encrypt on)**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/update-panel-encrypt-open.png) — Encryption enabled: **Read‑Key** pill, **Manage Read‑Key**, **Refresh**, **Expiry time** inputs, and a mini **Encrypted update** checklist that turns **✓** per step and shows live status.

---

## 3) Supported scenarios

- **Plain → Plain**: Overwrite a plain contract with a new plain rule.  
- **Plain → Encrypted**: Switch to encryption; pick **Expiry** and run the encrypted flow.  
- **Encrypted → Encrypted**: Keep encryption; you can extend/shorten **Expiry**.  
- **Encrypted → Plain**: Remove encryption by disabling **Encrypt** and sending a plain update (the old grant will not be used for reading the new plain content).

> **Read‑Key required:** Encrypted updates require a **verified Read‑Key**. Use **Manage Read‑Key** to create/import and verify yours. If not verified, the button stays disabled.

---

## 4) Results & Receipt

After sending, you’ll see:
- **Tx** hash (with explorer link + copy)  
- Optional **encrypted flow** ticks: prepare ✓, grants ✓, persist ✓  
- **Network** label  
- A collapsible **Receipt** (raw JSON)

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/update-panel-result.png) — Result box showing the update **Tx** (and extra txs if encryption was used).  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/update-panel-receipt.png) — Receipt details with the full JSON.

---

## How it works (under the hood)

- **Update flow** connects your wallet, encodes `updateRule(json)` and sends the transaction; waits for the receipt.  
- **Encrypted update** reuses the same encryption pipeline as encrypted deploy: off‑chain prepare → on‑chain grants → on‑chain persist; the panel lists `rid`, `hintTxHashes`, `persistHash` and a status `phase`.

---

## FAQ

**Can I update a contract I imported from Contract Manager?**  
Yes. Paste or import the **deployed address**; the Update panel will use it.

**Do I have to use encryption?**  
No. Leave **Encrypt** off to send a plain update. You can switch modes at any time.

**What happens after expiry?**  
The owner grant becomes **inactive** on-chain, so clients refuse to decrypt by policy. Write a new grant (via encrypted Update) to extend access.  
See **Encryption & Grants** → https://xgr.network/docs.html#xrc563

---

_Last updated: 2025-10-19_
