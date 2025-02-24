import { ethers } from "hardhat";

async function main() {
    console.log("Deploying WowFactoryImpl...");

    // Known addresses
    const wowImplementation = "0x47572E9132730EFa75fd0a3916743a1273a980A4";
    const bondingCurve = "0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac";

    // Get the contract factory
    const WowFactoryImpl = await ethers.getContractFactory("WowFactoryImpl");

    // Deploy the implementation contract
    console.log("Deploying implementation contract...");
    const factoryImpl = await WowFactoryImpl.deploy(
        wowImplementation,
        bondingCurve
    );

    await factoryImpl.waitForDeployment();

    const deployedAddress = await factoryImpl.getAddress();
    console.log("WowFactoryImpl deployed to:", deployedAddress);

    console.log("Deployment complete!");

    // Log the verification command
    console.log("\nVerification command:");
    console.log(`npx hardhat verify --network spotlightSepolia ${deployedAddress} ${wowImplementation} ${bondingCurve}`);
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    }); 