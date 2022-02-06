// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Token/RepToken.sol";
import "../Arbitration/Arbitration.sol";
import "../Voting/IVoting.sol";
import "../Project/IDepartment.sol";
import "../Factory/IClientProjectFactory.sol";
import "../Factory/IInternalProjectFactory.sol";



/// @title Main DAO contract
/// @author dOrg
/// @dev Experimental status
/// @custom:experimental This is an experimental contract.
contract Source {  // maybe ERC1820
    
    enum Motion {setDefaultPaymentToken,
                 removePaymentToken,
                 changePaymentInterval,
                 resetPaymentTimer,
                 liquidateInternalProject}
    
    struct Poll {
        uint256 index;
        uint8 status;
    }

    /* ========== CONTRACT VARIABLES ========== */

    IVoting public voting;
    RepToken public repToken;
    ArbitrationEscrow public arbitrationEscrow;
    IClientProjectFactory public clientProjectFactory;
    IInternalProjectFactory public internalProjectFactory;

    /* ========== LOCAL VARIABLES ========== */
    
    // maps Motion to Poll
    mapping(uint8 => Poll) public currentPoll;

    uint256 public startPaymentTimer;
    // TODO: SET INITIAL PAYMENT TIMER!!!

    address[] public paymentTokens;
    IERC20 public defaultPaymentToken;
    mapping(address => uint256) _paymentTokenIndex;
    address[] public clientProjects;
    address[] public internalProjects;
    uint256 public numberOfProjects;
    mapping(address=>bool) _isProject;

    uint256 public initialVotingDuration = 7 days; // 1 weeks;
    uint256 public paymentInterval;
    uint120 public defaultPermilleThreshold = 500;  // 50 percent
    uint40 public defaultVotingDuration = uint40(10 days);

    /* ========== EVENTS ========== */

    event ProjectCreated(address _project);

    /* ========== CONSTRUCTOR ========== */

    constructor (address votingContract, string memory name, string memory symbol){
        
        voting = IVoting(votingContract);
        repToken = new RepToken(name, symbol);
        arbitrationEscrow = new ArbitrationEscrow();

        // either at construction or after set default paymentToken
        paymentTokens.push(address(0x0));

        // actually set this with DAO vote
        // setDefaultPaymentToken(paymentToken);

        startPaymentTimer = block.timestamp;
    }


    function burnRep() external {
        require(_isProject[msg.sender]);
        repToken.burn(msg.sender, repToken.balanceOf(msg.sender));
    }

    function mintRep(uint256 _amount) external {
        require(_isProject[msg.sender]);
        repToken.mint(msg.sender, _amount);
    }

    function setDeploymentFactories(address _clientProjectFactory, address _internalProjectFactory) external {
        require(false, " requires DAO VOTE. To be implemented");
        clientProjectFactory = IClientProjectFactory(_clientProjectFactory);
        internalProjectFactory = IInternalProjectFactory(_internalProjectFactory);

    }
    
    
    /* ========== PROJECT HANDLING ========== */

    function createClientProject(address payable _client, address payable _arbiter)
    public
     {
        address projectAddress = clientProjectFactory.createClientProject(
            payable(msg.sender), 
            _client,
            _arbiter,
            address(repToken),
            address(arbitrationEscrow),
            address(voting),
            address(defaultPaymentToken),
            initialVotingDuration
        );
        clientProjects.push(projectAddress);
        _isProject[address(projectAddress)] = true;
        numberOfProjects += 1;
    }


    function createInternalProject(uint256 _requestedAmount) 
    external
    {
        address projectAddress = internalProjectFactory.createInternalProject(
                                payable(msg.sender),
                                address(repToken),
                                address(defaultPaymentToken),
                                address(voting),
                                initialVotingDuration,
                                paymentInterval,
                                _requestedAmount);

        internalProjects.push(address(projectAddress));
        _isProject[address(projectAddress)] = true;
        numberOfProjects += 1;
    }



    /* ========== GOVERNANCE ========== */


    function mintRepTokens(address payable payee, uint256 amount) external{
        require(_isProject[msg.sender]);
        repToken.mint(payee, amount);
    }

    // change default payment token.
    // add new payment tokens.
    function removePaymentToken(address _erc20TokenAddress) external {
        // TODO: not everyone should be able to call this.
        paymentTokens[_paymentTokenIndex[_erc20TokenAddress]] = address(0x0);
        _paymentTokenIndex[_erc20TokenAddress] = 0;
    }

    function addPaymentToken(address _erc20TokenAddress) external requiredRep() {
        require(_paymentTokenIndex[_erc20TokenAddress] == 0, "already exists");
        paymentTokens.push(_erc20TokenAddress);
        _paymentTokenIndex[_erc20TokenAddress] = paymentTokens.length - 1;
    }

    
    function setDefaultPaymentToken(address _erc20TokenAddress)
    public 
    isEligibleToken(_erc20TokenAddress)
    voteOnMotion(0, _erc20TokenAddress) {
        // DAO Vote: The MotionId is 0
        address newPaymentTokenAddress = voting.getElected(currentPoll[0].index);
        defaultPaymentToken = IERC20(newPaymentTokenAddress);
    }

    function transfer(uint256 _amount) external onlyProject() {
        defaultPaymentToken.transfer(msg.sender, _amount);
    }

    function liquidateInternalProject(address _project)
    external 
    voteOnMotion(4, _project){
        // DAO Vote: The MotionId is 4
        IInternalProject(_project).withdraw();
    }

    function changePaymentInterval(uint160 duration)
    external
    voteOnMotion(2, address(duration)){        
        // DAO Vote: The MotionId is 2
        address unconvertedDuration = voting.getElected(currentPoll[0].index);
        paymentInterval = uint256(uint160(unconvertedDuration));
    }

    function resetPaymentTimer() 
    external 
    voteOnMotion(3, address(0x0)){        
        // DAO Vote: The MotionId is 3
        startPaymentTimer = block.timestamp;
        // drawback that timer restarts when the majority is reached.
        // which is a little bit unpredictable.
        // But it will start before the end of defaultVotingDuration
    }

    function getStartPaymentTimer() view external returns(uint256) {
        return startPaymentTimer;
    }
    


    // make sure no funds are locked in the departments!
    // TODO!!! Change default at each project.
    


    
    function payout() external {
        require(block.timestamp - startPaymentTimer > paymentInterval);
        //TODO: Maybe just those internal projects that are still active
        for (uint256 i = 0; i<internalProjects.length; i++){
            // set amounts to zero again.
            IInternalProject(internalProjects[i]).pay();
        }
        // TODO!! Start this in constructor
        startPaymentTimer = block.timestamp;

        // maybe refund the caller with DAO cash
        _refundGas();

        // Maybe earn some DORG.
        
    }

    function _refundGas() internal {
        // require(False)
        // TODO: DOUBLE CHECK THIS REFUND
        if (false){

            uint256 roughGasAmountEstimate = 1000000;
            payable(msg.sender).transfer(roughGasAmountEstimate * tx.gasprice);
        }
    }

    modifier requiredRep() {
        require(repToken.balanceOf(msg.sender)>0);
        _;
    }

    modifier onlyProject() {
        require(_isProject[msg.sender]);
        _;
    }

    modifier isEligibleToken(address _tokenAddres){
        require(_paymentTokenIndex[_tokenAddres]>0);
        _;
    }

    modifier voteOnMotion(uint8 _motion, address _address) {
        // Motion motion = Motion.setDefaultPaymentToken;
        // Motion is 0
        require(currentPoll[_motion].status <= 1, "inactive or active");
        if (currentPoll[_motion].status == 0){
            // TODO!! If one changes the enum in Voting to include other statuses then
            // one should maybe not use the exclusion here.
            currentPoll[_motion].index = voting.start(4, defaultVotingDuration, defaultPermilleThreshold, uint120(repToken.totalSupply()));
            currentPoll[_motion].status = 1;
        }

        currentPoll[0].status = voting.safeVoteReturnStatus(
            currentPoll[0].index,
            msg.sender,
            _address,
            uint128(repToken.balanceOf(msg.sender)));

        if (currentPoll[0].status == 2){
            _;
            // reset status to inactive, so that polls can take place again.
            currentPoll[0].status == 0;
        }
        if (currentPoll[0].status == 3){
            // reset status to inactive, so that polls can take place again.
            currentPoll[0].status == 0;
        }
    }

    /* ========== MIGRATION ========== */

}