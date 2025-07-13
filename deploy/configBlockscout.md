## 📘 BlockScout Deployment & Betrieb XGRChain

### 🧰 Voraussetzungen

* **Elixir** >= 1.17
* **Erlang/OTP** passend zu Elixir (z. B. OTP 26)
* **Node.js** = 18 (mit `nvm` empfohlen)
* **PostgreSQL** 14+
* **Ubuntu-ähnliches System mit Git, Curl, Build-Essentials**

---

## 📦 Deployment Schritte

### 🔧 1. Node.js einrichten

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
source ~/.bashrc
nvm install 18
nvm use 18
nvm alias default 18
```

### 🔧 2. Elixir & Abhängigkeiten installieren

```bash
sudo apt update && sudo apt install -y curl git build-essential libssl-dev libncurses5-dev inotify-tools postgresql postgresql-contrib
```

> Elixir + Erlang installierst du idealerweise über `asdf` oder `kiex` oder direkt via `.deb`

---

### 🗃️ 3. Datenbank vorbereiten

```bash
sudo -u postgres psql
CREATE USER blockscout WITH PASSWORD 'blockscout';
CREATE DATABASE blockscout OWNER blockscout;
\q
```

Konfiguriere die Datenbankverbindung in `apps/explorer/config/dev.secret.exs` bzw. `prod.secret.exs`.

---

### 🚧 4. Assets bauen (nach jedem `git pull` oder UI-Änderungen)

```bash
cd apps/block_scout_web/assets
npm install
npm run deploy
cd ../../../
mix phx.digest
```

> Dies erzeugt `priv/static` und den Digest für die Weboberfläche

---

### 🚀 5. Dev-Start (nur Web-Oberfläche)

```bash
iex -S mix phx.server
```

→ Achtung: Das startet nur `block_scout_web`, nicht `explorer`, `indexer` etc.

---

### 🏗️ 6. Vollständiger Production-Build & Start (simuliertes Deployment)

```bash
export MIX_ENV=prod
mix deps.get --only prod
mix compile
npm --prefix apps/block_scout_web/assets install
npm --prefix apps/block_scout_web/assets run deploy
mix phx.digest
mix release
```

Dann starten mit:

```bash
_build/prod/rel/blockscout/bin/blockscout start
```

→ Damit läuft der Prozess im Hintergrund (nicht `strg+c`-anfällig)

Oder interaktiv mit Logs:

```bash
_build/prod/rel/blockscout/bin/blockscout start_iex
```

→ Kann mit `strg+c` beendet werden

→ Stoppen mit:

```bash
_build/prod/rel/blockscout/bin/blockscout stop
```

---

## ⚙️ Nützliche Konfigs

### 🔁 Batch Size für Balance-Fetching

In `config/dev.exs` oder `config/prod.exs`:

```elixir
config :indexer,
  coin_balance_catchup_batch_size: 20
```

### ❌ Preisabfrage deaktivieren (XGR ist nicht gelistet)

```elixir
config :explorer,
  disable_price_fetching: true
```

---

## 🖥️ Skript: Frontend neu bauen

Speichere z. B. als `scripts/deploy_frontend.sh`

```bash
#!/bin/bash
set -e
cd apps/block_scout_web/assets
npm install
npm run deploy
cd ../../../
mix phx.digest
```

Ausführbar machen:

```bash
chmod +x scripts/deploy_frontend.sh
```

---

## 📂 Wichtig: Dateistruktur

```plaintext
apps/
├── block_scout_web/      # Webserver/UI
│   └── assets/           # JS, CSS
├── explorer/             # EVM-Indexer
├── indexer/              # Token balances etc
├── ethereum_jsonrpc/     # RPC-Anbindung
config/                   # Umgebungs-Configs
├── dev.exs
├── prod.exs
├── runtime.exs
```

---

## 📁 Git-Strategie für XGRScan

Da du das Original-Repo via `git clone` gezogen hast, solltest du dir ein **eigenes Remote-Repo anlegen**, damit du volle Kontrolle hast:

```bash
# Neues GitHub-Repo anlegen (z. B. github.com/xgreen-project/xgrscan.git)
cd /home/xgradmin/xgrscan

# Falls schon gesetzt:
git remote remove origin

# Neues Remote setzen:
git remote add origin git@github.com:xgreen-project/xgrscan.git

# Erstes Push-Kommando (falls Branch 'master'):
git push -u origin master
```

> Vorteil: Du kannst jederzeit Updates von Blockscout via `git fetch upstream` einziehen, aber deine Änderungen sicher versionieren.

Optional kannst du `blockscout/blockscout` als Upstream behalten:

```bash
git remote add upstream https://github.com/blockscout/blockscout.git
```

Dann später z. B.:

```bash
git fetch upstream
git merge upstream/master
```
