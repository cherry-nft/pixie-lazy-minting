// npx hardhat run scripts/deployUrlsFactory.ts --network sepolia 0x1234...5678 0xabcd...ef90

import { ethers, network } from "hardhat";

async function main() {
    // Get the implementation address from command line arguments
    const implementationAddress = '0x8D698257ba85Df85cDF6E6ACFc093951e8569BE7';
    const bondingCurveAddress = '0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac';

    // Get the owner address from command line arguments
    const owner = '0x96d9894371d8cf0C566F557bc8830F881E4D6c7a';

    console.log("Deploying UrlsFactory proxy...");
    console.log("Implementation address:", implementationAddress);
    console.log("Owner address:", owner);

    // Get the UrlsFactory contract factory
    const UrlsFactory = await ethers.getContractFactory("UrlsFactory");

    // Encode the initialization data
    const iface = new ethers.Interface([
        "function initialize(address _owner) external"
    ]);
    const initData = iface.encodeFunctionData("initialize", [owner]);

    // Deploy the proxy
    const proxy = await UrlsFactory.deploy(implementationAddress, initData);
    await proxy.waitForDeployment();

    const proxyAddress = await proxy.getAddress();
    console.log("UrlsFactory proxy deployed to:", proxyAddress);

    console.log("\nVerification command:");
    console.log(`npx hardhat verify --network ${network.name} ${proxyAddress} ${implementationAddress} ${bondingCurveAddress}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
