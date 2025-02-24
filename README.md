# Pixie Lazy Minting

A smart contract implementation for lazy minting of ERC20 tokens in the Pixie platform, using Uniswap v4 hooks.

## Overview

This project implements a "lazy buying" mechanism for ERC20 tokens, where:

1. Content creators can register token metadata without deploying the actual token contract
2. The token contract is only deployed when the first purchase is made
3. The first buyer pays the gas cost for token deployment

This approach saves gas costs for creators and only deploys tokens that people actually want to buy.

## Use Case - Pixie Platform

Pixie is a social media platform similar to Instagram, but instead of likes, each post has its own ERC-20 token. The platform has:
- Creators posting hundreds of posts daily
- Tens of thousands of users signed up
- A need to avoid forcing creators to pay gas fees for token deployment, especially when many posts might never attract buyers

This lazy minting approach ensures that only posts with actual buyer interest result in deployed token contracts, with the first buyer naturally paying the deployment costs.

## Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Node.js](https://nodejs.org/) (optional, for scripts)
- An RPC endpoint for Base Sepolia

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd pixie-lazy-minting
```

2. Install dependencies:
```bash
forge install
```

3. Create a `.env` file based on `.env.example`:
```bash
cp .env.example .env
```

4. Fill in your private key and RPC URLs in the `.env` file.

## Testing

Run unit tests locally:
```bash
forge test
```

Run tests with verbosity for detailed output:
```bash
forge test -vvv
```

## Deploying to Base Sepolia

1. Deploy the core contracts:
```bash
forge script script/DeployLazyMinting.s.sol:DeployLazyMinting --rpc-url base_sepolia --broadcast --verify
```

2. Update your `.env` file with the deployed contract addresses.

3. Register a test token:
```bash
forge script script/DeployLazyMinting.s.sol:RegisterTestToken --rpc-url base_sepolia --broadcast
```

4. Execute a test swap to trigger lazy deployment:
```bash
forge script script/DeployLazyMinting.s.sol:ExecuteTestSwap --rpc-url base_sepolia --broadcast
```

## Contract Architecture

- **LazyTokenFactory**: Manages token metadata and handles lazy deployment
- **PixieToken**: The ERC20 token that gets deployed on first purchase
- **PixieHook**: Uniswap v4 hook that triggers token deployment on first swap
- **MockPoolManager**: A simplified version of Uniswap v4's PoolManager for testing
- **MockSwapRouter**: A router for executing swaps through the PoolManager

## Usage Flow

1. **Creator Registration**:
   - Creator submits content to Pixie
   - Backend registers token metadata via `LazyTokenFactory.registerToken()`
   - Backend calculates future token address via `getTokenAddress()`

2. **First Purchase**:
   - Buyer clicks "Buy" in Pixie UI
   - Pixie backend constructs a swap transaction
   - The swap triggers the hook's `beforeSwap` function
   - The hook deploys the token via `factory.deployToken()`
   - Token is minted to buyer, creator, and for liquidity

3. **Subsequent Purchases**:
   - Work normally through standard swap mechanisms
   - No special handling required

## Gas Considerations

- First buyer pays approximately 2-3x more gas than subsequent buyers
- Creator pays only for token metadata registration (very low gas cost)
- Subsequent purchases have standard gas costs

## License

MIT
