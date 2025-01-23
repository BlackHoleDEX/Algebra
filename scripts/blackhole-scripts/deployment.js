const { ethers } = require("hardhat")
const { votingEscrowAddress } = require('./gaugeConstants/voting-escrow')
const { bribeFactoryV3Abi } = require('./gaugeConstants/bribe-factory-v3')
const { permissionsRegistryAddress } = require('./gaugeConstants/permissions-registry')
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress } = require('./pairApiConstants');
const { voterV3Abi } = require('./gaugeConstants/voter-v3')
const { minterUpgradableAbi } = require('./gaugeConstants/minter-upgradable')
const { thenaAbi, thenaAddress } = require('./gaugeConstants/thena')
const { pairFactoryAddress, tokenOne, tokenTwo, tokenThree, tokenFour, tokenFive, tokenSix, tokenSeven, tokenEight, tokenNine, tokenTen } = require("../V1/dexAbi");

const deployVoterV3AndSetInit = async (ownerAddress, bribeFactoryV3Address, gaugeV2Address) => {
    try {
        const voterV3ContractFactory = await ethers.getContractFactory("VoterV3");
        const inputs = [votingEscrowAddress, pairFactoryAddress , gaugeV2Address, bribeFactoryV3Address]
        const VoterV3 = await upgrades.deployProxy(voterV3ContractFactory, inputs, {initializer: 'initialize'});
        const txDeployed = await VoterV3.deployed();
        console.log('VoterV3 address: ', VoterV3.address)
        const listOfTokens = [tokenOne, tokenTwo, tokenThree, tokenFour, tokenFive, tokenSix, tokenSeven, tokenEight, tokenNine, tokenTen];
        const initializeVoter = await VoterV3._init(listOfTokens, permissionsRegistryAddress, ownerAddress)
        return VoterV3.address;
    } catch (error) {
        console.log("error in deploying voterV3: ", error);
    }
    
}

const setVoterBribeV3 = async(voterV3Address, bribeFactoryV3Address) => {
    try {
        const bribeV3Contract = await ethers.getContractAt(bribeFactoryV3Abi, bribeFactoryV3Address);
        const createVoter = await bribeV3Contract.setVoter(voterV3Address);
    } catch (error) {
        console.log("error in setting voter in bribeV3: ", error);
    }
    
}

const deployRewardsDistributor = async() => {
    try {
        const rewardsDistributorContractFactory = await ethers.getContractFactory("RewardsDistributor");
        const rewardsDistributor = await rewardsDistributorContractFactory.deploy(votingEscrowAddress);
        const txDeployed = await rewardsDistributor.deployed();
        console.log('RewardsDistributor address: ', rewardsDistributor.address)
        return rewardsDistributor.address;
    } catch (error) {
        console.log("error in deploying rewardsDiastributer: ", error);
    }
    
}

const deployMinterUpgradeable = async(voterV3Address, rewardsDistributorAddress) => {
    try {
        const minterUpgradableContractFactory = await ethers.getContractFactory("MinterUpgradeable");
        const inputs = [voterV3Address, votingEscrowAddress, rewardsDistributorAddress]
        const minterUpgradeable = await upgrades.deployProxy(minterUpgradableContractFactory, inputs, {initializer: 'initialize'});
        const txDeployed = await minterUpgradeable.deployed();
        console.log('minterUpgradeable address: ', minterUpgradeable.address)
        return minterUpgradeable.address;
    } catch (error) {
        console.log("error in deploying minterUpgradeable: ", error);
    }
}

const createGauges = async(voterV3Address) => {
    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address);

    // creating gauge for pair bwn - token one and token two - basic volatile pool
    const blackHoleAllPairContract =  await ethers.getContractAt(blackHolePairApiV2Abi, blackHolePairApiV2ProxyAddress);
    const allPairs = await blackHoleAllPairContract.getAllPair(owner.address, BigInt(1000), BigInt(0));
    const pairs = allPairs[2];

    for(const p of pairs){
        const currentAddress = p[0];
        if(currentAddress === ZERO_ADDRESS)
            break;

        console.log("current pair ", currentAddress);
        const currentGaugeAddress = await voterV3Contract.gauges(currentAddress);
        console.log("currentGaugeAddress", currentGaugeAddress);
        if(currentGaugeAddress === ZERO_ADDRESS){
            const createGaugeTx = await voterV3Contract.createGauge(currentAddress, BigInt(0), {
                gasLimit: 21000000
            });
            console.log('createdgaugetx', createGaugeTx);
        }
    }
    console.log('done creation of gauge tx')
}

