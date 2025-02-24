import { ethers } from "hardhat";

async function main() {
    const contractAddress = "0x9B4025622685Ae00a3603E87bbaC6cD5b4E60016";
    const minABI = ["function tokenURI() public view returns (string memory)"];

    const [owner] = await ethers.getSigners();
    const degen20 = new ethers.Contract(
        contractAddress,
        minABI,
        owner
    );

    console.log('contractAddress', contractAddress)
    const tokenUriResp = await degen20.tokenURI();
    console.log(tokenUriResp);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
