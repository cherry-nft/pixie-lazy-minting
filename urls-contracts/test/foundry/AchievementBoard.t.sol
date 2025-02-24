// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {AchievementBoardImpl} from "../../contracts/AchievementBoardImpl.sol";
import {AchievementBoard} from "../../contracts/AchievementBoard.sol";
import {MaliciousAchievement} from "./MaliciousAchievement.sol";

/**
 * @title AchievementBoardImpl Test Suite
 * @notice Comprehensive tests for the AchievementBoardImpl contract
 * @dev Tests initialization, achievement recording, and data retrieval
 */
contract AchievementBoardTest is Test {
    AchievementBoardImpl public implementation;
    AchievementBoard public proxy;
    AchievementBoardImpl public achievementBoard;

    address public owner;
    address public user1;
    address public user2;
    address public urlAddress1;
    address public urlAddress2;

    /**
     * @notice Set up the test environment
     * @dev Deploys contracts and sets up test addresses
     */
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        urlAddress1 = makeAddr("urlAddress1");
        urlAddress2 = makeAddr("urlAddress2");

        // Deploy implementation
        implementation = new AchievementBoardImpl();

        // Deploy proxy with implementation
        bytes memory initData = abi.encodeWithSelector(
            AchievementBoardImpl.initialize.selector,
            owner
        );
        proxy = new AchievementBoard(address(implementation), initData);

        // Create interface to proxy
        achievementBoard = AchievementBoardImpl(address(proxy));
    }

    /**
     * @notice Test contract initialization
     * @dev Verifies owner is set correctly and implementation is accessible
     */
    function test_initialization() public {
        assertEq(achievementBoard.owner(), owner);
        assertEq(achievementBoard.implementation(), address(implementation));
    }

    /**
     * @notice Test recording a single achievement
     * @dev Records achievement and verifies all related data
     */
    function test_recordSingleAchievement() public {
        vm.startPrank(user1);

        achievementBoard.recordAchievement("score", 100, urlAddress1);

        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements.length, 1);
        assertEq(achievements[0].messageType, "score");
        assertEq(achievements[0].messageValue, 100);
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 100);
        assertEq(achievementBoard.getSubmissionCount(user1, urlAddress1), 1);

        vm.stopPrank();
    }

    /**
     * @notice Test recording multiple achievements
     * @dev Verifies correct handling of multiple achievements for same user/URL
     */
    function test_recordMultipleAchievements() public {
        vm.startPrank(user1);

        // Record multiple scores
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        achievementBoard.recordAchievement("score", 200, urlAddress1);
        achievementBoard.recordAchievement("score", 150, urlAddress1);

        // Verify achievements
        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements.length, 3);
        assertEq(achievements[1].messageValue, 200);

        // Verify high score
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 200);

        // Verify submission count
        assertEq(achievementBoard.getSubmissionCount(user1, urlAddress1), 3);

        vm.stopPrank();
    }

    /**
     * @notice Test different achievement types
     * @dev Verifies handling of non-score achievements
     */
    function test_differentAchievementTypes() public {
        vm.startPrank(user1);

        // Record different types
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        achievementBoard.recordAchievement("achievement", 1, urlAddress1);
        achievementBoard.recordAchievement("milestone", 5, urlAddress1);

        // Get achievements by type
        AchievementBoardImpl.Achievement[]
            memory scoreAchievements = achievementBoard.getAchievementsByType(
                user1,
                urlAddress1,
                "score"
            );
        AchievementBoardImpl.Achievement[]
            memory milestoneAchievements = achievementBoard
                .getAchievementsByType(user1, urlAddress1, "milestone");

        assertEq(scoreAchievements.length, 1);
        assertEq(milestoneAchievements.length, 1);
        assertEq(scoreAchievements[0].messageValue, 100);
        assertEq(milestoneAchievements[0].messageValue, 5);

        vm.stopPrank();
    }

    /**
     * @notice Test multiple users and URLs
     * @dev Verifies isolation between different users and URLs
     */
    function test_multipleUsersAndUrls() public {
        // User 1 records for URL 1
        vm.prank(user1);
        achievementBoard.recordAchievement("score", 100, urlAddress1);

        // User 2 records for URL 1
        vm.prank(user2);
        achievementBoard.recordAchievement("score", 200, urlAddress1);

        // User 1 records for URL 2
        vm.prank(user1);
        achievementBoard.recordAchievement("score", 300, urlAddress2);

        // Verify isolation
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 100);
        assertEq(achievementBoard.getHighScore(user2, urlAddress1), 200);
        assertEq(achievementBoard.getHighScore(user1, urlAddress2), 300);
    }

    /**
     * @notice Test latest achievement retrieval
     * @dev Verifies getLatestAchievement returns correct achievement
     */
    function test_getLatestAchievement() public {
        vm.startPrank(user1);

        achievementBoard.recordAchievement("score", 100, urlAddress1);
        achievementBoard.recordAchievement("score", 200, urlAddress1);

        AchievementBoardImpl.Achievement memory latest = achievementBoard
            .getLatestAchievement(user1, urlAddress1);

        assertEq(latest.messageValue, 200);

        vm.stopPrank();
    }

    /**
     * @notice Test revert on no achievements
     * @dev Verifies getLatestAchievement reverts when no achievements exist
     */
    function testFail_getLatestAchievementNoAchievements() public {
        achievementBoard.getLatestAchievement(user1, urlAddress1);
    }

    /**
     * @notice Test unauthorized upgrade attempts
     * @dev Verifies only owner can upgrade
     */
    function testFail_unauthorizedUpgrade() public {
        vm.prank(user1); // Not the owner
        achievementBoard.upgradeTo(address(0x123));
    }

    /**
     * @notice Test zero address URL
     * @dev Verifies can't record achievements for zero address
     */
    function testFail_zeroAddressUrl() public {
        vm.prank(user1);
        achievementBoard.recordAchievement("score", 100, address(0));
    }

    /**
     * @notice Test recording many achievements (gas limit test)
     * @dev Records and verifies many achievements
     */
    function test_manyAchievements() public {
        vm.startPrank(user1);

        // Record 100 achievements
        for (uint i = 0; i < 100; i++) {
            achievementBoard.recordAchievement("score", i, urlAddress1);
        }

        // Verify data
        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements.length, 100);
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 99);

        vm.stopPrank();
    }

    /**
     * @notice Test retrieving achievements with many types
     * @dev Tests filtering with many different achievement types
     */
    function test_manyAchievementTypes() public {
        vm.startPrank(user1);

        // Record achievements with 50 different types
        for (uint i = 0; i < 50; i++) {
            string memory achievementType = string(
                abi.encodePacked("type", vm.toString(i))
            );
            achievementBoard.recordAchievement(achievementType, i, urlAddress1);
        }

        // Try to retrieve each type
        for (uint i = 0; i < 50; i++) {
            string memory achievementType = string(
                abi.encodePacked("type", vm.toString(i))
            );
            AchievementBoardImpl.Achievement[]
                memory achievements = achievementBoard.getAchievementsByType(
                    user1,
                    urlAddress1,
                    achievementType
                );
            assertEq(achievements.length, 1);
            assertEq(achievements[0].messageValue, i);
        }

        vm.stopPrank();
    }

    /**
     * @notice Test reentrancy protection
     * @dev Attempts to reenter recordAchievement
     */
    function testFail_reentrancy() public {
        // Deploy malicious contract that tries to reenter recordAchievement
        MaliciousAchievement malicious = new MaliciousAchievement(
            address(achievementBoard)
        );

        // Try to attack - this should revert due to nonReentrant modifier
        vm.expectRevert();
        vm.prank(address(malicious));
        achievementBoard.recordAchievement("score", 100, address(malicious));
    }

    /**
     * @notice Test timestamp manipulation
     * @dev Verifies behavior with different timestamps
     */
    function test_timestampManipulation() public {
        vm.startPrank(user1);

        // Try to manipulate timestamps
        vm.warp(1);
        achievementBoard.recordAchievement("score", 100, urlAddress1);

        vm.warp(block.timestamp + 365 days * 1000);
        achievementBoard.recordAchievement("score", 200, urlAddress1);

        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements[0].timestamp, 1);
        assertGt(achievements[1].timestamp, achievements[0].timestamp);

        vm.stopPrank();
    }

    /**
     * @notice Test string manipulation attacks
     * @dev Tests various string edge cases
     */
    function test_stringManipulation() public {
        vm.startPrank(user1);

        // Try unicode, special characters, etc.
        achievementBoard.recordAchievement(unicode"🎮", 100, urlAddress1);
        achievementBoard.recordAchievement("score\x00hidden", 100, urlAddress1);
        achievementBoard.recordAchievement(
            "<script>alert(1)</script>",
            100,
            urlAddress1
        );

        // Verify we can retrieve these
        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements.length, 3);

        vm.stopPrank();
    }

    /**
     * @notice Test successful upgrade
     * @dev Verifies upgrade process works correctly
     */
    function test_upgrade() public {
        // Deploy new implementation
        AchievementBoardImpl newImpl = new AchievementBoardImpl();

        // Upgrade
        vm.prank(owner);
        achievementBoard.upgradeTo(address(newImpl));

        // Verify upgrade
        assertEq(achievementBoard.implementation(), address(newImpl));

        // Verify functionality still works
        vm.prank(user1);
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 100);
    }

    /**
     * @notice Test upgrade with existing data
     * @dev Verifies data persists through upgrade
     */
    function test_upgradeWithExistingData() public {
        // Record some achievements
        vm.prank(user1);
        achievementBoard.recordAchievement("score", 100, urlAddress1);

        // Deploy new implementation
        AchievementBoardImpl newImpl = new AchievementBoardImpl();

        // Upgrade
        vm.prank(owner);
        achievementBoard.upgradeTo(address(newImpl));

        // Verify old data persists
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 100);
    }

    /**
     * @notice Test max values
     * @dev Tests behavior with maximum uint256 values
     */
    function test_maxValues() public {
        vm.startPrank(user1);

        // Test max uint256 value
        achievementBoard.recordAchievement(
            "score",
            type(uint256).max,
            urlAddress1
        );
        assertEq(
            achievementBoard.getHighScore(user1, urlAddress1),
            type(uint256).max
        );

        // Try to exceed max
        achievementBoard.recordAchievement(
            "score",
            type(uint256).max,
            urlAddress1
        );
        assertEq(
            achievementBoard.getHighScore(user1, urlAddress1),
            type(uint256).max
        );

        vm.stopPrank();
    }

    /**
     * @notice Test gas limits with long strings
     * @dev Tests behavior with long message types
     */
    function test_longStrings() public {
        vm.startPrank(user1);

        // Create a message type at max length (32 chars)
        string memory longType = new string(32);
        achievementBoard.recordAchievement(longType, 100, urlAddress1);

        // Verify we can retrieve it
        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements.length, 1);

        vm.stopPrank();
    }

    /**
     * @notice Test string length validation
     * @dev Should revert when string is too long
     */
    function testFail_tooLongString() public {
        vm.startPrank(user1);

        // Try to use a string that's too long (33 chars)
        string memory tooLongType = new string(33);
        achievementBoard.recordAchievement(tooLongType, 100, urlAddress1);

        vm.stopPrank();
    }

    /**
     * @notice Test batch recording of achievements
     * @dev Tests basic functionality of recordAchievements
     */
    function test_recordAchievementsBatch() public {
        vm.startPrank(user1);

        // Prepare test data
        string[] memory types = new string[](3);
        types[0] = "score";
        types[1] = "achievement";
        types[2] = "milestone";

        uint256[] memory values = new uint256[](3);
        values[0] = 100;
        values[1] = 1;
        values[2] = 5;

        address[] memory urls = new address[](3);
        urls[0] = urlAddress1;
        urls[1] = urlAddress1;
        urls[2] = urlAddress2;

        // Record batch achievements
        achievementBoard.recordAchievements(types, values, urls);

        // Verify URL1 data
        AchievementBoardImpl.Achievement[]
            memory achievements1 = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements1.length, 2);
        assertEq(achievements1[0].messageValue, 100);
        assertEq(achievements1[1].messageValue, 1);
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 100);
        assertEq(achievementBoard.getSubmissionCount(user1, urlAddress1), 2);

        // Verify URL2 data
        AchievementBoardImpl.Achievement[]
            memory achievements2 = achievementBoard.getAchievements(
                user1,
                urlAddress2
            );
        assertEq(achievements2.length, 1);
        assertEq(achievements2[0].messageValue, 5);
        assertEq(achievementBoard.getSubmissionCount(user1, urlAddress2), 1);

        vm.stopPrank();
    }

    /**
     * @notice Test batch recording with mismatched array lengths
     * @dev Should revert with appropriate error message
     */
    function testFail_recordAchievementsMismatchedArrays() public {
        string[] memory types = new string[](2);
        uint256[] memory values = new uint256[](3);
        address[] memory urls = new address[](2);

        vm.prank(user1);
        achievementBoard.recordAchievements(types, values, urls);
    }

    /**
     * @notice Test batch recording with empty arrays
     * @dev Should revert with appropriate error message
     */
    function testFail_recordAchievementsEmptyArrays() public {
        string[] memory types = new string[](0);
        uint256[] memory values = new uint256[](0);
        address[] memory urls = new address[](0);

        vm.prank(user1);
        achievementBoard.recordAchievements(types, values, urls);
    }

    /**
     * @notice Test batch recording with zero address
     * @dev Should revert with appropriate error message
     */
    function testFail_recordAchievementsZeroAddress() public {
        string[] memory types = new string[](1);
        types[0] = "score";

        uint256[] memory values = new uint256[](1);
        values[0] = 100;

        address[] memory urls = new address[](1);
        urls[0] = address(0);

        vm.prank(user1);
        achievementBoard.recordAchievements(types, values, urls);
    }

    /**
     * @notice Test batch recording with maximum array size
     * @dev Tests gas usage and functionality with max batch size
     */
    function test_recordAchievementsMaxBatch() public {
        vm.startPrank(user1);

        // Prepare max size arrays (100 items)
        string[] memory types = new string[](100);
        uint256[] memory values = new uint256[](100);
        address[] memory urls = new address[](100);

        // Fill arrays with test data
        for (uint i = 0; i < 100; i++) {
            types[i] = "score";
            values[i] = i * 100;
            urls[i] = makeAddr(string(abi.encodePacked("url", vm.toString(i))));
        }

        // Record batch
        achievementBoard.recordAchievements(types, values, urls);

        // Verify random samples
        assertEq(achievementBoard.getHighScore(user1, urls[0]), 0);
        assertEq(achievementBoard.getHighScore(user1, urls[50]), 5000);
        assertEq(achievementBoard.getHighScore(user1, urls[99]), 9900);

        vm.stopPrank();
    }

    /**
     * @notice Test batch recording exceeding maximum size
     * @dev Should revert with appropriate error message
     */
    function testFail_recordAchievementsExceedMaxBatch() public {
        string[] memory types = new string[](101); // Exceeds max of 100
        uint256[] memory values = new uint256[](101);
        address[] memory urls = new address[](101);

        vm.prank(user1);
        achievementBoard.recordAchievements(types, values, urls);
    }

    /**
     * @notice Test batch recording with duplicate URLs
     * @dev Verifies correct handling of multiple achievements for same URL
     */
    function test_recordAchievementsDuplicateUrls() public {
        vm.startPrank(user1);

        // Prepare test data with duplicate URLs
        string[] memory types = new string[](3);
        types[0] = "score";
        types[1] = "score";
        types[2] = "score";

        uint256[] memory values = new uint256[](3);
        values[0] = 100;
        values[1] = 200; // Higher score
        values[2] = 150; // Lower than previous

        address[] memory urls = new address[](3);
        urls[0] = urlAddress1;
        urls[1] = urlAddress1; // Same URL
        urls[2] = urlAddress1; // Same URL

        // Record batch
        achievementBoard.recordAchievements(types, values, urls);

        // Verify data
        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements.length, 3);
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 200);
        assertEq(achievementBoard.getSubmissionCount(user1, urlAddress1), 3);

        vm.stopPrank();
    }

    /**
     * @notice Test batch recording with mixed achievement types
     * @dev Verifies correct handling of different achievement types in batch
     */
    function test_recordAchievementsMixedTypes() public {
        vm.startPrank(user1);

        // Prepare test data with mixed types
        string[] memory types = new string[](5);
        types[0] = "score";
        types[1] = "achievement";
        types[2] = "score";
        types[3] = "milestone";
        types[4] = "score";

        uint256[] memory values = new uint256[](5);
        values[0] = 100;
        values[1] = 1;
        values[2] = 200;
        values[3] = 5;
        values[4] = 150;

        address[] memory urls = new address[](5);
        for (uint i = 0; i < 5; i++) {
            urls[i] = urlAddress1;
        }

        // Record batch
        achievementBoard.recordAchievements(types, values, urls);

        // Verify all achievements were recorded
        AchievementBoardImpl.Achievement[]
            memory achievements = achievementBoard.getAchievements(
                user1,
                urlAddress1
            );
        assertEq(achievements.length, 5);

        // Verify high score only considers "score" type
        assertEq(achievementBoard.getHighScore(user1, urlAddress1), 200);

        // Verify achievements by type
        AchievementBoardImpl.Achievement[] memory scores = achievementBoard
            .getAchievementsByType(user1, urlAddress1, "score");
        assertEq(scores.length, 3);

        AchievementBoardImpl.Achievement[] memory milestones = achievementBoard
            .getAchievementsByType(user1, urlAddress1, "milestone");
        assertEq(milestones.length, 1);

        vm.stopPrank();
    }

    /**
     * @notice Test getting achievements across multiple mApps
     * @dev Tests the getAchievementsByWalletAndmApps function
     */
    function test_getAchievementsByWalletAndmApps() public {
        // Setup test data
        vm.startPrank(user1);

        // Record achievements for URL1
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        achievementBoard.recordAchievement("achievement", 1, urlAddress1);

        // Record achievements for URL2
        achievementBoard.recordAchievement("score", 200, urlAddress2);
        achievementBoard.recordAchievement("milestone", 5, urlAddress2);

        vm.stopPrank();

        // Create array of URLs to query
        address[] memory urls = new address[](2);
        urls[0] = urlAddress1;
        urls[1] = urlAddress2;

        // Get achievements across both URLs
        (
            AchievementBoardImpl.Achievement[][] memory achievements,
            uint256[] memory highScores,
            uint256[] memory submissionCounts
        ) = achievementBoard.getAchievementsByWalletAndmApps(user1, urls);

        // Verify URL1 data
        assertEq(achievements[0].length, 2);
        assertEq(achievements[0][0].messageValue, 100);
        assertEq(achievements[0][1].messageValue, 1);
        assertEq(highScores[0], 100);
        assertEq(submissionCounts[0], 2);

        // Verify URL2 data
        assertEq(achievements[1].length, 2);
        assertEq(achievements[1][0].messageValue, 200);
        assertEq(achievements[1][1].messageValue, 5);
        assertEq(highScores[1], 200);
        assertEq(submissionCounts[1], 2);
    }

    /**
     * @notice Test getting achievements with empty URLs array
     * @dev Tests edge case of empty input array
     */
    function test_getAchievementsByWalletAndmAppsEmptyArray() public {
        address[] memory urls = new address[](0);

        (
            AchievementBoardImpl.Achievement[][] memory achievements,
            uint256[] memory highScores,
            uint256[] memory submissionCounts
        ) = achievementBoard.getAchievementsByWalletAndmApps(user1, urls);

        assertEq(achievements.length, 0);
        assertEq(highScores.length, 0);
        assertEq(submissionCounts.length, 0);
    }

    /**
     * @notice Test getting achievements for non-existent URLs
     * @dev Tests behavior with URLs that have no achievements
     */
    function test_getAchievementsByWalletAndmAppsNonexistentUrls() public {
        address[] memory urls = new address[](2);
        urls[0] = makeAddr("nonexistent1");
        urls[1] = makeAddr("nonexistent2");

        (
            AchievementBoardImpl.Achievement[][] memory achievements,
            uint256[] memory highScores,
            uint256[] memory submissionCounts
        ) = achievementBoard.getAchievementsByWalletAndmApps(user1, urls);

        assertEq(achievements.length, 2);
        assertEq(achievements[0].length, 0);
        assertEq(achievements[1].length, 0);
        assertEq(highScores[0], 0);
        assertEq(highScores[1], 0);
        assertEq(submissionCounts[0], 0);
        assertEq(submissionCounts[1], 0);
    }

    /**
     * @notice Test getting achievements with large number of URLs
     * @dev Tests gas usage with many URLs
     */
    function test_getAchievementsByWalletAndmAppsLargeArray() public {
        // Create and populate 50 URLs
        address[] memory urls = new address[](50);
        vm.startPrank(user1);

        for (uint i = 0; i < 50; i++) {
            urls[i] = makeAddr(string(abi.encodePacked("url", vm.toString(i))));
            achievementBoard.recordAchievement("score", i * 100, urls[i]);
        }

        vm.stopPrank();

        // Get achievements for all URLs
        (
            AchievementBoardImpl.Achievement[][] memory achievements,
            uint256[] memory highScores,
            uint256[] memory submissionCounts
        ) = achievementBoard.getAchievementsByWalletAndmApps(user1, urls);

        // Verify data
        assertEq(achievements.length, 50);
        for (uint i = 0; i < 50; i++) {
            assertEq(achievements[i].length, 1);
            assertEq(achievements[i][0].messageValue, i * 100);
            assertEq(highScores[i], i * 100);
            assertEq(submissionCounts[i], 1);
        }
    }

    /**
     * @notice Test gas costs for achievements at different counts
     * @dev Records achievements and measures gas costs at different milestones
     */
    function test_gasGrowth() public {
        vm.startPrank(user1);

        // Record first achievement and measure gas
        uint256 gasCostFirst = gasleft();
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        gasCostFirst = gasCostFirst - gasleft();

        // Record up to 250 achievements
        for (uint i = 0; i < 248; i++) {
            achievementBoard.recordAchievement("score", 100, urlAddress1);
        }
        uint256 gasCost250 = gasleft();
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        gasCost250 = gasCost250 - gasleft();

        // Record up to 500 achievements
        for (uint i = 0; i < 249; i++) {
            achievementBoard.recordAchievement("score", 100, urlAddress1);
        }
        uint256 gasCost500 = gasleft();
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        gasCost500 = gasCost500 - gasleft();

        // Record up to 750 achievements
        for (uint i = 0; i < 249; i++) {
            achievementBoard.recordAchievement("score", 100, urlAddress1);
        }
        uint256 gasCost750 = gasleft();
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        gasCost750 = gasCost750 - gasleft();

        // Record up to 1000 achievements
        for (uint i = 0; i < 249; i++) {
            achievementBoard.recordAchievement("score", 100, urlAddress1);
        }
        uint256 gasCost1000 = gasleft();
        achievementBoard.recordAchievement("score", 100, urlAddress1);
        gasCost1000 = gasCost1000 - gasleft();

        console2.log("Gas costs for achievements:");
        console2.log("1st achievement:", gasCostFirst);
        console2.log("250th achievement:", gasCost250);
        console2.log("500th achievement:", gasCost500);
        console2.log("750th achievement:", gasCost750);
        console2.log("1000th achievement:", gasCost1000);

        // Gas costs should be relatively constant since we're just pushing to an array
        assertApproxEqAbs(gasCost250, gasCost500, 1000);
        assertApproxEqAbs(gasCost500, gasCost750, 1000);
        assertApproxEqAbs(gasCost750, gasCost1000, 1000);

        vm.stopPrank();
    }
}
