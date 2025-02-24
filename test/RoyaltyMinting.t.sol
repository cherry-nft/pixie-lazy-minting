// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LazyTokenFactory.sol";
import "../src/PixieHook.sol";
import "../src/mocks/MockPoolManager.sol";
import "../src/mocks/MockSwapRouter.sol";
import "../src/interfaces/IUniswapInterfaces.sol";
import "../src/PixieToken.sol";

contract RoyaltyMintingTest is Test {
    // Contracts
    LazyTokenFactory public factory;
    MockPoolManager public poolManager;
    PixieHook public hook;
    MockSwapRouter public router;
    
    // Test accounts
    address public creator = address(0x1);
    address public buyer1 = address(0x2);
    address public buyer2 = address(0x3);
    
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
        poolManager = new MockPoolManager();
        factory = new LazyTokenFactory();
        hook = new PixieHook(address(factory), address(poolManager));
        router = new MockSwapRouter(address(poolManager));
        
        // Setup test accounts
        vm.deal(creator, 10 ether);
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);
        
        // Register token metadata
        vm.prank(creator);
        factory.registerToken(contentId, tokenName, tokenSymbol, creator, contentURI);
    }
    
    function testDirectPurchaseWithRoyalty() public {
        // Track creator's ETH balance before purchase
        uint256 creatorEthBefore = creator.balance;
        
        // Make a direct purchase with ETH
        uint256 purchaseAmount = 1 ether;
        
        vm.prank(buyer1);
        address tokenAddress = factory.deployAndMint{value: purchaseAmount}(contentId, buyer1);
        
        // Verify token is deployed
        assertTrue(factory.isTokenDeployed(contentId), "Token should be deployed");
        
        // Verify token details
        PixieToken token = PixieToken(tokenAddress);
        assertEq(token.name(), tokenName, "Token name should match");
        assertEq(token.symbol(), tokenSymbol, "Token symbol should match");
        assertEq(token.creator(), creator, "Creator should match");
        
        // Calculate expected token amounts
        uint256 expectedBuyerTokens = purchaseAmount * 95 / 100; // 95% to buyer
        uint256 expectedCreatorTokens = purchaseAmount * 5 / 100; // 5% to creator
        
        // Verify token balances
        uint256 buyerBalance = token.balanceOf(buyer1);
        uint256 creatorBalance = token.balanceOf(creator);
        
        assertEq(buyerBalance, expectedBuyerTokens, "Buyer should have 95% of tokens");
        assertEq(creatorBalance, expectedCreatorTokens, "Creator should have 5% of tokens");
        
        // Verify ETH was transferred to creator
        uint256 creatorEthAfter = creator.balance;
        assertEq(creatorEthAfter - creatorEthBefore, purchaseAmount, "Creator should receive the ETH");
        
        // Log results
        console.log("Purchase amount (ETH):", purchaseAmount);
        console.log("Buyer tokens received:", buyerBalance);
        console.log("Creator tokens received:", creatorBalance);
        console.log("Creator ETH received:", creatorEthAfter - creatorEthBefore);
    }
    
    function testSubsequentPurchaseWithRoyalty() public {
        // First purchase to deploy the token
        uint256 firstPurchase = 0.5 ether;
        vm.prank(buyer1);
        address tokenAddress = factory.deployAndMint{value: firstPurchase}(contentId, buyer1);
        
        // Track balances after first purchase
        PixieToken token = PixieToken(tokenAddress);
        uint256 buyer1BalanceAfterFirstPurchase = token.balanceOf(buyer1);
        uint256 creatorBalanceAfterFirstPurchase = token.balanceOf(creator);
        uint256 creatorEthAfterFirstPurchase = creator.balance;
        
        // Make a second purchase
        uint256 secondPurchase = 2 ether;
        vm.prank(buyer2);
        factory.deployAndMint{value: secondPurchase}(contentId, buyer2);
        
        // Calculate expected token amounts for second purchase
        uint256 expectedBuyer2Tokens = secondPurchase * 95 / 100; // 95% to buyer2
        uint256 expectedCreatorAdditionalTokens = secondPurchase * 5 / 100; // 5% to creator
        
        // Verify token balances after second purchase
        uint256 buyer1BalanceAfterSecondPurchase = token.balanceOf(buyer1);
        uint256 buyer2BalanceAfterSecondPurchase = token.balanceOf(buyer2);
        uint256 creatorBalanceAfterSecondPurchase = token.balanceOf(creator);
        uint256 creatorEthAfterSecondPurchase = creator.balance;
        
        // Buyer1's balance should not change
        assertEq(buyer1BalanceAfterSecondPurchase, buyer1BalanceAfterFirstPurchase, "Buyer1 balance should not change");
        
        // Buyer2 should receive tokens
        assertEq(buyer2BalanceAfterSecondPurchase, expectedBuyer2Tokens, "Buyer2 should have 95% of second purchase tokens");
        
        // Creator should receive additional tokens
        assertEq(
            creatorBalanceAfterSecondPurchase - creatorBalanceAfterFirstPurchase, 
            expectedCreatorAdditionalTokens, 
            "Creator should receive 5% of second purchase tokens"
        );
        
        // Creator should receive the ETH
        assertEq(
            creatorEthAfterSecondPurchase - creatorEthAfterFirstPurchase, 
            secondPurchase, 
            "Creator should receive the ETH from second purchase"
        );
        
        // Log results
        console.log("First purchase (ETH):", firstPurchase);
        console.log("Second purchase (ETH):", secondPurchase);
        console.log("Buyer1 tokens:", buyer1BalanceAfterSecondPurchase);
        console.log("Buyer2 tokens:", buyer2BalanceAfterSecondPurchase);
        console.log("Creator total tokens:", creatorBalanceAfterSecondPurchase);
        console.log("Creator total ETH received:", creatorEthAfterSecondPurchase);
    }
    
    function testVariablePurchaseAmounts() public {
        // Test with different purchase amounts
        uint256[] memory purchaseAmounts = new uint256[](3);
        purchaseAmounts[0] = 0.1 ether;  // Minimum purchase
        purchaseAmounts[1] = 1.5 ether;  // Mid-range purchase
        purchaseAmounts[2] = 5 ether;    // Large purchase
        
        for (uint i = 0; i < purchaseAmounts.length; i++) {
            // Reset the test environment
            setUp();
            
            uint256 amount = purchaseAmounts[i];
            uint256 creatorEthBefore = creator.balance;
            
            // Make purchase
            vm.prank(buyer1);
            address tokenAddress = factory.deployAndMint{value: amount}(contentId, buyer1);
            
            // Calculate expected tokens
            uint256 expectedBuyerTokens = amount * 95 / 100;
            uint256 expectedCreatorTokens = amount * 5 / 100;
            
            // Verify balances
            PixieToken token = PixieToken(tokenAddress);
            uint256 buyerBalance = token.balanceOf(buyer1);
            uint256 creatorBalance = token.balanceOf(creator);
            
            assertEq(buyerBalance, expectedBuyerTokens, "Buyer should have 95% of tokens");
            assertEq(creatorBalance, expectedCreatorTokens, "Creator should have 5% of tokens");
            
            // Verify ETH transfer
            uint256 creatorEthAfter = creator.balance;
            assertEq(creatorEthAfter - creatorEthBefore, amount, "Creator should receive the ETH");
            
            console.log("Test case", i+1, "- Purchase amount:", amount);
            console.log("Buyer tokens:", buyerBalance);
            console.log("Creator tokens:", creatorBalance);
        }
    }
    
    function testLazyMintingViaHook() public {
        // Get the predetermined address
        address tokenAddress = factory.getTokenAddress(contentId);
        
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
        
        // Initialize the pool
        poolManager.initialize(poolKey, 1e18); // Initial price of 1
        
        // Purchase amount in ETH
        uint256 purchaseAmount = 0.5 ether;
        
        // Setup swap params (use amountSpecified to communicate ETH amount)
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, // Buying the token
            amountSpecified: int256(purchaseAmount), // ETH amount
            sqrtPriceLimitX96: 0 // No price limit
        });
        
        // Track creator ETH balance before swap
        uint256 creatorEthBefore = creator.balance;
        
        // Execute swap as buyer with ETH value
        vm.prank(buyer1);
        bytes memory hookData = abi.encode(buyer1); // Pass buyer address in hook data
        router.swap{value: purchaseAmount}(poolKey, params, hookData);
        
        // Verify token is deployed
        assertTrue(factory.isTokenDeployed(contentId), "Token should be deployed");
        
        // Verify token details
        PixieToken token = PixieToken(tokenAddress);
        
        // Calculate expected token amounts
        uint256 expectedBuyerTokens = purchaseAmount * 95 / 100; // 95% to buyer
        uint256 expectedCreatorTokens = purchaseAmount * 5 / 100; // 5% to creator
        
        // Verify token balances
        uint256 buyerBalance = token.balanceOf(buyer1);
        uint256 creatorBalance = token.balanceOf(creator);
        
        // Some tolerance might be needed due to gas fees or implementation details
        assertApproxEqRel(buyerBalance, expectedBuyerTokens, 0.01e18, "Buyer should have ~95% of tokens");
        assertApproxEqRel(creatorBalance, expectedCreatorTokens, 0.01e18, "Creator should have ~5% of tokens");
        
        // Verify ETH was transferred to creator
        uint256 creatorEthAfter = creator.balance;
        assertEq(creatorEthAfter - creatorEthBefore, purchaseAmount, "Creator should receive the ETH");
        
        // Log results
        console.log("Hook test - Purchase amount (ETH):", purchaseAmount);
        console.log("Buyer tokens received:", buyerBalance);
        console.log("Creator tokens received:", creatorBalance);
        console.log("Creator ETH received:", creatorEthAfter - creatorEthBefore);
    }
} 