pragma solidity 0.8.7;
//SPDX-License-Identifier: Unlicense
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract RepToken is ERC20 {
    constructor(uint256 initialSupply) ERC20 ("dORG Reputation", "DRT") public {
        _mint(msg.sender, initialSupply);
    }
}

contract Source {
    mapping(address =>Human) humans;
    mapping(address=>Project) projects;
    event HumanCreated(address _human);
    event ProjectCreated(address _project);

    function createProject(address payable _client, address payable _arbiter, address _paymentTokenAddress, uint256 _votingDuration) {
        project = new Project(msg.sender, _client, _arbiter, postLink, _paymentTokenAddress, _votingDuration);
        project.addDev(new_devs);
    }
    
}


// builders Multisig

contract Project{
    // it should be Multisig Escrow.
    // Three signature: client, builders, arbiter
    Source source;
    RepToken token;
    enum ProjectStatus {proposal, active, inactive, completed}
    ProjectStatus public status;
    uint256 public votes_pro;
    uint256 public votes_against;
    uint256 public numberOfVotes;
    uint256 public quorum;

    uint256 public votingDuration;  // in days

    IERC20 public paymentToken;
    
    string public forumLink;
    
    bool public milestoneApproved =false;
    address payable public client;
    address payable public sourcingLead;
    uint8 public votingDuration;
    address payable public arbiter;
    address payable[] devs;
    bool public urgent;

    uint8 public QUOTA = 50;

    function sendToken(address _to, uint256 _amount) public {
        token.transfer(_to, _amount);
    }
    event MilestoneApproved();
    constructor(address payable _sourcingLead,
                address payable _client,
                address payable _arbiter,
                string memory postLink,
                address payable[] memory parties,
                address _paymentTokenAddress,
                uint8 _votingDuration)  {
        forumLink=postLink;  // 
        status=ProjectStatus.proposal;
        sourcingLead=_sourcingLead;
        client=_client;
        arbiter=_arbiter;
        
        source = Source(msg.sender);
        token=RepToken(tokenAddress);
        startingTime = block.timestamp;
        votingDuration = _votingDuration;
        _changePaymentMethod(_paymentTokenAddress);
    }

    function voteOnProject(bool decision) external returns(bool){
        // if the duration is less than a week, then set flag to 1
        if(block.timestamp - startingTime > votingDuration * 86400 ){
            _registerVote();
            return False;
        }
        uint256 vote=token.balanceOf(msg.sender);
        if (decision){
            votes_pro += vote ;// add safeMath
        } else {
            votes_against += vote;  // add safeMath
        }
        numberOfVotes += 1;
        return True;
    }


    function addDev (address payable _dev) public {
        // add require only majority or sourcing lead and source contract
        require(msg.sender==sourcingLead || msg.sender==source.address);
        devs.push(_dev);
    }

    function _changePaymentMethod(address _tokenAddress) external {
        require(msg.sender == source.address || msg.sender== client);
        paymentToken = IRC20(_tokenAddress);
    }

    function _registerVote()  internal {
        if (votes_for > votes_against) {
            status = ProjectStatus.active;
       
        } else {
            status = ProjectStatus.inactive;
            // in the case that the client had already some funds locked
            _returnFunds();
        }
    }
    
    function dividends()public payable{
        uint256 total = address(this).balance;
        for (uint256 i = 0; i < team.length; i++) {
            team[i].transfer((total * (shares[i] * 100)) / 10000);
        }
    }

    function _returnFunds() internal {
        // return funds to client
        paymentToken.transfer(client, paymentToken.balanceOf(this));
    }


    function approveMilestone() external {
        // client approves milestone, i.e. approve payment to the developer
        require(msg.sender == client);
        milestoneApproved = true;
        uint256 total = paymentToken.balanceOf(this);
        // NOTE; Might be issues with calculating the 10 % percent of the other splits
        tenpercent=((total * 1000) / 10000);
        paymentToken.transfer(source, tenpercent);  
        // Record this event.
        emit MilestoneApproved();

    }

    mapping(address=>uint) earnings ; // of dev
    mapping(address=>uint) paymentRequests;
    bool paymentRequestsApprovedByProject;
    // if milestoneApproved==true and the distribution is not vetoed,
    // earnings[dev] += _amount

    _payout (address payable _human, uint256 _amount) internal {
        
        paymentToken.transfer(_human, _amount);
    }
    
    function sumbitPaymentRequest(uint256 _amount) public {
    //   if milestoneApproved==true)
        // require(msg.sender in dev)
        proposals[msg.sender].amount = _amount;
    }


    struct paymentProposal {
        amount uint256;
        numberOfApprovals uint16
    }


    

    function approveAll(bool _vote) external {
        for (uint i=0; i< devs.length; i++){
            if (msg.sender==devs[i]){
                continue;
            }
            approveOne(devs[i])
        }
    }


    function approveOne(address dev) public {
        // requirements here
        // TODO: only Devs may call this, otherwise a proxy could call it
        require(dev != msg.sender);

        proposals[dev].numberOfApprovals += 1;
        if (proposals[dev].numberOfApproval > (devs.length * QUOTA / 100)) {
            _payout(dev, proposals[dev].amount);
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


