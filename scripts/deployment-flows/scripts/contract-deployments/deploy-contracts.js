const { ethers } = require("hardhat")
const { bribeFactoryV3Abi } = require('../../../../generated/bribe-factory-v3')
const { permissionsRegistryAbi } = require('../../../../generated/permissions-registry')
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants.js");
const { blackholePairAPIV2Abi } = require('../../../../generated/blackhole-pair-apiv2');
const { voterV3Abi } = require('../../../../generated/voter-v3');
const { minterUpgradeableAbi, minterUpgradeableAddress } = require('../../../../generated/minter-upgradeable');
const { epochControllerAbi } = require('../../../../generated/epoch-controller')
const { blackAbi } = require('../../../blackhole-scripts/gaugeConstants/black')
const { votingEscrowAbi } = require('../../../../generated/voting-escrow');
const { tokenHandlerAbi } = require('../../../../generated/token-handler');
const { rewardsDistributorAbi } = require('../../../../generated/rewards-distributor');
const { pairFactoryUpgradeableAbi } = require('../../../../generated/pair-factory-upgradeable');
const { genesisPoolFactoryAbi } = require('../../../../generated/genesis-pool-factory');
const { addLiquidity } = require('../../../blackhole-scripts/addLiquidity')
const { BigNumber } = require("ethers");

const { generateConstantFile } = require('../../../blackhole-scripts/postDeployment/generator');
const fs = require('fs');
const path = require('path');

// Load the JSON file
const jsonFilePath = path.join(__dirname, '../../token-constants/deploying-tokens.json'); // Adjust the path
const jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));
// Extract addresses
const addresses = jsonData.map(obj => obj.address);

const deployedTokens = require('../../token-constants/deployed-tokens.json');
const { routerV2Abi } = require("../../../../generated/router-v2");
const blackAddress = deployedTokens[0].address;
console.log("Extracted Addresses: ", addresses);

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
        process.exit(1);
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
            console.log(`Role ${ownerAddress} = ${element}`);
        } catch (err) {
            console.log('Error in setRoleFor in permissionRegistry:', err);
            process.exit(1);
        }
    }
};

const deployTokenHanlder = async (permissionRegistryAddress) => {
    const tokens = [...addresses, blackAddress];
    const connectorTokens = [...addresses, blackAddress];
    
    try {
        const tokenHandlerContract = await ethers.getContractFactory("TokenHandler");
        const tokenHandler = await tokenHandlerContract.deploy(permissionRegistryAddress);
        const txDeployed = await tokenHandler.deployed();

        console.log("\ntoken handler address : ", tokenHandler.address)
        generateConstantFile("TokenHandler", tokenHandler.address);

        await tokenHandler.whitelistTokens(tokens);
        console.log("set tokens in token handler");
        await tokenHandler.whitelistConnectors(connectorTokens);
        console.log("set connector tokens in token handler\n");


        return tokenHandler.address;
    } catch (error) {
        console.log("error in deploying token handler: ", error)
        process.exit(1);
    }
}

const deployPairGenerator = async () => {
    try {
        const pairGeneratorContract = await ethers.getContractFactory("PairGenerator");
        const pairGenerator = await pairGeneratorContract.deploy();
        txDeployed = await pairGenerator.deployed();
        console.log("PairGenerator: ", pairGenerator.address)
        generateConstantFile("PairGenerator", pairGenerator.address);
        return pairGenerator.address;
    } catch (error) {
        console.log("error in deploying pairGenerator: ", error);
        process.exit(1);
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
        process.exit(1);
    }
    
}

const deployRouterV2 = async(pairFactoryAddress, pairGeneratorAddress) => {
    try {
        const wETH = '0x4200000000000000000000000000000000000006'
        const routerV2Contract = await ethers.getContractFactory("RouterV2");
        const routerV2 = await routerV2Contract.deploy(pairFactoryAddress, pairGeneratorAddress, wETH);
        txDeployed = await routerV2.deployed();
        console.log("routerV2 address: ", routerV2.address)
        generateConstantFile("RouterV2", routerV2.address);
        return routerV2.address;
    } catch (error) {
        console.log("error in deploying routerV2: ", error)
        process.exit(1);
    }
    
}

const setDibs = async (pairFactoryAddress) =>{
   try {
        const owner = await ethers.getSigners();
        const PairFactoryContract = await ethers.getContractAt(pairFactoryUpgradeableAbi, pairFactoryAddress);
        const tx = await PairFactoryContract.setDibs(owner[0].address);
        await tx.wait();
        console.log("setDibs\n");
   } catch (error) {
        console.log("error in setting dibs: ", error)
        process.exit(1);
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
        console.log("error in deploying deployBloackholeV2Abi: ", error);
        process.exit(1);
    }
}


const deployVotingEscrow = async(blackAddress) =>{
    try {
        const VeArtProxyUpgradeableContract = await ethers.getContractFactory("VeArtProxyUpgradeable");
        const veArtProxy = await upgrades.deployProxy(VeArtProxyUpgradeableContract,[], {initializer: 'initialize'});
        txDeployed = await veArtProxy.deployed();
        console.log("veArtProxy Address: ", veArtProxy.address)
        generateConstantFile("VeArtProxyUpgradeable", veArtProxy.address);

        const VotingEscrowContract = await ethers.getContractFactory("VotingEscrow");
        const veBlack = await VotingEscrowContract.deploy(blackAddress, veArtProxy.address, ZERO_ADDRESS);
        txDeployed = await veBlack.deployed();
        console.log("veBlack Address: ", veBlack.address);
        generateConstantFile("VotingEscrow", veBlack.address);
        return veBlack.address;
    } catch (error) {
        console.log("error in deploying veArtProxy: ", error);
        process.exit(1);
    }
    
}

const deployVoterV3AndSetInit = async (votingEscrowAddress, pairFactoryAddress, gaugeV2Address, bribeFactoryV3Address, tokenHandlerAddress, permissionRegistryAddress, ownerAddress) => {
    try {
        const voterV3ContractFactory = await ethers.getContractFactory("VoterV3");
        const inputs = [votingEscrowAddress, pairFactoryAddress , gaugeV2Address, bribeFactoryV3Address, tokenHandlerAddress]
        const VoterV3 = await upgrades.deployProxy(voterV3ContractFactory, inputs, {initializer: 'initialize'});
        const txDeployed = await VoterV3.deployed();

        console.log('VoterV3 address: ', VoterV3.address)
        generateConstantFile("VoterV3", VoterV3.address);

        const initializeVoter = await VoterV3._init(permissionRegistryAddress, ownerAddress);
        await initializeVoter.wait();

        console.log('VoterV3 init\n', )
        return VoterV3.address;
    } catch (error) {
        console.log("error in deploying voterV3: ", error);
        process.exit(1);
    }
    
}

const setVoterBribeV3 = async(voterV3Address, bribeFactoryV3Address) => {
    try {
        const bribeV3Contract = await ethers.getContractAt(bribeFactoryV3Abi, bribeFactoryV3Address);
        const createVoter = await bribeV3Contract.setVoter(voterV3Address);
        console.log('set VoterV3 in bribe\n');
    } catch (error) {
        console.log("error in setting voter in bribeV3: ", error);
        process.exit(1);
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
        process.exit(1);
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
        process.exit(1);
    }
}

const createGauges = async(voterV3Address, blackholeV2AbiAddress) => {

    // creating gauge for pair bwn - token one and token two - basic volatile pool
    const blackHoleAllPairContract =  await ethers.getContractAt(blackholePairAPIV2Abi, blackholeV2AbiAddress);
    const allPairs = await blackHoleAllPairContract.getAllPair(owner.address, BigInt(100), BigInt(0));
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
    console.log('done creation of gauge tx\n')
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
        process.exit(1);
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
        console.log("error in deploying gaugeV2: ", error);
        process.exit(1);
    }
}

