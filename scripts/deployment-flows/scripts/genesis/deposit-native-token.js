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

        const deployedTokens = require('../../token-constants/deployed-tokens.json');
        const blackAddress = deployedTokens[0].address;

        const nativeToken = addresses[0];
        const tokenOwner = accounts[1].address;
        const auctionIndex = 1;

        const genesisPoolInfo = {
            nativeToken : nativeToken,
            fundingToken : blackAddress,
            stable : false,
            duration : 1209600,
            threshold : 5000,
            supplyPercent : 100, 
            startPrice : BigNumber.from(0.01).mul(BigNumber.from("1000000000000000000")),
            startTime : 1741020000
        }

        proposedNativeAmount = "10000000000";
        proposedFundingAmount = "100000000"

        const tokenAllocation = {
            tokenOwner : tokenOwner,
            proposedNativeAmount : BigNumber.from(proposedNativeAmount).mul(BigNumber.from("1000000000000000000")),
            proposedFundingAmount : BigNumber.from(proposedFundingAmount).mul(BigNumber.from("1000000000000000000")),
            allocatedNativeAmount : 0,
            allocatedFundingAmount : 0,
            refundableNativeAmount : 0
        }

        console.log("nativeToken : ", nativeToken, "tokenOwner : ", tokenOwner);

        const GenesisManagerContract = await ethers.getContractAt(genesisPoolManagerAbi, genesisPoolManagerAddress);
        await GenesisManagerContract.depositNativeToken(nativeToken, auctionIndex, genesisPoolInfo, tokenAllocation);
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

