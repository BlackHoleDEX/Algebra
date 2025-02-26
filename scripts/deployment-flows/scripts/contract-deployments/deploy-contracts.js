const { ethers } = require("hardhat")
const { bribeFactoryV3Abi } = require('../../../../generated/bribe-factory-v3')
const { permissionsRegistryAbi } = require('../../../../generated/permissions-registry')
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackholePairAPIV2Abi } = require('../../../../generated/blackhole-pair-apiv2');
const { voterV3Abi } = require('../../../../generated/voter-v3');
const { minterUpgradeableAbi } = require('../../../../generated/minter-upgradeable');
const { epochControllerAbi } = require('../../../../generated/epoch-controller')
const { blackAbi } = require('../../../blackhole-scripts/gaugeConstants/black')
const { votingEscrowAbi } = require('../../../../generated/voting-escrow');
const { gaugeFactoryV2Abi, gaugeFactoryV2Address } = require('../../../../generated/gauge-factory-v2');
const { rewardsDistributorAbi } = require('../../../../generated/rewards-distributor');
const { addLiquidity } = require('../../../blackhole-scripts/addLiquidity')
const { BigNumber } = require("ethers");
const { pairFactoryUpgradeableAbi } = require('../../../../generated/pair-factory-upgradeable');

const { generateConstantFile } = require('../../../blackhole-scripts/postDeployment/generator');
const fs = require('fs');
const path = require('path');

// Load the JSON file
const jsonFilePath = path.join(__dirname, '../../token-constants/deploying-tokens.json'); // Adjust the path
const jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
// Extract addresses
const addresses = jsonData.map(obj => obj.address);
const deployedTokens = require('../../token-constants/deployed-tokens.json');
const { pairFactoryAddress } = require("../../../blackhole-scripts/dexAbi");
const blackAddress = deployedTokens[0].address;
console.log("Extracted Addresses: ", addresses);

const deployPairGenerator = async () => {
    try {
        const pairGeneratorContract = await ethers.getContractFactory("PairGenerator");
        const pairGenerator = await pairGeneratorContract.deploy();
        txDeployed = await pairGenerator.deployed();
        console.log("pairFactory: ", pairGenerator.address)
        generateConstantFile("PairGenerator", pairGenerator.address);
        return pairGenerator.address;
    } catch (error) {
        console.log("error in deploying pairGenerator: ", error)
    }
}

const deployPairFactory = async (pairGeneratorAddress) => {
    try {
        const pairFactoryContract = await ethers.getContractFactory("PairFactoryUpgradeable");
        const inputs = [pairGeneratorAddress];
        const pairFactory = await upgrades.deployProxy(pairFactoryContract,inputs,{initializer: 'initialize'});
        txDeployed = await pairFactory.deployed();
        console.log("pairFactory: ", pairFactory.address)
        generateConstantFile("PairFactoryUpgradeable", pairFactory.address);
        return pairFactory.address;
    } catch (error) {
        console.log("error in deploying pairFactory: ", error)
    }
    
}

const deployRouterV2 = async(pairFactoryAddress) => {
    try {
        const wETH = '0x4200000000000000000000000000000000000006'
        const routerV2Contract = await ethers.getContractFactory("RouterV2");
        const routerV2 = await routerV2Contract.deploy(pairFactoryAddress, wETH);
        txDeployed = await routerV2.deployed();
        console.log("routerV2 address: ", routerV2.address)
        generateConstantFile("RouterV2", routerV2.address);
        return routerV2.address;
    } catch (error) {
        console.log("error in deploying routerV2: ", error)
    }
    
}

const setDibs = async (pairFactoryAddress) =>{
   try {
        const owner = await ethers.getSigners();
        const PairFactoryContract = await ethers.getContractAt(pairFactoryUpgradeableAbi, pairFactoryAddress);
        const tx = await PairFactoryContract.setDibs(owner[0].address);
        await tx.wait();
   } catch (error) {
        console.log("error in setting dibs: ", error)
   }
}

