const { thenaAbi, thenaAddress } = require("./gaugeConstants/thena");
const { minterUpgradableAddress } = require("./gaugeConstants/minter-upgradable");

async function main () {
    const thenaContract = await ethers.getContractAt(thenaAbi, thenaAddress);
    await thenaContract.setMinter(minterUpgradableAddress);
    console.log('set minter in Thena');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });