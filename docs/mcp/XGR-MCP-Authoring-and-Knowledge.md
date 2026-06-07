# XGR MCP Gateway — Authoring & Knowledge

**Document ID:** XGR-MCP-AUTHORING-KNOWLEDGE  
**Last updated:** 2026-06-07  
**Audience:** Agent builders, integrators, developers  
**Implementation status:** Live  
**Source of truth:** `xgr-mcp-gateway/src/knowledge`, `xgr-mcp-gateway/src/tools/knowledgeTools.ts`

The gateway ships an agent-readable knowledge base — authoring rules, standard references, schemas, examples, and validators — so that the agent drafting an XRC-137/XRC-729/xDaLa artifact and the validator checking it work from the same definitions. This is what makes "describe it in plain language" produce a *validated* artifact rather than a guess.

---

## Why this lives in the gateway

A natural-language-to-on-chain flow is only trustworthy if the language layer lands on a hard, validated shape. The knowledge tools provide the guardrails:

- **Authoring rules** tell the agent how to draft (payload schema rules, placeholder syntax, `apiCalls`, rules, validation requirements).
- **Schemas** give machine-readable shapes to draft against.
- **Validators** reject anything that does not conform before it is presented as final.

The result: the agent cannot quietly produce a malformed bundle or session-start request — the same rules that guide drafting also gate the output.

## Knowledge tools

| Tool | Use before… |
|---|---|
| `list_xgr_standards` | …discovering which standards are available (incl. `xdala-authoring`). |
| `get_xdala_authoring_rules` | …creating, modifying, or reviewing XRC-137/XRC-729 artifacts, payloads, runbooks, or Workbench handoff JSON. |
| `get_xgr_standard_reference` | …drafting an XRC-137 or XRC-729 artifact (prose reference). |
| `get_xgr_standard_schema` | …drafting, when you need the machine-readable JSON schema. |
| `list_xgr_standard_examples` / `get_xgr_standard_example` | …drafting, when a concrete example helps. Examples are guidance — still validate. |
| `get_xgr_multibundle_reference` / `get_xgr_multibundle_schema` | …generating a complete `xgr-multi-bundle@1` process bundle. |
| `get_xgr_session_start_schema` | …preparing a `xgr-session-start@1` Workbench handoff. |

## Validators

| Tool | Validates |
|---|---|
| `validate_xgr_multibundle` | Canonical deployable `xgr-multi-bundle@1`. Rejects root validation metadata and bundle-level `initialPayload`, `entryStepId`, `requiredDeployments`. |
| `validate_xdala_bundle` | Alias for `validate_xgr_multibundle`. |
| `validate_xgr_session_start_handoff` | Canonical `xgr-session-start@1` (`type=xdala_session_start`, `sessions[].stepId/payload/maxTotalGas`). Do not use `entryStepId`. |
| `validate_legacy_session_start` | The legacy low-level session-start payload only — not the Workbench handoff. Do not put a legacy object into the MultiBundle. |

## Canonical schema boundaries

Two distinct artifacts, two distinct schemas — do not mix them:

- **`xgr-multi-bundle@1`** — a *deployable* process bundle (XRC-729 + XRC-137 rules). Deployed via the bundle-deploy handoff.
- **`xgr-session-start@1`** — a *start* request for an existing/deployed workflow. Prepared via the session-start handoff with `sessions[].stepId`, `sessions[].payload`, `sessions[].maxTotalGas`.

`entryStepId` belongs to neither Workbench field; use `sessions[].stepId` for session start.

## Single source of truth

The runtime authoring rules are defined in code, not in documentation: `src/knowledge/xdalaAuthoring.ts` exports the `xdalaAuthoringRules` constant that the knowledge tools serve. That TypeScript constant is the source of truth.

This page and the rest of the central docs are the human-readable reference; they must be kept in sync with the constant whenever the rules change. To avoid drift, treat the constant as canonical and regenerate or review this page against it on every rules change rather than editing the prose independently.

## Related documents

- [XDaLa_Agent_Authoring_Rules.md](../XDaLa_Agent_Authoring_Rules.md)
- [XRC-137_Smart_Contract_Standard.md](../XRC-137_Smart_Contract_Standard.md)
- [XRC-729_Smart_Contract_Standard.md](../XRC-729_Smart_Contract_Standard.md)