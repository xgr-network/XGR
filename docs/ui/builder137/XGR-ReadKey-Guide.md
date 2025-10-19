# XGR Read-Key: How it works and how to use it

This guide explains **what the Read-Key is**, how it’s stored **locally and on-chain**, how to **create/import** it, and how to **decrypt** your data across the app (XRC-137 Builder, Contract Manager, and XRC-729 Builder). It also clarifies the **RAM unlock** and **Permit** concepts and why they protect you.

---

## 1) What is the Read-Key?

- The **Read-Key** is an asymmetric key pair used to **encrypt/decrypt** your private rule data.
- **Public key** → stored on-chain in your contract (so others can encrypt for your contract).  
- **Private key** → stays **client-side** in your browser, **encrypted with your password** and saved in IndexedDB.  
- When you need to decrypt, the private key is **temporarily unlocked into RAM** (memory) for a short time window.

**Security model at a glance**
- Private key **at rest**: password-encrypted, non-extractable.  
- Private key **in use**: temporarily in RAM for **5 minutes** (auto-lock).  
- **Permit**: a short-lived wallet signature (≈5 minutes) that proves “a human is present” whenever decryption or local Read-Key saving is requested.  
- **Cross-tab safety**: if the key changes in another tab, your current session is invalidated.

> **Result:** even if someone gains access to your machine after you’ve closed the dialog, the Read-Key won’t be usable (RAM is cleared; password and permit have expired).

---

## 2) Read-Key Panel (create, import, manage)

Open **Read-Key** from the Builder or via **Manage Read-Key** in dialogs.

### 2.1 Create a Read-Key (seed)
1) Click **Create Read-Key**.  
2) You’ll see a **seed phrase**. **Write it down** and store it safely.  
3) Choose a **new password** (this encrypts the private key locally).  
4) Click **I saved the seed** → you’ll be asked to **sign a short-lived permit** (proves a real user saves the key).  
5) The app stores the **encrypted private key** locally and the **public key** for on-chain verification.

**Useful UI**
- **Read-Key verified** (green): your local public key matches the one on-chain (when wallet is connected).  
- **Permit (save)** badge + countdown: shows the short-lived authorization needed only for **local save** actions.

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/readkey-panel-create.png) — show the Read-Key Panel with seed display, password fields, and the “I saved the seed” button.  
  _What to capture:_ the seed area (blurred), password inputs, “I saved the seed”, and the **Permit (save)** badge.

### 2.2 Import a Read-Key
- **Import seed**: paste your seed phrase, set a **new password**, confirm → sign the **Permit (save)** → stored locally.  
- **Import public key (advanced)**: paste a hex public key if you only want to replace the on-chain match for verification. (You’ll still need a private key locally to decrypt.)

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/readkey-panel-import.png) — show both import options side-by-side.  
  _What to capture:_ seed import fields, public key import field, and the Permit (save) badge.

### 2.3 Delete & Re-create
- Deleting the local Read-Key will **wipe** the RAM unlock immediately (also in other tabs).  
- If you change the Read-Key (locally or on-chain), existing **RAM unlocks turn stale** and decryption is blocked until you re-authorize & unlock.

---

## 3) On-chain public key (verification)

The app compares:
- **On-chain** public key (from your contract)  
- **Local** public key (from your Read-Key Panel / IndexedDB)

**Read-Key verified (green)** means they match.  
If **not verified (red)**: connect the correct wallet/account & network, or update your on-chain key.

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/verified-badge.png) — show the green **Read-Key verified** badge.  
  _What to capture:_ wallet status line and the verified badge next to it.

---

## 4) Decryption: Authorize & Unlock

You decrypt in **Contract Manager (Load from chain)**, in **XRC-137 Builder**, or in the **XRC-729 Builder** flows (e.g., Load from Chain / Load All Rules). All use the same two controls:

1) **Authorize (Permit ~5 min)**  
   - A wallet signature proves that a real user is present (prevents headless/batch abuse).  
   - The permit is bound to your **owner address**, **contract**, and **chain**.

2) **Unlock (RAM ~5 min)**  
   - Enter your **password** to decrypt your private key **into RAM** for a short window.  
   - The unlocked key is **bound** to the current local public key (fingerprint). Any key change → unlock becomes **stale** and is cleared.

**Important**
- Both **Permit** and **RAM unlock** expire automatically (≈5 minutes).  
- The Decrypt button will first **fetch permit**, then **unlock from your password**, and finally **decrypt & load** the data.

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/decrypt-dialog.png) — show the Decrypt dialog with: wallet selector, **Read-Key verified**, **Permit (decrypt)** badge with countdown, password field, and **Authorize & Unlock**.  
  _What to capture:_ badges + countdowns and the main **Decrypt & Load** button.

---

## 5) XRC-137 Builder

### 5.1 Deploy Panel (encrypted deploy)
- Select **Network** (dropdown) and **Wallet** (dropdown).  
- **RPC preflight** checks the network is reachable; you’ll see **RPC online** in green.  
- Connect wallet → you can now **Deploy** with encrypted settings.
- Your Read-Key’s **public key** defines who can decrypt post-deployment.

