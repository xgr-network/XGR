# XRC-137 – CEL-Only Spec (Unified Rules & API Extracts)

**Scope:** deterministisch, fetch-only `apiCalls`, einheitliche **CEL**-Ausdrücke in *allen* Kontexten (Rules, Extracts, Gas/Value, Args, Output-Payload). JSON-only Responses.

**Pipeline:** `Payload prüfen → apiCalls (fetch) → Rules (CEL) → Branch (onValid/onInvalid) → Execution (optional)`

## 1) Top-Level Schema (XRC-137)

```json
{
  "payload": { "<Key>": {"type": "string|number|bool|array|object", "optional": false } },
  "apiCalls": [ APICall, ... ],
  "contractReads": [ {"name": "<alias>", "save": false}, ... ],
  "rules": [ "<CEL>", "<CEL>", ... ],
  "onValid":  Outcome,
  "onInvalid": Outcome,
  "address": "0x..."
}
```

``: deklarative Pflichtfelder (nur Plain). Pflichtfelder müssen im finalen Inputs-Satz vorhanden/nicht‑leer sein.

``: Alias + optional `save`. Liefert deterministische Werte aus der Chain (Implementierungsspezifik).

``: Liste von **CEL-Strings**. Alle müssen `true` liefern.

`` (`onValid` / `onInvalid`):

```json
{
  "waitMs": 0,
  "waitUntilMs": 0,
  "params": { "payload": { "<outKey>": "<ExprOrTemplate>" } },
  "execution": Execution
}
```

`` (Output-Payload):

- **Genau** `"[Key]"` → direktes Mapping.
- String mit Platzhaltern **ohne Operatoren** → reine Placeholder-Ersetzung (kein CEL).
- Sonst → **CEL** (siehe §4) mit denselben Variablen/Funktionen wie `rules`.

---

## 2) APICall (fetch-only)

```json
APICall = {
  "name": "<id>",
  "method": "GET|POST|PUT|PATCH",
  "urlTemplate": "https://.../path?x=[key]",
  "headers": {"K": "V"},
  "bodyTemplate": "...",
  "contentType": "json",
  "extractMap": { "alias": "<CEL on resp>", "alias2": "<CEL>" },
  "defaults": { "alias": <any> }
}
```

**Semantik:**

- **Timeout je Call:** 8s. **Redirects:** ≤3. **Max Response:** 1 MB. **TLS ≥1.2**. IPv4 bevorzugt. HTTP/1.1 erzwungen.
- `contentType`: nur `json` (Response wird als JSON geparst; Array‑Root erlaubt).
- `` ist Pflicht. Jeder Alias wird nach `inputs[alias]` geschrieben.
- **Persistenz:** Extrakte werden **automatisch gespeichert**, sofern der resultierende Wert **skalar** ist (`string|number|bool|int`). Für Listen/Objekte vorher in CEL reduzieren/casten; sonst Fehler.
- **Defaults:** Wenn CEL‑Auswertung fehlschlägt → `defaults[alias]` verwenden; sonst Fehler.
- **Alias‑Regeln:** Regex `^[A-Za-z][A-Za-z0-9._-]{0,63}$`, nicht mit `_` oder `sys.` beginnen, global eindeutig.

### 2.1 Platzhalter in `urlTemplate`/`bodyTemplate`

- Syntax: `[key]` → Wert aus `inputs[key]`.
- URL: URL-encoded. Body: roh (du baust selbst gültiges JSON/Plain).
- Fehlender Key ⇒ Fehler. Escapes: `[[` → `[`, `]]` → `]`.

### 2.2 API-Attribute (Strict)

| Feld           | Typ                  | Default | Pflicht | Beschreibung                                                                                                |       |      |                                                                                                       |
| -------------- | -------------------- | ------- | ------- | ----------------------------------------------------------------------------------------------------------- | ----- | ---- | ----------------------------------------------------------------------------------------------------- |
| `name`         | string               | –       | nein    | Interner Bezeichner für Logs/Debugging. Keine Semantik für Auswertung.                                      |       |      |                                                                                                       |
| `method`       | "GET"                | "POST"  | "PUT"   | "PATCH"                                                                                                     | `GET` | nein | HTTP-Methode. **Nur fetchend/idempotent verwenden.** Für `POST/PUT/PATCH` ggf. `bodyTemplate` setzen. |
| `urlTemplate`  | string               | –       | **ja**  | Ziel-URL mit Platzhaltern `[key]`. URL-Encoding wird automatisch angewandt.                                 |       |      |                                                                                                       |
| `headers`      | map\<string,string>  | `{}`    | nein    | Feste Header. Platzhalter erlaubt. Sensible Werte werden geloggt **maskiert** (Engine-Policy).              |       |      |                                                                                                       |
| `bodyTemplate` | string               | –       | nein    | Request-Body für `POST/PUT/PATCH`. Platzhalter erlaubt. Serialisierung liegt beim Autor (Raw-String).       |       |      |                                                                                                       |
| `contentType`  | "json"               | `json`  | nein    | Erwarteter Response-Typ (Root-Array erlaubt).                                                               |       |      |                                                                                                       |
| `extractMap`   | map\<string, string> | –       | **ja**  | Alias → CEL (Kurzform). Schreibt Werte nach `inputs[alias]` und persistiert sie automatisch, sofern skalar. |       |      |                                                                                                       |
| `defaults`     | map\<string, any>    | `{}`    | nein    | Fallback pro Alias bei Eval-Fehler des jeweiligen Extracts.                                                 |       |      |                                                                                                       |

