import { ethers } from "hardhat";

async function main() {
    // Factory contract address - replace with actual deployed address
    const FACTORY_ADDRESS = "0x74566613Fa1C7FB05A30A23b5387F0005481f2B3";

    try {
        // Get the factory contract
        const factory = await ethers.getContractAt("UrlsFactoryImpl", FACTORY_ADDRESS);

        // Get the deploy fee
        const deployFee = await factory.getDeployFee();

        // Log the fee in different formats
        console.log("\nDeploy Fee:");
        console.log("------------");
        console.log("Wei:", deployFee.toString());
        console.log("ETH:", ethers.formatEther(deployFee));
        console.log("Gwei:", ethers.formatUnits(deployFee, "gwei"));

        // Get the owner address
        const ownerAddress = await factory.owner();
        console.log("Factory Owner:", ownerAddress);

    } catch (error) {
        console.error("Error getting deploy fee:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 