// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface IClientProjectFactory {
    function createClientProject(address payable _souringLead, 
                                 address _client,
                                 address _arbiter,
                                 address _repTokenAddress,
                                 address _arbitrationEscrow,
                                 address _votingAddress,
                                 address _paymentTokenAddress,
                                 uint256 _votingDuration) 
    external
    returns(address);
}