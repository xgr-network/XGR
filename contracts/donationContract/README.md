# XGreen Donation Distributor

Smart contract for distributing native XGR from the blockchain's fee-split treasury to registered NGOs.

## Overview

The XGR Network allocates a configurable percentage of transaction fees to a treasury address. This contract receives those funds and distributes them to environmental NGOs based on configurable weights.

```
Transaction Fees → Fee-Split → Treasury (this contract) → NGOs
```

## Features

- **Weighted Distribution**: Each NGO receives funds proportional to their assigned weight
- **Permissionless Execution**: Anyone can trigger distribution once conditions are met
- **Configurable Parameters**: Minimum interval and amount adjustable by owner
- **Full Transparency**: All distributions emit events for on-chain tracking

## Contract Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `minInterval` | 7 days | Minimum time between distributions |
| `minDistributionAmount` | 1000 XGR | Minimum balance required to distribute |

## Usage

### Check Distribution Status

```solidity
DistributionStatus memory status = distributor.getDistributionStatus();

// status.ready          - true if distribution can be triggered
// status.remainingTime  - seconds until minInterval is satisfied
// status.missingAmount  - XGR needed to reach minDistributionAmount
// status.currentBalance - current contract balance
```

### Trigger Distribution

```solidity
// Anyone can call this once conditions are met
distributor.distribute();
```

### Manage NGOs (Owner Only)

```solidity
// Add a new NGO
distributor.addNGO(
    0x1234....,     // wallet address
    100,            // weight
    "Green Earth",  // name
    "https://..."   // url
);

// Update existing NGO
distributor.updateNGO(0, wallet, weight, name, url);

// Replace all NGOs
distributor.setNGOs(ngoArray);
```

### Update Parameters (Owner Only)

```solidity
distributor.setMinInterval(14 days);
distributor.setMinDistributionAmount(500 ether);
```

## Events

| Event | Description |
|-------|-------------|
| `DonationReceived` | Emitted when contract receives XGR |
| `DonationDistributed` | Emitted for each NGO payment |
| `NGOAdded` | New NGO registered |
| `NGOUpdated` | Existing NGO modified |
| `NGOsReset` | NGO list replaced |
| `MinIntervalUpdated` | Interval parameter changed |
| `MinDistributionAmountUpdated` | Amount parameter changed |
| `EmergencyWithdraw` | Emergency withdrawal executed |

## Security

- Only owner can manage NGOs and parameters
- Distribution logic is permissionless but protected by time and amount thresholds
- Emergency withdrawal available for owner in case of issues
- Based on battle-tested OpenZeppelin Ownable pattern

## Dependencies

- `Ownable.sol` - Access control (OpenZeppelin standard)
- `Context.sol` - Message context abstraction (OpenZeppelin standard)

## License

MIT

---

Part of the [XGR Network](https://xgr.network) infrastructure.
