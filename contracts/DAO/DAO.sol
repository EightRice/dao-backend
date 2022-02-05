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

    /* ========== CONTRACT VARIABLES ========== */

    IVoting public voting;
    RepToken public repToken;
    ArbitrationEscrow public arbitrationEscrow;
    IClientProjectFactory public clientProjectFactory;
    IInternalProjectFactory public internalProjectFactory;

    /* ========== LOCAL VARIABLES ========== */

    address[] public paymentTokens;
    IERC20 public defaultPaymentToken;
    mapping(address => uint256) _paymentTokenIndex;
    address[] public clientProjects;
    address[] public internalProjects;
    uint256 public numberOfProjects;
    mapping(address=>bool) _isProject;

    uint256 public votingDuration = 4 days ; // 1 weeks;
    uint256 public paymentInterval;

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
            votingDuration
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
                                votingDuration,
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

    function addPaymentToken(address _erc20TokenAddress) external {
        require(_paymentTokenIndex[_erc20TokenAddress]==0, "doesnt exist yet");
        paymentTokens.push(_erc20TokenAddress);
        _paymentTokenIndex[_erc20TokenAddress] = paymentTokens.length - 1;
    }

    function setDefaultPaymentToken(address _erc20TokenAddress) public {
        // TODO: ONLY REQUIRE DAO VOTE
        require(false);

        defaultPaymentToken = IERC20(_erc20TokenAddress);
        if (_paymentTokenIndex[_erc20TokenAddress]>0){
            paymentTokens.push(_erc20TokenAddress);
        }

        // make sure no funds are locked in the departments!
        // TODO!!! Change default at each project.
    }




    function transfer(uint256 _amount) external {
        require(_isProject[msg.sender]);
        defaultPaymentToken.transfer(msg.sender, _amount);
    }

    function liquidateInternalProject(address _project) external {
        IInternalProject(_project).withdraw();
    }

    function changePaymentInterval() external {
        // maybe later //DAO vote
    }


    // function veto(){

    // }

    


    uint256 public startPaymentTimer;
    // TODO: SET INITIAL PAYMENT TIMER!!!

    function setStartPaymentTimer() external {
        // DAO LEVEL
    }

    function getStartPaymentTimer() view external returns(uint256) {
        return startPaymentTimer;
    }
    
    
    function payout() external {
        require(block.timestamp - startPaymentTimer > paymentInterval);
        //TODO: Maybe just those internal projects that are still active
        for (uint256 i = 0; i<internalProjects.length; i++){
            // set amounts to zero again.
            IInternalProject(internalProjects[i]).pay();
        }
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

    /* ========== MIGRATION ========== */

}