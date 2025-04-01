// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPluginFactory.sol';
import '../base/AlgebraFeeConfiguration.sol';

/// @title The interface for the IAlgebraALMCustomPoolDeployer
interface IAlgebraALMCustomPoolDeployer is IAlgebraPluginFactory {

  /// @notice Emitted when the default fee configuration is changed
  /// @param newConfig The structure with dynamic fee parameters
  /// @dev See the AdaptiveFee library for more details
  event DefaultFeeConfiguration(AlgebraFeeConfiguration newConfig);

  /// @notice Emitted when the farming address is changed
  /// @param newFarmingAddress The farming address after the address was changed
  event FarmingAddress(address newFarmingAddress);

  /// @notice The hash of 'ALGEBRA_CUSTOM_PLUGIN_ADMINISTRATOR' used as role
  /// @dev allows to change settings of AlgebraALMCustomPoolDeployer
  function ALGEBRA_CUSTOM_PLUGIN_ADMINISTRATOR() external pure returns (bytes32);

  /// @notice Returns the address of AlgebraFactory
  /// @return The AlgebraFactory contract address
  function algebraFactory() external view returns (address);

  /// @notice Returns the address of entryPoint
  /// @return The entryPoint contract address
  function entryPoint() external view returns (address);

  /// @notice Returns current farming address
  /// @return The farming contract address
  function farmingAddress() external view returns (address);

  /// @notice Current default dynamic fee configuration
  /// @dev See the AdaptiveFee struct for more details about params.
  /// This value is set by default in new plugins
  function defaultFeeConfiguration()
    external
    view
    returns (uint16 alpha1, uint16 alpha2, uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2, uint16 baseFee);

  /// @notice Returns address of plugin created for given AlgebraPool
  /// @param pool The address of AlgebraPool
  /// @return The address of corresponding plugin
  function pluginByPool(address pool) external view returns (address);

  /// @notice Create custom pool
  function createCustomPool(address creator, address tokenA, address tokenB, bytes calldata data) external returns (address customPool);

  /// @notice Changes initial fee configuration for new pools
  /// @dev changes coefficients for sigmoids: α / (1 + e^( (β-x) / γ))
  /// alpha1 + alpha2 + baseFee (max possible fee) must be <= type(uint16).max and gammas must be > 0
  /// @param newConfig new default fee configuration. See the #AdaptiveFee.sol library for details
  function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig) external;

  /// @dev updates farmings manager address on the factory
  /// @param newFarmingAddress The new tokenomics contract address
  function setFarmingAddress(address newFarmingAddress) external;

}