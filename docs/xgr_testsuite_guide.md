# XGR Test Suite Deep HowTo

The XGR Test Suite is the workspace for building, validating, deploying, running and reviewing reproducible XGR test cases. It connects bundle import, test plan editing, signer alias preparation, setup contracts, multi-session scenarios, BundleDeploy handoff, Start Sessions execution and result analysis in one guided flow.

Use this guide to understand the full workflow from an imported XRC-137 / XRC-729 bundle to a runnable test plan. It explains how to configure runtime payloads, owner and executor aliases, setup contracts, expected timeline checks, API save checks, contract read checks and scenario wake-up flows so a user can create reliable tests without knowing the internal implementation.

All screenshots are stored under `pictures/ui/test-suite/`.

---

## 1. First orientation: the three top menu cards

The Test Suite starts with three cards:

| Card | What the user does there |
|---|---|
| **Wallet connect** | Connect or switch the active wallet, check chain and RPC context. |
| **Signer context** | Prepare the local signer and named alias signers. |
| **Action** | Choose the workbench, for example Bundle import, Plan import or Scenarios. |

![Top menu overview](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/01-top-menu-overview.png)

### Wallet connect

Use **Wallet connect** before every deploy or run.

Steps:

1. Open **Wallet connect**.
2. Connect the browser wallet.
3. Check that the connected address is the expected one.
4. Check the selected network.
5. Check RPC and explorer settings.
6. Continue only when wallet and network match the contracts you want to use.

![Wallet connect](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/02-wallet-connect.png)

### Signer context

Use **Signer context** when a plan uses named actors or aliases. This is important for multi-user tests, scenario runs and tests where owner, starter and executor are not the same identity.

The scenario example uses two actor aliases:

| Alias | Used for |
|---|---|
| `owner` | Order process plan |
| `owner1` | KYC worker plan |

To prepare aliases:

1. Open **Signer context**.
2. Select **Alias signers**.
3. Click **Suggest aliases from imported plans**.
4. Add missing aliases manually with **+ Add New Signer**.
5. Store the private key or seed encrypted.
6. Unlock the alias for the required TTL.
7. Confirm that no required alias is shown as missing or locked.

A plan cannot be handed to Start Sessions if required aliases are missing or locked.

![Signer context](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/03-signer-context.png)

### Action

Open **Action** and select what you want to do next.

| Action | Use case |
|---|---|
| **Bundle import** | Start with a bundle JSON and create local plans. |
| **Plan import** | Start with exported test plan JSON files. |
| **Scenarios** | Build or run multi-session scenarios. |
| **Compare results** | Compare two exported result bundles. |
| **Analyze results** | Inspect one result bundle deeply. |

![Action selector](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/04-action-selector.png)

---

## 2. Import data into the Test Suite

### Bundle import

Use **Bundle import** if you start from a bundle and want the Test Suite to create a local test plan.

Steps:

1. Open **Action**.
2. Select **Bundle import**.
3. In **Import bundle workspace**, choose **File import** or **JSON import**.
4. Load one or multiple bundle JSON files.
5. Open **Review prepared bundles**.
6. Select one prepared bundle.
7. Check the summary: steps, rules, API calls, contract reads, payload fields, onValid/onInvalid outputs and execution contracts.
8. Click **Create this plan** to create one local plan.
9. Use **Create all plans** when every prepared bundle should become a local plan.
10. Use **Deploy selected** when the prepared bundle should first go through BundleDeploy.

![Bundle import](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/05-bundle-import.png)

![Review bundle and create plan](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/06-review-bundle-create-plan.png)

### Plan import

Use **Plan import** if you already have exported test plans.

Steps:

1. Open **Action**.
2. Select **Plan import**.
3. Choose **File import** or **JSON import**.
4. Drop the JSON file or click **Open file system**.
5. The imported plan appears in **Manage test plans**.

This works for one plan or many plans in one file.

![Plan import](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/13-plan-import.png)

### Create one multi-plan file

To combine several plans into one file:

1. Import or create all local plans.
2. Check the plans in **Manage test plans**.
3. Open **Export Plans**.
4. Click **Export selected**.
5. The downloaded JSON contains all checked plans.