const setMinterUpgradableInVoterV3 = async(voterV3Address, minterUpgradableAddress)=>{
    const voterV3Contract = await ethers.getContractAt(voterV3Abi, voterV3Address);
    await voterV3Contract.setMinter(minterUpgradableAddress);
    console.log('set minter in voterV3Contract\n');
}

const setMinterInBlack = async(minterUpgradableAddress, blackAddress) => {
    const blackContract = await ethers.getContractAt(blackAbi, blackAddress);
    await blackContract.setMinter(minterUpgradableAddress);
    console.log('set minter in Black\n');
}

const setMinterInRewardDistributer = async(minterUpgradableAddress, rewardsDistributorAddress) => {
    const rewardDistributerContract = await ethers.getContractAt(rewardsDistributorAbi, rewardsDistributorAddress);
    await rewardDistributerContract.setDepositor(minterUpgradableAddress);
    console.log('set depositor in rewardDistributer\n');
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
        console.log("Done initializing minter post deployment\n");
    } catch (error) {
        console.log("error in initializing black value ", error);
        process.exit(1);
    }
}

const deployEpochController = async(voterV3Address, minterUpgradableAddress) =>{
    try {
        data = await ethers.getContractFactory("EpochController");
        const EpochController = await upgrades.deployProxy(data, [], {initializer: 'initialize'});
        txDeployed = await EpochController.deployed();

        console.log('deployed EpochController: ', EpochController.address);
        generateConstantFile("EpochController", EpochController.address);

        await EpochController.setVoter(voterV3Address);
        console.log('Voter set in EpochController');
        await EpochController.setMinter(minterUpgradableAddress);
        console.log('minter set in EpochController\n');
        return EpochController.address;
    } catch (error) {
        console.log("error in deploying EpochController: ", error);
        process.exit(1);
    }
}

const setChainLinkAddress = async (epocControllerAddress, chainlinkAutomationRegistryAddress) => {
    try{
        const epochController = await ethers.getContractAt(epochControllerAbi, epocControllerAddress);
        await epochController.setAutomationRegistry(chainlinkAutomationRegistryAddress);
        console.log("setChainLinkAddress succes\n");
    } catch(error){
        console.log("setChainLinkAddress failed: ", error);
        process.exit(1);
    }
}

const addBlackToUserAddress = async (minterUpgradableAddress) => {
    try {
        const accounts = await ethers.getSigners();
        const owner = accounts[0];
        const minterContract = await ethers.getContractAt(minterUpgradeableAbi, minterUpgradableAddress);
        const amountAdd = BigNumber.from("5000").mul(BigNumber.from("1000000000000000000"));

        console.log("owner address", owner.address)
        // await minterContract.transfer("0xa7243fc6FB83b0490eBe957941a339be4Db11c29", amountAdd);
        await minterContract.transfer(owner.address, amountAdd);
        console.log("transfer token successfully");

    } catch (error) {
        console.log("error in transfering token: ", error);
        process.exit(1);
    }
    
}

const setVoterV3InVotingEscrow = async(voterV3Address, votingEscrowAddress) => {
    try {
        const VotingEscrowContract = await ethers.getContractAt(votingEscrowAbi, votingEscrowAddress);
        await VotingEscrowContract.setVoter(voterV3Address);
        console.log("set voterV3 in voting escrow\n");
    } catch (error) {
        console.log("error voterV3 in voting escrow", error);
        process.exit(1);
    }
}

const deployveNFT = async (voterV3Address, rewardsDistributorAddress, gaugeV2Address) => {
    try {
        data = await ethers.getContractFactory("veNFTAPI");
        input = [voterV3Address, rewardsDistributorAddress, gaugeV2Address] 
        const veNFTAPI = await upgrades.deployProxy(data, input, {initializer: 'initialize', gasLimit:210000000});
        txDeployed = await veNFTAPI.deployed();

        console.log('deployed venftapi address: ', veNFTAPI.address);
        generateConstantFile("veNFTAPI", veNFTAPI.address);
    } catch (error) {
        console.log('deployed venftapi error ', error)
        process.exit(1);
    }
}

