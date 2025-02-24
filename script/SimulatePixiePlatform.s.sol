// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/LazyTokenFactory.sol";
import "../src/BondingCurve.sol";
import "../src/PixieToken.sol";

/**
 * @title SimulatePixiePlatform
 * @notice A simulation script that demonstrates how the Pixie platform works
 * with a bonding curve and lazy minting in a real-world scenario.
 */
contract SimulatePixiePlatform is Script {
    // Contracts
    BondingCurve bondingCurve;
    LazyTokenFactory factory;
    
    // Actors in our simulation
    address creator = address(0x1111);
    address alice = address(0x2222);
    address bob = address(0x3333);
    address charlie = address(0x4444);
    address diana = address(0x5555);
    address eve = address(0x6666);
    
    // Content
    bytes32 contentId = keccak256("Awesome NFT Collection #1");
    string tokenName = "Awesome NFT Token";
    string tokenSymbol = "AWESOME";
    string contentURI = "ipfs://QmAwesomeContentHash";
    
    // Tracking for reporting
    mapping(address => uint256) initialEthBalances;
    mapping(address => uint256) currentEthBalances;
    
    function run() public {
        // Run in fork mode for accurate simulation without broadcasts
        // Instead use vm.startPrank and vm.stopPrank for each actor
        
        console.log("\n====== PIXIE PLATFORM SIMULATION ======\n");
        console.log("Demonstrating how the Pixie platform works with a bonding curve and lazy minting");
        
        // Step 1: Deploy core contracts
        console.log("\n====== STEP 1: DEPLOYING CONTRACTS ======");
        bondingCurve = new BondingCurve();
        factory = new LazyTokenFactory(address(bondingCurve));
        
        console.log("Bonding Curve deployed at:   ", address(bondingCurve));
        console.log("Lazy Token Factory deployed at:", address(factory));
        
        // Provide initial ETH to all participants
        fundActors();
        saveInitialBalances();
        
        // Step 2: Creator registers a token
        console.log("\n====== STEP 2: CREATOR REGISTERS CONTENT ======");
        simulateCreatorRegistration();
        
        // Step 3: First buyer (Alice) discovers the content
        console.log("\n====== STEP 3: FIRST BUYER (ALICE) ======");
        simulateFirstBuyer();
        
        // Step 4: Second buyer (Bob) joins in
        console.log("\n====== STEP 4: SECOND BUYER (BOB) ======");
        simulateSecondBuyer();
        
        // Step 5: More interest (Charlie and Diana)
        console.log("\n====== STEP 5: MORE BUYERS JOIN (CHARLIE & DIANA) ======");
        simulateMoreBuyers();
        
        // Step 6: Eve buys a lot!
        console.log("\n====== STEP 6: LARGE PURCHASE (EVE) ======");
        simulateLargePurchase();
        
        // Step 7: Alice decides to sell half her tokens
        console.log("\n====== STEP 7: ALICE SELLS HALF HER TOKENS ======");
        simulatePartialSell();
        
        // Step 8: Bob sells all his tokens
        console.log("\n====== STEP 8: BOB SELLS ALL HIS TOKENS ======");
        simulateFullSell();
        
        // Step 9: Summary of what happened
        console.log("\n====== STEP 9: FINAL SUMMARY ======");
        simulateSummary();
    }
    
    // Helper functions
    function fundActors() internal {
        vm.deal(creator, 10 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(diana, 10 ether);
        vm.deal(eve, 10 ether);
    }
    
    function saveInitialBalances() internal {
        initialEthBalances[creator] = creator.balance;
        initialEthBalances[alice] = alice.balance;
        initialEthBalances[bob] = bob.balance;
        initialEthBalances[charlie] = charlie.balance;
        initialEthBalances[diana] = diana.balance;
        initialEthBalances[eve] = eve.balance;
    }
    
    function updateCurrentBalances() internal {
        currentEthBalances[creator] = creator.balance;
        currentEthBalances[alice] = alice.balance;
        currentEthBalances[bob] = bob.balance;
        currentEthBalances[charlie] = charlie.balance;
        currentEthBalances[diana] = diana.balance;
        currentEthBalances[eve] = eve.balance;
    }
    
    function simulateCreatorRegistration() internal {
        // Creator registers a token without deploying it
        vm.startPrank(creator);
        factory.registerToken(contentId, tokenName, tokenSymbol, creator, contentURI);
        vm.stopPrank();
        
        address expectedTokenAddress = factory.getTokenAddress(contentId);
        
        console.log("Content ID:     ", uint256(contentId));
        console.log("Token will be deployed at:", expectedTokenAddress);
        console.log("Initial price:  ", factory.getCurrentPrice(contentId) / 1e18, "ETH");
        
        // Verify token is not yet deployed
        bool isDeployed = factory.isTokenDeployed(contentId);
        console.log("Token deployed: ", isDeployed ? "Yes" : "No (lazy minting)");
    }
    
    function simulateFirstBuyer() internal {
        // Alice buys tokens
        uint256 alicePurchaseAmount = 0.1 ether;
        uint256 expectedTokens = factory.getBuyQuote(contentId, alicePurchaseAmount);
        
        console.log("Alice wants to buy with:  ", alicePurchaseAmount / 1e18, "ETH");
        console.log("Alice will receive approx:", expectedTokens / 1e18, "tokens");
        console.log("Current price before buy: ", factory.getCurrentPrice(contentId) / 1e18, "ETH");
        
        // Execute the purchase
        vm.startPrank(alice);
        address tokenAddress = factory.deployAndMint{value: alicePurchaseAmount}(contentId, alice);
        vm.stopPrank();
        
        // Get token instance after it's deployed
        PixieToken token = PixieToken(payable(tokenAddress));
        
        // Check balances and price
        uint256 aliceBalance = token.balanceOf(alice);
        uint256 creatorBalance = token.balanceOf(creator);
        uint256 newPrice = token.getCurrentPrice();
        
        console.log("Token deployed at:      ", tokenAddress);
        console.log("Alice received:         ", aliceBalance / 1e18, "tokens");
        console.log("Creator received:       ", creatorBalance / 1e18, "tokens (5% royalty)");
        console.log("New price after buy:    ", newPrice / 1e18, "ETH");
        
        updateCurrentBalances();
        uint256 ethToCreator = currentEthBalances[creator] - initialEthBalances[creator];
        console.log("Creator received:       ", ethToCreator / 1e18, "ETH (5% royalty)");
        console.log("Contract reserve:       ", address(token).balance / 1e18, "ETH");
    }
    
    function simulateSecondBuyer() internal {
        // Bob buys tokens
        uint256 bobPurchaseAmount = 0.2 ether;
        address tokenAddress = factory.getTokenAddress(contentId);
        PixieToken token = PixieToken(payable(tokenAddress));
        
        uint256 priceBeforeBob = token.getCurrentPrice();
        uint256 expectedTokens = factory.getBuyQuote(contentId, bobPurchaseAmount);
        
        console.log("Bob wants to buy with:  ", bobPurchaseAmount / 1e18, "ETH");
        console.log("Bob will receive approx: ", expectedTokens / 1e18, "tokens");
        console.log("Current price:          ", priceBeforeBob / 1e18, "ETH");
        
        // Execute the purchase
        vm.startPrank(bob);
        factory.deployAndMint{value: bobPurchaseAmount}(contentId, bob);
        vm.stopPrank();
        
        // Check balances and price
        uint256 bobBalance = token.balanceOf(bob);
        uint256 creatorBalanceBefore = currentEthBalances[creator];
        updateCurrentBalances();
        uint256 ethToCreator = currentEthBalances[creator] - creatorBalanceBefore;
        uint256 newPrice = token.getCurrentPrice();
        
        console.log("Bob received:           ", bobBalance / 1e18, "tokens");
        console.log("Creator received:       ", ethToCreator / 1e18, "ETH more (5% royalty)");
        console.log("New price after buy:    ", newPrice / 1e18, "ETH");
        console.log("Price increased by:     ", (newPrice - priceBeforeBob) / 1e18, "ETH");
        console.log("Contract reserve:       ", address(token).balance / 1e18, "ETH");
    }
    
    function simulateMoreBuyers() internal {
        address tokenAddress = factory.getTokenAddress(contentId);
        PixieToken token = PixieToken(payable(tokenAddress));
        uint256 priceBeforeMore = token.getCurrentPrice();
        
        // Charlie buys
        uint256 charliePurchaseAmount = 0.3 ether;
        vm.startPrank(charlie);
        factory.deployAndMint{value: charliePurchaseAmount}(contentId, charlie);
        vm.stopPrank();
        uint256 charlieBalance = token.balanceOf(charlie);
        uint256 priceAfterCharlie = token.getCurrentPrice();
        
        // Diana buys
        uint256 dianaPurchaseAmount = 0.25 ether;
        vm.startPrank(diana);
        factory.deployAndMint{value: dianaPurchaseAmount}(contentId, diana);
        vm.stopPrank();
        uint256 dianaBalance = token.balanceOf(diana);
        uint256 priceAfterDiana = token.getCurrentPrice();
        
        uint256 creatorBalanceBefore = currentEthBalances[creator];
        updateCurrentBalances();
        uint256 ethToCreator = currentEthBalances[creator] - creatorBalanceBefore;
        
        console.log("Charlie bought with:    ", charliePurchaseAmount / 1e18, "ETH");
        console.log("Charlie received:       ", charlieBalance / 1e18, "tokens");
        console.log("Price after Charlie:    ", priceAfterCharlie / 1e18, "ETH");
        
        console.log("Diana bought with:      ", dianaPurchaseAmount / 1e18, "ETH");
        console.log("Diana received:         ", dianaBalance / 1e18, "tokens");
        console.log("Price after Diana:      ", priceAfterDiana / 1e18, "ETH");
        
        console.log("Creator received:       ", ethToCreator / 1e18, "ETH more (5% royalty)");
        console.log("Total price increase:   ", (priceAfterDiana - priceBeforeMore) / 1e18, "ETH");
        console.log("Contract reserve:       ", address(token).balance / 1e18, "ETH");
    }
    
    function simulateLargePurchase() internal {
        address tokenAddress = factory.getTokenAddress(contentId);
        PixieToken token = PixieToken(payable(tokenAddress));
        uint256 priceBeforeEve = token.getCurrentPrice();
        
        // Eve makes a large purchase
        uint256 evePurchaseAmount = 2 ether;
        vm.startPrank(eve);
        factory.deployAndMint{value: evePurchaseAmount}(contentId, eve);
        vm.stopPrank();
        uint256 eveBalance = token.balanceOf(eve);
        uint256 priceAfterEve = token.getCurrentPrice();
        
        uint256 creatorBalanceBefore = currentEthBalances[creator];
        updateCurrentBalances();
        uint256 ethToCreator = currentEthBalances[creator] - creatorBalanceBefore;
        
        console.log("Eve bought with:        ", evePurchaseAmount / 1e18, "ETH");
        console.log("Eve received:           ", eveBalance / 1e18, "tokens");
        console.log("Price before Eve:       ", priceBeforeEve / 1e18, "ETH");
        console.log("Price after Eve:        ", priceAfterEve / 1e18, "ETH");
        console.log("Price increased by:     ", (priceAfterEve - priceBeforeEve) / 1e18, "ETH");
        console.log("Creator received:       ", ethToCreator / 1e18, "ETH more (5% royalty)");
        console.log("Contract reserve:       ", address(token).balance / 1e18, "ETH");
    }
    
    function simulatePartialSell() internal {
        address tokenAddress = factory.getTokenAddress(contentId);
        PixieToken token = PixieToken(payable(tokenAddress));
        uint256 priceBeforeSell = token.getCurrentPrice();
        
        // Alice sells half her tokens
        uint256 aliceBalance = token.balanceOf(alice);
        uint256 sellAmount = aliceBalance / 2;
        uint256 expectedEth = factory.getSellQuote(contentId, sellAmount);
        
        console.log("Alice current balance:  ", aliceBalance / 1e18, "tokens");
        console.log("Alice sells:            ", sellAmount / 1e18, "tokens");
        console.log("Alice expects to get:   ", expectedEth / 1e18, "ETH");
        console.log("Current price:          ", priceBeforeSell / 1e18, "ETH");
        
        // Approve and sell
        vm.startPrank(alice);
        token.approve(address(factory), sellAmount);
        uint256 ethReceived = factory.sellTokens(contentId, sellAmount);
        vm.stopPrank();
        
        uint256 aliceNewBalance = token.balanceOf(alice);
        uint256 priceAfterSell = token.getCurrentPrice();
        
        console.log("Alice received:         ", ethReceived / 1e18, "ETH");
        console.log("Alice's new balance:    ", aliceNewBalance / 1e18, "tokens");
        console.log("Price after sell:       ", priceAfterSell / 1e18, "ETH");
        console.log("Price decreased by:     ", (priceBeforeSell - priceAfterSell) / 1e18, "ETH");
        console.log("Contract reserve:       ", address(token).balance / 1e18, "ETH");
    }
    
    function simulateFullSell() internal {
        address tokenAddress = factory.getTokenAddress(contentId);
        PixieToken token = PixieToken(payable(tokenAddress));
        uint256 priceBeforeSell = token.getCurrentPrice();
        
        // Bob sells all his tokens
        uint256 bobBalance = token.balanceOf(bob);
        uint256 expectedEth = factory.getSellQuote(contentId, bobBalance);
        
        console.log("Bob current balance:    ", bobBalance / 1e18, "tokens");
        console.log("Bob sells all:          ", bobBalance / 1e18, "tokens");
        console.log("Bob expects to get:     ", expectedEth / 1e18, "ETH");
        console.log("Current price:          ", priceBeforeSell / 1e18, "ETH");
        
        // Approve and sell
        vm.startPrank(bob);
        token.approve(address(factory), bobBalance);
        uint256 ethReceived = factory.sellTokens(contentId, bobBalance);
        vm.stopPrank();
        
        uint256 bobNewBalance = token.balanceOf(bob);
        uint256 priceAfterSell = token.getCurrentPrice();
        
        console.log("Bob received:           ", ethReceived / 1e18, "ETH");
        console.log("Bob's new balance:      ", bobNewBalance / 1e18, "tokens");
        console.log("Price after sell:       ", priceAfterSell / 1e18, "ETH");
        console.log("Price decreased by:     ", (priceBeforeSell - priceAfterSell) / 1e18, "ETH");
        console.log("Contract reserve:       ", address(token).balance / 1e18, "ETH");
    }
    
    function simulateSummary() internal {
        address tokenAddress = factory.getTokenAddress(contentId);
        PixieToken token = PixieToken(payable(tokenAddress));
        updateCurrentBalances();
        
        console.log("=== FINAL STATE ===");
        console.log("Current token price:    ", token.getCurrentPrice() / 1e18, "ETH");
        console.log("Total supply:           ", token.totalSupply() / 1e18, "tokens");
        console.log("Contract reserve:       ", address(token).balance / 1e18, "ETH");
        
        console.log("\n=== TOKEN BALANCES ===");
        console.log("Creator:                ", token.balanceOf(creator) / 1e18, "tokens");
        console.log("Alice:                  ", token.balanceOf(alice) / 1e18, "tokens");
        console.log("Bob:                    ", token.balanceOf(bob) / 1e18, "tokens");
        console.log("Charlie:                ", token.balanceOf(charlie) / 1e18, "tokens");
        console.log("Diana:                  ", token.balanceOf(diana) / 1e18, "tokens");
        console.log("Eve:                    ", token.balanceOf(eve) / 1e18, "tokens");
        
        console.log("\n=== ETH CHANGES ===");
        console.log("Creator:                +", (currentEthBalances[creator] - initialEthBalances[creator]) / 1e18, "ETH (royalties)");
        console.log("Alice:                  ", (currentEthBalances[alice] - initialEthBalances[alice]) / 1e18, "ETH (spent/received)");
        console.log("Bob:                    ", (currentEthBalances[bob] - initialEthBalances[bob]) / 1e18, "ETH (spent/received)");
        console.log("Charlie:                ", (currentEthBalances[charlie] - initialEthBalances[charlie]) / 1e18, "ETH (spent)");
        console.log("Diana:                  ", (currentEthBalances[diana] - initialEthBalances[diana]) / 1e18, "ETH (spent)");
        console.log("Eve:                    ", (currentEthBalances[eve] - initialEthBalances[eve]) / 1e18, "ETH (spent)");
        
        console.log("\n=== KEY TAKEAWAYS ===");
        console.log("1. The token was lazily deployed only when the first purchase occurred");
        console.log("2. The price increased as more tokens were purchased");
        console.log("3. The price decreased when tokens were sold back");
        console.log("4. The creator earned 5% royalties on all purchases");
        console.log("5. Early buyers (Alice) got better prices than later buyers (Eve)");
        console.log("6. The bonding curve provided continuous liquidity for selling");
    }
} 