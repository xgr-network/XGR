// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract XgrVault is Ownable, Pausable {
    address public operator; // relayer key (hot) - can be rotated by owner (cold)
    uint256 public depositNonce;

    // Exactly-once unlock (Polygon redeem)
    mapping(bytes32 => bool) public processedRedeem;

    // Optional blast-radius limiter (0 = unlimited)
    uint256 public dailyUnlockLimit;
    uint256 private _dayIndex;
    uint256 private _unlockedToday;

    event OperatorSet(address indexed operator);
    event DailyUnlockLimitSet(uint256 limit);

    event DepositToPolygon(
        address indexed depositor,
        address indexed toPolygon,
        uint256 amount,
        uint256 nonce
    );

    event UnlockedFromPolygon(
        bytes32 indexed redeemId,
        address indexed toXgr,
        uint256 amount,
        bytes32 polygonTxHashRef
    );

    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    constructor(address initialOwner, address initialOperator) Ownable(initialOwner) {
        operator = initialOperator;
        emit OperatorSet(initialOperator);
    }

    receive() external payable {} // allow direct top-ups (no event)

    function setOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "ZERO_OPERATOR");
        operator = newOperator;
        emit OperatorSet(newOperator);
    }

    function setDailyUnlockLimit(uint256 limit) external onlyOwner {
        dailyUnlockLimit = limit;
        emit DailyUnlockLimitSet(limit);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // Lock native XGR and emit canonical event used for mint on Polygon
    function depositToPolygon(address toPolygon) external payable whenNotPaused returns (uint256 nonce) {
        require(toPolygon != address(0), "ZERO_TO");
        require(msg.value > 0, "ZERO_AMOUNT");

        nonce = ++depositNonce;
        emit DepositToPolygon(msg.sender, toPolygon, msg.value, nonce);
    }

    // Unlock native XGR after Polygon redeem is final
    function unlockFromPolygon(
        bytes32 redeemId,
        address payable toXgr,
        uint256 amount,
        bytes32 polygonTxHashRef
    ) external onlyOperator whenNotPaused {
        require(!processedRedeem[redeemId], "ALREADY_PROCESSED");
        require(toXgr != address(0), "ZERO_TO");
        require(amount > 0, "ZERO_AMOUNT");
        require(address(this).balance >= amount, "INSUFFICIENT_VAULT");

        _enforceDailyLimit(amount);

        processedRedeem[redeemId] = true;

        (bool ok, ) = toXgr.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");

        emit UnlockedFromPolygon(redeemId, toXgr, amount, polygonTxHashRef);
    }

    function _enforceDailyLimit(uint256 amount) internal {
        if (dailyUnlockLimit == 0) return;

        uint256 today = block.timestamp / 1 days;
        if (today != _dayIndex) {
            _dayIndex = today;
            _unlockedToday = 0;
        }
        require(_unlockedToday + amount <= dailyUnlockLimit, "DAILY_LIMIT");
        _unlockedToday += amount;
    }
}
