const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {

    const deployDataPath = path.resolve(__dirname, '../../../'+(process.env.DEPLOY_ENV || '')+'deploys.json');
    let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));

    await hre.run("verify:verify", {
        address: deploysData.eternal,
        constructorArguments: [
            deploysData.poolDeployer,
            deploysData.nonfungiblePositionManager
        ],
        });
   
    await hre.run("verify:verify", {
        address: deploysData.fc,
        constructorArguments: [
            deploysData.eternal,
            deploysData.nonfungiblePositionManager
        ],
        });

/*
    // TODO:: VERIFY EternalVirtualPool
     await hre.run('verify:verify', {
       address: "0x45204AC8f938b44bfb0f19be6d2794EeFBfe08B2",
       constructorArguments: ["0x01A8A00A6fC8106B94f84aAbAef689Fd0D77271A", "0xdB2093a4DF635dcE499A0db0BBA9ABe39dB6594A"],
     });*/

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });