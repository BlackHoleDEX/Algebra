const { ethers } = require("hardhat");
const { pairFactoryAbi, pairAbi, pairAddressForTT_TO } = require("../V1/dexAbi");

async function main () {
    const accounts = (await ethers.getSigners())[0];
    const address = accounts.address;

    const PairContract = await ethers.getContractAt(pairAbi, pairAddressForTT_TO);

    console.log('token 0 is: ', await PairContract.token0());
}

main()