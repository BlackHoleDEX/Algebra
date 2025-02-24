// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract PairFactoryStorage {
    mapping(address => mapping(address => mapping(bool => address))) private _getPair;
    address[] private _allPairs;
    mapping(address => bool) private _isPair;
    mapping(address => uint256) private _customFees;

    event PairAdded(address indexed token0, address indexed token1, bool stable, address pair);
    event CustomFeeSet(address indexed pair, uint256 fee);

    // Getter methods
    function getPair(address tokenA, address tokenB, bool stable) external view returns (address) {
        return _getPair[tokenA][tokenB][stable];
    }

    function getAllPairs() external view returns (address[] memory) {
        return _allPairs;
    }

    // function isPair(address pair) external view returns (bool) {
    //     return _isPair[pair];
    // }

    function getCustomFee(address pair) external view returns (uint256) {
        return _customFees[pair];
    }

    function allPairsLength() external view returns (uint256) {
        return _allPairs.length;
    }

    // Setter methods (Only callable by the PairFactory)
    function addPair(address token0, address token1, bool stable, address pair) external {
        _getPair[token0][token1][stable] = pair;
        _getPair[token1][token0][stable] = pair;
        _allPairs.push(pair);
        _isPair[pair] = true;
        emit PairAdded(token0, token1, stable, pair);
    }

    function setCustomFee(address pair, uint256 fee) external {
        _customFees[pair] = fee;
        emit CustomFeeSet(pair, fee);
    }
}
