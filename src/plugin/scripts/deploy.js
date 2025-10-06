const hre = require("hardhat");
const fs = require('fs');
const path = require('path');


async function getFeeData() {
    const { maxFeePerGas, maxPriorityFeePerGas } = await hre.ethers.provider.getFeeData();
    return { maxFeePerGas, maxPriorityFeePerGas };
}


async function main() {

    const deployDataPath = path.resolve(__dirname, '../../../'+(process.env.DEPLOY_ENV || '')+'deploys.json')
    const deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'))

    const BasePluginV1Factory = await hre.ethers.getContractFactory("BasePluginV1Factory");
    const feeData1 = await getFeeData();
    const dsFactory = await BasePluginV1Factory.deploy(deploysData.factory, { ...feeData1 });

    await dsFactory.waitForDeployment()

    console.log("PluginFactory to:", dsFactory.target);

    /**
     * @dev This below call setDefaultPluginFactory will fail because the factory's owner is multisig.
     * It'll work as long as it's completely new deployment.
     * Now we set only if current value is zero; otherwise skip.
     */
    const factory = await hre.ethers.getContractAt('IAlgebraFactory', deploysData.factory)
    const currentDefault = await factory.defaultPluginFactory().catch(() => hre.ethers.ZeroAddress)

    if (currentDefault === hre.ethers.ZeroAddress) {
        const feeData3 = await getFeeData();
        try {
            const tx = await factory.setDefaultPluginFactory(dsFactory.target, { ...feeData3 })
            console.log('setDefaultPluginFactory tx:', tx.hash)
            await tx.wait()
            console.log('Updated plugin factory address in Pairfactory')
        } catch (e) {
            console.log('setDefaultPluginFactory failed Reason:', e?.message || e)
        }
    } else {
        console.log('Default plugin factory already set');
    }

    deploysData.BasePluginV1Factory = dsFactory.target;
    fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
      console.error(error);
      process.exit(1);
  });
