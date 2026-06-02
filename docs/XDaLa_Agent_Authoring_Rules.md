# XDaLa Agent Authoring Rules

**Document ID:** XDALA-AGENT-AUTHORING-RULES  
**Audience:** AI agents, MCP tool authors, Workbench developers, SDK developers  
**Status:** Authoring guardrail  
**Purpose:** Prevent invalid XRC-137/XRC-729 drafts by forcing agent-generated artifacts to follow the actual xDaLa parser/runtime schema.

---

## 1. Hard rule

Agents must not present XRC-137/XRC-729 JSON as final unless it has passed an authoritative xgrEngine/MCP validation step.

If validation cannot be executed because a tool is missing, denied, expired, or unavailable, the agent must mark the output as:

```text
DRAFT ONLY - NOT VALIDATED
```

and state the exact missing tool/action.

Correct language:

```text
Validated by xgrEngine parser.
```

Incorrect language:

```text
Based on the XGR standards.
```

---

## 2. XRC-137 payload is input schema only

In XRC-137, the top-level `payload` object defines the expected input fields for a step.

Each payload field may contain only:

```json
{
  "type": "string",
  "default": "optional fallback"
}
```

`default` is optional.

### Correct

```json
{
  "payload": {
    "orderId": { "type": "string" },
    "amount": { "type": "uint256" },
    "currency": { "type": "string", "default": "EUR" }
  }
}
```

### Forbidden

Never put `value`, `expr`, `source`, `$input`, `${...}`, or mapping expressions inside `payload` fields.

```json
{
  "payload": {
    "orderId": {
      "type": "string",
      "value": "$input.orderId"
    }
  }
}
```

This is invalid. The xgrEngine parser treats unknown payload field properties as schema errors.

---

## 3. Where `value` and `expr` are allowed

`value` / `expr` belong only to TypedValue contexts.

Allowed locations:

- `apiCalls[].extractMap.<alias>.value`
- `apiCalls[].extractMap.<alias>.expr` (legacy alias for `value`)
- `contractReads[].args[].value`
- `contractReads[].args[].expr` (legacy alias for `value`)
- `onValid.execution.args[].value`
- `onInvalid.execution.args[].value`
- `onValid.execution.value.value`
- `onInvalid.execution.value.value`

Not allowed:

- `payload.<field>.value`
- `payload.<field>.expr`
- `rules[].expr`
- `apiCalls[].extract`

---

## 4. API call schema

Use this schema:

```json
{
  "apiCalls": [
    {
      "name": "payment_status",
      "method": "GET",
      "urlTemplate": "https://payments.example.com/status/[paymentReference]",
      "contentType": "json",
      "timeoutMs": 3000,
      "extractMap": {
        "paymentStatus": {
          "type": "string",
          "value": "string(resp.status)",
          "default": "pending"
        }
      }
    }
  ]
}
```

Required/known fields:

- `name`
- `method`
- `urlTemplate`
- `contentType`
- `bodyTemplate`
- `headers`
- `timeoutMs`
- `extractMap`

Forbidden generic workflow fields:

- `id` instead of `name`
- `url` instead of `urlTemplate`
- `extract` instead of `extractMap`
- JSONPath-only mappings such as `"$.status"` without a typed extract spec

`extractMap` aliases become direct variables in the step environment. If the alias is `paymentStatus`, downstream rules and branch payloads reference `[paymentStatus]`.

---

## 5. Placeholder and expression syntax

xDaLa placeholders use square brackets:

```text
[orderId]
[paymentReference]
[paymentStatus]
```

Do not use:

```text
$input.orderId
${orderId}
$api.payment_status.paymentTxId
```

Examples:

```json
{
  "urlTemplate": "https://payments.example.com/status/[paymentReference]",
  "rules": [
    "[paymentStatus] == 'paid' && [paidAmount] >= [amount]"
  ],
  "onValid": {
    "payload": {
      "paymentTxId": "[paymentTxId]"
    }
  }
}
```

---

## 6. Rules schema

Rules must be either strings:

```json
{
  "rules": [
    "[amount] > 0 && [currency] != ''"
  ]
}
```

or objects with `expression` and optional `type`:

```json
{
  "rules": [
    {
      "expression": "[paymentStatus] == 'paid'",
      "type": "validate"
    }
  ]
}
```

Forbidden:

```json
{
  "rules": [
    {
      "id": "payment_received",
      "expr": "paymentStatus == 'paid'"
    }
  ]
}
```

---

## 7. Branch payload semantics

`onValid.payload` and `onInvalid.payload` are outcome/follow-up payload overlays. They are not input schemas.

Correct:

```json
{
  "onValid": {
    "payload": {
      "orderStatus": "payment_received",
      "paymentTxId": "[paymentTxId]"
    }
  },
  "onInvalid": {
    "waitSec": 300,
    "payload": {
      "orderStatus": "awaiting_payment"
    }
  }
}
```

---

## 8. XRC-729 orchestration rules

XRC-729 OSTC nodes reference deployed XRC-137 rule contract addresses.

Draft placeholders such as:

```text
{{XRC137_ORDER_RECEIVED_ADDRESS}}
```

are allowed only in draft handoff packages and must be explicitly marked as placeholders. They are not deployable final OSTC values.

For each OSTC:

- `id` must identify the orchestration.
- `structure` maps step IDs to nodes.
- each node should reference a rule contract address.
- `onValid.spawns` / `onInvalid.spawns` must reference existing step IDs.
- joins/wakeups must be cross-checked against known process semantics.

---

## 9. Required validation pipeline

Before returning a final XDaLa process bundle, agents must validate:

1. every XRC-137 rule document
2. the XRC-729 OSTC document
3. the entry step
4. the initial payload against the entry step input schema
5. all cross references between XRC-729 steps and XRC-137 rules
6. placeholder references used in rules, URL templates, output payloads, contract reads, and execution args

If any validation tool is missing, the agent must say exactly:

```text
Missing MCP tool: <tool name>
```

and return only a draft.

---

## 10. Minimal valid pattern: order/payment/finalize

### XRC-137 input payload

```json
{
  "payload": {
    "orderId": { "type": "string" },
    "amount": { "type": "uint256" },
    "currency": { "type": "string" },
    "paymentReference": { "type": "string" }
  },
  "apiCalls": [
    {
      "name": "payment_status",
      "method": "GET",
      "urlTemplate": "https://payments.example.com/status/[paymentReference]",
      "contentType": "json",
      "extractMap": {
        "paymentStatus": {
          "type": "string",
          "value": "string(resp.status)",
          "default": "pending"
        },
        "paidAmount": {
          "type": "uint256",
          "value": "uint(resp.amount)",
          "default": 0
        },
        "paidCurrency": {
          "type": "string",
          "value": "string(resp.currency)",
          "default": ""
        },
        "paymentTxId": {
          "type": "string",
          "value": "string(resp.transactionId)",
          "default": ""
        }
      }
    }
  ],
  "contractReads": [],
  "rules": [
    "[paymentStatus] == 'paid' && [paidAmount] >= [amount] && [paidCurrency] == [currency]"
  ],
  "onValid": {
    "payload": {
      "paymentStatus": "paid",
      "paymentTxId": "[paymentTxId]",
      "orderStatus": "payment_received"
    }
  },
  "onInvalid": {
    "waitSec": 300,
    "payload": {
      "paymentStatus": "pending",
      "orderStatus": "awaiting_payment"
    }
  }
}
```

---

## 11. Agent output requirements

Final output must include a validation block:

```text
Validation:
- XRC-137: passed
- XRC-729: passed
- bundle cross references: passed
- initial payload: passed
```

Draft output must include:

```text
DRAFT ONLY - NOT VALIDATED
Missing MCP tool: <tool name>
```

or the specific denied/expired validation action.

Agents must never hide validation failure behind wording such as “structured draft based on standards” when the JSON is presented as executable.
