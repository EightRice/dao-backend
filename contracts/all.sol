pragma solidity ^0.8.7;
//SPDX-License-Identifier: Unlicense
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract RepToken is ERC20 {
    address public source;
    
    constructor(string memory name, string memory symbol) ERC20 (name, symbol)  {
        // _mint(msg.sender, initialSupply);
        source = msg.sender;
    }


    // TODO! MUST BE REMOVED
    function FREEMINTING(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function mint(address holder, uint256 amount) external {
        require(msg.sender==source);
        _mint(holder, amount);
    } 
}


// interface ISource {

// }

// contract dOrgFactory {
//     function create_dOrg(string memory name, string memory symbol) external {
//         Source source = new Source(name, symbol);
//         // source
//     }
// }

contract ArbitrationEscrow {
    mapping(address=>uint256) arbrationFee;  // project address => fee
}

contract Source {  // maybe ERC1820
    // mapping(address =>Human) humans;
    address[] public projects;
    uint256 public numberOfProjects;
    event HumanCreated(address _human);
    event ProjectCreated(address _project);
    RepToken public repToken;
    ArbitrationEscrow public arbitrationEscrow;
    uint256 INITIAL_SUPPLY=0; // 9*10**16;
    constructor (string memory name, string memory symbol){

        repToken = new RepToken(name, symbol);
        arbitrationEscrow = new ArbitrationEscrow();

    }
    
    //add function to retrieve all projects

    function createProject(address payable _client, address payable _arbiter, address _paymentTokenAddress, uint8 _votingDuration)
    public
     {
        Project project = new Project(
                                payable(msg.sender),
                                _client,
                                _arbiter,
                                address(repToken),
                                arbitrationEscrow,
                                _paymentTokenAddress,
                                _votingDuration);
        projects.push(address(project));
        _isProject[address(project)] = true;
        numberOfProjects += 1;
    }

    mapping(address=>bool) public _isProject;

    function mintRepTokens(address payable payee, uint256 amount) external{
        require(_isProject[msg.sender]);
        repToken.mint(payee, amount);
    }

    // function _migrate(address payable newSource) public {
    //     uint256 threshold = 80;  // TODO: CHekc whether this works on remix
    //     // if (migrationVote[newSource] > (repToken.totalSupply * threshold) / 100){
            
    //     }
    // // }

    // mapping (address=>uint256) public migrationVote;

    
    // function approveMigration(address newSource) external {
    //     migrationVote[newSource] += repToken.balanceOf(msg.sender);
    // }
    
}




// builders Multisig

contract Project{
    // it should be Multisig Escrow.
    // Three signature: client, builders, arbiter
    Source public source;
    RepToken public repToken;
    ArbitrationEscrow public arbitrationEscrow;
    enum ProjectStatus {proposal, active, inDispute, inactive, completed, rejected}
    ProjectStatus public status;
    uint256 public votes_pro;
    uint256 public votes_against;
    uint256 public numberOfVotes;
    uint256 public quorum;



    IERC20 public paymentToken;
    string public forumLink;
    bool public milestoneApproved =false;
    address payable public client;
    address payable public sourcingLead;
    uint8 public votingDuration; // in seconds (1 day = 86400)
    address payable public arbiter;
    address payable[] team;
    uint256 public startingTime;
    uint256 public approvalAmount;
    bool milestoneDisputed=false;
    uint256 public outstandingInvoice=0;
    uint8 public PAYMENT_APPROVAL_QUOTA = 50;
    // can be called by an oracle or querying an exchange.
    uint256 public repWeiPerPaymentGwei = 10**9;  // 10**9; for stablecoin

    uint256 public vetoDurationForPayments = 4 * 86400 ;// in seconds
    // You earn one WETH, then how many reptokens you get?
    // (10**18) * (repToPaymentRatio) / (10 ** 9)
    // where the repToPaymentRatio = 3000 * 10 ** 9

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

    Milestone[] public milestones;  // holds all the milestones of the project

    mapping(address=>paymentProposal) public payments;
    mapping(address=>bool) _isTeamMember;
    mapping(address=>mapping(address=>bool)) public excludeMember;
    mapping(address=>uint16) public voteToExclude;
    mapping (address=>mapping(address=>uint256)) public votesForNewSourcingLead;
    mapping (address=>mapping(address=>bool)) public alreadyVotedForNewSourcingLead;
    uint256 public defaultThreshold = 50;  // in percent
    uint256 public exclusionThreshold = 50;  // in percent  
    // TODO: Discuss in dOrg
    // Maybe include Appeal

    event MilestoneApproved(uint256 milestoneIndex, uint256 approvedAmount);
    event RequestedAmountAddedToMilestone(uint256 milestoneIndex, uint256 requetedAmount);
    event PayrollRosterSubmitted(uint256 milestoneIndex);
    event Disputed(address disputer);

    constructor(address payable _sourcingLead,
                address payable _client,
                address payable _arbiter,
                address repTokenAddress,
                ArbitrationEscrow _arbitrationEscrow,
                address _paymentTokenAddress,
                uint8 _votingDuration){
         
        status=ProjectStatus.proposal;
        sourcingLead=_sourcingLead;
        team.push(sourcingLead);
        _isTeamMember[sourcingLead] = true;
        client=_client;
        arbitrationEscrow=_arbitrationEscrow;
        arbiter=_arbiter;
        source = Source(msg.sender);
        repToken=RepToken(repTokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        // use default ratio between Rep and Payment
        _changePaymentMethod(_paymentTokenAddress, repWeiPerPaymentGwei);
        
    }

    /*
    VOTING ON THE PROJECT
    */

    function voteOnProject(bool decision) external returns(bool){
        // if the duration is less than a week, then set flag to 1
        if(block.timestamp - startingTime > votingDuration ){ 
            _registerVote();
            return false;
        }
        uint256 vote=repToken.balanceOf(msg.sender);
        if (decision){
            votes_pro += vote ;// add safeMath
        } else {
            votes_against += vote;  // add safeMath
        }
        numberOfVotes += 1;
        return true;
    }

    function setRepWeiValuePerGweiTokenValue(uint256 _repWeiPerPaymentGwei)public {
        require(msg.sender == address(source) || msg.sender==sourcingLead);
        repWeiPerPaymentGwei = _repWeiPerPaymentGwei;
    }

    function sendRepToken(address _to, uint256 _amount) public {
        repToken.transfer(_to, _amount);
    }

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
    
    function replaceSourcingLead(address _nominee) external {
        require(_nominee!=sourcingLead);  // Maybe allow also sourcingLead to 
        require(!alreadyVotedForNewSourcingLead[msg.sender][_nominee]);
        votesForNewSourcingLead[msg.sender][_nominee] += 1;
        alreadyVotedForNewSourcingLead[msg.sender][_nominee] = true;
    }

    function claimSourcingLead() external {
        uint256 totalVotes = 0;
        for (uint256 i=0; i<team.length; i++){
            totalVotes += votesForNewSourcingLead[team[i]][msg.sender];
        }
        if (totalVotes > (team.length * defaultThreshold ) / 100) {
            sourcingLead = payable(msg.sender);
            // reset all the votes
            for (uint256 i; i<team.length; i++){
                votesForNewSourcingLead[team[i]][msg.sender] = 0;
                alreadyVotedForNewSourcingLead[team[i]][msg.sender] = false;
            }
        }
    }
        


    /*
    MILESTONE HANDLING
    */

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

    
    function startProject() external {
        // is there enough money in escrow and project deposited by client?
        
    }



    // function allowFunds(_amount) {
    //     paymentToken.approve(msg.sender, _amount);
    // }

    // function sendArbitrationFunds() {
    //     paymentToken.transfer(msg.sender, _amount);
    // }


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


    function submitPayrollRoster(uint256 milestoneIndex, address[] memory payees, uint256[] memory amounts ) external {
        require(msg.sender==sourcingLead && payees.length == amounts.length);
        milestones[milestoneIndex].payrollVetoDeadline = block.timestamp + vetoDurationForPayments;
        
        emit PayrollRosterSubmitted(milestoneIndex);  // maybe milestones[milestoneIndex].payrollVetoDeadline
    }

    // add function if its vetoed
    function vetoPayrollRoster(uint256 milestoneIndex) public{
        require(_isTeamMember[msg.sender]);
        uint256 [] memory NoPayments;
        milestones[milestoneIndex].payments = NoPayments;  // TODO: think about storage 
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
        // // send repTokens
        // uint256 _repAmount = _amount * repWeiPerPaymentGwei / (10 ** 9);
        // repToken.transfer(_human, _repAmount);
        // if (paymentToken.balanceOf(address(this))==0){
        //     // NOTE: HOw to make sure that this is not a minimal amount left
        //     _startNewMilestone();
        // }
    }



}



