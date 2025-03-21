const pairGeneratorAddress = "0xc72A7E03633Dc333D975874b49c5bA27A7A8381C";

const pairGeneratorAbi = [
  {
    "inputs": [],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "token0",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "token1",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "bool",
        "name": "stable",
        "type": "bool"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "pair",
        "type": "address"
      }
    ],
    "name": "PairCreated",
    "type": "event"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token0",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "token1",
        "type": "address"
      },
      {
        "internalType": "bool",
        "name": "stable",
        "type": "bool"
      }
    ],
    "name": "createPair",
    "outputs": [
      {
        "internalType": "address",
        "name": "pair",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pairCodeHash",
    "outputs": [
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      }
    ],
    "stateMutability": "pure",
    "type": "function"
  }
];

module.exports = {pairGeneratorAddress, pairGeneratorAbi};