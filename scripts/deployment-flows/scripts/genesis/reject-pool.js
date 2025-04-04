const { genesisPoolManagerAddress, genesisPoolManagerAbi } = require('../../../../generated/genesis-pool-manager');
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", ownerAddress)

    try{
        const jsonFilePath = path.join(__dirname, '../../token-constants/genesis-tokens.json'); 
        const jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
        const addresses = jsonData.map(obj => obj.address);

        const nativeToken = "0xB2d52F3cC9796ea606a383f00cB49e66D599B688"

        console.log("nativeToken : ", nativeToken);

        const GenesisManagerContract = await ethers.getContractAt(genesisPoolManagerAbi, genesisPoolManagerAddress);
        await GenesisManagerContract.rejectGenesisPool(nativeToken);
    }
    catch(error){
        console.log("Error in reject token : ", error)
    }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

