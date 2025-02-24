# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```

## deploy notes

- deploy:

```
npx hardhat run scripts/deploy.ts --network spotlightSepolia
```

- verify:

```
$ npx hardhat verify --network spotlightSepolia 0x47572E9132730EFa75fd0a3916743a1273a980A4 0x96d9894371d8cf0C566F557bc8830F881E4D6c7a 0x96d9894371d8cf0C566F557bc8830F881E4D6c7a 0x999B45BB215209e567FaF486515af43b83
53e393 0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4
```

- implementation address for wowtoken: 0x47572E9132730EFa75fd0a3916743a1273a980A4

- deploy bondingcurve:

```
$ npx hardhat run scripts/deployBondingCurve.ts --network spotlightSepolia
WARNING: You are currently using Node.js v21.5.0, which is not supported by Hardhat. This can lead to unexpected behavior. See https://hardhat.org/nodejs-versions


Deploying BondingCurve...
Deploying implementation contract...
BondingCurve deployed to: 0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac
Deployment complete!

Verification command:
npx hardhat verify --network spotlightSepolia 0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac
alec@swerve:~/code/playground/wowtoken$ npx hardhat verify --network spotlightSepolia 0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac
WARNING: You are currently using Node.js v21.5.0, which is not supported by Hardhat. This can lead to unexpected behavior. See https://hardhat.org/nodejs-versions


Successfully submitted source code for contract
contracts/BondingCurve.sol:BondingCurve at 0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac
for verification on the block explorer. Waiting for verification result...

We tried verifying your contract BondingCurve without including any unrelated one, but it failed.
Trying again with the full solc input used to compile and deploy it.
This means that unrelated contracts may be displayed on Etherscan...

Successfully submitted source code for contract
contracts/BondingCurve.sol:BondingCurve at 0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac
for verification on the block explorer. Waiting for verification result...

hardhat-verify found one or more errors during the verification process:

Etherscan:
The contract verification failed.
Reason: Fail - Unable to verify


Sourcify:
Failed to send contract verification request.
Endpoint URL: https://sourcify.dev/server/check-all-by-addresses?addresses=0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac&chainIds=10058112
The HTTP server response is not ok. Status code: 500 Response text: {"error":"Invalid chainIds: 10058112","message":"Invalid chainIds: 10058112"}


```

- deploy wowfactory:

```
$ npx hardhat run scripts/deployFactory.ts --network spotlightSepolia
WARNING: You are currently using Node.js v21.5.0, which is not supported by Hardhat. This can lead to unexpected behavior. See https://hardhat.org/nodejs-versions


Deploying WowFactoryImpl...
Deploying implementation contract...
WowFactoryImpl deployed to: 0x0267EE74B80d089481863Ee6Ab04186e88A10ac0
Deployment complete!

Verification command:
npx hardhat verify --network spotlightSepolia 0x0267EE74B80d089481863Ee6Ab04186e88A10ac0 0x47572E9132730EFa75fd0a3916743a1273a980A4 0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac
alec@swerve:~/code/playground/wowtoken$ npx hardhat verify --network spotlightSepolia 0x0267EE74B80d089481863Ee6Ab04186e88A10ac0 0x47572E9132730EFa75fd0a3916743a1273a980A4 0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac
WARNING: You are currently using Node.js v21.5.0, which is not supported by Hardhat. This can lead to unexpected behavior. See https://hardhat.org/nodejs-versions


Verifying implementation: 0x0000000000000000000000000000000000000000
Failed to verify implementation contract at 0x0000000000000000000000000000000000000000: The address 0x0000000000000000000000000000000000000000 has no bytecode. Is the contract deployed to this network?
The selected network is spotlightSepolia.
Verifying beacon or beacon-like contract: 0x0267EE74B80d089481863Ee6Ab04186e88A10ac0
Successfully submitted source code for contract
contracts/WowFactoryImpl.sol:WowFactoryImpl at 0x0267EE74B80d089481863Ee6Ab04186e88A10ac0
for verification on the block explorer. Waiting for verification result...

Successfully verified contract WowFactoryImpl on the block explorer.
https://spotlight-sepolia.explorer.alchemy.com/address/0x0267EE74B80d089481863Ee6Ab04186e88A10ac0#code


Verification completed with the following warnings.

Warning 1: Failed to verify implementation contract at 0x0000000000000000000000000000000000000000: The address 0x0000000000000000000000000000000000000000 has no bytecode. Is the contract deployed to this network?
The selected network is spotlightSepolia.
hardhat-verify found one or more errors during the verification process:

Sourcify:
Failed to send contract verification request.
Endpoint URL: https://sourcify.dev/server/check-all-by-addresses?addresses=0x0267EE74B80d089481863Ee6Ab04186e88A10ac0&chainIds=10058112
The HTTP server response is not ok. Status code: 500 Response text: {"error":"Invalid chainIds: 10058112","message":"Invalid chainIds: 10058112"}

# AchievementBoard Deployment & Upgrade Guide

## Overview
The AchievementBoard contract uses a proxy pattern with deterministic deployment addresses through Create2. This ensures that the contract addresses are predictable and consistent across different networks.

## Deployment Process

### Understanding Create2 and Salt
The deployment uses Create2 for deterministic addresses. The address of a contract deployed with Create2 depends on:
1. The deployer's address
2. The salt (a unique value you provide)
3. The contract's bytecode

```bash
# Default salt
ACHIEVEMENT_BOARD_SALT="achievement.board.v1"

