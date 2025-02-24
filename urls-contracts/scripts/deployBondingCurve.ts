import { ethers } from "hardhat";

async function main() {
    console.log("Deploying BondingCurve...");

    // Get the contract factory
    const BondingCurve = await ethers.getContractFactory("BondingCurve");

    // Deploy the contract
    console.log("Deploying implementation contract...");
    const bondingCurve = await BondingCurve.deploy();

    await bondingCurve.waitForDeployment();

    const deployedAddress = await bondingCurve.getAddress();
    console.log("BondingCurve deployed to:", deployedAddress);

    console.log("Deployment complete!");

    // Log the verification command
    console.log("\nVerification command:");
    console.log(`npx hardhat verify --network spotlightSepolia ${deployedAddress}`);
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    }); 