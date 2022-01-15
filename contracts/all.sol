pragma solidity ^0.8.7;
//SPDX-License-Identifier: Unlicense
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RepToken is ERC20 {
    constructor(uint256 initialSupply) ERC20 ("dORG Reputation", "DRT")  {
        _mint(msg.sender, initialSupply);
    }

    // TODO! MUST BE REMOVED
    function FREEMINTING(uint256 amount) external {
        _mint(msg.sender, amount);
    }
    
}

contract Source {
    // mapping(address =>Human) humans;
    address[] public projects;
    uint256 public numberOfProjects;
    event HumanCreated(address _human);
    event ProjectCreated(address _project);
    RepToken public repToken;
    uint256 INITIAL_SUPPLY=9*10**16;
    constructor (){
        repToken=new RepToken(INITIAL_SUPPLY);
    }
    
    //add function to retrieve all projects

    function createProject(address payable _client, address payable _arbiter, address _paymentTokenAddress, uint8 _votingDuration)
    public
     {
        projects.push(
            address(new Project(
                            payable(msg.sender),
                            _client,
                            _arbiter, 
                            address(repToken),
                            _paymentTokenAddress,
                            _votingDuration)
                    ));
        numberOfProjects += 1;
    }
    
}


// builders Multisig

contract Project{
    // it should be Multisig Escrow.
    // Three signature: client, builders, arbiter
    Source public source;
    RepToken public repToken;
    enum ProjectStatus {proposal, active, milestoneInDispute, inactive, completed}
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
    uint256 public repWeiPerPaymentGwei = 10**9;  // 10**9 for stablecoin
    // You earn one WETH, then how many reptokens you get?
    // (10**18) * (repToPaymentRatio) / (10 ** 9)
    // where the repToPaymentRatio = 3000 * 10 ** 9

    struct paymentProposal {
        uint256 amount ;  // TODO: diminish the size here from uint256 to something smaller
        uint16 numberOfApprovals;         
    }

    // enum paymentApprovalStatus {requested, approved, denied}
    
    mapping(address=>paymentProposal) public payments;
    
    mapping(address=>bool) _isTeamMember;

    event MilestoneApproved();
    constructor(address payable _sourcingLead,
                address payable _client,
                address payable _arbiter,
                address repTokenAddress,
                address _paymentTokenAddress,
                uint8 _votingDuration)  {
         
        status=ProjectStatus.proposal;
        sourcingLead=_sourcingLead;
        team.push(sourcingLead);
        client=_client;
        arbiter=_arbiter;
        source = Source(msg.sender);
        repToken=RepToken(repTokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        // use default ratio between Rep and Payment
        _changePaymentMethod(_paymentTokenAddress, repWeiPerPaymentGwei);
        
    }

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
            status = ProjectStatus.active;
       
        } else {
            status = ProjectStatus.inactive;
            // in the case that the client had already some funds locked
            _returnFundsToClient(paymentToken.balanceOf(address(this)));
        }
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


    function approveMilestone(uint256 _approvalAmount) external {
        require(msg.sender == client && outstandingInvoice > 0);
        approvalAmount = _approvalAmount;  // 
        if (_approvalAmount>=outstandingInvoice && _approvalAmount<=paymentToken.balanceOf(address(this))){
            _releaseMilestoneFunds();
        }else{
            status = ProjectStatus.milestoneInDispute;
        }
        
    }


    function dispute() public {
        require(msg.sender == client || msg.sender==sourcingLead );
        status = ProjectStatus.milestoneInDispute;
    }
   
    function artbitration(bool inFavourOfInvoice)public{
        require(msg.sender == arbiter && status==ProjectStatus.milestoneInDispute);
        if (inFavourOfInvoice){
           approvalAmount = outstandingInvoice;
            }
        status = ProjectStatus.active;
        _releaseMilestoneFunds();
    }


    function _releaseMilestoneFunds() internal {
        // client approves milestone, i.e. approve payment to the developer
        
        
        milestoneApproved = true;

        uint256 totalAmount = paymentToken.balanceOf(address(this));
        uint256 clientAmount = totalAmount - approvalAmount;  //safeMath!!

        // NOTE; Might be issues with calculating the 10 % percent of the other splits
        uint256 tenpercent=((approvalAmount * 1000) / 10000);
        paymentToken.transfer(address(source), tenpercent);  
        // send back the rest to client
        if (clientAmount>0){
            _returnFundsToClient(clientAmount);
            // important to set th outstandingInvoice back!!
            outstandingInvoice = 0;
        }

        // Record this event.
        emit MilestoneApproved();
    }

   function _payout (address payable _human, uint256 _amount) internal {
        require(milestoneApproved);
        paymentToken.transfer(_human, _amount);
        // send repTokens
        uint256 _repAmount = _amount * repWeiPerPaymentGwei / (10 ** 9);
        repToken.transfer(_human, _repAmount);
        if (paymentToken.balanceOf(address(this))==0){
            // NOTE: HOw to make sure that this is not a minimal amount left
            _startNewMilestone();
        }
    }

    function _startNewMilestone() internal {
        // reset milestone approval flag
        milestoneApproved = false;
        // reset balances of all team
        for (uint i=0; i<team.length; i++){
            payments[team[i]].amount = 0;
        }
    }


    
    function sumbitPaymentRequest(uint256 _amount) public {
    //   if milestoneApproved==true)
        // require(msg.sender in dev)
        // APPROVEALL MUST HAPPEN AFTER PAYMENT REQUEST.
        payments[msg.sender].amount = _amount;
    }
    // withdraw funds to treasury if voted by everyone.


    function approveAll() external {
        for (uint i=0; i< team.length; i++){
            if (msg.sender==team[i]){
                continue;
            }
            approveOne(team[i]);
        }
    }

    function approveOne(address payable teamMember) public {
        // requirements here
        // TODO: only team may call this, otherwise a proxy could call it
        require(_isTeamMember[msg.sender]);

        payments[teamMember].numberOfApprovals += 1;
        if (payments[teamMember].numberOfApprovals > team.length * PAYMENT_APPROVAL_QUOTA / 100) {
            _payout(teamMember, payments[teamMember].amount);
        }
    }

    // to milestoneApproved= false

   

}


