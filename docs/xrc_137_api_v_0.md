# XRC-137 – API Calls v0.2 (Strict, Full Spec)

**Scope (v0.2):** JSON-only. Deterministisch. Keine Heuristiken. `apiCalls` dienen ausschließlich der **Datenbeschaffung** vor der Regelprüfung. Seiteneffekte (HTTP-Sends) sind in v0.2 **nicht Teil von \*\*\*\***\`\`.

**Pipeline:** `payload prüfen → apiCalls (fetch) → Regeln prüfen → Ausführung (außerhalb dieser Spec)`.

**Striktes Schema:** Unbekannte Felder → **Fehler**. In `apiCalls` ist `extractMap` **Pflicht** (kein `extract`/`saveAs`).

---

## 1) `apiCalls` – Schema (fetch-only)

Jedes Element in `apiCalls` ist ein Objekt:

| Feld           | Typ                            | Default | Beschreibung                                                                                                                             |         |       |                                                   |
| -------------- | ------------------------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------- | ----- | ------------------------------------------------- |
| `name`         | string                         | –       | Interner Bezeichner für Logs/Debugging.                                                                                                  |         |       |                                                   |
| `method`       | "GET"                          | "POST"  | "PUT"                                                                                                                                    | "PATCH" | `GET` | HTTP-Methode (nur fetchend/idempotent verwenden). |
| `urlTemplate`  | string                         | –       | URL mit Platzhaltern `[key]`.                                                                                                            |         |       |                                                   |
| `headers`      | map\<string,string>            | `{}`    | Feste Header (Platzhalter erlaubt). Sensibles wird geloggt **maskiert**.                                                                 |         |       |                                                   |
| `bodyTemplate` | string                         | –       | Body (bei POST/PUT/PATCH). Platzhalter erlaubt.                                                                                          |         |       |                                                   |
| `contentType`  | "json"                         | `json`  | Erwarteter Response-Typ; v0.2: **nur \*\*\*\***\`\`.                                                                                     |         |       |                                                   |
| `extractMap`   | map\<string, string \| object> | –       | **Pflicht.** Alias → (String‑Expr **oder** Objekt `{expr, save?}`). Schreibt Aliasse in `inputs`; `save` steuert Speicherung im Receipt. |         |       |                                                   |
| `defaults`     | map\<string,any>               | `{}`    | Defaultwerte pro **Alias-Key** (werden verwendet, wenn für den Alias kein Wert extrahiert werden kann).                                  |         |       |                                                   |

---

## 2) Platzhalter in Templates

**Syntax:** `[key]` → Wert aus `inputs[key]`.

- In `urlTemplate`: URL-encoded. In `bodyTemplate`: roh (JSON selbst bauen).
- Fehlender Key ⇒ Fehler.
- Escaping: `[[` → `[` , `]]` → `]`.
- Serialisierung: Zahl → Dezimal; Bool → `true/false`; Objekt/Array → JSON.
- Erlaubte Zeichen in Keys: `[a-zA-Z0-9._-]` (keine Leerzeichen).

---

## 3) Extract-Expressions (Pipeline)

**Form:** `JSONPath ( "|" Step )*`

### 3.1 JSONPath-Subset (v0.2)

- Root: `$`
- Child: `.name` oder `['name']`
- Wildcard: `*` (Objektwerte/Array-Items)
- Array-Index: `[0]`, `[-1]` (negativ = vom Ende)
- Filter: `[?( <predicate> )]` **nur auf Listen** (Array / Wildcard-Ergebnis)\
  `@` = aktuelles Element. Operatoren: `== != < <= > >=`\
  Funktionen: `startsWith(s)`, `endsWith(s)`, `contains(s)`\
  Existenz: `exists(@.field)`, `!exists(@.field)`

> Regel: Filter **nur** wenn der linke Teil eine Liste liefert. Auf Objekten/Skalaren nicht erlaubt.

**Klarstellung: Feldzugriff vs. Platzhalter**

- `.name` und `['name']` sind **JSONPath-Feldzugriffe** auf die **Response**.
- `['name']` adressiert den **literalen** Key – nötig bei Sonderzeichen, Leerzeichen, Punkten oder numerischem Beginn (z. B. `['price.value']`, `['weird key']`, `['0']`).
- `[key]` (ohne Anführungszeichen) ist **kein JSONPath**, sondern unser **Template‑Platzhalter** in `urlTemplate`/`bodyTemplate`. In Extract‑Expressions **nicht erlaubt**.
- Unterschied: `['0']` (Objektfeld mit Key "0") vs. `[0]` (Array‑Index 0).

**Mini‑Beispiele** Response:

```json
{
  "quote": { "name": "AAPL", "price.value": "214.02", "weird key": 7, "0": "zero" },
  "arr": [10, 11]
}
```

Zugriffe:

- `$.quote.name` ⟶ `"AAPL"`  (gleich wie `$.quote['name']`)
- `$.quote['price.value']` ⟶ `"214.02"`
- `$.quote['weird key']` ⟶ `7`
- `$.quote['0']` ⟶ `"zero"`
- `$.arr[0]` ⟶ `10`  (Array‑Index, nicht mit `['0']` verwechseln)

### 3.2 Steps (nach JSONPath)

**Reducer (Mehrtreffer → Einzelwert):**\
`first` · `last` · `one` (genau 1, sonst Fehler) · `nth(k)` · `sum` · `avg` · `min` · `max` · `count` · `join(sep)` · `unique`

**Cast (Typisierung):**\
`number` · `int` · `bool` · `string` · `object` · `array`

**Transforms:**\
`round(ndigits)` · `lower` · `upper` · `trim`

**Mehrtreffer-Policy:** Ohne Reducer bei >1 Treffer ⇒ **Fehler**. Ein Cast ist **kein** Reducer.

**Beispiele:**\
`$.quote.venues[?(@.name=='BATS')].price.value|first|number`\
`$.items[*].amount|sum|number`

---

## 3.3 `extractMap`: Kurzform/Langform & Receipt

- **Kurzform (String):** `"alias": "<Extract-Expression>"`\
  Entspricht intern `{ "expr": "<Extract-Expression>", "save": false }`.
- **Langform (Objekt):** `"alias": { "expr": "<Extract-Expression>", "save": <bool optional> }`\
  `save` Default = `false`.
- **Inputs:** Jeder Alias (egal ob Kurz- oder Langform) wird nach `inputs[alias]` geschrieben.
- **Receipt:** Nur Aliasse mit `save:true` erscheinen im Receipt (Key = Alias, Value = finaler Wert).\
  – Wenn kein Treffer und `defaults[alias]` existiert, wird **der Default** gespeichert.\
  – Für `save:true` muss der finale Wert **skalar** sein (`string|number|bool|int`); sonst Fehler (ggf. `|string` casten).

---

## 4) Schreiben in `inputs`

- Für jeden `extractMap`-Eintrag: `inputs[alias] = Wert`.
- **Receipt:** Speicherung gemäß `save:true` (siehe §3.3).
- **Eindeutige Benennung** liegt beim XRC-Autor direkt im Alias (z. B. `fx.rate`, `quote.ask`).
- **Alias-Regeln:**
  - Syntax: `^[A-Za-z][A-Za-z0-9._-]{0,63}$` (1–64 Zeichen, beginnt mit Buchstabe).
  - Eindeutigkeit: Aliasse müssen **über alle ****\`\`**** hinweg** eindeutig sein.
  - Case: **case-sensitiv**; Empfehlung: lowercase mit Punkten.
  - Reserviert/verboten: beginnend mit `_` oder `sys.`.
- **Kollisions-Policy:** Alias muss im Call eindeutig sein; Kollision **zwischen** Calls ⇒ **Fehler**.

---

## 5) Zahlenbehandlung

- Intern **Decimal bevorzugt** (Geld/Preise). Fallback Float64 (konfigurierbar) mit Warnung.
- `number`: Decimal-Parse; `int`: nur ganzzahlig (kein implizites Runden).
- `round(ndigits)`: Rundung **HALF\_UP**.
- **Receipt (bei ****\`\`****) – kanonische JSON-Zahlen:**
  - Typ: JSON-Number (kein String), **ohne Exponent**.
  - Format: optionales `-`, Ziffern; optional `.` + Dezimalteil.
  - Trailing-Zeros im Dezimalteil werden entfernt (`2.3000` → `2.3`, `2.0` → `2`).
  - Präzision: max. **38** signifikante Stellen, max. **18** Nachkommastellen.
  - Verboten: `NaN`, `Infinity`, `-Infinity`.

---

## 6) Fehler- & Default-Handling

Fehlerquellen: Timeout, HTTP-Status, Parsing, kein Treffer, Mehrtreffer, Cast-Fehler.

- **Kein Wert für Alias:** Wenn die Pfadauswertung 0 Treffer liefert, wird – falls vorhanden – `defaults[alias]` verwendet, sonst **Fehler**.
- **Mehrtreffer ohne Reducer:** **Fehler**.
- **Cast-/Transform-Fehler:** **Fehler**.

---

## 7) Sicherheit & Limits

- Host-Allowlist, TLS ≥ 1.2, Redirects ≤ 3.
- Log-Redaction: `Authorization`, `Cookie`, `X-Api-Key`.
- Max `apiCalls` pro XRC-137: 50 (konfigurierbar).
- Max Responsegröße: 1 MB.
- Timeout & Retry: engine-intern festgelegt (nicht konfigurierbar in `apiCalls`).
- Keine Seiteneffekte in `apiCalls` (v0.2).

---

## 8) Beispiele

### 8.1 Einfacher Fetch (ein Wert)

**Spec:**

```json
{
  "name": "fx_latest_single",
  "method": "GET",
  "urlTemplate": "https://api.exchangerate.host/latest?base=EUR&symbols=USD",
  "contentType": "json",
  "extractMap": { "fxRate": { "expr": "$.rates.USD|number", "save": true } }
}
```

**Beispiel-Response:**

```json
{
  "base": "EUR",
  "date": "2025-09-10",
  "rates": { "USD": 1.0875 }
}
```

### 8.2 Komplexe Antwort (Filter, Aggregat, Aliasse)

**Spec:**

```json
{
  "name": "quote_latest",
  "method": "GET",
  "urlTemplate": "https://api.example.com/quote?symbol=[sym]",
  "contentType": "json",
  "extractMap": {
    "quote.symbol": { "expr": "$.quote.symbol|string", "save": true },
    "quote.price":  { "expr": "$.quote.price.value|number", "save": true },
    "quote.bid":    { "expr": "$.quote.bid.value|number", "save": true },
    "quote.ask":    { "expr": "$.quote.ask.value|number", "save": true },
    "quote.bats":   "$.quote.venues[?(@.name=='BATS')].price.value|first|number",
    "quote.venues": { "expr": "$.quote.venues[*].name|unique|join(';')|string", "save": false },
    "quote.ts":     "$.quote.meta.ts|int"
  },
  "defaults": { "quote.venues": "" }
}
```

**Beispiel-Response:**

```json
{
  "quote": {
    "symbol": "AAPL",
    "price": { "value": "214.01", "ccy": "USD" },
    "bid":   { "value": "213.98" },
    "ask":   { "value": "214.04" },
    "venues": [
      { "id": "v1", "name": "XNAS", "price": { "value": "214.01" } },
      { "id": "v2", "name": "BATS", "price": { "value": "214.02" } }
    ],
    "meta": { "ts": 1725882000 }
  }
}
```

### 8.3 POST als fetch (Input raus, Score rein)

**Spec:**

```json
{
  "name": "risk_score",
  "method": "POST",
  "urlTemplate": "https://risk.example.com/score",
  "headers": { "Content-Type": "application/json" },
  "bodyTemplate": "{\"amount\": [AmountA], \"user\": \"[userId]\"}",
  "contentType": "json",
  "extractMap": { "risk.score": { "expr": "$.score|number", "save": true } }
}
```

**Beispiel-Response:**

```json
{ "score": "0.73" }
```

---

## 9) Validierung & Determinismus

- Keine „Best Guess“-Extraktion. Jeder Pfad eindeutig oder mit Reducer.
- Reihenfolgeabhängige Reducer (`first/last/nth`) sind deterministisch bzgl. API-Reihenfolge.
- Treffer=0 → Fehler; falls `defaults[alias]` gesetzt ist, wird dieser verwendet. Treffer>1 ohne Reducer → Fehler.

---

## 10) Reserved für v0.3 (nicht Teil von v0.2)

- `contentType: "text"|"xml"|"csv"|"auto"`
- Weitere Reducer/Transforms: `sort`, `sortBy(path)`, `take(k)`, `slice(a,b)`
- Casts: `decimal(scale)`, `date(fmt)`, `epochSeconds/epochMillis`
- Filter: `matches(/regex/i)`
- Platzhalter-Modifier: `[key|raw]`, `[key|url]`, `[key|json]`
- Pre-Seiteneffekte (Two-Phase Reserve/Commit) als explizites Feature-Flag

---

## 11) Best Practices

- Aliasse **eindeutig benennen** (z. B. `fx.rate`, `quote.ask`) – direkt im `extractMap`-Alias.
- Beträge: `number` + `round(ndigits)`; intern Decimal.
- Defaults gezielt einsetzen.
- Responses klein halten (serverseitige Filter/Fields nutzen).
- Keine Seiteneffekte vor Regeln.

---

## 12) Cheatsheet

- `extractMap` ist **Pflicht** in `apiCalls`.
- Filter nur auf Listen; ohne Reducer bei Mehrtreffern → **Fehler**.
- Platzhalter `[key]`: URL-encoded in URLs, roh in Bodies.
- Seiteneffekte sind **nicht Teil** von `apiCalls` (v0.2).