const deployBlackGovernor = async(votingEscrowAddress, minterUpgradableAddress) => {
    try {
        const blackGovernorContract = await ethers.getContractFactory("BlackGovernor");
        const BlackGovernor = await blackGovernorContract.deploy(votingEscrowAddress, minterUpgradableAddress);
        const txDeployed = await BlackGovernor.deployed();
        generateConstantFile("BlackGovernor", BlackGovernor.address);
        console.log('BlackGovernor address: ', BlackGovernor.address);
    } catch (error) {
        console.log("error in deploying BlackGovernor: ", error);
    }
}

const pushDefaultRewardToken = async (bribeFactoryV3Address, blackAddress) => {
    const BribeFactoryV3Contract = await ethers.getContractAt(bribeFactoryV3Abi, bribeFactoryV3Address);
    await BribeFactoryV3Contract.pushDefaultRewardToken(blackAddress);
    console.log("pushDefaultRewardToken\n");
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
        process.exit(1);
    }
}

const deployFixedAuction = async () => {
    try {
        const fixedAuctionContract = await ethers.getContractFactory("FixedAuction");
        const fixedAuction = await fixedAuctionContract.deploy();
        const txDeployed = await fixedAuction.deployed();

        console.log("fixed auction address: ", fixedAuction.address)
        generateConstantFile("FixedAuction", fixedAuction.address);
        return fixedAuction.address;
    } catch (error) {
        console.log("error in deploying fixed aution : ", error);
        process.exit(1);
    }
}

const deployAuctionFacotry = async (fixedAuctionAddress) => {
    try {
        data = await ethers.getContractFactory("AuctionFactory");
        input = [fixedAuctionAddress] 
        const auctionFactory = await upgrades.deployProxy(data, input, {initializer: 'initialize', gasLimit:210000000});
        const txDeployed = await auctionFactory.deployed();

        console.log('deployed auction factory address : ', auctionFactory.address);
        generateConstantFile("AuctionFactory", auctionFactory.address);
        return auctionFactory.address;
    } catch (error) {
        console.log('deployed auction factory address : ', error);
        process.exit(1);
    }
}

const deployGenesisFactory = async (tokenHandlerAddress, voterV3Address) => {
    try {
        data = await ethers.getContractFactory("GenesisPoolFactory");
        input = [tokenHandlerAddress, voterV3Address] 
        const genesisFactory = await upgrades.deployProxy(data, input, {initializer: 'initialize', gasLimit:210000000});
        const txDeployed = await genesisFactory.deployed();

        console.log('deployed genesis factory address : ', genesisFactory.address);
        generateConstantFile("GenesisPoolFactory", genesisFactory.address);
        return genesisFactory.address;
    } catch (error) {
        console.log('deployed genesis factory address : ', error);
        process.exit(1);
    }
}

const deployGenesisManager = async (epochControllerAddress, routerV2Address, permissionRegistryAddress, voterV3Address, pairFactoryAddress, genesisFactoryAddress, auctionFactoryAddress, tokenHandlerAddress) => {
    try {
        const data = await ethers.getContractFactory("GenesisPoolManager");
        input = [epochControllerAddress, routerV2Address, permissionRegistryAddress, voterV3Address, pairFactoryAddress, genesisFactoryAddress, auctionFactoryAddress, tokenHandlerAddress];
        const genesisManager = await upgrades.deployProxy(data, input, {initializer: 'initialize', gasLimit:210000000});
        const txDeployed = await genesisManager.deployed();

        console.log("Genesis manager address : ", genesisManager.address)
        generateConstantFile("GenesisPoolManager", genesisManager.address);
        return genesisManager.address;
    } catch (error) {
        console.log("error in deploying Genesis manager : ", error);
        process.exit(1);
    }
}

