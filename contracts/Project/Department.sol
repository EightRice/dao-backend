// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Token/RepToken.sol";
import "../Arbitration/Arbitration.sol";
import "../DAO/IDAO.sol";
import "../Voting/IVoting.sol";

struct Payout {
    address payee;
    uint256 amountInStableCointEquivalent;
}

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

    
    uint256 internal remainingFunds;
    uint256 internal allowedSpendingsPerPaymentCycle;

    Payout[] payouts;

    uint256 internal thisCyclesRequestedAmount;

    address payable[] team;
    mapping(address=>bool) _isTeamMember;
    address payable public teamLead;

    uint256 MILLE = 1000;
    
    event PayrollRosterSubmitted();


    /* ========== CONSTRUCTOR ========== */
                

    constructor(address _sourceAddress,
                address payable _teamLead,
                address _votingAddress,
                uint256 _votingDuration,
                uint256 _paymentInterval,
                uint256 _requestedAmounts,
                uint256 _requestedMaxAmountPerPaymentCycle){
                    
        paymentInterval = _paymentInterval;
        remainingFunds = _requestedAmounts;
        allowedSpendingsPerPaymentCycle = _requestedMaxAmountPerPaymentCycle;
        teamLead = _teamLead;
        team.push(teamLead);
        _isTeamMember[teamLead] = true;
        source = ISource(_sourceAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        voting = IVoting(_votingAddress);
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
        
    }




    function submitPayrollRoster(
        address payable[] memory _payees,
        uint256[] memory _amounts) 
    external 
    onlyProjectManager
    {
        // bool withinFirstSubmissionPeriod = block.timestamp <= source.getFirstPayrollSubmissionDue();
        // bool withinSecondSubmissionPeriod = block.timestamp > source.getVetoDue() && block.timestamp <= source.getSecondPayrollSubmissionDue();

        // require(withinFirstSubmissionPeriod || withinSecondSubmissionPeriod);

        require(_payees.length == _amounts.length);

        
        uint256 _thisCyclesRequestedAmount;
        for (uint256 i=0; i<_payees.length; i++){

            _thisCyclesRequestedAmount += _amounts[i] ;

            payouts.push(Payout({
                payee: _payees[i],
                amountInStableCointEquivalent: _amounts[i]
            }));

        }

        require(_thisCyclesRequestedAmount <= allowedSpendingsPerPaymentCycle);
        require(_thisCyclesRequestedAmount <= remainingFunds); 
        remainingFunds -= _thisCyclesRequestedAmount;

        // set requested amount for this cycle.
        thisCyclesRequestedAmount = _thisCyclesRequestedAmount;
        
        // emit PayrollRosterSubmitted();  // maybe milestones[milestoneIndex].payrollVetoDeadline
    }



    function payout(uint256 shareValue) 
    external 
    onlyDAO
    {
        require(shareValue<=1e18); 

        address defaultPaymentToken = source.getDefaultPaymentToken();
        uint256 conversionRate = source.getConversionRate(defaultPaymentToken);

        for (uint256 i; i<payouts.length; i++){
            IERC20(defaultPaymentToken).transferFrom(
                address(source),
                payouts[i].payee,
                (payouts[i].amountInStableCointEquivalent * shareValue) / conversionRate);
            
            // transfer the rest as a redeemable DeptToken and allocate RepToken
            /*if (shareValue>0){
                deptToken.transferFrom(
                    address(source),
                    payouts[i].payee,
                    (payouts[i].amountInStableCointEquivalent * (1e18 - shareValue)) / 1e18);
            }*/

            source.mintRepTokens(
                payouts[i].payee,
                (payouts[i].amountInStableCointEquivalent * shareValue) / 1e18);

            // NOTE: maybe deduct the expenses from the allowed spendings per month and transfer the rest over to the next months allowed spendings. 
            
        }

        // delete all cached payouts, payoutTokens and thisCyclesRequestedAmountPerToken
        delete payouts;
        // also delte this cylces total requested amount.
        thisCyclesRequestedAmount = 0;      

    }  

    function getThisCyclesRequestedAmount()
    external 
    view 
    returns (uint256)
    {
        return thisCyclesRequestedAmount;
    }

    modifier onlyMember {
        require(repToken.balanceOf(msg.sender)>0, "only Members");
        _;
    }

    modifier onlyDAO {
        require(msg.sender==address(source), "only DAO");
        _;
    }

    modifier onlyProjectManager {
        require(msg.sender==teamLead, "only DAO");
        _;
    }

}