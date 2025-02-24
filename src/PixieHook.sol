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
     * @param hookData Hook data
     */
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external payable override returns (bytes4, BeforeSwapDelta memory) {
        require(msg.sender == poolManager, "PixieHook: Only pool manager");
        
        console.log("PixieHook: beforeSwap entry point");
        console.log("  Sender:", sender);
        console.log("  Msg.value:", msg.value);
        console.log("  HookData length:", hookData.length);
        
        // First byte of hookData indicates operation type (buy/sell)
        bytes1 opType = bytes1(hookData[0]);
        
        // Extract buyer/seller address from hookData (skip the first byte which is the operation type)
        address payable recipient;
        if (hookData.length > 1) {
            // Extract recipient from the rest of the hookData (after the operation type)
            bytes memory recipientData = new bytes(hookData.length - 1);
            for (uint i = 0; i < hookData.length - 1; i++) {
                recipientData[i] = hookData[i + 1];
            }
            // Decode the address from the extracted data
            (address extractedAddress) = abi.decode(recipientData, (address));
            recipient = payable(extractedAddress);
        } else {
            // Default to sender if no address is provided
            recipient = payable(sender);
        }
        
        console.log("PixieHook: beforeSwap parsed data");
        console.log("  Operation type:", uint8(opType));
        console.log("  Recipient:", recipient);
        console.log("  Value:", msg.value);
        
        // Handle operation based on type
        if (opType == 0x00) {
            console.log("PixieHook: Executing buy operation");
            // Buy operation
            handleBuyOperation(key, params, recipient);
        } else if (opType == 0x01) {
            console.log("PixieHook: Executing sell operation");
            // Sell operation
            handleSellOperation(key, params, recipient);
        } else {
            console.log("PixieHook: Unknown operation type");
            revert("PixieHook: Unknown operation type");
        }
        
        console.log("PixieHook: Operation completed successfully");
        return (IHooks.beforeSwap.selector, BeforeSwapDelta(0, 0, 0));
    }
    
    /**
     * @notice Handle after swap
     * @param key Pool key
     * @param params Swap parameters
     * @param delta Balance delta
     * @param hookData Hook data
     */
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta calldata delta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta memory) {
        require(msg.sender == poolManager, "PixieHook: Only pool manager");
        
        // Get operation type from data
        bytes1 opType = bytes1(hookData[0]);
        
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
    
    /**
     * @dev Handle buy operation
     * @param key Pool key
     * @param params Swap parameters
     * @param recipient Recipient address
     */
    function handleBuyOperation(
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        address payable recipient
    ) internal {
        // Buy operation - requires ETH
        require(msg.value > 0, "PixieHook: Buy requires ETH");
        require(params.zeroForOne, "PixieHook: Buy must be zeroForOne");
        
        console.log("PixieHook: Processing buy with ETH value:", msg.value);
        
        // Get token address from currency
        address tokenAddress = Currency.unwrap(key.currency1);
        console.log("PixieHook: Token address from currency:", tokenAddress);
        
        // Find content ID for the token
        bytes32 tokenContentId;
        // Try to get contentId from the currency mapping
        tokenContentId = factory.getContentId(key.currency1);
        
        // If not found, use the contentId from storage (for testing)
        if (bytes32(0) == tokenContentId) {
            tokenContentId = contentId;
        }
        
        console.log("PixieHook: Content ID:", uint256(tokenContentId));
        
        // Deploy token if needed and mint tokens to recipient
        factory.deployAndMint{value: msg.value}(tokenContentId, recipient);
        
        console.log("PixieHook: Buy operation completed successfully");
    }
    
    /**
     * @dev Handle sell operation
     * @param key Pool key
     * @param params Swap parameters
     * @param recipient Recipient address
     */
    function handleSellOperation(
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        address payable recipient
    ) internal {
        // Sell operation
        require(!params.zeroForOne, "PixieHook: Sell must be oneForZero");
        require(params.amountSpecified > 0, "PixieHook: Sell amount must be positive");
        
        console.log("PixieHook: Processing sell with amount:", uint256(params.amountSpecified));
        
        // Get token address from currency
        address tokenAddress = Currency.unwrap(key.currency1);
        console.log("PixieHook: Token address from currency:", tokenAddress);
        
        // Find content ID for the token
        bytes32 tokenContentId = factory.getContentId(key.currency1);
        
        // If not found, use the contentId from storage (for testing)
        if (bytes32(0) == tokenContentId) {
            tokenContentId = contentId;
        }
        
        console.log("PixieHook: Content ID:", uint256(tokenContentId));
        
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
        
        console.log("PixieHook: ETH received from sell:", ethReceived);
        
        // Send ETH back to recipient
        (success, ) = recipient.call{value: ethReceived}("");
        require(success, "PixieHook: ETH transfer failed");
        
        console.log("PixieHook: Sell operation completed successfully");
    }
    
    // Allow the contract to receive ETH
    receive() external payable {}
} 