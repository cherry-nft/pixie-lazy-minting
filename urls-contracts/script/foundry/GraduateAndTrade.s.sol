// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../contracts/Urls.sol";
import "../../contracts/BondingCurve.sol";
import "../../contracts/interfaces/IUrls.sol";

contract GraduateAndTradeScript is Script {
    Urls public urls;
    BondingCurve public bondingCurve;

    function setUp() public {}

    function run(address urlsAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable deployer = payable(vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        // Get contract instances
        urls = Urls(payable(urlsAddress));
        bondingCurve = BondingCurve(urls.bondingCurve());

        // Log initial state
        console.log("\n=== Initial Contract State ===");
        console.log("URLs Contract:", address(urls));
        console.log("Bonding Curve:", address(bondingCurve));
        console.log("Total Supply:", urls.totalSupply());
        console.log("Market Type:", uint256(urls.marketType()));
        console.log("Pool Address:", urls.poolAddress());

        // Calculate remaining tokens to graduation
        uint256 currentSupply = urls.totalSupply();
        uint256 PRIMARY_MARKET_SUPPLY = 800_000_000e18;
        uint256 remainingToGraduation = PRIMARY_MARKET_SUPPLY - currentSupply;

        console.log("\n=== Pre-Graduation State ===");
        console.log("Current Supply:", currentSupply);
        console.log("Remaining to Graduation:", remainingToGraduation);

        // Get quote and execute graduation buy if not already graduated
        if (urls.marketType() == IUrls.MarketType.BONDING_CURVE) {
            uint256 ethNeeded = bondingCurve.getTokenBuyQuote(
                currentSupply,
                remainingToGraduation
            );
            uint256 ethWithPriceImpact = (ethNeeded * 105) / 100;
            uint256 ethToSend = (ethWithPriceImpact * 101) / 100;

            console.log(
                "ETH Needed for Graduation:",
                ethNeeded / 1 ether,
                "ETH"
            );
            console.log("ETH to Send:", ethToSend / 1 ether, "ETH");

            uint256 minTokensToReceive = (remainingToGraduation * 99) / 100;

            urls.buy{value: ethToSend}(
                deployer,
                deployer,
                address(0),
                "Graduation Buy",
                IUrls.MarketType.BONDING_CURVE,
                minTokensToReceive,
                0
            );
        }

        // Verify graduation
        console.log("\n=== Post-Graduation State ===");
        console.log("Market Type:", uint256(urls.marketType()));
        console.log("Pool Address:", urls.poolAddress());
        console.log("Balance:", urls.balanceOf(deployer));

        require(
            urls.marketType() == IUrls.MarketType.UNISWAP_POOL,
            "Market did not graduate"
        );

        // Test post-graduation trading
        console.log("\n=== Testing Post-Graduation Trading ===");

        // Buy through contract
        uint256 postGradBuyAmount = 1 ether;
        console.log("\nExecuting post-graduation buy:");
        console.log("ETH Amount:", postGradBuyAmount / 1 ether, "ETH");

        uint256 preBalance = urls.balanceOf(deployer);
        uint256 expectedTokens = bondingCurve.getEthBuyQuote(
            urls.totalSupply(),
            (postGradBuyAmount * 99) / 100
        );
        uint256 minTokensOut = (expectedTokens * 95) / 100;

        urls.buy{value: postGradBuyAmount}(
            deployer,
            deployer,
            address(0),
            "Post Graduation Buy",
            IUrls.MarketType.UNISWAP_POOL,
            minTokensOut,
            0
        );

        uint256 postBalance = urls.balanceOf(deployer);
        uint256 tokensBought = postBalance - preBalance;
        console.log("Tokens Bought:", tokensBought);

        // Sell through contract
        console.log("\nExecuting post-graduation sell:");
        uint256 tokensToSell = tokensBought / 2;
        console.log("Tokens to Sell:", tokensToSell);

        uint256 expectedEth = bondingCurve.getTokenSellQuote(
            urls.totalSupply(),
            tokensToSell
        );
        uint256 minEthOut = (expectedEth * 50) / 100;

        urls.approve(address(urls), tokensToSell);
        uint256 preEthBalance = deployer.balance;

        urls.sell(
            tokensToSell,
            deployer,
            address(0),
            "Post Graduation Sell",
            IUrls.MarketType.UNISWAP_POOL,
            minEthOut,
            0
        );

        uint256 ethReceived = deployer.balance - preEthBalance;
        console.log("ETH Received:", ethReceived, "WEI");
        console.log("Final Token Balance:", urls.balanceOf(deployer));

        vm.stopBroadcast();
    }
}
