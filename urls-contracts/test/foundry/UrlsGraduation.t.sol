// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/Urls.sol";
import "../../contracts/BondingCurve.sol";
import "../../contracts/interfaces/IUrls.sol";

contract UrlsGraduationTest is Test {
    Urls public urls;
    BondingCurve public bondingCurve;
    address public constant URLS_ADDRESS = 0xa9b95A2Cff4B2931123063e72223DBE68Bf0Ab1E;
    
    function setUp() public {
        // Fork Base Sepolia at specific block
        vm.createSelectFork(vm.envString("HTTP_RPC_URL_BASE_SEPOLIA"), 18134662);
        
        // Get existing deployed contract
        urls = Urls(payable(URLS_ADDRESS));
        
        // Get bonding curve address from contract
        bondingCurve = BondingCurve(urls.bondingCurve());
        
        // Log initial state
        console.log("\n=== Initial Contract State ===");
        console.log("URLs Contract:", address(urls));
        console.log("Bonding Curve:", address(bondingCurve));
        console.log("Total Supply:", urls.totalSupply());
        console.log("Market Type:", uint256(urls.marketType()));
        console.log("Pool Address:", urls.poolAddress());
    }

    function test_graduateAndTrade() public {
        // Setup test accounts
        address buyer = makeAddr("buyer");
        vm.deal(buyer, 100 ether);
        
        console.log("\n=== Test Account Setup ===");
        console.log("Buyer Address:", buyer);
        console.log("Buyer Initial ETH:", buyer.balance / 1 ether, "ETH");

        // Switch to buyer context
        vm.startPrank(buyer);

        // Calculate remaining tokens to graduation
        uint256 currentSupply = urls.totalSupply();
        uint256 PRIMARY_MARKET_SUPPLY = 800_000_000e18; // From contract
        uint256 remainingToGraduation = PRIMARY_MARKET_SUPPLY - currentSupply;

        console.log("\n=== Pre-Graduation State ===");
        console.log("Current Supply:", currentSupply);
        console.log("Remaining to Graduation:", remainingToGraduation);

        // Get quote for remaining tokens with extra ETH to account for price impact
        uint256 ethNeeded = bondingCurve.getTokenBuyQuote(currentSupply, remainingToGraduation);
        uint256 ethWithPriceImpact = ethNeeded * 105 / 100; // Add 5% for price impact
        uint256 ethToSend = ethWithPriceImpact * 101 / 100; // Add 1% for fees

        console.log("ETH Needed for Graduation:", ethNeeded / 1 ether, "ETH");
        console.log("ETH with Price Impact:", ethWithPriceImpact / 1 ether, "ETH");
        console.log("ETH to Send (including fees):", ethToSend / 1 ether, "ETH");

        // Calculate minimum tokens to receive (allow 1% slippage)
        uint256 minTokensToReceive = remainingToGraduation * 99 / 100;

        // Execute graduation buy
        console.log("\n=== Executing Graduation Buy ===");
        console.log("Minimum Tokens Expected:", minTokensToReceive);
        console.log("Target Supply:", PRIMARY_MARKET_SUPPLY);
        console.log("Total Supply Before:", urls.totalSupply());
        
        urls.buy{value: ethToSend}(
            buyer,
            buyer,
            address(0),
            "Graduation Buy",
            IUrls.MarketType.BONDING_CURVE,
            minTokensToReceive,
            0
        );

        console.log("\n=== Post-Buy State ===");
        console.log("Total Supply After:", urls.totalSupply());
        console.log("Total Supply Target:", PRIMARY_MARKET_SUPPLY);
        console.log("Supply Delta:", int256(urls.totalSupply()) - int256(PRIMARY_MARKET_SUPPLY));

        // Verify graduation
        console.log("\n=== Post-Graduation State ===");
        console.log("Market Type:", uint256(urls.marketType()));
        console.log("Pool Address:", urls.poolAddress());
        console.log("Buyer Token Balance:", urls.balanceOf(buyer));
        console.log("Total Supply:", urls.totalSupply());

        // Require graduation before testing trades
        require(urls.marketType() == IUrls.MarketType.UNISWAP_POOL, "Market did not graduate");

        // Test post-graduation trading through contract
        console.log("\n=== Testing Post-Graduation Trading ===");
        
        // Try to buy through contract
        uint256 postGradBuyAmount = 1 ether;
        console.log("\nExecuting post-graduation buy:");
        console.log("ETH Amount:", postGradBuyAmount / 1 ether, "ETH");
        
        uint256 preBalance = urls.balanceOf(buyer);
        
        // Get expected tokens out from bonding curve as estimate
        uint256 expectedTokens = bondingCurve.getEthBuyQuote(urls.totalSupply(), postGradBuyAmount * 99 / 100); // Accounting for 1% fee
        uint256 minTokensOut = expectedTokens * 95 / 100; // Allow 5% slippage for Uniswap

        urls.buy{value: postGradBuyAmount}(
            buyer,
            buyer,
            address(0),
            "Post Graduation Buy",
            IUrls.MarketType.UNISWAP_POOL,
            minTokensOut,
            0  // No price limit
        );
        
        uint256 postBalance = urls.balanceOf(buyer);
        uint256 tokensBought = postBalance - preBalance;
        console.log("Tokens Bought:", tokensBought);
        console.log("Minimum Expected:", minTokensOut);

        // Try to sell through contract
        console.log("\nExecuting post-graduation sell:");
        uint256 tokensToSell = tokensBought / 2; // Sell half of what we just bought
        console.log("Tokens to Sell:", tokensToSell);
        
        // Get expected ETH out from bonding curve as estimate
        uint256 expectedEth = bondingCurve.getTokenSellQuote(urls.totalSupply(), tokensToSell);
        uint256 minEthOut = expectedEth * 50 / 100; // Allow 50% slippage for Uniswap
        
        urls.approve(address(urls), tokensToSell);
        uint256 preEthBalance = buyer.balance;
        urls.sell(
            tokensToSell,
            buyer,
            address(0),
            "Post Graduation Sell",
            IUrls.MarketType.UNISWAP_POOL,
            minEthOut,
            0  // No price limit
        );
        
        uint256 ethReceived = buyer.balance - preEthBalance;
        console.log("ETH Received:", ethReceived, "WEI");
        console.log("Minimum Expected:", minEthOut, "WEI");
        console.log("Final Token Balance:", urls.balanceOf(buyer));

        vm.stopPrank();
    }
}