Use this for customer handoff, regression packs, or reusable test collections.

![Action bar multi export](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/08-action-bar-multi-export.png)

---

## 3. Manage local test plans

The **Manage test plans** area is the central working area after import.

Toolbar actions:

| Toolbar tab | Button | What it does |
|---|---|---|
| **Run Plans** | Run selected | Opens checked plans for execution. |
| **Run Plans** | Run all filtered | Runs all currently filtered plans. |
| **Select Plans** | Select filtered | Checks all plans matching the current filter. |
| **Select Plans** | Clear selected | Clears the current checked selection. |
| **Export Plans** | Export selected | Exports checked plans into one JSON file. |
| **Export Plans** | Save bundles to Contract Manager | Extracts embedded bundles from selected plans and saves them to Contract Manager. |
| **Edit Plans** | Add plan JSON | Imports additional plan JSON into the local workspace. |
| **Edit Plans** | Replace selected | Replaces exactly one selected plan with another imported plan. |
| **Edit Plans** | Delete selected | Removes checked local plans. |
| **Edit Plans** | Delete filtered | Removes all filtered local plans. |
| **Bundle Sync** | Rebind selected | Rebinds selected plans to a newly deployed bundle. |
| **Bundle Sync** | Validate selected | Validates selected plans against a bundle. |
| **Bundle Sync** | Deploy bundles | Opens deploy flow for selected plans. |

![Manage test plans](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/07-manage-plans.png)

---

## 4. Runtime configuration

Open one local plan. The editor has three main tabs:

- **Runtime**
- **Expectations**
- **Setup contracts**

### Runtime → Start setup

Start setup defines how the session starts.

Example from the scenario order plan:

| Field | Value |
|---|---|
| Start step | `receive_order` |
| Starter alias | `owner` |
| Expected final step | `fulfill_order` |
| Expected final status | `done` |
| Max total gas | `0` |

Steps:

1. Select the plan.
2. Open **Runtime**.
3. Open **Start setup**.
4. Choose the start step.
5. Enter the starter alias.
6. Choose expected final step.
7. Select expected final status.
8. Save the plan.

![Runtime start setup](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/09-runtime-start-setup.png)

### Runtime → Payload

Payload is the data sent into the start step.

Example from the order scenario start payload:

```json
{
  "orderId": "ORD-KYC-1001",
  "customerId": "CUST-KYC-1001",
  "cartId": "CART-1001",
  "totalAmount": 19900,
  "currency": "EUR",
  "applicantConsent": true
}
```

How to fill payload values:

1. Open **Runtime**.
2. Select **Payload**.
3. Find the field from the start step schema.
4. Enter the value:
   - string: `ORD-KYC-1001`
   - number: `19900`
   - boolean: `true` or `false`
   - object/array: valid JSON
5. Use the default toggle only when the schema default should be used.
6. Save the plan.

For the contract read example, enter:

| Field | Value |
|---|---|
| AmountA | `50` |
| AmountB | `5` |

### Runtime → Aliases

Aliases define who owns, starts and executes the plan.

| Field | Meaning |
|---|---|
| Owner alias | Signer used for owner/setup/grant/deployment-related actions. |
| Starter alias | Signer used to start the session. |
| XRC-729 executor aliases | Signers allowed to execute the orchestration. |
| XRC-137 executors · contract alias | Signers allowed to execute a specific rule contract. |

Example:

| Plan | Owner alias | Starter alias |
|---|---|---|
| `Order KYC wakeup process - valid KYC path - no callback trigger - v8` | `owner` | `owner` |
| `KYC worker wakeup process - valid path - no callback trigger - v8` | `owner1` | `owner1` |

How to set custom executors:

1. Open **Runtime**.
2. Select **Aliases**.
3. Enter **Owner alias**.
4. Enter **Starter alias**.
5. Enter XRC-729 executors separated by commas.
6. Enter XRC-137 executors per contract alias.
7. Open **Signer context → Alias signers**.
8. Ensure all aliases are stored and unlocked.
9. Save the plan.

![Runtime aliases](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/10-runtime-aliases.png)

