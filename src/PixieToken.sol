// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BondingCurve.sol";

/**
 * @title PixieToken
 * @dev ERC20 Token for Pixie platform content with bonding curve mechanism
 */
contract PixieToken is ERC20, ReentrancyGuard {
    // Constants
    uint256 public constant ROYALTY_BPS = 500; // 5% royalty to creator
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000e18; // 1B tokens
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MIN_ORDER_SIZE = 0.0000001 ether;
    
    // Core token data
    address public factory;
    address public creator;
    string public contentURI;
    bool private _initialized;
    BondingCurve public bondingCurve;
    
    // Events
    event TokenBought(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event TokenSold(address indexed seller, uint256 ethAmount, uint256 tokenAmount);
    
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
     * @dev Initialize the token with bonding curve
     * @param _bondingCurve The bonding curve contract address
     */
    function initialize(address _bondingCurve) external {
        require(msg.sender == factory, "Unauthorized");
        require(!_initialized, "Already initialized");
        require(_bondingCurve != address(0), "Zero address");
        
        bondingCurve = BondingCurve(_bondingCurve);
        _initialized = true;
    }
    
    /**
     * @dev Buy tokens with ETH
     * @param buyer Address of the buyer
     */
    function buy(address buyer) external payable nonReentrant returns (uint256) {
        require(msg.sender == factory, "Unauthorized");
        require(_initialized, "Not initialized");
        require(msg.value >= MIN_ORDER_SIZE, "Order too small");
        require(buyer != address(0), "Zero address");
        
        // Calculate the royalty and net investment amount
        uint256 royaltyAmount = (msg.value * ROYALTY_BPS) / FEE_DENOMINATOR;
        uint256 netInvestment = msg.value - royaltyAmount;
        
        // Calculate tokens to mint based on bonding curve
        uint256 tokenAmount = bondingCurve.getEthBuyQuote(totalSupply(), netInvestment);
        
        // Split tokens between buyer and creator
        uint256 creatorTokens = (tokenAmount * ROYALTY_BPS) / FEE_DENOMINATOR;
        uint256 buyerTokens = tokenAmount - creatorTokens;
        
        // Mint the tokens
        _mint(buyer, buyerTokens);
        _mint(creator, creatorTokens);
        
        // Send royalty to creator
        (bool success, ) = creator.call{value: royaltyAmount}("");
        require(success, "ETH transfer failed");
        
        emit TokenBought(buyer, msg.value, tokenAmount);
        
        return tokenAmount;
    }
    
    /**
     * @dev Sell tokens for ETH
     * @param seller Address of the seller
     * @param tokenAmount Amount of tokens to sell
     */
    function sell(address seller, uint256 tokenAmount) external nonReentrant returns (uint256) {
        require(msg.sender == factory, "Unauthorized");
        require(_initialized, "Not initialized");
        require(tokenAmount > 0, "Amount too small");
        require(balanceOf(seller) >= tokenAmount, "Insufficient balance");
        
        // Calculate ETH to return based on bonding curve
        uint256 ethAmount = bondingCurve.getTokenSellQuote(totalSupply(), tokenAmount);
        require(ethAmount >= MIN_ORDER_SIZE, "ETH amount too small");
        require(address(this).balance >= ethAmount, "Insufficient ETH reserves");
        
        // Burn the tokens
        _burn(seller, tokenAmount);
        
        // Send ETH to seller (no fees on selling to ensure liquidity)
        (bool success, ) = seller.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        
        emit TokenSold(seller, ethAmount, tokenAmount);
        
        return ethAmount;
    }
    
    /**
     * @dev Get the current token price based on supply
     */
    function getCurrentPrice() public view returns (uint256) {
        return bondingCurve.getCurrentPrice(totalSupply());
    }
    
    /**
     * @dev Get quote for buying tokens with ETH
     * @param ethAmount Amount of ETH to spend
     */
    function getBuyQuote(uint256 ethAmount) public view returns (uint256) {
        // Calculate royalty
        uint256 royaltyAmount = (ethAmount * ROYALTY_BPS) / FEE_DENOMINATOR;
        uint256 netInvestment = ethAmount - royaltyAmount;
        
        // Get token amount from bonding curve
        return bondingCurve.getEthBuyQuote(totalSupply(), netInvestment);
    }
    
    /**
     * @dev Get quote for selling tokens
     * @param tokenAmount Amount of tokens to sell
     */
    function getSellQuote(uint256 tokenAmount) public view returns (uint256) {
        return bondingCurve.getTokenSellQuote(totalSupply(), tokenAmount);
    }
    
    /**
     * @dev Allow contract to receive ETH
     */
    receive() external payable {}
} 