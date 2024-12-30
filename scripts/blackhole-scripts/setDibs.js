const { ethers } = require("hardhat");
const { routerV2Abi, routerV2Address, pairFactoryAbi, pairFactoryAddress } = require("../V1/dexAbi");

async function main () {
    const owner = await ethers.getSigners();
    const PairFactoryContract = await ethers.getContractAt(pairFactoryAbi, pairFactoryAddress);
    const tx = await PairFactoryContract.setDibs(owner[0].address);
    await tx.wait();
}

main()
