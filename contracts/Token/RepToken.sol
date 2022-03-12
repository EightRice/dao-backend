// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract RepToken is ERC20 {
    address public source;
    // add top 7 holders only for the case that transfers are disabled

    // mapping(address=>address) holderBelow;
    // address topHolder;
    
    constructor(string memory name, string memory symbol) ERC20 (name, symbol)  {
        // _mint(msg.sender, initialSupply);
        source = msg.sender;
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
        // walk up until holderabove has more
        // for (uint256 j=0; j<100; j++){
        //     if (_balances[holder]
        // }
        
    } 

    function burn(address holder, uint256 amount) external onlyDAO() {
        _burn(holder, amount);
    }

    modifier onlyDAO() {
        require(msg.sender==source);
        _;
    }
}