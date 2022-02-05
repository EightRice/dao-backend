// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Project/Project.sol";

contract ClientProjectFactory{

    function createClientProject(address payable _sourcingLead, 
                                 address payable _client,
                                 address payable _arbiter,
                                 address _repTokenAddress,
                                 address _arbitrationEscrow,
                                 address _votingAddress,
                                 address _paymentTokenAddress,
                                 uint256 _votingDuration) 
    external
    returns(address)
    {
        return address(new ClientProject(
                                msg.sender, // the source.
                                _sourcingLead,
                                _client,
                                _arbiter,
                                _repTokenAddress,
                                _arbitrationEscrow,
                                _votingAddress,
                                _paymentTokenAddress,
                                _votingDuration));
    }


}