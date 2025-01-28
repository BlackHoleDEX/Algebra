const { ethers } = require("hardhat");
const { routerV2Abi, tokenAbi, tokenOne, tokenTwo, pairFactoryAbi, routerV2Address, pairFactoryAddress, tokenFour } = require("../V1/dexAbi");

// 0x1c2b9eb0a6c13e7d21f9915bea738e4d7a24c358 - pool address for TT/TO

async function main () {
    const owner = (await ethers.getSigners())[0];
    const routerContractV2 = await ethers.getContractAt(routerV2Abi, routerV2Address);
    const pairFactoryContract = await ethers.getContractAt(pairFactoryAbi, pairFactoryAddress)
    
    const setdibsTx = await pairFactoryContract.setDibs("0xa7243fc6FB83b0490eBe957941a339be4Db11c29");
    await setdibsTx.wait();

    const RouterV2Contract = await ethers.getContractAt(routerV2Abi, routerV2Address);
    const tokenOneContract = await ethers.getContractAt(tokenAbi, tokenOne);
    const tokenTwoContract = await ethers.getContractAt(tokenAbi, tokenFour);
    // console.log('owner balance of tokens pre swapping', await tokenOneContract.balanceOf(owner.address), await tokenTwoContract.balanceOf(owner.address));

    // weirdly enuf routev2 is centralized
    const swapIn = "100000000000000000000";
    const approvalIn = "102000000000000000000"
    const approvalTx = await tokenOneContract.approve(routerV2Address, approvalIn);
    await approvalTx.wait();
    // console.log('approvalTx', approvalTx)

    // console.log(swapIn,
    //     "100",
    //     tokenOne,
    //     tokenFour,
    //     false,
    //     owner.address,
    //     Math.floor(Date.now()/1000) + 718080,
    //     {
    //         gasLimit: 21000000
    //     })

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
    const stable = false;

    console.log('owner balance of tokens post swapping', await tokenOneContract.balanceOf("0xa7243fc6FB83b0490eBe957941a339be4Db11c29"), await tokenTwoContract.balanceOf("0xa7243fc6FB83b0490eBe957941a339be4Db11c29"));

    const swappintTx = await RouterV2Contract.swapExactTokensForTokensSimple(
        swapIn,
        "0", 
        tokenOne,
        tokenFour,
        stable,
        "0xa7243fc6FB83b0490eBe957941a339be4Db11c29",
        Math.floor(Date.now() / 1000) + 718080,
        {
            gasLimit: 21000000
        }
    );

    await swappintTx.wait();
    console.log('swappingTx', swappintTx)


    console.log('owner balance of tokens post swapping', await tokenOneContract.balanceOf("0xa7243fc6FB83b0490eBe957941a339be4Db11c29"), await tokenTwoContract.balanceOf("0xa7243fc6FB83b0490eBe957941a339be4Db11c29"));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

