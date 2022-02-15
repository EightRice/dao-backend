// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface IInternalProject {
    function pay() external returns(uint256 totalPaymentValue, uint256 totalRepValue);
    function withdraw() external;
}