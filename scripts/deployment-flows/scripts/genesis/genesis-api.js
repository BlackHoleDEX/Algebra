const { genesisPoolAPIAbi, genesisPoolAPIAddress } = require('../../../../generated/genesis-pool-api');
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');
const { genesisPoolManagerAbi, genesisPoolManagerAddress } = require('../../../../generated/genesis-pool-manager');
const { genesisPoolFactoryAbi } = require('../../../../generated/genesis-pool-factory');

async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", accounts[1].address)

    try{
        const GenesisPoolApi = await ethers.getContractAt(genesisPoolAPIAbi, "0x6E49D82979e4a23184d16Afa96876c9852F0AD09");
        const signers = GenesisPoolApi.connect(accounts[1]); 
        const genesisPoolsData = await signers.getAllUserRelatedGenesisPools(accounts[1].address);

        console.log("genesisPool : ", genesisPoolsData);

        const GenesisPoolManager = await ethers.getContractAt(genesisPoolManagerAbi, '0xF6c64e5cBe8fafb44eAb82353245e890EBcE943c');
        const nativeTokens = await GenesisPoolManager.getAllNaitveTokens();

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

