import { expect } from "chai";
import { ethers } from "hardhat";

describe("UrlsFactoryImpl", function () {
    it("Should deploy UrlsFactoryImpl correctly", async function () {
        // Known addresses (same as deploy script)
        const tokenImplementation = "0x47572E9132730EFa75fd0a3916743a1273a980A4";
        const bondingCurve = "0x928194c9B46b1BF92Fe0Ceb980582B7Eea7A72Ac";

        // Deploy the implementation contract
        const UrlsFactoryImpl = await ethers.getContractFactory("UrlsFactoryImpl");
        const factoryImpl = await UrlsFactoryImpl.deploy(
            tokenImplementation,
            bondingCurve
        );
        await factoryImpl.waitForDeployment();

        // Verify the deployment
        expect(await factoryImpl.tokenImplementation()).to.equal(tokenImplementation);
        expect(await factoryImpl.bondingCurve()).to.equal(bondingCurve);
    });
});
