// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Project/Department.sol";

contract InternalProjectFactory{

    function createInternalProject(address payable _teamLead,
                                   address _votingAddress,
                                   uint256 _votingDuration,
                                   uint256 _paymentInterval,
                                   uint256 _requestedAmounts) 
    external
    returns(address)
    {

        return address(new InternalProject(
                                msg.sender, // the source.
                                _teamLead,
                                _votingAddress,
                                _votingDuration,
                                _paymentInterval,
                                _requestedAmounts));
    }

}