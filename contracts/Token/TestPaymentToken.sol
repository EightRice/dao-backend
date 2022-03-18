// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Payment is ERC20 {

    constructor (string memory name, string memory symbol) ERC20(name, symbol) {

    }

    function freeMint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}