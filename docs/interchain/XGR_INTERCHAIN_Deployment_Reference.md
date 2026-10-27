# Recorded deployments and route inventory

[Documentation index](README.md). Snapshot of public xgr-interchain commit `9518472c04432c57a5939a3688e90be332180636`. These are recorded deployment identities, not a fresh live-chain availability claim. Verify current code, bindings, set, fees and reciprocal routes before signing.

## 1. Supported compiled chain policy

| Network | Chain/domain | Node name | Finality | Source Registry activation (RPC receipt height) |
| --- | ---: | --- | --- | ---: |
| XGRChain | 1643 | xgr | Locally committed IBFT | 12053797 |
| Base | 8453 | base | Checked safe | 53026521 |
| Arbitrum | 42161 | arbitrum | Checked safe | 517836903 |

The policies are pinned in node `interchain/config.go`. Polygon prospect definitions do not establish active node support. Arbitrum activation uses RPC L2 receipt height, not Solidity L1-origin `block.number`.

## 2. Shared infrastructure

### xgrchain

| Component | Address | Receipt block / evidence |
| --- | --- | --- |
| validatorRegistry | `0x9b6b92ef1745611f402341965f7fc649cbe0da8c` | [12053438](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/f0156bb3f725bba47458435a6f848911e354252654aef751a0edac198fd9e9dc-9b6b92ef1745611f402341965f7fc649cbe0da8c.json) |
| ism | `0x1bd47599e8e7436948e596a0e055f2c7ec02cc30` | [12053472](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/c9885fe5749129cc9635ea8b99517d9d58281a3aade8a0f3a0cf5994026c7ab0-1bd47599e8e7436948e596a0e055f2c7ec02cc30.json) |
| transportBundle | `0xeeb50ae5ade22969a5ec3b9da0878ab57211d606` | [12053674](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/516baafdf932e41d9f22b49a39cb325e37b801633bce282dcee933f0cb92ea3f-eeb50ae5ade22969a5ec3b9da0878ab57211d606.json) |
| mailbox | `0x37a8c5f601adf3cbbe70ea66df2f964321c0e02a` | [12053674](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/516baafdf932e41d9f22b49a39cb325e37b801633bce282dcee933f0cb92ea3f-37a8c5f601adf3cbbe70ea66df2f964321c0e02a.json) |
| dispatchHook | `0x0a6e9d3e672b281f3351aaa77bfcfbfb5ed019fd` | [12053674](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/516baafdf932e41d9f22b49a39cb325e37b801633bce282dcee933f0cb92ea3f-0a6e9d3e672b281f3351aaa77bfcfbfb5ed019fd.json) |
| requiredHook | `0x0a6e9d3e672b281f3351aaa77bfcfbfb5ed019fd` | [12053674](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/516baafdf932e41d9f22b49a39cb325e37b801633bce282dcee933f0cb92ea3f-0a6e9d3e672b281f3351aaa77bfcfbfb5ed019fd.json) |
| nativeRouterDeployer | `0x62a9fb2f0df77aa0297dbc567079813ccf7c4ea1` | [12053694](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/9ef0e0413751d06896b32fbdea22dd233b8f2831a7ee57baac3468ffa6937a44-62a9fb2f0df77aa0297dbc567079813ccf7c4ea1.json) |
| syntheticRouterDeployer | `0x511ebf6ce53781c279e88ecf7681f0ea59cc4cad` | [12053719](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/3dd79d903bf31912e6a7d81dcfc960e5e2d2bcd7b1d392c740551bcb7a4cb06e-511ebf6ce53781c279e88ecf7681f0ea59cc4cad.json) |
| collateralRouterDeployer | `0x6e886a9c17bea13190a2dc26a4c61e1a258d608e` | [12053745](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/d2daac47651ce0ab165068b5b7a863fd457a73dcabd6ac570ca60acfdcd554bb-6e886a9c17bea13190a2dc26a4c61e1a258d608e.json) |
| factory | `0x0e657364c1a82ecb4c62d16e8c4560d95610fe56` | [12053771](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/f5f0c153f64e94425c036701227b9309312005dd2904be69b0901d6f2286e2df-0e657364c1a82ecb4c62d16e8c4560d95610fe56.json) |
| sourceRegistry | `0xea887a7f2f519f291732aaadf578baf3ff374df6` | [12053797](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/369ce335efd63fa2d2c39de4f8196955ed6e1e9d31bd8d518b180562e48634ab-ea887a7f2f519f291732aaadf578baf3ff374df6.json) |
| executionGateway | `0xedd68419d215c8e4fdc9fc5f0d63f824747bc176` | [12053833](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/f80fd00056d3a2b8253f45a56d320982c8968065eda62155ec9c720c310b0262-edd68419d215c8e4fdc9fc5f0d63f824747bc176.json) |

