// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {AchievementBoardImpl} from "../contracts/AchievementBoardImpl.sol";
import {AchievementBoard} from "../contracts/AchievementBoard.sol";

/**
 * @title AchievementBoard Deployment Script
 * @notice Handles deterministic deployment of AchievementBoard contracts
 * @dev Uses Create2 for deterministic addresses
 */
contract AchievementBoardDeploy is Script {
    /// @notice The Create2 salt used for deterministic deployment
    bytes32 public salt;

    /// @notice The owner address that will be set during initialization
    address public owner;

    /**
     * @notice Sets up deployment parameters
     * @dev Reads salt and owner from environment variables
     */
    function setUp() public {
        // Read salt from environment variable, default to keccak256("achievement.board.v1")
        string memory saltString = vm.envOr(
            "ACHIEVEMENT_BOARD_SALT",
            string("achievement.board.v1")
        );
        salt = keccak256(bytes(saltString));

        // Read owner from environment variable, default to msg.sender
        owner = vm.envOr("ACHIEVEMENT_BOARD_OWNER", msg.sender);
    }

    /**
     * @notice Computes the deterministic addresses for implementation and proxy
     * @param deployer The address that will deploy the contracts
     * @return implAddr The computed implementation address
     * @return proxyAddr The computed proxy address
     */
    function computeAddresses(address deployer) 
        public 
        view 
        returns (address implAddr, address proxyAddr) 
    {
        bytes memory implBytecode = type(AchievementBoardImpl).creationCode;
        implAddr = Create2.computeAddress(
            salt,
            keccak256(implBytecode),
            deployer
        );

        bytes memory initData = abi.encodeWithSelector(
            AchievementBoardImpl.initialize.selector,
            owner
        );

        bytes memory proxyBytecode = abi.encodePacked(
            type(AchievementBoard).creationCode,
            abi.encode(implAddr, initData)
        );
        proxyAddr = Create2.computeAddress(
            salt,
            keccak256(proxyBytecode),
            deployer
        );
    }

    /**
     * @notice Deploys the implementation and proxy contracts
     * @return impl The deployed implementation contract
     * @return proxy The deployed proxy contract
     */
    function run() public returns (AchievementBoardImpl impl, AchievementBoard proxy) {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy implementation with Create2
        impl = new AchievementBoardImpl{salt: salt}();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            AchievementBoardImpl.initialize.selector,
            owner
        );

        // Deploy proxy with Create2
        proxy = new AchievementBoard{salt: salt}(
            address(impl),
            initData
        );

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log deployment addresses
        console2.log("Implementation deployed at:", address(impl));
        console2.log("Proxy deployed at:", address(proxy));

        // Verify addresses match computed addresses
        (address expectedImpl, address expectedProxy) = computeAddresses(msg.sender);
        require(address(impl) == expectedImpl, "Implementation address mismatch");
        require(address(proxy) == expectedProxy, "Proxy address mismatch");
    }
} 