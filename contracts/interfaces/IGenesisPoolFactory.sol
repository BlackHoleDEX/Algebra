// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGenesisPoolFactory {
    function getGenesisPool(address nativeToken) external view returns (address);
    function genesisPools(uint index) external returns (address);

    function genesisPoolsLength() external view returns (uint256);
    function createGenesisPool(address tokenOwner, address nativeToken, address fundingToken, address auction) external returns (address);
}