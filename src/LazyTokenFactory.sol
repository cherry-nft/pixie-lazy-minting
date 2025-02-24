// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PixieToken.sol";
import "./interfaces/IUniswapInterfaces.sol";

/**
 * @title LazyTokenFactory
 * @dev Factory for lazy deployment of Pixie tokens
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
    
    // Map content IDs to metadata
    mapping(bytes32 => TokenMetadata) public tokenMetadata;
    // Map Currency to content ID
    mapping(Currency => bytes32) public currencyToContentId;
    
    // Events
    event TokenRegistered(bytes32 indexed contentId, string name, string symbol, address creator);
    event TokenDeployed(bytes32 indexed contentId, address tokenAddress);
    
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
     * @dev Deploy a token and perform initial minting in one transaction
     * @param contentId Content identifier
     * @param buyer Address of first buyer
     * @param buyAmount Amount of tokens for buyer
     * @param poolAddress Address of the liquidity pool
     * @param poolAmount Amount of tokens for liquidity pool
     * @return The token address
     */
    function deployAndMint(
        bytes32 contentId,
        address buyer,
        uint256 buyAmount,
        address poolAddress,
        uint256 poolAmount
    ) public returns (address) {
        // First, deploy the token if not already deployed
        address tokenAddress = deployToken(contentId);
        
        // Then perform initial minting (factory is authorized to call this)
        PixieToken(tokenAddress).initialMint(buyer, buyAmount, poolAddress, poolAmount);
        
        return tokenAddress;
    }
} 