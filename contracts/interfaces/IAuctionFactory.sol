// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuctionFactory {
    function factories(uint index) external view returns (address);
    function isFactory(address auction) external view returns (bool);
    function factoriesLength() external view returns (uint256);
    function allFactories() external view returns (address[] memory);
}