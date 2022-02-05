// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRepToken.sol";
import "./Arbitration.sol";
import "./IDAO.sol";
import "./IVoting.sol";


/// @title Main Project contract
/// @author dOrg
/// @dev Experimental status
/// @custom:experimental This is an experimental contract.
contract ClientProject{

    /* ========== CONTRACT VARIABLES ========== */

    ISource public source;
    IRepToken public repToken;
    IERC20 public paymentToken;
    ArbitrationEscrow public arbitrationEscrow;
    IVoting public voting;

    /* ========== ENUMS AND STRUCTS ========== */

    enum ProjectStatus {proposal, active, inDispute, inactive, completed, rejected}

    struct paymentProposal {
        uint256 amount ;  // TODO: diminish the size here from uint256 to something smaller
        uint16 numberOfApprovals;         
    }


    struct Milestone {
        bool approved;
        bool inDispute;
        uint256 requestedAmount;
        bytes32 requirementsCid;
        uint256 payrollVetoDeadline;
        address payable[] payees;
        uint256[] payments;
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
    uint256 public vetoDurationForPayments = 4 * 86400 ;// in seconds
    uint256 public startingTime;
    uint256 public approvalAmount;
    
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
    address payable[] team;


    /* ========== PAYMENT ========== */

    uint256 public outstandingInvoice = 0;
    uint256 public repWeiPerPaymentGwei = 10**9;  // 10**9; for stablecoin
    // You earn one WETH, then how many reptokens you get?
    // (10**18) * (repToPaymentRatio) / (10 ** 9)
    // where the repToPaymentRatio = 3000 * 10 ** 9


    /* ========== MILESTONES ========== */

    Milestone[] public milestones;  // holds all the milestones of the project
    
    /* ========== EVENTS ========== */

    event MilestoneApproved(uint256 milestoneIndex, uint256 approvedAmount);
    event RequestedAmountAddedToMilestone(uint256 milestoneIndex, uint256 requetedAmount);
    event PayrollRosterSubmitted(uint256 milestoneIndex);
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
                uint256 _votingDuration){
         
        status=ProjectStatus.proposal;
        sourcingLead=_sourcingLead;
        team.push(sourcingLead);
        _isTeamMember[sourcingLead] = true;
        client=_client;
        arbitrationEscrow=ArbitrationEscrow(_arbitrationEscrow);
        arbiter=_arbiter;
        source = ISource(_sourceAddress);
        repToken = IRepToken(repTokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        voting = IVoting(_votingAddress);
        // use default ratio between Rep and Payment
        _changePaymentMethod(_paymentTokenAddress, repWeiPerPaymentGwei);
        
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


    function registerVote() external {
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


    // add function if its vetoed
    function vetoPayrollRoster(uint256 milestoneIndex) public{
        require(_isTeamMember[msg.sender]);
        uint256 [] memory NoPayments;
        milestones[milestoneIndex].payments = NoPayments;  // TODO: think about storage 
    }


    /* ========== REPUTATION ========== */

    function setRepWeiValuePerGweiTokenValue(uint256 _repWeiPerPaymentGwei) public {
        require(msg.sender == address(source) || msg.sender==sourcingLead);
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
        (uint8 votingStatus, address winner) = voting.getStatusAndWinner(currentVoteId.onSourcingLead);
        require(votingStatus==2, "Voting has not passed");
        require(winner == msg.sender, "Only elected Project Manager can claim!");
        sourcingLead = payable(msg.sender);
        // reset all the votes maybe.
    }
        


    /* ========== PROJECT HANDLING ========== */

    function startProject() external {
        // is there enough money in escrow and project deposited by client?

    }

    function addMilestone(bytes32 requirementsCid) public {
        require(msg.sender == sourcingLead,"Only the sourcing lead can add milestones");
        address payable[] memory NoPayees;
        uint256[] memory NoPayments;
        milestones.push(Milestone({
            approved: false,
            inDispute: false,
            requestedAmount: 0,
            requirementsCid: requirementsCid,
            payrollVetoDeadline: 0,
            payees: NoPayees,
            payments: NoPayments
        }));
    }

    function addAmountToMilestone(uint256 milestoneIndex, uint256 amount)public{
        require(msg.sender == sourcingLead,"Only the sourcing lead can request payment from client");
        milestones[milestoneIndex].requestedAmount = amount;
        emit RequestedAmountAddedToMilestone(milestoneIndex, amount);
    }

    function approveMilestone(uint256 milestoneIndex) public {
        require(msg.sender == client,"Only the client can approve a milestone");
        milestones[milestoneIndex].approved = true;
        emit MilestoneApproved(milestoneIndex, milestones[milestoneIndex].requestedAmount);
        _releaseMilestoneFunds(milestoneIndex);
    }


    /* ========== PAYMENTS HANDLING ========== */

    function changePaymentMethod(address _tokenAddress, uint256 _repWeiPerPaymentGwei) external {
        require(paymentToken.balanceOf(address(this))==0, "Previous Token needs to be depleted before the change");
        _changePaymentMethod(_tokenAddress, _repWeiPerPaymentGwei);
    }

    function _changePaymentMethod(address _tokenAddress, uint256 _repWeiPerPaymentGwei) internal {
        require(msg.sender == address(source) || msg.sender== sourcingLead, "source or sourcing Lead!");
        paymentToken = IERC20(_tokenAddress);
        // set the new ratio.
        setRepWeiValuePerGweiTokenValue(_repWeiPerPaymentGwei);
    }


    function _returnFundsToClient(uint256 _amount) internal {
        // return funds to client
        paymentToken.transfer(client, _amount);
    }

    // dev A doesnt withdraw --> then the con 
    function invoiceClient(uint256 _amount) public {
         //the sourcingLead can claim the milestone
        require(msg.sender==sourcingLead);
        
        outstandingInvoice=_amount;
    }



    function submitPayrollRoster(uint256 milestoneIndex, address[] memory payees, uint256[] memory amounts ) external {
        require(msg.sender==sourcingLead && payees.length == amounts.length);
        milestones[milestoneIndex].payrollVetoDeadline = block.timestamp + vetoDurationForPayments;
        
        emit PayrollRosterSubmitted(milestoneIndex);  // maybe milestones[milestoneIndex].payrollVetoDeadline
    }


    function _releaseMilestoneFunds(uint256 milestoneIndex) internal {
        // client approves milestone, i.e. approve payment to the developer
        require(milestones[milestoneIndex].approved);

        // NOTE; Might be issues with calculating the 10 % percent of the other splits
        uint256 tenpercent=((milestones[milestoneIndex].requestedAmount * 1000) / 10000);
        paymentToken.transfer(address(source), tenpercent); 

    }

   function batchPayout (uint256 milestoneIndex) external {
        require(milestones[milestoneIndex].approved);
        
        require(block.timestamp > milestones[milestoneIndex].payrollVetoDeadline);
        for (uint i=0; i< milestones[milestoneIndex].payees.length; i++){
            paymentToken.transfer(milestones[milestoneIndex].payees[i], milestones[milestoneIndex].payments[i]);
            source.mintRepTokens(milestones[milestoneIndex].payees[i], milestones[milestoneIndex].payments[i]);
            // _repAmount = _amount * repWeiPerPaymentGwei / (10 ** 9);
            
        }
    }

    /* ========== DISPUTE ========== */

    function dispute(uint256[] memory milestoneIndices) external {
        require(msg.sender == client || msg.sender==sourcingLead );
        for (uint256 j=0; j<milestoneIndices.length; j++){
            milestones[milestoneIndices[j]].inDispute = true;
            
            // emit Disputed(msg.sender, milestoneIndices[j]);
        }
        status = ProjectStatus.inDispute;
        emit Disputed(msg.sender);
        // TODO: emit an event also in case that there are no milestone indices (for the client)

    }
   
    function arbitration(bool forInvoice)public{
        require(msg.sender == arbiter && status==ProjectStatus.inDispute);
        if (forInvoice){
            approvalAmount = outstandingInvoice;
            for (uint256 j=0; j<milestones.length; j++){
                // Maybe could be more cost efficient in future implementation
                if (milestones[j].inDispute){
                    milestones[j].approved = true;
                    milestones[j].inDispute = false;  
                }
            }
            // in current logic the status reverts to active irrespective of whether motion is for or agains invoice
            // status = ProjectStatus.active;
        }
        // client gets entire funds of the project
        _returnFundsToClient(paymentToken.balanceOf(address(this)));

        // what happens to the project?
        status = ProjectStatus.active;  
    }



}
