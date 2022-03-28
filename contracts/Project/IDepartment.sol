// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface IInternalProject {
    function payout(uint256 shareValue) external;
    function getThisCyclesRequestedAmount() external view returns (uint256);
}