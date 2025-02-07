const { ethers  } = require('hardhat');
const { pairFactoryAbi, routerV2Abi, tokenOne, tokenTwo, tokenAbi, tokenFive, tokenThree, tokenFour, tokenEight, tokenTen, tokenNine } = require("./dexAbi");



async function addLiquidity(routerV2Address, tokenOne, tokenTwo) {
    accounts = await ethers.getSigners();
    owner = accounts[0]
    const selfAddress = "0xa7243fc6FB83b0490eBe957941a339be4Db11c29";
    const tokenA = tokenOne;
    const tokenB = tokenTwo;
    const tokenAAmount = 100;
    const tokenBAmount = 98;
    const approvalAmount = Math.max(tokenAAmount, tokenBAmount)
    const approvalAmountString = (BigInt(approvalAmount) * BigInt(10 ** 18)).toString();
    const tokenOneContract = await ethers.getContractAt(tokenAbi, tokenA);
    const tokenTwoContract = await ethers.getContractAt(tokenAbi, tokenB);
    const txApprovalOne = await tokenOneContract.approve(routerV2Address, approvalAmountString);
    await txApprovalOne.wait();
    const txApprovalTwo = await tokenTwoContract.approve(routerV2Address, approvalAmountString);
    await txApprovalTwo.wait();
    const routerV2Contract = await ethers.getContractAt(routerV2Abi, routerV2Address);
    const stable = false;
    const amountADesired = (BigInt(tokenAAmount) * BigInt(10 ** 18)).toString();
    const amountBDesired = (BigInt(tokenBAmount) * BigInt(10 ** 18)).toString();
    const amountAMin = "0";
    const amountBMin = "0";
    const to = selfAddress;
    const deadlineUnixTimestamp = Math.floor(Date.now() / 1000) + 718080;
    console.log(deadlineUnixTimestamp);
    const deadline = deadlineUnixTimestamp;
    
    const parameters = {
        tokenA,
        tokenB,
        stable,
        amountADesired,
        amountBDesired,
        amountAMin,
        amountBMin,
        to,
        deadline
    }
    console.log('add liq method', parameters, routerV2Contract.addLiquidity)
    const tx = await routerV2Contract.addLiquidity(
        tokenA,
        tokenB,
        stable,
        amountADesired,
        amountBDesired,
        amountAMin,
        amountBMin,
        to,
        deadline,
    {
        gasLimit: 21000000
    });
    const awaitedTx = await tx.wait();
    console.log("awwaitedTex", awaitedTx);  
}

module.exports = { addLiquidity };