const setGenesisManagerInGenesisFactory = async (genesisFactoryAddress, genesisManagerAddress) => {
    try {
        const genesisFactoryContract = await ethers.getContractAt(genesisPoolFactoryAbi, genesisFactoryAddress);
        await genesisFactoryContract.setGenesisManager(genesisManagerAddress);
        console.log("set genesis manager in genesis factory\n");
    } catch (error) {
        console.log("error genesis manager in genesis factory", error);
        process.exit(1);
    }
}

const setGenesisManagerRole = async (permissionRegistryAddress, genesisManagerAddress) => {
    const permissionRegistryContract = await ethers.getContractAt(permissionsRegistryAbi, permissionRegistryAddress);

    try {
        const setRoleTx = await permissionRegistryContract.setRoleFor(genesisManagerAddress, "GENESIS_MANAGER", {
            gasLimit: 21000000,
        });
        await setRoleTx.wait(); // Wait for the transaction to be mined
        console.log('setRoleFor in permissionRegistry\n');
    } catch (err) {
        console.log('Error in setRoleFor in permissionRegistry:', err);
        process.exit(1);
    }
};

const setGenesisPoolManagerInVoter = async(voterV3Address, genesisManagerAddress) => {
    try {
        const VoterContract = await ethers.getContractAt(voterV3Abi, voterV3Address);
        await VoterContract.setGenesisManager(genesisManagerAddress);
        console.log("set genesis manager in voter\n");
    } catch (error) {
        console.log("error genesis manager in gvoter", error);
        process.exit(1);
    }
};

const setGenesisPoolManagerInPairFactory = async(pairFactoryAddress, genesisManagerAddress) => {
    try {
        const PairFactoryContract = await ethers.getContractAt(pairFactoryUpgradeableAbi, pairFactoryAddress);
        await PairFactoryContract.setGenesisManager(genesisManagerAddress);
        console.log("set genesis manager in pair factory\n");
    } catch (error) {
        console.log("error genesis manager in pair factory", error);
        process.exit(1);
    }
};

const deployGenesisApi = async (genesisManagerAddress, genesisFactoryAddress) => {
    try {
        data = await ethers.getContractFactory("GenesisPoolAPI");
        input = [genesisManagerAddress, genesisFactoryAddress] 
        const genesisApi = await upgrades.deployProxy(data, input, {initializer: 'initialize', gasLimit:210000000});
        txDeployed = await genesisApi.deployed();

        console.log('deployed genesis pool API address: ', genesisApi.address);
        generateConstantFile("GenesisPoolAPI", genesisApi.address);
    } catch (error) {
        console.log('error genesis pool API  ', error);
        process.exit(1);
    }
}

const checker = async (routerV2Address, pairFactoryAddress) => {

    try {
        const RouterContract = await ethers.getContractAt(routerV2Abi, routerV2Address);
        const PairFactoryContract = await ethers.getContractAt(pairFactoryUpgradeableAbi, pairFactoryAddress);

        const tokenA = addresses[1] < addresses[2] ? addresses[1] : addresses[2];
        const tokenB = tokenA == addresses[1] ? addresses[2] : addresses[1];
        const stable = false;

        const tx = await PairFactoryContract.createPair(tokenA, tokenB, stable);
        const receipt = await tx.wait(); 
        const event = receipt.events.find(e => e.event === "PairCreated");
        const deployedPair = event.args.pair;

        const computedPair = await RouterContract.pairFor(tokenA, tokenB, stable);
    
        console.log("Deployed Pair:", deployedPair);
        console.log("Computed Pair:", computedPair);


        if (computedPair.toLowerCase() === deployedPair.toLowerCase()) {
            console.log("✅ Addresses Match!");
        } else {
            console.log("❌ Address Mismatch!");
        }

    } catch (error) {
        console.log("error genesis pool in genesis factory", error);
        process.exit(1);
    }
}

