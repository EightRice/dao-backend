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

    address payable[] public payees;
    uint256[] public amounts;


    struct RepSplittingOption{
        uint32 rep;
        uint32 pay;
    }

    RepSplittingOption[] public repSplittingOptions;
    mapping(address=>uint16) _preferredRepSplitting;

    address payable[] team;
    mapping(address=>bool) _isTeamMember;
    uint256 public funds;
    address payable public teamLead;

    event PayrollRosterSubmitted();


    /* ========== CONSTRUCTOR ========== */
                

    constructor(address _sourceAddress,
                address payable _teamLead,
                address repTokenAddress,
                address paymentTokenAddress,
                address _votingAddress,
                uint256 _votingDuration,
                uint256 _paymentInterval,
                uint256 _requestedAmount){
                    
        paymentInterval = _paymentInterval;
        funds = _requestedAmount;
        status = ProjectStatus.proposal;
        teamLead = _teamLead;
        team.push(teamLead);
        _isTeamMember[teamLead] = true;
        source = ISource(_sourceAddress);
        repToken = IRepToken(repTokenAddress);
        paymentToken = IERC20(paymentTokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        voting = IVoting(_votingAddress);
        // use default ratio between Rep and Payment
        // PAYMENT OPTIONS ? (A,B  or C)

        // RepSplitting Options
        _addRepSplittingOption(uint32(500), uint32(500));
        _addRepSplittingOption(uint32(250), uint32(750));
        _addRepSplittingOption(uint32(0), uint32(1000));
    }

    function _addRepSplittingOption(uint32 _rep, uint32 _pay) internal {
        repSplittingOptions.push(RepSplittingOption({rep: _rep, pay: _pay}));
    }

    function addRepSplittingOption(uint32 _rep, uint32 _pay) external {
        require(msg.sender==teamLead);
        _addRepSplittingOption(_rep, _pay);
    }

    function _setRepSplittingOption(uint16 _optionIndex) external {
        _preferredRepSplitting[msg.sender] = _optionIndex;
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
            source.transfer(funds);
        }
    }


    


    function submitPayrollRoster(address payable[] memory _payees, uint256[] memory _amounts) external {
        require(msg.sender==teamLead && _payees.length == _amounts.length);
        require(block.timestamp - source.getStartPaymentTimer() < (paymentInterval * 3) / 4);
        uint256 totalPaymentValue=0;
        for (uint256 i;i<_payees.length; i++){totalPaymentValue+=_amounts[i];} 
        require(totalPaymentValue<funds, "Not enough funds in contract");
        // require(_isProject[msg.sender]);
        payees = _payees;
        amounts = _amounts;

        // check whether requested and then approved amount is not exceeded

        emit PayrollRosterSubmitted();  // maybe milestones[milestoneIndex].payrollVetoDeadline
    }
   

    function pay () external {
        require(msg.sender==address(source));

        for (uint256 i; i<payees.length; i++){
            RepSplittingOption memory repSplit = repSplittingOptions[_preferredRepSplitting[payees[i]]];
            paymentToken.transfer(payees[i], (amounts[i] * repSplit.pay) / 1000);
            repToken.transfer(payees[i], (amounts[i] * repSplit.rep) / 1000);
            funds -= amounts[i];
        }

        // and set payee amounts to []
        delete payees;
        delete amounts;
    }    

    function withdraw() external {
        require(msg.sender==address(source));
        // if Project Manager misbehaves or for other reasons
        // dOrg can withdraw at any time maybe.
        paymentToken.transfer(address(source), paymentToken.balanceOf(address(this)));
    }

}