**Buttons & dropdowns**
- **Network**: pick the chain (e.g., XGR Mainnet, Testnet).  
- **Wallet**: select provider (e.g., MetaMask).  
- **Connect / Disconnect**: handle wallet session.  
- **Deploy**: sends transactions; expect your wallet to pop up several times.

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/137-deploy.png) — show the Deploy panel with wallet connected and **RPC online**.  
  _What to capture:_ chain dropdown, wallet dropdown, connect/disconnect, and status line.

### 5.2 Update Panel (encrypted update)
- Same structure as Deploy: choose network, wallet, connect, then **Update**.  
- Reads your on-chain public key to keep “Read-Key verified” status correct.

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/137-update.png) — show the Update panel with a connected wallet and verified badge.

---

## 6) Contract Manager → **Load from Chain** (XRC-137)

1) Open the **Decrypt XRC-137** dialog.  
2) Ensure **Read-Key verified** is green.  
3) Click **Decrypt & Load**:
   - If needed, the app asks for **Permit** (wallet signature, ~5 min).  
   - Enter password to **Unlock** your Read-Key into RAM (~5 min).  
   - Decryption runs and loads the rule set.

**Edge cases the app handles**
- If your local key was deleted in another tab, you’ll see a **red** message:  
  *“No local wrapped Read-Key found. Use ‘Manage Read-Key’ to create or import it.”*
- If your unlocked RAM key belongs to a different public key (stale), the app blocks decryption until you re-unlock for the current key.

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/137-contractmanager-load.png) — show the Decrypt dialog mid-flow with a red message about missing local key (for documentation).

---

## 7) XRC-729 Builder

### 7.1 Load from Chain
- Connect wallet (RPC preflight as in 137 Deploy).  
- Click **Load from Chain** → decryption dialog appears.  
- Same **Authorize & Unlock** flow (Permit + RAM unlock) and **Read-Key verified**.

### 7.2 Load All Rules
- Loads all rule entries for your contract; decryption may process multiple payloads during the **same 5-minute window** (you won’t be asked for your password or permit again while they’re valid).

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/729-load-all.png) — show the list after a successful decryption batch.  
  _What to capture:_ loaded rules, success state, any inline status.

---

## 8) Why Permit + RAM unlock protect you

- **Permit (~5 min)**: ensures a human approved the action **just now** with the correct wallet, on the exact chain and contract. Headless scripts can’t replay indefinitely; it expires quickly and is scoped.
- **RAM unlock (~5 min)**: even if malware looked into your IndexedDB, it only finds an **encrypted** private key. Without your password + current session unlock, decrypt is impossible. After 5 minutes, the in-RAM key is wiped.

> **Together**, they minimize the attack window (time-boxed decryption) and make secret exfiltration much harder.

---

## 9) Troubleshooting

- **“Read-Key not verified” (red)**  
  Connect the correct wallet/network. If your on-chain key changed, re-create/import the Read-Key to match.
- **“Permit (decrypt) · expired”**  
  Click **Decrypt & Load** again; the app will re-request the permit and proceed.
- **“No local wrapped Read-Key found…”**  
  Open **Manage Read-Key** and import/create the key again (you may have deleted it or switched browsers).
- **“Stale (other key)” on RAM**  
  Your in-RAM unlock belongs to a different public key. Re-enter password to unlock for the current one.
- **Nothing happens when clicking Decrypt**  
  Check the red status line under the password field; it will tell you whether to connect wallet, authorize, or manage the Read-Key first.
- **RPC offline / wrong chain**  
  The status line shows a **red** “✗ RPC offline …” message. Fix the RPC or switch the chain and retry **Connect**.

**PNG proposal**  
- ![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/troubleshooting-messages.png) — collage of red/green status lines.  
  _What to capture:_ “RPC offline…”, “Not verified”, “No local wrapped…”, and a green “Authorized & unlocked”.

---

## 10) Best practices for customers

- **Back up your seed** offline. Treat it like a root credential.
- Use a **strong password** for the local encryption of the private key.
- Prefer one browser profile per operator; avoid sharing profiles.
- If you step away, simply **close the decrypt dialog** — the Read-Key locks again shortly anyway.
- For operations requiring many decrypts, do them within a single **5-minute window** after Authorize & Unlock.

---

## 11) Quick glossary

- **Read-Key**: Asymmetric key pair to encrypt/decrypt your rules.  
- **Public key (on-chain)**: Published so senders can encrypt for your contract.  
- **Private key (local)**: Encrypted with your password; never leaves your browser.  
- **Permit**: Short-lived wallet signature that authorizes sensitive actions.  
- **RAM unlock**: Temporary in-memory decryption of the private key (≈5 minutes).

---

### Need help?
If something doesn’t look right (verification stays red, RPC shows offline, or decryption won’t start), look at the **status line** under the password field — it tells you what’s missing. Otherwise, contact support with a screenshot of the dialog and the status line.

---

> **Note on screenshots**: Replace the `PNG:` links with your own images. Aim for high-contrast captures with the relevant badges, buttons, and status messages clearly visible.
