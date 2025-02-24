// scripts/deploy.ts
import { ethers } from "hardhat";

async function main() {
    console.log("Deploying Wow...");

    // Get the contract factory for "Wow"
    const Wow = await ethers.getContractFactory("Wow");

    // Define constructor parameters with actual addresses for Base Sepolia
    const protocolFeeRecipient: string = "0x96d9894371d8cf0C566F557bc8830F881E4D6c7a";
    const protocolRewards: string = "0x96d9894371d8cf0C566F557bc8830F881E4D6c7a";
    const weth: string = "0x999B45BB215209e567FaF486515af43b8353e393";
    const nonfungiblePositionManager: string = "0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2"; // Base Sepolia Uniswap V3 Nonfungible Position Manager
    const swapRouter: string = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4"; // Base Sepolia Uniswap V3 Swap Router

    // Deploy the contract as a standard (non-upgradeable) contract
    console.log("Deploying Wow contract...");
    const wow = await Wow.deploy(
        protocolFeeRecipient,
        protocolRewards,
        weth,
        nonfungiblePositionManager,
        swapRouter
    );

    // Wait for the deployment transaction to be mined
    await wow.waitForDeployment();
    console.log("Wow deployed to:", wow.target);
    console.log(`big thang: ${JSON.stringify(wow)}`);
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });
