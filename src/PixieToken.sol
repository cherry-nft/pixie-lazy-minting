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
    
    // Constant for total supply
    uint256 public constant TOTAL_SUPPLY = 1_000_000 * 10**18; // 1 million tokens with 18 decimals
    
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
     * @param buyAmount Amount of tokens for buyer
     * @param poolAddress Address of the liquidity pool
     * @param poolAmount Amount of tokens for liquidity pool
     */
    function initialMint(
        address buyer, 
        uint256 buyAmount, 
        address poolAddress,
        uint256 poolAmount
    ) external {
        // Only factory can call this function
        require(msg.sender == factory, "Unauthorized");
        // Can only be initialized once
        require(!_initialized, "Already initialized");
        
        // Calculate creator amount (remaining tokens)
        uint256 creatorAmount = TOTAL_SUPPLY - buyAmount - poolAmount;
        
        // Mint tokens to the buyer, creator, and pool
        _mint(buyer, buyAmount);
        _mint(creator, creatorAmount);
        _mint(poolAddress, poolAmount);
        
        // Mark as initialized
        _initialized = true;
    }
} 