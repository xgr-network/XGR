# XGR Contract Reads (UI Guide)

This guide explains how to configure **Contract Reads** in the **XRC-137 Builder** UI. Contract Reads call **view/pure** functions on EVM-compatible contracts and expose the returned values as reusable placeholders.

---

## 1) What a Contract Read does

A Contract Read performs an on-chain call against a contract address (**To**) and a function signature (**Function**).  
Returned values are stored via **Save As** and can be referenced later using placeholders like `[target]`.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-panel-main.png) — Contract Reads panel with one configured read and an “Add Read” button.

---

## 2) Fields in a Contract Read

### To
The target contract address to call.

- Expected format: `0x` + 40 hex characters (EVM address)

### Function
The function signature for the read in this format:

- `name(type1,type2,...)(ret1,ret2,...)`

Examples:
- `balanceOf(address)(uint256)`
- `balanceOf(address,address)(uint256,int256)`

### Args
Arguments passed to the function. Each argument has:

- `type` — the ABI input type (must match the function signature)
- `value` — a literal or a placeholder like `[address]`

### Save As
Maps return tuple indices to named outputs. Each return index (e.g. `"0"`, `"1"`) defines:

- `key` — the placeholder name you will use later (e.g. `[target]`)
- `type` — the payload type for the stored output (used by the builder/engine)
- `default` (optional) — used when the read does not produce a value for this output

### RPC (optional)
An optional RPC endpoint to use for this specific read.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-rpc-field.png) — RPC input field.

---

## 3) Save As and per-output Defaults

Each return value is mapped by its **tuple index**.

- Use `"0"` for the first return value, `"1"` for the second, etc.
- `key` names are case-sensitive and must be unique by exact spelling.
- `default` is optional and can be set per return value.

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-saveas.png) — Save As mapping table.  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-defaults.png) — Default values per output.

---

## 4) Placeholders

You can use placeholders inside **Args** and later throughout the builder.

- Payload fields become placeholders like `[address]`
- Contract Read outputs become placeholders based on `saveAs.*.key` (e.g. `[target]`)
- Other producers (e.g. API extracts) also appear in autocomplete where supported

---

## 5) JSON structure

Contract Reads live at the root under `contractReads`:

- `contractReads` is an array of read objects
- each read has `to`, `function`, `args`, optional `rpc`, and `saveAs`

### A) Contract Reads panel example (single arg, single return)

```json
{
  "contractReads": [
    {
      "args": [
        {
          "type": "address",
          "value": "[address]"
        }
      ],
      "function": "balanceOf(address)(uint256)",
      "saveAs": {
        "0": {
          "default": 0,
          "key": "target",
          "type": "int256"
        }
      },
      "to": "0x733083399533ebf2CfA3fF61322f0aab1Bf4Ac7C"
    }
  ],
  "onInvalid": {},
  "onValid": {},
  "payload": {
    "address": {
      "type": "address"
    }
  }
}
```

---

### B) Save As and Defaults example (two args, two returns)

```json
{
  "contractReads": [
    {
      "args": [
        {
          "type": "address",
          "value": "[address]"
        },
        {
          "type": "address",
          "value": "[address2]"
        }
      ],
      "function": "balanceOf(address,address)(uint256,int256)",
      "saveAs": {
        "0": {
          "key": "target",
          "type": "uint256"
        },
        "1": {
          "default": 200,
          "key": "target1",
          "type": "uint256"
        }
      },
      "to": "0x733083399533ebf2CfA3fF61322f0aab1Bf4Ac7C"
    }
  ],
  "onInvalid": {},
  "onValid": {},
  "payload": {
    "address": {
      "type": "address"
    },
    "address2": {
      "type": "address"
    }
  }
}
```

---

### C) RPC field example

```json
{
  "contractReads": [
    {
      "args": [
        {
          "type": "address",
          "value": "[address]"
        },
        {
          "type": "address",
          "value": "[address2]"
        }
      ],
      "function": "balanceOf(address,address)(uint256,int256)",
      "rpc": "https://rpc.xyz.com",
      "saveAs": {
        "0": {
          "key": "target",
          "type": "uint256"
        },
        "1": {
          "default": 200,
          "key": "target1",
          "type": "uint256"
        }
      },
      "to": "0x733083399533ebf2CfA3fF61322f0aab1Bf4Ac7C"
    }
  ],
  "onInvalid": {},
  "onValid": {},
  "payload": {
    "address": {
      "type": "address"
    },
    "address2": {
      "type": "address"
    }
  }
}
```

---

## 6) Examples

**What you see**  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-examples-cards-1.png) — Example card (single return).  
![](https://raw.githubusercontent.com/xgr-network/XGR/main/pictures/ui/builder137/reads-examples-cards-2.png) — Example card (two returns).

### Example 1

```json
{
  "contractReads": [
    {
      "args": [
        {
          "type": "address",
          "value": "[address]"
        }
      ],
      "function": "balanceOf(address)(uint256)",
      "rpc": "https://rpc.xyz.com",
      "saveAs": {
        "0": {
          "default": 200,
          "key": "target",
          "type": "uint256"
        }
      },
      "to": "0x733083399533ebf2CfA3fF61322f0aab1Bf4Ac7C"
    }
  ],
  "onInvalid": {},
  "onValid": {},
  "payload": {
    "address": {
      "type": "address"
    },
    "address2": {
      "type": "address"
    }
  }
}
```

### Example 2

```json
{
  "contractReads": [
    {
      "args": [
        {
          "type": "address",
          "value": "[address]"
        },
        {
          "type": "address",
          "value": "0x733083399533ebf2CfA3fF61322f0aab1Bf4Ac7C"
        }
      ],
      "function": "balanceOf(address,address)(uint256,uint256)",
      "rpc": "https://rpc.xyz.com",
      "saveAs": {
        "0": {
          "default": 200,
          "key": "target",
          "type": "uint256"
        },
        "1": {
          "key": "target2",
          "type": "uint256"
        }
      },
      "to": "0x733083399533ebf2CfA3fF61322f0aab1Bf4Ac7C"
    }
  ],
  "onInvalid": {},
  "onValid": {},
  "payload": {
    "address": {
      "type": "address"
    },
    "address2": {
      "type": "address"
    }
  }
}
```

---

## 7) Tips

- Keep `function` and `args[*].type` consistent (same ABI types, same order).
- Prefer placeholders in args for user-driven inputs (e.g. `[address]`).
- Use `saveAs` keys that clearly communicate meaning (e.g. `balance`, `threshold`, `isAllowed`).
- Set `default` when downstream rules/outcomes should continue even when a read output is not available.
