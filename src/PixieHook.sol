// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IUniswapInterfaces.sol";
import "./LazyTokenFactory.sol";
import "./PixieToken.sol";
import "forge-std/console.sol";

/**
 * @title PixieHook
 * @dev Hook for lazy deployment of Pixie tokens during first swap
 */
contract PixieHook is IHooks {
    // Constants
    uint256 public constant MIN_LIQUIDITY_AMOUNT = 1000 * 10**18; // 1000 tokens for initial liquidity
    
    // The token factory
    LazyTokenFactory public immutable factory;
    // The pool manager
    IPoolManager public immutable poolManager;
    
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
     * @dev Constructor
     * @param _factory Factory contract address
     * @param _poolManager Pool manager address
     */
    constructor(address _factory, address _poolManager) {
        factory = LazyTokenFactory(_factory);
        poolManager = IPoolManager(_poolManager);
    }
    
    /**
     * @dev Hook called before swap to check and deploy token if needed
     */
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override payable returns (bytes4, BeforeSwapDelta memory) {
        // Debug logging to identify the sender
        console.log("PixieHook beforeSwap - sender:", sender);
        console.log("PixieHook beforeSwap - msg.sender:", msg.sender);
        console.log("PixieHook beforeSwap - ETH value:", msg.value);
        
        // For simplicity, we assume currency1 is always the token we might need to deploy
        // In a production setting, you would check both currencies and determine which one
        // might need deployment based on the swap direction
        
        // Check if we have a lazy token to deploy
        bytes32 contentId = factory.getContentId(key.currency1);
        if (contentId != bytes32(0)) {
            // Extract ETH amount from params (for testing purposes)
            // In a real implementation, you'd extract from the swap data appropriately
            uint256 ethAmount = uint256(params.amountSpecified > 0 ? params.amountSpecified : -params.amountSpecified);
            
            // For testing purposes, use a hardcoded amount if none provided
            if (ethAmount == 0) {
                ethAmount = 0.1 ether;
            }
            
            console.log("ETH amount for purchase:", ethAmount);
            
            // Get actual buyer
            address buyer = sender;
            
            // If needed for testing, can use a fixed buyer address
            if (hookData.length > 0 && hookData.length == 32) {
                // Try to extract buyer from hookData (simple approach)
                buyer = address(bytes20(hookData[12:32]));
                console.log("Using buyer from hookData:", buyer);
            }
            
            // Deploy the token and mint tokens based on ETH value
            // Note: In production, this would handle real ETH flow
            // For testing we're just simulating the ETH transaction
            try factory.deployAndMint{value: ethAmount}(
                contentId,
                buyer
            ) returns (address tokenAddress) {
                console.log("Token deployed/purchased at:", tokenAddress);
            } catch Error(string memory reason) {
                console.log("Purchase failed:", reason);
            }
        }
        
        // Return the actual interface selector
        return (IHooks.beforeSwap.selector, BeforeSwapDelta(0, 0, 0));
    }
    
    /**
     * @dev Hook called after swap (required by interface)
     */
    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta calldata,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta memory) {
        // No changes to the balance delta
        return (IHooks.afterSwap.selector, BalanceDelta(0, 0));
    }
    
    // The following functions are placeholders to satisfy the IHooks interface
    // In a real implementation, you would implement all required hooks
    
    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        return BEFORE_INITIALIZE_SELECTOR;
    }
    
    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        return AFTER_INITIALIZE_SELECTOR;
    }
    
    // Allow the contract to receive ETH
    receive() external payable {}
} 