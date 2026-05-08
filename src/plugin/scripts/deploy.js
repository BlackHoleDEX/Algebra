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

    const BasePluginV3Factory = await hre.ethers.getContractFactory("BasePluginV3Factory");
    const feeData1 = await getFeeData();
    const pluginFactory = await BasePluginV3Factory.deploy(deploysData.factory, { ...feeData1 });

    await pluginFactory.waitForDeployment()

    console.log("PluginFactory to:", pluginFactory.target);

    // Deploy PluginV3Deployer
    const PluginV3Deployer = await hre.ethers.getContractFactory("PluginV3Deployer");
    const feeDataDeployer = await getFeeData();
    const pluginDeployer = await PluginV3Deployer.deploy(pluginFactory.target, { ...feeDataDeployer });

    await pluginDeployer.waitForDeployment();

    console.log("PluginV3Deployer deployed to:", pluginDeployer.target);

    // Set PluginV3Deployer in BasePluginV3Factory
    const feeDataDeployerSet = await getFeeData();
    try {
        const tx = await pluginFactory.setPluginDeployer(pluginDeployer.target, { ...feeDataDeployerSet });
        console.log('setPluginDeployer tx:', tx.hash);
        await tx.wait();
        console.log('Updated plugin deployer address in BasePluginV3Factory');
    } catch (e) {
        console.log('setPluginDeployer failed Reason:', e?.message || e);
    }

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
            const tx = await factory.setDefaultPluginFactory(pluginFactory.target, { ...feeData3 })
            console.log('setDefaultPluginFactory tx:', tx.hash)
            await tx.wait()
            console.log('Updated plugin factory address in Pairfactory')
        } catch (e) {
            console.log('setDefaultPluginFactory failed Reason:', e?.message || e)
        }
    } else {
        console.log('Default plugin factory already set');
    }

    // Set default fee configuration with alpha1, alpha2, and baseFee as 0
    const feeConfiguration = {
        alpha1: 0,      // max value of the first sigmoid
        alpha2: 0,      // max value of the second sigmoid
        beta1: 0,   // shift along the x-axis for the first sigmoid
        beta2: 0,   // shift along the x-axis for the second sigmoid
        gamma1: 10,  // horizontal stretch factor for the first sigmoid
        gamma2: 10,  // horizontal stretch factor for the second sigmoid
        baseFee: 0      // minimum possible fee
    };

    const feeData2 = await getFeeData();
    try {
        const tx = await pluginFactory.setDefaultFeeConfiguration(feeConfiguration, { ...feeData2 });
        console.log('setDefaultFeeConfiguration tx:', tx.hash);
        await tx.wait();
        console.log('Updated default fee configuration with alpha1=0, alpha2=0, baseFee=0');
    } catch (e) {
        console.log('setDefaultFeeConfiguration failed Reason:', e?.message || e);
    }

    // Deploy SecurityRegistry
    const SecurityRegistry = await hre.ethers.getContractFactory("SecurityRegistry");
    const feeData4 = await getFeeData();
    const securityRegistry = await SecurityRegistry.deploy(deploysData.factory, { ...feeData4 });

    await securityRegistry.waitForDeployment();

    console.log("SecurityRegistry deployed to:", securityRegistry.target);

    // Set SecurityRegistry in BasePluginV3Factory
    const feeData5 = await getFeeData();
    try {
        const tx = await pluginFactory.setSecurityRegistry(securityRegistry.target, { ...feeData5 });
        console.log('setSecurityRegistry tx:', tx.hash);
        await tx.wait();
        console.log('Updated security registry address in BasePluginV3Factory');
    } catch (e) {
        console.log('setSecurityRegistry failed Reason:', e?.message || e);
    }

    // Deploy FeeDiscountRegistry
    const FeeDiscountRegistry = await hre.ethers.getContractFactory("FeeDiscountRegistry");
    const feeData6 = await getFeeData();
    const feeDiscountRegistry = await FeeDiscountRegistry.deploy(deploysData.factory, { ...feeData6 });

    await feeDiscountRegistry.waitForDeployment();

    console.log("FeeDiscountRegistry deployed to:", feeDiscountRegistry.target);

    // Set FeeDiscountRegistry in BasePluginV3Factory
    const feeData7 = await getFeeData();
    try {
        const tx = await pluginFactory.setFeeDiscountRegistry(feeDiscountRegistry.target, { ...feeData7 });
        console.log('setFeeDiscountRegistry tx:', tx.hash);
        await tx.wait();
        console.log('Updated fee discount registry address in BasePluginV3Factory');
    } catch (e) {
        console.log('setFeeDiscountRegistry failed Reason:', e?.message || e);
    }

    deploysData.BasePluginV3Factory = pluginFactory.target;
    deploysData.PluginV3Deployer = pluginDeployer.target;
    deploysData.SecurityRegistry = securityRegistry.target;
    deploysData.FeeDiscountRegistry = feeDiscountRegistry.target;
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
