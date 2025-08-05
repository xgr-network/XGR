## Grundlagen der EVM-Datenhaltung – Mentoring-Übersicht

### 1. Wo werden Daten gespeichert?

In jeder EVM-Chain (Ethereum, Polygon, BSC, XGRChain etc.) wird der gesamte „Weltzustand“ in einer Reihe von *Merkle-Patricia-Tries* gespeichert:

* **Global State Trie** → enthält alle Accounts (Wallets & Contracts)
* **Storage Trie** → für jeden Contract, enthält seine Variablen
* **Transaction Trie** → alle Transaktionen eines Blocks
* **Receipt Trie** → alle Receipts eines Blocks (Logs etc.)

---

### 2. Was ist ein Account in der EVM?

Zwei Typen:

* **Externally Owned Account (EOA)** = normale Wallet (Adresse, ETH-Balance, Nonce)
* **Contract Account** = Smart Contract mit eigenem Code + Speicher

Jeder Account hat:

* `address` (Hash des Public Keys bzw. Contract-Adresse)
* `balance` (z. B. ETH, XGR…)
* `nonce` (Anzahl gesendeter Transaktionen)
* `codeHash` (nur bei Contracts)
* `storageRoot` (Root des Storage-Tries, nur bei Contracts)

---

### 3. Was ist ein Smart Contract Speicher?

→ Ein Contract hat einen eigenen **Storage Trie**, in dem Variablen gespeichert sind.
Wichtig:

* Jeder Slot ist 32 Byte groß
* Die Position basiert auf dem Slot-Index der Variable im Solidity-Layout (z. B. Slot 0, Slot 1 …)
* Mappings und Arrays verwenden Hashes zur Adressberechnung (z. B. `keccak256(key . slot)`)

#### Beispiel: Einfacher Storage Trie

Angenommen ein Contract speichert:

```solidity
uint256 a = 42;         // Slot 0
mapping(address => uint256) b;  // Slot 1
```

Dann ist:

* `a` unter `keccak256(0)` gespeichert → Wert: `0x2a`
* `b[0xABC...]` unter `keccak256(pad(0xABC...) ++ 1)` gespeichert

Jeder dieser Schlüssel-Wert-Pfade wird im Storage Trie des Contracts abgelegt. Nur geänderte Werte erzeugen neue Trie-Knoten.

---

### 4. Was steckt in einem Block?

#### A. Block Header

Enthält u. a.:

* `parentHash` – Verweis auf vorherigen Block
* `stateRoot` – Hash des Merkle-Root vom Weltzustand nach dem Block
* `transactionsRoot` – Root-Hash des Transaktionstries
* `receiptsRoot` – Root-Hash der Receipts
* `timestamp`, `number`, `gasUsed`, `gasLimit`, `baseFee` …

#### B. Transactions

Liste aller Transaktionen mit:

* Sender, Empfänger, Gas, Payload (data), Signatur

#### C. Receipts

Jede Receipt enthält:

* `status` (success/fail)
* `cumulativeGasUsed`
* `logs` (Events)
* `logsBloom` (Filter)

---

### 5. Was ist ein Merkle(-Patricia)-Trie?

Ein effizienter Datenbaum mit:

* **Schlüssel-Wert-Paaren**, z. B. `address → accountData`
* Jeder Knoten ist gehasht → Root-Hash repräsentiert gesamte Struktur
* Änderungen propagieren nur bis zur Root → effizient & manipulationssicher

#### Beispiel: Global State Trie

Wenn sich eine Wallet-Balance ändert, dann:

* wird nur der Pfad `keccak256(walletAdresse)` im Trie angepasst
* neue Hashes entstehen entlang des Pfades nach oben
* der neue `stateRoot` ergibt sich aus neuem Root-Hash des Tries

Vergangenheit bleibt rekonstruierbar, da alter Pfad (alte Hashes) durch den alten Block referenziert ist.

→ Die Trie-Pfade sind **nicht willkürlich**, sondern geordnet nach den Hex-Nibbles des Hashes `keccak256(address)`. Jeder Branch-Node hat maximal **16 Kinder** (`0x0`–`0xf`). Man „biegt also richtig ab“, indem man der Hashstruktur folgt. Es ist wie eine Bibliothek mit Regalen A–F, sortiert nach Präfixen. Man traversiert immer nur **einen** Pfad durch den Trie, kein Suchen notwendig.

→ Wenn sich Daten verändern, entstehen **nur entlang dieses Pfades neue Knoten**. Alle anderen Pfade im Trie bleiben identisch. Es handelt sich um eine **persistente Datenstruktur**.

