// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IUniswapInterfaces.sol";
import "forge-std/console.sol";

/**
 * @title MockPoolManager
 * @dev A simplified mock of Uniswap v4's PoolManager for testing
 */
contract MockPoolManager is IPoolManager {
    // Mapping from poolId to pool state
    mapping(bytes32 => PoolState) public pools;
    
    // Pool state for tracking pools
    struct PoolState {
        bool initialized;
        address hook;
        int24 tick;
        uint160 sqrtPriceX96;
    }
    
    // Event for tracking calls
    event SwapCalled(address sender, PoolKey key, SwapParams params);
    event ModifyLiquidityCalled(address sender, PoolKey key, ModifyLiquidityParams params);
    
    /**
     * @dev Allow the contract to receive ETH
     */
    receive() external payable {}
    
    /**
     * @dev Calculate the pool ID from the pool key
     * @param key Pool key
     * @return Pool ID
     */
    function _poolIdFromKey(PoolKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key));
    }
    
    /**
     * @dev Initialize a pool
     * @param key Pool key
     * @param sqrtPriceX96 Initial price
     * @return tick The current tick after initialization
     */
    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24 tick) {
        bytes32 poolId = _poolIdFromKey(key);
        
        // Ensure this pool hasn't been initialized already
        require(!pools[poolId].initialized, "MockPoolManager: Already initialized");
        
        // For mock purposes, we just set a fixed tick
        tick = 0;
        
        // Store the hook address and initialized state
        pools[poolId] = PoolState({
            initialized: true,
            hook: key.hooks,
            tick: tick,
            sqrtPriceX96: sqrtPriceX96
        });
        
        console.log("MockPoolManager: Initialized pool");
        console.log("  Hook address:", key.hooks);
        
        return tick;
    }
    
    /**
     * @dev Swap tokens
     * @param key Pool key
     * @param params Swap parameters
     * @param hookData Additional data for hooks
     * @return delta Balance delta
     */
    function swap(
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external payable returns (BalanceDelta memory) {
        return swap(key, params, hookData, msg.sender);
    }
    
    /**
     * @dev Execute a swap operation with a specific sender
     * @param key Pool key
     * @param params Swap parameters
     * @param hookData Additional data for hooks
     * @param sender The sender of the swap
     * @return delta Balance delta
     */
    function swap(
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData,
        address sender
    ) public payable returns (BalanceDelta memory) {
        bytes32 poolId = _poolIdFromKey(key);
        
        // Ensure the pool is initialized
        require(pools[poolId].initialized, "MockPoolManager: Not initialized");
        
        PoolState storage pool = pools[poolId];
        
        // Mock balance delta - in a real system this would be calculated
        BalanceDelta memory delta;
        
        // Call hooks if they exist
        if (pool.hook != address(0)) {
            bytes1 opType = bytes1(hookData[0]);
            
            console.log("MockPoolManager: Executing swap");
            console.log("  Operation type:", uint8(opType));
            console.log("  Amount specified:", uint256(params.amountSpecified));
            console.log("  Zero for one:", params.zeroForOne);
            console.log("  Value:", msg.value);
            
            if (params.zeroForOne) {
                // Buying tokens - extract ETH value
                uint256 amount = uint256(params.amountSpecified);
                
                // Call the beforeSwap hook
                IHooks(pool.hook).beforeSwap{value: msg.value}(msg.sender, key, params, hookData);
                
                // Since this is a mock, we don't need to calculate real deltas
                delta = BalanceDelta(int256(msg.value), -int256(amount));
            } else {
                // Selling tokens - hookData should contain the sell details
                uint256 tokenAmount = uint256(params.amountSpecified);
                
                // Call the beforeSwap hook (no ETH for sell)
                IHooks(pool.hook).beforeSwap(msg.sender, key, params, hookData);
                
                // The hook will handle the actual ETH transfer to the seller
                // For mock purposes, we'll just set a mock delta
                // The ETH amount would depend on the bonding curve calculation
                delta = BalanceDelta(-int256(tokenAmount), int256(tokenAmount));
            }
            
            // Call the afterSwap hook
            IHooks(pool.hook).afterSwap(msg.sender, key, params, delta, hookData);
        } else {
            // For a pool without hooks, we just return a mock delta
            delta = BalanceDelta(int256(params.amountSpecified), -int256(params.amountSpecified));
        }
        
        emit SwapCalled(sender, key, params);
        return delta;
    }
    
    /**
     * @dev Modify liquidity in pool
     * @param key Pool key
     * @param params Liquidity parameters
     * @param hookData Additional data for hooks
     * @return delta Balance delta after modification
     */
    function modifyLiquidity(
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (BalanceDelta memory delta) {
        bytes32 poolId = _poolIdFromKey(key);
        
        // Ensure the pool is initialized
        require(pools[poolId].initialized, "MockPoolManager: Not initialized");
        
        PoolState storage pool = pools[poolId];
        
        // Mock balance delta
        delta = BalanceDelta(0, 0);
        
        // Return the delta
        return delta;
    }
    
    /**
     * @dev Unlock the manager for operations
     * @param data Operations data
     * @return Result of callbacks
     */
    function unlock(bytes calldata data) external returns (bytes memory) {
        console.log("MockPoolManager: Unlock called with data length", data.length);
        
        // The callback might revert, so we need to handle that gracefully
        IUnlockCallback callback = IUnlockCallback(msg.sender);
        
        (bool success, bytes memory returnData) = address(callback).call(
            abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, data)
        );
        
        if (success) {
            return returnData;
        } else {
            console.log("MockPoolManager: Unlock callback failed");
            // Return a default value rather than reverting
            return abi.encode(BalanceDelta(0, 0));
        }
    }
} 