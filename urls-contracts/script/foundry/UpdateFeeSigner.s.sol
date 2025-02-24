// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {UrlsFactoryImpl} from "../../contracts/UrlsFactoryImpl.sol";
import "forge-std/console.sol";

contract UpdateFeeSigner is Script {
    address constant PROXY_ADDRESS = 0x5f1A00Bb3f2002AC4d48c7a14b3DcbC01e2AC958;

    function setUp() public {}

    function getOwner(address proxy) internal view returns (address) {
        (bool success, bytes memory data) = proxy.staticcall(
            abi.encodeWithSignature("owner()")
        );
        require(success, "Failed to get owner");
        return abi.decode(data, (address));
    }

    function getFeeSigner(address proxy) internal view returns (address) {
        (bool success, bytes memory data) = proxy.staticcall(
            abi.encodeWithSignature("feeSigner()")
        );
        require(success, "Failed to get feeSigner");
        return abi.decode(data, (address));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint(
            "DEPLOY_ALL_SCRIPT_PRIVATE_KEY"
        );
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Starting UrlsFactory fee signer update...");
        console.log("Proxy address:", PROXY_ADDRESS);

        // Get owner and deployer
        address owner = getOwner(PROXY_ADDRESS);
        console.log("Contract owner [from chain]:", owner);
        console.log("Deployer address [our EOA]:", deployerAddress);
        require(owner == deployerAddress, "Not the owner");

        // Get current fee signer
        address currentFeeSigner = getFeeSigner(PROXY_ADDRESS);
        console.log("Current fee signer:", currentFeeSigner);

        // Get new fee signer from env
        address newFeeSigner = vm.envAddress("URLS_DEPLOY_SIGNER_ADDRESS");
        console.log("New fee signer:", newFeeSigner);

        // Update fee signer
        UrlsFactoryImpl(PROXY_ADDRESS).updateFeeSigner(newFeeSigner);

        // Verify the update
        address updatedFeeSigner = getFeeSigner(PROXY_ADDRESS);
        console.log("Updated fee signer [from chain]:", updatedFeeSigner);
        require(updatedFeeSigner == newFeeSigner, "Fee signer update failed");

        console.log("Successfully updated fee signer");

        vm.stopBroadcast();
    }
}
