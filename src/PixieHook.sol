// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IUniswapInterfaces.sol";
import "./interfaces/IPixieHook.sol";
import "./LazyTokenFactory.sol";
import "./PixieToken.sol";
import "forge-std/console.sol";

/**
 * @title PixieHook
 * @notice Uniswap v4 hook for Pixie tokens with bonding curve support
 */
contract PixieHook is IHooks, IPixieHook {
    // Constants
    uint256 public constant MIN_LIQUIDITY_AMOUNT = 1000 * 10**18; // 1000 tokens for initial liquidity
    
    // Factory address
    LazyTokenFactory public immutable factory;
    
    // Pool manager address
    address public immutable poolManager;
    
    // Content ID for lazy deployment
    bytes32 public contentId;
    
    // Mock selector constants for interface compliance
    bytes4 private constant BEFORE_INITIALIZE_SELECTOR = bytes4(keccak256("beforeInitialize(address,PoolKey,uint160)"));
    bytes4 private constant AFTER_INITIALIZE_SELECTOR = bytes4(keccak256("afterInitialize(address,PoolKey,uint160,int24)"));
    bytes4 private constant BEFORE_ADD_LIQUIDITY_SELECTOR = bytes4(keccak256("beforeAddLiquidity(address,PoolKey,IPoolManager.ModifyLiquidityParams,bytes)"));
    bytes4 private constant AFTER_ADD_LIQUIDITY_SELECTOR = bytes4(keccak256("afterAddLiquidity(address,PoolKey,IPoolManager.ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)"));
    bytes4 private constant BEFORE_REMOVE_LIQUIDITY_SELECTOR = bytes4(keccak256("beforeRemoveLiquidity(address,PoolKey,IPoolManager.ModifyLiquidityParams,bytes)"));
    bytes4 private constant AFTER_REMOVE_LIQUIDITY_SELECTOR = bytes4(keccak256("afterRemoveLiquidity(address,PoolKey,IPoolManager.ModifyLiquidityParams,BalanceDelta,BalanceDelta,bytes)"));
    bytes4 private constant BEFORE_SWAP_SELECTOR = bytes4(keccak256("beforeSwap(address,PoolKey,IPoolManager.SwapParams,bytes)"));
    bytes4 private constant AFTER_SWAP_SELECTOR = bytes4(keccak256("afterSwap(address,PoolKey,IPoolManager.SwapParams,BalanceDelta,bytes)"));
    bytes4 private constant BEFORE_DONATE_SELECTOR = bytes4(keccak256("beforeDonate(address,PoolKey,uint256,uint256,bytes)"));
    bytes4 private constant AFTER_DONATE_SELECTOR = bytes4(keccak256("afterDonate(address,PoolKey,uint256,uint256,bytes)"));
    
    /**
     * @notice Constructor
     * @param _factory Factory address
     * @param _poolManager Pool manager address
     */
    constructor(address _factory, address _poolManager) {
        factory = LazyTokenFactory(_factory);
        poolManager = _poolManager;
    }
    
    /**
     * @notice Handle before swap
     * @param key Pool key
     * @param params Swap parameters
     * @param data Hook data
     */
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) external payable override returns (bytes4, BeforeSwapDelta memory) {
        require(msg.sender == poolManager, "PixieHook: Only pool manager");
        
        // Get operation type and recipient from data
        bytes1 opType = bytes1(data[0]);
        address recipient = address(bytes20(data[1:21]));
        
        console.log("PixieHook: Before swap");
        console.log("  Operation type:", uint8(opType));
        console.log("  Recipient:", recipient);
        console.log("  Value:", msg.value);
        
        // Get token address from currency
        address tokenAddress = Currency.unwrap(key.currency1);
        
        // Determine operation type (0x00 = buy, 0x01 = sell)
        if (opType == 0x00) {
            // Buy operation - requires ETH
            require(msg.value > 0, "PixieHook: Buy requires ETH");
            require(params.zeroForOne, "PixieHook: Buy must be zeroForOne");
            
            // Find content ID for the token
            bytes32 tokenContentId;
            // Try to get contentId from the currency mapping
            tokenContentId = factory.getContentId(key.currency1);
            
            // If not found, use the contentId from storage (for testing)
            if (bytes32(0) == tokenContentId) {
                tokenContentId = contentId;
            }
            
            // Deploy token if needed and mint tokens to recipient
            factory.deployAndMint{value: msg.value}(tokenContentId, recipient);
            
        } else if (opType == 0x01) {
            // Sell operation
            require(!params.zeroForOne, "PixieHook: Sell must be oneForZero");
            require(params.amountSpecified > 0, "PixieHook: Sell amount must be positive");
            
            // Find content ID for the token
            bytes32 tokenContentId = factory.getContentId(key.currency0);
            
            // If not found, use the contentId from storage (for testing)
            if (bytes32(0) == tokenContentId) {
                tokenContentId = contentId;
            }
            
            // Approve and sell tokens
            // Note: Recipient must have approved the hook to spend their tokens
            uint256 sellAmount = uint256(params.amountSpecified);
            
            // Get the recipient to approve the factory
            bool success = IERC20(tokenAddress).transferFrom(
                recipient,
                address(this),
                sellAmount
            );
            require(success, "PixieHook: Transfer from sender failed");
            
            // Approve factory to spend tokens
            IERC20(tokenAddress).approve(address(factory), sellAmount);
            
            // Sell tokens and get ETH back
            uint256 ethReceived = factory.sellTokens(tokenContentId, sellAmount);
            
            // Send ETH back to recipient
            (success, ) = recipient.call{value: ethReceived}("");
            require(success, "PixieHook: ETH transfer failed");
        } else {
            revert("PixieHook: Invalid operation type");
        }
        
        return (IHooks.beforeSwap.selector, BeforeSwapDelta(0, 0, 0));
    }
    
    /**
     * @notice Handle after swap
     * @param key Pool key
     * @param params Swap parameters
     * @param delta Balance delta
     * @param data Hook data
     */
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta calldata delta,
        bytes calldata data
    ) external override returns (bytes4, BalanceDelta memory) {
        require(msg.sender == poolManager, "PixieHook: Only pool manager");
        
        // Get operation type from data
        bytes1 opType = bytes1(data[0]);
        
        // Log swap completion
        console.log("PixieHook: After swap");
        console.log("  Operation type:", uint8(opType));
        
        return (IHooks.afterSwap.selector, BalanceDelta(0, 0));
    }
    
    /**
     * @notice Set content ID (for testing)
     * @param _contentId Content ID
     */
    function setContentId(bytes32 _contentId) external override {
        contentId = _contentId;
    }
    
    // Allow the contract to receive ETH
    receive() external payable {}
} 