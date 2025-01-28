const { fetchAbi } = require('./abi-fetcher.js')
const fs = require('fs');
const path = require('path');

const dirPath = './generated'

const generateConstantFile = (contract, address) => {
    const abi = fetchAbi(contract);

    const contractData = 
    `const ${contract}Address = "${address}";\n\nconst ${contract}Abi = ${JSON.stringify(abi, null, 2)};\n\nmodule.exports = {${contract}Address, ${contract}Abi};`;

    try {

        if (!fs.existsSync(dirPath)) {
            fs.mkdirSync(dirPath, { recursive: true });
        }

        const filename = contract.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase();
        const pathname = `${dirPath}/${filename}.js`
        fs.writeFileSync(pathname, contractData);
        console.log(`Data written to ${pathname}`);

    } catch (error) {
        console.error("Error fetching pairs data: ", error);
    }

}

async function main () {
    generateConstantFile("BribeFactoryV3", "627890");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
});

module.exports = { generateConstantFile };