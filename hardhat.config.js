require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-web3");

const { PRIVATEKEY, APIKEY } = require("./pvkey.js");

module.exports = {
  // Latest Solidity version
  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.7.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },

  networks: {
    baseSepolia: {
      url: "https://base-sepolia.g.alchemy.com/v2/zY8fO9bbJbzywRt0xRheXQWpWjWiCqop",
      // chainId: 84532, // Sepolia's Chain ID
      accounts: [PRIVATEKEY],
      gas: 21000000,
    },

    // hardhat: {
    //   forking: {
    //     url: "https://base-sepolia.g.alchemy.com/v2/zY8fO9bbJbzywRt0xRheXQWpWjWiCqop",// Base Sepolia forking
    //     chainId: 84532,
    //   },
    //   accounts: [PRIVATEKEY]
    // },
  },

  etherscan: {
    // Your API key for Etherscan (can also be used for Base block explorers)
    apiKey: APIKEY,
  },

  mocha: {
    timeout: 100000000,
  },
};
