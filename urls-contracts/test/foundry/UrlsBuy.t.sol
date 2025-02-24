// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BuyTest is Test {
    address constant TARGET = 0x30c07af8662791E2C98995a8521b129555E6BB63;
    address constant USER = 0x96d9894371d8cf0C566F557bc8830F881E4D6c7a;

    function setUp() public {
        // Fork Base Sepolia
        vm.createSelectFork(vm.rpcUrl("base_sepolia"));

        // Fund our test user with more ETH
        vm.deal(USER, 100 ether);

        // Log initial state
        console2.log("User ETH Balance:", USER.balance);
        console2.log("Target contract address:", TARGET);
        console2.log("Target contract balance:", TARGET.balance);
    }

    function test_buy() public {
        // Impersonate the user
        vm.startPrank(USER);

        // Log pre-call state
        console2.log("\nPre-call state:");
        console2.log("User ETH Balance:", USER.balance);

        // Prepare the buy call
        bytes memory callData = abi.encodeWithSignature(
            "buy(address,address,address,string,uint8,uint256,uint160)",
            USER, // recipient
            USER, // refundRecipient
            USER, // orderReferrer
            "test comment", // comment - using a simple string instead of an address
            0, // expectedMarketType
            1, // minOrderSize
            0 // sqrtPriceLimitX96
        );

        console2.log("\nCall data:");
        console2.logBytes(callData);

        // Make the call with more ETH
        (bool success, bytes memory data) = TARGET.call{value: 0.1 ether}(
            callData
        );

        // Log the result
        console2.log("\nCall result:");
        console2.log("Success:", success);
        if (!success) {
            console2.log("Error data:");
            console2.logBytes(data);

            // Try to decode standard revert reason if present
            if (data.length > 4) {
                bytes4 errorSelector = bytes4(data);
                console2.log("Error selector:", vm.toString(errorSelector));

                string memory revertReason = _getRevertMsg(data);
                if (bytes(revertReason).length > 0) {
                    console2.log("Revert reason:", revertReason);
                }
            }
        }

        // Log post-call state
        console2.log("\nPost-call state:");
        console2.log("User ETH Balance:", USER.balance);

        vm.stopPrank();
    }

    // Helper function to decode revert messages
    function _getRevertMsg(
        bytes memory _returnData
    ) internal pure returns (string memory) {
        // If the _returnData length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string));
    }
}