const deployPermissionRegistry = async() =>{
    try {
        const permissionRegistryContract = await ethers.getContractFactory("PermissionsRegistry");
        const permissionsRegistry = await permissionRegistryContract.deploy();
        const txDeployed = await permissionsRegistry.deployed();
        console.log("permissionsRegistry: ", permissionsRegistry.address)
        generateConstantFile("PermissionsRegistry", permissionsRegistry.address);
        return permissionsRegistry.address;
    } catch (error) {
        console.log("error in deploying permissionRegistry: ", error)
    }
}

const deployBloackholeV2Abi = async(voterV3Address, routerV2Address)=>{
    try {
        const blackholePairAbiV2Contract = await ethers.getContractFactory("BlackholePairAPIV2");
        const input = [voterV3Address, routerV2Address]
        const blackHolePairAPIV2Factory = await upgrades.deployProxy(blackholePairAbiV2Contract, input, {initializer: 'initialize'});
        txDeployed = await blackHolePairAPIV2Factory.deployed();
        console.log('BlackHolePairAPIV2Factory : ', blackHolePairAPIV2Factory.address)
        generateConstantFile("BlackholePairAPIV2", blackHolePairAPIV2Factory.address);
        return blackHolePairAPIV2Factory.address;
    } catch (error) {
        console.log("error in deploying deployBloackholeV2Abi: ", error)
    }
}

const setPermissionRegistryRoles = async (permissionRegistryAddress, ownerAddress) => {
    const permissionRegistryContract = await ethers.getContractAt(permissionsRegistryAbi, permissionRegistryAddress);
    const permissionRegistryRolesInStringFormat = await permissionRegistryContract.rolesToString();

    for (const element of permissionRegistryRolesInStringFormat) {
        try {
            const setRoleTx = await permissionRegistryContract.setRoleFor(ownerAddress, element, {
                gasLimit: 21000000,
            });
            await setRoleTx.wait(); // Wait for the transaction to be mined
        } catch (err) {
            console.log('Error in setRoleFor in permissionRegistry:', err);
        }
    }
};

const setGenesisManagerRole = async (permissionRegistryAddress, genesisPoolAddress) => {
    const permissionRegistryContract = await ethers.getContractAt(permissionsRegistryAbi, permissionRegistryAddress);

    try {
        const setRoleTx = await permissionRegistryContract.setRoleFor(genesisPoolAddress, "GENESIS_MANAGER", {
            gasLimit: 21000000,
        });
        await setRoleTx.wait(); // Wait for the transaction to be mined
    } catch (err) {
        console.log('Error in setRoleFor in permissionRegistry:', err);
    }
};


const deployVotingEscrow = async(blackAddress) =>{
    try {
        const VeArtProxyUpgradeableContract = await ethers.getContractFactory("VeArtProxyUpgradeable");
        const veArtProxy = await upgrades.deployProxy(VeArtProxyUpgradeableContract,[], {initializer: 'initialize'});
        txDeployed = await veArtProxy.deployed();
        console.log("veArtProxy Address: ", veArtProxy.address)
        generateConstantFile("VeArtProxyUpgradeable", veArtProxy.address);

        const VotingEscrowContract = await ethers.getContractFactory("VotingEscrow");
        const veBlack = await VotingEscrowContract.deploy(blackAddress, veArtProxy.address);
        txDeployed = await veBlack.deployed();
        console.log("veBlack Address: ", veBlack.address);
        generateConstantFile("VotingEscrow", veBlack.address);
        return veBlack.address;
    } catch (error) {
        console.log("error in deploying veArtProxy: ", error)
    }
    
}