→ Dabei werden gemeinsam genutzte Präfixe im Trie als sog. **Extension Nodes** komprimiert gespeichert. So können viele Keys, die z. B. mit `0xabc...` beginnen, gemeinsam über eine kurze Teilstruktur referenziert werden. Das entspricht einer Art „bibliografischer Ordnung“ – strukturell effizient.

→ Jeder Knoten (Branch, Extension, Leaf) ist eindeutig referenzierbar über seinen **Hash**, der sich aus seinen **Kind-Hashes ableitet**.

Beispiel:

* `H_leaf = keccak256(RLP(encodedPath, value))`
* `H_branch = keccak256(RLP([child_0, ..., child_15, optional_value]))`
* → Ändert sich ein Leaf, ändert sich der Pfad nach oben bis zur Root

---

### 6. Wie verändern sich Daten mit der Zeit?

* Jeder Block verändert den `stateRoot`, also den Weltzustand
* Smart-Contract-Variablen ändern nur, wenn sie z. B. via `setX()` angepasst werden
* Wallet-Balances ändern sich durch Transaktionen

→ Änderungen erzeugen **neue Knoten** im Trie (Persistent Data Structure), alte bleiben erhalten. → Jeder Block zeigt auf seinen **eigenen Trie-Zustand** über den `stateRoot` im Header.

Man kann sich das vorstellen wie einen Baum, bei dem jeder neue Ast nicht den ganzen Baum ersetzt, sondern nur Teilpfade neu erzeugt – die Wurzeln („roots“) ändern sich, aber frühere Pfade bleiben gültig.

---

### 7. Wie liest man historische Daten (Block X)?

Dazu brauchst du:

* `stateRoot` von Block X (steht im Header)
* Zugriff auf vollständige Trie-Struktur (z. B. mit Archivnode)

Du kannst dann z. B.:

* Account-Balance zum Zeitpunkt X rekonstruieren
* Contract-Variable zum Zeitpunkt X lesen
* Logs aus Receipts abfragen

Archivnodes halten Snapshots oder komplette Trie-Historien, damit man beliebige `stateRoot`s wieder traversieren kann.

#### Beispiel: Historische Wallet-Balance lesen

1. Hole dir den `stateRoot` aus Block 15\_000\_000
2. Traversiere den Global State Trie mit `keccak256(walletAdresse)` ab diesem Root
3. Folge den Hex-Nibbles des Hashes (z. B. `['d', 'e', '1', 'c', '4', ...]`) entlang der Branches
4. Extrahiere die Balance → So bekommst du exakt den Zustand zu diesem Zeitpunkt

---

### 8. Skalierung der Datenstruktur

* Die Trie-Struktur wächst mit der Anzahl der Accounts, Contracts und geänderten Variablen
* Trotzdem bleibt die Zugriffskomplexität konstant: **maximal 64 Schritte (Hex-Nibbles)** für einen Key
* → Der Zugriff auf eine Wallet oder Contract-Variable ist **logarithmisch effizient**, nicht linear

Egal ob 1.000 oder 100 Mio. Accounts – durch die Trie-Struktur brauchst du nur einen festen Schlüsselpfad entlang der Nibbles abzulaufen.

Nur die **geänderten Pfade werden neu gehasht und gespeichert**, alle anderen Referenzen bleiben bestehen.

→ Dadurch ist die EVM trotz wachsender States **nicht grundsätzlich langsamer** im Datenzugriff – die Struktur bleibt tief, aber schmal.

---

### 9. Wie wird ein Leaf im Trie referenziert?

Wenn du nach einem Account oder Contract suchst:

* Du kennst die Adresse → `keccak256(adresse)` = Trie-Pfad
* Du traversierst entlang der Hex-Nibbles diesen Pfad
* Am Ende erreichst du den **Leaf Node** mit `encodedPath` = Restpfad, `value` = Account- oder Contract-Daten
* Der Hash dieses Leafs wird gebildet als `keccak256(RLP(encodedPath, value))`
* Dieser Hash ist eindeutig – und wird im Parent-Knoten (Branch/Extension) gespeichert

→ **Fazit:** Du traversierst den Trie **mit dem Key**, aber die Knoten selbst sind über den Hash von `(Key + Value)` referenziert.

→ Dadurch ist jeder Leaf-Knoten **eindeutig identifizierbar und referenzierbar**, obwohl sich mehrere Accounts einen Teilpfad im Trie teilen können.

→ Jeder Branch-Knoten speichert intern einen Zeiger auf seine Kinder – sortiert nach Hex-Nibble (0–f). Die **Pfadtiefe** entspricht der gemeinsamen Länge der Hash-Präfixe.

→ Eine Änderung in einem Leaf verändert alle Hashes bis zur Root – **jeder Knoten-Hash ist mittelbar abhängig von allen Kind-Hashes**. Das macht die Struktur sicher, nachvollziehbar und historisch rekonstruierbar.
