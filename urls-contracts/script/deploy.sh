#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SALT=${ACHIEVEMENT_BOARD_SALT:-"achievement.board.v1"}
OWNER=${ACHIEVEMENT_BOARD_OWNER:-""}
NETWORK=${NETWORK:-"sepolia"}
RPC_URL=${RPC_URL:-""}

# Print header
echo -e "${BLUE}=== AchievementBoard Deployment Script ===${NC}\n"

# Validate RPC URL
if [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: RPC_URL is required${NC}"
    echo "Please set the RPC_URL environment variable"
    echo "Example: RPC_URL=https://sepolia.infura.io/v3/your-api-key"
    exit 1
fi

# Print and confirm deployment parameters
echo -e "${YELLOW}Deployment Parameters:${NC}"
echo -e "Network: ${GREEN}$NETWORK${NC}"
echo -e "Salt: ${GREEN}$SALT${NC}"
echo -e "Owner: ${GREEN}${OWNER:-"<will use deployer address>"}"${NC}
echo -e "RPC URL: ${GREEN}$RPC_URL${NC}\n"

# Prompt for confirmation
read -p "Are these parameters correct? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Deployment cancelled${NC}"
    exit 1
fi

echo -e "\n${BLUE}Starting deployment...${NC}"

# Build contracts
echo -e "\n${YELLOW}Building contracts...${NC}"
forge build
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi
echo -e "${GREEN}Build successful${NC}"

# Set up deployment command
DEPLOY_CMD="forge script script/AchievementBoardDeploy.s.sol:AchievementBoardDeploy"
DEPLOY_CMD="$DEPLOY_CMD --rpc-url $RPC_URL"
DEPLOY_CMD="$DEPLOY_CMD --broadcast"
DEPLOY_CMD="$DEPLOY_CMD -vvvv"

# Add owner if specified
if [ ! -z "$OWNER" ]; then
    export ACHIEVEMENT_BOARD_OWNER=$OWNER
    echo -e "\n${YELLOW}Using specified owner: ${GREEN}$OWNER${NC}"
fi

# Set salt
export ACHIEVEMENT_BOARD_SALT=$SALT
echo -e "${YELLOW}Using salt: ${GREEN}$SALT${NC}"

# Run deployment
echo -e "\n${BLUE}Executing deployment...${NC}"
echo -e "${YELLOW}Command: ${NC}$DEPLOY_CMD\n"

eval $DEPLOY_CMD

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Deployment failed${NC}"
    exit 1
fi

echo -e "\n${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}Please save the implementation and proxy addresses displayed above${NC}"
echo -e "${YELLOW}You will need them for future upgrades${NC}" 