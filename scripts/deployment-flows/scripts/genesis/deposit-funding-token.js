const { genesisPoolManagerAddress, genesisPoolManagerAbi } = require('../../../../generated/genesis-pool-manager');
const { customTokenAbi } = require('../../../../generated/custom-token');
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');
const { BigNumber } = require("ethers");

async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", ownerAddress)

    try{
        const jsonFilePath = path.join(__dirname, '../../token-constants/genesis-tokens.json'); 
        const jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
        const addresses = jsonData.map(obj => obj.address);

        const deployedTokens = require('../../token-constants/deployed-tokens.json');
        const blackAddress = deployedTokens[0].address;

        const nativeToken = addresses[1];
        const fundingToken = blackAddress;
        let depositAmount = 55;
        const genesisPoolAddress = "0x3fD0D1763De7378E236008cBd26c506E7CDA1B64";

        // let approvalAmountString = (BigInt(depositAmount) * BigInt(10 ** 18)).toString();
        const tokenContract = await ethers.getContractAt(customTokenAbi, fundingToken);
        // let tokenSigner = tokenContract.connect(accounts[1]);
        // let txApproval = await tokenSigner.approve(genesisPoolAddress, approvalAmountString);
        // await txApproval.wait();

        const GenesisManagerContract = await ethers.getContractAt(genesisPoolManagerAbi, genesisPoolManagerAddress);
        // let genesisSigner = GenesisManagerContract.connect(accounts[1]);
        // let txt = await genesisSigner.depositToken(genesisPoolAddress, approvalAmountString);
        // await txt.wait();
        // console.log("deposited from owner");

        // depositAmount = 50;

        approvalAmountString = (BigInt(depositAmount) * BigInt(10 ** 18)).toString();
        tokenSigner = tokenContract.connect(accounts[0]);
        txApproval = await tokenSigner.approve(genesisPoolAddress, approvalAmountString);
        await txApproval.wait();

        genesisSigner = GenesisManagerContract.connect(accounts[0]);
        txt = await genesisSigner.depositToken(genesisPoolAddress, approvalAmountString);
        await txt.wait();
        console.log("deposited from funder");
    }
    catch(error){
        console.log("Error in deposit funding token : ", error)
    }
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});

