// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGenesisPoolManager {
    function proposedTokens(uint256 index) external view returns(address);
    function getAllProposedTokens() external view returns (address[] memory);
}
