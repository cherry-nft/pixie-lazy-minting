// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LazyTokenFactory.sol";
import "../src/PixieHook.sol";
import "../src/BondingCurve.sol";
import "../src/mocks/MockPoolManager.sol";
import "../src/mocks/MockSwapRouter.sol";

contract DeployLazyMinting is Script {
    function run() public {
        // Retrieve the private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy bonding curve
        BondingCurve bondingCurve = new BondingCurve();
        console.log("BondingCurve deployed at:", address(bondingCurve));
        
        // Deploy mock pool manager for testing
        MockPoolManager poolManager = new MockPoolManager();
        console.log("MockPoolManager deployed at:", address(poolManager));
        
        // Deploy token factory with bonding curve
        LazyTokenFactory factory = new LazyTokenFactory(address(bondingCurve));
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
        
        // Get price quotes
        uint256 initialPrice = factory.getCurrentPrice(contentId);
        uint256 buyQuote = factory.getBuyQuote(contentId, 0.1 ether);
        console.log("Initial token price (in ETH):", initialPrice);
        console.log("Tokens from 0.1 ETH:", buyQuote);
        
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
        
        // Setup swap params - buying tokens
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, // Buying the token
            amountSpecified: 1e18, // 1 ETH worth
            sqrtPriceLimitX96: 0 // No price limit
        });
        
        // Prepare hook data for a buy operation
        // First byte 0 = Buy operation
        bytes memory hookData = abi.encodePacked(bytes1(0x00), msg.sender);
        
        // Execute swap to trigger lazy deployment with ETH value
        uint256 ethAmount = 0.1 ether;
        router.swap{value: ethAmount}(poolKey, params, hookData);
        
        // Check if token is deployed
        bool isDeployed = factory.isTokenDeployed(contentId);
        console.log("Token deployed:", isDeployed);
        
        if (isDeployed) {
            console.log("Token deployed at:", tokenAddress);
            
            // Get token prices after purchase
            uint256 currentPrice = factory.getCurrentPrice(contentId);
            console.log("Current token price (in ETH):", currentPrice);
        }
        
        vm.stopBroadcast();
    }
}

contract SellTestTokens is Script {
    function run() public {
        // Retrieve the private key and addresses from environment
        uint256 sellerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable routerAddress = payable(vm.envAddress("ROUTER_ADDRESS"));
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        bytes32 contentId = vm.envBytes32("CONTENT_ID");
        uint256 tokenAmount = vm.envUint("TOKEN_AMOUNT");
        
        vm.startBroadcast(sellerPrivateKey);
        
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
        
        // Setup swap params - selling tokens
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false, // Selling the token
            amountSpecified: int256(tokenAmount),
            sqrtPriceLimitX96: 0 // No price limit
        });
        
        // Prepare hook data for a sell operation
        // First byte 1 = Sell operation
        bytes memory hookData = abi.encodePacked(bytes1(0x01), msg.sender);
        
        // Approve tokens to be spent by the factory
        address payable tokenPayable = payable(tokenAddress);
        PixieToken token = PixieToken(tokenPayable);
        token.approve(address(factory), tokenAmount);
        
        // Get sell quote before selling
        uint256 ethQuote = factory.getSellQuote(contentId, tokenAmount);
        console.log("Expected ETH return:", ethQuote);
        
        // Execute swap to trigger token sale
        router.swap(poolKey, params, hookData);
        
        // Get token prices after sale
        uint256 currentPrice = factory.getCurrentPrice(contentId);
        console.log("Current token price (in ETH):", currentPrice);
        
        vm.stopBroadcast();
    }
} 