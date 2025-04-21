const { ethers } = require("hardhat");
const { epochControllerAbi, epochControllerAddress } = require("../../../../generated/epoch-controller");

async function main () {
    try{
        const epochController = await ethers.getContractAt(epochControllerAbi, epochControllerAddress);
        await epochController.setAutomationRegistry("0xfbA17c74eDE719224A42dcF74FA8cfC2859A5646");
        console.log("setChainLinkAddress success");
    } catch(error){
        console.log("setChainLinkAddress failed: ", error);
        process.exit(1);
    }
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error); 
    process.exit(1);
  });