The ExecutionGateway is optional commercial infrastructure. `dispatchHook` and `requiredHook` identify the same zero-fee ProtocolFee hook in the Direct transport; no MerkleTreeHook is required.

### base

| Component | Address | Receipt block / evidence |
| --- | --- | --- |
| blsVerifier | `0x0e657364c1a82ecb4c62d16e8c4560d95610fe56` | [53026233](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/418f8efcb6dcc2ebdbcf16316a5251922e30cd5722c6e5913b51186bc71ee80a-0e657364c1a82ecb4c62d16e8c4560d95610fe56.json) |
| validatorRegistry | `0x3dc4cc1912792749d320789a67c2c14b7ee4ee33` | [53026281](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/c8b2547d9da5daa39cdf15e6d680825a8d4ada161bf0f7e9c286ba83982c0706-3dc4cc1912792749d320789a67c2c14b7ee4ee33.json) |
| ism | `0xedd68419d215c8e4fdc9fc5f0d63f824747bc176` | [53026311](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/80f52b736d67462514dd1f4a251266ca12a2ca1d6576789fe5fa74b33471d8ad-edd68419d215c8e4fdc9fc5f0d63f824747bc176.json) |
| transportBundle | `0x7bc756993559a26bac564fdf4abc5a5dabbf4849` | [53026338](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/109e957cc801a5164d7257ac4fe415f10948d03257c516c429ef7f455bcedfe8-7bc756993559a26bac564fdf4abc5a5dabbf4849.json) |
| mailbox | `0xa77c34aa23d190c71a1d0b9d4ac469b0fb01b363` | [53026338](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/109e957cc801a5164d7257ac4fe415f10948d03257c516c429ef7f455bcedfe8-a77c34aa23d190c71a1d0b9d4ac469b0fb01b363.json) |
| dispatchHook | `0xe83d5ad3014c4d31584b87fd892f51969c385172` | [53026338](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/109e957cc801a5164d7257ac4fe415f10948d03257c516c429ef7f455bcedfe8-e83d5ad3014c4d31584b87fd892f51969c385172.json) |
| requiredHook | `0xe83d5ad3014c4d31584b87fd892f51969c385172` | [53026338](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/109e957cc801a5164d7257ac4fe415f10948d03257c516c429ef7f455bcedfe8-e83d5ad3014c4d31584b87fd892f51969c385172.json) |
| nativeRouterDeployer | `0x3617775089b94591a60316f63b200a5963b442ea` | [53026366](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/348f1902420b3c9af4fe00e761890bdeee6be64dd5819b5e6315fd4e9ec7d220-3617775089b94591a60316f63b200a5963b442ea.json) |
| syntheticRouterDeployer | `0x2dbdd19c9cd267ffe6830bb61f7988c140a7a75a` | [53026396](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/b69083ca7601b13fc972f0b3497d46932ca1492cd87a3d8da183acdc543e553b-2dbdd19c9cd267ffe6830bb61f7988c140a7a75a.json) |
| collateralRouterDeployer | `0x719e08364b4a1f04f6364dd81df0ca6456676c9c` | [53026443](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/47091c4b867bd6e97ab765bfab0d4b37455b9d72bfc6a15db422791d23fa1c8b-719e08364b4a1f04f6364dd81df0ca6456676c9c.json) |
| factory | `0x01ddcbbda44b2a7d72b6c5801b88cd36319cec94` | [53026472](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/1f259f1d894b77305d1a03ae29b2989d18d5ab470cc4c3532f81ea4af272130b-01ddcbbda44b2a7d72b6c5801b88cd36319cec94.json) |
| sourceRegistry | `0xf243093350b1b4ef8a9e3b0c13be3495297461b0` | [53026521](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/da05fb98fbc2cc8625d4a28e5e61dd2b9ce987acfa9ff3be612787dad561b4e5-f243093350b1b4ef8a9e3b0c13be3495297461b0.json) |
| executionGateway | `0x8910679c883b00e42f9c52fd6664571cd64833f4` | [53026984](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/99859eb9e20e848c566525226b2f371f31d675de1cfab6a39e1f8193e6420c59-8910679c883b00e42f9c52fd6664571cd64833f4.json) |

The ExecutionGateway is optional commercial infrastructure. `dispatchHook` and `requiredHook` identify the same zero-fee ProtocolFee hook in the Direct transport; no MerkleTreeHook is required.

### arbitrum

| Component | Address | Receipt block / evidence |
| --- | --- | --- |
| blsVerifier | `0x504f241c1c177d811021f6412a0c2474d410ec99` | [517835200](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/9e3b1de0f9c7bf7c8aea9de1f3cad5ce386ea7f8daf4575ce389687a45cea08b-504f241c1c177d811021f6412a0c2474d410ec99.json) |
| validatorRegistry | `0x1a6610cc7dd0d0f42e22c3608e025d891065814c` | [517835411](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/879889c27ff9693908a4dcdcb21b585be2ee4638ef610cf5a33f22d17d2f7218-1a6610cc7dd0d0f42e22c3608e025d891065814c.json) |
| ism | `0xcf7e1a877d919c1c8dba48b42a832bdb1042101f` | [517835602](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/6db840ad41ef56a4c9fbe960a71b483580c1816448fa69fb2bae074446390051-cf7e1a877d919c1c8dba48b42a832bdb1042101f.json) |
| transportBundle | `0x402d1eabd5b11e517688231a641d027376c6ed10` | [517835797](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/a940bb5e9a52a5715d347edceee8e2fdecbff31d4595232272a4b1e257f2dcb2-402d1eabd5b11e517688231a641d027376c6ed10.json) |
| mailbox | `0xd4c7665f3c984bfbbeca9e67e593a5bab3881fe3` | [517835797](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/a940bb5e9a52a5715d347edceee8e2fdecbff31d4595232272a4b1e257f2dcb2-d4c7665f3c984bfbbeca9e67e593a5bab3881fe3.json) |
| dispatchHook | `0xb58225ac533243b03bde6d38720310c24b1dd37a` | [517835797](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/a940bb5e9a52a5715d347edceee8e2fdecbff31d4595232272a4b1e257f2dcb2-b58225ac533243b03bde6d38720310c24b1dd37a.json) |
| requiredHook | `0xb58225ac533243b03bde6d38720310c24b1dd37a` | [517835797](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/a940bb5e9a52a5715d347edceee8e2fdecbff31d4595232272a4b1e257f2dcb2-b58225ac533243b03bde6d38720310c24b1dd37a.json) |
| nativeRouterDeployer | `0x2c7a18747fda9b8a3d98e8603ddab24a5248dcce` | [517836007](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/87a83fdb83920b3a0d05ac5f05f8e6a2700d083a02c0762184ae13b57bb7a1a8-2c7a18747fda9b8a3d98e8603ddab24a5248dcce.json) |
| syntheticRouterDeployer | `0x495eeac5e0ae1eba54fb30de31483929d847a5db` | [517836210](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/c9fbe83e0c9e5f8be2a1cd0ca62c6af8e15feaf9efaeba925ea0297dfddf80ea-495eeac5e0ae1eba54fb30de31483929d847a5db.json) |
| collateralRouterDeployer | `0xa91b1e7179a50f0d798d284676d3ba9ff705fe82` | [517836423](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/f72af354dbd5b67db03b415b61f9221ec0ff97f0a97bad16b1f25fc5be28899a-a91b1e7179a50f0d798d284676d3ba9ff705fe82.json) |
| factory | `0xa27eadcaf70631e29009019d390e48410a830e64` | [517836718](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/048d1697485ba89963c161b0142510c8d568fef500206d2e730a1a6f69ad3ffa-a27eadcaf70631e29009019d390e48410a830e64.json) |
| sourceRegistry | `0x51e3b684ed61fc88083497e475825a6cecaf21f5` | [517836903](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/278fb105f65918f0ae18ab64ce0766afe4f1c6c22ab2b56574ab7a6a63c8bd0b-51e3b684ed61fc88083497e475825a6cecaf21f5.json) |
| executionGateway | `0x64d9da5d8365069d79ea82344c4ce488bb6a72e7` | [517837223](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/eba76a6679996c7fd77268b521fe03c0fc09e48cdfc56a47e27fa3b563169147-64d9da5d8365069d79ea82344c4ce488bb6a72e7.json) |

The ExecutionGateway is optional commercial infrastructure. `dispatchHook` and `requiredHook` identify the same zero-fee ProtocolFee hook in the Direct transport; no MerkleTreeHook is required.

## 3. Asset representations

### XGR

Canonical Asset ID: `0xa7585b8fbd074c1a7fa6df8b8e2e5ce73395ccbb64bf99b631c5da8ff2ac44e0`.

| Chain | Role | Address | Evidence |
| --- | --- | --- | --- |
| arbitrum | syntheticRouter | `0x5a31a62bb6441b499718df8fb767b6286267c74b` | [Receipt](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/c49aefb248efe523f37d0d204aa1c728b1b4bfe7b496d01f502311ac12fb914e-5a31a62bb6441b499718df8fb767b6286267c74b.json) |
| base | syntheticRouter | `0xd7443427ca21ae0907d2aa55446470307c990092` | [Receipt](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/9b840802054acf3ee49a4491544318076f5cb55b00b2b8a49544cd0fc410771a-d7443427ca21ae0907d2aa55446470307c990092.json) |
| xgrchain | nativeRouter | `0x7d9354baab0bf308d17e90ee3895609680e355ed` | [Receipt](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/b56c020cec2fd1e7d6c0e64859afc4c87f91dee5768a88dcc3f8d4de06ed0b54-7d9354baab0bf308d17e90ee3895609680e355ed.json) |

### ARB

Canonical Asset ID: `0xb913a68b77dc8b9df32e6e7d6158dfd4abb3b2c57fd127321c2727a17c207528`.

| Chain | Role | Address | Evidence |
| --- | --- | --- | --- |
| arbitrum | collateralRouter | `0x76f5d761ae41116ba5fa2ecb358e5fad15e0d992` | [Receipt](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/arbitrum/5c7eb172bb556a70126a0a68f3d0c60fdf1f78f7941f3624c050d83f9ab8386f-76f5d761ae41116ba5fa2ecb358e5fad15e0d992.json) |
| base | syntheticRouter | `0xc78929dc2d877ced57034319c3f162407cd605b9` | [Receipt](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/base/96627a097fd66348fea3dfc4d9bb8607e5d75eb4cb1b0bbfc41e8dac90838fa8-c78929dc2d877ced57034319c3f162407cd605b9.json) |
| xgrchain | syntheticRouter | `0x96940e83d3096eb868541adf29aa8da44a783e85` | [Receipt](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/receipts/xgrchain/97a3cfbea2351277f4464f87eaa500ca4ed04f86c94f84ea52da3c451c9db5d6-96940e83d3096eb868541adf29aa8da44a783e85.json) |

## 4. Recorded directed routes

Each row is a separate source operation. Reverse direction has its own route ID/Gateway/vault. This snapshot contains four directions per recorded asset, not one global route.