---

## 3) Rules (CEL)

- Typ: **Array von Strings**; jeder String ist ein **CEL-Ausdruck** über deine **Input-Keys**.
- Schreibweise mit Platzhalter-Klammern: `[Key]` wird intern zu CEL-Ident `Key` umgeschrieben.
- **Bewertung:** Alle `rules[i]` müssen `true` liefern. Fehlende Keys ⇒ Ausdruck wird als `false` bewertet (kein Fehler). Max Länge pro Expr: 1024 Zeichen. Per-Expr-Timeout: 25 ms.

**Beispiele:**

- `"[AmountA] > 0"`
- `"[AmountA] + [AmountB] > [Threshold]"`
- `"[RecipientIBAN].startsWith('GH') == true"`

---

## 4) CEL – Syntax & Funktionen (in allen Kontexten)

### 4.1 Grundsyntax

- Operatoren: `+ - * / %`, `== != < <= > >=`, `&& || !`, Ternary `cond ? a : b`.
- Zugriff: `obj.field`, `map["key"]`, `list[0]`.
- Casts: `double(x)`, `int(x)`, `string(x)`, `bool(x)`.

### 4.2 Listen-Makros (CEL)

- `list.map(x, expr)`
- `list.filter(x, predicate)`
- `list.exists(x, predicate)` · `list.exists_one(x, predicate)` · `list.all(x, predicate)`

### 4.3 XGR-Helper (zusätzlich verfügbar)

- `max(list<dyn>) -> double`
- `min(list<dyn>) -> double`
- `sum(list<dyn>) -> double`
- `avg(list<dyn>) -> double`
- `join(list<dyn>, sep) -> string`
- `unique(list<dyn>) -> list<dyn>`

### 4.4 Variablen je Kontext

- **extractMap:** eine Variable `resp` (parsed JSON der HTTP-Response).
- **rules**, **execution.args**, **gas.limitExpr**, **execution.valueExpr**, **Output-Payload**: Variablen sind deine **Input-Keys** (ohne Klammern) sowie optional `pid`.

**Beispiele (extractMap)**

- `double(resp.quote.price.value)`
- `max(resp.quote.venues.map(v, double(v.price.value)))`
- `resp.quote.venues.filter(v, double(v.price.value) == max(resp.quote.venues.map(x, double(x.price.value)))).map(v, v.name)[0]`

**Beispiele (Rules/Args/Gas/Value/Output):**

- `"[AmountA] > 0 && [q.price] > 0"`
- Gas: `"220000 + 50000"`
- Arg: `"string([AmountA])"`
- Output: `"[AmountA]-[AmountB]"` oder komplex als CEL.

---

## 5) Execution

```json
Execution = {
  "to": "0x...",
  "function": "setMessage(string)",
  "args": [ "<ExprOrLiteral>", ... ],
  "valueExpr": "<CEL>",
  "gas": { "limit": 150000, "limitExpr": "<CEL>", "cap": 220000 }
}
```

**Auflösung:**

- `gas.limitExpr` hat Vorrang vor `gas.limit`. `cap` begrenzt den resultierenden `limit`.
- `args[i]` werden jeweils als CEL ausgewertet und anschließend in den ABI-Typ der Signatur gecastet.
- `valueExpr` wird in Wei umgewandelt (Ganzzahl ≥0).

Fehlerfälle: fehlender/ungültiger `to`, Argumentanzahl ≠ Signatur, nicht castbare Werte, Gaslimit=0 bei vorhandenem `to`.

---

## 6) Required Inputs & Validierung