async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    const ownerAddress = owner.address;

    console.log("Black token address is: ", blackAddress);

    // deploy permissionRegistry
    const permissionRegistryAddress = await deployPermissionRegistry();

    //set owner roles in permission registry
    await setPermissionRegistryRoles(permissionRegistryAddress, ownerAddress);

    //deploy token handler & whitelist tokens and connectors
    const tokenHandlerAddress = await deployTokenHanlder(permissionRegistryAddress);

    //deploy pairGenerator
    const pairGeneratorAddress = await deployPairGenerator();

    //deploy pairFactory
    const pairFactoryAddress = await deployPairFactory(pairGeneratorAddress);

    //deploy router V2
    const routerV2Address = await deployRouterV2(pairFactoryAddress, pairGeneratorAddress);

    // setDibs
    await setDibs(pairFactoryAddress);

    //deploy voting  escrow
    const votingEscrowAddress = await deployVotingEscrow(blackAddress);
    
    //deploy bribeV3
    const bribeV3Address = await deployBribeV3Factory(permissionRegistryAddress);

    //deploygaugeV2
    const gaugeV2Address = await deployGaugeV2Factory(permissionRegistryAddress);

    // //deploy voterV3 and initialize
    const voterV3Address = await deployVoterV3AndSetInit(votingEscrowAddress, pairFactoryAddress, gaugeV2Address, bribeV3Address, tokenHandlerAddress, permissionRegistryAddress, ownerAddress);

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
    // TODO: separate out the setting of chalink address 
    await setChainLinkAddress(epochControllerAddress, "0xb2C2f24FcC2478f279B6B566419a739FA53c70D3");

    //add black to user Address
    await addBlackToUserAddress(minterUpgradableAddress);

    //set voterV3 in voting escrow
    await setVoterV3InVotingEscrow(voterV3Address, votingEscrowAddress);

    await deployBlackGovernor(votingEscrowAddress,minterUpgradeableAddress);

    await pushDefaultRewardToken(bribeV3Address, blackAddress);

    //deploy blackClaim
    const blackClaimAddress = await deployBlackClaim(votingEscrowAddress, ownerAddress);

    //deploy fixedAuction
    const fixedAuctionAddress = await deployFixedAuction();

    //deploy auctionFactory
    const auctionFactoryAddress = await deployAuctionFacotry(fixedAuctionAddress);

    //deploy genesisFactory
    const genesisFactoryAddress = await deployGenesisFactory(tokenHandlerAddress, voterV3Address);

    //deploy genesisManager
    const genesisManagerAddress = await deployGenesisManager(epochControllerAddress, routerV2Address, permissionRegistryAddress, voterV3Address, pairFactoryAddress, genesisFactoryAddress, auctionFactoryAddress, tokenHandlerAddress);

    //set genesisManager in genesisFactory
    await setGenesisManagerInGenesisFactory(genesisFactoryAddress, genesisManagerAddress);

    //assign genesisManager role of GENESIS_MANAGER
    await setGenesisManagerRole(permissionRegistryAddress, genesisManagerAddress);

    //set genesisManager in VoterV3
    await setGenesisPoolManagerInVoter(voterV3Address, genesisManagerAddress);

    //set genesisManager in pairFactory
    await setGenesisPoolManagerInPairFactory(pairFactoryAddress, genesisManagerAddress);

    //deploy GenesisApi
    await deployGenesisApi(genesisManagerAddress, genesisFactoryAddress);

    // await checker(routerV2Address, pairFactoryAddress);

    // createPairs two by default
    await addLiquidity(routerV2Address, addresses[0], addresses[1], 100, 100);
    await addLiquidity(routerV2Address, addresses[1], addresses[2], 100, 100);
    await addLiquidity(routerV2Address, addresses[2], addresses[3], 100, 100);
    await addLiquidity(routerV2Address, addresses[3], addresses[4], 10, 100);
    await addLiquidity(routerV2Address, addresses[4], addresses[5], 100, 10);

    console.log("DONE ADDING LIQUIDITY");

    // create Gauges
    await createGauges(voterV3Address, blackholeV2AbiAddress);
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
