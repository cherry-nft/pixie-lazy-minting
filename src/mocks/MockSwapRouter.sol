// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IUniswapInterfaces.sol";
import "forge-std/console.sol";

/**
 * @title MockSwapRouter
 * @dev A simplified swap router for testing
 */
contract MockSwapRouter {
    address payable public poolManager;
    mapping(bytes32 => address) public originSenders;
    
    /**
     * @dev Constructor
     * @param _poolManager Pool manager address
     */
    constructor(address _poolManager) {
        poolManager = payable(_poolManager);
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
    ) external payable returns (BalanceDelta memory) {
        // Store the original sender for the callback
        bytes32 poolId = keccak256(abi.encode(key));
        originSenders[poolId] = msg.sender;
        
        // Log swap details
        console.log("MockSwapRouter: Swap initiated");
        console.log("  Value sent:", msg.value);
        console.log("  Amount specified:", uint256(params.amountSpecified));
        console.log("  Zero for one:", params.zeroForOne);
        
        // Decode the hook data to determine operation type
        bytes1 opType = bytes1(hookData[0]);
        console.log("  Operation type:", uint8(opType));
        
        // Forward value to pool manager for the swap
        // This ensures that the hook has access to ETH for buying operations
        (bool success, bytes memory data) = poolManager.call{value: msg.value}(
            abi.encodeWithSelector(
                IPoolManager.unlock.selector,
                abi.encode(key, params, hookData, msg.sender)
            )
        );
        
        require(success, "Mock Swap Router: unlock failed");
        
        // For sell operations (opType = 0x01), the ETH is returned to the user
        // This is handled automatically through the hook callback
        
        return abi.decode(data, (BalanceDelta));
    }
    
    /**
     * @dev Callback from pool manager
     * @param data Encoded swap data
     * @return Result
     */
    function unlockCallback(
        bytes calldata data,
        bytes calldata
    ) external returns (bytes memory) {
        // Decode the swap parameters
        (PoolKey memory key, IPoolManager.SwapParams memory params, bytes memory hookData, address sender) = 
            abi.decode(data, (PoolKey, IPoolManager.SwapParams, bytes, address));
        
        bytes32 poolId = keccak256(abi.encode(key));
        address originSender = originSenders[poolId];
        
        // Call to the pool manager to execute the swap
        IPoolManager pm = IPoolManager(poolManager);
        BalanceDelta memory delta = pm.swap(key, params, hookData);
        
        // If we're selling tokens (not zeroForOne), ensure ETH is sent back to the user
        // The hook will handle the actual ETH transfer after completing the sell
        // No need to do anything here as the hook will handle it
        
        return abi.encode(delta);
    }
    
    /**
     * @dev Allow the contract to receive ETH
     */
    receive() external payable {}
} 