const deployVoterV3AndSetInit = async (votingEscrowAddress, permissionRegistryAddress, pairFactoryAddress, ownerAddress, bribeFactoryV3Address, gaugeV2Address) => {
    try {
        const voterV3ContractFactory = await ethers.getContractFactory("VoterV3");
        const inputs = [votingEscrowAddress, pairFactoryAddress , gaugeV2Address, bribeFactoryV3Address]
        const VoterV3 = await upgrades.deployProxy(voterV3ContractFactory, inputs, {initializer: 'initialize'});
        const txDeployed = await VoterV3.deployed();
        console.log('VoterV3 address: ', VoterV3.address)
        const listOfTokens = [...addresses, blackAddress];
        const initializeVoter = await VoterV3._init(listOfTokens, permissionRegistryAddress, ownerAddress)
        generateConstantFile("VoterV3", VoterV3.address);
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

const deployRewardsDistributor = async(votingEscrowAddress) => {
    try {
        const rewardsDistributorContractFactory = await ethers.getContractFactory("RewardsDistributor");
        const rewardsDistributor = await rewardsDistributorContractFactory.deploy(votingEscrowAddress);
        const txDeployed = await rewardsDistributor.deployed();
        console.log('RewardsDistributor address: ', rewardsDistributor.address)
        generateConstantFile("RewardsDistributor", rewardsDistributor.address);
        return rewardsDistributor.address;
    } catch (error) {
        console.log("error in deploying rewardsDiastributer: ", error);
    }
    
}

const deployMinterUpgradeable = async(votingEscrowAddress, voterV3Address, rewardsDistributorAddress) => {
    try {
        const minterUpgradableContractFactory = await ethers.getContractFactory("MinterUpgradeable");
        const inputs = [voterV3Address, votingEscrowAddress, rewardsDistributorAddress]
        const minterUpgradeable = await upgrades.deployProxy(minterUpgradableContractFactory, inputs, {initializer: 'initialize'});
        const txDeployed = await minterUpgradeable.deployed();
        console.log('minterUpgradeable address: ', minterUpgradeable.address)
        generateConstantFile("MinterUpgradeable", minterUpgradeable.address);
        return minterUpgradeable.address;
    } catch (error) {
        console.log("error in deploying minterUpgradeable: ", error);
    }
}

const createGauges = async(voterV3Address, blackholeV2AbiAddress) => {

    // creating gauge for pair bwn - token one and token two - basic volatile pool
    const blackHoleAllPairContract =  await ethers.getContractAt(blackholePairAPIV2Abi, blackholeV2AbiAddress);
    console.log("blackHoleAllPairContract fetched");
    const allPairs = await blackHoleAllPairContract.getAllPair(owner.address, BigInt(100), BigInt(0));
    console.log("All pairs fetched");
    const pairs = allPairs[2];

    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address);

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

        }
    }
    console.log('done creation of gauge tx')
}

const deployBribeV3Factory = async (permissionRegistryAddress) => {
    try {
        const bribeContractFactory = await ethers.getContractFactory("BribeFactoryV3");
        const input = [ZERO_ADDRESS, permissionRegistryAddress]
        const BribeFactoryV3 = await upgrades.deployProxy(bribeContractFactory, input, {initializer: 'initialize'});
        const txDeployed = await BribeFactoryV3.deployed();
        console.log('deployed bribefactory v3: ', BribeFactoryV3.address)
        generateConstantFile("BribeFactoryV3", BribeFactoryV3.address);
        return BribeFactoryV3.address;
    } catch (error) {
        console.log("error in deploying bribeV3: ", error);
    }
}

