// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IRepToken, HandlesRepToken} from "../Token/RepToken.sol";


contract DAOMembership is HandlesRepToken{

    function _isDAOMember(address user) internal view returns(bool){
        return repToken.balanceOf(user) > 0;
    }


    modifier onlyDAOMember {
        require(_isDAOMember(msg.sender));
        _;
    }
}