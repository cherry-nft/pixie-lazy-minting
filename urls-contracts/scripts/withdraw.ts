import { ethers } from "hardhat";

async function main() {
    // Address of the deployed factory contract
    const FACTORY_ADDRESS = "0x97afd41890ea749a1b7d4491d8f2f86b0eb90207"; // Replace with your deployed contract address

    // Minimal ABI for the functions we need
    const FACTORY_ABI = [
        "function owner() view returns (address)",
        "function withdraw(address[] calldata tokens)",
    ];

    try {
        // Get the signer
        const [signer] = await ethers.getSigners();
        console.log("Using signer address:", await signer.getAddress());

        // Get contract instance
        const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, signer);

        // Verify we're the owner
        const owner = await factory.owner();
        const signerAddress = await signer.getAddress();
        if (owner.toLowerCase() !== signerAddress.toLowerCase()) {
            throw new Error(`Not contract owner. Owner is ${owner}`);
        }

        console.log("Calling withdraw...");

        // Call withdraw with empty array to just withdraw ETH
        // Add token addresses to the array if you want to withdraw specific ERC20 tokens
        const tx = await factory.withdraw([]);
        console.log("Transaction hash:", tx.hash);

        // Wait for transaction to be mined
        const receipt = await tx.wait();
        console.log("Transaction confirmed in block:", receipt.blockNumber);

        // Get final balances
        const balance = await ethers.provider.getBalance(FACTORY_ADDRESS);
        console.log("Final contract ETH balance:", ethers.formatEther(balance));

    } catch (error) {
        console.error("Error:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });