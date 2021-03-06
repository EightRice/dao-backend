// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "../Token/RepToken.sol";
import "../Arbitration/Arbitration.sol";
import "../DAO/IDAO.sol";
import "../Voting/IVoting.sol";

import {HandleDAOInteraction} from "../DAO/DAO.sol";

import {PayrollRoster, Payroll, HandlePaymentToken} from "../Payment/ProjectPayments.sol";


/// @title Main Project contract
/// @author dOrg
/// @dev Experimental status
/// @custom:experimental This is an experimental contract.
contract ClientProject is HandleDAOInteraction, HandlePaymentToken, PayrollRoster{
    /* ========== CONTRACT VARIABLES ========== */

    IRepToken public repToken;
    ArbitrationEscrow public arbitrationEscrow;
    IVoting public voting;

    /* ========== ENUMS AND STRUCTS ========== */

    enum ProjectStatus {proposal, active, inDispute, inactive, completed, rejected}

    struct paymentProposal {
        uint256 amount ;  // TODO: diminish the size here from uint256 to something smaller
        uint16 numberOfApprovals;         
    }
    
    struct CurrentVoteId {
        uint256 onProject;
        uint256 onSourcingLead;
        uint256 onTeam;
    }

    /* ========== VOTING VARIABLES ========== */
    ProjectStatus public status;
    CurrentVoteId public currentVoteId;
    uint256 public votes_pro;
    uint256 public votes_against;
    uint256 public votingDuration;  // in seconds (1 day = 86400)
    uint256 public vetoDurationForPayments = 300 ;// in seconds
    uint256 public startingTime;    
    
    // TODO: Discuss in dOrg
    uint256 public defaultThreshold = 500;  // in permille
    uint256 public exclusionThreshold = 500;  // in permille

    mapping(address=>bool) _isTeamMember;
    mapping(address=>mapping(address=>bool)) public excludeMember;
    mapping(address=>uint16) public voteToExclude;
    mapping (address=>mapping(address=>uint256)) public votesForNewSourcingLead;
    mapping (address=>mapping(address=>bool)) public alreadyVotedForNewSourcingLead;
    /* ========== ROLES ========== */

    address payable public client;
    address payable public sourcingLead;
    address payable public arbiter;
    address payable[] public team;
    /* ========== PAYMENT ========== */
    
    uint256 public repWeiPerPaymentGwei = 10**9;  // 10**9; for stablecoin
    // You earn one WETH, then how many reptokens you get?
    // (10**18) * (repToPaymentRatio) / (10 ** 9)
    // where the repToPaymentRatio = 3000 * 10 ** 9

    enum MotionType {
        removeTeamMember,
        changeSourcingLead,
        disputeProject,
        refundClient
    }

    struct Motion {
        MotionType motionType;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 timestamp;
        address nominee;
        bool inactive;
    }

    Motion[] public motions;


    /* ========== EVENTS ========== */

    event Disputed(address disputer);

    /* ========== CONSTRUCTOR ========== */
    

    constructor(address _sourceAddress,
                address payable _sourcingLead,
                address payable _client,
                address payable _arbiter,
                address repTokenAddress,
                address _arbitrationEscrow,   //TODO! Better use address!
                address _votingAddress,
                address _paymentTokenAddress,
                uint256 _votingDuration)
        HandleDAOInteraction(_sourceAddress)
    {
        _setPaymentToken(_paymentTokenAddress);
        status=ProjectStatus.proposal;
        sourcingLead=_sourcingLead;
        team.push(sourcingLead);
        _isTeamMember[sourcingLead] = true;
        client=_client;
        arbitrationEscrow=ArbitrationEscrow(_arbitrationEscrow);
        arbiter=_arbiter;
        repToken = IRepToken(repTokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        voting = IVoting(_votingAddress);
        // use default ratio between Rep and Payment
        
        
    }

    /* ========== VOTING  ========== */

    function voteOnProject(bool decision) external returns(bool){
        // if the duration is less than a week, then set flag to 1
        if(block.timestamp - startingTime > votingDuration ){ 
            _registerVote();
            return false;
        }
        uint256 vote = repToken.balanceOf(msg.sender);
        if (decision){
            votes_pro += vote ;// add safeMath
        } else {
            votes_against += vote;  // add safeMath
        }
        return true;
    }


    function registerVote() public {
        require(block.timestamp - startingTime > votingDuration, "Voting is still ongoing");
        _registerVote();
    }

    function _registerVote() internal {
        if (votes_pro > votes_against) {
            // transact money into enscrow
            status = ProjectStatus.inactive;
       
        } else {
            status = ProjectStatus.rejected;
            // in the case that the client had already some funds locked
            _returnFundsToClient(paymentToken.balanceOf(address(this)));
        }
    }



    /* ========== REPUTATION ========== */

    function setRepWeiValuePerGweiTokenValue(uint256 _repWeiPerPaymentGwei) public {
        // TODO: Careful with the guard
        // require(msg.sender == address(source) || msg.sender==sourcingLead);
        repWeiPerPaymentGwei = _repWeiPerPaymentGwei;
    }

    function sendRepToken(address _to, uint256 _amount) public {
        // TODO send rep from source.
        repToken.transfer(_to, _amount);
    }

    /* ========== TEAM HANDLING ========== */
    
    function addTeamMember (address payable _teamMember) public {
        // add require only majority or sourcing lead and source contract
        require(msg.sender==sourcingLead || msg.sender==address(source));
        team.push(_teamMember);
        _isTeamMember[_teamMember] = true;
    }

    
    function excludeFromTeam(address _teamMember) external {
        // TODO!!!with some vetos or majority
        require(excludeMember[msg.sender][_teamMember] == false && sourcingLead!=_teamMember);
        excludeMember[msg.sender][_teamMember] = true;
        voteToExclude[_teamMember] += 1;
        if (voteToExclude[_teamMember]> (team.length * exclusionThreshold ) / 100){
            _isTeamMember[_teamMember]= false;
            // TODO: add these to the motions, once it passes
            motions.push(Motion({
                motionType: MotionType.removeTeamMember,
                votesFor: voteToExclude[_teamMember],
                votesAgainst: 0,
                timestamp: block.timestamp,
                nominee: _teamMember,
                inactive: true
            }));
        }
    }
    
    function startSourcingLeadVote() external {
        // TODO: Save conversion to uint120!
        currentVoteId.onSourcingLead = voting.start(1, 0, uint120(defaultThreshold), uint120(team.length));
    }

    function replaceSourcingLead(address _nominee) external {
        require(_nominee!=sourcingLead);  // Maybe allow also sourcingLead to         
        voting.safeVote(currentVoteId.onSourcingLead, msg.sender, _nominee, 1);
        voting.getStatus(currentVoteId.onSourcingLead); // you cant hear me probably.
    }

    function claimSourcingLead() external {
        (uint8 votingStatus, address elected) = voting.getStatusAndElected(currentVoteId.onSourcingLead);
        require(votingStatus==2, "Voting has not passed");
        require(elected == msg.sender, "Only elected Project Manager can claim!");
        sourcingLead = payable(msg.sender);
        // reset all the votes maybe.
    }

    /* ========== PROJECT HANDLING ========== */

    function startProject() external{
        require(msg.sender==sourcingLead, "only Sourcing Lead");
        require(status == ProjectStatus.inactive, "not allowed to change status");
        // is there enough money in escrow and project deposited by client?
        status = ProjectStatus.active;
    }



    /* ========== PAYMENTS HANDLING ========== */

    function changePaymentMethod(address _tokenAddress, uint256 _repWeiPerPaymentGwei) external {
        require(paymentToken.balanceOf(address(this))==0, "Previous Token needs to be depleted before the change");
        _changePaymentMethod(_tokenAddress, _repWeiPerPaymentGwei);
    }

    function _changePaymentMethod(address _tokenAddress, uint256 _repWeiPerPaymentGwei) internal {
        // TODO: Maybe a guard should be put in place here.
        // require(msg.sender == address(source) || msg.sender== sourcingLead, "source or sourcing Lead!");
        paymentToken = IERC20(_tokenAddress);
        // set the new ratio.
        setRepWeiValuePerGweiTokenValue(_repWeiPerPaymentGwei);
    }


    function _returnFundsToClient(uint256 _amount) internal {
        // return funds to client
        paymentToken.transfer(client, _amount);
    }

    
    // dev A doesnt withdraw --> then the con 
    function submitPayrollRoster(address[] memory _payees, uint256[] memory _amounts) external {
        require(msg.sender==sourcingLead, "only sourcing Lead");
        _submitPayrollRoster(_payees, _amounts);
    }

     // add function if its vetoed   
    function vetoPayrollRoster() external {
        require(_isTeamMember[msg.sender]);
        _vetoPayrollRoster();
    }

    function batchPayout() external {
        _payout();
    }

    
}
