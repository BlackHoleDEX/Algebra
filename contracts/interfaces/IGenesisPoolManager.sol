// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGenesisPoolManager {
    function nativeTokens(uint256 index) external view returns(address);
    function getAllNaitveTokens() external view returns (address[] memory);
    function getLiveNaitveTokens() external view returns (address[] memory);
}
