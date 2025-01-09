const { ethers } = require("hardhat");
const { thenaAbi, thenaAddress } = require("./gaugeConstants/thena");
const { BigNumber } = require("ethers");

async function main () {
    const acc = await ethers.getSigners();
    const owner = acc[0].address;
    console.log('owner is', owner)
    const blackholeContract = await ethers.getContractAt(thenaAbi, thenaAddress);
    let balanceOfOwner = await blackholeContract.balanceOf(owner);
    console.log('balanceOfOwner pre minting', balanceOfOwner)
    const mintingTx = await blackholeContract.mint(owner, BigNumber.from(100_000_000));
    await mintingTx.wait();
    balanceOfOwner = await blackholeContract.balanceOf(owner);
    console.log('balanceOfOwner post minting', balanceOfOwner)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
