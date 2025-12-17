// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '../base/AlgebraFeeConfiguration.sol';

/// @title Interface for PluginV3Deployer
/// @notice Used by BasePluginV3Factory to deploy plugins without importing the deployer contract
interface IPluginV3Deployer {
  function deployPlugin(
    address pool,
    address algebraFactory,
    address pluginFactory,
    AlgebraFeeConfiguration memory defaultFeeConfiguration,
    address reflexRouter,
    bytes32 reflexConfigId,
    address feeDiscountRegistry
  ) external returns (address plugin);
}