---

## 5. Setup contracts for contract reads

Use **Setup contracts** when a test needs a helper contract deployed or supplied before the run.

Contract read example:

| Field | Value |
|---|---|
| Plan | `xrc137_contractread_value_eq__valid` |
| Address key | `readContract` |
| Contract read target | `${addr:readContract}` |
| Function | `getValue()(int256)` |
| Saved read alias | `readValue` |
| Deploy signer alias | `owner` |

The XRC-137 reads from `${addr:readContract}`. The setup contract must therefore create or provide the address behind `readContract`.

Steps to configure a setup contract:

1. Open the plan.
2. Click **Setup contracts**.
3. Click **Add setup contract** if no setup contract exists.
4. Set **Address key** to `readContract`.
5. Set **Mode** to **Deploy Solidity**.
6. Set **Contract name** to `readContract`.
7. Paste the Solidity source.
8. Keep **Constructor args JSON** as `[]` if there is no constructor.
9. Set **Deploy signer alias** to `owner`.
10. Save the plan.
11. Deploy or run through the flow that resolves setup placeholders.

The relevant Solidity function in the example is:

```solidity
function getValue() public pure returns (uint256) { return 42; }
```

![Setup contracts](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/11-setup-contracts.png)

---

## 6. Expectations

Expectations define what must happen during execution.

### Timeline checks

A timeline entry checks one expected step occurrence.

| Field | Example | Meaning |
|---|---|---|
| Group label | `fulfill_order #1` | Readable label for the expectation. |
| Match mode | `allOf` | All alternatives must match. |
| Step | `fulfill_order` | Step id to check. |
| Occurrence | `1` | Which occurrence of the step to check. |
| Expect step | `exists` / `not exists` | Whether the step should appear. |
| Expected valid | `true` / `false` / `any` | Whether the rule result must be valid. |
| Expected status | `done` / `waiting` / any | Optional status expectation. |

Order process example:

| Step | Expect step | Expected valid | Expected status |
|---|---|---|---|
| `receive_order` | exists | true | any |
| `request_kyc` | exists | true | done |
| `wait_for_kyc_result` | exists | true | any |
| `fulfill_order` | exists | true | done |
| `cancel_order` | not exists | any | any |

Steps to create a timeline entry:

1. Open **Expectations**.
2. Click **Add expected step**.
3. Select the new row.
4. Enter **Group label**.
5. Choose **Match mode**.
6. Select **Step**.
7. Enter **Occurrence**.
8. Set **Expect step**.
9. Set **Expected valid**.
10. Set **Expected status** if needed.
11. Save the plan.

![Expectations](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/12-expectations.png)

### Input payload checks

Input payload checks verify the actual input payload of a step.

Contract read example checks:

| Field | Operator | Expected value |
|---|---|---|
| AmountA | = | `50` |
| AmountB | = | `5` |

Steps:

1. Open **Expectations**.
2. Select timeline entry `A1 #1`.
3. Open **Input payload checks**.
4. Click **Add payload field**.
5. Select field `AmountA`.
6. Select operator `=`.
7. Enter expected value `50`.
8. Click **Add payload field** again.
9. Select `AmountB`.
10. Select operator `=`.
11. Enter expected value `5`.
12. Save the plan.

### API saves checks

API saves checks verify values saved from an API response.

API example:

| Item | Value |
|---|---|
| URL | `https://api.test.xgr.network/slow` |
| Extract aliases | `Ok, notOk` |
| Expected check | `Ok = true` |

Steps:

1. Open **Expectations**.
2. Select timeline entry `A1 #1`.
3. Open **API SAVES CHECKS**.
4. Click **Add check**.
5. Select field `Ok`.
6. Select operator `=`.
7. Enter `true`.
8. Save the plan.

If no field is available, the selected step does not have API extract aliases.

### Contract read checks

Contract read checks verify values saved from `contractReads.saveAs`.

Contract read example:

| Item | Value |
|---|---|
| Target | `${addr:readContract}` |
| Function | `getValue()(int256)` |
| Saved alias | `readValue` |
| Expected value | `42` |

Steps:

