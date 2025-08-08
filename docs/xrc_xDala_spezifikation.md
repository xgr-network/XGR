### 🔄 Komponenten der xDaLa-Engine

```
🏉 xgr_validateDataTransfer   ◀︍︍︍ Initialer Aufruf
└──────────────────────────────┐
           │
           ▼
   🏢 XRC-729        
     (Orchestrierung)  
   └───────┐
          │ (stepId)
          ▼
     📄 XRC-137 A    ◀◀◀◀◀◀◀◀◀◀◀◀◀◀◀◀┐
     └─────┐             │
          ▼             │
  [isValid = true/false]    │
          │             │
   ├─────────────────┐     │
   │                     │     │
   ▼                     ▼     │
onValid                onInvalid     │
   │                       │      │
   ▼                       │      │
📄 XRC-137 B            │      │
                         └──────────────────────┘ Rücksprung
```

Das Validierungssystem basiert auf drei eng verzahnten Komponenten:

- **XRC-137** beschreibt einzelne Validierungsregeln in deklarativer Form (z. B. Preis prüfen, Guthaben abgleichen). Diese Regeln nutzen externe API-Calls und Smart-Contract-Lesefunktionen, um ein valides oder ungültiges Ergebnis zu bestimmen.

- **XRC-729** strukturiert mehrere XRC-137-Instanzen zu komplexen Abläufen. Es definiert, was bei Erfolg oder Misserfolg der einzelnen Validierung passieren soll und in welcher Reihenfolge die Schritte abgearbeitet werden.

- `xgr_validateDataTransfer` ist der zentrale RPC-Endpunkt, der eine XRC-729-Kette sequenziell durchläuft. Dabei werden die XRC-137-Regeln nacheinander interpretiert, die jeweiligen Ausgänge verarbeitet und gegebenenfalls Ausführungsverträge gestartet – solange Gas verfügbar ist oder die Kette nicht abbricht.

---

## 🔷 Komponente: XRC-137 – Rules-as-Contract (deklariertes Validierungsmodul)

### 🧱 Struktur (JSON-basiert – inkl. Smart-Contract-Read)

```json
{
  "payload": {
    "Wallet": { "type": "string", "optional": false },
    "ProduktID": { "type": "string", "optional": false }
  },
  "encryptedPayload": {
    "IBAN": { "type": "string", "optional": false }
  },
  "apiCalls": [
    {
      "name": "ProduktPreis",
      "apiUrl": "https://api.shop123.de/preis?produktId=[ProduktID]",
      "default": 0,
      "useDefaultOnError": true,
      "timeoutMs": 3000
    }
  ],
  "contractReads": [
    {
      "name": "WalletBalance",
      "contract": "0xABCDEF0123456789",
      "method": "balanceOf",
      "params": ["[Wallet]"],
      "default": 0,
      "useDefaultOnError": true
    }
  ],
  "rules": [
    { "expression": "[ProduktPreis] > 0" },
    { "expression": "[WalletBalance] >= [ProduktPreis]" }
  ],
  "onValid": {
    "waitMs": 1000,
    "params": {
      "processId": "[prozess_id]",
      "payload": {
        "produktId": "[ProduktID]",
        "preis": "[ProduktPreis]"
      }
    }
  },
  "onInvalid": {
    "waitMs": 1000,
    "params": {
      "processId": "[prozess_id]",
      "payload": {
        "error": "Wallet enthält nicht genug Token oder Produkt ungültig"
      }
    }
  }
}
```

### 🔁 Ablauf:

1. XRC-137 wird **nicht direkt ausgeführt**, sondern durch die Engine interpretiert.
2. Die Engine (`xgr_validateDataTransfer`) liest:
   - Eingaben aus `payload` (z. B. Wallet, Produkt-ID)
   - verschlüsselte Eingaben aus `encryptedPayload` (→ `decryption`, 30.000 Gas)
   - API-Aufrufe (Produktpreis extern)
   - Smart-Contract-Reads (z. B. `balanceOf`)
   - Regeln zur Prüfung
