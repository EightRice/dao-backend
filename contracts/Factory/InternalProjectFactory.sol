// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Project/Department.sol";

contract ClientProjectFactory{


    function createInternalProject(address payable _teamLead,
                                   address _repTokenAddress,
                                   address _paymentTokenAddress,
                                   address _votingAddress,
                                   uint256 _votingDuration,
                                   uint256 _paymentInterval,
                                   uint256 _requestedAmount) 
    external
    returns(address)
    {

        return address(new InternalProject(
                                msg.sender, // the source.
                                _teamLead,
                                _repTokenAddress,
                                _paymentTokenAddress,
                                _votingAddress,
                                _votingDuration,
                                _paymentInterval,
                                _requestedAmount));
    }

}