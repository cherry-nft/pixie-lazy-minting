// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ValidateSignatureScript is Script {
    using ECDSA for bytes32;

    // Test values
    bytes constant SIGNATURE =
        hex"0ef07c738df5d237f7c062e4db2992e3f9919e0b38b7ee7b829d0cefc005d2c760d766cf4438eeb09006250732a88a96a2214d448fc2c2e55ab963f4adf8017f1b";
    address constant TOKEN_CREATOR = 0x0000000000000000000000000000000000000123;
    string constant TOKEN_URI = "test_uri";
    address constant FEE_SIGNER = 0x2e988A386a799F506693793c6A5AF6B54dfAaBfB; // Address of the signer that created the test signature

    function run() external {
        // Copy-pasted from UrlsFactoryImpl._verifyFeeBypass
        bytes32 messageHash = keccak256(
            abi.encodePacked(TOKEN_CREATOR, TOKEN_URI)
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        address recoveredSigner = ECDSA.recover(
            ethSignedMessageHash,
            SIGNATURE
        );

        // Print debug info
        console.log("Message Hash:");
        console.logBytes32(messageHash);
        console.log("Eth Signed Message Hash:");
        console.logBytes32(ethSignedMessageHash);
        console.log("Recovered Signer: %s", recoveredSigner);
        console.log("Expected Signer: %s", FEE_SIGNER);
        console.log("Signature Valid: %s", recoveredSigner == FEE_SIGNER);
    }
}