1. Open **Expectations**.
2. Select timeline entry `A1 #1`.
3. Open **CONTRACT READ CHECKS**.
4. Click **Add check**.
5. Select field `readValue`.
6. Select operator `=`.
7. Enter `42`.
8. Save the plan.

---

## 7. Scenarios

Use **Scenarios** when several sessions must work together. A scenario can import or reuse test plans, define actor aliases, set payload data, configure wake-up rules, validate the whole scenario package and then run a multi-session flow.

Scenario example:

| Plan key | Bundle | Start step | Actor | Final step |
|---|---|---|---|---|
| `order_process` | `order_kyc_bestellprozess_v1` | `receive_order` | `owner` | `fulfill_order` |
| `kyc_worker` | `kyc_order_wakeup_process_v1` | `arm_kyc_request` | `owner1` | `notify_order_kyc_valid` |

### Scenario import and sources

Use **Scenario import** when the scenario JSON already contains the scenario, embedded plans and bundle data.

Steps:

1. Open **Action → Scenarios**.
2. Use the import area to load a scenario JSON file.
3. Check the detected scenario title.
4. Check the imported plan count and bundle count.
5. Save or replace the local Test Suite workspace when the scenario should be the active working set.

![Scenario import](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-import.png)

Use **Sources** to inspect which scenario JSON, embedded plans and bundle source data were imported.

![Scenario sources](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-sources.png)

### Scenario flow menu

The scenario flow is split into dedicated editing areas. Work left to right:

| Area | Purpose |
|---|---|
| **Data / WakeUp** | Runtime payload data and wake-up permissions. |
| **Sessions** | `startSession` and `waitForStep` flow steps. |
| **Timeline checks** | Expected steps and statuses inside sessions. |
| **Asserts** | Final session assertions. |
| **Validate / Export** | Validate the scenario and export the package. |
| **Run** | Start and monitor the scenario run. |

![Scenario flow menu](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-Flow-Menu.png)

### Data and WakeUp

The scenario uses `__wakeUp` in the start payload. This allows one session to wake a waiting step in another session.

Example:

```json
"__wakeUp": {
  "steps": {
    "wait_for_kyc_result": {
      "internal": {
        "allow": ["$actor.address:owner1"],
        "fromXRC137": ["$contract.address:kyc_worker:NotifyOrderKycValid"]
      }
    }
  }
}
```

Meaning:

- `wait_for_kyc_result` is the waiting step.
- `owner1` is allowed to perform the wake-up.
- The wake-up must come from the `NotifyOrderKycValid` XRC-137 contract in the `kyc_worker` plan.

![Scenario Data and WakeUp](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-DataAndWakeup-PayloadAndWakeup.png)

### Session flow steps

The scenario uses these step types:

| Step type | What it does |
|---|---|
| `startSession` | Starts a session from a plan. |
| `waitForStep` | Waits until a session step reaches a status. |
| `assertSession` | Checks the final session result and timeline. |

Example flow:

1. Start KYC worker with `arm_kyc_request` as `owner1`.
2. Wait until the KYC worker reaches `wait_for_kyc_request` with status `waiting`.
3. Start order process with `receive_order` as `owner`.
4. Wait until `request_kyc` is done.
5. Wait until `wait_for_kyc_result` is waiting.
6. Wait until the KYC worker sends `notify_order_kyc_valid`.
7. Assert the order session final step `fulfill_order`.
8. Assert the KYC worker final step `notify_order_kyc_valid`.

![Scenario session flow](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-Flow-Sessions.png)

### Timeline checks and asserts

Timeline checks define which steps are expected during a session and with which status. Use them to check that positive paths appear and negative paths do not appear.

![Scenario timeline checks](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-Flow-Sessions-TimelineChecks.png)

Asserts validate the final state of a session, for example final status and final step.

![Scenario asserts](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-Flow-Sessions-Asserts.png)

### Validate, export and run

Before running or sharing a scenario:

1. Validate the scenario package.
2. Confirm that all referenced plans, actors, bundles and wake-up references resolve.
3. Export the scenario package if another user should run the same flow.
4. Run the scenario from the Run panel.

