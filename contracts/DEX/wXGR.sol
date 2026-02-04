// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract wXGR is ERC20Capped, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        address admin
    ) ERC20(name_, symbol_) ERC20Capped(cap_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // Required override because of ERC20Capped
    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Capped) {
        super._mint(to, amount);
    }
}
