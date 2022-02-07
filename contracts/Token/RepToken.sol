// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract RepToken is ERC20 {
    address public source;
    
    constructor(string memory name, string memory symbol) ERC20 (name, symbol)  {
        // _mint(msg.sender, initialSupply);
        source = msg.sender;
    }



    // TODO! MUST BE REMOVED
    function FREEMINTING(uint256 amount) external {
        _mint(msg.sender, amount);
    }


    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override pure {
        require(false, "non-transferrable");
        
    }

    function mint(address holder, uint256 amount) external onlyDAO() {
        _mint(holder, amount);
    } 

    function burn(address holder, uint256 amount) external onlyDAO() {
        _burn(holder, amount);
    }

    modifier onlyDAO() {
        require(msg.sender==source);
        _;
    }
}