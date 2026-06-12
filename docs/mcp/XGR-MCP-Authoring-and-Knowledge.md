# XGR MCP Gateway — Authoring & Knowledge

**Document ID:** XGR-MCP-AUTHORING-KNOWLEDGE  
**Last updated:** 2026-06-12  
**Audience:** Agent builders, integrators, developers  
**Implementation status:** Live  
**Source of truth:** `xgr-network/XGR/docs`

The gateway exposes the XGR/XDaLa documentation and validators to AI agents and authoring tools. The documentation source of truth is the central `docs/` directory in the `xgr-network/XGR` repository. The MCP gateway is the delivery and validation layer: it serves selected Markdown topics, provides schemas/examples where useful, and rejects malformed artifacts through hard validators.

This separation keeps the authoring model stable:

```text
XGR/docs = documentation source of truth
MCP gateway = delivery + validation layer
XValDos Studio = UI / authoring frontend
```

The purpose is not to let an AI guess a deployable artifact from prose. The purpose is to guide the AI and the UI through the same documented XRC/XDaLa semantics that the validators enforce.

---

## Authoring principle

A language-to-XDaLa flow is trustworthy only if the language layer lands on validated XRC artifacts. Agents and Studio clients must treat MCP validation as a hard gate:

1. Load the relevant XGR documentation topics from MCP.
2. Draft or modify the current authoring model.
3. Build XRC-137 step artifacts.
4. Validate each XRC-137 artifact.
5. Validate rule expressions and placeholder scope where rules are generated or modified.
6. Build XRC-729 orchestration from the validated step set.
7. Validate the XRC-729 blueprint and payload flow.
8. Assemble the canonical `xgr-multi-bundle@1`.
9. Validate the final MultiBundle.

A final bundle must be the result of the validated XRC-137 + XRC-729 composition. Agents should not attempt to generate a complete MultiBundle directly from a cold prompt and only then discover broken internal structure.

---

## Knowledge tools

| Tool | Use before… |
|---|---|
| `list_xgr_docs` | …discovering canonical Markdown documentation topics served by MCP. |
| `get_xgr_doc` | …loading a specific topic from `xgr-network/XGR/docs`. |
| `list_xgr_standards` | …discovering legacy/compatibility standard handles. |
| `get_xdala_authoring_rules` | …creating, modifying, or reviewing XRC/XDaLa artifacts. Compatibility alias for the authoring rules topic. |
| `get_xgr_standard_reference` | …drafting an XRC-137 or XRC-729 artifact when a legacy standard handle is used. |
| `get_xgr_standard_schema` | …drafting, when a machine-readable JSON schema is needed. |
| `list_xgr_standard_examples` / `get_xgr_standard_example` | …drafting, when a concrete example helps. Examples are guidance; still validate. |
| `get_xgr_multibundle_reference` / `get_xgr_multibundle_schema` | …assembling or validating a complete `xgr-multi-bundle@1` process bundle. |
| `get_xgr_session_start_schema` | …preparing a `xgr-session-start@1` Workbench handoff. |

Preferred modern clients should use `list_xgr_docs` and `get_xgr_doc(topic)` first. Compatibility tools may remain available for older clients, but they are not the documentation source of truth.

Recommended topic loading:

| Authoring need | Topics |
|---|---|
| Simple output/rule workflow | `xdala-authoring`, `xrc-137-rule-document`, `expression-evaluation` |
| API-backed workflow | plus `api-calls` |
| Contract-read workflow | plus `contract-reads` |
| Join/orchestration workflow | `xrc-729-orchestration`, `xrc-137-rule-document` |
| Final bundle/export | `xgr-multibundle` |

---

## Validators

| Tool | Validates |
|---|---|
| `validate_xrc137_authoring` | A single XRC-137 authoring object, including payload schema and branch payload misuse. |
| `validate_xdala_rules` | Rule expressions against available placeholder fields. Use this for rule-only edits and for generated rules before bundle assembly. |
| `validate_xdala_blueprint` | XRC-729 OSTC plus per-step XRC-137 payload-flow consistency. |
| `validate_xgr_multibundle` | Canonical deployable `xgr-multi-bundle@1`. Rejects root validation metadata and bundle-level `initialPayload`, `entryStepId`, `requiredDeployments`. |
| `validate_xdala_bundle` | Alias for `validate_xgr_multibundle`. |
| `validate_xgr_session_start_handoff` | Canonical `xgr-session-start@1` (`type=xdala_session_start`, `sessions[].stepId/payload/maxTotalGas`). Do not use `entryStepId`. |
| `validate_xgr_session_start` | Legacy low-level session-start payload only. Do not put a legacy object into the MultiBundle. |

---

## Canonical schema boundaries

Two distinct artifacts, two distinct schemas — do not mix them:

- **`xgr-multi-bundle@1`** — a deployable process bundle composed from one XRC-729 orchestration and one or more XRC-137 rule artifacts. Deployed via the bundle-deploy handoff.
- **`xgr-session-start@1`** — a start request for an existing/deployed workflow. Prepared via the session-start handoff with `sessions[].stepId`, `sessions[].payload`, and `sessions[].maxTotalGas`.

`entryStepId` belongs to neither Workbench field; use `sessions[].stepId` for session start.

---

## Studio and agent behavior

For XValDos Studio, AI should be treated as a language-based change request mechanism over the current draft state:

- If no draft exists, the prompt creates the initial draft.
- If a draft exists, the prompt modifies that current draft and should preserve unchanged parts unless explicitly asked to replace them.
- Loading a draft, importing a previous workflow, or generating from language should all converge into the same current draft model.
- Graph view, field editing, validation, and final local draft creation must use the same downstream path regardless of how the current draft state was obtained.

The AI should output a normalized Studio authoring model first, not a final bundle. XValDos then builds XRC-137 artifacts, validates them, builds XRC-729, validates the blueprint, assembles the canonical MultiBundle, and validates the final bundle.

---

## Related documents

- [XDaLa_Agent_Authoring_Rules.md](../XDaLa_Agent_Authoring_Rules.md)
- [XRC-137_Rule_Document_Spec.md](../XRC-137_Rule_Document_Spec.md)
- [XRC-137_Smart_Contract_Standard.md](../XRC-137_Smart_Contract_Standard.md)
- [XRC-729_Smart_Contract_Standard.md](../XRC-729_Smart_Contract_Standard.md)
- [xrc_729_orchestration_session_manager.md](../xrc_729_orchestration_session_manager.md)
- [xgr_expression_evaluation_developer_guide.md](../xgr_expression_evaluation_developer_guide.md)
