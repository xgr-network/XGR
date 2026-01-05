// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract XgrGrants {
    // ===== Admin =====
    address private _admin;

    // ===== Read-key registry =====
    mapping(address => bytes) private _readPub; // SEC1 P-256 (33B/65B)

    // ===== Events =====
    event ReadKeyRegistered(address indexed owner, bytes pubkey);
    event ReadKeyCleared(address indexed owner);

    // ===== Errors =====
    error NotAdmin();

    // ===== Modifiers =====
    modifier onlyAdmin() { if (msg.sender != _admin) revert NotAdmin(); _; }

    constructor(address admin_) {
        _admin = admin_;
    }

    function setAdmin(address newAdmin) external onlyAdmin { _admin = newAdmin; }

    // ===== Read-key registry =====
    function registerReadKey(bytes calldata pubkey) external {
        require(pubkey.length == 33 || pubkey.length == 65, "readPub: invalid length");
        _readPub[msg.sender] = pubkey;
        emit ReadKeyRegistered(msg.sender, pubkey);
    }
    function getReadKey(address owner) external view returns (bytes memory pubkey) { return _readPub[owner]; }
    function clearReadKey() external { delete _readPub[msg.sender]; emit ReadKeyCleared(msg.sender); }

    // --- Admin-managed variants ---
    function registerReadKeyFor(address owner, bytes calldata pubkey) external onlyAdmin {
        require(owner != address(0), "owner=0");
        require(pubkey.length == 33 || pubkey.length == 65, "readPub: invalid length");
        _readPub[owner] = pubkey;
        emit ReadKeyRegistered(owner, pubkey);
    }

    function clearReadKeyFor(address owner) external onlyAdmin {
        require(owner != address(0), "owner=0");
        delete _readPub[owner];
        emit ReadKeyCleared(owner);
    }

}
