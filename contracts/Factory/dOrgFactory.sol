// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../DAO/DAO.sol";
import "../Token/RepToken.sol";

contract dOrgFactory{

    address public masterDORG;

    constructor (address votingAddress, address repTokenAddress) {
        createDORG(votingAddress, repTokenAddress, true);
    }
    
    function createDORG(address votingAddress, address repTokenAddress, bool setAsNewMaster) 
    public
    returns(address){
        if (setAsNewMaster && msg.sender==masterDORG){
            masterDORG = address(new Source(votingAddress,repTokenAddress));
            return masterDORG;
        } else {
            return address(new Source(votingAddress,repTokenAddress));
        }
    }

}