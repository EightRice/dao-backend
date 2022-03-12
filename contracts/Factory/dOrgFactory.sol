// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../DAO/DAO.sol";
import "../Token/RepToken.sol";

contract dOrgFactory{

    address masterDORG;

    constructor (){
        masterDORG = msg.sender;
    }
    
    function createDORG(
        address votingAddress,
        address repTokenAddress,
        address[] memory newMembers,
        uint256[] memory newBalances,
        bool setAsNewMaster) 
    public
    returns(address){
        if (setAsNewMaster && msg.sender==masterDORG){
            masterDORG = address(new Source(votingAddress,repTokenAddress, newMembers, newBalances));
            return masterDORG;
        } else {
            return address(new Source(votingAddress,repTokenAddress, newMembers, newBalances));
        }
    }

    function getMasterDorg() external view returns(address){
        return masterDORG;
    }

}