const { ethers } = require("hardhat");
const { addLiquidity } = require('../../../blackhole-scripts/addLiquidity')
const { routerV2Address } = require('../../../../generated/router-v2')
const fs = require('fs');
const path = require('path');

async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", ownerAddress)

    try{
        const jsonFilePath = path.join(__dirname, '../../token-constants/deploying-tokens.json'); // Adjust the path
        const jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
        // Extract addresses
        const addresses = jsonData.map(obj => obj.address);

        const deployedTokens = require('../../token-constants/deployed-tokens.json');
        const blackAddress = deployedTokens[0].address;

        await addLiquidity(routerV2Address, addresses[0], addresses[1], 100, 267800);  // WETH/USDC
        await addLiquidity(routerV2Address, addresses[0], addresses[8], 100, 261100);  // WETH/DAI
        await addLiquidity(routerV2Address, addresses[0], addresses[7], 3604, 100);  // WETH/cbBTC
        // // await addLiquidity(routerV2Address, addresses[0], blackAddress, 100, 535600);  // WETH/BLACK
        await addLiquidity(routerV2Address, addresses[0], addresses[2], 100, 1071200);  // WETH/CHAMP
        await addLiquidity(routerV2Address, addresses[0], addresses[3], 100, 802400);  // WETH/SUPER
        await addLiquidity(routerV2Address, addresses[0], addresses[4], 100, 957634200);  // WETH/XAI
        await addLiquidity(routerV2Address, addresses[0], addresses[6], 100, 1059670);  // WETH/YGG
        await addLiquidity(routerV2Address, addresses[0], addresses[5], 100, 205850);  // WETH/VIRTUALS

        await addLiquidity(routerV2Address, addresses[1], addresses[8], 100, 100);      // USDC/DAI
        await addLiquidity(routerV2Address, addresses[1], addresses[7], 9614320, 100);  // USDC/cbBTC
        await addLiquidity(routerV2Address, addresses[1], blackAddress, 100, 202);      // USDC/BLACK

    }
    catch(error){

    }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

