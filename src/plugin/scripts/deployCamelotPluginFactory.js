const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {

    const deployDataPath = path.resolve(__dirname, '../../../deploys.json')
    const deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'))

    const CamelotBasePluginFactory = await hre.ethers.getContractFactory("CamelotBasePluginFactory");
    const dsFactory = await CamelotBasePluginFactory.deploy(deploysData.factory);

    await dsFactory.waitForDeployment()

    console.log("PluginFactory to:", dsFactory.target);

    await dsFactory.changeDynamicFeeStatus(true);
    
    const securityRegistryFactory = await hre.ethers.getContractFactory("SecurityRegistry");
    const securityRegistry = await securityRegistryFactory.deploy(deploysData.factory);

    await securityRegistry.waitForDeployment()

    console.log("SecurityRegistry to:", securityRegistry.target);

    await dsFactory.setSecurityRegistry(securityRegistry.target);
    
    const factory = await hre.ethers.getContractAt('IAlgebraFactory', deploysData.factory)

    await factory.setDefaultPluginFactory(dsFactory.target)
    console.log('Updated plugin factory address in factory')

    deploysData.CamelotBasePluginFactory = dsFactory.target;
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