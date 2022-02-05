// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./RepToken.sol";
import "./IRepToken.sol";
import "./Project.sol";
import "./IProject.sol";
import "./Arbitration.sol";
import "./IVoting.sol";

interface IArbitrationEscrow {}


/// @title Main DAO contract
/// @author dOrg
/// @dev Experimental status
/// @custom:experimental This is an experimental contract.
contract Source {  // maybe ERC1820

    /* ========== CONTRACT VARIABLES ========== */

    IVoting public voting;
    RepToken public repToken;
    ArbitrationEscrow public arbitrationEscrow;

    /* ========== LOCAL VARIABLES ========== */

    address[] public projects;
    uint256 public numberOfProjects;
    mapping(address=>bool) _isProject;

    /* ========== EVENTS ========== */

    event ProjectCreated(address _project);

    /* ========== CONSTRUCTOR ========== */

    constructor (address votingContract, string memory name, string memory symbol){
        
        voting = IVoting(votingContract);
        repToken = new RepToken(name, symbol);
        arbitrationEscrow = new ArbitrationEscrow();

    }
    
    
    /* ========== PROJECT HANDLING ========== */

    function createProject(address payable _client, address payable _arbiter, address _paymentTokenAddress, uint8 _votingDuration)
    public
     {
        Project project = new Project(
                                payable(msg.sender),
                                _client,
                                _arbiter,
                                address(repToken),
                                address(arbitrationEscrow),
                                address(voting),
                                _paymentTokenAddress,
                                _votingDuration);
        projects.push(address(project));
        _isProject[address(project)] = true;
        numberOfProjects += 1;
    }


    /* ========== GOVERNANCE ========== */


    function mintRepTokens(address payable payee, uint256 amount) external{
        require(_isProject[msg.sender]);
        repToken.mint(payee, amount);
    }


    /* ========== MIGRATION ========== */

}