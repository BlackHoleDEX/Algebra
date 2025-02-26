"use strict";

var _require = require("hardhat"),
    ethers = _require.ethers;

var _require2 = require("../../../generated/voting-escrow"),
    votingEscrowAddress = _require2.votingEscrowAddress,
    votingEscrowAbi = _require2.votingEscrowAbi;

var _require3 = require("../../../generated/avm"),
    avmAbi = _require3.avmAbi,
    avmAddress = _require3.avmAddress;

var _require4 = require("../../../generated/ve-nftapi"),
    veNFTAPIAbi = _require4.veNFTAPIAbi,
    veNFTAPIAddress = _require4.veNFTAPIAddress;

var _require5 = require("../gaugeConstants/bribe"),
    bribeAbi = _require5.bribeAbi;

var _require6 = require("@openzeppelin/test-helpers/src/constants"),
    ZERO_ADDRESS = _require6.ZERO_ADDRESS;

var _require7 = require("../../../generated/blackhole-pair-apiv2"),
    blackholePairAPIV2Abi = _require7.blackholePairAPIV2Abi,
    blackholePairAPIV2Address = _require7.blackholePairAPIV2Address;

var deployedTokens = require('../../deployment-flows/token-constants/deployed-tokens.json');

var _require8 = require("../../../generated/black"),
    blackAbi = _require8.blackAbi;

var _require9 = require("../dexAbi"),
    pairAbi = _require9.pairAbi;

var _require10 = require("../gaugeConstants/gaugeV2-constants"),
    gaugeV2Abi = _require10.gaugeV2Abi;

var _require11 = require("bignumber.js"),
    BigNumber = _require11["default"];

var _require12 = require("../../../generated/voter-v3"),
    voterV3Abi = _require12.voterV3Abi,
    voterV3Address = _require12.voterV3Address;

var blackAddress = deployedTokens[0].address;
console.log("blackAddress is as: ", blackAddress);

function getEpochStart(timestamp) {
  var WEEK = 30 * 60; // 604800 seconds

  return timestamp - timestamp % WEEK;
}

