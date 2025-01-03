const { ethers  } = require('hardhat');

const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackHoleAllPairAbi, blackHoleAllPairProxyAddress } = require('./pairApiConstants');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]

    const blackHoleAllPairContract = await ethers.getContractAt(blackHoleAllPairAbi, blackHoleAllPairProxyAddress);
    const blackHoleAllPairContractOwner = await blackHoleAllPairContract.owner();
    console.log("blackHoleAllPairContract owner : ", blackHoleAllPairContractOwner);

    const  blackHoleAllPairContractPairsData = await blackHoleAllPairContract.getAllPair(owner.address, BigInt(2), BigInt(0));
    const totalPairs = blackHoleAllPairContractPairsData[0];
    const pairs = blackHoleAllPairContractPairsData[1];
    console.log("Total pairs : ", totalPairs);
    console.log("All pairs : ", pairs);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// returns the following
// [
//     BigNumber { value: "8" },
//     [
//       [
//         '0x1C2b9eb0a6C13e7d21f9915BEA738E4d7A24c358',
//         'vAMM-TT/TO',
//         'VolatileV1 AMM - TT/TO',
//         BigNumber { value: "18" },
//         false,
//         BigNumber { value: "42743172" },
//         '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         'TT',
//         BigNumber { value: "18" },
//         BigNumber { value: "41704743" },
//         BigNumber { value: "0" },
//         '0x635a8C9Fda481482cD83969709cc9f46114032F7',
//         'TO',
//         BigNumber { value: "18" },
//         BigNumber { value: "46059005" },
//         BigNumber { value: "1220" },
//         BigNumber { value: "42742172" },
//         BigNumber { value: "999999999999999939371719" },
//         BigNumber { value: "999999999999999933339262" },
//         BigNumber { value: "0" },
//         BigNumber { value: "0" },
//         pair_address: '0x1C2b9eb0a6C13e7d21f9915BEA738E4d7A24c358',
//         symbol: 'vAMM-TT/TO',
//         name: 'VolatileV1 AMM - TT/TO',
//         decimals: BigNumber { value: "18" },
//         stable: false,
//         total_supply: BigNumber { value: "42743172" },
//         token0: '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         token0_symbol: 'TT',
//         token0_decimals: BigNumber { value: "18" },
//         reserve0: BigNumber { value: "41704743" },
//         claimable0: BigNumber { value: "0" },
//         token1: '0x635a8C9Fda481482cD83969709cc9f46114032F7',
//         token1_symbol: 'TO',
//         token1_decimals: BigNumber { value: "18" },
//         reserve1: BigNumber { value: "46059005" },
//         claimable1: BigNumber { value: "1220" },
//         account_lp_balance: BigNumber { value: "42742172" },
//         account_token0_balance: BigNumber { value: "999999999999999939371719" },
//         account_token1_balance: BigNumber { value: "999999999999999933339262" },
//         account_gauge_balance: BigNumber { value: "0" },
//         account_gauge_earned: BigNumber { value: "0" }
//       ],
//       [
//         '0xC6e39a293117881cbf6156d1616Bb362121bBB0A',
//         'vAMM-TTH/TT',
//         'VolatileV1 AMM - TTH/TT',
//         BigNumber { value: "18" },
//         false,
//         BigNumber { value: "1200000" },
//         '0x230819D91cCaD0da03C4b32c9cC79A058c293552',
//         'TTH',
//         BigNumber { value: "18" },
//         BigNumber { value: "1200000" },
//         BigNumber { value: "0" },
//         '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         'TT',
//         BigNumber { value: "18" },
//         BigNumber { value: "1200000" },
//         BigNumber { value: "0" },
//         BigNumber { value: "1199000" },
//         BigNumber { value: "999999999999999997600000" },
//         BigNumber { value: "999999999999999939371719" },
//         BigNumber { value: "0" },
//         BigNumber { value: "0" },
//         pair_address: '0xC6e39a293117881cbf6156d1616Bb362121bBB0A',
//         symbol: 'vAMM-TTH/TT',
//         name: 'VolatileV1 AMM - TTH/TT',
//         decimals: BigNumber { value: "18" },
//         stable: false,
//         total_supply: BigNumber { value: "1200000" },
//         token0: '0x230819D91cCaD0da03C4b32c9cC79A058c293552',
//         token0_symbol: 'TTH',
//         token0_decimals: BigNumber { value: "18" },
//         reserve0: BigNumber { value: "1200000" },
//         claimable0: BigNumber { value: "0" },
//         token1: '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         token1_symbol: 'TT',
//         token1_decimals: BigNumber { value: "18" },
//         reserve1: BigNumber { value: "1200000" },
//         claimable1: BigNumber { value: "0" },
//         account_lp_balance: BigNumber { value: "1199000" },
//         account_token0_balance: BigNumber { value: "999999999999999997600000" },
//         account_token1_balance: BigNumber { value: "999999999999999939371719" },
//         account_gauge_balance: BigNumber { value: "0" },
//         account_gauge_earned: BigNumber { value: "0" }
//       ]
//     ],
//     totPairs: BigNumber { value: "8" },
//     Pairs: [
//       [
//         '0x1C2b9eb0a6C13e7d21f9915BEA738E4d7A24c358',
//         'vAMM-TT/TO',
//         'VolatileV1 AMM - TT/TO',
//         BigNumber { value: "18" },
//         false,
//         BigNumber { value: "42743172" },
//         '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         'TT',
//         BigNumber { value: "18" },
//         BigNumber { value: "41704743" },
//         BigNumber { value: "0" },
//         '0x635a8C9Fda481482cD83969709cc9f46114032F7',
//         'TO',
//         BigNumber { value: "18" },
//         BigNumber { value: "46059005" },
//         BigNumber { value: "1220" },
//         BigNumber { value: "42742172" },
//         BigNumber { value: "999999999999999939371719" },
//         BigNumber { value: "999999999999999933339262" },
//         BigNumber { value: "0" },
//         BigNumber { value: "0" },
//         pair_address: '0x1C2b9eb0a6C13e7d21f9915BEA738E4d7A24c358',
//         symbol: 'vAMM-TT/TO',
//         name: 'VolatileV1 AMM - TT/TO',
//         decimals: BigNumber { value: "18" },
//         stable: false,
//         total_supply: BigNumber { value: "42743172" },
//         token0: '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         token0_symbol: 'TT',
//         token0_decimals: BigNumber { value: "18" },
//         reserve0: BigNumber { value: "41704743" },
//         claimable0: BigNumber { value: "0" },
//         token1: '0x635a8C9Fda481482cD83969709cc9f46114032F7',
//         token1_symbol: 'TO',
//         token1_decimals: BigNumber { value: "18" },
//         reserve1: BigNumber { value: "46059005" },
//         claimable1: BigNumber { value: "1220" },
//         account_lp_balance: BigNumber { value: "42742172" },
//         account_token0_balance: BigNumber { value: "999999999999999939371719" },
//         account_token1_balance: BigNumber { value: "999999999999999933339262" },
//         account_gauge_balance: BigNumber { value: "0" },
//         account_gauge_earned: BigNumber { value: "0" }
//       ],
//       [
//         '0xC6e39a293117881cbf6156d1616Bb362121bBB0A',
//         'vAMM-TTH/TT',
//         'VolatileV1 AMM - TTH/TT',
//         BigNumber { value: "18" },
//         false,
//         BigNumber { value: "1200000" },
//         '0x230819D91cCaD0da03C4b32c9cC79A058c293552',
//         'TTH',
//         BigNumber { value: "18" },
//         BigNumber { value: "1200000" },
//         BigNumber { value: "0" },
//         '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         'TT',
//         BigNumber { value: "18" },
//         BigNumber { value: "1200000" },
//         BigNumber { value: "0" },
//         BigNumber { value: "1199000" },
//         BigNumber { value: "999999999999999997600000" },
//         BigNumber { value: "999999999999999939371719" },
//         BigNumber { value: "0" },
//         BigNumber { value: "0" },
//         pair_address: '0xC6e39a293117881cbf6156d1616Bb362121bBB0A',
//         symbol: 'vAMM-TTH/TT',
//         name: 'VolatileV1 AMM - TTH/TT',
//         decimals: BigNumber { value: "18" },
//         stable: false,
//         total_supply: BigNumber { value: "1200000" },
//         token0: '0x230819D91cCaD0da03C4b32c9cC79A058c293552',
//         token0_symbol: 'TTH',
//         token0_decimals: BigNumber { value: "18" },
//         reserve0: BigNumber { value: "1200000" },
//         claimable0: BigNumber { value: "0" },
//         token1: '0x30816e127553dd03F0318bFab72bA9F3C452A92A',
//         token1_symbol: 'TT',
//         token1_decimals: BigNumber { value: "18" },
//         reserve1: BigNumber { value: "1200000" },
//         claimable1: BigNumber { value: "0" },
//         account_lp_balance: BigNumber { value: "1199000" },
//         account_token0_balance: BigNumber { value: "999999999999999997600000" },
//         account_token1_balance: BigNumber { value: "999999999999999939371719" },
//         account_gauge_balance: BigNumber { value: "0" },
//         account_gauge_earned: BigNumber { value: "0" }
//       ]
//     ]
//   ]