| Asset / direction | Full route ID | Gateway | FeeVault |
| --- | --- | --- | --- |
| [XGR: xgrchain → arbitrum](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/a7/XGR/routes/1b75cf1eb34fa922258e4d4f1fc8d2d5e181cfde74c0bc307498147dcd56e7a2.json) | `0x1b75cf1eb34fa922258e4d4f1fc8d2d5e181cfde74c0bc307498147dcd56e7a2` | `0xd79fca769f7ecd45593411abb905cb93dd0230f7` | `0x17eb63cc1af0c1a206781e3b4ad7faa1e3c3fbc7` |
| [XGR: xgrchain → base](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/a7/XGR/routes/34147bb992614ff3b01fb4be16fff55d9be7f7973f74d567c4b9a7a53e4f92fb.json) | `0x34147bb992614ff3b01fb4be16fff55d9be7f7973f74d567c4b9a7a53e4f92fb` | `0x44a479f722cb146ccb1dffa46e297879ab76268d` | `0xc2fd91639964d91e069225f2a08e70f1c0228eed` |
| [XGR: arbitrum → xgrchain](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/a7/XGR/routes/6b8b2d38524393eea76cda62f54300d169d4834bd8e8eb18644f2e1f7f2c105a.json) | `0x6b8b2d38524393eea76cda62f54300d169d4834bd8e8eb18644f2e1f7f2c105a` | `0x88da20e5ae14c2ec48c3b3069f0d88a33f5849db` | `0x834291e15b9db12b599bfc201ad5516490776d7f` |
| [XGR: base → xgrchain](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/a7/XGR/routes/7c10670b7cc28d27d88805d8eef081ef2ec50f5a7e69ca50864c057b16d94e0a.json) | `0x7c10670b7cc28d27d88805d8eef081ef2ec50f5a7e69ca50864c057b16d94e0a` | `0xeeb21da92aaeca479009346c8f27f2fd4d3571f3` | `0xdf4289e8037c736955127af53371e1002677b35f` |
| [ARB: xgrchain → base](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/b9/ARB/routes/32fbba0d007fcdae2e5cef59701691dd8b00e40144c5ffa3199c393b34176312.json) | `0x32fbba0d007fcdae2e5cef59701691dd8b00e40144c5ffa3199c393b34176312` | `0x6084f3136d6d9563f19acd41a8afb3020cd2859f` | `0x1c5ba6dcc7ed4caa8748462789b6eb5df494e1cd` |
| [ARB: arbitrum → xgrchain](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/b9/ARB/routes/49f483f6b1014e24a60955d33ce662104ca70b2cf142527f969b72517b578f40.json) | `0x49f483f6b1014e24a60955d33ce662104ca70b2cf142527f969b72517b578f40` | `0xa979d979d1f9aab0e246b307b8192620310a9d18` | `0x21c248434512378906cc19c70e6401d65247b048` |
| [ARB: xgrchain → arbitrum](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/b9/ARB/routes/4c5c82424f051f210ee1383a60fb1d2d84c4e12187fb285485664030554abeba.json) | `0x4c5c82424f051f210ee1383a60fb1d2d84c4e12187fb285485664030554abeba` | `0x731dd9a0417810013b2958555c79038dfb93aa90` | `0xc60375387eb571e0fd58e518b89619eaec4a8da3` |
| [ARB: base → xgrchain](https://github.com/xgr-network/xgr-interchain/blob/9518472c04432c57a5939a3688e90be332180636/deployments/assets/b9/ARB/routes/acd9cc536b3f809a8d40c34a554557d9341b8db032ad087ec3c7ce0ad6f01e83.json) | `0xacd9cc536b3f809a8d40c34a554557d9341b8db032ad087ec3c7ce0ad6f01e83` | `0xa2785616b468a92829c48806fbd2cd22be37ffb4` | `0xc1349b7c7bef9e49e314716d1e28f2b5a4aced04` |

## 5. Verification procedure

1. Verify RPC `eth_chainId`, canonical deployment receipt status/hash/block and expected contract address/Factory provenance. Read runtime bytecode and compare Keccak-256 with the reviewed receipt and artifact, accounting for the verified compiler/constructor build.
2. Match shared transport: Mailbox local domain, default/required hook, default ISM and ISM validator Registry. Check compiled node Registry/source Registry identities.
3. Match Factory/source Registry and the route tuple, asset metadata, router token and Creator provenance. Recompute Asset/Route IDs from exact ABI encoding.
4. Match Gateway immutable Registry/route/domain/router/token and FeeVault Gateway/route/domain/governance registry. The cumulative Gateway fee counter is not a balance proof.
5. Verify destination reciprocal route and `verifyInboundRoute`, current set/key format and available escrow; quote the exact recipient/amount before use.
6. After a transfer retain both canonical source identity and confirmed destination execution evidence. A deployment receipt does not prove transfer E2E, current quorum, production service rollout or sufficient native gas.

## 6. Updating records

Public receipt files are append-only evidence. Do not replace a historical receipt to make it look current. Record new identities through the verified deployment/receipt workflow, regenerate catalog and documentation from the same reviewed revision, and re-evaluate compiled policy when shared network infrastructure changes. Do not publish secrets or applicant contact details.

This generated inventory checked 60 component/representation/route references against their existing receipt address, chain and recorded runtime hash. This is internal record consistency, not a new RPC bytecode verification.
