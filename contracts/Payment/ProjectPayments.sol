// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HandleDAOInteraction} from "../DAO/DAO.sol";

struct Payroll {
    address[] payees;
    uint256[] amounts;
    uint256 vetoDeadline;
}

abstract contract HandlePaymentToken {
    IERC20 public paymentToken;
    constructor(address _paymentTokenAddress) {
        paymentToken = IERC20(_paymentTokenAddress);
    }
}

abstract contract PayrollRoster is HandleDAOInteraction, HandlePaymentToken {

    event PayrollRosterSubmitted(address payable[] payees, uint256[] amounts);

    Payroll[] public payrolls;

    uint256 constant VETO_TIME = 5 minutes;

    function _submitPayrollRoster(
        address payable[] calldata _payees,
        uint256[] calldata _amounts) 
    internal 
    {
        require(_payees.length == _amounts.length);
        Payroll memory newPayroll;
        for (uint256 i=0; i<_payees.length; i++){
            newPayroll.payees[i] = _payees[i];
            newPayroll.amounts[i] =_amounts[i];
        }
        newPayroll.vetoDeadline = block.timestamp + VETO_TIME;
        payrolls.push(newPayroll);

        emit PayrollRosterSubmitted(_payees, _amounts);
    }

    function _vetoPayrollRoster()
    internal{
        require(block.timestamp < payrolls[payrolls.length - 1].vetoDeadline);
        address [] memory NoPayees;
        uint256 [] memory NoPayments;
        // hopefull errors and reverts.
        payrolls[payrolls.length - 1].payees = NoPayees;
        payrolls[payrolls.length - 1].amounts = NoPayments;
    }

    function payout () external {
        require(block.timestamp >= payrolls[payrolls.length - 1].vetoDeadline);

        for (uint i=0; i<payrolls[payrolls.length-1].payees.length; i++){
            paymentToken.transfer(payrolls[payrolls.length-1].payees[i], payrolls[payrolls.length-1].amounts[i]);
            source.mintRepTokens(payrolls[payrolls.length-1].payees[i], payrolls[payrolls.length-1].amounts[i]);
        }
    }
}