// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {AchievementBoardImpl} from "../contracts/AchievementBoardImpl.sol";
import {AchievementBoard} from "../contracts/AchievementBoard.sol";

/**
 * @title AchievementBoard Upgrade Script
 * @notice Handles upgrades of AchievementBoard implementation
 * @dev Uses Create2 for deterministic deployment of new implementation
 */
contract AchievementBoardUpgrade is Script {
    /// @notice The Create2 salt used for deterministic deployment
    bytes32 public salt;

    /// @notice The proxy contract to upgrade
    address public proxyAddress;

    /**
     * @notice Sets up upgrade parameters
     * @dev Reads salt and proxy address from environment variables
     */
    function setUp() public {
        // Read salt from environment variable
        string memory saltString = vm.envString("ACHIEVEMENT_BOARD_SALT");
        salt = keccak256(bytes(saltString));

        // Read proxy address from environment variable
        proxyAddress = vm.envAddress("ACHIEVEMENT_BOARD_PROXY");
    }

    /**
     * @notice Computes the deterministic address for the new implementation
     * @param deployer The address that will deploy the contract
     * @return implAddr The computed implementation address
     */
    function computeImplementationAddress(address deployer) 
        public 
        view 
        returns (address implAddr) 
    {
        bytes memory implBytecode = type(AchievementBoardImpl).creationCode;
        implAddr = Create2.computeAddress(
            salt,
            keccak256(implBytecode),
            deployer
        );
    }

    /**
     * @notice Deploys new implementation and upgrades proxy
     * @return newImpl The newly deployed implementation contract
     */
    function run() public returns (AchievementBoardImpl newImpl) {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy new implementation with Create2
        newImpl = new AchievementBoardImpl{salt: salt}();

        // Get proxy interface
        AchievementBoardImpl proxy = AchievementBoardImpl(payable(proxyAddress));

        // Upgrade to new implementation
        proxy.upgradeTo(address(newImpl));

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log upgrade details
        console2.log("New implementation deployed at:", address(newImpl));
        console2.log("Proxy upgraded at:", proxyAddress);

        // Verify address matches computed address
        address expectedImpl = computeImplementationAddress(msg.sender);
        require(address(newImpl) == expectedImpl, "Implementation address mismatch");
    }
} 