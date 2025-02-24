// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PixieToken
 * @dev ERC20 Token for Pixie platform content
 */
contract PixieToken is ERC20 {
    address public factory;
    address public creator;
    string public contentURI;
    bool private _initialized;
    
    /**
     * @dev Constructor that initializes token details
     */
    constructor(string memory name, string memory symbol, address _creator, string memory _contentURI) 
        ERC20(name, symbol) 
    {
        factory = msg.sender;
        creator = _creator;
        contentURI = _contentURI;
    }
    
    /**
     * @dev Initial mint function called only by factory
     * @param buyer Address of first buyer
     * @param buyerAmount Amount of tokens for buyer (95% of purchase)
     * @param creatorAmount Amount of tokens for creator (5% royalty)
     */
    function initialMint(
        address buyer, 
        uint256 buyerAmount,
        uint256 creatorAmount
    ) external {
        // Only factory can call this function
        require(msg.sender == factory, "Unauthorized");
        // Can only be initialized once
        require(!_initialized, "Already initialized");
        
        // Mint tokens to the buyer and creator
        _mint(buyer, buyerAmount);
        _mint(creator, creatorAmount);
        
        // Mark as initialized
        _initialized = true;
    }
    
    /**
     * @dev Mint function for subsequent purchases with royalty split
     * @param buyer Address of the buyer
     * @param amount Total amount of tokens to mint
     */
    function mintWithRoyalty(address buyer, uint256 amount) external {
        // Only factory can call this function
        require(msg.sender == factory, "Unauthorized");
        require(_initialized, "Not initialized");
        
        // Calculate royalty (5% to creator)
        uint256 royaltyAmount = amount * 5 / 100;
        uint256 buyerAmount = amount - royaltyAmount;
        
        // Mint tokens to buyer and creator
        _mint(buyer, buyerAmount);
        _mint(creator, royaltyAmount);
    }
} 