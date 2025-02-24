// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LazyTokenFactory.sol";
import "../src/PixieHook.sol";
import "../src/mocks/MockPoolManager.sol";
import "../src/mocks/MockSwapRouter.sol";
import "../src/interfaces/IUniswapInterfaces.sol";
import "../src/PixieToken.sol";
import "../src/BondingCurve.sol";

contract LazyMintingTest is Test {
    // Contracts
    LazyTokenFactory public factory;
    MockPoolManager public poolManager;
    PixieHook public hook;
    MockSwapRouter public router;
    BondingCurve public bondingCurve;
    
    // Test accounts
    address public creator = address(0x1);
    address public buyer = address(0x2);
    
    // Test data
    bytes32 public contentId = keccak256("Test Content");
    string public tokenName = "Pixie Test Token";
    string public tokenSymbol = "PTT";
    string public contentURI = "ipfs://QmTest";
    
    // Pool settings
    uint24 constant FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    
    function setUp() public {
        // Deploy contracts
        bondingCurve = new BondingCurve();
        poolManager = new MockPoolManager();
        factory = new LazyTokenFactory(address(bondingCurve));
        hook = new PixieHook(address(factory), address(poolManager));
        router = new MockSwapRouter(address(poolManager));
        
        // Setup test accounts
        vm.deal(creator, 10 ether);
        vm.deal(buyer, 10 ether);
        
        // Register token metadata
        vm.prank(creator);
        factory.registerToken(contentId, tokenName, tokenSymbol, creator, contentURI);
    }
    
    function testTokenRegistration() public {
        // Verify token registration
        (string memory name, string memory symbol, address creatorAddr, string memory uri, bool deployed) = factory.tokenMetadata(contentId);
        assertEq(name, tokenName);
        assertEq(symbol, tokenSymbol);
        assertEq(creatorAddr, creator);
        assertEq(uri, contentURI);
        assertEq(deployed, false);
    }
    
    function testGetTokenAddress() public {
        // Get the predetermined address
        address tokenAddress = factory.getTokenAddress(contentId);
        
        // Verify the address is not zero
        assertTrue(tokenAddress != address(0));
        
        // Verify token is not yet deployed
        uint32 size;
        assembly {
            size := extcodesize(tokenAddress)
        }
        assertEq(size, 0);
    }
    
    function testLazyDeployment() public {
        // Get the predetermined address
        address tokenAddress = factory.getTokenAddress(contentId);
        
        // Pre-check token deployment status
        assertFalse(factory.isTokenDeployed(contentId));
        
        // Deploy the token
        address deployedAddress = factory.deployToken(contentId);
        
        // Verify token is now deployed
        assertTrue(factory.isTokenDeployed(contentId));
        assertEq(deployedAddress, tokenAddress);
        
        // Verify token contract exists
        uint32 size;
        assembly {
            size := extcodesize(tokenAddress)
        }
        assertTrue(size > 0);
        
        // Verify token details
        address payable tokenPayable = payable(tokenAddress);
        PixieToken token = PixieToken(tokenPayable);
        assertEq(token.name(), tokenName);
        assertEq(token.symbol(), tokenSymbol);
        assertEq(token.creator(), creator);
        assertEq(token.contentURI(), contentURI);
    }
    
    function testLazyDeploymentViaHook() public {
        // Get the predetermined address
        address tokenAddress = factory.getTokenAddress(contentId);
        console.log("Expected token address:", tokenAddress);
        console.log("Creator address:", creator);
        console.log("Buyer address:", buyer);
        
        // Wrap the address in Currency
        Currency currency = Currency.wrap(tokenAddress);
        
        // Setup pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0xCafe)), // Mock base currency
            currency1: currency, // Our lazy token
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: address(hook)
        });
        
        console.log("Hook address:", address(hook));
        
        // Initialize the pool
        poolManager.initialize(poolKey, 1e18); // Initial price of 1
        
        // Setup swap params
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, // Buying the token
            amountSpecified: 1e18, // 1 ETH worth
            sqrtPriceLimitX96: 0 // No price limit
        });
        
        console.log("Before swap - Token deployed:", factory.isTokenDeployed(contentId));
        
        // Execute swap as buyer (which should trigger lazy deployment)
        vm.prank(buyer);
        // Pass the buyer address as hook data for proper recipient tracking
        bytes memory hookData = abi.encode(buyer);
        // Add ETH value to the swap call to support the royalty model
        router.swap{value: 1 ether}(poolKey, params, hookData);
        
        console.log("After swap - Token deployed:", factory.isTokenDeployed(contentId));
        
        // Verify token is now deployed
        assertTrue(factory.isTokenDeployed(contentId), "Token should be deployed");
        
        // Verify token details
        address payable tokenPayable = payable(tokenAddress);
        PixieToken token = PixieToken(tokenPayable);
        assertEq(token.name(), tokenName, "Token name should match");
        assertEq(token.symbol(), tokenSymbol, "Token symbol should match");
        
        // Verify token balances
        uint256 buyerBalance = token.balanceOf(buyer);
        uint256 creatorBalance = token.balanceOf(creator);
        uint256 hookBalance = token.balanceOf(address(hook));
        
        console.log("Content ID:", uint256(contentId));
        console.log("Actual token address:", address(token));
        console.log("Buyer balance:", buyerBalance);
        console.log("Creator balance:", creatorBalance);
        console.log("Hook balance:", hookBalance);
        
        assertTrue(buyerBalance > 0, "Buyer should have tokens");
        assertTrue(creatorBalance > 0, "Creator should have tokens");
        // Hook balance check is removed since hook no longer receives tokens in the royalty model
    }

    function testLazyTokenCreation() public {
        // ... existing code ...
        address tokenAddress = factory.getTokenAddress(contentId);
        
        // ... existing code ...
        // Validate lazy token properties
        address payable tokenPayable = payable(tokenAddress);
        PixieToken token = PixieToken(tokenPayable);
        // ... existing code ...
    }
    
    function testMultipleMints() public {
        // ... existing code ...
        address tokenAddress = factory.getTokenAddress(contentId);
        // ... existing code ...
        address payable tokenPayable = payable(tokenAddress);
        PixieToken token = PixieToken(tokenPayable);
        // ... existing code ...
    }
} 