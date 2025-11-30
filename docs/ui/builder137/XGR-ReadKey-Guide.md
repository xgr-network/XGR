# XGR Read-Key: How it works and how to use it

This guide explains **what the Read-Key is**, how it’s stored **locally and on-chain**, how to **create/import** it, and how to **decrypt** your data across the app. It clarifies the **RAM unlock** and **Permit** concepts and why they protect you. It also explains **when a short Wallet signature (Permit)** is needed in Manage Read-Key and why you might sometimes see **two wallet dialogs**.

---

## 1) What is the Read-Key?

- Asymmetric key pair for encrypt/decrypt private rule data.  
- **Public key** on-chain; **private key** stays client-side, password-encrypted in IndexedDB.  
- Private key is temporarily unlocked into RAM (~5 min) for decryption.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/readkey-panel-create.png) — Read-Key panel showing seed (blurred), password fields, “I saved the seed”, and a **Permit (save)** badge with countdown.

---

## 2) Create / Import / Manage

**Create**: Generate seed, set password, sign short-lived **Permit (save)**, store locally.  
**Import**: Paste seed and set a new password, or paste a hex public key (advanced).  
**Delete & re-create**: Wipes any RAM unlock; other tabs become invalid.

**Permit (save)**  
- Create/Import **write to local storage** (encrypted). For this the app needs a short wallet signature called **Permit (save)** (~5 minutes).  
- You’ll see a **badge with a countdown** in the Read-Key panel when the Permit is active. If it expired, you’ll be asked to sign again the next time you save.  
- After a **hard browser refresh / cache clear**, your wallet may be **connected** but the DApp still requires **authorization/signature** for saving. Use **“Jetzt autorisieren / Authorize now”** in the panel or simply proceed with Create/Import and you’ll get the short signature prompt.

**Why you might see two dialogs**  
- **Normal case:** one signature dialog for **Permit (save)**.  
- **If your account hasn’t been granted to the DApp yet:** your wallet may first show **“connect/allow account”** (wallet UI), followed by the **Permit (save)** signature. That looks like *two* prompts, but they do different things.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/readkey-panel-import.png) — Import via seed vs public key; the Permit (save) badge indicates whether saving is already authorized.

---

## 3) Verification (on-chain vs local)

The app compares the on-chain public key with your local public key.

- **Read-Key verified** (green) means they match.  
- If red: connect the correct wallet & chain or update the on-chain key.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/verified-badge.png) — Green **Read-Key verified** badge near the wallet status.

---

## 4) Decryption: Authorize & Unlock

Used across the app (Contract Manager “Load from chain”, XRC-137 Builder, XRC-729 Builder). Two steps:

1) **Authorize (Permit ~5 min)** — wallet signature proves a human is present.  
2) **Unlock (RAM ~5 min)** — decrypt your private key in memory for a short window.

Both expire automatically; key changes invalidate any unlock.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/decrypt-dialog.png) — Decrypt dialog with wallet selector, **Read-Key verified**, **Permit (decrypt)** badge + countdown, password field, and **Authorize & Unlock**.

---

## 5) Why Permit + RAM unlock protect you

- **Permit** scopes authorization to account + contract + chain and expires quickly.  
- **RAM unlock** minimizes exposure: encrypted at rest, wiped from RAM after ~5 min.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/troubleshooting-messages.png) — A collage of status lines: “RPC offline…”, “Not verified”, “No local wrapped…”, and a green “Authorized & unlocked”.

---

## 6) Troubleshooting (common)

- **Not verified** → connect correct wallet/network or import the matching key.  
- **Permit expired** → click **Authorize now** or run **Authorize & Unlock** again.  
- **No local wrapped key** → open **Manage Read-Key** and import/create it.  
- **Stale unlock** → re-enter password after key changes.  
- **RPC offline** → switch chain or endpoint; reconnect wallet.  
- **Import button does nothing** → usually missing Permit or invalid input.  
  - Ensure **Permit (save)** is active (badge shows a countdown). If expired, use **Authorize now**.  
  - Check that the seed is a valid **BIP‑39 mnemonic** and that passwords match. Errors are shown inline.

---

## 7) Security hygiene in the panel (UX details)

- Password inputs are cleared on close/cancel or when switching flow (Create/Import).  
- Browser autofill is disabled for password fields to avoid accidental reuse.  
- Changing or re-importing the Read-Key invalidates any in‑RAM unlocks across tabs.

---

_Last updated: 2025-10-19_
