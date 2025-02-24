// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUniswapInterfaces.sol";
import "forge-std/console.sol";

/**
 * @title MockSwapRouter
 * @dev A simplified swap router for testing
 */
contract MockSwapRouter is IUnlockCallback {
    IPoolManager public immutable poolManager;
    address public lastActualSender;
    
    /**
     * @dev Constructor
     * @param _poolManager Pool manager address
     */
    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
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
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external payable returns (BalanceDelta memory delta) {
        // Store the original sender
        lastActualSender = msg.sender;
        console.log("SwapRouter swap - Original sender:", msg.sender);
        console.log("SwapRouter swap - ETH value:", msg.value);
        
        // Encode the parameters for the callback
        bytes memory data = abi.encode(key, params, hookData, msg.sender, msg.value);
        
        // Call unlock on the pool manager
        poolManager.unlock(data);
        
        // The actual swap happens in the unlockCallback
        // For simplicity, we're returning a mock delta here
        return BalanceDelta(0, 0);
    }
    
    /**
     * @dev Callback from pool manager
     * @param data Encoded swap data
     * @return Result
     */
    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(poolManager), "Not pool manager");
        
        // Decode parameters
        (
            PoolKey memory key,
            IPoolManager.SwapParams memory params,
            bytes memory hookData,
            address sender,
            uint256 ethValue
        ) = abi.decode(data, (PoolKey, IPoolManager.SwapParams, bytes, address, uint256));
        
        console.log("SwapRouter unlockCallback - Decoded sender:", sender);
        console.log("SwapRouter unlockCallback - ETH value:", ethValue);
        
        // Execute the swap as the original sender, passing along the ETH value
        BalanceDelta memory delta = IPoolManager(msg.sender).swap{value: ethValue}(key, params, hookData);
        
        // Return the result
        return abi.encode(delta);
    }
    
    /**
     * @dev Allow the contract to receive ETH
     */
    receive() external payable {}
} 