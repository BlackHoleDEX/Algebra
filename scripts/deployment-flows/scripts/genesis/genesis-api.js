const { genesisPoolAPIAbi, genesisPoolAPIAddress } = require('../../../../generated/genesis-pool-api');
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", ownerAddress)

    try{
        const GenesisPoolApi = await ethers.getContractAt(genesisPoolAPIAbi, genesisPoolAPIAddress);
        const genesisPoolsData = await GenesisPoolApi.getAllGenesisPools(ownerAddress, 10, 0);

        const genesisPools = genesisPoolsData[0];

        for(const genesisPool of genesisPools){
            console.log("genesisPool : ", genesisPool);
        }
    }
    catch(error){
        console.log("Error in whitelisting token : ", error)
    }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

