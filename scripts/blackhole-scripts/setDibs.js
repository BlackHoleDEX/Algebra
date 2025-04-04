const { ethers } = require("hardhat");
const { pairFactoryAbi, pairFactoryAddress } = require("../../generated/pair-factory");

async function main () {
    const owner = await ethers.getSigners();
    const PairFactoryContract = await ethers.getContractAt(pairFactoryAbi, pairFactoryAddress);
    const tx = await PairFactoryContract.setDibs("0xC0071bb38544dA9FE162FB39B1914ABfe8B082dF");
    await tx.wait();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
    console.error(error);
    process.exit(1);
});
