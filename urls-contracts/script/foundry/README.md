# Foundry Deployment Guide

## Deploy to SpotlightSepolia

1. Create a .env file with your credentials:

```bash
HTTP_RPC_URL_SPOTLIGHT_SEPOLIA=your_rpc_url
PRIVATE_KEY_SPOTLIGHT_SEPOLIA=your_private_key
```

2. Source the environment:

```bash
source .env
```

3. Deploy with one command:

```bash
forge script script/foundry/DeployAll.s.sol \
    --rpc-url $HTTP_RPC_URL_SPOTLIGHT_SEPOLIA \
    --private-key $PRIVATE_KEY_SPOTLIGHT_SEPOLIA \
    --broadcast
```

```bash
forge script script/foundry/DeployAll.s.sol \
    --rpc-url $HTTP_RPC_URL_SPOTLIGHT_SEPOLIA \
    --private-key $PRIVATE_KEY_SPOTLIGHT_SEPOLIA \
    --broadcast
```

```bash
forge script script/foundry/DeployAll.s.sol \
    --rpc-url $HTTP_RPC_URL_BASE_SEPOLIA \
    --private-key $PRIVATE_KEY_BASE_SEPOLIA \
    --broadcast
```

```bash
forge script script/foundry/DeployAll.s.sol \
    --rpc-url $HTTP_RPC_URL_BASE_MAINNET \
    --private-key $PRIVATE_KEY_BASE_MAINNET \
    --broadcast
```

That's it! The script will deploy all contracts in sequence.

## Deploy to Anvil (Local)a

1. Start anvil:

```bash
anvil
```

2. Deploy:

```bash
forge script script/foundry/DeployAll.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```

---

$ forge script script/foundry/DeployAll.s.sol --rpc-url $HTTP_RPC_URL_SPOTLIGHT_SEPOLIA --private-key $PRIVATE_KEY_SPOTLIGHT_SEPOLIA --broadcast

```

forge script script/foundry/DeployAll.s.sol \
 --rpc-url $HTTP_RPC_URL_SEPOLIA \
 --private-key $PRIVATE_KEY_SEPOLIA \
 --broadcast

```
