// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Token/RepToken.sol";
import "../Arbitration/Arbitration.sol";
import "../Voting/IVoting.sol";
import "../Project/IDepartment.sol";
import "../Factory/IClientProjectFactory.sol";
import "../Factory/IInternalProjectFactory.sol";
import "../Factory/IdOrgFactory.sol";

import {Poll, PollStatus} from "../Voting/Poll.sol";
import {DAOMembership} from "./Membership.sol";
import {DAOPaymentTokens, DAOPaymentCycle} from "../Payment/DAOPayments.sol";
import {GasRefunds} from "../Payment/GasRefunds.sol";

/// @title Main DAO contract
/// @author dOrg
/// @dev Experimental status
/// @custom:experimental This is an experimental contract.
contract Source is Poll, GasRefunds, HandlesRepToken, DAOMembership, DAOPaymentCycle, DAOPaymentTokens {  // maybe ERC1820
    
    bool public deprecated;
    
    enum MotionType {setDefaultPaymentToken,
                 removePaymentToken,
                 changePaymentInterval,
                 resetPaymentTimer,
                 liquidateInternalProject,
                 migrateDORG,
                 migrateRepToken,
                 changeInitialVotingDuration}
                 
    

    /* ========== CONTRACT VARIABLES ========== */

    IVoting public voting;
    IRepToken public oldRepToken;
    ArbitrationEscrow public arbitrationEscrow;
    IClientProjectFactory public clientProjectFactory;
    IInternalProjectFactory public internalProjectFactory;
    IdOrgFactory public dOrgFactory;

    /* ========== LOCAL VARIABLES ========== */
    
    // maps Motion to Poll
    // mapping(uint8 => Poll) public currentPoll;

    uint256 public startPaymentTimer;
    address internal deployer;
    // TODO: SET INITIAL PAYMENT TIMER!!!

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
    // event Refunded(address recipient, uint256 amount, bool successful);
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
    onlyRegisteredToken(paymentToken)
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

    // function liquidateInternalProject(address _project)
    // external 
    // voteOnMotion(4, _project){
    //     // DAO Vote: The MotionId is 4
    //     IInternalProject(_project).withdraw();
    // }

    // function changePaymentInterval(uint160 duration)
    // external
    // voteOnMotion(2, address(duration)){        
    //     // DAO Vote: The MotionId is 2
    //     address unconvertedDuration = voting.getElected(currentPoll[2].index);
    //     paymentInterval = uint256(uint160(unconvertedDuration));
    // }

    

    // function resetPaymentTimer() 
    // external 
    // voteOnMotion(3, address(0x0)){        
    //     // DAO Vote: The MotionId is 3
    //     startPaymentTimer = block.timestamp;
    //     // drawback that timer restarts when the majority is reached.
    //     // which is a little bit unpredictable.
    //     // But it will start before the end of defaultVotingDuration
    // }



    // make sure no funds are locked in the departments!
    // TODO!!! Change default at each project.
    // function getPollStatus(uint256 pollIndex) external view
    // returns(uint8, uint40, uint256, uint256, address)
    // {
    //     return voting.retrieve(pollIndex);
    // }

    function getThisCyclesTotalRequested() view public returns(uint256 totalRequested) {
        for (uint256 i=0; i < internalProjects.length; i++){
            totalRequested += IInternalProject(internalProjects[i]).getThisCyclesRequestedAmount();
        }
    }

    function payout()
    external 
    refundGas()
    maySubmitPayment()
    {
        // NOTE: Think about swapping into the defaultPaymentToken.
        uint256 totalRequested = getThisCyclesTotalRequested();
        uint256 defaultTokenConversionRate = getConversionRate(address(defaultPaymentToken));
        uint256 balanceOfDAOInStableCoinEquivalent = (defaultPaymentToken.balanceOf(address(this)) * defaultTokenConversionRate) / 1e18;
        uint256 share = 1e18;
        
        if (totalRequested > balanceOfDAOInStableCoinEquivalent){
            share = (balanceOfDAOInStableCoinEquivalent * 1e18) / totalRequested;
        }

        // calculate how much there is in the treasury as opposed to what is requested
        for (uint256 i=0; i < internalProjects.length; i++){
            //get requeste amounts per Token
            uint256 requestedAmount = IInternalProject(internalProjects[i]).getThisCyclesRequestedAmount();
            uint256 sentAmount = (requestedAmount * share) / 1e18;
            uint256 deptAmount = (requestedAmount * (1e18 - share)) / 1e18;
            if (deptAmount>0){
                // deptToken.mint(deptAmount);
                // deptToken.increaseAllowance(internalProjects[i], deptAmount);
            }
            defaultPaymentToken.increaseAllowance(internalProjects[i], (sentAmount * 1e18) / defaultTokenConversionRate);
            IInternalProject(internalProjects[i]).payout(share);
        }

        _resetPaymentTimer(block.timestamp);

        // emit Payment();
        
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


    // modifier voteOnMotion(uint8 _motion, address _address) {
    //     // Motion motion = Motion.setDefaultPaymentToken;
    //     // Motion is 0
    //     require(voting.getStatus(currentPoll[_motion].index) <= uint8(1), "inactive or active");
    //     if (voting.getStatus(currentPoll[_motion].index) == uint8(0)){
    //         // TODO!! If one changes the enum in Voting to include other statuses then
    //         // one should maybe not use the exclusion here.
    //         // currentPoll[_motion].index = voting.start(uint8(4), uint40(defaultVotingDuration), uint120(defaultPermilleThreshold), uint120(repToken.totalSupply()));
    //     }

    //     _;

    //     // voting.safeVoteReturnStatus(
    //     //     currentPoll[0].index,
    //     //     msg.sender,
    //     //     _address,
    //     //     uint128(repToken.balanceOf(msg.sender)));

    //     // if (voting.getStatus(currentPoll[_motion].index) == 2){
    //     //     _;
    //     //     // reset status to inactive, so that polls can take place again.
    //     // }
    // }

    /* ========== MIGRATION ========== */

    // function migrateDORG()
    // external 
    // voteOnMotion(5, address(0x0)){ 
    //     // TODO! MUST BE a lot higher CONDITONS and THRESHOLD!!!
    //     dOrgFactory.createDORG(address(voting), address(repToken), true);
    //     deprecated = true;  // cant start new projects
    //     _refundGas();
    // }

    // function migrateRepToken(address _newRepToken)
    // external
    // voteOnMotion(6, address(_newRepToken)){ 
    //     // TODO! MUST BE a lot higher CONDITONS and THRESHOLD!!!
    //     // TODO: Check whethe I need to call this via RepToken(address(repToken))
    //     oldRepToken = repToken;
    //     repToken = IRepToken(voting.getElected(currentPoll[6].index));
    //     _refundGas();
    // }


    // function claimOldRep() external {
    //     uint256 oldBalance = oldRepToken.balanceOf(msg.sender);
    //     require(oldBalance>0);
    //     // transfer and burn
    //     repToken.mint(msg.sender, oldBalance);
    //     oldRepToken.burn(msg.sender, oldBalance);
    // }

}