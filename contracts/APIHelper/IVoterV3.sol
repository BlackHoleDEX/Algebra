// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVoterV3 {
    function length() external view returns (uint256);
    function poolVoteLength(uint256 tokenId) external view returns(uint256);
    function factories() external view returns(address[] memory);
    function factoryLength() external view returns(uint256);
    function gaugeFactories() external view returns(address[] memory);
    function gaugeFactoriesLength() external view returns(uint256);
    function weights(address _pool) external view returns(uint256);
    function weightsAt(address _pool, uint256 _time) external view returns(uint256);
    function totalWeight() external view returns(uint256);
    function totalWeightAt(uint256 _time) external view returns(uint256);
}