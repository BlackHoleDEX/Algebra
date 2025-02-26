//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAutomatedVotingManager {
    function originalOwner(uint256 tokenId) external view returns(address);
    function setOriginalOwner(uint256 tokenId, address owner) external;
}
