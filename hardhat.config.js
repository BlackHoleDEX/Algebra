require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-web3");
require("dotenv").config(); 

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
      accounts: [`0x${process.env.PRIVATEKEY}`, `0x${process.env.SECONDPRIVATEKEY}`, `0x${process.env.THIRDPRIVATEKEY}`],
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
    apiKey: `${process.env.APIKEY}`,
  },

  mocha: {
    timeout: 100000000,
  },
};
