// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';

import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol';

import './plugins/DynamicFeePlugin.sol';
import './plugins/FarmingProxyPlugin.sol';
import './plugins/SlidingFeePlugin.sol';
import './plugins/VolatilityOraclePlugin.sol';

import './interfaces/plugins/ISecurityPlugin.sol';
import './interfaces/plugins/ISecurityRegistry.sol';

/// @title Algebra Integral 1.2.2 adaptive fee plugin with security checks
contract AlgebraCustomPluginV1 is DynamicFeePlugin, FarmingProxyPlugin, VolatilityOraclePlugin, ISecurityPlugin {
  using Plugins for uint8;

  /// @inheritdoc IAlgebraPlugin
  uint8 public constant override defaultPluginConfig =
    uint8(
      Plugins.AFTER_INIT_FLAG |
        Plugins.BEFORE_SWAP_FLAG |
        Plugins.BEFORE_FLASH_FLAG |
        Plugins.BEFORE_POSITION_MODIFY_FLAG |
        Plugins.AFTER_SWAP_FLAG |
        Plugins.DYNAMIC_FEE
    );

  address internal securityRegistry;

  constructor(
    address _pool,
    address _factory,
    address _pluginFactory,
    AlgebraFeeConfiguration memory _config,
    address _securityRegistry
  ) AlgebraBasePlugin(_pool, _factory, _pluginFactory) DynamicFeePlugin(_config) {
    securityRegistry = _securityRegistry;
    // activeModules.push("Security Plugin");
  }

  // ###### HOOKS ######

  function beforeInitialize(address, uint160) external override onlyPool returns (bytes4) {
    _updatePluginConfigInPool(defaultPluginConfig);
    return IAlgebraPlugin.beforeInitialize.selector;
  }

  function afterInitialize(address, uint160, int24 tick) external override onlyPool returns (bytes4) {
    _initialize_TWAP(tick);
    return IAlgebraPlugin.afterInitialize.selector;
  }

  /// @dev unused
  function beforeModifyPosition(address, address, int24, int24, int128, bytes calldata) external override onlyPool returns (bytes4, uint24) {
    _checkStatus();
    _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
    return (IAlgebraPlugin.beforeModifyPosition.selector, 0);
  }

  /// @dev unused
  function afterModifyPosition(address, address, int24, int24, int128, uint256, uint256, bytes calldata) external override onlyPool returns (bytes4) {
    _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
    return IAlgebraPlugin.afterModifyPosition.selector;
  }

  function beforeSwap(address, address, bool, int256, uint160, bool, bytes calldata) external override onlyPool returns (bytes4, uint24, uint24) {
    _checkStatus();
    _writeTimepoint();
    uint88 volatilityAverage = _getAverageVolatilityLast();
    uint24 fee = _getCurrentFee(volatilityAverage);
    return (IAlgebraPlugin.beforeSwap.selector, fee, 0);
  }

  function afterSwap(address, address, bool zeroToOne, int256, uint160, int256, int256, bytes calldata) external override onlyPool returns (bytes4) {
    _updateVirtualPoolTick(zeroToOne);
    return IAlgebraPlugin.afterSwap.selector;
  }

  /// @dev unused
  function beforeFlash(address, address, uint256, uint256, bytes calldata) external override onlyPool returns (bytes4) {
    _checkStatus();
    _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
    return IAlgebraPlugin.beforeFlash.selector;
  }

  /// @dev unused
  function afterFlash(address, address, uint256, uint256, uint256, uint256, bytes calldata) external override onlyPool returns (bytes4) {
    _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
    return IAlgebraPlugin.afterFlash.selector;
  }

  function getCurrentFee() external view override returns (uint16 fee) {
    uint88 volatilityAverage = _getAverageVolatilityLast();
    fee = _getCurrentFee(volatilityAverage);
  }

  // ###### SECURITY ######

  function setSecurityRegistry(address _securityRegistry) external override {
    _authorize();
    securityRegistry = _securityRegistry;
    emit SecurityRegistry(_securityRegistry);
  }

  function getSecurityRegistry() external view override returns (address) {
    return securityRegistry;
  }

  function _checkStatus() internal {
    if (securityRegistry != address(0)) {
      ISecurityRegistry.Status status = ISecurityRegistry(securityRegistry).getPoolStatus(msg.sender);
      if (status != ISecurityRegistry.Status.ENABLED) {
        if (status == ISecurityRegistry.Status.DISABLED) {
          revert PoolDisabled();
        } else {
          revert BurnOnly();
        }
      }
    }
  }

  function _checkStatusOnBurn() internal {
    if (securityRegistry != address(0)) {
      ISecurityRegistry.Status status = ISecurityRegistry(securityRegistry).getPoolStatus(msg.sender);
      if (status == ISecurityRegistry.Status.DISABLED) {
        revert PoolDisabled();
      }
    }
  }
}
