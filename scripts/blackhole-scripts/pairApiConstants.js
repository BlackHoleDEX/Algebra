const blackHoleAllPairAbi = [
    {
      "inputs": [],
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": false,
          "internalType": "uint8",
          "name": "version",
          "type": "uint8"
        }
      ],
      "name": "Initialized",
      "type": "event"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": false,
          "internalType": "address",
          "name": "oldWBF",
          "type": "address"
        },
        {
          "indexed": false,
          "internalType": "address",
          "name": "newWBF",
          "type": "address"
        }
      ],
      "name": "WBF",
      "type": "event"
    },
    {
      "inputs": [],
      "name": "MAX_EPOCHS",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "MAX_PAIRS",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "MAX_REWARDS",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "WEEK",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_user",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "_amounts",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "_offset",
          "type": "uint256"
        }
      ],
      "name": "getAllPair",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "totPairs",
          "type": "uint256"
        },
        {
          "components": [
            {
              "internalType": "address",
              "name": "pair_address",
              "type": "address"
            },
            {
              "internalType": "string",
              "name": "symbol",
              "type": "string"
            },
            {
              "internalType": "string",
              "name": "name",
              "type": "string"
            },
            {
              "internalType": "uint256",
              "name": "decimals",
              "type": "uint256"
            },
            {
              "internalType": "bool",
              "name": "stable",
              "type": "bool"
            },
            {
              "internalType": "uint256",
              "name": "total_supply",
              "type": "uint256"
            },
            {
              "internalType": "address",
              "name": "token0",
              "type": "address"
            },
            {
              "internalType": "string",
              "name": "token0_symbol",
              "type": "string"
            },
            {
              "internalType": "uint256",
              "name": "token0_decimals",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "reserve0",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "claimable0",
              "type": "uint256"
            },
            {
              "internalType": "address",
              "name": "token1",
              "type": "address"
            },
            {
              "internalType": "string",
              "name": "token1_symbol",
              "type": "string"
            },
            {
              "internalType": "uint256",
              "name": "token1_decimals",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "reserve1",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "claimable1",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_lp_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_token0_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_token1_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_gauge_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_gauge_earned",
              "type": "uint256"
            }
          ],
          "internalType": "struct BlackHolePairAPI.pairInfo[]",
          "name": "Pairs",
          "type": "tuple[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_pair",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "_account",
          "type": "address"
        }
      ],
      "name": "getPair",
      "outputs": [
        {
          "components": [
            {
              "internalType": "address",
              "name": "pair_address",
              "type": "address"
            },
            {
              "internalType": "string",
              "name": "symbol",
              "type": "string"
            },
            {
              "internalType": "string",
              "name": "name",
              "type": "string"
            },
            {
              "internalType": "uint256",
              "name": "decimals",
              "type": "uint256"
            },
            {
              "internalType": "bool",
              "name": "stable",
              "type": "bool"
            },
            {
              "internalType": "uint256",
              "name": "total_supply",
              "type": "uint256"
            },
            {
              "internalType": "address",
              "name": "token0",
              "type": "address"
            },
            {
              "internalType": "string",
              "name": "token0_symbol",
              "type": "string"
            },
            {
              "internalType": "uint256",
              "name": "token0_decimals",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "reserve0",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "claimable0",
              "type": "uint256"
            },
            {
              "internalType": "address",
              "name": "token1",
              "type": "address"
            },
            {
              "internalType": "string",
              "name": "token1_symbol",
              "type": "string"
            },
            {
              "internalType": "uint256",
              "name": "token1_decimals",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "reserve1",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "claimable1",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_lp_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_token0_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_token1_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_gauge_balance",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "account_gauge_earned",
              "type": "uint256"
            }
          ],
          "internalType": "struct BlackHolePairAPI.pairInfo",
          "name": "_pairInfo",
          "type": "tuple"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_pairFactory",
          "type": "address"
        }
      ],
      "name": "initialize",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "owner",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "pairFactory",
      "outputs": [
        {
          "internalType": "contract IPairFactory",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_owner",
          "type": "address"
        }
      ],
      "name": "setOwner",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]


const blackHoleAllPairProxyAddress = "0xdeb2963856d3eaac913b776c63a552b7cab0580b";
const blackHoleAllPairAddress = "0xc5aef405aeb37176b77667d31065bdcbd9cd1324";

module.exports = {blackHoleAllPairAbi, blackHoleAllPairAddress, blackHoleAllPairProxyAddress}
