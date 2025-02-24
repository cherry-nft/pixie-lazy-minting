// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {AchievementBoardImpl} from "../contracts/AchievementBoardImpl.sol";
import {AchievementBoard} from "../contracts/AchievementBoard.sol";

/**
 * @title AchievementBoardImpl Test Suite
 * @notice Comprehensive tests for the AchievementBoardImpl contract
 * @dev Tests initialization, achievement recording, and data retrieval
 */
contract AchievementBoardImplTest is Test {
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
        
        AchievementBoardImpl.Achievement[] memory achievements = achievementBoard.getAchievements(user1, urlAddress1);
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
        AchievementBoardImpl.Achievement[] memory achievements = achievementBoard.getAchievements(user1, urlAddress1);
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
        AchievementBoardImpl.Achievement[] memory scoreAchievements = 
            achievementBoard.getAchievementsByType(user1, urlAddress1, "score");
        AchievementBoardImpl.Achievement[] memory milestoneAchievements = 
            achievementBoard.getAchievementsByType(user1, urlAddress1, "milestone");
            
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
        
        AchievementBoardImpl.Achievement memory latest = 
            achievementBoard.getLatestAchievement(user1, urlAddress1);
            
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
} 