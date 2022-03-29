// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface IInternalProjectFactory {
    function createInternalProject(address payable _teamLead,
                                   address _votingAddress,
                                   uint256 _votingDuration,
                                   uint256 _paymentInterval,
                                   uint256 _requestedAmounts,
                                   uint256 _requestedMaxAmountPerPaymentCycle) 
    external
    returns(address);
}