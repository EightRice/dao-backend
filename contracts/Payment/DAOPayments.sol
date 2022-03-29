// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IERC20} from "../Token/IERC20.sol";
import {DAOMembership} from "../DAO/Membership.sol";
import {Poll} from "../Voting/Poll.sol";



interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}


contract DAOPaymentTokens is Poll, DAOMembership {
    
    bytes4 internal setDefaultPaymentTokenId = bytes4(keccak256("setDefaultPaymentToken(address)"));
    bytes4 internal removePaymentTokenId = bytes4(keccak256("removePaymentToken(address)"));
    bytes4 internal addPaymentTokenId = bytes4(keccak256("addPaymentToken(address)"));

    address[] public paymentTokens;
    IERC20 public defaultPaymentToken;
    mapping(address => bool) _isRegisteredToken;
    mapping(address => uint256) internal conversionRate;


    // change default payment token.
    // add new payment tokens.
    function removePaymentToken(address _erc20TokenAddress) 
    external
    onlyRegisteredToken(_erc20TokenAddress)
    {
        // require(_isVoteImplementationCall());
        uint256 index = 0;
        for (uint256 i = 0; i<paymentTokens.length; i++){
            if (_erc20TokenAddress==paymentTokens[i]){
                index = i;
                break;
            }
        }
        paymentTokens[index] = paymentTokens[paymentTokens.length - 1];
        // delete paymentTokens[paymentTokens.length -1];
        paymentTokens.pop();
        _isRegisteredToken[_erc20TokenAddress] = false;
        conversionRate[_erc20TokenAddress] = 0;
    }

    function addPaymentToken(address _erc20TokenAddress, uint256 _conversionRate)
    external
    {
        // require(_isVoteImplementationCall());
        require(!isRegisteredToken(_erc20TokenAddress));
        paymentTokens.push(_erc20TokenAddress);
        _isRegisteredToken[_erc20TokenAddress] = true;
        conversionRate[_erc20TokenAddress] = _conversionRate;
        // TODO: Might add Oracle functionality at some point
    }

    
    function setDefaultPaymentToken(address _erc20TokenAddress)
    external
    onlyRegisteredToken(_erc20TokenAddress)
    {
        // require(_isVoteImplementationCall());
        defaultPaymentToken = IERC20(_erc20TokenAddress);
    }

    function updateConversionRate(address _tokenAddress, uint256 newConversionRate)
    external
    {
        // FIXME: FIX THE GUARD TO ENTER THIS FUNCTION
        conversionRate[_tokenAddress] = newConversionRate;
    }

    /** VIEW FUNCTIONS */

    function getDefaultPaymentToken()
    external
    view
    returns(address)
    {
        return address(defaultPaymentToken);
    }

    function getConversionRate(address _tokenAddress)
    public 
    view
    onlyRegisteredToken(_tokenAddress)
    returns(uint256)
    {
        return conversionRate[_tokenAddress];
    }

    function isRegisteredToken(address _tokenAddress)
    public 
    view
    returns(bool)
    {
        return _isRegisteredToken[_tokenAddress];
    }

    modifier onlyRegisteredToken(address _tokenAddress){
        require(isRegisteredToken(_tokenAddress));
        _;
    }

}


struct CycleParameters {
    uint256 paymentInterval;
    uint256 vetoDuration;
    uint256 secondPayrollSubmissionDuration;
    uint256 triggerPaymentDuration;
    uint256 firstPayrollSubmissionMinDuration;
}

struct Cycle {
    uint256 start;
    uint256 paymentDue;
    uint256 firstPayrollSubmissionDue;
    uint256 vetoDue;
    uint256 secondPayrollSubmissionDue;
}



contract DAOPaymentCycle is Poll {

    bytes4 internal changePaymentIntervalId = bytes4(keccak256("changePaymentInterval(uint256)"));
    bytes4 internal changeSecondPayrollSubmissionDurationId = bytes4(keccak256("changeSecondPayrollSubmissionDuration(uint256)"));
    bytes4 internal changeVetoDurationId = bytes4(keccak256("changeVetoDuration(uint256)"));
    bytes4 internal changeTriggerPaymentDurationId = bytes4(keccak256("changeTriggerPaymentDuration(uint256)"));
    bytes4 internal resetPaymentTimerId = bytes4(keccak256("resetPaymentTimer(uint256)"));


    // NOTE: Dividing up the constants that determine the payment cycle from the 
    // actual due dates allows for the former to be altered through vote
    // without affecting the sudden adjustment of the latter during the cycle.
    // NOTE: making most quantities a duration 
    // allows for the automatic readjustment of the payroll submission relative to the payment interval.
    // So the latter can be altered by vote without a separate vote being necessary for the former. 
    CycleParameters internal cycleParameters = CycleParameters({
        paymentInterval: 30 days,
        vetoDuration: 3 days,
        secondPayrollSubmissionDuration: 2 days,
        triggerPaymentDuration: 3 days,
        firstPayrollSubmissionMinDuration: 4 days
    });

    Cycle internal cycle;


    constructor() {
        _resetPaymentTimer(block.timestamp);
    }



    function changePaymentInterval(uint256 _paymentInterval)
    external
    {    
        // require(_isVoteImplementationCall());
        cycleParameters.paymentInterval = _paymentInterval;
        _checkCycleParameterConsistency();
    }

    function changeSecondPayrollSubmissionDuration(uint256 _secondPayrollSubmissionDuration)
    external
    {    
        // require(_isVoteImplementationCall());
        cycleParameters.secondPayrollSubmissionDuration = _secondPayrollSubmissionDuration;
        _checkCycleParameterConsistency();
    }

    function changeVetoDuration (uint256 _vetoDuration) external
    {
        // require(_isVoteImplementationCall());
        cycleParameters.vetoDuration = _vetoDuration;
        _checkCycleParameterConsistency();
    }

    function changeTriggerPaymentDuration (uint256 _triggerPaymentDuration) external
    {
        // require(_isVoteImplementationCall());
        cycleParameters.triggerPaymentDuration = _triggerPaymentDuration;
        _checkCycleParameterConsistency();
    }
    

    function resetPaymentTimer(uint256 _newStartTime) 
    external 
    {        
        // require(_isVoteImplementationCall());
        _resetPaymentTimer(_newStartTime);
    }


    function _resetPaymentTimer(uint256 _startTime) 
    internal
    {
        cycle.start = _startTime;
        cycle.paymentDue = _startTime + cycleParameters.paymentInterval;
        cycle.secondPayrollSubmissionDue = cycle.paymentDue - cycleParameters.triggerPaymentDuration;
        cycle.vetoDue = cycle.secondPayrollSubmissionDue - cycleParameters.secondPayrollSubmissionDuration;
        cycle.firstPayrollSubmissionDue = cycle.vetoDue - cycleParameters.vetoDuration;
    }

    function _checkCycleParameterConsistency()
    view
    internal {
        uint256 cumulativeDuration = (
            cycleParameters.vetoDuration + 
            cycleParameters.secondPayrollSubmissionDuration +
            cycleParameters.triggerPaymentDuration +
            cycleParameters.firstPayrollSubmissionMinDuration);
        require(cycleParameters.paymentInterval >= cumulativeDuration);
    }


    /* VIEW FUNCTIONS */

    function getFirstPayrollSubmissionDue()
    view
    public
    returns(uint256) {
        return cycle.firstPayrollSubmissionDue;
    }

    function getVetoDue()
    view 
    public
    returns(uint256) {
        return cycle.vetoDue;
    }

    function getSecondPayrollSubmissionDue() view public returns(uint256) {
        return cycle.secondPayrollSubmissionDue;
    }

    function getPaymentDue() view public returns(uint256) {
        return cycle.paymentDue;
    }

    function getPaymentInterval() view public returns(uint256) {
        return cycleParameters.paymentInterval;
    }

    function getStartPaymentTimer() view external returns(uint256) {
        return cycle.start;
    }
    
    /* MODIFIER */

    modifier maySubmitPayment() {
        // TODO: Change This.
        require(block.timestamp > getSecondPayrollSubmissionDue() && block.timestamp <= getPaymentDue());
        _;
    }

}