3. Ergebnis ist ein Boolean: `isValid`
4. **Das Verhalten bei Gültigkeit oder Ungültigkeit** (`onValid` / `onInvalid`) wird direkt innerhalb der Loop von `xgr_validateDataTransfer` abgehandelt.
5. Auch im Fall von `onInvalid` wird eine Transaktion erzeugt. Diese wird jedoch kontrolliert \*\*mit \*\*\`\` zurückgewiesen, verursacht aber **bewusst Validierungskosten**.

### ⚠️ Entwicklerhinweis:

Wenn bei der Auswertung eines XRC-137 kritische Werte aus einem Smart Contract gelesen und danach im zugehörigen `executionContract` verändert werden, muss in `onValid.waitMs` oder `onInvalid.waitMs` mindestens **2000 ms** gewartet werden. Grund: Der nächste `contractRead` darf nicht auf einen noch unbestätigten Block zugreifen, um Konsistenzfehler zu vermeiden.

---

## 🔷 Komponente: XRC-729 – Orchestrierungsstruktur (Knotenpunkte)

### 📌 Zweck

Modularisierung und Steuerung einer Abfolge von Validierungsschritten (`XRC-137`) über eindeutige Bezeichner, inkl. Ausführung bei Erfolg/Misserfolg.

### 🧱 Struktur (vereinfachte Repräsentation):

```json
[
  {
    "id": "my_orchestration",
    "structure": {
      "step_0_priceCheck": {
        "rule": "0xRULE_ADDRESS_123",
        "executionContract": "0xCONTRACT_EXEC_1",
        "onValidNext": "step_1_store",
        "onInvalidNext": "step_2_notify"
      },
      "step_1_store": {
        "rule": "0xRULE_ADDRESS_456",
        "executionContract": "0xCONTRACT_EXEC_2",
        "onValidNext": null,
        "onInvalidNext": null
      },
      "step_2_notify": {
        "rule": "0xRULE_ADDRESS_789",
        "executionContract": "0xCONTRACT_EXEC_3",
        "onValidNext": null,
        "onInvalidNext": null
      }
    }
  }
]
```

### 📌 Hinweise

- Die **erste Rule** wird durch den initialen RPC-Aufruf (mit `stepId`) bestimmt
- Die `rule`-Felder enthalten die **Smart-Contract-Adresse des jeweiligen XRC-137**
- `executionContract` beschreibt den aufzurufenden Contract zur Ausführung nach Regelprüfung
- `onValidNext` und `onInvalidNext` referenzieren den nächsten Schritt per `stepId`
- Alle Bezeichner (`step_0_x`) sind frei wählbar, aber eindeutig
- Die Engine hält pro Nutzer **eine XRC-729 Instanz**, in der mehrere Orchestrierungen (`id`) verwaltet werden
- Es gibt **keinen festen Startschritt** – der Einstiegspunkt ergibt sich **aus dem initialen RPC-Aufruf**, nicht aus einer definierten Startmarkierung
- Die Struktur kann zyklisch sein, wenn gewünscht (z. B. periodisches Triggern bei Feeds)
- Es ist erlaubt, mehrere gleichzeitige Validierungspfade oder rekursive Konstrukte zu modellieren
- **Endlosschleifen sind prinzipiell erlaubt.** Die Validierung endet automatisch, wenn das zugewiesene Gas-Limit aufgebraucht ist.

---

## ✩️ RPC-Spezifikation: `xgr_validateDataTransfer`

### 📌 Zweck

Der zentrale Aufruf zur Verarbeitung einer vollständigen Validierungskette innerhalb einer XRC-729-Orchestrierung. Alle Schritte werden sequenziell in einer einzigen Ausführung durchlaufen.

### 🧱 Struktur: Eingabeparameter

```json
{
  "orchestration": "0xOrchestrationContract",
  "stepId": "step_0_priceCheck",
  "payload": {
    "IBAN": "DE28243423420012345600"
  },
  "encryption": false,
  "validatorKey": "0x...",
  "recipientKey": "0x...",
  "senderKey": "0x..."
}
```

Alternativ bei verschlüsselten Eingaben:

```json
{
  "orchestration": "0xOrchestrationContract",
  "stepId": "step_0_priceCheck",
  "encryptedPayload": "0xABC123...",
  "encryption": true,
  "validatorKey": "0x...",
  "recipientKey": "0x...",
  "senderKey": "0x..."
}
```

➡️ Ergebnis der Entschlüsselung wird im Engine-Modul als `inputs.decryption` gespeichert und wie normale Inputs verarbeitet.

### 🔁 Ablauf intern (Loop-basiert)

```ts
let currentStep = input.stepId;
let resultLog = [];
let processId = generateProcessId(...);

while (currentStep) {
  // 1. Hole Regel (XRC-137 Contract)
  // 2. Zerlege Regelstruktur in Teilkomponenten (→ modularer Parser)
  // 3. Führe API-Calls & ContractReads durch
  // 4. Evaluiere Regeln → isValid
  // 5. Logge Ergebnis (optional)
  // 6. Führe zugehörigen executionContract aus (wenn definiert)
  // 7. Warte `waitMs` aus onValid/onInvalid
  // 8. Gehe zu nextStep → currentStep = onValidNext / onInvalidNext
}

return {
  processId,
  finalResult,
  executedSteps: resultLog
};
```

### 📤 Rückgabe (Beispiel)

```json
{
  "processId": "0xHASH456...",
  "executedSteps": [
    { "step": "step_0_priceCheck", "isValid": true },
    { "step": "step_1_store", "isValid": true }
  ],
  "finalResult": true
}
```

### 📌 Hinweise

- Der gesamte Ablauf erfolgt **synchron im selben RPC-Kontext**
- Die Engine verhält sich wie ein **TaskHandler**, der Regelketten vollständig abarbeitet
- Es existiert **kein festes Limit für Schleifendurchläufe** – Schleifen stoppen automatisch bei Erreichen des Gaslimits oder bei fehlenden nextStep
- Die Inputs bestehen aus Klartext (`payload`) und/oder entschlüsseltem Inhalt (`encryptedPayload`) – beide werden gleichwertig genutzt
- Die Rule Engine kann auf alle Teilbereiche zugreifen: `payload`, `apiResults`, `contractReads`, `encryptedPayload`
- Bei `encryption: true` erfolgt die Entschlüsselung serverseitig vor Auswertung

---

## ✳️ Modulare Aufbereitung für Gasabschätzung und Validierung

Zur einheitlichen Behandlung beider RPCs `xgr_validateDataTransfer` und `xgr_getValidationGas` wird eine zentrale Parsing-Funktion bereitgestellt:

```go
type ParsedXRC137 struct {
  PlainInputs     []InputField
  EncryptedInputs []InputField
  APICalls        []APICall
  ContractReads   []ContractRead
  Expressions     []string
}

func ParseXRC137(rawJSON []byte) (*ParsedXRC137, error)
```

Diese Funktion wird sowohl in der Validierungslogik als auch bei der Gaskalkulation eingesetzt.

Folgefunktionen:

```go
func CalculateGas(parsed *ParsedXRC137) uint64 {
  // z. B. EncryptedInputs → +30_000, Regeln/Operators zählen usw.
}
```

Damit ist die gesamte Gasschätzung wiederverwendbar und konsistent zur realen Ausführung.

