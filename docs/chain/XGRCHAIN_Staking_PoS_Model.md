# XGR Chain — Node Operation

**Document ID:** XGRCHAIN-NODE-OPERATION  
**Last updated:** 2026-05-03  
**Audience:** Node operators, validators, infrastructure operators, RPC providers  
**Implementation status:** Public operator guidance  
**Source of truth:** Public `xgr-network/xgr-node` releases, published network configuration, and official XGR Network operator announcements

---

## 1. Scope

This document describes how to operate an XGR Chain node from an operator perspective.

It covers:

- node roles
- hardware guidance
- public release checkout
- stable source build
- binary installation
- genesis and configuration handling
- data directory handling
- key material
- validator node operation
- full node / RPC node operation
- P2P networking
- JSON-RPC exposure
- logging
- metrics
- backups
- upgrades
- security
- basic troubleshooting

This document does **not** describe private repositories, internal development branches, unpublished implementation work, deprecated bridge systems, or unmaintained local test environments.

---

## 2. Public repository and release model

The public node repository is:

```text
https://github.com/xgr-network/xgr-node
