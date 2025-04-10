const hre = require("hardhat");

async function main() {
    const constructorArgs = [
        "0x7eba5e139d1192384dca805bb39076a75dd027f0", // vault
        600,
        [
            100,
            9400,
            8100,
            7800,
            9100,
            100,
            2500,
            900,
            200,
            300,
            3000,
            1500,
            500,
        ]
    ]

    const RebalanceManagerFactory = await hre.ethers.getContractFactory("RebalanceManager");
    const RebalanceManager = await RebalanceManagerFactory.deploy(
        ...constructorArgs
    );

    await RebalanceManager.waitForDeployment()

    console.log("RebalanceManager to:", RebalanceManager.target);

    await hre.run("verify:verify", {
        address: RebalanceManager.target,
        constructorArguments: constructorArgs,
    });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });