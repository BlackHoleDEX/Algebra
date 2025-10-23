// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './IBasePluginV1Factory.sol';

/// @title The interface for the CustomPluginV1Factory
/// @notice This contract creates Algebra adaptive fee plugins for Algebra liquidity pools
interface ICustomPluginV1Factory is IBasePluginV1Factory {
  /// @notice Create plugin for already existing pool
  /// @param token0 The address of first token in pool
  /// @param token1 The address of second token in pool
  /// @param customPoolDeployer The address of custom pool deployer
  /// @return The address of created plugin
  function createPluginForExistingCustomPool(address token0, address token1, address customPoolDeployer) external returns (address);
}
