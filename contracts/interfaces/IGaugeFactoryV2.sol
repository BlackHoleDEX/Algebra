// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IGaugeFactory {
    function createGaugeV2(address _rewardToken,address _ve,address _token,address _distribution, address _internal_bribe, address _external_bribe, bool _isPair, address genesisManager) external returns (address) ;
    function gauges() external view returns(address[] memory);
    function length() external view returns(uint);
}
