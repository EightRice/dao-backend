// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface ISource {
    function mintRepTokens(address payable payee, uint256 amount) external;
    function transferToken(address _erc20address, address _recipient, uint256 _amount) external; 
    function setPayrollRoster(address payable[] memory _payees, uint256[] memory _amounts) external;
    function getStartPaymentTimer() external returns(uint256);
    function mintRep(uint256 _amount) external;
    function burnRep() external;
}