// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PixieToken.sol";
import "./BondingCurve.sol";
import "./interfaces/IUniswapInterfaces.sol";

/**
 * @title LazyTokenFactory
 * @dev Factory for lazy deployment of Pixie tokens with bonding curve
 */
contract LazyTokenFactory {
    // Token metadata storage
    struct TokenMetadata {
        string name;
        string symbol;
        address creator;
        string contentURI;
        bool deployed;
    }
    
    // The bonding curve implementation
    BondingCurve public immutable bondingCurve;
    
    // Map content IDs to metadata
    mapping(bytes32 => TokenMetadata) public tokenMetadata;
    // Map Currency to content ID
    mapping(Currency => bytes32) public currencyToContentId;
    
    // Events
    event TokenRegistered(bytes32 indexed contentId, string name, string symbol, address creator);
    event TokenDeployed(bytes32 indexed contentId, address tokenAddress);
    event TokenPurchased(bytes32 indexed contentId, address buyer, uint256 ethAmount, uint256 tokenAmount);
    event TokenSold(bytes32 indexed contentId, address seller, uint256 ethAmount, uint256 tokenAmount);
    
    /**
     * @dev Constructor
     * @param _bondingCurve The bonding curve contract address
     */
    constructor(address _bondingCurve) {
        require(_bondingCurve != address(0), "Zero address");
        bondingCurve = BondingCurve(_bondingCurve);
    }
    
    /**
     * @dev Register a new token without deploying
     * @param contentId Unique identifier for the content
     * @param name Token name
     * @param symbol Token symbol
     * @param creator Creator address
     * @param contentURI Content URI reference
     */
    function registerToken(
        bytes32 contentId, 
        string memory name, 
        string memory symbol, 
        address creator,
        string memory contentURI
    ) external {
        require(tokenMetadata[contentId].creator == address(0), "Already registered");
        require(creator != address(0), "Zero address");
        
        tokenMetadata[contentId] = TokenMetadata({
            name: name,
            symbol: symbol,
            creator: creator,
            contentURI: contentURI,
            deployed: false
        });
        
        // Register the currency with a predetermined address
        Currency currency = Currency.wrap(getTokenAddress(contentId));
        currencyToContentId[currency] = contentId;
        
        emit TokenRegistered(contentId, name, symbol, creator);
    }
    
    /**
     * @dev Calculate deterministic address for a token
     * @param contentId Content identifier
     * @return The predetermined token address
     */
    function getTokenAddress(bytes32 contentId) public view returns (address) {
        TokenMetadata storage metadata = tokenMetadata[contentId];
        require(metadata.creator != address(0), "Token not registered");
        
        // CREATE2 deterministic address calculation
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            contentId,
            keccak256(abi.encodePacked(
                type(PixieToken).creationCode,
                abi.encode(metadata.name, metadata.symbol, metadata.creator, metadata.contentURI)
            ))
        )))));
    }
    
    /**
     * @dev Deploy a token if it doesn't exist
     * @param contentId Content identifier
     * @return The token address
     */
    function deployToken(bytes32 contentId) public returns (address) {
        TokenMetadata storage metadata = tokenMetadata[contentId];
        require(metadata.creator != address(0), "Token not registered");
        
        // If already deployed, just return the address
        if (metadata.deployed) {
            return getTokenAddress(contentId);
        }
        
        // Deploy the token using CREATE2 for deterministic address
        PixieToken token = new PixieToken{salt: contentId}(
            metadata.name,
            metadata.symbol,
            metadata.creator,
            metadata.contentURI
        );
        
        // Initialize with bonding curve
        token.initialize(address(bondingCurve));
        
        // Mark as deployed
        metadata.deployed = true;
        
        emit TokenDeployed(contentId, address(token));
        return address(token);
    }
    
    /**
     * @dev Check if a token is deployed
     * @param contentId Content identifier
     * @return True if token is deployed
     */
    function isTokenDeployed(bytes32 contentId) public view returns (bool) {
        return tokenMetadata[contentId].deployed;
    }
    
    /**
     * @dev Get content ID from Currency
     * @param currency The currency to check
     * @return Content ID
     */
    function getContentId(Currency currency) public view returns (bytes32) {
        return currencyToContentId[currency];
    }
    
    /**
     * @dev Deploy a token and perform initial purchase in one transaction
     * @param contentId Content identifier
     * @param buyer Address of buyer
     * @return The token address
     */
    function deployAndMint(
        bytes32 contentId,
        address buyer
    ) public payable returns (address payable) {
        require(msg.value > 0, "Must send ETH");
        
        // Get or deploy the token
        address payable tokenAddress;
        bool isNewDeployment = !isTokenDeployed(contentId);
        
        if (isNewDeployment) {
            // First time purchase - deploy the token
            tokenAddress = payable(deployToken(contentId));
        } else {
            // Get existing token address
            tokenAddress = payable(getTokenAddress(contentId));
        }
        
        // Buy tokens using the bonding curve
        PixieToken token = PixieToken(tokenAddress);
        uint256 tokenAmount = token.buy{value: msg.value}(buyer);
        
        emit TokenPurchased(contentId, buyer, msg.value, tokenAmount);
        
        return tokenAddress;
    }
    
    /**
     * @dev Sell tokens back to the bonding curve
     * @param contentId Content identifier of the token
     * @param amount Amount of tokens to sell
     * @return ethAmount Amount of ETH received
     */
    function sellTokens(bytes32 contentId, uint256 amount) external returns (uint256) {
        require(amount > 0, "Amount too small");
        
        // Get token address
        address payable tokenAddress = payable(getTokenAddress(contentId));
        require(isTokenDeployed(contentId), "Token not deployed");
        
        // Get the token contract
        PixieToken token = PixieToken(tokenAddress);
        
        // Ensure the sender has approved the factory to spend tokens
        require(token.allowance(msg.sender, address(this)) >= amount, "Not approved");
        
        // Transfer tokens from seller to token contract
        require(token.transferFrom(msg.sender, tokenAddress, amount), "Transfer failed");
        
        // Sell tokens and get ETH
        uint256 ethAmount = token.sell(msg.sender, amount);
        
        emit TokenSold(contentId, msg.sender, ethAmount, amount);
        
        return ethAmount;
    }
    
    /**
     * @dev Get a quote for buying tokens
     * @param contentId Content identifier
     * @param ethAmount Amount of ETH to spend
     * @return tokenAmount Estimated token amount
     */
    function getBuyQuote(bytes32 contentId, uint256 ethAmount) external view returns (uint256) {
        if (!isTokenDeployed(contentId)) {
            // If token is not deployed yet, use initial price calculation
            return ethAmount * 1000; // Simplified example
        }
        
        // Get token and query its bonding curve
        PixieToken token = PixieToken(payable(getTokenAddress(contentId)));
        return token.getBuyQuote(ethAmount);
    }
    
    /**
     * @dev Get a quote for selling tokens
     * @param contentId Content identifier
     * @param tokenAmount Amount of tokens to sell
     * @return ethAmount Estimated ETH amount
     */
    function getSellQuote(bytes32 contentId, uint256 tokenAmount) external view returns (uint256) {
        require(isTokenDeployed(contentId), "Token not deployed");
        
        // Get token and query its bonding curve
        PixieToken token = PixieToken(payable(getTokenAddress(contentId)));
        return token.getSellQuote(tokenAmount);
    }
    
    /**
     * @dev Get current token price
     * @param contentId Content identifier
     * @return price Current token price in ETH (18 decimals)
     */
    function getCurrentPrice(bytes32 contentId) external view returns (uint256) {
        if (!isTokenDeployed(contentId)) {
            // If token is not deployed yet, return initial price
            return bondingCurve.getCurrentPrice(0);
        }
        
        // Get token and query its current price
        PixieToken token = PixieToken(payable(getTokenAddress(contentId)));
        return token.getCurrentPrice();
    }
} 