const wethAddress = "0x4200000000000000000000000000000000000006";

const { ethers } = require("hardhat");

const { routerV2Abi, routerV2Address } = require("../../../generated/router-v2");
const deployedTokens = require("../../deployment-flows/token-constants/deploying-tokens.json")
console.log("deployed tokens", deployedTokens);
const { abi: wethAbi } = require("./weth-abi");
const { tokenAbi } = require("../dexAbi");
console.log("abi: ", wethAbi)
async function main () {
    // function addLiquidityETH(
    //     address token,
    //     bool stable,
    //     uint amountTokenDesired,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline
    // )

    accounts = await ethers.getSigners();
    owner = accounts[0];
    const ownerAddress = owner.address;
    // const wethErc20 = await ethers.getContractAt(tokenAbi, wethAddress);
    // console.log("weth balance before depositing: ",await  wethErc20.balanceOf(ownerAddress));

    const wethContract = await ethers.getContractAt(wethAbi, wethAddress)
    const depositTx = await wethContract.deposit({ value: BigInt(1), gasLimit: 21000000 }); // have to add a transfer of eth as well
    await depositTx.wait();

    console.log("weth balance after depositing: ", await wethErc20.balanceOf(ownerAddress));

    const novaToken = deployedTokens.find((elm) => elm.name === 'Nova Genesis');
    const routerV2Contract = await ethers.getContractAt(routerV2Abi, routerV2Address);
    const stable = false;


    // const 
    
    // await routerV2Contract.addLiquidityETH(
    //     novaToken.address,
    //     stable,

    // )
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
