## XGRChain Setup – Teil 2: Netzaufbau & Deployment

### ✨ Ziel

Dokumentation der einzelnen Schritte nach dem Build bis zum funktionierenden Mehrknoten-Netzwerk mit IBFT-Konsens.

---

### ᵀ. 📂 Allgemeine Verzeichnisstruktur pro Node

```bash
/home/xgradmin/
├── xgrmain/                      # Laufzeitumgebung aller Nodes
│   ├── node-1/
│   │   ├── data/                # Konsensdaten, Blocks, Chain-State
│   │   └── xgrchain             # Binary & Genesis (ausgerollt)
│   ├── node-2/
│   └── ...
├── xgrchain-src/                # Nur auf Mainnode: Quellcode & Build
│   ├── XGR/                     # Fork von Polygon Edge
│   └── build/xgrchain           # Gebaute Binary
├── scripts/                     # gen_secrets.sh, creategenesis.sh, checknodes.sh
└── Makefile                     # make xgr-deploy all etc.
```

---

### ᵁ. 🔐 Secrets erzeugen mit `gen_secrets.sh`

**Befehl:**

```bash
./scripts/gen_secrets.sh
```

**Was passiert:**

* Für jeden Validator-Node wird ein neuer Satz an:

  * ECDSA-Key (für Validator-Adresse)
  * BLS-Key (für IBFT)
  * LibP2P-Netzwerkschlüssel
    erzeugt und abgelegt unter:

```bash
xgrmain/node-1/consensus/
├── validator.key
├── validator.pub
├── bls.key
├── network.key
├── manifest.json  ✅ muss vorhanden sein!
```

> Falls `manifest.json` fehlt: Fehler beim Auslesen via `secrets output`

---

### ᵂ. 🔨 Genesis erzeugen mit `creategenesis.sh`

**Befehl:**

```bash
./scripts/creategenesis.sh
```

**Wichtig dabei:**

* Die Datei verwendet **Verzeichnisse der Validatoren** direkt (z.B. `./xgrmain/node-1/consensus/`)
* Der **Bootnode** muss korrekt gesetzt werden:

  ```
  /ip4/<IP>/tcp/1478/p2p/<PeerID>
  ```

  Dabei ist `<PeerID>` der **LibP2P Peer ID** aus dem Konsensverzeichnis:

  ```bash
  xgrchain secrets output --config ./consensus/manifest.json --node-id
  ```

Ergebnis: `genesis.json` im selben Verzeichnis

---

### ᵃ. 🚚 Verteilen auf alle Nodes via Makefile

**Befehl:**

```bash
make xgr-deploy all
```

**Was passiert:**

* Kopiert `xgrchain` Binary und `genesis.json` in alle `xgrmain/node-*/xgrchain/`
* Legt Symlink oder kopiert Binary in `/usr/local/bin/xgrchain`

---

### ᵄ. 🔍 Konsistenzprüfung mit `checknodes.sh`

**Befehl:**

```bash
./scripts/checknodes.sh
```

**Was wird geprüft:**

* Ob `genesis.json` auf allen Nodes identisch ist (Hashvergleich)
* Ob `/usr/local/bin/xgrchain` überall den gleichen Hash hat

---

### ᵅ. 🔄 Startbefehl pro Node

```bash
xgrchain server \
  --data-dir ./data \
  --grpc-address 0.0.0.0:9632 \
  --libp2p 0.0.0.0:1478 \
  --jsonrpc 0.0.0.0:8545
```

> ⚠️ Falls "validator key already initialized" kommt: Manifest.json oder Konsensverzeichnis prüfen

---

### ᵆ. ✉️ RPC-Tests per `curl`

**Peer Count (Anzahl aktiver Peers):**

```bash
curl -X POST http://<IP>:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

**Block-Höhe:**

```bash
curl -X POST http://<IP>:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

**Erwartet:**

* `peerCount` liefert mind. `0x1`
* `eth_blockNumber` sollte >0 sein, sobald Konsens funktioniert

---

Für morgen:

* ✍️ Erweiterung: Logs strukturieren
* ♻️ Cleanup-Skripte
* ⚖️ Optional: Autostart über Systemd vorbereiten
