// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Token/IRepToken.sol";
import "../Token/RepToken.sol";
import "../Arbitration/Arbitration.sol";
import "../Voting/IVoting.sol";
import "../Project/IDepartment.sol";
import "../Factory/IClientProjectFactory.sol";
import "../Factory/IInternalProjectFactory.sol";
import "../Factory/IdOrgFactory.sol";


/// @title Main DAO contract
/// @author dOrg
/// @dev Experimental status
/// @custom:experimental This is an experimental contract.
contract Source {  // maybe ERC1820
    
    bool public deprecated;
    
    enum MotionType {setDefaultPaymentToken,
                 removePaymentToken,
                 changePaymentInterval,
                 resetPaymentTimer,
                 liquidateInternalProject,
                 migrateDORG,
                 migrateRepToken,
                 changeInitialVotingDuration}
                 
    struct Poll {
        MotionType motionType;
        uint256 index;
        address internalProjectAddress;
    }

    /* ========== CONTRACT VARIABLES ========== */

    IVoting public voting;
    IRepToken public repToken;
    IRepToken public oldRepToken;
    ArbitrationEscrow public arbitrationEscrow;
    IClientProjectFactory public clientProjectFactory;
    IInternalProjectFactory public internalProjectFactory;
    IdOrgFactory public dOrgFactory;

    /* ========== LOCAL VARIABLES ========== */
    
    // maps Motion to Poll
    mapping(uint8 => Poll) public currentPoll;

    uint256 public startPaymentTimer;
    address internal deployer;
    // TODO: SET INITIAL PAYMENT TIMER!!!

    address[] public paymentTokens;
    IERC20 public defaultPaymentToken;
    mapping(address => uint256) public _paymentTokenIndex;
    address[] public clientProjects;
    address[] public internalProjects;
    uint256 public numberOfDepartments;
    uint256 public numberOfProjects;
    mapping(address=>bool) _isProject;

    uint256 public initialVotingDuration = 300; //  change to 300 s for demo; // 1 weeks;
    uint256 public paymentInterval;
    uint120 public defaultPermilleThreshold = 500;  // 50 percent
    uint256 public payoutRep = 100 * (10 ** 18);
    uint40 public defaultVotingDuration = uint40(50);

    /* ========== EVENTS ========== */

    event ProjectCreated(address _project);
    event Refunded(address recipient, uint256 amount, bool successful);
    event Payment(uint256 amount, uint256 repAmount);

    /* ========== CONSTRUCTOR ========== */
    constructor (address votingContract){
        
        repToken = IRepToken(address(new RepToken("DORG", "DORG")));
        voting = IVoting(votingContract);
        // _importMembers(initialMembers, initialRep);
        arbitrationEscrow = new ArbitrationEscrow();

        // // either at construction or after set default paymentToken
        paymentTokens.push(address(0x0));


        startPaymentTimer = block.timestamp;
        deployer = msg.sender;
    }

    function importMembers(address[] memory initialMembers,uint256[] memory initialRep)
    external
    {
        require(msg.sender==deployer, "Only after Deployment");
        _importMembers(initialMembers, initialRep);
    }

    function _importMembers(address[] memory initialMembers,uint256[] memory initialRep) internal{
        // only once!
        require(initialMembers.length==initialRep.length);
        for (uint256 i=0; i< initialMembers.length; i++){
            repToken.mint(initialMembers[i], initialRep[i]);
        }
    }

    function setDeploymentFactories(address _clientProjectFactory, address _internalProjectFactory) external {
        // require(false, " requires DAO VOTE. To be implemented");
        clientProjectFactory = IClientProjectFactory(_clientProjectFactory);
        internalProjectFactory = IInternalProjectFactory(_internalProjectFactory);
    }
    
    
    /* ========== PROJECT HANDLING ========== */


    function createClientProject(address payable _client, address payable _arbiter, address paymentToken)
    public
    isEligibleToken(paymentToken)
     {
        require(!deprecated);
        address projectAddress = clientProjectFactory.createClientProject(
            payable(msg.sender), 
            _client,
            _arbiter,
            address(repToken),
            address(arbitrationEscrow),
            address(voting),
            paymentToken,
            initialVotingDuration
        );
        clientProjects.push(projectAddress);
        _isProject[address(projectAddress)] = true;
        numberOfProjects += 1;
    }


    function createInternalProject(uint256[] memory _requestedAmounts, address[] memory _requestedTokenAddresses) 
    external
    {
        require(!deprecated);
        address projectAddress = internalProjectFactory.createInternalProject(
                                payable(msg.sender),
                                address(voting),
                                initialVotingDuration,
                                paymentInterval,
                                _requestedAmounts,
                                _requestedTokenAddresses);

        internalProjects.push(address(projectAddress));
        _isProject[address(projectAddress)] = true;
        numberOfDepartments += 1;
    }



    /* ========== GOVERNANCE ========== */


    function mintRepTokens(address payee, uint256 amount) external{
        require(_isProject[msg.sender]);
        _mintRepTokens(payee, amount);
    }

    function _mintRepTokens(address receiver, uint256 amount) internal {
        repToken.mint(receiver, amount);
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

    
    // TODO: Current attack vector with voting is that anyone can trigger a vote anytime
    // and by current design there is only one vote per Motion at any time. So one could 
    // congest the voting service (i.e. denial of service attack).
    // Solution could be to add the index for the particular vote.
    // TODO: Also currently options are encoded by different addresses
    function setDefaultPaymentToken(address _erc20TokenAddress)
    public 
    isEligibleToken(_erc20TokenAddress)
    {
        // DAO Vote: The MotionId is 0
        // address newPaymentTokenAddress = voting.getElected(currentPoll[0].index);
        defaultPaymentToken = IERC20(_erc20TokenAddress);
    }

    function withdrawByProject(uint256 _amount) external onlyProject() {
        // TODO: A bit risky like this. 
        // Or course there is currently no way to trigger this function
        // other than if the payment amount is approved by DAO, but
        // we should make this manifestly secure against malicious changes to the contract.
        defaultPaymentToken.transfer(msg.sender, _amount);
    }

    function transferToken(address _erc20address, address _recipient, uint256 _amount) 
    external 
    onlyProject(){
        //DAO Vote on transfer Token to address
        // isEligibleToken(_erc20address)
        
        IERC20(_erc20address).transfer(_recipient, _amount);
        
    }

    function changeInitialVotingDuration(uint256 _votingDuration)
    external
    onlyTwice {  // FIXME Need to change the modifier!! Or rather adapt the new voting interaction.
        initialVotingDuration = _votingDuration;
        // DAO Vote: The MotionId is 4
        // address unconvertedDuration = voting.getElected(currentPoll[7].index);
        // initialVotingDuration = uint256(uint160(unconvertedDuration));
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
        address unconvertedDuration = voting.getElected(currentPoll[2].index);
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
    function getPollStatus(uint256 pollIndex) external view
    returns(uint8, uint40, uint256, uint256, address)
    {
        return voting.retrieve(pollIndex);
    }


    
    function payout()
    external 
    refundGas()
    {
        
        require(block.timestamp - startPaymentTimer > paymentInterval);
        //TODO: Maybe just those internal projects that are still active
        uint256 totalAmount = 0;
        uint256 totalRep = 0;
        for (uint256 i = 0; i<internalProjects.length; i++){
            // set amounts to zero again.
            (uint256 amount, uint256 repAmount) = IInternalProject(internalProjects[i]).pay();
            totalAmount += amount;
            totalRep += repAmount;
        }
        // TODO!! Start this in constructor
        startPaymentTimer = block.timestamp;

        emit Payment(totalAmount, totalRep);
        // Maybe earn some DORG.
        // TODO: Maybe discuss with feedback
        // _mintRepTokens(msg.sender, payoutRep);

        
    }

    modifier refundGas() {
        uint256 _gasbefore = gasleft();
        _;
        // TODO: How can I not care about the return value something? I think the notaiton  is _, right?
        uint256 refundAmount = (_gasbefore - gasleft()) * tx.gasprice;
        (bool sent, bytes memory something) = payable(msg.sender).call{value: refundAmount}("");
        emit Refunded(msg.sender, refundAmount, sent);
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
        require(repToken.balanceOf(msg.sender)>0, "Caller has no Rep");
        _;
    }

    modifier onlyProject() {
        require(_isProject[msg.sender]);
        _;
    }

    uint8 internal onlyTwoCallsFlag = 0;
    modifier onlyTwice() {
        require(onlyTwoCallsFlag < 2);
        _;
        onlyTwoCallsFlag += 1;
    }

    modifier isEligibleToken(address _tokenAddres){
        require(_paymentTokenIndex[_tokenAddres]>0);
        _;
    }

    modifier voteOnMotion(uint8 _motion, address _address) {
        // Motion motion = Motion.setDefaultPaymentToken;
        // Motion is 0
        require(voting.getStatus(currentPoll[_motion].index) <= uint8(1), "inactive or active");
        if (voting.getStatus(currentPoll[_motion].index) == uint8(0)){
            // TODO!! If one changes the enum in Voting to include other statuses then
            // one should maybe not use the exclusion here.
            // currentPoll[_motion].index = voting.start(uint8(4), uint40(defaultVotingDuration), uint120(defaultPermilleThreshold), uint120(repToken.totalSupply()));
        }

        _;

        // voting.safeVoteReturnStatus(
        //     currentPoll[0].index,
        //     msg.sender,
        //     _address,
        //     uint128(repToken.balanceOf(msg.sender)));

        // if (voting.getStatus(currentPoll[_motion].index) == 2){
        //     _;
        //     // reset status to inactive, so that polls can take place again.
        // }
    }

    /* ========== MIGRATION ========== */

    function migrateDORG()
    external 
    voteOnMotion(5, address(0x0)){ 
        // TODO! MUST BE a lot higher CONDITONS and THRESHOLD!!!
        dOrgFactory.createDORG(address(voting), address(repToken), true);
        deprecated = true;  // cant start new projects
        _refundGas();
    }

    function migrateRepToken(address _newRepToken)
    external
    voteOnMotion(6, address(_newRepToken)){ 
        // TODO! MUST BE a lot higher CONDITONS and THRESHOLD!!!
        // TODO: Check whethe I need to call this via RepToken(address(repToken))
        oldRepToken = repToken;
        repToken = IRepToken(voting.getElected(currentPoll[6].index));
        _refundGas();
    }


    function claimOldRep() external {
        uint256 oldBalance = oldRepToken.balanceOf(msg.sender);
        require(oldBalance>0);
        // transfer and burn
        repToken.mint(msg.sender, oldBalance);
        oldRepToken.burn(msg.sender, oldBalance);
    }

}