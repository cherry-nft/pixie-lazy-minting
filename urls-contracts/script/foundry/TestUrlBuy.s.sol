// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IUrls} from "../../contracts/interfaces/IUrls.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestUrlBuy is Script {
    // Already deployed contract on Base Sepolia
    address public constant URLS_CONTRACT =
        0x7dF884Be189dbb5E7AC0cC9B44c253BBEeA3368A;

    function setUp() public {}

    function run() public {
        // Get private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get contract interfaces
        IUrls urls = IUrls(payable(URLS_CONTRACT));
        IERC20 urlsErc20 = IERC20(URLS_CONTRACT);

        // Log initial state
        console2.log("Testing buy on contract:", URLS_CONTRACT);
        console2.log("Initial token balance:", urlsErc20.balanceOf(deployer));

        // Test buying tokens
        uint256 buyAmount = 0.1 ether;
        console2.log("\nTesting buy with", buyAmount, "ETH");

        // Calculate expected tokens and minimum acceptable amount
        uint256 fee = (buyAmount * 100) / 10000; // 1% fee
        uint256 ethAfterFee = buyAmount - fee;
        uint256 expectedTokens = urls.getEthBuyQuote(ethAfterFee);
        uint256 minTokens = (expectedTokens * 95) / 100; // Allow 5% slippage

        console2.log("Expected tokens:", expectedTokens);
        console2.log("Minimum acceptable tokens:", minTokens);
        console2.log("Fee amount:", fee);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Execute buy
        console2.log("\nCalling buy function...");
        urls.buy{value: buyAmount}(
            deployer,
            deployer,
            address(0),
            "",
            IUrls.MarketType.BONDING_CURVE,
            minTokens,
            0
        );

        // Log final state
        console2.log("\nFinal state:");
        console2.log("Token balance:", urlsErc20.balanceOf(deployer));

        vm.stopBroadcast();
    }
}
