// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPairFactoryStorage {
    function getPair(address tokenA, address tokenB, bool stable) external view returns (address);
    function getAllPairs() external view returns (address[] memory);
    function isPair(address pair) external view returns (bool);
    function getCustomFee(address pair) external view returns (uint256);
    function allPairsLength() external view returns (uint256);
    function addPair(address token0, address token1, bool stable, address pair) external;
    function setCustomFee(address pair, uint256 fee) external;
}
