// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './AlgebraBasePluginV3.sol';
import './interfaces/IPluginV3Deployer.sol';

/// @title PluginV3Deployer
/// @notice Helper contract to deploy `AlgebraBasePluginV3` instances
/// @dev Kept minimal so that the main factory (`BasePluginV3Factory`) can stay below bytecode size limits
contract PluginV3Deployer is IPluginV3Deployer {
  /// @notice The address of BasePluginV3Factory that can call deployPlugin
  address public immutable factory;

  modifier onlyFactory() {
    require(msg.sender == factory, 'NA');
    _;
  }

  constructor(address _factory) {
    require(_factory != address(0), 'IA');
    factory = _factory;
  }

  function deployPlugin(
    address pool,
    address algebraFactory,
    address pluginFactory,
    AlgebraFeeConfiguration memory defaultFeeConfiguration,
    address reflexRouter,
    bytes32 reflexConfigId,
    address feeDiscountRegistry
  ) external override onlyFactory returns (address plugin) {
    plugin = address(
      new AlgebraBasePluginV3(pool, algebraFactory, pluginFactory, defaultFeeConfiguration, reflexRouter, reflexConfigId, feeDiscountRegistry)
    );
  }
}
