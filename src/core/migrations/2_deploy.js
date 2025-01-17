const tronbox = require('../tronbox-config');

const AlgebraFactory = artifacts.require("AlgebraFactory.sol");
const AlgebraPoolDeployer = artifacts.require("AlgebraPoolDeployer.sol");
const AlgebraCommunityVault = artifacts.require('AlgebraCommunityVault');
const AlgebraVaultFactoryStub = artifacts.require('AlgebraVaultFactoryStub');

const deployerAddress = "TGq5GWxruUu47FaTcHLiX8oJGNtD8aRcoV"
const tronWeb = tronbox.tronWeb.nile

module.exports = async function(deployer) {

    await deployer.deploy(AlgebraFactory)
    console.log("AlgebraFactory deployed to:", AlgebraFactory.address)

    deployer.deploy(AlgebraPoolDeployer, AlgebraFactory.address).then(() => {
      console.log("AlgebraPoolDeployer deployed to:", AlgebraPoolDeployer.address)
    })

    await AlgebraFactory.setDeployerAddress(AlgebraPoolDeployer.address).send();
    console.log(
      `Check tx on the explorer: https://nile.tronscan.org/#/transaction/${txId}`
    );

    await deployer.deploy(
        AlgebraCommunityVault,
        tronWeb.address.toHex(AlgebraFactory.address), // factory
        tronWeb.address.toHex(deployerAddress) // deployer
    )
    await AlgebraCommunityVault.deployed()
    const vaultContract = await tronWeb.contract().at(tronWeb.address.fromHex(AlgebraCommunityVault.address))
    console.log("AlgebraCommunityVault deployed to:", AlgebraCommunityVault.address)

    await deployer.deploy(AlgebraVaultFactoryStub, AlgebraCommunityVault.address)
    const stub = await AlgebraVaultFactoryStub.deployed()
    console.log("AlgebraVaultFactoryStub deployed to:", AlgebraVaultFactoryStub.address)

    const factoryContract = await tronWeb.contract().at(AlgebraFactory.address);
    await factoryContract.setVaultFactory(stub.address).send();
    console.log("set vault factory to:", stub.address)

    const algebraFeeRecipient = tronWeb.address.toHex("TGq5GWxruUu47FaTcHLiX8oJGNtD8aRcoV")
    const partnerAddress = tronWeb.address.toHex("TGq5GWxruUu47FaTcHLiX8oJGNtD8aRcoV") // owner address, must be changed
    const algebraFeeShare =  1000 // specified on algebraVault, 100% of community fee by default(3% of all fees)
    const defaultCommunityFee = 30 // 3% by default

    await factoryContract.setDefaultCommunityFee(defaultCommunityFee).send();
    console.log("set default community fee to:", defaultCommunityFee)

    await vaultContract.changeAlgebraFeeReceiver(algebraFeeRecipient).send();
    console.log("set algebra fee receiver to:", algebraFeeRecipient)

    await vaultContract.changeCommunityFeeReceiver(partnerAddress).send();
    console.log("set community fee receiver to:", partnerAddress)

    await vaultContract.proposeAlgebraFeeChange(algebraFeeShare).send();
    await vaultContract.acceptAlgebraFeeChangeProposal(algebraFeeShare).send()

    await factoryContract.transferOwnership(partnerAddress).send();
    console.log("transfer ownership to:", partnerAddress)

    const deployDataPath = path.resolve(__dirname, '../../../deploys.json');
    let deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'));
    deploysData.poolDeployer = AlgebraPoolDeployer.address;
    deploysData.factory = AlgebraFactory.address;
    deploysData.vault = AlgebraCommunityVault.address;
    deploysData.vaultFactory = AlgebraVaultFactoryStub.address;
    fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
}