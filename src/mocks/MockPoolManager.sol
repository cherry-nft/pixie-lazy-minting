// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUniswapInterfaces.sol";

/**
 * @title MockPoolManager
 * @dev A simplified mock of Uniswap v4's PoolManager for testing
 */
contract MockPoolManager is IPoolManager {
    // Track registered pools
    mapping(PoolId => bool) public pools;
    
    // Simplified pool state
    struct PoolState {
        uint160 sqrtPriceX96;
        int24 tick;
        bool initialized;
    }
    
    mapping(PoolId => PoolState) public poolState;
    
    // Event for tracking calls
    event SwapCalled(address sender, PoolKey key, SwapParams params);
    event ModifyLiquidityCalled(address sender, PoolKey key, ModifyLiquidityParams params);
    
    /**
     * @dev Convert pool key to pool ID
     * @param key Pool key
     * @return Pool ID
     */
    function toId(PoolKey memory key) public pure returns (PoolId) {
        return PoolId.wrap(keccak256(abi.encode(key)));
    }
    
    /**
     * @dev Initialize a pool
     * @param key Pool key
     * @param sqrtPriceX96 Initial price
     * @return Current tick
     */
    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24) {
        PoolId id = toId(key);
        require(!poolState[id].initialized, "Pool already initialized");
        
        // For mock purposes, just set a fixed tick
        int24 tick = 0;
        
        poolState[id] = PoolState({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            initialized: true
        });
        
        pools[id] = true;
        
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
    ) external override returns (BalanceDelta memory delta) {
        PoolId id = toId(key);
        require(pools[id], "Pool not initialized");
        
        // Call hooks if they exist
        if (address(key.hooks) != address(0)) {
            // Call beforeSwap hook
            (bytes4 selector, BeforeSwapDelta memory beforeDelta) = IHooks(key.hooks).beforeSwap(
                msg.sender,
                key,
                params,
                hookData
            );
            
            // Verify selector
            require(selector == IHooks.beforeSwap.selector, "Invalid beforeSwap selector");
            
            // Apply changes from hook (in a real implementation)
            
            // Mock swap result
            delta = BalanceDelta(
                params.zeroForOne ? int256(-params.amountSpecified) : int256(0),
                params.zeroForOne ? int256(0) : int256(-params.amountSpecified)
            );
            
            // Call afterSwap hook
            (selector,) = IHooks(key.hooks).afterSwap(
                msg.sender,
                key,
                params,
                delta,
                hookData
            );
            
            // Verify selector
            require(selector == IHooks.afterSwap.selector, "Invalid afterSwap selector");
        } else {
            // Mock swap result without hooks
            delta = BalanceDelta(
                params.zeroForOne ? int256(-params.amountSpecified) : int256(0),
                params.zeroForOne ? int256(0) : int256(-params.amountSpecified)
            );
        }
        
        emit SwapCalled(msg.sender, key, params);
        return delta;
    }
    
    /**
     * @dev Modify liquidity in pool
     * @param key Pool key
     * @param params Liquidity parameters
     * @param hookData Additional data for hooks
     * @return delta Balance delta
     */
    function modifyLiquidity(
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (BalanceDelta memory delta) {
        PoolId id = toId(key);
        require(pools[id], "Pool not initialized");
        
        // Mock modification result
        delta = BalanceDelta(0, 0);
        
        emit ModifyLiquidityCalled(msg.sender, key, params);
        return delta;
    }
    
    /**
     * @dev Unlock the manager for operations
     * @param data Operations data
     * @return Result of callbacks
     */
    function unlock(bytes calldata data) external override returns (bytes memory) {
        // Call the unlock callback
        return IUnlockCallback(msg.sender).unlockCallback(data);
    }
} 