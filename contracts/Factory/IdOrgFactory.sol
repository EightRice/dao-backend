// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface IdOrgFactory {
    function createDORG(address votingAddress, address tokenAddress, bool setAsNewMaster) 
    external
    returns(address);

    function getMasterDorg() external view returns(address);
}

