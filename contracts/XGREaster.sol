// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract XGREaster {
    address public owner;

    mapping(uint256 => string) public easterQuotes;
    uint256[] private easterKeys;

    event EasterEgg(string quote);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;

        // Optional: some default easter eggs
        easterQuotes[137] = "Feynman: All good theoretical physics is the result of trying to explain 137.";
        easterKeys.push(137);

        easterQuotes[314] = "Euler: \xCF\x80 is the bridge between logic and form.";
        easterKeys.push(314);

        easterQuotes[273] = "Kelvin: Absolute zero is the beginning of measurement.";
        easterKeys.push(273);

        easterQuotes[1231879] = "Einstein: Imagination is more important than knowledge.";
        easterKeys.push(1231879);

        easterQuotes[4241858] = "Planck: Science progresses funeral by funeral.";
        easterKeys.push(4241858);
    }

    function setEaster(uint256 number, string memory quote) external onlyOwner {
        if (bytes(easterQuotes[number]).length == 0) {
            easterKeys.push(number);
        }
        easterQuotes[number] = quote;
    }

    function _check(uint256 value) internal {
        uint256 valInXGR = value / 1 ether;

        string memory exact = easterQuotes[valInXGR];
        if (bytes(exact).length != 0) {
            emit EasterEgg(exact);
            return;
        }

        for (uint256 i = 0; i < easterKeys.length; i++) {
            uint256 key = easterKeys[i];
            if (_startsWith(valInXGR, key)) {
                emit EasterEgg(easterQuotes[key]);
                return;
            }
        }
    }

    function _startsWith(uint256 full, uint256 prefix) internal pure returns (bool) {
        uint256 prefixDigits = _numDigits(prefix);
        uint256 fullDigits = _numDigits(full);
        if (prefixDigits > fullDigits) {
            return false;
        }
        while (fullDigits > prefixDigits) {
            full /= 10;
            fullDigits--;
        }
        return full == prefix;
    }

    function _numDigits(uint256 x) internal pure returns (uint256) {
        uint256 digits = 0;
        do {
            digits++;
            x /= 10;
        } while (x != 0);
        return digits;
    }
}

