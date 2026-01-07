// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Ownable.sol";

/// @title XGR Public Sale (native coin) with deterministic tranche pricing
/// @notice Implements the whitepaper price rule on a rolling 30-day window (configurable).
///         The contract holds native XGR; payouts are executed by owner OR payout-operator.
///         All view functions are stateless: they compute a virtual "rolled" view and never
///         mutate storage. Persistent rollover can be triggered via `refreshTranche()`.
contract XGRPublicSale is Ownable {
    // ---- Sale switch ----
    bool public saleActive = true;

    // ---- Payout operator (additional payout authorization) ----
    address public payoutOperator;
    event PayoutOperatorUpdated(address indexed operator);

    modifier onlyPayoutRole() {
        require(msg.sender == owner() || msg.sender == payoutOperator, "not payout role");
        _;
    }

    function setPayoutOperator(address op) external onlyOwner {
        payoutOperator = op; // address(0) disables the operator
        emit PayoutOperatorUpdated(op);
    }

    // ---- Tranche parameters (whitepaper) ----

    // Tranche size: 17,000,000 XGR (18 decimals)
    uint256 public constant TRANCHE_SIZE = 17_000_000 ether;

    // de minimis δ = 10,000 XGR
    uint256 public constant DELTA = 10_000 ether;

    // Tranche duration (default here: 60 minutes for testing; set to 30 days for production)
    uint256 public constant TRANCHE_DURATION = 30 days;

    // Fixed-point base (1e18 = 1.0)
    uint256 private constant ONE = 1e18;

    // P0 = 0.000001 EUR per XGR → scaled by 1e18 → 1e12
    uint256 public constant P0 = 1_000_000_000_000;

    // m0 = 0.02 → 0.02 * 1e18
    uint256 public constant M0 = 20_000_000_000_000_000;

    // M = 9.0 → 9 * 1e18
    uint256 public constant M_MAX = 9_000_000_000_000_000_000;

    // D = 0.30 → 0.30 * 1e18
    uint256 public constant D = 300_000_000_000_000_000;

    // We discretize the tranche duration into 30 equal "steps" (matches 30 calendar days).
    // This keeps the (sell-out) d-term stable even when TRANCHE_DURATION is shortened for tests.
    uint256 private constant TRANCHE_STEPS = 30;
    uint256 private constant STEP_DURATION = TRANCHE_DURATION / TRANCHE_STEPS;

    // ---- Stored state (minimal) ----

    // Current issue price P_n (EUR * 1e18 per 1 XGR)
    uint256 public currentPrice;

    // Start timestamp t0 of the *stored* current tranche
    uint256 public trancheStart;

    // Tranche index (0-based)
    uint256 public currentTranche;

    // Msold in the *stored* current tranche (real paid-out XGR, in wei)
    uint256 public tokensSoldInTranche;

    // t* (first timestamp when Msold >= TRANCHE_SIZE - δ), 0 if never reached in that tranche
    uint256 public soldOutTimestamp;

    // ---- Events ----

    event TokensSold(
        uint256 indexed trancheIndex,
        address indexed buyer,
        uint256 xgrAmount,
        uint256 pricePerToken
    );
    /// Sichtbarer Beleg im Receipt-Log (Explorer): Order-Ref optional
    event Payout(bytes32 indexed orderRef, address indexed buyer, uint256 amount, address indexed caller);

    event TrancheFinalized(
        uint256 indexed trancheIndex,
        uint256 msold,
        uint256 stepsSoldOut,
        uint256 oldPrice,
        uint256 newPrice
    );

    event TrancheRolled(uint256 newStart, uint256 newEnd, uint256 newPrice, uint256 newIndex);
    event SaleToggled(bool active);

    /// @dev Summary event for gas-efficient maintenance that rolls many empty windows
    /// in a single admin call (without per-window events).
    /// fromIndex = tranche index at function entry,
    /// toIndex   = tranche index after processing.
    event TranchesFastForwarded(
        uint256 indexed fromIndex, uint256 indexed toIndex, uint256 windowsProcessed, uint256 oldPrice, uint256 newPrice);

    // ---- Lifecycle ----

    constructor() {
        require(STEP_DURATION > 0, "Invalid tranche duration");
        // Tranche 0 starts at deployment; initial price is P0
        currentPrice = P0;
        trancheStart = block.timestamp;
        currentTranche = 0;
    }

    // ---- Admin ----

    function toggleSale(bool active) external onlyOwner {
        saleActive = active;
        emit SaleToggled(active);
    }

    /// @notice Owner/Operator pays out native XGR to the buyer; Msold is increased by the paid amount.
    /// @dev Amount is in wei (18 decimals). Requires sufficient contract balance.
    function sellTokens(address buyer, uint256 xgrAmount) external onlyPayoutRole {
        _payout(buyer, xgrAmount, bytes32(0));
    }

    /// Auszahlung mit Referenz (für Bank/Order-Korrelation im Explorer)
    function sellTokensWithRef(address buyer, uint256 xgrAmount, bytes32 orderRef) external onlyPayoutRole {
        _payout(buyer, xgrAmount, orderRef);
    }

    function _payout(address buyer, uint256 xgrAmount, bytes32 orderRef) internal {
        require(saleActive, "Sale not active");
        require(buyer != address(0), "Invalid buyer");
        require(xgrAmount > 0, "Amount must be > 0");

        // Make sure all elapsed tranches are finalized and state is rolled forward
        _rollTranches();

        // Enforce the residual tranche limit
        require(tokensSoldInTranche + xgrAmount <= TRANCHE_SIZE, "Tranche limit exceeded");

        // Ensure the contract holds enough native XGR
        require(address(this).balance >= xgrAmount, "Insufficient XGR balance");

        // Book Msold
        tokensSoldInTranche += xgrAmount;

        // Set t* once when Msold first reaches TRANCHE_SIZE - δ
        if (soldOutTimestamp == 0 && tokensSoldInTranche >= TRANCHE_SIZE - DELTA) {
            soldOutTimestamp = block.timestamp;
        }

        // Send native XGR to the buyer
        (bool success, ) = payable(buyer).call{value: xgrAmount}("");
        require(success, "XGR transfer failed");
        emit TokensSold(currentTranche, buyer, xgrAmount, currentPrice);
        emit Payout(orderRef, buyer, xgrAmount, msg.sender);
    }

    /// @notice Persistently roll the stored state forward until `block.timestamp` is inside the active tranche.
    /// @dev Anyone can call this; it finalizes one or more elapsed tranches and updates price/start/index.
    function refreshTranche() external returns (bool changed) {
        uint256 before = currentTranche;
        if (block.timestamp >= trancheStart + TRANCHE_DURATION) {
            _rollTranches();
            emit TrancheRolled(trancheStart, trancheStart + TRANCHE_DURATION, currentPrice, currentTranche);
        }
        return currentTranche != before;
    }

    // ---- Admin maintenance: monitoring & compact roll-forward ----
    /// @notice Number of fully elapsed tranche windows since the stored trancheStart.
    /// @dev Read-only helper for monitoring/UI to see how far storage lags behind "now".
    /// 0 means we are still inside the stored active window; >=1 means storage is behind.
    function pendingWindows() external view returns (uint256) {
        if (block.timestamp <= trancheStart) return 0;
        uint256 diff = block.timestamp - trancheStart;
        return diff / TRANCHE_DURATION; // floor
    }

    /// @notice Gas-efficient admin fast-forward: persistently roll many empty windows up to `maxWindows`.
    /// @dev onlyOwner. Finalizes the currently stored window once (emits TrancheFinalized),
    /// then applies additional empty windows (msold=0, t*=0) without per-window events.
    /// Emits a single TranchesFastForwarded summary event at the end.
    /// @return processed Number of windows actually advanced.
    function fastForward(uint256 maxWindows) external onlyOwner returns (uint256 processed) {
        require(maxWindows > 0, "maxWindows=0");
        // Strong safety: do nothing unless at least one full window has elapsed.
        // Prevents touching/“finalizing” an active (not-yet-closed) time window.
        require(block.timestamp >= trancheStart + TRANCHE_DURATION, "active window; nothing to fast-forward");

        uint256 startIndex = currentTranche;
        uint256 oldP = currentPrice;

        while (processed < maxWindows && block.timestamp >= trancheStart + TRANCHE_DURATION) {
            if (processed == 0) {
                // Finalize the actually stored window (may have non-zero msold / t*)
                _finalizeCurrentTranche();
            } else {
                // Subsequent windows are guaranteed empty in storage (msold=0; t*=0)
                currentPrice = _computeNextPrice(currentPrice, 0, trancheStart, 0);
            }

            // Advance one stored window
            trancheStart        += TRANCHE_DURATION;
            currentTranche      += 1;
            tokensSoldInTranche  = 0;
            soldOutTimestamp     = 0;

            unchecked { processed += 1; }
        }

        if (processed > 0) {
            emit TranchesFastForwarded(startIndex, currentTranche, processed, oldP, currentPrice);
        }
    }

    // ---- Stateless view API (virtual "rolled" view) ----

    /// @notice Compute a virtual rolled view as of `nowTs`, without writing storage.
    /// @return P      virtual current price
    /// @return t0     virtual current tranche start
    /// @return t1     virtual current tranche end
    /// @return rem    virtual remaining amount in the current tranche
    /// @return msCur  virtual Msold of the current tranche
    /// @return tStar  virtual sell-out timestamp (only relevant if sold out inside this tranche)
    function _rolledView(uint256 nowTs)
        internal
        view
        returns (uint256 P, uint256 t0, uint256 t1, uint256 rem, uint256 msCur, uint256 tStar)
    {
        // Start from stored state
        P     = currentPrice;
        t0    = trancheStart;
        t1    = t0 + TRANCHE_DURATION;
        msCur = tokensSoldInTranche;
        tStar = soldOutTimestamp;

        if (nowTs < t1) {
            // We are still inside the stored window
            rem = TRANCHE_SIZE > msCur ? TRANCHE_SIZE - msCur : 0;
            return (P, t0, t1, rem, msCur, tStar);
        }

        // 1) Close the stored (elapsed) window using its real Msold and t*
        P = _computeNextPrice(P, msCur, t0, tStar);
        t0 = t1; // move to next window

        // From here on, there were no sales in those windows
        msCur = 0;
        tStar = 0;

        // 2) Skip any additional full windows with s = 0
        if (nowTs > t0) {
            uint256 k = (nowTs - t0) / TRANCHE_DURATION; // number of *full* windows after the first
            while (k > 0) {
                P  = _computeNextPrice(P, 0, t0, 0);
                t0 = t0 + TRANCHE_DURATION;
                unchecked { k--; }
            }
        }

        // 3) We are now inside the virtual current window
        t1  = t0 + TRANCHE_DURATION;
        rem = TRANCHE_SIZE; // no sales yet in the virtual window
        return (P, t0, t1, rem, msCur, tStar);
    }

    /// @notice Current price P_n (stateless).
    function getCurrentPrice() external view returns (uint256) {
        (uint256 p,, , , ,) = _rolledView(block.timestamp);
        return p;
    }

    /// @notice Current tranche start (stateless).
    function getCurrentTrancheStart() external view returns (uint256) {
        (, uint256 t0,, , ,) = _rolledView(block.timestamp);
        return t0;
    }

    /// @notice Current tranche end (stateless).
    function getCurrentTrancheEnd() external view returns (uint256) {
        (,, uint256 t1,, ,) = _rolledView(block.timestamp);
        return t1;
    }

    /// @notice Remaining amount in the current tranche (stateless).
    function remainingInTranche() external view returns (uint256) {
        (,,, uint256 rem,,) = _rolledView(block.timestamp);
        return rem;
    }

    /// @notice Stateless preview of the next tranche price P_{n+1} from the current virtual view.
    function previewNextPrice() external view returns (uint256) {
        (uint256 p, uint256 t0,, , uint256 ms, uint256 tStar) = _rolledView(block.timestamp);
        return _computeNextPrice(p, ms, t0, tStar);
    }

    // ---- Internals: time steps / rolling / pricing ----

    /// @notice Number of "steps" (0..30) between two timestamps, based on STEP_DURATION.
    ///         Works with both 30-day and shortened test durations.
    function _stepsBetween(uint256 fromTs, uint256 toTs) internal pure returns (uint256) {
        if (toTs <= fromTs) return 0;
        uint256 diff = toTs - fromTs;
        return diff / STEP_DURATION; // floor
    }

    /// @dev Roll all fully elapsed tranches forward until `block.timestamp` is inside the active tranche.
    function _rollTranches() internal {
        if (block.timestamp < trancheStart + TRANCHE_DURATION) return;

        uint256 safetyCounter = 0;
        while (block.timestamp >= trancheStart + TRANCHE_DURATION) {
            _finalizeCurrentTranche();

            trancheStart        += TRANCHE_DURATION;
            currentTranche      += 1;
            tokensSoldInTranche  = 0;
            soldOutTimestamp     = 0;

            unchecked { safetyCounter += 1; }
            require(safetyCounter < 60, "Too many empty tranches"); // ~5 years of empty windows
        }
    }

    /// @dev Finalize the stored current tranche and compute P_{n+1} from (P_n, Msold, d).
    function _finalizeCurrentTranche() internal {
        uint256 oldPrice = currentPrice;
        uint256 msold    = tokensSoldInTranche;
        uint256 t0       = trancheStart;
        uint256 tStar    = soldOutTimestamp;

        uint256 newPrice = _computeNextPrice(oldPrice, msold, t0, tStar);

        uint256 stepsSoldOutEffective = 0;
        if (msold >= TRANCHE_SIZE - DELTA && tStar != 0) {
            stepsSoldOutEffective = _stepsBetween(t0, tStar);
            if (stepsSoldOutEffective > TRANCHE_STEPS) {
                stepsSoldOutEffective = TRANCHE_STEPS;
            }
        }

        emit TrancheFinalized(currentTranche, msold, stepsSoldOutEffective, oldPrice, newPrice);

        // Commit the new price
        currentPrice = newPrice;
    }

    /// @dev Price transition function:
    ///      Case 1 (sold out):  P_{n+1} = P_n * (1 + m0 + (M - m0) * d * (P0 / P_n)^0.5)
    ///      Case 2 (undersub):  P_{n+1} = max(P0; P_n * (1 - D * u * (P0 / P_n)^0.5)), u = 1 - s
    function _computeNextPrice(
        uint256 oldPrice,
        uint256 msold,
        uint256 t0,
        uint256 tStar
    ) internal pure returns (uint256) {
        uint256 newPrice;

        if (msold >= TRANCHE_SIZE - DELTA) {
            // Case 1: sold out (incl. δ)
            // Compute d from "steps" (0..30) relative to the tranche duration
            uint256 cutoffTs = tStar == 0 ? t0 + TRANCHE_DURATION : tStar;
            uint256 steps = cutoffTs <= t0 ? 0 : _stepsBetween(t0, cutoffTs);
            if (steps > TRANCHE_STEPS) steps = TRANCHE_STEPS;

            // d = (30 - steps) / 30
            uint256 d1e18 = ((TRANCHE_STEPS - steps) * ONE) / TRANCHE_STEPS;

            // (P0 / P_n)^0.5
            uint256 betaTerm = _betaTerm(oldPrice);

            // inc = m0 + (M - m0) * d * beta
            uint256 inc = M0 + (((M_MAX - M0) * d1e18) / ONE) * betaTerm / ONE;

            // P_{n+1} = P_n * (1 + inc)
            newPrice = (oldPrice * (ONE + inc)) / ONE;
        } else {
            // Case 2: undersubscribed
            // s = msold / TRANCHE_SIZE ; u = 1 - s
            uint256 s1e18 = (msold * ONE) / TRANCHE_SIZE;
            if (s1e18 > ONE) s1e18 = ONE;
            uint256 u1e18 = ONE - s1e18;

            // (P0 / P_n)^0.5
            uint256 betaTerm = _betaTerm(oldPrice);

            // tmp = D * u * beta
            uint256 tmp = (D * u1e18 / ONE) * betaTerm / ONE;

            if (tmp >= ONE) {
                // Floor guard (cannot go below P0 anyway)
                newPrice = P0;
            } else {
                // P_{n+1} = max(P0; P_n * (1 - tmp))
                uint256 factor = ONE - tmp;
                newPrice = (oldPrice * factor) / ONE;
                if (newPrice < P0) newPrice = P0;
            }
        }
        return newPrice;
    }

    /// @dev betaTerm = (P0 / P)^0.5 in 1e18 fixed-point.
    function _betaTerm(uint256 price) internal pure returns (uint256) {
        // x = P0 * 1e36 / price; sqrt(x) → 1e18 scale
        uint256 x = (P0 * ONE * ONE) / price;
        return _sqrt(x);
    }

    /// @dev Integer sqrt (Babylonian method).
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) { y = z; z = (x / z + z) / 2; }
        return y;
    }

    /// @notice Accept native XGR (funding the contract).
    receive() external payable {}
}