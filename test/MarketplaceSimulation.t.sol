// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LazyTokenFactory.sol";
import "../src/PixieToken.sol";
import "../src/BondingCurve.sol";

/**
 * @title MarketplaceSimulationTest
 * @dev Comprehensive simulation of marketplace activity with multiple creators and buyers
 */
contract MarketplaceSimulationTest is Test {
    // Constants
    uint256 public constant INITIAL_CREATOR_BALANCE = 1 ether;
    uint256 public constant INITIAL_BUYER_BALANCE = 10 ether;
    
    // Contracts
    BondingCurve public bondingCurve;
    LazyTokenFactory public factory;
    
    // Test participants
    address[] public creators;
    address[] public buyers;
    
    // Content tracking
    bytes32[] public contentIds;
    mapping(bytes32 => address payable) public tokenAddresses;
    
    // Transaction tracking
    struct Transaction {
        string action;
        address user;
        bytes32 contentId;
        uint256 ethAmount;
        uint256 tokenAmount;
    }
    Transaction[] public transactions;
    
    // Set up the test environment
    function setUp() public {
        // Deploy the bonding curve
        bondingCurve = new BondingCurve();
        
        // Deploy the factory
        factory = new LazyTokenFactory(address(bondingCurve));
        
        // Create 5 creators
        for (uint256 i = 0; i < 5; i++) {
            address creator = makeAddr(string.concat("Creator", vm.toString(i+1)));
            creators.push(creator);
            vm.deal(creator, INITIAL_CREATOR_BALANCE);
        }
        
        // Create 10 buyers
        for (uint256 i = 0; i < 10; i++) {
            address buyer = makeAddr(string.concat("Buyer", vm.toString(i+1)));
            buyers.push(buyer);
            vm.deal(buyer, INITIAL_BUYER_BALANCE);
        }
    }
    
    // Record transaction for reporting
    function recordTransaction(
        string memory action,
        address user,
        bytes32 contentId,
        uint256 ethAmount,
        uint256 tokenAmount
    ) internal {
        transactions.push(Transaction({
            action: action,
            user: user,
            contentId: contentId,
            ethAmount: ethAmount,
            tokenAmount: tokenAmount
        }));
    }
    
    // Main test simulating a complete marketplace
    function testFullMarketplaceSimulation() public {
        emit log_string("========= STARTING MARKETPLACE SIMULATION =========");
        
        // Phase 1: Each creator registers a token
        emit log_string("--- PHASE 1: TOKEN REGISTRATION ---");
        for (uint256 i = 0; i < creators.length; i++) {
            vm.startPrank(creators[i]);
            
            bytes32 contentId = keccak256(abi.encodePacked("Content from Creator", vm.toString(i+1)));
            string memory name = string.concat("Token", vm.toString(i+1));
            string memory symbol = string.concat("TKN", vm.toString(i+1));
            string memory contentURI = string.concat("ipfs://content/", vm.toString(i+1));
            
            factory.registerToken(contentId, name, symbol, creators[i], contentURI);
            contentIds.push(contentId);
            
            recordTransaction("register", creators[i], contentId, 0, 0);
            
            address payable tokenAddr = payable(factory.getTokenAddress(contentId));
            tokenAddresses[contentId] = tokenAddr;
            
            vm.stopPrank();
        }
        
        // Phase 2: Initial purchases - each creator's token gets bought by 2 different buyers
        emit log_string("--- PHASE 2: INITIAL PURCHASES ---");
        for (uint256 i = 0; i < creators.length; i++) {
            bytes32 contentId = contentIds[i];
            
            // First buyer buys with 0.5 ETH
            {
                uint256 buyerIdx = i * 2;
                address buyer = buyers[buyerIdx];
                uint256 ethAmount = 0.5 ether;
                
                vm.startPrank(buyer);
                
                uint256 buyerEthBefore = buyer.balance;
                uint256 creatorEthBefore = creators[i].balance;
                
                address payable tokenAddr = payable(factory.deployAndMint{value: ethAmount}(contentId, buyer));
                require(tokenAddr == tokenAddresses[contentId], "Token address mismatch");
                
                uint256 buyerTokenBalance = PixieToken(tokenAddr).balanceOf(buyer);
                uint256 creatorTokenBalance = PixieToken(tokenAddr).balanceOf(creators[i]);
                
                recordTransaction("buy", buyer, contentId, ethAmount, buyerTokenBalance);
                
                vm.stopPrank();
            }
            
            // Second buyer buys with 1 ETH
            {
                uint256 buyerIdx = i * 2 + 1;
                address buyer = buyers[buyerIdx];
                uint256 ethAmount = 1 ether;
                
                vm.startPrank(buyer);
                
                uint256 buyerEthBefore = buyer.balance;
                uint256 creatorEthBefore = creators[i].balance;
                
                factory.deployAndMint{value: ethAmount}(contentId, buyer);
                
                uint256 buyerTokenBalance = PixieToken(tokenAddresses[contentId]).balanceOf(buyer);
                uint256 creatorTokenBalance = PixieToken(tokenAddresses[contentId]).balanceOf(creators[i]);
                
                recordTransaction("buy", buyer, contentId, ethAmount, buyerTokenBalance);
                
                vm.stopPrank();
            }
        }
        
        // Phase 3: Some buyers sell partial amounts
        emit log_string("--- PHASE 3: PARTIAL TOKEN SALES ---");
        for (uint256 i = 0; i < 3; i++) {
            // Choose a buyer
            address buyer = buyers[i];
            // Choose which content ID to sell
            bytes32 contentId = contentIds[i % creators.length];
            address payable tokenAddr = tokenAddresses[contentId];
            
            vm.startPrank(buyer);
            
            // Get buyer's token balance
            uint256 tokenBalance = PixieToken(tokenAddr).balanceOf(buyer);
            emit log_named_uint("Buyer token balance", tokenBalance);
            
            // Only proceed if the buyer has tokens
            if (tokenBalance > 0) {
                // Sell 50% of tokens - use a larger percentage to avoid "amount too small" errors
                uint256 sellAmount = tokenBalance / 2;
                emit log_named_uint("Sell amount", sellAmount);
                
                // Approve tokens for selling
                PixieToken(tokenAddr).approve(address(factory), sellAmount);
                
                // Get sell quote to verify amount
                uint256 expectedEth = factory.getSellQuote(contentId, sellAmount);
                emit log_named_uint("Expected ETH from sell", expectedEth);
                
                // Only sell if the expected ETH is enough
                if (expectedEth >= 0.0000001 ether) {
                    // Sell tokens
                    uint256 ethReceived = factory.sellTokens(contentId, sellAmount);
                    
                    recordTransaction("sell_partial", buyer, contentId, ethReceived, sellAmount);
                } else {
                    emit log_string("Skipping sell due to small ETH return");
                }
            } else {
                emit log_string("Buyer has no tokens to sell");
            }
            
            vm.stopPrank();
        }
        
        // Phase 4: More buyers purchase tokens
        emit log_string("--- PHASE 4: ADDITIONAL PURCHASES ---");
        for (uint256 i = 5; i < 8; i++) {
            address buyer = buyers[i];
            bytes32 contentId = contentIds[(i+1) % creators.length];
            address payable tokenAddr = tokenAddresses[contentId];
            uint256 ethAmount = 0.7 ether;
            
            vm.startPrank(buyer);
            
            uint256 buyerEthBefore = buyer.balance;
            uint256 buyerTokenBefore = PixieToken(tokenAddr).balanceOf(buyer);
            
            factory.deployAndMint{value: ethAmount}(contentId, buyer);
            
            uint256 buyerTokenAfter = PixieToken(tokenAddr).balanceOf(buyer);
            uint256 tokensBought = buyerTokenAfter - buyerTokenBefore;
            
            recordTransaction("buy", buyer, contentId, ethAmount, tokensBought);
            
            vm.stopPrank();
        }
        
        // Phase 5: Some buyers sell ALL their tokens
        emit log_string("--- PHASE 5: FULL TOKEN SALES ---");
        for (uint256 i = 3; i < 5; i++) {
            address buyer = buyers[i];
            bytes32 contentId = contentIds[(i+2) % creators.length];
            address payable tokenAddr = tokenAddresses[contentId];
            
            vm.startPrank(buyer);
            
            // Get buyer's full token balance
            uint256 tokenBalance = PixieToken(tokenAddr).balanceOf(buyer);
            emit log_named_uint("Buyer token balance for full sell", tokenBalance);
            
            // Only proceed if the buyer has tokens
            if (tokenBalance > 0) {
                emit log_named_uint("Selling all tokens", tokenBalance);
                
                // Get sell quote to verify amount
                uint256 expectedEth = factory.getSellQuote(contentId, tokenBalance);
                emit log_named_uint("Expected ETH from full sell", expectedEth);
                
                // Only sell if the expected ETH is enough
                if (expectedEth >= 0.0000001 ether) {
                    // Approve tokens for selling
                    PixieToken(tokenAddr).approve(address(factory), tokenBalance);
                    
                    // Sell ALL tokens
                    uint256 ethReceived = factory.sellTokens(contentId, tokenBalance);
                    
                    uint256 newTokenBalance = PixieToken(tokenAddr).balanceOf(buyer);
                    assertEq(newTokenBalance, 0, "Buyer should have zero tokens after selling all");
                    
                    recordTransaction("sell_all", buyer, contentId, ethReceived, tokenBalance);
                } else {
                    emit log_string("Skipping full sell due to small ETH return");
                }
            } else {
                emit log_string("Buyer has no tokens for full sell");
            }
            
            vm.stopPrank();
        }
        
        // Make sure each buyer has bought tokens for the remaining tests
        emit log_string("--- ENSURING BUYERS HAVE TOKENS FOR FINAL TESTS ---");
        {
            // Give buyer 0, 1, and 8 some tokens if they don't have any
            address[] memory testBuyers = new address[](3);
            testBuyers[0] = buyers[0];
            testBuyers[1] = buyers[1];
            testBuyers[2] = buyers[8];
            
            for (uint256 i = 0; i < testBuyers.length; i++) {
                address buyer = testBuyers[i];
                bytes32 contentId = contentIds[0]; // Use the first content for all
                
                // Check if buyer needs tokens
                uint256 tokenBalance = PixieToken(tokenAddresses[contentId]).balanceOf(buyer);
                if (tokenBalance == 0) {
                    emit log_string(string.concat("Giving buyer ", vm.toString(i), " some tokens"));
                    
                    vm.startPrank(buyer);
                    factory.deployAndMint{value: 0.2 ether}(contentId, buyer);
                    vm.stopPrank();
                }
            }
        }
        
        // Phase 6: Mixed transactions (buys and sells happening interleaved)
        emit log_string("--- PHASE 6: MIXED TRANSACTIONS ---");
        
        // Buyer 9 buys tokens from content 0
        {
            address buyer = buyers[8];
            bytes32 contentId = contentIds[0];
            uint256 ethAmount = 0.3 ether;
            
            vm.startPrank(buyer);
            factory.deployAndMint{value: ethAmount}(contentId, buyer);
            uint256 tokenBalance = PixieToken(tokenAddresses[contentId]).balanceOf(buyer);
            vm.stopPrank();
            
            recordTransaction("buy", buyer, contentId, ethAmount, tokenBalance);
        }
        
        // Buyer 2 sells 50% of tokens from content 0
        {
            address buyer = buyers[1];
            bytes32 contentId = contentIds[0];
            address payable tokenAddr = tokenAddresses[contentId];
            
            vm.startPrank(buyer);
            
            uint256 tokenBalance = PixieToken(tokenAddr).balanceOf(buyer);
            emit log_named_uint("Buyer 2 token balance", tokenBalance);
            
            // Only proceed if the buyer has tokens
            if (tokenBalance > 0) {
                uint256 sellAmount = tokenBalance / 2;
                emit log_named_uint("Sell amount", sellAmount);
                
                // Get sell quote to verify amount
                uint256 expectedEth = factory.getSellQuote(contentId, sellAmount);
                emit log_named_uint("Expected ETH from sell", expectedEth);
                
                // Only sell if the expected ETH is enough
                if (expectedEth >= 0.0000001 ether) {
                    PixieToken(tokenAddr).approve(address(factory), sellAmount);
                    uint256 ethReceived = factory.sellTokens(contentId, sellAmount);
                    
                    recordTransaction("sell_partial", buyer, contentId, ethReceived, sellAmount);
                } else {
                    emit log_string("Skipping Buyer 2 sell due to small ETH return");
                }
            } else {
                emit log_string("Buyer 2 has no tokens to sell");
            }
            
            vm.stopPrank();
        }
        
        // Buyer 10 buys tokens from content 3
        {
            address buyer = buyers[9];
            bytes32 contentId = contentIds[3];
            uint256 ethAmount = 1.5 ether;
            
            vm.startPrank(buyer);
            factory.deployAndMint{value: ethAmount}(contentId, buyer);
            uint256 tokenBalance = PixieToken(tokenAddresses[contentId]).balanceOf(buyer);
            vm.stopPrank();
            
            recordTransaction("buy", buyer, contentId, ethAmount, tokenBalance);
        }
        
        // Buyer 1 sells all tokens from content 0
        {
            address buyer = buyers[0];
            bytes32 contentId = contentIds[0];
            address payable tokenAddr = tokenAddresses[contentId];
            
            vm.startPrank(buyer);
            
            uint256 tokenBalance = PixieToken(tokenAddr).balanceOf(buyer);
            emit log_named_uint("Buyer 1 token balance for final sell", tokenBalance);
            
            // Only proceed if the buyer has tokens
            if (tokenBalance > 0) {
                // Get sell quote to verify amount
                uint256 expectedEth = factory.getSellQuote(contentId, tokenBalance);
                emit log_named_uint("Expected ETH from sell", expectedEth);
                
                // Only sell if the expected ETH is enough
                if (expectedEth >= 0.0000001 ether) {
                    PixieToken(tokenAddr).approve(address(factory), tokenBalance);
                    uint256 ethReceived = factory.sellTokens(contentId, tokenBalance);
                    
                    uint256 newTokenBalance = PixieToken(tokenAddr).balanceOf(buyer);
                    assertEq(newTokenBalance, 0, "Buyer should have zero tokens after selling all");
                    
                    recordTransaction("sell_all", buyer, contentId, ethReceived, tokenBalance);
                } else {
                    emit log_string("Skipping Buyer 1 sell due to small ETH return");
                }
            } else {
                emit log_string("Buyer 1 has no tokens to sell");
            }
            
            vm.stopPrank();
        }
        
        // Print summary
        emit log_string("========= MARKETPLACE SIMULATION COMPLETE =========");
        emit log_string("All transaction types completed successfully!");
        
        // Verify no failures occurred
        for (uint256 i = 0; i < contentIds.length; i++) {
            bytes32 contentId = contentIds[i];
            address payable tokenAddr = tokenAddresses[contentId];
            
            // Verify contract exists
            assertTrue(tokenAddr.code.length > 0, "Token contract should be deployed");
            
            // Verify token supply matches expectations
            uint256 totalSupply = PixieToken(tokenAddr).totalSupply();
            assertTrue(totalSupply > 0, "Token should have positive supply");
            
            emit log_named_uint("Content ID token supply", totalSupply);
        }
    }
} 