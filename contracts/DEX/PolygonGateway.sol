// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IWXGR {
    function mint(address to, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

contract PolygonGateway is Ownable, Pausable {
    IWXGR public immutable token;
    address public operator;

    uint256 public redeemNonce;

    mapping(bytes32 => bool) public processedDeposit; // XGRChain deposit -> Polygon mint (exactly once)

    // Optional mint limiter (0 = unlimited)
    uint256 public dailyMintLimit;
    uint256 private _dayIndex;
    uint256 private _mintedToday;

    event OperatorSet(address indexed operator);
    event DailyMintLimitSet(uint256 limit);

    event Redeem(
        address indexed redeemer,
        address indexed toXgr,
        uint256 amount,
        uint256 nonce
    );

    event MintFromXgr(
        bytes32 indexed depositId,
        address indexed toPolygon,
        uint256 amount,
        bytes32 xgrTxHashRef
    );

    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    constructor(address initialOwner, address initialOperator, address wxgr) Ownable(initialOwner) {
        require(wxgr != address(0), "ZERO_TOKEN");
        token = IWXGR(wxgr);
        operator = initialOperator;
        emit OperatorSet(initialOperator);
    }

    function setOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "ZERO_OPERATOR");
        operator = newOperator;
        emit OperatorSet(newOperator);
    }

    function setDailyMintLimit(uint256 limit) external onlyOwner {
        dailyMintLimit = limit;
        emit DailyMintLimitSet(limit);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // User burns wXGR and declares XGRChain recipient
    // Requires prior: wXGR.approve(gateway, amount)
    function redeem(address toXgr, uint256 amount) external whenNotPaused {
        require(toXgr != address(0), "ZERO_TO");
        require(amount > 0, "ZERO_AMOUNT");

        token.burnFrom(msg.sender, amount);

        uint256 nonce = ++redeemNonce;
        emit Redeem(msg.sender, toXgr, amount, nonce);
    }

    // Operator mints wXGR after XGRChain deposit is final
    function mintFromXgr(
        bytes32 depositId,
        address toPolygon,
        uint256 amount,
        bytes32 xgrTxHashRef
    ) external onlyOperator whenNotPaused {
        require(!processedDeposit[depositId], "ALREADY_PROCESSED");
        require(toPolygon != address(0), "ZERO_TO");
        require(amount > 0, "ZERO_AMOUNT");

        _enforceDailyMintLimit(amount);

        processedDeposit[depositId] = true;
        token.mint(toPolygon, amount);

        emit MintFromXgr(depositId, toPolygon, amount, xgrTxHashRef);
    }

    function _enforceDailyMintLimit(uint256 amount) internal {
        if (dailyMintLimit == 0) return;

        uint256 today = block.timestamp / 1 days;
        if (today != _dayIndex) {
            _dayIndex = today;
            _mintedToday = 0;
        }
        require(_mintedToday + amount <= dailyMintLimit, "DAILY_LIMIT");
        _mintedToday += amount;
    }
}
