// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title XRC-729 OSTC Registry (JSON-only)
/// @notice Speichert Orchestrierungen (OSTC) als JSON unter einer string-ID.
///         Die RPC/Engine liest das JSON off-chain und interpretiert es.
contract XRC729 {
    address public immutable owner;
    string public nameXRC = "XGR_XRC729";

    // ID -> JSON
    mapping(string => string) private ostcJSON;

    // Listing aller IDs
    string[] private ostcIds;

    // 1-basiertes Index-Mapping für O(1)-Swap-Delete; 0 == nicht vorhanden
    mapping(string => uint256) private ostcIndex;

    event OSTCSet(string indexed id);
    event OSTCDeleted(string indexed id);

    modifier onlyOwner() {
        require(msg.sender == owner, "XRC729: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function _setOSTC(string memory id, string memory json) internal {
        if (ostcIndex[id] == 0) {
            ostcIds.push(id);
            ostcIndex[id] = ostcIds.length; // 1-basiert
        }
        ostcJSON[id] = json;
        emit OSTCSet(id);
    }

    /// @notice Anlegen oder Aktualisieren einer OSTC unter der gegebenen ID.
    function setOSTC(string calldata id, string calldata json) external onlyOwner {
        _setOSTC(id, json);
    }

    /// @notice Löscht eine OSTC per ID (inkl. Swap-Delete in der ID-Liste).
    function deleteOSTC(string calldata id) external onlyOwner {
        uint256 idx1b = ostcIndex[id];
        require(idx1b != 0, "XRC729: not found");

        uint256 idx = idx1b - 1;
        uint256 last = ostcIds.length - 1;

        if (idx != last) {
            string memory moved = ostcIds[last];
            ostcIds[idx] = moved;
            ostcIndex[moved] = idx + 1;
        }
        ostcIds.pop();

        delete ostcIndex[id];
        delete ostcJSON[id];

        emit OSTCDeleted(id);
    }

    /// @notice Gibt alle OSTC-IDs zurück.
    function getAllOSTC() external view returns (string[] memory) {
        return ostcIds;
    }

    /// @notice Liefert das JSON der OSTC zur ID.
    function getOSTC(string calldata id) external view returns (string memory) {
        require(ostcIndex[id] != 0, "XRC729: not found");
        return ostcJSON[id];
    }

    /// @notice Existenzcheck.
    function hasOSTC(string calldata id) external view returns (bool) {
        return ostcIndex[id] != 0;
    }
    function getNameXRC() public view returns (string memory) {
        return nameXRC;
    }
}