# Custom salt example
ACHIEVEMENT_BOARD_SALT="my.custom.salt.v1"
```

The same salt will generate the same addresses on any network when deployed from the same address. This is useful for:
- Cross-chain deployments
- Testing on different networks
- Verifying contract addresses before deployment

### How to Deploy

1. Basic deployment:
```bash
RPC_URL=https://sepolia.infura.io/v3/your-key ./script/deploy.sh
```

2. Custom deployment:
```bash
RPC_URL=https://sepolia.infura.io/v3/your-key \
ACHIEVEMENT_BOARD_SALT="my.custom.salt" \
ACHIEVEMENT_BOARD_OWNER="0x..." \
NETWORK="sepolia" \
./script/deploy.sh
```

The script will:
1. Validate parameters
2. Show deployment details for confirmation
3. Deploy implementation contract
4. Deploy proxy contract
5. Initialize the proxy
6. Output the addresses

**Important**: Save both the implementation and proxy addresses, and the salt used. You'll need these for upgrades.

## Upgrade Process

### Understanding the Upgrade
The AchievementBoard uses the UUPS (Universal Upgradeable Proxy Standard) pattern:
1. A new implementation is deployed
2. The proxy is told to point to the new implementation
3. The proxy's storage remains unchanged
4. All future calls use the new implementation's logic

### Why Testing is Critical
The upgrade warning exists because:
1. **Storage Collisions**: New implementations must maintain the same storage layout
2. **Function Changes**: Modified functions might affect existing integrations
3. **State Changes**: Upgrades can't modify existing storage
4. **No Rollback**: Upgrades are permanent unless another upgrade is performed

### How to Upgrade

1. Test thoroughly on a testnet first:
```bash
# Deploy to testnet
RPC_URL=https://sepolia.infura.io/v3/your-key ./script/deploy.sh

# Make changes to implementation

# Test upgrade on testnet
RPC_URL=https://sepolia.infura.io/v3/your-key \
ACHIEVEMENT_BOARD_SALT="original.deployment.salt" \
ACHIEVEMENT_BOARD_PROXY="0x..." \
./script/upgrade.sh
```

2. Upgrade on mainnet:
```bash
RPC_URL=https://ethereum.infura.io/v3/your-key \
ACHIEVEMENT_BOARD_SALT="original.deployment.salt" \
ACHIEVEMENT_BOARD_PROXY="0x..." \
./script/upgrade.sh
```

### Upgrade Safety Checklist
Before upgrading:
- [ ] Test new implementation thoroughly
- [ ] Verify storage layout is compatible
- [ ] Test upgrade process on testnet
- [ ] Verify all existing functionality works
- [ ] Check for any breaking changes
- [ ] Ensure you're using the correct salt
- [ ] Verify you have upgrade permissions

### Verifying the Upgrade
After upgrading:
1. Call `implementation()` on the proxy
2. Verify it returns the new implementation address
3. Test key functionality through the proxy
4. Monitor for any unexpected behavior

## Development Notes

### Storage Layout
When modifying the implementation:
- Never remove existing storage variables
- Only add new variables at the end
- Never change variable types
- Use storage gaps for future-proofing

### Testing
Run the test suite:
```bash
forge test
```

### Deployment Verification
You can pre-compute addresses:
```solidity
(address impl, address proxy) = deployer.computeAddresses(msg.sender);
```

This is useful for:
- Verifying addresses before deployment
- Setting up integration tests
- Cross-chain coordination
