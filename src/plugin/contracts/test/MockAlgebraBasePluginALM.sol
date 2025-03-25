// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import '../AlgebraBasePluginALM.sol';

contract MockAlgebraBasePluginALM is AlgebraBasePluginALM {
  constructor(
    address _pool,
    address _factory,
    address _pluginFactory,
    AlgebraFeeConfiguration memory _config
  ) AlgebraBasePluginALM(_pool, _factory, _pluginFactory, _config) {}
}
