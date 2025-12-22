# XGR Read Key: How it works and how to use it

This guide explains **what the Read Key is**, how it is stored **locally and on-chain**, how to **create/import** it, and how to **decrypt** your data in the app. It clarifies the concepts of **RAM unlock** and **permit** and why they protect you. It also explains **when** a short wallet signature (permit) is required in **Manage Read Key** and why you sometimes see **two wallet dialogs**.

---

## 1) What is the Read Key?

- An asymmetric key pair for encrypting/decrypting private rule and log data.  
- The **public key** is stored on-chain; the **private key** stays client-side and is stored password-encrypted in IndexedDB.  
- For decryptions, the private key is **temporarily unlocked in RAM** (~5 minutes).

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/readkey-panel-create.png) — Read Key panel with the seed (blurred), password fields, “I saved the seed”, and a **Permit (save)** badge with a countdown.

---

## 2) Create / Import / Manage

**Create**: generate a seed, set a password, sign a short-lived **Permit (save)**, store locally.  
**Import**: paste a seed and set a new password, or (advanced) paste a hex public key.  
**Delete & re-create**: removes any RAM unlock; other tabs become invalid.

**Permit (save)**  
- Create/Import writes to **local storage** (encrypted). For this, the app requires a short wallet signature called **Permit (save)** (~5 minutes).  
- When the permit is active, you’ll see a **badge with a countdown** in the Read Key panel. When it expires, you must sign again the next time you save.  
- After a **hard browser refresh / cache clear**, the wallet may still be **connected**, but the DApp may still require a fresh **authorization/signature** for saving. Use **“Authorize now”** in the panel or simply start Create/Import — then the short signature prompt will appear.

**Why you sometimes see two dialogs**  
- **Typical case:** one signature dialog for **Permit (save)**.  
- **If your account hasn’t been granted to the DApp yet:** the wallet may first show **“connect/allow account”** (wallet UI) and then the **Permit (save)** signature. This looks like *two* prompts, but they serve two different purposes.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/readkey-panel-import.png) — Import via seed vs. public key; the Permit (save) badge shows whether saving is currently authorized.

---

## 3) Verification (on-chain vs. local)

The app compares the on-chain public key with your local public key.

- **Read Key verified** (green) means they match.  
- If it’s red: connect the correct wallet & chain or update the on-chain key.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/verified-badge.png) — Green **Read Key verified** badge near the wallet status.

---

## 4) Decryption: Authorize & Unlock

Used across the app (Contract Manager “Load from chain”, XRC-137 Builder, XRC-729 Builder). Two steps:

1) **Authorize (permit ~5 min.)** — a wallet signature proves a human is actively present.  
2) **Unlock (RAM ~5 min.)** — decrypts your private key temporarily in memory.

Both expire automatically; key changes invalidate any existing unlock.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/decrypt-dialog.png) — Decrypt dialog with wallet selector, **Read Key verified**, a **Permit (decrypt)** badge + countdown, password field, and **Authorize & Unlock**.

![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/decrypt-dialog-2.png)

---

## 5) Why Permit + RAM Unlock protect you

- **Permit** scopes authorization to account + contract + chain and expires quickly.  
- **RAM unlock** minimizes exposure: encrypted “at rest”, wiped from RAM after ~5 minutes.  
- **Permit and RAM unlock** can remain valid and be used across the page while they are active.

---

## 6) Troubleshooting (common)

- **Not verified** → connect the correct wallet/network or import the matching key.  
- **Permit expired** → click **Authorize now** or run **Authorize & Unlock** again.  
- **No local wrapped key** → open **Manage Read Key** and create/import one.  
- **Stale unlock** → after key changes, enter the password again.  
- **RPC offline** → switch chain or endpoint; reconnect the wallet.  
- **Import button does nothing** → usually the permit is missing or the input is invalid.  
  - Check that **Permit (save)** is active (badge shows a countdown). If expired, use **Authorize now**.  
  - Check that the seed is a valid **BIP-39 mnemonic** and that the passwords match. Errors are shown inline.

---

## 7) Security hygiene in the panel (UX details)

- Password inputs are cleared on close/cancel or when switching flows (Create/Import).  
- Browser autofill is disabled for password fields to avoid accidental reuse.  
- Changing or re-importing the Read Key invalidates all in-RAM unlocks across tabs.

---
