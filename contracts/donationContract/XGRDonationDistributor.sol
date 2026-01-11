// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../shared/Ownable.sol";

/**
 * @title xGreenDonationDistributor
 * @notice Distributes native XGR from the fee-split treasury to registered NGOs
 * @dev Receives native XGR from the blockchain's fee distribution mechanism
 *      and distributes it to NGOs based on configurable weights.
 *      
 *      Flow: Transaction Fees → Fee-Split → Treasury (this contract) → NGOs
 */
contract xGreenDonationDistributor is Ownable {
    
    /**
     * @notice NGO recipient configuration
     * @param wallet The address to receive donations (must be payable)
     * @param weight Distribution weight (0 = excluded from distribution)
     * @param name Human-readable name of the NGO
     * @param url Website or verification URL of the NGO
     */
    struct NGO {
        address payable wallet;
        uint256 weight;
        string name;
        string url;
    }

    /**
     * @notice Status information for distribution readiness
     * @param ready True if distribution can be triggered
     * @param remainingTime Seconds until minInterval is satisfied (0 if ready)
     * @param missingAmount XGR needed to reach minDistributionAmount (0 if sufficient)
     * @param currentBalance Current native XGR balance of the contract
     */
    struct DistributionStatus {
        bool ready;
        uint256 remainingTime;
        uint256 missingAmount;
        uint256 currentBalance;
    }

    /// @notice Array of all registered NGOs
    NGO[] public ngos;

    /// @notice Minimum time between distributions
    uint256 public minInterval = 7 days;

    /// @notice Minimum balance required to trigger distribution
    uint256 public minDistributionAmount = 1000 ether;

    /// @notice Timestamp of the last successful distribution
    uint256 public lastDistribution;

    /// @notice Emitted when funds are distributed to an NGO
    event DonationDistributed(address indexed recipient, string url, uint256 amount);

    /// @notice Emitted when native XGR is received
    event DonationReceived(address indexed sender, uint256 amount);

    /// @notice Emitted when a new NGO is added
    event NGOAdded(address indexed wallet, string name, string url, uint256 weight);

    /// @notice Emitted when an existing NGO is updated
    event NGOUpdated(uint256 index, address indexed wallet, string name, string url, uint256 weight);

    /// @notice Emitted when the NGO list is reset
    event NGOsReset(uint256 count);

    /// @notice Emitted when minInterval is changed
    event MinIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    /// @notice Emitted when minDistributionAmount is changed
    event MinDistributionAmountUpdated(uint256 oldAmount, uint256 newAmount);

    /// @notice Emitted on emergency withdrawal
    event EmergencyWithdraw(address indexed to, uint256 amount);

    constructor() {}

    /**
     * @notice Receives native XGR from the fee-split mechanism
     * @dev Required to accept native token transfers from the blockchain's
     *      fee distribution. Without this, incoming transfers would revert.
     */
    receive() external payable {
        emit DonationReceived(msg.sender, msg.value);
    }

    /**
     * @notice Updates the minimum interval between distributions
     * @param interval New minimum interval in seconds
     */
    function setMinInterval(uint256 interval) external onlyOwner {
        emit MinIntervalUpdated(minInterval, interval);
        minInterval = interval;
    }

    /**
     * @notice Updates the minimum balance required for distribution
     * @param amount New minimum amount in wei
     */
    function setMinDistributionAmount(uint256 amount) external onlyOwner {
        emit MinDistributionAmountUpdated(minDistributionAmount, amount);
        minDistributionAmount = amount;
    }

    /**
     * @notice Returns the current distribution status
     * @return status Struct containing readiness info and current balance
     */
    function getDistributionStatus() external view returns (DistributionStatus memory status) {
        uint256 currentBalance = address(this).balance;
        uint256 timeLeft = block.timestamp >= lastDistribution + minInterval
            ? 0
            : (lastDistribution + minInterval - block.timestamp);
        uint256 missing = currentBalance >= minDistributionAmount
            ? 0
            : (minDistributionAmount - currentBalance);

        return DistributionStatus({
            ready: timeLeft == 0 && missing == 0,
            remainingTime: timeLeft,
            missingAmount: missing,
            currentBalance: currentBalance
        });
    }

    /**
     * @notice Distributes accumulated XGR to all registered NGOs
     * @dev Can be called by anyone once conditions are met (permissionless).
     *      Distribution is proportional to each NGO's weight.
     *      
     *      Requirements:
     *      - At least minInterval seconds since last distribution
     *      - Contract balance >= minDistributionAmount
     *      - At least one NGO with weight > 0
     *      
     *      Note: Small dust amounts may remain due to integer division.
     */
    function distribute() external {
        require(block.timestamp >= lastDistribution + minInterval, "Too early");

        uint256 balance = address(this).balance;
        require(balance >= minDistributionAmount, "Not enough funds");

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < ngos.length; i++) {
            totalWeight += ngos[i].weight;
        }
        require(totalWeight > 0, "No valid NGOs set");

        for (uint256 i = 0; i < ngos.length; i++) {
            if (ngos[i].weight > 0) {
                uint256 amount = (balance * ngos[i].weight) / totalWeight;
                (bool success, ) = ngos[i].wallet.call{value: amount}("");
                require(success, "Transfer failed");
                emit DonationDistributed(ngos[i].wallet, ngos[i].url, amount);
            }
        }

        lastDistribution = block.timestamp;
    }

    /**
     * @notice Replaces the entire NGO list
     * @param _newNGOs Array of new NGO configurations
     * @dev Use this for bulk updates. For single changes, use addNGO or updateNGO.
     */
    function setNGOs(NGO[] calldata _newNGOs) external onlyOwner {
        delete ngos;
        for (uint256 i = 0; i < _newNGOs.length; i++) {
            ngos.push(_newNGOs[i]);
        }
        emit NGOsReset(_newNGOs.length);
    }

    /**
     * @notice Returns all registered NGOs
     * @return Array of NGO structs
     */
    function getNGOs() external view returns (NGO[] memory) {
        return ngos;
    }

    /**
     * @notice Returns the number of registered NGOs
     * @return count Number of NGOs in the array
     */
    function getNGOCount() external view returns (uint256 count) {
        return ngos.length;
    }

    /**
     * @notice Updates an existing NGO at the specified index
     * @param index Array index of the NGO to update
     * @param wallet New wallet address
     * @param weight New distribution weight (0 to exclude)
     * @param name New name
     * @param url New URL
     */
    function updateNGO(
        uint256 index, 
        address payable wallet, 
        uint256 weight, 
        string calldata name, 
        string calldata url
    ) external onlyOwner {
        require(index < ngos.length, "Invalid index");
        ngos[index] = NGO(wallet, weight, name, url);
        emit NGOUpdated(index, wallet, name, url, weight);
    }

    /**
     * @notice Adds a new NGO to the distribution list
     * @param wallet Wallet address to receive donations
     * @param weight Distribution weight (0 = no distribution)
     * @param name Human-readable name
     * @param url Website or verification URL
     */
    function addNGO(
        address payable wallet, 
        uint256 weight, 
        string calldata name, 
        string calldata url
    ) external onlyOwner {
        ngos.push(NGO(wallet, weight, name, url));
        emit NGOAdded(wallet, name, url, weight);
    }

    /**
     * @notice Emergency function to withdraw all funds
     * @param to Address to receive the funds
     * @dev Only use in emergencies. This bypasses normal distribution logic.
     */
    function emergencyWithdraw(address payable to) external onlyOwner {
        require(to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        (bool success, ) = to.call{value: balance}("");
        require(success, "Withdraw failed");
        emit EmergencyWithdraw(to, balance);
    }
}
