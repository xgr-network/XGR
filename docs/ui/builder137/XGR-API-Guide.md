# XGR API Calls (UI Guide)

This guide explains how to **configure HTTP API calls** in the **XRC-137 Builder** UI so they work 1:1 with the engine (runner & parser). It covers what each field does, how placeholders work, **validation rules**, and provides copy‑paste **examples**. Wherever helpful, we include **screenshot placeholders** like `[PNG: apis-panel-main.png]` that your `docs.html` can replace later.

---

## 1) What an API Call is

An API Call fetches **JSON** from an external endpoint and stores fields from that JSON into your rule’s **inputs** via an **extract map**. These inputs are then available for other steps (more API calls, contract reads, rules).

- **Fetch-only** (no retry logic, no custom scripting)
- **JSON response only** (the engine parses JSON, object or array root)
- **Stateless & deterministic** (see limits below)

**PNG proposal**
- [PNG: ![](pictures/ui/builder137/apis-panel-main.png)] — the APIs panel listing with “Add API Call” button and one configured row.

---

## 2) Fields in the UI (engine‑aligned)

Each API Call has these fields (the UI enforces this shape exactly as the engine expects):

| Field          | Type   | Required | Notes                                                                                                     |
|----------------|--------|----------|-----------------------------------------------------------------------------------------------------------|
| **Name**       | string | yes      | Identifier (1–64 chars). Used for logs and alias scoping. Must be unique within this builder rule.       |
| **Method**     | enum   | yes      | One of `GET`, `POST`, `PUT`, `PATCH`. Use `GET` for idempotent reads.                                     |
| **URL Template** | string | yes    | Absolute URL recommended. May include placeholders `[key]`. URL-encoding of placeholder values is automatic. |
| **Headers**    | object | no       | Static string→string map. Avoid dynamic auth headers.                                                      |
| **Body Template** | string | no   | **String** (not object). For non‑GET methods. May contain placeholders. **No URL-encoding** applied.       |
| **Content Type** | enum | yes     | Fixed to `json`. Engine parses JSON only (object or array root allowed).                                   |
| **Extract Map** | object | yes    | `alias → "<CEL over resp>"`. Extracted **scalars** are persisted as inputs.                                |
| **Defaults**   | object | no       | `alias → fallback`. Used if evaluation of the corresponding extract fails.                                 |

**PNG proposal**
- [PNG: apis-editor-modal.png] — the “Edit API Call” modal showing all fields and validation messages.

---

## 3) Placeholders `[key]` in URL / Body

- **Syntax**: `[key]` references an input variable named `key`.
- **Where the values come from**: union of
  1. **Payload** (provided at run time)
  2. **Contract Reads** (`saveAs` outputs)
  3. **Prior API extracts** (from previous API Calls in the list)
- **Escapes**: `[[` → `[` and `]]` → `]`
- **Missing key**: triggers an **error**
- **Body Template** is a **string**; if you author JSON, store it as a compact string (e.g. `"{\"id\":\"[User]\"}"`).

**PNG proposal**
- [PNG: apis-placeholders-help.png] — small tooltip popup explaining placeholder rules.

---

## 4) Extract Map (CEL on `resp`)

- Write small **CEL expressions** against the response **JSON** object named `resp`.
- Each entry saves a **scalar result** (`string | number | bool | int`) under the given **alias**.
- **Alias rules**: `^[A-Za-z][A-Za-z0-9._-]{0,63}$`, must be **unique** across all API Calls of this rule.
- If evaluation fails, the engine uses `defaults[alias]` (if present), otherwise the call **fails**.

**PNG proposal**
- [PNG: apis-extract-map.png] — table‑like editor mapping aliases to CEL expressions with inline validation.

---

## 5) Determinism & Limits

- Timeout per call: **8 s**
- Redirects: **≤ 3**
- Response size: **≤ 1 MB**
- Protocols: **HTTPS** recommended (HTTP allowed by engine config), **TLS ≥ 1.2**, HTTP/1.1
- Network: **IPv4**, no proxies read from env
- Content type: **JSON** only (object or array root)

**PNG proposal**
- [PNG: apis-limits-banner.png] — compact info box with the limits listed above.

---

## 6) Validation (what the UI enforces)

