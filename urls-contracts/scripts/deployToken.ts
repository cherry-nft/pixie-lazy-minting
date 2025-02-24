import { ethers } from "hardhat";

async function main() {
    // Factory contract address - replace with actual deployed address
    const FACTORY_ADDRESS = "0xDB39e4A11bfF5993FDEfA4ebA076486E1e6e2c62";

    const tokenUri = {
        name: "Test Token",
        symbol: "TEST",
        description: "Test Token Description",
        image: "https://example.com/image.png",
    }

    // Configuration for the token deployment
    const config = {
        tokenCreator: "0x96d9894371d8cf0C566F557bc8830F881E4D6c7a", // replace with creator address
        platformReferrer: "0x96d9894371d8cf0C566F557bc8830F881E4D6c7a", // replace with referrer address
        tokenUri: 'eyJuYW1lIjoiVHdpdGNoIiwic3ltYm9sIjoiJFRXSVRDSCIsImRlc2NyaXB0aW9uIjoiVHdpdGNoIGlzIGFuIGludGVyYWN0aXZlIGxpdmVzdHJlYW1pbmcgc2VydmljZSBmb3IgY29udGVudCBzcGFubmluZyBnYW1pbmcsIGVudGVydGFpbm1lbnQsIHNwb3J0cywgbXVzaWMsIGFuZCBtb3JlLiBUaGVyZeKAmXMgc29tZXRoaW5nIGZvciBldmVyeW9uZSBvbiBUd2l0Y2guIiwid2Vic2l0ZUxpbmsiOiJodHRwczovL3d3dy50d2l0Y2gudHYvIiwibnNmdyI6ZmFsc2UsInRpbWVzdGFtcCI6IjIwMjQtMTEtMjdUMDQ6MTg6MDAuODkzWiIsIm1ldGFkYXRhIjp7Im9wZW5ncmFwaCI6eyJ0aXRsZSI6IlR3aXRjaCIsImRlc2NyaXB0aW9uIjoiVHdpdGNoIGlzIGFuIGludGVyYWN0aXZlIGxpdmVzdHJlYW1pbmcgc2VydmljZSBmb3IgY29udGVudCBzcGFubmluZyBnYW1pbmcsIGVudGVydGFpbm1lbnQsIHNwb3J0cywgbXVzaWMsIGFuZCBtb3JlLiBUaGVyZeKAmXMgc29tZXRoaW5nIGZvciBldmVyeW9uZSBvbiBUd2l0Y2guIiwidHlwZSI6IndlYnNpdGUiLCJpbWFnZSI6Imh0dHBzOi8vc3RhdGljLWNkbi5qdHZudy5uZXQvdHR2LXN0YXRpYy1tZXRhZGF0YS90d2l0Y2hfbG9nbzMuanBnIiwic2l0ZU5hbWUiOiJ3d3cudHdpdGNoLnR2IiwidmlkZW8iOm51bGx9fSwiaW1hZ2UiOiJodHRwczovL3N0YXRpYy1jZG4uanR2bncubmV0L3R0di1zdGF0aWMtbWV0YWRhdGEvdHdpdGNoX2xvZ28zLmpwZyJ9',
        name: "Test Token",
        symbol: "TEST",
        // Optional: Additional ETH to send for token initialization
        additionalEth: ethers.parseEther("0.000666") // 0.000666 ETH
    };

    try {
        // Get the factory contract
        const factory = await ethers.getContractAt("UrlsFactoryImpl", FACTORY_ADDRESS);

        // Get the deploy fee
        const deployFee: bigint = await factory.deployFee();
        console.log("Deploy fee:", ethers.formatEther(deployFee.toString()), "ETH");

        // Calculate total ETH to send (deploy fee + additional ETH)
        const totalEth = deployFee + config.additionalEth;
        console.log("Total ETH to send:", totalEth.toString(), "ETH");

        // Deploy the token
        console.log("Deploying token...");
        const tx = await factory.deploy(
            config.tokenCreator,
            config.platformReferrer,
            config.tokenUri,
            config.name,
            config.symbol,
            {
                value: totalEth.toString()
            }
        );

        // Wait for deployment
        console.log("Waiting for transaction...");
        await tx.wait();

        console.log("Transaction hash:", tx.hash);

    } catch (error) {
        console.error("Error deploying token:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 