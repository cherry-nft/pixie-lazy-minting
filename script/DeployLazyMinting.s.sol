// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LazyTokenFactory.sol";
import "../src/PixieHook.sol";
import "../src/mocks/MockPoolManager.sol";
import "../src/mocks/MockSwapRouter.sol";

contract DeployLazyMinting is Script {
    function run() public {
        // Retrieve the private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock pool manager for testing
        MockPoolManager poolManager = new MockPoolManager();
        console.log("MockPoolManager deployed at:", address(poolManager));
        
        // Deploy token factory
        LazyTokenFactory factory = new LazyTokenFactory();
        console.log("LazyTokenFactory deployed at:", address(factory));
        
        // Deploy hook
        PixieHook hook = new PixieHook(address(factory), address(poolManager));
        console.log("PixieHook deployed at:", address(hook));
        
        // Deploy mock swap router
        MockSwapRouter router = new MockSwapRouter(address(poolManager));
        console.log("MockSwapRouter deployed at:", address(router));
        
        vm.stopBroadcast();
    }
}

contract RegisterTestToken is Script {
    function run() public {
        // Retrieve the private key and factory address from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        // Test token details
        bytes32 contentId = keccak256("Test Content");
        string memory tokenName = "Pixie Test Token";
        string memory tokenSymbol = "PTT";
        string memory contentURI = "ipfs://QmTest";
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get factory instance
        LazyTokenFactory factory = LazyTokenFactory(factoryAddress);
        
        // Register a test token
        factory.registerToken(contentId, tokenName, tokenSymbol, msg.sender, contentURI);
        
        // Get token address
        address tokenAddress = factory.getTokenAddress(contentId);
        console.log("Test token registered with future address:", tokenAddress);
        console.log("Content ID (for swapping):", vm.toString(contentId));
        
        vm.stopBroadcast();
    }
}

contract ExecuteTestSwap is Script {
    function run() public {
        // Retrieve the private key and addresses from environment
        uint256 buyerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable routerAddress = payable(vm.envAddress("ROUTER_ADDRESS"));
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        bytes32 contentId = vm.envBytes32("CONTENT_ID");
        
        vm.startBroadcast(buyerPrivateKey);
        
        // Get contract instances
        MockSwapRouter router = MockSwapRouter(routerAddress);
        LazyTokenFactory factory = LazyTokenFactory(factoryAddress);
        
        // Get token address
        address tokenAddress = factory.getTokenAddress(contentId);
        Currency tokenCurrency = Currency.wrap(tokenAddress);
        
        // Setup pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0xCafe)), // Mock base currency
            currency1: tokenCurrency, // Our lazy token
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: hookAddress
        });
        
        // Setup swap params
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, // Buying the token
            amountSpecified: 1e18, // 1 ETH worth
            sqrtPriceLimitX96: 0 // No price limit
        });
        
        // Execute swap to trigger lazy deployment with ETH value
        uint256 ethAmount = 0.1 ether;
        router.swap{value: ethAmount}(poolKey, params, "");
        
        // Check if token is deployed
        bool isDeployed = factory.isTokenDeployed(contentId);
        console.log("Token deployed:", isDeployed);
        
        if (isDeployed) {
            console.log("Token deployed at:", tokenAddress);
        }
        
        vm.stopBroadcast();
    }
} 