- **Name** unique within the rule.
- **URL Template** present; placeholders must match `^[A-Za-z0-9._-]+$` and be **known** (payload, reads, or prior API outputs).
- **Method** is one of `GET/POST/PUT/PATCH`.
- **Content Type** is always **json**.
- **Body Template** is a **string** (the UI never stores objects here).
- **Extract Map** is required, non‑empty, object `alias → expr`.
- **Alias** matches regex and is unique; **expr** is non‑empty, may be globally unique if your policy requires.

**PNG proposal**
- [PNG: apis-validation-errors.png] — modal showing invalid alias and missing placeholder errors.

---

## 7) Examples

### 7.1 GET with URL placeholder
```json
{
  "name": "Quote",
  "method": "GET",
  "urlTemplate": "https://api.example.com/q?symbol=[payload.symbol]",
  "contentType": "json",
  "extractMap": {
    "q.price": "resp.last.value",
    "q.symbol": "resp.last.symbol"
  },
  "defaults": {
    "q.price": 0
  }
}
```

### 7.2 POST with JSON body template
```json
{
  "name": "Lookup",
  "method": "POST",
  "urlTemplate": "https://api.example.com/lookup",
  "headers": { "Content-Type": "application/json" },
  "bodyTemplate": "{\"id\":\"[contract.targetId]\"}",
  "contentType": "json",
  "extractMap": {
    "user.name": "resp.user.name",
    "user.active": "resp.user.active"
  },
  "defaults": { "user.active": false }
}
```

**PNG proposal**
- [PNG: apis-examples-cards.png] — two cards with the examples and a “validated” badge.

---

## 8) Tips & Troubleshooting

- If a placeholder is unknown, check that it’s part of **payload**, a **previous read’s saveAs**, or a **prior API extract**.
- Keep **Body Template** compact (one line JSON string).
- Prefer stable headers; avoid time‑varying auth headers.
- For staging vs. prod endpoints, use **payload‑controlled** placeholders (e.g. `[env.baseUrl]`).

**PNG proposal**
- [PNG: apis-troubleshooting.png] — compact list of common validation messages.

---

## 9) Common Errors & Quick Fixes

> The UI surfaces these validations early; the list below helps you resolve them fast.

1) **`extractMap is required`**  
   **Cause:** You tried to save an API without any extract entries.  
   **To fix:** Add at least one `alias → expr` row. Keep results **scalar**.

2) **`Body template must be a string`**  
   **Cause:** You pasted JSON as an object instead of a string.  
   **To fix:** Store JSON as a **compact string**, e.g. `"{\"id\":\"[userId]\"}"`.

3) **`Unknown placeholder [key]`**  
   **Cause:** `[key]` isn’t in payload, contract read outputs, or prior API extracts.  
   **To fix:** Add the source first or rename to an existing key. Use the placeholders help popover.

4) **`Placeholder violates key regex`**  
   **Cause:** `[key]` contains characters outside `^[A-Za-z0-9._-]+$`.  
   **To fix:** Rename the key to match the regex.

5) **`Invalid alias "..."` / `Duplicate alias`**  
   **Cause:** Alias fails the regex or appears twice across API calls.  
   **To fix:** Use `^[A-Za-z][A-Za-z0-9._-]{0,63}$` and ensure global uniqueness.

6) **`Expression failed; no default provided`**  
   **Cause:** CEL couldn’t evaluate on `resp` and no fallback exists.  
   **To fix:** Add `defaults[alias]` or guard your CEL (`has(resp.x) ? resp.x : 0`).

7) **`Non-JSON response`**  
   **Cause:** Endpoint returned HTML/text/XML.  
   **To fix:** Switch to a JSON endpoint or a path that returns JSON; keep `contentType: "json"`.

8) **`Timeout / >3 redirects / >1 MB`**  
   **Cause:** Endpoint too slow, redirect loop, or large payload.  
   **To fix:** Use a faster endpoint; reduce response size; avoid excessive redirects.

9) **`HTTP 4xx/5xx`**  
   **Cause:** Server-side error.  
   **To fix:** Check URL, required params/headers, and credentials (prefer static tokens or payload-driven values).

---

## How to reference screenshots in this guide

Place a single line with the pattern below. Your `docs.html` will replace it with an actual image:

```
[PNG: apis-panel-main.png]
```

You can use different names per section, for example:

```
[PNG: reads-modal.png]
[PNG: reads-args-validators.png]
```
