const { ethers  } = require('hardhat');
const { pairFactoryUpgradeableAbi, pairFactoryUpgradeableAddress } = require('../../generated/pair-factory-upgradeable');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]
    try {
        const pairFactoryContract = await ethers.getContractAt(pairFactoryUpgradeableAbi, "0x49A8f8DA66FA2af7477d9fbc221FAD229ef98f32");

        const getAllPairs = await pairFactoryContract.getPair("0x2b9ba91D776Ef9b5fF95C394342E7C9235925D1D", "0xe185EC9cFA90FaEB88A396Dc86aA5a79Fb653F88", true);
        console.log("getAllPairs", getAllPairs)
    } catch (error) {
        console.log("error ", error)
    }
    
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });