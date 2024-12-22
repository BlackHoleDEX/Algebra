const { ethers  } = require('hardhat');

const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { pairFactoryAbi, routerV2Abi, routerV2Address, tokenOne, tokenTwo, tokenAbi } = require("./dexAbi");



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]
    const selfAddress = "0x8ec18CcA7E8d40861dc07C217a6426f60005A661";
    const tokenOneContract = await ethers.getContractAt(tokenAbi, tokenOne);
    const tokenTwoContract = await ethers.getContractAt(tokenAbi, tokenTwo);
    const txApprovalOne = await tokenOneContract.approve(routerV2Address, "12000000");
    await txApprovalOne.wait();
    const txApprovalTwo = await tokenTwoContract.approve(routerV2Address, "12000000");
    await txApprovalTwo.wait();
    const routerV2Contract = await ethers.getContractAt(routerV2Abi, routerV2Address);
    /**
     *  address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
     */
    const tokenA = tokenOne;
    const tokenB = tokenTwo;
    const stable = false;
    const amountADesired = "1200000";
    const amountBDesired = "1200000";
    const amountAMin = "1000000";
    const amountBMin = "1000000";
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
    console.log('tx', tx)
    const awaitedTx = await tx.wait();
    console.log("awwaitedTex", awaitedTx);

    // const parameters = {
    //     tokenIn: usdc.address,
    //     tokenOut: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    //     recipient: impersonator,
    //     deadline: 1681727850,
    //     amountIn: ethers.utils.parseEther("0.5"),
    //     amountOutMinimum: ethers.utils.parseEther("0"),
    //     limitSqrtPrice: 0
    // }
    

    // await algebrarouter.exactInputSingle(parameters)   


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
