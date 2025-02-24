// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {IUrls} from "../../contracts/interfaces/IUrls.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UrlsSellTest is Test {
    address constant URLS_CONTRACT = 0x3893e0F8460285BfC0DF3554A3AeF11dBCbF8a33;
    address constant SELLER = 0x96d9894371d8cf0C566F557bc8830F881E4D6c7a;
    
    IUrls urls;
    IERC20 urlsErc20;

    function setUp() public {
        // Fork Base Sepolia at the specified block
        vm.createSelectFork(vm.envString("HTTP_RPC_URL_BASE_SEPOLIA"), 18094127);
        
        // Set up contract interfaces
        urls = IUrls(payable(URLS_CONTRACT));
        urlsErc20 = IERC20(URLS_CONTRACT);

        // Impersonate the seller account
        vm.startPrank(SELLER);
    }

    function testSell() public {
        // Get current token balance
        uint256 initialBalance = urlsErc20.balanceOf(SELLER);
        console2.log("Initial token balance:", initialBalance);
        
        // Calculate amount to sell (90% of balance)
        uint256 amountToSell = (initialBalance * 90) / 100;
        console2.log("Amount to sell:", amountToSell);

        // Get sell quote to estimate payout
        uint256 expectedPayout = urls.getTokenSellQuote(amountToSell);
        console2.log("Expected payout:", expectedPayout);
        
        // Set minPayoutSize to 80% of expected payout (20% slippage tolerance)
        uint256 minPayoutSize = (expectedPayout * 80) / 100;
        console2.log("Minimum payout size:", minPayoutSize);

        // Execute sell
        uint256 actualPayout = urls.sell(
            amountToSell,
            SELLER,  // recipient
            address(0),  // no referrer
            "",  // no comment
            IUrls.MarketType.BONDING_CURVE,  // assuming bonding curve market
            minPayoutSize,
            0  // sqrtPriceLimitX96 (not used for bonding curve)
        );

        console2.log("Actual payout received:", actualPayout);
        console2.log("Final token balance:", urlsErc20.balanceOf(SELLER));
    }
}
