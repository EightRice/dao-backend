pragma solidity 0.8.7;
//SPDX-License-Identifier: Unlicense
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RepToken is ERC20 {
    constructor(uint256 initialSupply) ERC20 ("dORG Reputation", "DRT")  {
        _mint(msg.sender, initialSupply);
    }
}

contract Source {
    // mapping(address =>Human) humans;
    mapping(address=>Project) projects;
    event HumanCreated(address _human);
    event ProjectCreated(address _project);
    RepToken repToken;
    uint256 INITIAL_SUPPLY=9*10**16;
    constructor (){
        repToken=new RepToken(INITIAL_SUPPLY);
    }


    function createProject(address payable _client, address payable _arbiter, address _paymentTokenAddress, uint8 _votingDuration)
    public
     {
               

        Project project = new Project(
        payable(msg.sender),
         _client,
        _arbiter, 
        address(repToken),
        _paymentTokenAddress,
        _votingDuration);
        
    }
    
}


// builders Multisig

contract Project{
    // it should be Multisig Escrow.
    // Three signature: client, builders, arbiter
    Source public source;
    RepToken public repToken;
    enum ProjectStatus {proposal, active, inactive, completed}
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
    uint8 public votingDuration; // in days
    address payable public arbiter;
    address payable[] devs;
    bool public urgent;
    uint256 public startingTime;
    uint8 public QUOTA = 50;

    function sendToken(address _to, uint256 _amount) public {
        repToken.transfer(_to, _amount);
    }
    event MilestoneApproved();
    constructor(address payable _sourcingLead,
                address payable _client,
                address payable _arbiter,
                address repTokenAddress,
                address _paymentTokenAddress,
                uint8 _votingDuration)  {
         
        status=ProjectStatus.proposal;
        sourcingLead=_sourcingLead;
        client=_client;
        arbiter=_arbiter;
        source = Source(msg.sender);
        repToken=RepToken(repTokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        _changePaymentMethod(_paymentTokenAddress);
    }

    function voteOnProject(bool decision) external returns(bool){
        // if the duration is less than a week, then set flag to 1
        if(block.timestamp - startingTime > votingDuration * 86400 ){
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


    function addDev (address payable _dev) public {
        // add require only majority or sourcing lead and source contract
        require(msg.sender==sourcingLead || msg.sender==address(source));
        devs.push(_dev);
    }

    function _changePaymentMethod(address _tokenAddress) public {
        require(msg.sender == address(source) || msg.sender== sourcingLead);
        paymentToken = IERC20(_tokenAddress);
    }

    function _registerVote()  internal {
        if (votes_pro > votes_against) {
            status = ProjectStatus.active;
       
        } else {
            status = ProjectStatus.inactive;
            // in the case that the client had already some funds locked
            _returnFunds();
        }
    }
    
    

    function _returnFunds() internal {
        // return funds to client
        paymentToken.transfer(client, paymentToken.balanceOf(address(this)));
    }


    function approveMilestone() external {
        // client approves milestone, i.e. approve payment to the developer
        require(msg.sender == client);
        milestoneApproved = true;
        uint256 total = paymentToken.balanceOf(address(this));
        // NOTE; Might be issues with calculating the 10 % percent of the other splits
        uint256 tenpercent=((total * 1000) / 10000);
        paymentToken.transfer(address(source), tenpercent);  
        // Record this event.
        emit MilestoneApproved();

    }

    mapping(address=>uint) earnings ; // of dev
    mapping(address=>uint) paymentRequests;
    bool paymentRequestsApprovedByProject;
    // if milestoneApproved==true and the distribution is not vetoed,
    // earnings[dev] += _amount

   function _payout (address payable _human, uint256 _amount) internal {
        
        paymentToken.transfer(_human, _amount);
    }
    
    function sumbitPaymentRequest(uint256 _amount) public {
    //   if milestoneApproved==true)
        // require(msg.sender in dev)
        payments[msg.sender].amount = _amount;
    }


    struct paymentProposal {
        uint256 amount ;
        uint16 numberOfApprovals;
    }


    

    function approveAll(bool _vote) external {
        for (uint i=0; i< devs.length; i++){
            if (msg.sender==devs[i]){
                continue;
            }
            approveOne(devs[i]);
        }
    }
    mapping(address=>paymentProposal) payments;

    function approveOne(address payable dev) public {
        // requirements here
        // TODO: only Devs may call this, otherwise a proxy could call it
        require(dev != msg.sender);

        payments[dev].numberOfApprovals += 1;
        if (payments[dev].numberOfApprovals > (devs.length * QUOTA / 100)) {
            _payout(dev, payments[dev].amount);
        }
        // check whether quota is reached.
        
        // paymentProposal.Approvals += 1;
        // paymentRequestsApprovedByProject = true;
        // for (uint i=0; i< devs.length; i++){
        //     earnings[devs[i]] += paymentRequests[devs[i]];
        //     // payout()
        // }
        
        // paymentRequestsApprovedByProject = false;
    }

    // to milestoneApproved= false

   

}


