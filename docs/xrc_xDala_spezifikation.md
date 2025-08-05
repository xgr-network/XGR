### 🔄 Komponenten der xDaLa-Engine&#x20;

```text
┌────────────────────────────┐
│ xgr_validateDataTransfer   │◄──── Initialer Aufruf
└────────────┬───────────────┘
             │
             ▼
     ┌────────────────────┐
     │     XRC-729        │
     │  (Orchestrierung)  │
     └────────┬───────────┘
              │ (stepId)
              ▼
         ┌──────────────┐
         │ XRC-137 A    │◄────────────┐
         └────┬─────────┘             │
              ▼                       │
      [isValid = true/false]          │
              │                       │
      ┌───────┴─────────────┐         │
      │                     │         │
      ▼                     ▼         │
 onValid                onInvalid     │
   │                       │          │
   ▼                       │          │
┌──────────────┐           │          │
│ XRC-137 B    │           │          │
└──────────────┘           │          │
                           └──────────┘ Rücksprung
```



Das Validierungssystem basiert auf drei eng verzahnten Komponenten:

- **XRC-137** beschreibt einzelne Validierungsregeln in deklarativer Form (z. B. Preis prüfen, Guthaben abgleichen). Diese Regeln nutzen externe API-Calls und Smart-Contract-Lesefunktionen, um ein valides oder ungültiges Ergebnis zu bestimmen.

- **XRC-729** strukturiert mehrere XRC-137-Instanzen zu komplexen Abläufen. Es definiert, was bei Erfolg oder Misserfolg der einzelnen Validierung passieren soll und in welcher Reihenfolge die Schritte abgearbeitet werden.

- `` ist der zentrale RPC-Endpunkt, der eine XRC-729-Kette sequenziell durchläuft. Dabei werden die XRC-137-Regeln nacheinander interpretiert, die jeweiligen Ausgänge verarbeitet und gegebenenfalls Ausführungsverträge gestartet – solange Gas verfügbar ist oder die Kette nicht abbricht.

---

## 🔷 Komponente: XRC-137 – Rules-as-Contract (deklariertes Validierungsmodul)

### 🧱 Struktur (JSON-basiert – inkl. Smart-Contract-Read)

```json
{
  "inputs": [
    { "name": "Wallet", "type": "string", "optional": false },
    { "name": "ProduktID", "type": "string", "optional": false }
  ],
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
      "isFirst": false,
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
      "isFirst": false,
      "processId": "[prozess_id]",
      "payload": {
        "error": "Wallet enthält nicht genug Token oder Produkt ungültig"
      }
    }
  }
}
```

---

### 🔁 Ablauf:

1. XRC-137 wird **nicht direkt ausgeführt**, sondern durch die Engine interpretiert.
2. Die Engine (`xgr_validateDataTransfer`) liest:
   - Eingaben (z. B. Wallet, Produkt-ID)
   - API-Aufrufe (Produktpreis extern)
   - Smart-Contract-Reads (z. B. `balanceOf`)
   - Regeln zur Prüfung
3. Ergebnis ist ein Boolean: `isValid`
4. **Das Verhalten bei Gültigkeit oder Ungültigkeit (**`**, **`**) wird direkt innerhalb der Loop von ****\`\`**** abgehandelt.**
5. Auch im Fall von `onInvalid` wird eine Transaktion erzeugt. Diese wird jedoch kontrolliert **mit ****\`\`**** zurückgewiesen**, verursacht aber **bewusst Validierungskosten**.

### ⚠️ Entwicklerhinweis:

Wenn bei der Auswertung eines XRC-137 kritische Werte aus einem Smart Contract gelesen und danach im zugehörigen `executionContract` verändert werden, muss in `onValid.waitMs` oder `onInvalid.waitMs` mindestens **2000 ms** gewartet werden. Grund: Der nächste `contractRead` darf nicht auf einen noch unbestätigten Block zugreifen, um Konsistenzfehler zu vermeiden.

---

## 🔷 Komponente: XRC-729 – Orchestrierungsstruktur (Knotenpunkte)

### 📍 Zweck

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

## 🧩 RPC-Spezifikation: `xgr_validateDataTransfer`

### 📍 Zweck

Der zentrale Aufruf zur Verarbeitung einer vollständigen Validierungskette innerhalb einer XRC-729-Orchestrierung. Alle Schritte werden sequenziell in einer einzigen Ausführung durchlaufen.

### 🧱 Struktur: Eingabeparameter

```json
{
  "isFirst": true,
  "processId": "",  
  "orchestrationId": "my_orchestration",
  "stepId": "step_0_priceCheck",
  "inputs": {
    "Wallet": "0x1234...",
    "ProduktID": "ABC-123"
  }
}
```

### 🔁 Ablauf intern (Loop-basiert)

```ts
let currentStep = input.stepId;
let resultLog = [];

while (currentStep) {
  // 1. Hole Regel (XRC-137 Contract)
  // 2. Führe API-Calls & ContractReads durch
  // 3. Evaluiere Regeln → isValid
  // 4. Logge Ergebnis (optional)
  // 5. Führe zugehörigen executionContract aus (wenn definiert)
  // 6. Warte `waitMs` aus onValid/onInvalid
  // 7. Gehe zu nextStep → currentStep = onValidNext / onInvalidNext
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

