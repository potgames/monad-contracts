const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);

    // 1. Deploy PythAdapter
    const PythAdapter = await ethers.getContractFactory("PythAdapter");
    console.log("Deploying PythAdapter...");
    const pythAdapter = await PythAdapter.deploy(
        "0x2880aB155794e7179c9eE2e38200202908C17B43",
        "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
        "pyth adapter on monad",
        deployer.address
    );
    await pythAdapter.waitForDeployment();
    console.log("PythAdapter deployed to:", await pythAdapter.getAddress());

    // 2. Deploy MoonOrDoomOperator
    const MoonOrDoomOperator = await ethers.getContractFactory("MoonOrDoomOperator");
    console.log("Deploying MoonOrDoomOperator...");
    const operator = await MoonOrDoomOperator.deploy(
        deployer.address,      // Admin address
        deployer.address       // Operator address
    );
    await operator.waitForDeployment();
    console.log("MoonOrDoomOperator deployed to:", await operator.getAddress());

    // 3. Deploy MoonOrDoomNativeToken
    const MoonOrDoomNativeToken = await ethers.getContractFactory("MoonOrDoomNativeToken");
    console.log("Deploying MoonOrDoomNativeToken...");
    const moonOrDoom = await MoonOrDoomNativeToken.deploy(
        await pythAdapter.getAddress(),  // Oracle address
        deployer.address,               // Admin address
        await operator.getAddress(),    // Operator address
        60,                          // intervalSeconds (60 seconds)
        30,                           // bufferSeconds (30 seconds)
        ethers.parseEther("0.01"),     // minEntry
        60,                           // oracleUpdateAllowance
        200                            // treasuryFee (2%)
    );
    await moonOrDoom.waitForDeployment();
    console.log("MoonOrDoomNativeToken deployed to:", await moonOrDoom.getAddress());

    console.log("Initializing MoonOrDoomOperator...");
    await operator.initialize(
        await moonOrDoom.getAddress(),
        await pythAdapter.getAddress()
    );

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });