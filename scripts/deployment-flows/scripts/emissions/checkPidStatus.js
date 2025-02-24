
const { blackGovernorAbi, blackGovernorAddress } = require('../../../../generated/black-governor');



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    const ownerAddress = owner.address;
    
    const blackGovernorContract = await ethers.getContractAt(blackGovernorAbi, blackGovernorAddress);
    const statusPid = await blackGovernorContract.state("16134786894693074512526881837070247251028559825807118338989515965967069897879"); //assign pid
    console.log("statue of pid ", statusPid)
}

main()
  .then(
    () => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});