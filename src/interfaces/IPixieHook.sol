// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPixieHook
 * @notice Interface for Pixie Hook functions specific to the implementation
 */
interface IPixieHook {
    /**
     * @notice Set content ID (for testing)
     * @param _contentId Content ID
     */
    function setContentId(bytes32 _contentId) external;
} 