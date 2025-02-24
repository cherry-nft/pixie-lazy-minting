#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SALT=${ACHIEVEMENT_BOARD_SALT:-""}
PROXY=${ACHIEVEMENT_BOARD_PROXY:-""}
NETWORK=${NETWORK:-"sepolia"}
RPC_URL=${RPC_URL:-""}

# Print header
echo -e "${BLUE}=== AchievementBoard Upgrade Script ===${NC}\n"

# Validate required parameters
if [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: RPC_URL is required${NC}"
    echo "Please set the RPC_URL environment variable"
    echo "Example: RPC_URL=https://sepolia.infura.io/v3/your-api-key"
    exit 1
fi

if [ -z "$SALT" ]; then
    echo -e "${RED}Error: ACHIEVEMENT_BOARD_SALT is required${NC}"
    echo "Please set the ACHIEVEMENT_BOARD_SALT environment variable"
    echo "This must match the salt used in the original deployment"
    exit 1
fi

if [ -z "$PROXY" ]; then
    echo -e "${RED}Error: ACHIEVEMENT_BOARD_PROXY is required${NC}"
    echo "Please set the ACHIEVEMENT_BOARD_PROXY environment variable"
    echo "This should be the address of the proxy contract from the original deployment"
    exit 1
fi

# Print and confirm upgrade parameters
echo -e "${YELLOW}Upgrade Parameters:${NC}"
echo -e "Network: ${GREEN}$NETWORK${NC}"
echo -e "Salt: ${GREEN}$SALT${NC}"
echo -e "Proxy Address: ${GREEN}$PROXY${NC}"
echo -e "RPC URL: ${GREEN}$RPC_URL${NC}\n"

# Prompt for confirmation
echo -e "${RED}WARNING: This will upgrade the implementation contract.${NC}"
echo -e "${RED}Make sure you have tested the new implementation thoroughly.${NC}"
read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Upgrade cancelled${NC}"
    exit 1
fi

echo -e "\n${BLUE}Starting upgrade process...${NC}"

# Build contracts
echo -e "\n${YELLOW}Building contracts...${NC}"
forge build
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi
echo -e "${GREEN}Build successful${NC}"

# Set up upgrade command
UPGRADE_CMD="forge script script/AchievementBoardUpgrade.s.sol:AchievementBoardUpgrade"
UPGRADE_CMD="$UPGRADE_CMD --rpc-url $RPC_URL"
UPGRADE_CMD="$UPGRADE_CMD --broadcast"
UPGRADE_CMD="$UPGRADE_CMD -vvvv"

# Export environment variables
export ACHIEVEMENT_BOARD_SALT=$SALT
export ACHIEVEMENT_BOARD_PROXY=$PROXY

echo -e "\n${YELLOW}Using salt: ${GREEN}$SALT${NC}"
echo -e "${YELLOW}Upgrading proxy at: ${GREEN}$PROXY${NC}"

# Run upgrade
echo -e "\n${BLUE}Executing upgrade...${NC}"
echo -e "${YELLOW}Command: ${NC}$UPGRADE_CMD\n"

eval $UPGRADE_CMD

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Upgrade failed${NC}"
    exit 1
fi

echo -e "\n${GREEN}Upgrade completed successfully!${NC}"
echo -e "${YELLOW}Please save the new implementation address displayed above${NC}"
echo -e "${YELLOW}You may need it for future reference${NC}"

# Verify upgrade
echo -e "\n${BLUE}Verifying upgrade...${NC}"
echo -e "${YELLOW}Please verify that the proxy is using the new implementation${NC}"
echo -e "${YELLOW}You can do this by calling the implementation() function on the proxy${NC}" 