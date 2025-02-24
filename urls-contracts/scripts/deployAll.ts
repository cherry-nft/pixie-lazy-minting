import { ethers, network, run } from "hardhat";

async function verifyContract(address: string, constructorArguments: any[] = []) {
    console.log(`\nVerifying contract at ${address}...`);
    try {
        await run("verify:verify", {
            address: address,
            constructorArguments: constructorArguments,
        });
        console.log("Verification successful");
    } catch (error: any) {
        if (error.message.includes("Already Verified")) {
            console.log("Contract already verified");
        } else {
            console.log("Verification failed:", error);
        }
    }
}

async function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
    // Known addresses for Sepolia (matching Foundry script)
    const PROTOCOL_FEE_RECIPIENT = "0x96d9894371d8cf0C566F557bc8830F881E4D6c7a";
    const ORIGIN_FEE_RECIPIENT = "0x96d9894371d8cf0C566F557bc8830F881E4D6c7a";
    const PROTOCOL_REWARDS = "0x96d9894371d8cf0C566F557bc8830F881E4D6c7a";
    const WETH = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";
    const NONFUNGIBLE_POSITION_MANAGER = "0x1238536071E1c677A632429e3655c799b22cDA52";
    const SWAP_ROUTER = "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E";

    console.log("Starting deployment sequence...");
    console.log("Network:", network.name);

    // 1. Deploy Urls implementation
    console.log("\nDeploying Urls implementation...");
    const Urls = await ethers.getContractFactory("Urls");
    const urlsImpl = await Urls.deploy(
        PROTOCOL_FEE_RECIPIENT,
        ORIGIN_FEE_RECIPIENT,
        PROTOCOL_REWARDS,
        WETH,
        NONFUNGIBLE_POSITION_MANAGER,
        SWAP_ROUTER
    );
    await urlsImpl.waitForDeployment();
    const urlsImplAddress = await urlsImpl.getAddress();
    console.log("Urls implementation deployed to:", urlsImplAddress);

    // 2. Deploy BondingCurve
    console.log("\nDeploying BondingCurve...");
    const BondingCurve = await ethers.getContractFactory("BondingCurve");
    const bondingCurve = await BondingCurve.deploy();
    await bondingCurve.waitForDeployment();
    const bondingCurveAddress = await bondingCurve.getAddress();
    console.log("BondingCurve deployed to:", bondingCurveAddress);

    // 3. Deploy UrlsFactoryImpl
    console.log("\nDeploying UrlsFactoryImpl...");
    const UrlsFactoryImpl = await ethers.getContractFactory("UrlsFactoryImpl");
    const factoryImpl = await UrlsFactoryImpl.deploy(
        urlsImplAddress,
        bondingCurveAddress
    );
    await factoryImpl.waitForDeployment();
    const factoryImplAddress = await factoryImpl.getAddress();
    console.log("UrlsFactoryImpl deployed to:", factoryImplAddress);

    // 4. Deploy UrlsFactory proxy
    console.log("\nDeploying UrlsFactory proxy...");
    const UrlsFactory = await ethers.getContractFactory("UrlsFactory");

    // Encode initialization data
    const iface = new ethers.Interface([
        "function initialize(address _owner) external"
    ]);
    const initData = iface.encodeFunctionData("initialize", [PROTOCOL_FEE_RECIPIENT]);

    const proxy = await UrlsFactory.deploy(factoryImplAddress, initData);
    await proxy.waitForDeployment();
    const proxyAddress = await proxy.getAddress();
    console.log("UrlsFactory proxy deployed to:", proxyAddress);

    // Log all deployed addresses
    console.log("\nDeployment Summary:");
    console.log("--------------------");
    console.log("Urls Implementation:", urlsImplAddress);
    console.log("BondingCurve:", bondingCurveAddress);
    console.log("UrlsFactoryImpl:", factoryImplAddress);
    console.log("UrlsFactory Proxy:", proxyAddress);

    // Wait 10 seconds before starting verifications
    console.log("\nWaiting 10 seconds before starting contract verifications...");
    await sleep(10000);

    console.log("\nStarting contract verifications...");

    // Verify all contracts
    await verifyContract(urlsImplAddress, [
        PROTOCOL_FEE_RECIPIENT,
        ORIGIN_FEE_RECIPIENT,
        PROTOCOL_REWARDS,
        WETH,
        NONFUNGIBLE_POSITION_MANAGER,
        SWAP_ROUTER
    ]);
    await verifyContract(bondingCurveAddress);
    await verifyContract(factoryImplAddress, [urlsImplAddress, bondingCurveAddress]);
    await verifyContract(proxyAddress, [factoryImplAddress, initData]);

    console.log("\nAll deployments and verifications completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });
