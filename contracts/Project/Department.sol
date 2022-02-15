// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Token/IRepToken.sol";
import "../Arbitration/Arbitration.sol";
import "../DAO/IDAO.sol";
import "../Voting/IVoting.sol";

contract InternalProject { 
    // maybe inherit from mutual parent with Project contract.

    // possibility to turn project into ongoing

    enum ProjectType {fixedTerm, ongoing}
    enum ProjectStatus {proposal, active, inactive, completed, rejected}

    ProjectStatus public status;
    ProjectType public projectType;

    // payment after fixed interval.

    /* ========== CONTRACT VARIABLES ========== */

    IVoting public voting;
    IRepToken public repToken;
    ISource public source;
    IERC20 public paymentToken;


    uint256 public startingTime;
    uint256 public votingDuration;
    uint256 public votes_pro;
    uint256 public votes_against;
    uint256 public numberOfVotes;
    uint256 public paymentInterval;

    struct Payout {
        address payee;
        uint256[] erc20Amounts;
        address[] erc20Addresses;
    }

    Payout[] payoutSpecs;

    address payable[] team;
    mapping(address=>bool) _isTeamMember;
    mapping(address=>uint256) public funds;
    address[] public registeredPaymentTokens;
    address payable public teamLead;

    uint256 MILLE = 1000;
    
    event PayrollRosterSubmitted();


    /* ========== CONSTRUCTOR ========== */
                

    constructor(address _sourceAddress,
                address payable _teamLead,
                address _votingAddress,
                uint256 _votingDuration,
                uint256 _paymentInterval,
                uint256[] memory _requestedAmounts,
                address[] memory _requestedTokenAddresses){
                    
        require(_requestedAmounts.length==_requestedTokenAddresses.length);
        paymentInterval = _paymentInterval;
        for (uint256 i; i<_requestedAmounts.length; i++){
            funds[_requestedTokenAddresses[i]] = _requestedAmounts[i];
        }
        registeredPaymentTokens = _requestedTokenAddresses;
        status = ProjectStatus.proposal;
        teamLead = _teamLead;
        team.push(teamLead);
        _isTeamMember[teamLead] = true;
        source = ISource(_sourceAddress);
        repToken = IRepToken(_requestedTokenAddresses[0]);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        voting = IVoting(_votingAddress);
        // use default ratio between Rep and Payment
        // PAYMENT OPTIONS ? (A,B  or C)

        // RepSplitting Options
        // _addRepSplittingOption(uint32(250), uint32(750));
        // _addRepSplittingOption(uint32(0), uint32(1000));
    }




     /* ========== VOTING  ========== */


    function voteOnProject(bool decision) external returns(bool){
        // if the duration is less than a week, then set flag to 1
        bool durationCondition = block.timestamp - startingTime > votingDuration;
        bool majorityCondition = votes_pro > repToken.totalSupply() / 2 || votes_against > repToken.totalSupply() / 2;
        if(durationCondition || majorityCondition ){ 
            _registerVote();
            return false;
        }
        uint256 vote = repToken.balanceOf(msg.sender);
        if (decision){
            votes_pro += vote ;// add safeMath
        } else {
            votes_against += vote;  // add safeMath
        }
        numberOfVotes += 1;
        return true;
    }
 

    function registerVote() external {
        bool durationCondition = block.timestamp - startingTime > votingDuration;
        bool majorityCondition = votes_pro > repToken.totalSupply() / 2 || votes_against > repToken.totalSupply() / 2;
        require(durationCondition || majorityCondition, "Voting is still ongoing");
        _registerVote();
    }


    function _registerVote() internal {
        status = (votes_pro > votes_against) ? ProjectStatus.active : ProjectStatus.rejected ;
        if (status == ProjectStatus.active){
            for (uint256 i; i<registeredPaymentTokens.length; i++){
                source.transferToken(registeredPaymentTokens[i], address(this), funds[registeredPaymentTokens[i]]);
            }
        }
    }

    uint256 _totalPaymentValueThisPayroll = 0;
    uint256 _totalRepValueThisPayroll = 0;



    function submitPayrollRoster(address payable[] memory _payees, uint256[][] memory _amounts, uint256[][] memory _erc20Addresses) external {
        require(msg.sender==teamLead && _payees.length == _amounts.length);
        // TODO: do we need the _payees.length == _amounts.length requirements.
        // Will the contract function call revert if _amounts[i] doesnt exist?
        // If not, then we need to add another row with _repAmount length. 
        require(block.timestamp - source.getStartPaymentTimer() < (paymentInterval * 3) / 4);

        for (uint256 i=0; i<_payees.length; i++){
            payoutSpecs.push(Payout({
                payee: _payees[i],
                erc20Amounts: _erc20Amounts[i],
                erc20Addresses _erc20Addresses[i]
            }))
        }
        
        uint256 totalPaymentValue = 0;
        uint256 totalRepValue = 0;
        for (uint256 i; i<_payees.length; i++){
            totalPaymentValue += _amounts[i];
            totalRepValue += _repAmounts[i];
        } 
        // TODO: Maybe check for available funds
        // require(totalPaymentValue <= funds, "Not enough funds in contract");
 
        payees = _payees;
        amounts = _amounts;
        repAmounts = _repAmounts;

        // check whether requested and then approved amount is not exceeded

        emit PayrollRosterSubmitted();  // maybe milestones[milestoneIndex].payrollVetoDeadline
    }
   

    function pay() external returns(uint256 totalPaymentValue, uint256 totalRepValue) {
        require(msg.sender==address(source));

        
        for (uint256 i; i<payoutSpecs.length; i++){
            for (uint256 j; j<payoutSpecs[i].erc20Addresses.length; j++){
                uint256 paymentAmount =  payoutSpecs[i].erc20Amounts[j];
                IERC20(payoutSpecs[i].erc20Addresses[j]).transfer(payoutSpecs[i].payee, paymentAmount);
                funds[payoutSpecs[i].erc20Addresses[j]] -= paymentAmount[i];
            }
            
        }

        // and set payee amounts to []
        // delete payees;
        // delete amounts;
        // delete repAmounts;
        delete payoutSpecs;
        totalPaymentValue = _totalPaymentValueThisPayroll;
        totalRepValue = _totalRepValueThisPayroll;
        _totalPaymentValueThisPayroll = 0;
        _totalRepValueThisPayroll = 0;

    }    


    function withdraw() external {
        require(msg.sender==address(source));
        for (uint256 i; i<registeredPaymentTokens.length; i++){
            uint256 amount = IERC20(registeredPaymentTokens[i]).balanceOf(address(this));
            IERC20(registeredPaymentTokens[i]).transfer(address(source), amount);
        }
    }


    function freeze() external {
        // lock contract functions until further action.
    }

    function unfreeze() external {
        // unlock contract functions.
    }

}