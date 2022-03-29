// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



interface IRepToken {
    function mint(address holder, uint256 amount) external;

    function burn(address holder, uint256 amount) external;

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    
    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

        /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    function changeDAO(address newDAO) external;

    function revokeOwnershipWithoutReplacement() external;
}



contract RepToken is ERC20 {
    address public owner;
    address public DAO;
    // add top 7 holders only for the case that transfers are disabled

    // mapping(address=>address) holderBelow;
    // address topHolder;
    
    constructor(string memory name, string memory symbol) ERC20 (name, symbol)  {
        // _mint(msg.sender, initialSupply);
        owner = msg.sender;
    }



    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override pure {
        require(false, "non-transferrable");
        
    }

    function mint(address holder, uint256 amount) external onlyDAO {
        _mint(holder, amount);
        
    } 

    function burn(address holder, uint256 amount) external onlyDAO {
        _burn(holder, amount);
    }

    function changeDAO(address newDAO) external onlyDAOorOwner {
        DAO = newDAO;
    }

    function revokeOwnershipWithoutReplacement() external onlyDAOorOwner {
        owner = address(0x0);
    }

    function getDAO() external view returns(address){
        return DAO;
    }

    modifier onlyDAO() {
        require(msg.sender==DAO, "only DAO");
        _;
    }

    modifier onlyDAOorOwner {
        require(msg.sender==owner || msg.sender==DAO, "only DAO or Owner");
        _;
    }
}



contract HandlesRepToken {
    IRepToken public repToken;
}


contract InitializeRepToken is HandlesRepToken{

    constructor(
        string memory DAO_name,
        string memory DAO_symbol
    ) {
        address _repTokenAddress = address(new RepToken(DAO_name, DAO_symbol));
        repToken = IRepToken(_repTokenAddress);
    }
}