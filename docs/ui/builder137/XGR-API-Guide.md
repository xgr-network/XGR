# XGR API Calls (UI Guide)

This guide explains how to **configure HTTP API calls** in the **XRC-137 Builder** UI so they work 1:1 with the engine (runner & parser). It covers fields, placeholders, **validation**, and **examples**. Screenshots are linked directly.

---

## 1) What an API Call is

An API Call fetches **JSON** and stores fields from that JSON into your rule’s inputs via an **extract map**.

- **Fetch-only** (no retry logic)  
- **JSON response only** (object or array root)  
- **Stateless & deterministic**

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-panel-main.png) — APIs panel with “Add API Call” and one configured row.

---

## 2) Fields in the UI (engine-aligned)

| Field            | Required | Notes                                                                 |
|------------------|----------|-----------------------------------------------------------------------|
| **Name**         | yes      | Identifier (1–64 chars), unique in the rule.                          |
| **Method**       | yes      | `GET`, `POST`, `PUT`, `PATCH`.                                       |
| **URL Template** | yes      | Absolute URL; placeholders `[key]` allowed (URL-encoded).             |
| **Headers**      | no       | String→string map.                                                    |
| **Body Template**| no       | **String** (not object). For non-GET; placeholders allowed.           |
| **Content Type** | yes      | Fixed `json`; engine parses JSON only.                                |
| **Extract Map**  | yes      | `alias → "<CEL over resp>"`; persisted if scalar.                     |
| **Defaults**     | no       | `alias → fallback` when extract fails.                                |

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-editor-modal.png) — “Edit API Call” modal with all fields and a small validation hint.

---

## 3) Placeholders `[key]` in URL / Body

- Sources: **payload**, **reads (`saveAs`)**, **previous APIs**.  
- Escapes: `[[` → `[`, `]]` → `]`.  
- Missing key ⇒ error.  
- Body Template is a **string** (use compact JSON).

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-placeholders-help.png) — Tooltip/popover with sources and two example keys.

---

## 4) Extract Map (CEL on `resp`)

- CEL expressions against `resp`.  
- Results must be **scalars**.  
- Alias regex: `^[A-Za-z][A-Za-z0-9._-]{0,63}$`, unique in rule.  
- If evaluation fails, `defaults[alias]` is used; else the call fails.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-extract-map.png) — Table-like editor mapping aliases to expressions with inline validation.

---

## 5) Determinism & Limits

- Timeout: **8 s**; ≤ **3** redirects; ≤ **1 MB** response  
- TLS ≥ 1.2; HTTP/1.1; IPv4; no env proxies

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-limits-banner.png) — Compact box listing the limits above.

---

## 6) Validation (what the UI enforces)

- Name unique, 1–64 chars  
- URL present; placeholders resolvable  
- Method from enum; Content Type `json`  
- Body Template is **string**  
- Extract Map non-empty; aliases valid & unique

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-validation-errors.png) — Invalid alias + missing placeholder examples.

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
  "defaults": { "q.price": 0 }
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

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-examples-cards.png) — Two example cards with a “validated” badge.

---

## 8) Tips & Troubleshooting

- Unknown placeholder? Ensure it’s in payload, reads, or a prior API.  
- Keep Body Template compact (single-line JSON string).  
- Avoid time-varying auth headers.  
- Use payload-controlled `[env.*]` to switch endpoints per environment.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/apis-troubleshooting.png) — Compact list of common messages with one-line fixes.
