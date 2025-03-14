require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-web3");

const { PRIVATEKEY, SECONDPRIVATEKEY, THIRDPRIVATEKEY, APIKEY } = require("./pvkey.js");
const { PRIVATEKEY_DEPLOYMENT} = require("./pvkey_deployment.js");

module.exports = {
  // Latest Solidity version
  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 50,
          },
          metadata: {
              useLiteralContent: true
          }
        },
      },
    ],
  },

  networks: {
    baseSepolia: {
      url: "https://base-sepolia.g.alchemy.com/v2/zY8fO9bbJbzywRt0xRheXQWpWjWiCqop",
      chainId: 84532, // Sepolia's Chain ID
      accounts: [PRIVATEKEY, SECONDPRIVATEKEY, THIRDPRIVATEKEY],
      gas: 21000000,
    },
    // baseMainnet: {
    //   url: "",
    //   chainId: 8453,
    //   accounts: [PRIVATEKEY_DEPLOYMENT],
    //   gas: "auto",
    // },
  },

  etherscan: {
    apiKey: APIKEY,
  },

  mocha: {
    timeout: 100000000,
  },
};
