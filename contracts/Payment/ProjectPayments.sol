// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HandleDAOInteraction} from "../DAO/DAO.sol";

struct Payroll {
    address[] payees;
    uint256[] amounts;
    uint256 vetoDeadline;
}

abstract contract HandlePaymentToken is HandleDAOInteraction{
    IERC20 public paymentToken;

    function _setPaymentToken(address _paymentTokenAddress) internal {
        paymentToken = IERC20(_paymentTokenAddress);
    }

    function _getPaymentTokenFromSource() internal view returns(IERC20 _paymentToken) {
        _paymentToken = IERC20(source.getDefaultPaymentToken());
    }

    function _getPaymentTokenConversionRate() internal view returns(uint256 _conversionRate){
        _conversionRate = source.getConversionRate(source.getDefaultPaymentToken());
    }
    
}

abstract contract PayrollRoster is HandleDAOInteraction, HandlePaymentToken {

    event PayrollRosterSubmitted(address[] payees, uint256[] amounts);

    Payroll[] public payrolls;
    uint256 public TAX = 1_000; 

    uint256 constant VETO_TIME = 0 minutes; //5 minutes;

    function getPayeesAndAmounts(uint256 rosterIndex) 
    external 
    view 
    returns(address[] memory _payees, uint256[] memory _amounts, uint256 _vetoDeadline)
    {
        _payees = payrolls[rosterIndex].payees;
        _amounts = payrolls[rosterIndex].amounts;
        _vetoDeadline = payrolls[rosterIndex].vetoDeadline;
    } 

    function _submitPayrollRoster(
        address[] memory _payees,
        uint256[] memory _amounts) 
    internal 
    {
        require(_payees.length == _amounts.length);
        Payroll memory newPayroll;
        uint256 latestIndex = payrolls.length;
        payrolls.push(newPayroll);
        for (uint256 i=0; i<_payees.length; i++){
            payrolls[latestIndex].payees.push(_payees[i]);
            payrolls[latestIndex].amounts.push(_amounts[i]);
        }
        newPayroll.vetoDeadline = block.timestamp + VETO_TIME;

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

    function _payout() internal {
        require(block.timestamp >= payrolls[payrolls.length - 1].vetoDeadline);
        uint256 tax;
        for (uint i=0; i<payrolls[payrolls.length-1].payees.length; i++){
            uint256 netPayout = (payrolls[payrolls.length-1].amounts[i] * (10_000 -TAX)) / 10_000;
            tax += (payrolls[payrolls.length-1].amounts[i] * TAX) / 10_000;
            paymentToken.transfer(payrolls[payrolls.length-1].payees[i], netPayout);
            source.mintRepTokens(payrolls[payrolls.length-1].payees[i], netPayout);
        }
        paymentToken.transfer(address(source), tax);
    }



    function _payout(uint256 shareValue) internal {
        require(block.timestamp >= payrolls[payrolls.length - 1].vetoDeadline, "deadline expired");
        require(shareValue<=1e18, "value should be less than 1e18"); 
        uint256 conversionRate = _getPaymentTokenConversionRate();
        for (uint i=0; i<payrolls[payrolls.length-1].payees.length; i++){
            _getPaymentTokenFromSource().transferFrom(
                address(source),
                payrolls[payrolls.length-1].payees[i],
                (payrolls[payrolls.length-1].amounts[i] * shareValue) / conversionRate);
            source.mintRepTokens(
                payrolls[payrolls.length-1].payees[i],
                (payrolls[payrolls.length-1].amounts[i] * shareValue) / 1e18);
        }
    }
}