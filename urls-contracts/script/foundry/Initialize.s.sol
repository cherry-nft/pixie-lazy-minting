// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IUrls {
    function initialize(
        address _tokenCreator,
        address _platformReferrer,
        address _protocolFeeRecipient,
        address _bondingCurveAddress,
        string memory _tokenURI,
        string memory _name,
        string memory _symbol
    ) external payable;
}

contract InitializeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address token = 0xa55C407D6B1A75FBd836cf478E4Ca4D1295202b8;

        IUrls(token).initialize(
            0x5Ea370F8Af029bCEa37279A235441C744EdBcf90, // tokenCreator
            0x5Ea370F8Af029bCEa37279A235441C744EdBcf90, // platformReferrer
            address(0), // protocolFeeRecipient
            0x71bD694163372732731365C00FA8583Fe9ac80B1, // bondingCurveAddress
            "eyJuYW1lIjoiVVJMIFRva2VuIiwic3ltYm9sIjoiJFBVQjJGMkY0IiwiZGVzY3JpcHRpb24iOiIiLCJzdW1tYXJ5IjoiIiwid2Vic2l0ZUxpbmsiOiJodHRwczovL3VybHMuYXJ0IiwibnNmdyI6ZmFsc2UsInRpbWVzdGFtcCI6IjIwMjUtMDEtMDdUMjM6NDQ6MTIuNzQ1WiIsIm1ldGFkYXRhIjp7Im9wZW5ncmFwaCI6eyJ0aXRsZSI6IlVSTCBUb2tlbiIsImRlc2NyaXB0aW9uIjoiIiwiaW1hZ2UiOiJpcGZzOi8vZmFsc2UifX0sImltYWdlIjoiaXBmczovL2ZhbHNlIn0=", // tokenURI
            "URL Token", // name
            "$PUB2F2F4" // symbol
        );

        vm.stopBroadcast();
    }
}
