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
        
        // Log swap details
        console.log("MockSwapRouter: Swap initiated");
        console.log("  Value sent:", msg.value);
        console.log("  Amount specified:", uint256(params.amountSpecified));
        console.log("  Zero for one:", params.zeroForOne);
        
        // Decode the hook data to determine operation type
        bytes1 opType = bytes1(hookData[0]);
        console.log("  Operation type:", uint8(opType));
        console.log("  Hook data length:", hookData.length);
        
        // Prepare the data for the unlock call
        bytes memory encodedData = abi.encode(key, params, hookData, msg.sender);
        console.log("  Encoded data length:", encodedData.length);
        
        // Forward value to pool manager for the swap
        // This ensures that the hook has access to ETH for buying operations
        (bool success, bytes memory data) = poolManager.call{value: msg.value}(
            abi.encodeWithSelector(
                IPoolManager.unlock.selector,
                encodedData
            )
        );
        
        if (!success) {
            console.log("  Call to unlock failed");
            return BalanceDelta(0, 0);
        }
        
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
        
        // Log decoded data for troubleshooting
        console.log("UnlockCallback: Processing hook data of length", hookData.length);
        if (hookData.length > 0) {
            console.log("  Operation type:", uint8(bytes1(hookData[0])));
        }
        
        // Call to the pool manager to execute the swap
        IPoolManager pm = IPoolManager(poolManager);
        
        // Pass the hook data directly - do not try to re-encode it
        // The IPoolManager.swap function only accepts 3 parameters, not 4
        BalanceDelta memory delta = pm.swap(key, params, hookData);
        
        return abi.encode(delta);
    }
    
    /**
     * @dev Allow the contract to receive ETH
     */
    receive() external payable {}
} 