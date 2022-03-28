// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PaymentToken is ERC20 {
    uint256 public maxFreeMintingAllowance; 
    constructor (string memory name, string memory symbol) ERC20(name, symbol) {
        maxFreeMintingAllowance = 1_000_000 * (10**decimals());
    }

    function freeMint(uint256 amount) external {
        _mint(msg.sender, amount);
        require(balanceOf(msg.sender) <= maxFreeMintingAllowance, "Exceeds Free Minting allowance of 1 Million");
    }
}