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

        const nativeToken = "0xf9b53f75AE3cE042bE135d377e275d01FCFeA250"

        const GenesisManagerContract = await ethers.getContractAt(genesisPoolManagerAbi, "0x1454971a1063D14bDfa8F14c5F45A39A34118Aba");
        await GenesisManagerContract.approveGenesisPool(nativeToken);
    }
    catch(error){
        console.log("Error in aprrove token : ", error)
    }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

