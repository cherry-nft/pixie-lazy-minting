// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

// -----------------------------------------------------------------------
// ______   _____    ___________     _____                        _____
// \     \  \    \   \          \   |\    \                  _____\    \
//  \    |  |    |    \    /\    \   \\    \                /    / \    |
//   |   |  |    |     |   \_\    |   \\    \              |    |  /___/|
//   |    \_/   /|     |      ___/     \|    | ______   ____\    \ |   ||
//   |\         \|     |      \  ____   |    |/      \ /    /\    \|___|/
//   | \         \__  /     /\ \/    \  /            ||    |/ \    \
//    \ \_____/\    \/_____/ |\______| /_____/\_____/||\____\ /____/|
//     \ |    |/___/||     | | |     ||      | |    ||| |   ||    | |
//      \|____|   | ||_____|/ \|_____||______|/|____|/ \|___||____|/
//            |___|/
// -----------------------------------------------------------------------
// -----------!!!              wow wow wow             !!!----------------
// -----------------------------------------------------------------------

contract AchievementBoardImpl is
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    /// @notice Maximum length for message type strings
    uint256 public constant MAX_MESSAGE_TYPE_LENGTH = 32;

    /// @notice Maximum items per page in queries
    uint256 public constant MAX_PAGE_SIZE = 50;

    /// @notice Maximum achievements per user/URL pair
    uint256 public constant MAX_ACHIEVEMENTS_PER_URL = 100000;

    /// @notice Struct to store achievement/score data
    struct Achievement {
        string messageType;
        uint256 messageValue;
        uint256 timestamp;
    }

    /// @notice Struct for pagination metadata
    struct PaginationInfo {
        uint256 total;
        uint256 offset;
        uint256 limit;
        bool hasMore;
    }

    /// @notice Mapping from user address to URL address to array of achievements
    mapping(address => mapping(address => Achievement[])) public achievements;

    /// @notice Mapping to track highest score per user per URL
    mapping(address => mapping(address => uint256)) public highScores;

    /// @notice Mapping to track total submissions per user per URL
    mapping(address => mapping(address => uint256)) public submissionCounts;

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

    // Custom errors
    error MessageTypeTooLong(uint256 length, uint256 maxLength);
    error InvalidPagination(uint256 offset, uint256 limit, uint256 maxLimit);
    error AchievementLimitReached(
        address user,
        address urlAddress,
        uint256 limit
    );
    error InvalidURL();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the achievement board contract
     * @param _owner Address of the contract owner
     * @dev Can only be called once due to initializer modifier
     */
    function initialize(address _owner) external initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
    }

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
    ) external nonReentrant {
        // Validate URL
        if (urlAddress == address(0)) revert InvalidURL();

        // Validate string length
        uint256 typeLength = bytes(messageType).length;
        if (typeLength > MAX_MESSAGE_TYPE_LENGTH || typeLength == 0) {
            revert MessageTypeTooLong(typeLength, MAX_MESSAGE_TYPE_LENGTH);
        }

        // Check array bounds
        if (
            achievements[msg.sender][urlAddress].length >=
            MAX_ACHIEVEMENTS_PER_URL
        ) {
            revert AchievementLimitReached(
                msg.sender,
                urlAddress,
                MAX_ACHIEVEMENTS_PER_URL
            );
        }

        Achievement memory newAchievement = Achievement({
            messageType: messageType,
            messageValue: messageValue,
            timestamp: block.timestamp
        });

        // Store the achievement
        achievements[msg.sender][urlAddress].push(newAchievement);

        // Update submission count
        submissionCounts[msg.sender][urlAddress]++;

        // Update high score if applicable and if it's a score type
        if (
            keccak256(bytes(messageType)) == keccak256(bytes("score")) &&
            messageValue > highScores[msg.sender][urlAddress]
        ) {
            highScores[msg.sender][urlAddress] = messageValue;
        }

        // Emit event
        emit AchievementRecorded(
            msg.sender,
            urlAddress,
            messageType,
            messageValue,
            block.timestamp
        );
    }

    /**
     * @notice Records multiple achievements in a single transaction
     * @dev Batch version of recordAchievement for gas optimization
     * @param messageTypes Array of achievement types
     * @param messageValues Array of achievement values
     * @param urlAddresses Array of mApp addresses
     * @custom:security nonReentrant to prevent reentrancy attacks
     * @custom:events Emits AchievementRecorded for each achievement
     */
    function recordAchievements(
        string[] calldata messageTypes,
        uint256[] calldata messageValues,
        address[] calldata urlAddresses
    ) external nonReentrant {
        // Input validation
        require(
            messageTypes.length == messageValues.length &&
                messageTypes.length == urlAddresses.length,
            "Array lengths must match"
        );
        require(messageTypes.length > 0, "Empty arrays not allowed");
        require(messageTypes.length <= 100, "Max 100 achievements per batch");

        // Process each achievement
        for (uint256 i = 0; i < messageTypes.length; i++) {
            require(urlAddresses[i] != address(0), "Invalid URL address");

            Achievement memory newAchievement = Achievement({
                messageType: messageTypes[i],
                messageValue: messageValues[i],
                timestamp: block.timestamp
            });

            // Store the achievement
            achievements[msg.sender][urlAddresses[i]].push(newAchievement);

            // Update submission count
            submissionCounts[msg.sender][urlAddresses[i]]++;

            // Update high score if applicable and if it's a score type
            if (
                keccak256(bytes(messageTypes[i])) ==
                keccak256(bytes("score")) &&
                messageValues[i] > highScores[msg.sender][urlAddresses[i]]
            ) {
                highScores[msg.sender][urlAddresses[i]] = messageValues[i];
            }

            // Emit event
            emit AchievementRecorded(
                msg.sender,
                urlAddresses[i],
                messageTypes[i],
                messageValues[i],
                block.timestamp
            );
        }
    }

    /**
     * @notice Get all achievements for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return Achievement[] Array of achievements
     */
    function getAchievements(
        address user,
        address urlAddress
    ) external view returns (Achievement[] memory) {
        return achievements[user][urlAddress];
    }

    /**
     * @notice Get paginated achievements for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @param offset Starting position
     * @param limit Maximum items to return
     */
    function getAchievementsPaginated(
        address user,
        address urlAddress,
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (Achievement[] memory items, PaginationInfo memory pagination)
    {
        if (limit > MAX_PAGE_SIZE) {
            revert InvalidPagination(offset, limit, MAX_PAGE_SIZE);
        }

        Achievement[] storage allAchievements = achievements[user][urlAddress];
        uint256 total = allAchievements.length;

        if (offset >= total) {
            return (
                new Achievement[](0),
                PaginationInfo({
                    total: total,
                    offset: offset,
                    limit: limit,
                    hasMore: false
                })
            );
        }

        uint256 available = total - offset;
        if (available > limit) {
            available = limit;
        }

        items = new Achievement[](available);
        for (uint256 i = 0; i < available; i++) {
            items[i] = allAchievements[offset + i];
        }

        pagination = PaginationInfo({
            total: total,
            offset: offset,
            limit: limit,
            hasMore: (offset + available) < total
        });
    }

    /**
     * @notice Get the high score for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return uint256 The highest score
     */
    function getHighScore(
        address user,
        address urlAddress
    ) external view returns (uint256) {
        return highScores[user][urlAddress];
    }

    /**
     * @notice Get the total number of submissions for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return uint256 The number of submissions
     */
    function getSubmissionCount(
        address user,
        address urlAddress
    ) external view returns (uint256) {
        return submissionCounts[user][urlAddress];
    }

    /**
     * @notice Get the latest achievement for a user at a specific URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return Achievement The latest achievement or revert if none exists
     */
    function getLatestAchievement(
        address user,
        address urlAddress
    ) external view returns (Achievement memory) {
        Achievement[] storage userAchievements = achievements[user][urlAddress];
        require(userAchievements.length > 0, "No achievements found");
        return userAchievements[userAchievements.length - 1];
    }

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
    ) external view returns (Achievement[] memory) {
        Achievement[] storage allAchievements = achievements[user][urlAddress];
        uint256 count = 0;

        // First count matching achievements
        for (uint256 i = 0; i < allAchievements.length; i++) {
            if (
                keccak256(bytes(allAchievements[i].messageType)) ==
                keccak256(bytes(messageType))
            ) {
                count++;
            }
        }

        // Create and populate filtered array
        Achievement[] memory filtered = new Achievement[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allAchievements.length; i++) {
            if (
                keccak256(bytes(allAchievements[i].messageType)) ==
                keccak256(bytes(messageType))
            ) {
                filtered[index] = allAchievements[i];
                index++;
            }
        }

        return filtered;
    }

    /**
     * @notice Get achievements for a wallet across multiple mApp addresses
     * @param user The user's wallet address
     * @param urlAddresses Array of mApp addresses to query
     * @return achievements_ Array of arrays containing achievements for each mApp
     * @return highScores_ Array of high scores for each mApp
     * @return submissionCounts_ Array of submission counts for each mApp
     */
    function getAchievementsByWalletAndmApps(
        address user,
        address[] calldata urlAddresses
    )
        external
        view
        returns (
            Achievement[][] memory achievements_,
            uint256[] memory highScores_,
            uint256[] memory submissionCounts_
        )
    {
        // Initialize return arrays
        achievements_ = new Achievement[][](urlAddresses.length);
        highScores_ = new uint256[](urlAddresses.length);
        submissionCounts_ = new uint256[](urlAddresses.length);

        // Populate data for each mApp
        for (uint256 i = 0; i < urlAddresses.length; i++) {
            address urlAddress = urlAddresses[i];

            // Get achievements
            achievements_[i] = achievements[user][urlAddress];

            // Get high score
            highScores_[i] = highScores[user][urlAddress];

            // Get submission count
            submissionCounts_[i] = submissionCounts[user][urlAddress];
        }

        return (achievements_, highScores_, submissionCounts_);
    }

    /// @notice The implementation address of the contract
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @dev Authorizes an upgrade to a new implementation
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}

    /**
     * @notice Upgrades the implementation to a new address
     * @param newImplementation The address of the new implementation
     * @dev Can only be called by the owner
     */
    function upgradeTo(address newImplementation) external onlyOwner {
        _authorizeUpgrade(newImplementation);
        ERC1967Utils.upgradeToAndCall(newImplementation, new bytes(0));
    }

    /**
     * @notice Check if a user has reached achievement limit for a URL
     * @param user Address of the user
     * @param urlAddress Address of the URL/game contract
     * @return bool True if limit reached
     */
    function hasReachedAchievementLimit(
        address user,
        address urlAddress
    ) external view returns (bool) {
        return
            achievements[user][urlAddress].length >= MAX_ACHIEVEMENTS_PER_URL;
    }
}
