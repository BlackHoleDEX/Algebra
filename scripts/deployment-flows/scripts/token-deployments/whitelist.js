const { genesisPoolAbi } = require('../../../../generated/genesis-pool');
const { customTokenAbi } = require('../../../../generated/custom-token');
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');
const { BigNumber } = require("ethers");
const { tokenHandlerAbi, tokenHandlerAddress } = require('../../../../generated/token-handler');

async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", ownerAddress)

    try{
        const token = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
       
        const TokenHandlerContract = await ethers.getContractAt(tokenHandlerAbi, tokenHandlerAddress);
        await TokenHandlerContract.whitelistToken(token);

        // await TokenHandlerContract.blacklistToken(token);
        console.log("Done");
    }
    catch(error){
        console.log("Error in deposit native token : ", error)
    }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

