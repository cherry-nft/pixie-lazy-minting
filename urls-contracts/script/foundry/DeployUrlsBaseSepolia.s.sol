// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Urls} from "../../contracts/Urls.sol";
import {BondingCurve} from "../../contracts/BondingCurve.sol";
import {IUrls} from "../../contracts/interfaces/IUrls.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployUrlsBaseSepoliaScript is Script {
    // Base Sepolia contract addresses
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant NFT_POS_MGR =
        0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address public constant SWAP_ROUTER =
        0x0BE808376Ecb75a5CF9bB6D237d16cd37893d904;
    address public constant PROTOCOL_REWARDS =
        0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B;

    function setUp() public {}

    function run() public {
        // Get private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_BASE_SEPOLIA");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying with address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy bonding curve
        BondingCurve bondingCurve = new BondingCurve();
        console2.log("BondingCurve deployed at:", address(bondingCurve));

        // Deploy implementation contract
        Urls urlsImpl = new Urls(
            deployer, // protocol fee recipient
            deployer, // origin fee recipient
            PROTOCOL_REWARDS,
            WETH,
            NFT_POS_MGR,
            SWAP_ROUTER
        );
        console2.log("Urls implementation deployed at:", address(urlsImpl));

        // Initialize with proxy
        bytes memory initData = abi.encodeWithSelector(
            Urls.initialize.selector,
            deployer, // token creator
            deployer, // platform referrer
            deployer, // origin fee recipient
            address(bondingCurve),
            "test-uri",
            "Test Token",
            "TEST"
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(urlsImpl), initData);
        console2.log("Proxy deployed at:", address(proxy));

        vm.stopBroadcast();

        // Log all the important addresses
        console2.log("\nDeployment Summary:");
        console2.log("- BondingCurve:", address(bondingCurve));
        console2.log("- Implementation:", address(urlsImpl));
        console2.log("- Proxy:", address(proxy));
        console2.log("- WETH:", WETH);
        console2.log("- NFT Position Manager:", NFT_POS_MGR);
        console2.log("- Swap Router:", SWAP_ROUTER);
        console2.log("- Protocol Rewards:", PROTOCOL_REWARDS);
    }
}
