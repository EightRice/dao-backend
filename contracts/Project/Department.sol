// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Token/RepToken.sol";
import "../Arbitration/Arbitration.sol";
import "../DAO/IDAO.sol";
import "../Voting/IVoting.sol";

import {HandleDAOInteraction} from "../DAO/DAO.sol";
import {HandlePaymentToken, PayrollRoster, Payroll} from "../Payment/ProjectPayments.sol";



contract InternalProject is HandleDAOInteraction,HandlePaymentToken, PayrollRoster{ 
    // maybe inherit from mutual parent with Project contract.

    // possibility to turn project into ongoing

    enum ProjectType {fixedTerm, ongoing}
    enum ProjectStatus {proposal, active, inactive, completed, rejected}

    ProjectStatus public status;
    ProjectType public projectType;

    // payment after fixed interval.

    /* ========== CONTRACT VARIABLES ========== */

    IVoting public voting;
    RepToken public repToken;

    uint256 public startingTime;
    uint256 public votingDuration;
    uint256 public votes_pro;
    uint256 public votes_against;
    uint256 public numberOfVotes;
    uint256 public paymentInterval;

    
    uint256 public remainingFunds;
    uint256 public allowedSpendingsPerPaymentCycle;


    uint256 internal thisCyclesRequestedAmount;
    address payable[] public team;
    mapping(address=>bool) _isTeamMember;
    address payable public teamLead;
    uint256 MILLE = 1000;
    // event PayrollRosterSubmitted();

    /* ========== CONSTRUCTOR ========== */           

    constructor(address _sourceAddress,
                address payable _teamLead,
                address _votingAddress,
                address repTokenAddress,
                uint256 _votingDuration,
                uint256 _paymentInterval,
                uint256 _requestedAmounts,
                uint256 _requestedMaxAmountPerPaymentCycle)
                HandleDAOInteraction(_sourceAddress){   
        paymentInterval = _paymentInterval;
        remainingFunds = _requestedAmounts;
        allowedSpendingsPerPaymentCycle = _requestedMaxAmountPerPaymentCycle;
        teamLead = _teamLead;
        team.push(teamLead);
        _isTeamMember[teamLead] = true;
        repToken=RepToken(repTokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        voting = IVoting(_votingAddress);
    }


     /* ========== VOTING  ========== */

    function voteOnProject(bool decision) external returns(bool){
        // // if the duration is less than a week, then set flag to 1
        // bool durationCondition = block.timestamp - startingTime > votingDuration;
        // bool majorityCondition = votes_pro > repToken.totalSupply() / 2 || votes_against > repToken.totalSupply() / 2;
        // if(durationCondition || majorityCondition ){ 
        //     _registerVote();
        //     return false;
        // }
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
        // bool durationCondition = block.timestamp - startingTime > votingDuration;
        // bool majorityCondition = votes_pro > repToken.totalSupply() / 2 || votes_against > repToken.totalSupply() / 2;
        // require(durationCondition || majorityCondition, "Voting is still ongoing");
        _registerVote();
    }


    function _registerVote() internal {
        require(status == ProjectStatus.proposal || status == ProjectStatus.active);
        status = (votes_pro > votes_against) ? ProjectStatus.active : ProjectStatus.rejected ;
    }


    function submitPayrollRoster(
        address[] calldata _payees,
        uint256[] calldata _amounts) 
    external 
    {
        _registerVote();

        uint256 _thisCyclesRequestedAmount;
        for (uint256 i=0; i<_payees.length; i++){
            _thisCyclesRequestedAmount += _amounts[i] ;
        }

        _submitPayrollRoster(_payees, _amounts); 

        require(_thisCyclesRequestedAmount <= allowedSpendingsPerPaymentCycle, "requested amount supersedes cycle allowance");
        require(_thisCyclesRequestedAmount <= remainingFunds, "requested amount supersedes remaining funds"); 
        remainingFunds -= _thisCyclesRequestedAmount;
        // set requested amount for this cycle.
        thisCyclesRequestedAmount = _thisCyclesRequestedAmount;
        
        // emit PayrollRosterSubmitted();  // maybe milestones[milestoneIndex].payrollVetoDeadline
    }



    function payout(uint256 shareValue) 
    external 
    onlyDAO
    {
        
        _payout(shareValue);

        // NOTE: maybe deduct the expenses from the allowed spendings per month and transfer the rest over to the next months allowed spendings. 
            
        

        // delete all cached payouts, payoutTokens and thisCyclesRequestedAmountPerToken
        // delete payouts;
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
        require(msg.sender==teamLead, "only Project Manager");
        _;
    }

}