![Validate and export scenario](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-ValidateAndExport.png)

![Scenario run empty](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-run.png)

When the scenario is running or finished, use the graph and detail panel to inspect the current state.

![Scenario run filled](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-run-filled.png)

![Scenario run expanded view with details](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-run-Expand-View-with-Details.png)

### Review scenario results in List Sessions

After a scenario run, the results can be inspected in **List Sessions** and the **Testplan monitor**. Use this to review the step monitor, receipt details and final status after leaving the scenario runner.

![Scenario result in List Sessions monitor](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-run-Result-in-Listsession-Testplanmonitor.png)

![Scenario result monitor detail](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/16-scenarios-run-Result-in-Listsession-Testplanmonitor-Detail.png)

---

## 8. Deploy from Test Suite and return

You can deploy a plan bundle directly from the Test Suite flow.

Steps:

1. Select the local plan.
2. Open the selected plan action bar.
3. Open **Export Plan**.
4. Click **Save bundle to Contract Manager** or **Deploy bundle**.
5. In BundleDeploy, confirm the bundle.
6. Confirm deploy owner alias.
7. Deploy.
8. Return to Test Suite.
9. Use **Bundle Sync → Rebind selected** if addresses changed.
10. Use **Validate selected** to verify the plan against the new deployed bundle.
11. Open in Start Sessions or run the selected plan.

![BundleDeploy](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/14-bundledeploy.png)

---

## 9. Run from the Test Suite

Steps:

1. Connect wallet.
2. Unlock all alias signers.
3. Select the plan.
4. Open **Run Plan**.
5. Click **Open in Start Sessions**.
6. Review the runtime draft.
7. Start the session.

![Start Sessions](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/15-start-sessions.png)

---

## 10. Compare results

Use **Compare results** when you have two exported run bundles and want to see how a candidate run differs from a baseline run.

The compare panel supports:

| Function | What it does |
|---|---|
| **Load result → Baseline bundle** | Imports the first result bundle. |
| **Load result → Candidate bundle** | Imports the second result bundle. |
| **Download compare report** | Downloads a structured comparison report after both sides are loaded. |
| **Structured / JSON view** | Switches between readable comparison cards and raw JSON diff view. |
| **Plan filter** | Shows all plans, only plans with differences, only errors, missing partner plans or clean plans. |
| **Current plan** | Selects the plan pair currently being compared. |
| **Step filter** | Shows only differences, changed steps, errors, all steps or unchanged steps. |
| **Prev / Next** | Moves through the filtered plan list. |
| **Summary** | Shows timeline changes, final changes and scenario changes. |
| **Final checks** | Compares final status and final step. |
| **Scenario assertion compare** | Compares scenario-level assertion output when available. |
| **Timeline diff** | Compares every matched step, including expectation changes and actual observed changes. |
| **Expand visible / Collapse visible** | Opens or closes the filtered timeline rows. |

The panel matches plans by title. If one side has no matching plan, it shows a missing partner warning.

![Compare results upload](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/17-compare-results.png)

![Compare results details](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/17-compare-results-details.png)

### What to check in a comparison

1. Load the old run as **Baseline bundle**.
2. Load the new run as **Candidate bundle**.
3. Use **Plan filter → Only plans with differences** to focus on changed plans.
4. Use **Step filter → Only changed steps** to focus on changed timeline entries.
5. Open changed steps and compare:
   - expected payload checks
   - expected API saves checks
   - expected contract read checks
   - actual payload checks
   - actual API saves checks
   - actual contract read checks
6. Download the compare report if the result should be archived or shared.

---

## 11. Analyze results

Use **Analyze results** when you want to inspect one exported result bundle deeply.

The analysis panel supports:

| Function | What it does |
|---|---|
| **Load result bundle** | Imports one compact or long result bundle. |
| **Download analysis** | Downloads a structured analysis JSON for the loaded result bundle. |
| **Status summary** | Shows overall status and passed/pending/failed plan counts. |
| **Plans summary** | Shows number of plans and percentage that passed. |
| **Assertions summary** | Shows passed assertions versus total assertions. |
| **Filtered rows** | Shows how many rows match the current filters. |
| **Categories** | Groups findings by category and status. |
| **Top findings** | Lists the most frequent findings. |
| **Status filter** | Shows Problems, Failed, Pending, Passed or All. |
| **Category filter** | Filters by result category. |
| **Finding filter** | Filters by specific finding reason. |
| **Search** | Searches title, bundle, session id, current status and current step. |
| **Table column filters** | Filters plan, category, status, current, checks and finding columns. |
| **Result detail** | Opens the selected row and shows structured expected-vs-actual data. |

Analyze is best for debugging a single run. It can help find:

- missing steps
- invalid steps
- wrong final step
- wrong final status
- failed input payload checks
- failed API saves checks
- failed contract read checks
- missing or locked aliases

![Analyze results](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/test-suite/18-analyze-results.png)

### Recommended analysis workflow

1. Load the result bundle.
2. Start with **Problems** to see failed or pending rows first.
3. Use **Category** and **Finding** to narrow the issue type.
4. Use table filters if the result bundle is large.
5. Open a row to inspect expected versus actual values.
6. Download the analysis JSON if the result should be shared with support or stored with a test report.

---

## 12. End-to-end recipes

### Recipe A: Contract read test

Goal: prove that the helper contract returns `42` and the rule validates.

1. Import `xrc137_contractread_value_eq__valid_multi_plan.json`.
2. Select `xrc137_contractread_value_eq__valid`.
3. Open **Setup contracts**.
4. Confirm address key `readContract`.
5. Confirm mode **Deploy Solidity**.
6. Confirm deploy signer alias `owner`.
7. Confirm the Solidity function `getValue()` returns `42`.
8. Open **Runtime → Start setup**.
9. Confirm start step `A1`.
10. Open **Runtime → Payload**.
11. Enter `AmountA = 50`.
12. Enter `AmountB = 5`.
13. Open **Expectations**.
14. Select `A1 #1`.
15. Add input check `AmountA = 50`.
16. Add input check `AmountB = 5`.
17. Add contract read check `readValue = 42`.
18. Deploy or rebind if needed.
19. Open in Start Sessions and run.

### Recipe B: API saves test

Goal: prove that the API response saved `Ok = true`.

1. Import `xrc137_api_slow_json_ok_valid_default_multi_plan.json`.
2. Select `xrc137_api_slow_json_ok_valid_default`.
3. Open **Runtime → Start setup**.
4. Confirm start step `A1`.
5. Keep payload empty.
6. Open **Expectations**.
7. Select `A1 #1`.
8. Open **API SAVES CHECKS**.
9. Click **Add check**.
10. Select `Ok`.
11. Select operator `=`.
12. Enter `true`.
13. Save and run.

### Recipe C: KYC scenario

Goal: run an order process and a KYC worker that wake each other.

1. Import the scenario JSON.
2. Confirm plans `order_process` and `kyc_worker`.
3. Prepare alias signer `owner`.
4. Prepare alias signer `owner1`.
5. Start the KYC worker first.
6. Wait until the KYC worker is ready.
7. Start the order process.
8. Let the order process wake the KYC worker.
9. Let the KYC worker wake the order result step.
10. Assert both sessions.
11. Confirm final steps `fulfill_order` and `notify_order_kyc_valid`.

---

## 13. Troubleshooting

### Alias warning before running

Fix:

1. Open **Signer context → Alias signers**.
2. Click **Suggest aliases from imported plans**.
3. Add missing aliases.
4. Unlock all required aliases.
5. Try again.

### API check has no selectable field

The selected step has no API extract alias. Select the correct timeline step or check the imported XRC-137 API extract map.

### Contract read check has no selectable field

The selected step has no `contractReads.saveAs` alias. Select the correct step or check the contract read configuration.

### Setup contract placeholder is not ready

The plan references `${addr:...}` but the matching setup contract is missing or not deployable.

Fix:

1. Open **Setup contracts**.
2. Add the missing key.
3. Provide Solidity source or fixed address.
4. Save.
5. Deploy/rebind again.

### Run reaches wrong final step

Open **Expectations**, check **Expected final step**, then compare timeline entries with the actual result.
