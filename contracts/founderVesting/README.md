# Founder Vesting

Smart contract for linear 4-year vesting of native XGR tokens for founding team members.

## Overview

This contract manages the vesting schedule for the four XGR Network founders. It implements a simple linear vesting model without cliff, allowing founders to claim their vested tokens continuously over the vesting period.

```
Vesting Start                                              Vesting End
     │                                                           │
     ▼                                                           ▼
     ├───────────────────────────────────────────────────────────┤
     │              Linear vesting over 4 years                  │
     │                                                           │
     │  ████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
     │  ▲                          ▲                             │
     │  Vested (claimable)         Unvested (locked)             │
     └───────────────────────────────────────────────────────────┘
```

## Key Features

- **Linear Vesting**: Tokens vest continuously, no step functions
- **No Cliff**: Vesting begins immediately at start timestamp
- **Self-Service Claims**: Founders call `release()` to claim vested tokens
- **Address Recovery**: Founders can migrate to a new wallet if compromised
- **Multi-Founder**: Single contract manages all four founders efficiently
- **No Admin**: Fully autonomous after deployment, no owner privileges

## Vesting Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Duration | 4 years | 126,144,000 seconds |
| Cliff | None | Vesting starts immediately |
| Schedule | Linear | Proportional to time elapsed |
| Founders | 4 | Fixed at deployment |

## Vesting Formula

```
vested = totalAmount × (elapsedTime / vestingDuration)

where:
  elapsedTime = now - vestingStart
  
Claimable = vested - alreadyReleased
```

## Usage

### View Functions

```solidity
// Get complete vesting info for a founder
(uint256 total, uint256 vested, uint256 released, uint256 releasable) 
    = vesting.getVestingInfo(founderAddress);

// Individual queries
uint256 vested = vesting.vestedAmount(founderAddress);
uint256 claimable = vesting.releasableAmount(founderAddress);

// Global progress (basis points, 10000 = 100%)
uint256 progressBps = vesting.vestingProgressBps();

// Contract balance
uint256 balance = vesting.contractBalance();

// Number of founders
uint256 count = vesting.getFounderCount();

// Access founder by index
address founder = vesting.founders(0);

// Access grant details
(uint256 totalAmount, uint256 releasedAmount) = vesting.grants(founderAddress);
```

### Claim Tokens (Founders Only)

```solidity
// Founder claims all available vested tokens
vesting.release();
```

### Change Wallet Address (Founders Only)

```solidity
// Migrate grant to new address (e.g., if wallet compromised)
vesting.changeFounderAddress(newWalletAddress);
```

## Deployment

### Constructor Parameters

```solidity
constructor(
    address[] memory _founders,      // Exactly 4 founder addresses
    uint256[] memory _allocations,   // Token amounts per founder (in wei)
    uint256 _startTimestamp,         // Unix timestamp for vesting start
    uint256 _durationSeconds         // Vesting duration (4 years = 126144000)
)
```

### Example Deployment

```solidity
address[] memory founders = new address[](4);
founders[0] = 0x1111...;
founders[1] = 0x2222...;
founders[2] = 0x3333...;
founders[3] = 0x4444...;

uint256[] memory allocations = new uint256[](4);
allocations[0] = 25_000_000 ether;  // 25M XGR
allocations[1] = 25_000_000 ether;
allocations[2] = 25_000_000 ether;
allocations[3] = 25_000_000 ether;

uint256 startTime = block.timestamp;           // Or specific date
uint256 duration = 4 * 365 days;               // 4 years

FounderVesting vesting = new FounderVesting(
    founders,
    allocations,
    startTime,
    duration
);
```

### Fund the Contract

After deployment, send the total allocation to the contract:

```solidity
(bool success, ) = payable(vestingAddress).call{value: totalAllocation}("");
```

## Events

| Event | Description |
|-------|-------------|
| `TokensReleased` | Emitted when a founder claims vested tokens |
| `FounderAddressChanged` | Emitted when a founder migrates to a new address |

## Security Features

| Feature | Implementation |
|---------|----------------|
| No Admin | Contract is autonomous after deployment |
| Self-Custody | Only founders can claim their own tokens |
| Address Recovery | Founders can migrate wallets without admin |
| Immutable Schedule | Start time and duration cannot be changed |
| Overflow Protection | Solidity 0.8+ built-in checks |
| Reentrancy Safe | State updated before external call |

## Vesting Timeline Example

Assuming 100M XGR total allocation (25M per founder):

| Time | Progress | Vested per Founder | Claimable* |
|------|----------|-------------------|------------|
| Start | 0% | 0 XGR | 0 XGR |
| 1 year | 25% | 6.25M XGR | 6.25M XGR |
| 2 years | 50% | 12.5M XGR | 12.5M XGR |
| 3 years | 75% | 18.75M XGR | 18.75M XGR |
| 4 years | 100% | 25M XGR | 25M XGR |

*Assuming no prior claims

## Contract State

| Variable | Type | Description |
|----------|------|-------------|
| `vestingStart` | `uint256 immutable` | Unix timestamp when vesting begins |
| `vestingDuration` | `uint256 immutable` | Total vesting period in seconds |
| `grants` | `mapping(address => VestingGrant)` | Per-founder allocation and release tracking |
| `founders` | `address[]` | Array of founder addresses |

### VestingGrant Struct

```solidity
struct VestingGrant {
    uint256 totalAmount;    // Total allocation for this founder
    uint256 releasedAmount; // Already claimed amount
}
```

## Notes

- Contract must be funded with native XGR before founders can claim
- Founders can claim at any time (gas costs apply)
- Partial claims are supported (claim any time, as often as desired)
- No penalties for early or late claiming
- Address changes are irreversible (old address loses access)

## License

MIT

---

Part of the [XGR Network](https://xgr.network) infrastructure.
