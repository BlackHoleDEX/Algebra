// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './AlgebraBasePluginV3.sol';

/// @title PluginV3Deployer
/// @notice Helper contract to deploy `AlgebraBasePluginV3` instances
/// @dev Kept minimal so that the main factory (`BasePluginV3Factory`) can stay below bytecode size limits
contract PluginV3Deployer {
  function deployPlugin(
    address pool,
    address algebraFactory,
    address pluginFactory,
    AlgebraFeeConfiguration memory defaultFeeConfiguration,
    address feeDiscountRegistry
  ) external returns (address plugin) {
    plugin = address(new AlgebraBasePluginV3(pool, algebraFactory, pluginFactory, defaultFeeConfiguration, feeDiscountRegistry));
  }
}