const deployBribeV3Factory = async () => {
    try {
        const bribeContractFactory = await ethers.getContractFactory("BribeFactoryV3");
        const input = [ZERO_ADDRESS, permissionsRegistryAddress]
        const BribeFactoryV3 = await upgrades.deployProxy(bribeContractFactory, input, {initializer: 'initialize'});
        const txDeployed = await BribeFactoryV3.deployed();
        console.log('deployed bribefactory v3: ', BribeFactoryV3.address)
        return BribeFactoryV3.address;
    } catch (error) {
        console.log("error in deploying bribeV3: ", error);
    }
}

const deployGaugeV2Factory = async () => {
    try {
        const gaugeContractFactory = await ethers.getContractFactory("GaugeFactoryV2");
        const input = [permissionsRegistryAddress]
        const GaugeFactoryV2 = await upgrades.deployProxy(gaugeContractFactory, input, {initializer: 'initialize'});
        const txDeployed = await GaugeFactoryV2.deployed();
        console.log('deployed GaugeFactoryV2: ', GaugeFactoryV2.address, txDeployed)
        return GaugeFactoryV2.address
    } catch (error) {
        console.log("error in deploying gaugeV2: ", error)
    }
}

const setMinterUpgradableInVoterV3 = async(voterV3Address, minterUpgradableAddress)=>{
    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address);
    await voterV3Contract.setMinter(minterUpgradableAddress);
    console.log('set minter in voterV3Contract');
}

const setMinterInThena = async(minterUpgradableAddress) => {
    const thenaContract = await ethers.getContractAt(thenaAbi, thenaAddress);
    await thenaContract.setMinter(minterUpgradableAddress);
    console.log('set minter in Thena');
}

const setMinterInRewardDistributer = async(minterUpgradableAddress, rewardsDistributorAddress) => {
    await rewardsDistributorAddress.setDepositor(minterUpgradableAddress);
    console.log('set depositor in rewardDistributer');
}

const initializeMinter = async (minterUpgradableAddress) => {
    try {
        const minterContract = await ethers.getContractAt(minterUpgradableAbi, minterUpgradableAddress);
        const initializingTx = await minterContract._initialize(
            [],
            [],
            0
        );
        await initializingTx.wait();
        console.log("Done initializing minter post deployment")
    } catch (error) {
        
    }
}

async function main () {

    accounts = await ethers.getSigners();
    owner = accounts[0];
    const ownerAddress = owner.address;
    
    //deploy bribeV3
    const bribeV3Address = await deployBribeV3Factory();

    //deploygaugeV2
    const gaugeV2Address = await deployGaugeV2Factory();

    // //deploy voterV3 and initialize
    const voterV3Address = await deployVoterV3AndSetInit(ownerAddress, bribeV3Address, gaugeV2Address);

    //setVoter in bribe factory
    await setVoterBribeV3(voterV3Address, bribeV3Address);

    //deploy rewardsDistributor
    const rewardsDistributorAddress = await deployRewardsDistributor();

    //set depositor

    //deploy minterUpgradable
    const minterUpgradableAddress = await deployMinterUpgradeable(voterV3Address, rewardsDistributorAddress);

    //set MinterUpgradable in VoterV3
    await setMinterUpgradableInVoterV3(voterV3Address, minterUpgradableAddress);

    // call _initialize
    await initializeMinter(minterUpgradableAddress);

    //set minter in thena
    await setMinterInThena(minterUpgradableAddress);

    await setMinterInRewardDistributer(minterUpgradableAddress, rewardsDistributorAddress); //set as depositor

    //create Gauges
    await createGauges(voterV3Address);

    // We need to add epoch controller here.
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
