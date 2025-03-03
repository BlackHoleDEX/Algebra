const { genesisPoolAbi } = require('../../../../generated/genesis-pool');
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');


async function main () {

  accounts = await ethers.getSigners();
  owner = accounts[0];
  const ownerAddress = owner.address;
  console.log("ownerAddress : ", ownerAddress)

    try{
        let jsonFilePath = path.join(__dirname, '../../token-constants/genesis-tokens.json'); 
        let jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
        const nativeAddresses = jsonData.map(obj => obj.address);

        jsonFilePath = path.join(__dirname, '../../token-constants/deploying-tokens.json'); 
        jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
        const addresses = jsonData.map(obj => obj.address);

        const deployedTokens = require('../../token-constants/deployed-tokens.json');
        const blackAddress = deployedTokens[0].address;

        const genesisPoolAddress = "";

        const nativeToken = nativeAddresses[0];
        const incentivesTokens = [addresses[0], addresses[1], blackAddress, nativeToken];
        const incentivesAmounts = [
            BigNumber.from(100).mul(BigNumber.from("1000000000000000000")),
            BigNumber.from(20).mul(BigNumber.from("1000000000000000000")),
            BigNumber.from(100).mul(BigNumber.from("1000000000000000000")),
            BigNumber.from(50).mul(BigNumber.from("1000000000000000000"))
        ]
       
        const tokenOwner = accounts[1].address;

        const GenesisPoolContract = await ethers.getContractAt(genesisPoolAbi, genesisPoolAddress);
        await GenesisPoolContract.addIncentives(incentivesTokens, incentivesAmounts);
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

