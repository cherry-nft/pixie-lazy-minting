// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IAchievementBoard {
    /// @notice Struct to store achievement/score data
    struct Achievement {
        string messageType;
        uint256 messageValue;
        uint256 timestamp;
    }

    /**
     * @notice Event emitted when a new achievement is recorded
     * @param user The address of the user who achieved the score/achievement
     * @param urlAddress The contract address of the URL/game
     * @param messageType The type of achievement (e.g., "score")
     * @param messageValue The value associated with the achievement
     * @param timestamp When the achievement was recorded
     */
    event AchievementRecorded(
        address indexed user,
        address indexed urlAddress,
        string indexed messageType,
        uint256 messageValue,
        uint256 timestamp
    );

    /**
     * @notice Records a new achievement or score
     * @param messageType Type of the achievement (e.g., "score")
     * @param messageValue Value associated with the achievement
     * @param urlAddress Address of the URL/game contract
     */
    function recordAchievement(
        string calldata messageType,
        uint256 messageValue,
        address urlAddress
    ) external;

    /**
     * @notice Get all achievements for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return Achievement[] Array of achievements
     */
    function getAchievements(address user, address urlAddress)
        external
        view
        returns (Achievement[] memory);

    /**
     * @notice Get the high score for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return uint256 The highest score
     */
    function getHighScore(address user, address urlAddress)
        external
        view
        returns (uint256);

    /**
     * @notice Get the total number of submissions for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return uint256 The number of submissions
     */
    function getSubmissionCount(address user, address urlAddress)
        external
        view
        returns (uint256);

    /**
     * @notice Get the latest achievement for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return Achievement The latest achievement or revert if none exists
     */
    function getLatestAchievement(address user, address urlAddress)
        external
        view
        returns (Achievement memory);

    /**
     * @notice Get achievements by type for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @param messageType Type of achievement to filter by
     * @return Achievement[] Array of filtered achievements
     */
    function getAchievementsByType(
        address user,
        address urlAddress,
        string calldata messageType
    ) external view returns (Achievement[] memory);

    /// @notice The implementation address of the contract
    function implementation() external view returns (address);
} 