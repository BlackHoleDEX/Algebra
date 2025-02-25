// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGenesisPoolFactory {
    function createGenesisPool(address nativeToken, address fundingToken) external returns (address);
}