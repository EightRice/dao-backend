// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface ISource {
    function mintRepTokens(address payable payee, uint256 amount) external;
    function transferToken(address _erc20address, address _recipient, uint256 _amount) external; 
    function mintRepTokens(address payee, uint256 amount) external;
    function transferToken(address _erc20address, address _recipient, uint256 _amount) external; 
    function getStartPaymentTimer() external returns(uint256);
    function getFirstPayrollSubmissionDue() view external returns(uint256);
    function getSecondPayrollSubmissionDue() view external returns(uint256);
    function isRegisteredToken(address _tokenAddress) view external returns(bool);
    function getConversionRate(address _tokenAddress) view external returns(uint256);
    function getDefaultPaymentToken() view external returns(address);
    function getVetoDue() view external returns(uint256);
}