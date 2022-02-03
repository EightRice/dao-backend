// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface ISource {
    function mintRepTokens(address payable payee, uint256 amount) external;
}