- Aus `payload` definierte Pflichtfelder müssen **vor** Rule-Eval vorhanden sein (nicht `nil`, nicht leerer String/Array/Map).
- `rules`: Alle müssen `true` sein, sonst `onInvalid`.

---

## 7) Receipt & Speicherung

- **APISaves**: alle `extractMap`-Aliasse (automatisch), **nur skalare Werte**. Bei Fehlern greifen `defaults` (falls gesetzt).
- **ContractSaves**: alle `contractReads` mit `save:true`.
- **PayloadAll**: finale Plain-Payload (ohne API-/Contract-Werte) nach Outcome-Resolving.
- Optionale **Verschlüsselung** der Receipt-Logs (Engine/Chain-spezifisch).

---

## 8) Limits & Sicherheit

- `apiCalls` pro XRC-137: Empfehlung ≤50.
- HTTP: Timeout je Call 8s, Redirects ≤3, Response ≤1MB, TLS ≥1.2.
- Header-Redaction für Secrets empfohlen (Engine-Policy).
- Host-Allowlist: Engine-Policy; default offen (konfigurierbar).

---

## 9) Fehlerbehandlung (Auszug)

- Platzhalter: ungültiger Key / fehlender Key.
- HTTP: Status ≠ 2xx, Non‑JSON, Timeout, Größe > Limit.
- `extractMap`: leerer Ausdruck, Eval‑Fehler ohne `defaults`, nicht‑skalares Ergebnis (ohne Reduktion).
- `rules`: Syntaxfehler, Non‑Boolean‑Result, Timeout, Expr > 1024 Zeichen.
- Execution: invalides Ziel, ABI‑Mismatch, Gaslimit 0 trotz Call, Cast‑Fehler.
- Output‑Payload: fehlende Keys, ungültige Template‑Ersetzung, Auswertungsfehler.

---

## 10) Beispiele

### 10.1 Quote mit Aggregaten (GET)

```json
{
  "name": "test-quote",
  "method": "GET",
  "urlTemplate": "https://api.test.xgr.network/quote/AAPL",
  "contentType": "json",
  "headers": {"Accept": "application/json"},
  "extractMap": {
    "q.symbol": "resp.quote.symbol",
    "q.price":  "double(resp.quote.price.value)",
    "q.bid":    "double(resp.quote.bid.value)",
    "q.ask":    "double(resp.quote.ask.value)",
    "q.ts":     "int(resp.quote.meta.ts)",
    "q.venue_best_px":   "max(resp.quote.venues.map(v, double(v.price.value)))",
    "q.venue_best_name": "resp.quote.venues.filter(v, double(v.price.value) == max(resp.quote.venues.map(x, double(x.price.value)))).map(v, v.name)[0]"
  },
  "defaults": {"q.price":0, "q.bid":0, "q.ask":0}
}
```

### 10.2 Komplettes XRC-137 (Ausschnitt)

```json
{
  "payload": {
    "AmountA": {"type":"number","optional":false},
    "AmountB": {"type":"number","optional":false}
  },
  "apiCalls": [ { /* see 10.1 */ } ],
  "contractReads": [],
  "rules": [
    "[AmountA] > 0",
    "[AmountB] > 0",
    "[q.price] > 0"
  ],
  "onValid": {
    "waitMs": 50000,
    "params": {"payload": {
      "AmountA": "[AmountA]-[AmountB]",
      "AmountB": "[AmountB]",
      "fromApi": "[q.symbol]"
    }},
    "execution": {
      "to": "0x7863b2E0Cb04102bc3758C8A70aC88512B46477C",
      "function": "setMessage(string)",
      "args": ["string([AmountA])"],
      "valueExpr": null,
      "gas": {"limit":150000, "limitExpr":"220000 + 50000", "cap":220000}
    }
  },
  "onInvalid": {
    "waitMs": 1000,
    "params": {"payload": {"memo":"invalid-path","error":"Amount"}},
    "execution": {
      "to": "0x7863b2E0Cb04102bc3758C8A70aC88512B46477C",
      "function": "setMessage(string)",
      "args": ["not enough balance"],
      "gas": {"limit":90000, "cap":120000}
    }
  }
}
```

---

## 11) Best Practices

- Aliasse sprechend und stabil benennen (`quote.price`, `fx.rate`).
- Frühe Reduktion auf **Skalare**, da nur skalare Ergebnisse persistiert werden.
- `waitUntilMs` für deterministische Verzögerungen bevorzugen (UTC-Epochenzeit).
- Gaslimit via einfacher Formel (`base + delta`) berechnen und mit `cap` begrenzen.
- Responses serverseitig klein halten (Query-Filter/Fields).

