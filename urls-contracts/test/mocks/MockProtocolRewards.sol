// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockProtocolRewards {
    function depositBatch(
        address[] memory recipients,
        uint256[] memory amounts,
        bytes4[] memory reasons,
        bytes memory
    ) external payable {
        // Mock implementation - just accept the ETH
    }
}
