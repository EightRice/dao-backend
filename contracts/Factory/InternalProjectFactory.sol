// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Project/Department.sol";

contract InternalProjectFactory{

    function createInternalProject(address payable _teamLead,
                                   address _votingAddress,
                                   address _repTokenAddress,
                                   uint256 _votingDuration,
                                   uint256 _paymentInterval,
                                   uint256 _requestedAmounts,
                                   uint256 _requestedMaxAmountPerPaymentCycle) 
    external
    returns(address)
    {

        return address(new InternalProject(
                                msg.sender, // the source.
                                _teamLead,
                                _votingAddress,
                                _repTokenAddress,
                                _votingDuration,
                                _paymentInterval,
                                _requestedAmounts,
                                _requestedMaxAmountPerPaymentCycle));
    }

}