function main() {
  var owner, ownerAddress, pairApiContract, avmContract, blackContract, allPairs, allPairsInfo, voterV3, transactions, txResponses, externalBribeOne, externalBribeTwo, amount, approveBlackToBribe, incentivizeFirstPool, approveBlackToSecondBribe, incentivizeSecondPool, pairOne, gaugeOne, pairBalance, depositingAmount, pairApproval, depositLPTx, pairTwoApproval, depositLPTxForPairTwo;
  return regeneratorRuntime.async(function main$(_context2) {
    while (1) {
      switch (_context2.prev = _context2.next) {
        case 0:
          _context2.next = 2;
          return regeneratorRuntime.awrap(ethers.getSigners());

        case 2:
          owner = _context2.sent[0];
          ownerAddress = owner.address;
          console.log("owner address: ", ownerAddress); // GET CONTRACTS 

          _context2.next = 7;
          return regeneratorRuntime.awrap(ethers.getContractAt(blackholePairAPIV2Abi, blackholePairAPIV2Address));

        case 7:
          pairApiContract = _context2.sent;
          _context2.next = 10;
          return regeneratorRuntime.awrap(ethers.getContractAt(avmAbi, avmAddress));

        case 10:
          avmContract = _context2.sent;
          _context2.next = 13;
          return regeneratorRuntime.awrap(ethers.getContractAt(blackAbi, blackAddress));

        case 13:
          blackContract = _context2.sent;
          _context2.next = 16;
          return regeneratorRuntime.awrap(pairApiContract.getAllPair(ownerAddress, "5", "0"));

        case 16:
          allPairs = _context2.sent;
          allPairsInfo = allPairs[2];
          _context2.next = 20;
          return regeneratorRuntime.awrap(ethers.getContractAt(voterV3Abi, voterV3Address));

        case 20:
          voterV3 = _context2.sent;
          console.log("got contracts");
          _context2.next = 24;
          return regeneratorRuntime.awrap(Promise.all(allPairsInfo.map(function _callee(element) {
            var externalBribe;
            return regeneratorRuntime.async(function _callee$(_context) {
              while (1) {
                switch (_context.prev = _context.next) {
                  case 0:
                    _context.next = 2;
                    return regeneratorRuntime.awrap(ethers.getContractAt(bribeAbi, element.external_bribes[0]));

                  case 2:
                    externalBribe = _context.sent;
                    return _context.abrupt("return", externalBribe.populateTransaction.addRewardToken(blackAddress));

                  case 4:
                  case "end":
                    return _context.stop();
                }
              }
            });
          })));

        case 24:
          transactions = _context2.sent;
          _context2.next = 27;
          return regeneratorRuntime.awrap(Promise.all(transactions.map(function (tx) {
            return ethers.provider.sendTransaction(tx);
          })));

        case 27:
          txResponses = _context2.sent;
          _context2.next = 30;
          return regeneratorRuntime.awrap(Promise.all(txResponses.map(function (tx) {
            return tx.wait();
          })));

        case 30:
          console.log("All reward tokens added successfully!"); // STEP 1: INCENTIVIZE USERS - INCENTIVIZATION CAN BE DONE BY ANYBODY AND WILL BE DISTRIBUTED TO THE VOTERS BASED ON THE VOTES

          _context2.next = 33;
          return regeneratorRuntime.awrap(ethers.getContractAt(bribeAbi, allPairsInfo[0].external_bribes[0]));

        case 33:
          externalBribeOne = _context2.sent;
          _context2.next = 36;
          return regeneratorRuntime.awrap(ethers.getContractAt(bribeAbi, allPairsInfo[1].external_bribes[0]));

        case 36:
          externalBribeTwo = _context2.sent;
          amount = "1000000000000000000";
          _context2.next = 40;
          return regeneratorRuntime.awrap(blackContract.approve(allPairsInfo[0].external_bribes[0], amount));

        case 40:
          approveBlackToBribe = _context2.sent;
          _context2.next = 43;
          return regeneratorRuntime.awrap(approveBlackToBribe.wait());

        case 43:
          _context2.next = 45;
          return regeneratorRuntime.awrap(externalBribeOne.notifyRewardAmount(blackAddress, amount));

        case 45:
          incentivizeFirstPool = _context2.sent;
          _context2.next = 48;
          return regeneratorRuntime.awrap(incentivizeFirstPool.wait());

        case 48:
          _context2.next = 50;
          return regeneratorRuntime.awrap(blackContract.approve(allPairsInfo[1].external_bribes[0], amount));

        case 50:
          approveBlackToSecondBribe = _context2.sent;
          _context2.next = 53;
          return regeneratorRuntime.awrap(approveBlackToSecondBribe.wait());

        case 53:
          _context2.next = 55;
          return regeneratorRuntime.awrap(externalBribeTwo.notifyRewardAmount(blackAddress, amount));

        case 55:
          incentivizeSecondPool = _context2.sent;
          _context2.next = 58;
          return regeneratorRuntime.awrap(incentivizeSecondPool.wait());

        case 58:
          // STEP 1.1: TRADE IN ALL 5 POOLS IN WHICH U ADDED LIQUIDITY
          // SKIPPED FOR STAGE I
          // STEP 1.2: STAKE LIQUIDITY
          console.log("pair address: ", allPairsInfo[0].pair_address);
          _context2.next = 61;
          return regeneratorRuntime.awrap(ethers.getContractAt(pairAbi, allPairsInfo[0].pair_address));

        case 61:
          pairOne = _context2.sent;
          _context2.next = 64;
          return regeneratorRuntime.awrap(ethers.getContractAt(gaugeV2Abi, allPairsInfo[0].gauge));

        case 64:
          gaugeOne = _context2.sent;
          pairBalance = allPairsInfo[0].account_lp_balance;
          depositingAmount = BigNumber(pairBalance).multipliedBy(0.3);
          console.log("pair balance is: ", pairBalance, " depositing pair tokens quantity: ", depositingAmount);
          _context2.next = 70;
          return regeneratorRuntime.awrap(pairOne.approve(allPairsInfo[0].gauge, depositingAmount));

        case 70:
          pairApproval = _context2.sent;
          _context2.next = 73;
          return regeneratorRuntime.awrap(pairApproval.wait());

        case 73:
          _context2.next = 75;
          return regeneratorRuntime.awrap(gaugeOne.deposit(depositingAmount));

        case 75:
          depositLPTx = _context2.sent;
          _context2.next = 78;
          return regeneratorRuntime.awrap(depositLPTx.wait());

        case 78:
          _context2.next = 80;
          return regeneratorRuntime.awrap(pairOne.approve(allPairsInfo[1].gauge, depositingAmount));

        case 80:
          pairTwoApproval = _context2.sent;
          _context2.next = 83;
          return regeneratorRuntime.awrap(pairTwoApproval.wait());

        case 83:
          _context2.next = 85;
          return regeneratorRuntime.awrap(gaugeOne.deposit(depositingAmount));

        case 85:
          depositLPTxForPairTwo = _context2.sent;
          _context2.next = 88;
          return regeneratorRuntime.awrap(depositLPTxForPairTwo.wait());

        case 88:
        case "end":
          return _context2.stop();
      }
    }
  });
}

main().then(function () {
  return process.exit(0);
})["catch"](function (error) {
  console.error(error);
  process.exit(1);
});