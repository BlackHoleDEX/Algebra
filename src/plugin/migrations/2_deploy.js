const tronbox = require('../tronbox-config');
const fs = require('fs')
const path = require('path')
const AlgebraPluginFactory = artifacts.require("BasePluginV1Factory");

const tronWeb = tronbox.tronWeb.nile

module.exports = async function(deployer) {

    const deployDataPath = path.resolve(__dirname, '../../../deploys.json')
    const deploysData = JSON.parse(fs.readFileSync(deployDataPath, 'utf8'))

    await deployer.deploy(AlgebraPluginFactory, deploysData.factory)
    console.log("AlgebraPluginFactory deployed to:", AlgebraPluginFactory.address)

    let factory = await tronWeb.contract().at(deploysData.factory);

    let txId = await factory.setDefaultPluginFactory(AlgebraPluginFactory.address).send();
    console.log(
      `Check tx on the explorer: https://nile.tronscan.org/#/transaction/${txId}`
    );

    deploysData.BasePluginV1Factory = AlgebraPluginFactory.address;
    fs.writeFileSync(deployDataPath, JSON.stringify(deploysData), 'utf-8');
}