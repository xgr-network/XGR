# XGR Interchain / XITA — complete v3.2.3 technical reference

> **Historical snapshot — not current execution instructions.** The current v3.4.0 [technical reference](./XGR_INTERCHAIN_v3.4.0_Reference.md) and [independent operations](./XGR_INTERCHAIN_v3.4.0_Operations.md) supersede this page for Direct-BLS transport, route registration, fees and recovery. Historical contract addresses and Merkle/route-governance procedures below must not be used for current deployments.


**Updated:** 2026-10-23. **Code:** [xgr-interchain](https://github.com/xgr-network/xgr-interchain) and [xgr-node v3.2.3](https://github.com/xgr-network/xgr-node/tree/v3.2.3). **Implementation repository:** `xgr-interchain`. This snapshot predates Direct-BLS. **Current website:** https://xita.xgr.network. Production public-launch status remains separately controlled.

## Documentation map

| Audience | Authoritative reference |
| --- | --- |
| Protocol integrators and auditors | This reference; [XITA v3.1.5 contract specification](https://github.com/xgr-network/xgr-interchain/blob/main/docs/XITA_SPEC_V315.md) for frozen contract interfaces |
| Validator node operators | [XGR-Node v3.2.3 operator, CLI, RPC and recovery](https://github.com/xgr-network/xgr-node/blob/XGR3.0/docs/ILN_V340_OPERATOR_REFERENCE.md) |
| Independent transfer users | [Direct ILN source/destination recovery without commercial fee adapter or relayer](./XGR_INTERCHAIN_v3.4.0_Operations.md) |
| Contract integrators | [ILNGateway](https://github.com/xgr-network/xgr-interchain/blob/main/contracts/ILNGateway.sol), [Factory/Registry](https://github.com/xgr-network/xgr-interchain/blob/main/contracts/XGRILNRegistryV315.sol), [FeeVault](https://github.com/xgr-network/xgr-interchain/blob/main/contracts/XGRILNFeeVault.sol), [ISM](https://github.com/xgr-network/xgr-interchain/blob/main/contracts/XITADirectBLSISM.sol) |
| Deployment/maintenance operators | [Deployment references](https://github.com/xgr-network/xgr-interchain/blob/main/docs/GENERIC_CHAIN_DEPLOYMENT_V315.md), [Merkle bootstrap](https://github.com/xgr-network/xgr-interchain/blob/main/docs/ILN_V320_MERKLE_BOOTSTRAP.md), [actual receipts](https://github.com/xgr-network/xgr-interchain/tree/main/deployments) |
| XITA website maintainers | [UI architecture](https://github.com/xgr-network/xgr-interchain/blob/main/docs/XETA_UI_ARCHITECTURE.md), [source](https://github.com/xgr-network/xgr-interchain/tree/main/apps/web) |
| Release engineers | Tagged xgr-node source, CI and [operational tests](https://github.com/xgr-network/xgr-interchain/tree/main/contracts/test) |

The original 2026-10-04 XGR docs describing v3.1.1 Base-only architecture are **historical**, not current deployment authority. `xgr-node` runtime v3.2.3 and the deployed v3.1.5 Solidity contract family are independently versioned, so they do **not** have to share a single semantic version.

## 1. Motivation, properties and topology

XGR Interchain connects independently finalized EVM networks through the XGRChain security hub. For different spokes, a user's journey requires exactly **two individual source operations** and corresponding destination deliveries: Arbitrum → XGRChain → Base or its reverse. XGRChain chain ID and domain are **1643**, Base **8453**, Arbitrum **42161**. Direct spoke-to-spoke router connections bypassing the hub are not supported.

Important guarantees and explicit non-guarantees:

- Validator quorum **independently validates each canonical source message**, including expected route, original paid source fee, canonical Mailbox dispatch, confirmed Merkle root and recipient network.
- The destination ISM authenticates the currently valid BLS aggregate, Merkle inclusion and full route binding. A relayer is an **untrusted delivery transport**, not a custodian, route administrator or authorized minter.
- Every wallet-signed user transaction remains under user control. There is **no automatic signing of users' lock/burn/onward/delivery** by XITA. Technical proof preparation may be automated without private keys.
- Original collateral may be held by **on-chain router escrow**, which is a separate contract risk; the company does not hold the user's private wallet key.
- Public permissionless routes require no governance admission vote. Validator quorum governs message security and **chain-wide source validator fee changes**.
- External blockchains, RPC providers and validator quorum availability are failure dependencies; guaranteed delivery time and zero smart-contract risk are **not** promised.

## 2. Components by chain

```text
              Arbitrum                         XGRChain                          Base
         (domain 42161)                     (hub domain 1643)                (domain 8453)
 ERC20 ARB + collateral router  --[Mailbox/Hook + BLS proof]-->  synthetic wARB router
                              <--- corresponding independently secured return direction
                                                |
                           hub synthetic burn + second ILNGateway.bridge
                                                |
                                   [Mailbox/Hook + BLS proof]
                                                v
                                           Base wARB mint

Each hop source: ILNRegistry + Factory -> ILNGateway -> guarded Warp Router
                  ILNGateway -> per-route FeeVault.allocate()
                  Mailbox.Dispatch -> MerkleTreeHook.InsertedIntoTree
Each hop destination: Mailbox.process -> destination ISM verifies canonical proof
                       -> inbound Warp Router -> mint/unlock
Off-chain: xgr-node validator worker + P2P + read-only quorum/proof RPC
Optional commercial: XITAExecutionGateway, UI quote, sponsor and transfer indexer
```

**Shared per-physical-chain contracts**: validator registry, BLS verifier where applicable, destination ISM, Mailbox/Merkle Hook, Factory/source ILN Registry, deployment-specific adapter and router deployers. **Per-asset-per-chain**: asset source/wrapped router. **Per-directed-route**: protocol ILNGateway and FeeVault. Independent asset identity includes the canonical chain/token/kind; directed route identity additionally binds source/destination, routers and domains. Contract deployment receipts must be verified against live bytecode and source registries, not copied from old screenshots.

## 3. Asset models and supply invariants

| Model | Source operation | Destination operation | Reverse operation |
| --- | --- | --- | --- |
| Native XGR → wrapped XGR | Source native XGR lock | Mint wXGR | Burn wXGR; unlock source XGR |
| Canonical ERC-20 ARB → wARB | ERC-20 `approve` then collateral lock | Mint synthetic wARB | Burn wARB, and finally unlock original ARB |
| Synthetic → synthetic spoke transfer | Burn on source synthetic router | Mint on hub then burn for onward hop | Mint on target synthetic router |
| Direct hub-to-spoke or spoke-to-hub | One individual route/source bridge | One authenticated destination delivery | Reverse route needed separately |

On a two-hop journey, the hub's intermediate minted representation is an **intermediate balance**; it is not a second independently backed original asset. Ensure the post-hop escrow and total wrapped supply balance reconcile across all connected chains. The existence of a router on one chain does not guarantee a return route, sufficient collateral or advertised transfer readiness.

## 4. Permissionless route lifecycle

The registered source Factory can create a route-specific ILNGateway and its source FeeVault, storing the immutable directed route identity in the on-chain ILN Registry. A new route on an **already configured physical chain** becomes discoverable to xgr-node validators through confirmed `RouteAdded` events and registry checks without per-token environment configuration or validator restart.

For a **brand-new physical chain**, deploy shared contracts, verify bytecode, identify actual chain/domain, register authorized validator set and safely add the new `XGR_INTERCHAIN_<NAME>_*` chain config to each operator's node environment. **In v3.2.3 the node creates its destination map on startup and therefore requires a controlled restart for a wholly new chain**. A zero-restart general chain addition is a future enhancement, not documented as released. A token listing on XITA is not itself a protocol authorization gate.

The deployment tooling is GitHub-receipt-backed, requires wallet signatures for on-chain writes and must distinguish a confirmed transaction from a documented contract. `./manage.sh deploy` deploys the website, not new blockchain contracts. Avoid resurrecting deprecated historical registry/ISM deployments or legacy router identities.

## 5. ILN proofs and message security

For source message `messageId`: (1) verify source chain identity and confirmed source Gateway operation; (2) verify same-operation canonical Mailbox Dispatch; (3) validate route and allocated original source fee; (4) check confirmed MerkleTreeHook root/count; (5) verify ordered leaf inclusion, independently; (6) obtain 2/3 eligible validator BLS signatures bound to original message, route, current destination set ID and confirmed checkpoint; (7) independently verify destination ISM acceptance with `Mailbox.process.staticCall`; (8) sign and broadcast destination `Mailbox.process(metadata,message)`; (9) verify `Mailbox.delivered(messageId)` and recipient balance.

The **current destination validator set ID matters**. Old archival signatures can become ineligible after set rotation; re-attest the original source message under the current set without re-sending source lock/burn. Neither a source transaction receipt nor an RPC `AVAILABLE_UNVERIFIED` status by itself proves completion.

Merkle P2P replication transfers **public hashes, not secret keys or trust**. Each candidate is anchored to source Hook state; per-peer chunks are bounded and authenticated at the transport layer. The local confirmed-hook catch-up is limited to 128 blocks; a complete missing prefix needs a verified peer/backup or operator-verified one-off Hook log reconstruction. `v3.2.3` fixes a checkpoint stability check from v3.2.2 that incorrectly required identical advancing block heads, but **does not** automatically rebuild every missing replica from historical events.

## 6. Independent noncommercial transfer path

The public **ILNGateway** is not the optional commercial **XITAExecutionGateway**. Quote with `quoteILN(destinationDomain,recipient,amount)`; approve the **ILNGateway** for ERC-20; sign `bridge` with exact native quoted value. Obtain message ID from source receipt. `node runtime/native-relayer/recover-iln.mjs MESSAGE_ID` reconstructs and validates the public proof using public RPCs and releases an **unsigned** destination Mailbox call. The user pays destination gas and signs `Mailbox.process`. Repeat for second hop as a separately signed operation. The web UI, commercial service fee, gas sponsor and managed relayer are optional. Protocol validator fee, authentic validator quorum, on-chain contracts, chain RPC access and user native gas remain necessary.

**Full procedure, env variables, caveats and replay protection:** [v3.2.3 independent transfer operations](./XGR_INTERCHAIN_v3.4.0_Operations.md).

## 7. Fees and accounting trust separation

**Protocol fees:** every source-chain registry has a single source-native validator fee value, changed through explicit 2/3 validator fee governance. Each source ILNGateway/ FeeVault enforces payment and message-linked allocation as part of source bridge execution. Validators may independently `claimable(address)` and `claim()` on the **fee source chain**; claims are pull-based.

**Optional commercial fee:** XITAExecutionGateway may quote/sign and collect a separately stated off-chain-service price in source currency. It is not part of validator quorum truth, not a mandatory protocol charge and cannot authorize mint without verified message proofs.

**Gas sponsor:** where enabled, a separate company worker can send native gas to a **user-controlled wallet** for qualifying steps. No transfer signing authority is conferred. Sponsoring is limited to eligible steps and reserve/budget rules; the service may be off or depleted.

**Accounting/GeoIP:** XITA fee-related records and optional collected IP/country evidence are private off-chain commercial data, not validator signing inputs. Tax classification and validator revenue allocation must be assessed separately; customer IP is not automatically conclusive VAT proof.

## 8. Validator/operator CLI and RPC map

Source authoritative node commands:

```sh
xgrchain ibft interchain bootstrap-proof --data-dir /ABS/PATH --origin-chain-id 1643 --destination-domain 8453
xgrchain ibft interchain set-active --chain base --active true --data-dir /ABS/PATH
xgrchain ibft interchain fee create --source base --fee-wei AMOUNT --data-dir /ABS/PATH
xgrchain ibft interchain fee approve --proposal-id 0xHASH --data-dir /ABS/PATH
xgrchain ibft interchain fee execute --proposal-id 0xHASH --data-dir /ABS/PATH
xgrchain ibft interchain storage-status --data-dir /ABS/PATH
```

Source authoritative node RPC: `xgr_getInterchainValidators`, `xgr_requestILNQuorum`, `xgr_getILNQuorum`, `xgr_getILNQuorumAttestation`, `xgr_getILNReplicaProof`, `xgr_getILNIndexerStatus`, `xgr_getILNGovernanceQuorum`. Quorum requests are untrusted **hints**, not arbitrary signing instructions.

For complete flags, sample JSON-RPC requests, Merkle backup/catch-up, deployment env and failure tables, see [node v3.2.3 operator reference](https://github.com/xgr-network/xgr-node/blob/XGR3.0/docs/ILN_V340_OPERATOR_REFERENCE.md).

## 9. Production operation and release acceptance

Maintain at least one full, verified copy of each active source Hook replica and reliable validator data-dir backup; test independent restoration. Monitor worker heartbeat, route count/root, `localLeaves`, `lagLeaves`, peer exchange errors, quorum thresholds and chain-specific RPC failures. A progress stall never authorizes a second original source transaction.

Regression coverage should include XGR↔Base native bridge, real ARB Collateral↔Synthetic mainnet **both directions**, two-hop journey continuation, current-set rotation, P2P cold-join, absence of complete peers, rejected forged source evidence, receipt/fee reconciliation, independent unsigned recovery, wallet reload and UI state stability. **Tests are required evidence; a document does not assert an unperformed transfer passed.**

Changes to node consensus/StateTx/EVM require appropriate tagged node release, independent test and compatibility review; editing XITA website or contract documentation does not itself modify the blockchain. Existing Solidity contracts must never be casually redeployed as a consequence of routine node documentation updates.

## 10. Security and operational limitations

- The assumption that a 2/3 quorum remains honest is a meaningful protocol trust boundary. Do not advertise absolute trustlessness or zero risk.
- System components that the company deploys/operates may create provider responsibilities; "public code" does not automatically remove liability.
- If source Hook history is missing from **all** replicas and reliable backups, the on-chain Merkle root alone cannot invert into the missing ordered hashes.
- Validators are not required to fund third-party destination gas; any account may act as an untrusted executor once proof is available.
- No single RPC should be accepted as an unquestioned authority; verify chain ID, deployment binding, receipt, root/count and destination `process` simulation.
- `xgr-interchain` and the historic `bridge.xgr.network` references are **legacy**; do not use them for current onboarding/deployments.
