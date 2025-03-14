const { genesisPoolAPIAbi, genesisPoolAPIAddress } = require('../../../../generated/genesis-pool-api');
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');
const { genesisPoolManagerAbi, genesisPoolManagerAddress } = require('../../../../generated/genesis-pool-manager');

async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", ownerAddress)

    try{
        const GenesisPoolApi = await ethers.getContractAt(genesisPoolAPIAbi, genesisPoolAPIAddress);
        const genesisPoolsData = await GenesisPoolApi.getAllGenesisPools(ownerAddress, "2", "0");

        console.log("genesisPool : ", genesisPoolsData);

        const GenesisPoolManager = await ethers.getContractAt(genesisPoolManagerAbi, genesisPoolManagerAddress);
        const nativeTokens = await GenesisPoolManager.getLiveNaitveTokens();

        console.log("nativeTokens : ", nativeTokens);
        // const genesisPools = genesisPoolsData[0];

        // for(const genesisPool of genesisPools){
        //     console.log("genesisPool : ", genesisPool);
        // }
    }
    catch(error){
        console.log("Error in genesis api : ", error)
    }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

