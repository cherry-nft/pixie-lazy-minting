// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Urls} from "../../contracts/Urls.sol";
import {BondingCurve} from "../../contracts/BondingCurve.sol";
import {UrlsFactoryImpl} from "../../contracts/UrlsFactoryImpl.sol";
import {UrlsFactory} from "../../contracts/UrlsFactory.sol";
import "forge-std/console.sol";

contract DeployAll is Script {
    uint256 deployerPrivateKey = vm.envUint("DEPLOY_ALL_SCRIPT_PRIVATE_KEY");

    // Known addresses for base sepolia
    address constant PROTOCOL_FEE_RECIPIENT =
        0x97a027C65e52D8617E69770A782D638585F521eb;

    address constant ORIGIN_FEE_RECIPIENT =
        0xd95BAcBED43F3Ad75Ab3A162AA09eaA442cf9453;

    // zora protocol rewards
    // base sepolia: 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B
    // base mainnet: 0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B
    address constant PROTOCOL_REWARDS =
        0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B;

    // base sepolia: 0x4200000000000000000000000000000000000006
    // base mainnet: 0x4200000000000000000000000000000000000006
    address constant WETH = 0x4200000000000000000000000000000000000006;

    // base sepolia: 0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2
    // base mainnet: 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
    address constant NONFUNGIBLE_POSITION_MANAGER =
        0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;

    // base sepolia: 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4
    // base mainnet: 0x2626664c2603336E57B271c5C0b26F421741e481
    address constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;

    function setUp() public {}

    // Helper function to convert address to string
    function addressToString(
        address _addr
    ) public pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(
                uint8(uint(uint160(_addr)) / (2 ** (8 * (19 - i))))
            );
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string.concat("0x", string(s));
    }

    function char(bytes1 b) public pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function run() public {
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        console.log("Starting deployment sequence...");

        // 1. Deploy Urls implementation
        console.log("Deploying Urls implementation...");
        Urls urlsImpl = new Urls(
            PROTOCOL_FEE_RECIPIENT,
            ORIGIN_FEE_RECIPIENT,
            PROTOCOL_REWARDS,
            WETH,
            NONFUNGIBLE_POSITION_MANAGER,
            SWAP_ROUTER
        );
        console.log("Urls implementation deployed to:", address(urlsImpl));

        // 2. Deploy BondingCurve
        console.log("Deploying BondingCurve...");
        BondingCurve bondingCurve = new BondingCurve();
        console.log("BondingCurve deployed to:", address(bondingCurve));

        // 3. Deploy UrlsFactoryImpl
        console.log("Deploying UrlsFactoryImpl...");
        UrlsFactoryImpl factoryImpl = new UrlsFactoryImpl(
            address(urlsImpl),
            address(bondingCurve)
        );
        console.log("UrlsFactoryImpl deployed to:", address(factoryImpl));

        // 4. Deploy UrlsFactory proxy
        console.log("Deploying UrlsFactory proxy...");
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address)",
            deployer
        );
        UrlsFactory proxy = new UrlsFactory(address(factoryImpl), initData);
        console.log("UrlsFactory proxy deployed to:", address(proxy));

        // Set the fee signer
        address feeSigner = vm.envAddress("URLS_DEPLOY_SIGNER_ADDRESS");
        console.log("Setting fee signer to:", feeSigner);
        UrlsFactoryImpl(address(proxy)).updateFeeSigner(feeSigner);
        console.log("Fee signer set successfully");

        // Log deployment summary
        console.log("\nDeployment Summary:");
        console.log("--------------------");
        console.log("Urls Implementation:", address(urlsImpl));
        console.log("BondingCurve:", address(bondingCurve));
        console.log("UrlsFactoryImpl:", address(factoryImpl));
        console.log("UrlsFactory Proxy:", address(proxy));

        // Get chain-specific verification details from environment
        uint256 chainId = vm.envUint("DEPLOY_ALL_SCRIPT_CHAIN_ID");
        string memory verifierUrl = vm.envString(
            "DEPLOY_ALL_SCRIPT_VERIFIER_URL"
        );

        // Log verification commands
        console.log("\nVerification Commands:");
        console.log("----------------------");

        // Create the verification strings with chain-id and blockscout verifier
        string memory verifyBondingCurve = string.concat(
            "forge verify-contract ",
            addressToString(address(bondingCurve)),
            " BondingCurve --watch --chain-id ",
            vm.toString(chainId),
            " --verifier-url ",
            verifierUrl,
            " --verifier blockscout"
        );

        string memory verifyFactoryImpl = string.concat(
            "forge verify-contract ",
            addressToString(address(factoryImpl)),
            " UrlsFactoryImpl --watch --chain-id ",
            vm.toString(chainId),
            " --verifier-url ",
            verifierUrl,
            " --verifier blockscout"
        );

        string memory verifyProxy = string.concat(
            "forge verify-contract ",
            addressToString(address(proxy)),
            " UrlsFactory --watch --chain-id ",
            vm.toString(chainId),
            " --verifier-url ",
            verifierUrl,
            " --verifier blockscout"
        );

        // Then log them all at once
        console.log(verifyBondingCurve);
        console.log(verifyFactoryImpl);
        console.log(verifyProxy);

        vm.stopBroadcast();
    }
}
