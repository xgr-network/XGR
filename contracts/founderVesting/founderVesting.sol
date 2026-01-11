// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title FounderVesting
 * @notice 4-Jahres lineares Vesting ohne Cliff für native Layer-1 Coins
 * @dev Alle Gründer in einem Kontrakt, individuelle Allocations
 */
contract FounderVesting {
    
    // ============ State Variables ============
    
    uint256 public immutable vestingStart;
    uint256 public immutable vestingDuration;
    
    struct VestingGrant {
        uint256 totalAmount;      // Gesamte Allocation
        uint256 releasedAmount;   // Bereits ausgezahlt
    }
    
    mapping(address => VestingGrant) public grants;
    address[] public founders;
    
    // ============ Events ============
    
    event TokensReleased(address indexed founder, uint256 amount);
    event FounderAddressChanged(address indexed oldAddress, address indexed newAddress);
    
    // ============ Constructor ============
    
    /**
     * @param _founders Array der 4 Gründer-Adressen
     * @param _allocations Array der Coin-Mengen für jeden Gründer (in wei)
     * @param _startTimestamp Unix-Timestamp wann das Vesting startet
     * @param _durationSeconds Vesting-Dauer in Sekunden (4 Jahre = 126144000)
     */
    constructor(
        address[] memory _founders,
        uint256[] memory _allocations,
        uint256 _startTimestamp,
        uint256 _durationSeconds
    ) {
        require(_founders.length == 4, "Must have exactly 4 founders");
        require(_founders.length == _allocations.length, "Arrays length mismatch");
        require(_durationSeconds > 0, "Duration must be > 0");
        
        vestingStart = _startTimestamp;
        vestingDuration = _durationSeconds;
        
        for (uint256 i = 0; i < _founders.length; i++) {
            require(_founders[i] != address(0), "Invalid founder address");
            require(_allocations[i] > 0, "Allocation must be > 0");
            require(grants[_founders[i]].totalAmount == 0, "Duplicate founder");
            
            grants[_founders[i]] = VestingGrant({
                totalAmount: _allocations[i],
                releasedAmount: 0
            });
            founders.push(_founders[i]);
        }
    }
    
    /**
     * @notice Empfängt native Coins für das Vesting
     */
    receive() external payable {}
    
    // ============ View Functions ============
    
    /**
     * @notice Zeigt das aktuelle Balance des Kontrakts
     */
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice Berechnet die insgesamt gevesteten Coins für einen Gründer
     * @param _founder Adresse des Gründers
     * @return Anzahl der gevesteten Coins
     */
    function vestedAmount(address _founder) public view returns (uint256) {
        VestingGrant memory grant = grants[_founder];
        
        if (grant.totalAmount == 0) {
            return 0;
        }
        
        if (block.timestamp < vestingStart) {
            return 0;
        }
        
        uint256 elapsed = block.timestamp - vestingStart;
        
        if (elapsed >= vestingDuration) {
            return grant.totalAmount;
        }
        
        // Lineares Vesting: (totalAmount * elapsed) / duration
        return (grant.totalAmount * elapsed) / vestingDuration;
    }
    
    /**
     * @notice Berechnet die aktuell auszahlbaren Coins
     * @param _founder Adresse des Gründers
     * @return Anzahl der auszahlbaren Coins
     */
    function releasableAmount(address _founder) public view returns (uint256) {
        return vestedAmount(_founder) - grants[_founder].releasedAmount;
    }
    
    /**
     * @notice Gibt alle Vesting-Infos für einen Gründer zurück
     * @param _founder Adresse des Gründers
     */
    function getVestingInfo(address _founder) external view returns (
        uint256 total,
        uint256 vested,
        uint256 released,
        uint256 releasable
    ) {
        VestingGrant memory grant = grants[_founder];
        return (
            grant.totalAmount,
            vestedAmount(_founder),
            grant.releasedAmount,
            releasableAmount(_founder)
        );
    }
    
    /**
     * @notice Gibt die Anzahl der Gründer zurück
     */
    function getFounderCount() external view returns (uint256) {
        return founders.length;
    }
    
    /**
     * @notice Berechnet den Vesting-Fortschritt in Prozent (Basis 10000 = 100%)
     */
    function vestingProgressBps() external view returns (uint256) {
        if (block.timestamp < vestingStart) {
            return 0;
        }
        uint256 elapsed = block.timestamp - vestingStart;
        if (elapsed >= vestingDuration) {
            return 10000;
        }
        return (elapsed * 10000) / vestingDuration;
    }
    
    // ============ External Functions ============
    
    /**
     * @notice Zahlt alle verfügbaren gevesteten Coins an den Gründer aus
     */
    function release() external {
        uint256 amount = releasableAmount(msg.sender);
        require(amount > 0, "No coins available for release");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        grants[msg.sender].releasedAmount += amount;
        
        // Native Transfer
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit TokensReleased(msg.sender, amount);
    }
    
    /**
     * @notice Erlaubt einem Gründer seine Adresse zu ändern (z.B. bei Wallet-Kompromittierung)
     * @param _newAddress Neue Wallet-Adresse
     */
    function changeFounderAddress(address _newAddress) external {
        require(_newAddress != address(0), "Invalid new address");
        require(grants[msg.sender].totalAmount > 0, "Not a founder");
        require(grants[_newAddress].totalAmount == 0, "Address already has grant");
        
        // Grant übertragen
        grants[_newAddress] = grants[msg.sender];
        delete grants[msg.sender];
        
        // Founders-Array aktualisieren
        for (uint256 i = 0; i < founders.length; i++) {
            if (founders[i] == msg.sender) {
                founders[i] = _newAddress;
                break;
            }
        }
        
        emit FounderAddressChanged(msg.sender, _newAddress);
    }
}