const deployGaugeV2Factory = async (permissionRegistryAddress) => {
    try {
        const gaugeContractFactory = await ethers.getContractFactory("GaugeFactoryV2");
        const input = [permissionRegistryAddress]
        const GaugeFactoryV2 = await upgrades.deployProxy(gaugeContractFactory, input, {initializer: 'initialize'});
        const txDeployed = await GaugeFactoryV2.deployed();
        console.log('deployed GaugeFactoryV2: ', GaugeFactoryV2.address);
        generateConstantFile("GaugeFactoryV2", GaugeFactoryV2.address);
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

const setMinterInBlack = async(minterUpgradableAddress, blackAddress) => {
    const blackContract = await ethers.getContractAt(blackAbi, blackAddress);
    await blackContract.setMinter(minterUpgradableAddress);
    console.log('set minter in Black');
}

const setMinterInRewardDistributer = async(minterUpgradableAddress, rewardsDistributorAddress) => {
    const rewardDistributerContract = await ethers.getContractAt(rewardsDistributorAbi, rewardsDistributorAddress);
    await rewardDistributerContract.setDepositor(minterUpgradableAddress);
    console.log('set depositor in rewardDistributer');
}

const initializeMinter = async (minterUpgradableAddress) => {
    try {
        const minterContract = await ethers.getContractAt(minterUpgradeableAbi, minterUpgradableAddress);
        const mintAmount = BigNumber.from("100000").mul(BigNumber.from("1000000000000000000"));
        console.log("mintAmount ", mintAmount)
        const initializingTx = await minterContract._initialize(
            [],
            [],
            mintAmount
        );
        await initializingTx.wait();
        console.log("Done initializing minter post deployment")
    } catch (error) {
        console.log("error in initializing black value ", error)
    }
}

const deployEpochController = async(voterV3Address, minterUpgradableAddress) =>{
    try {
        data = await ethers.getContractFactory("EpochController");
        const EpochController = await upgrades.deployProxy(data, [], {initializer: 'initialize'});
        txDeployed = await EpochController.deployed();
        generateConstantFile("EpochController", EpochController.address);
        console.log('deployed EpochController: ', EpochController.address);

        await EpochController.setVoter(voterV3Address);
        console.log('Voter set in EpochController');
        await EpochController.setMinter(minterUpgradableAddress);
        console.log('minter set in EpochController');
        return EpochController.address;
    } catch (error) {
        console.log("error in deploying EpochController: ", error)
    }
}

const setChainLinkAddress = async (epocControllerAddress, chainlinkAutomationRegistryAddress) => {
    try{
        const epochController = await ethers.getContractAt(epochControllerAbi, epocControllerAddress);
        await epochController.setAutomationRegistry(chainlinkAutomationRegistryAddress);
        console.log("setChainLinkAddress succes");
    } catch(error){
        console.log("setChainLinkAddress failed: ", error);
    }
}

const addBlackToUserAddress = async (minterUpgradableAddress) => {
    try {
        const minterContract = await ethers.getContractAt(minterUpgradeableAbi, minterUpgradableAddress);
        const amountAdd = BigNumber.from("5000").mul(BigNumber.from("1000000000000000000"));
        await minterContract.transfer("0xa7243fc6FB83b0490eBe957941a339be4Db11c29", amountAdd);
        console.log("transfer token successfully");
    } catch (error) {
        console.log("error in transfering token: ", error);
    }
    
}

const setVoterV3InVotingEscrow = async(voterV3Address, votingEscrowAddress) => {
    try {
        const VotingEscrowContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
        await VotingEscrowContract.setVoter(voterV3Address);
        console.log("set voterV3 in voting escrow");
    } catch (error) {
        console.log("error voterV3 in voting escrow", error);
    }
}

const deployveNFT = async (voterV3Address, rewardsDistributorAddress, gaugeV2Address) => {
    try {
        data = await ethers.getContractFactory("veNFTAPI");
        input = [voterV3Address, rewardsDistributorAddress, gaugeV2Address] 
        const veNFTAPI = await upgrades.deployProxy(data, input, {initializer: 'initialize', gasLimit:210000000});
        txDeployed = await veNFTAPI.deployed();

        generateConstantFile("veNFTAPI", veNFTAPI.address);
        console.log('deployed venftapi address: ', veNFTAPI.address)
    } catch (error) {
        console.log('deployed venftapi error ', error)
    }
}

const pushDefaultRewardToken = async (bribeFactoryV3Address, blackAddress) => {
    const BribeFactoryV3Contract = await ethers.getContractAt(bribeFactoryV3Abi, bribeFactoryV3Address);
    await BribeFactoryV3Contract.pushDefaultRewardToken(blackAddress);
}

const deployBlackClaim = async (votingEscrowAddress, treasury) => {
    try {
        const BlackClaimsContract = await ethers.getContractFactory("BlackClaims");
        const BlackClaims = await BlackClaimsContract.deploy(treasury, votingEscrowAddress);
        const txDeployed =  await BlackClaims.deployed();

        console.log("BlackClaims address: ", BlackClaims.address)
        generateConstantFile("BlackClaims", BlackClaims.address);
        return BlackClaims.address;
    } catch (error) {
        console.log("error in deploying Black Claims: ", error);
    }
}

const deployGenesisPool = async (routerV2Address, epochControllerAddress, voterV3Address, pairFactoryAddress, tokenHandlerAddress, permissionRegistryAddress) => {
    try {
        console.log("deploying 1")
        const genesisPoolContract = await ethers.getContractFactory("GenesisPoolManager");
        input = [routerV2Address, epochControllerAddress, voterV3Address, pairFactoryAddress, tokenHandlerAddress, permissionRegistryAddress];
        console.log("deploying 2")
        const genesisPool = await upgrades.deployProxy(genesisPoolContract, input, {initializer: 'initialize', gasLimit:210000000});
        console.log("deploying 3")
        const txDeployed = await genesisPool.deployed();
        console.log("deploying 4")

        console.log("Genesis Pool address: ", genesisPool.address)
        generateConstantFile("GenesisPoolManager", genesisPool.address);
        return genesisPool.address;
    } catch (error) {
        console.log("error in deploying Genesis Pool : ", error);
    }
}

const setGenesisPoolManagerInGaugeFactory = async(gaugeV2Address, genesisPoolAddress) => {
    try {
        const GaugeFactoryContract = await ethers.getContractAt(gaugeFactoryV2Abi, gaugeV2Address);
        await GaugeFactoryContract.setGenesisPool(genesisPoolAddress);
        console.log("set genesis pool in gauge factory");
    } catch (error) {
        console.log("error genesis pool in gauge factory", error);
    }
}

const setGenesisPoolManagerInPairFactory = async(pairFactoryAddress, genesisPoolAddress) => {
    try {
        const PairFactoryContract = await ethers.getContractAt(pairFactoryUpgradeableAbi, pairFactoryAddress);
        await PairFactoryContract.setGenesisPool(genesisPoolAddress);
        console.log("set genesis pool in pair factory");
    } catch (error) {
        console.log("error genesis pool in pair factory", error);
    }
}

const deployDucthAction = async (genesisPoolAddress) => {
    try {
        const dutchAuctionContract = await ethers.getContractFactory("DutchAction");
        input = [genesisPoolAddress];

        const dutchAuction = await upgrades.deployProxy(dutchAuctionContract, input, {initializer: 'initialize', gasLimit:210000000});
        const txDeployed = await dutchAuction.deployed();

        console.log("Genesis Pool address: ", dutchAuction.address)
        generateConstantFile("DutchAction", dutchAuction.address);
        return dutchAuction.address;
    } catch (error) {
        console.log("error in deploying dutch aution : ", error);
    }
}

const setDutchAuctioninGenesisPool = async (genesisPoolAddress, dutchAuctionAddress) => {
    // try {
    //     const VotingEscrowContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
    //     await VotingEscrowContract.setVoter(voterV3Address);
    //     console.log("set voterV3 in voting escrow");
    // } catch (error) {
    //     console.log("error voterV3 in voting escrow", error);
    // }
}

const deployGenesisApi = async (genesisPoolAddress) => {
    try {
        data = await ethers.getContractFactory("GenesisPoolAPI");
        input = [genesisPoolAddress] 
        const genesisApi = await upgrades.deployProxy(data, input, {initializer: 'initialize', gasLimit:210000000});
        txDeployed = await genesisApi.deployed();

        generateConstantFile("GenesisPoolAPI", genesisApi.address);
        console.log('deployed genesis pool API address: ', genesisApi.address)
    } catch (error) {
        console.log('error genesis pool API  ', error)
    }
}

async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    const ownerAddress = owner.address;

    console.log("Black token address is: ", blackAddress);

    //deploy permissionRegistry
    const permissionRegistryAddress = await deployPermissionRegistry();

    const tokenHandlerAddress = await deployTokenHanlder(permissionRegistryAddress);

    const pairGeneratorAddress = await deployPairGenerator();

    //deploy pairFactory
    const pairFactoryAddress = await deployPairFactory(pairGeneratorAddress);

    //deploy router V2
    const routerV2Address = await deployRouterV2(pairFactoryAddress);

    //setDibs
    await setDibs(pairFactoryAddress);

    //deploy voting  escrow
    const votingEscrowAddress = await deployVotingEscrow(blackAddress);

    //set owner roles in permission registry
    await setPermissionRegistryRoles(permissionRegistryAddress, ownerAddress);
    
    //deploy bribeV3
    const bribeV3Address = await deployBribeV3Factory(permissionRegistryAddress);

    //deploygaugeV2
    const gaugeV2Address = await deployGaugeV2Factory(permissionRegistryAddress);

    // //deploy voterV3 and initialize
    const voterV3Address = await deployVoterV3AndSetInit(votingEscrowAddress, permissionRegistryAddress, pairFactoryAddress, ownerAddress, bribeV3Address, gaugeV2Address);

    //setVoter in bribe factory
    await setVoterBribeV3(voterV3Address, bribeV3Address);

    // // blackholeV2Abi deployment
    const blackholeV2AbiAddress = await deployBloackholeV2Abi(voterV3Address, routerV2Address);

    //deploy rewardsDistributor
    const rewardsDistributorAddress = await deployRewardsDistributor(votingEscrowAddress);

    //deploy veNFT
    await deployveNFT(voterV3Address, rewardsDistributorAddress, gaugeV2Address);

    //deploy minterUpgradable
    const minterUpgradableAddress = await deployMinterUpgradeable(votingEscrowAddress, voterV3Address, rewardsDistributorAddress);

    //set MinterUpgradable in VoterV3
    await setMinterUpgradableInVoterV3(voterV3Address, minterUpgradableAddress);

    //set minter in black
    await setMinterInBlack(minterUpgradableAddress, blackAddress);

    // await logActivePeriod();

    // call _initialize
    await initializeMinter(minterUpgradableAddress);

    // await logActivePeriod();

    //set minter in reward distributer in depositer
    await setMinterInRewardDistributer(minterUpgradableAddress, rewardsDistributorAddress); //set as depositor

    // deploy epoch controller here.
    const epochControllerAddress = await deployEpochController(voterV3Address, minterUpgradableAddress);

    // set chainlink address
    await setChainLinkAddress(epochControllerAddress, "0x03eb20259251F324f5b1cba988754656B6BbE96F");

    //add black to user Address
    await addBlackToUserAddress(minterUpgradableAddress);

    //set voterV3 in voting escrow
    await setVoterV3InVotingEscrow(voterV3Address, votingEscrowAddress);

    await pushDefaultRewardToken(bribeV3Address, blackAddress);

    const blackClaimAddress = await deployBlackClaim(votingEscrowAddress, ownerAddress);

    const genesisPoolAddress = deployGenesisPool(routerV2Address, epochControllerAddress, voterV3Address, pairFactoryAddress, tokenHandlerAddress, permissionRegistryAddress);

    await setGenesisManagerRole(permissionRegistryAddress, genesisPoolAddress);

    await setGenesisPoolManagerInGaugeFactory(gaugeFactoryV2Address, genesisPoolAddress);

    await setGenesisPoolManagerInPairFactory(pairFactoryAddress, genesisPoolAddress);

    const dutchAuctionAddress = deployDucthAction(genesisPoolAddress);

    await setDutchAuctioninGenesisPool(genesisPoolAddress, dutchAuctionAddress);

    await deployGenesisApi(genesisPoolAddress);

    //createPairs two by default
    await addLiquidity(routerV2Address, addresses[0], addresses[1], 100, 100);
    await addLiquidity(routerV2Address, addresses[1], addresses[2], 100, 100);
    await addLiquidity(routerV2Address, addresses[2], addresses[3], 100, 100);

    //create Gauges
    await createGauges(voterV3Address, blackholeV2AbiAddress);
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
