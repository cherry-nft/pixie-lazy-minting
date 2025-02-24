// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AchievementBoardImpl} from "../../contracts/AchievementBoardImpl.sol";

contract MaliciousAchievement {
    AchievementBoardImpl public achievementBoard;
    uint256 public attackCount;

    constructor(address _achievementBoard) {
        achievementBoard = AchievementBoardImpl(_achievementBoard);
    }

    function attack() external {
        achievementBoard.recordAchievement("score", 100, address(this));
    }

    // Fallback function that tries to reenter
    fallback() external {
        if (attackCount < 5) {  // Limit to prevent infinite loop in tests
            attackCount++;
            achievementBoard.recordAchievement("score", 100, address(this));
        }
    }

    receive() external payable {
        if (attackCount < 5) {  // Limit to prevent infinite loop in tests
            attackCount++;
            achievementBoard.recordAchievement("score", 100, address(this));
        }
    }
} 