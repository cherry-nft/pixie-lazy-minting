// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

contract UpgradeUrlsFactory is Script {
    address constant PROXY_ADDRESS = 0x5f1A00Bb3f2002AC4d48c7a14b3DcbC01e2AC958;
    address constant NEW_IMPLEMENTATION =
        0x54a33F76d9339ed62e6836Bb36702bD84504fEc4;

    function setUp() public {}

    function getImplementation(address proxy) internal view returns (address) {
        // Storage slot for implementation address in ERC1967
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

        // Get implementation address
        (bool success, bytes memory data) = proxy.staticcall(
            abi.encodeWithSignature("implementation()")
        );
        require(success, "Failed to get implementation");
        return abi.decode(data, (address));
    }

    function getOwner(address proxy) internal view returns (address) {
        (bool success, bytes memory data) = proxy.staticcall(
            abi.encodeWithSignature("owner()")
        );
        require(success, "Failed to get owner");
        return abi.decode(data, (address));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint(
            "DEPLOY_ALL_SCRIPT_PRIVATE_KEY"
        );
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Starting UrlsFactory upgrade...");
        console.log("Proxy address:", PROXY_ADDRESS);

        // Get current implementation
        address currentImpl = getImplementation(PROXY_ADDRESS);
        console.log("Current implementation [from chain]:", currentImpl);

        // Get owner and deployer
        address owner = getOwner(PROXY_ADDRESS);
        console.log("Contract owner [from chain]:", owner);
        console.log("Deployer address [our EOA]:", deployerAddress);

        console.log("New implementation [hardcoded]:", NEW_IMPLEMENTATION);

        // Encode the upgradeToAndCall function call
        bytes memory data = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            NEW_IMPLEMENTATION,
            ""
        );

        // Call the proxy
        (bool success, ) = PROXY_ADDRESS.call(data);
        require(success, "Upgrade failed");

        // Get new implementation to verify
        address newImpl = getImplementation(PROXY_ADDRESS);
        console.log("Implementation after upgrade [from chain]:", newImpl);
        require(
            newImpl == NEW_IMPLEMENTATION,
            "Implementation address mismatch"
        );

        console.log("Successfully upgraded UrlsFactory implementation");

        vm.stopBroadcast();
    }
}
