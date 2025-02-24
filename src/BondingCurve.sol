// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title BondingCurve
 * @dev Implements an exponential bonding curve for Pixie tokens
 * Based on the formula y = A*e^(Bx) where:
 * - y is the price
 * - x is the token supply
 * - A and B are constants that determine the curve shape
 */
contract BondingCurve {
    using Math for uint256;

    error InsufficientLiquidity();

    // Bonding curve parameters
    // y = A*e^(Bx) where A and B are constants
    uint256 public immutable A = 1060848709; // Base price factor
    uint256 public immutable B = 4379701787; // Steepness factor

    // Precision constants for fixed-point math
    uint256 internal constant WAD = 1e18;

    /**
     * @dev Calculate tokens to sell given an ETH amount
     * @param currentSupply Current token supply
     * @param ethOrderSize ETH amount to receive
     * @return tokensToSell Number of tokens to sell
     */
    function getEthSellQuote(
        uint256 currentSupply,
        uint256 ethOrderSize
    ) external pure returns (uint256) {
        uint256 deltaY = ethOrderSize;
        uint256 x0 = currentSupply;
        
        // We simplify the calculation for gas efficiency
        // In real production code, you'd use a library like FixedPointMathLib
        // This is a simplified linear approximation
        uint256 price = getCurrentPrice(x0);
        uint256 tokensToSell = (deltaY * WAD) / price;
        
        return tokensToSell;
    }

    /**
     * @dev Calculate ETH received for selling tokens
     * @param currentSupply Current token supply
     * @param tokensToSell Number of tokens to sell
     * @return ethReceived Amount of ETH received
     */
    function getTokenSellQuote(
        uint256 currentSupply,
        uint256 tokensToSell
    ) external pure returns (uint256) {
        if (currentSupply < tokensToSell) revert InsufficientLiquidity();
        
        uint256 x0 = currentSupply;
        uint256 x1 = x0 - tokensToSell;
        
        // Simplified calculation using average price
        uint256 avgPrice = (getCurrentPrice(x0) + getCurrentPrice(x1)) / 2;
        uint256 ethReceived = (tokensToSell * avgPrice) / WAD;
        
        return ethReceived;
    }

    /**
     * @dev Calculate tokens received for buying with ETH
     * @param currentSupply Current token supply
     * @param ethOrderSize ETH amount to spend
     * @return tokensBought Number of tokens bought
     */
    function getEthBuyQuote(
        uint256 currentSupply,
        uint256 ethOrderSize
    ) external pure returns (uint256) {
        uint256 x0 = currentSupply;
        
        // Simplified calculation using current price
        uint256 price = getCurrentPrice(x0);
        uint256 tokensBought = (ethOrderSize * WAD) / price;
        
        return tokensBought;
    }

    /**
     * @dev Calculate ETH needed to buy tokens
     * @param currentSupply Current token supply
     * @param tokenOrderSize Number of tokens to buy
     * @return ethNeeded Amount of ETH needed
     */
    function getTokenBuyQuote(
        uint256 currentSupply,
        uint256 tokenOrderSize
    ) external pure returns (uint256) {
        uint256 x0 = currentSupply;
        uint256 x1 = x0 + tokenOrderSize;
        
        // Simplified calculation using average price
        uint256 avgPrice = (getCurrentPrice(x0) + getCurrentPrice(x1)) / 2;
        uint256 ethNeeded = (tokenOrderSize * avgPrice) / WAD;
        
        return ethNeeded;
    }
    
    /**
     * @dev Get current token price at a specific supply point
     * @param supply Current supply point
     * @return price Current token price in ETH (18 decimals)
     */
    function getCurrentPrice(uint256 supply) public pure returns (uint256) {
        // For simplicity, we use a simplified pricing curve
        // In production, you would implement the full formula: y = A*e^(Bx)
        // using proper fixed-point math libraries
        
        // This is a simple approximation: price starts low and increases with supply
        uint256 basePrice = 1e15; // 0.001 ETH initial price
        
        if (supply == 0) {
            return basePrice;
        }
        
        // Price increases with supply
        // This is a simple quadratic curve for demonstration
        return basePrice + ((supply * supply) / (1e36));
    }
} 