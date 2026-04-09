// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol';

import './plugins/DynamicFeePlugin.sol';
import './plugins/FarmingProxyPlugin.sol';
import './plugins/VolatilityOraclePlugin.sol';
import './plugins/SecurityPlugin.sol';
import './base/AlgebraBasePlugin.sol';
import './plugins/reflex-mev/ReflexAfterSwap.sol';
import './plugins/whitelist-fee-discount/FeeDiscountPlugin.sol';

/// @title Algebra Integral 1.2, contains adaptive fee, twap oracle, farming proxy and security plugins
contract AlgebraBasePluginV3 is DynamicFeePlugin, FarmingProxyPlugin, VolatilityOraclePlugin, SecurityPlugin, ReflexAfterSwap, FeeDiscountPlugin {
  using Plugins for uint8;

  event ReflexEnabled(bool indexed enabled);
  /// @inheritdoc IAlgebraPlugin
  uint8 public constant override defaultPluginConfig =
    uint8(
      Plugins.BEFORE_POSITION_MODIFY_FLAG |
        Plugins.AFTER_INIT_FLAG |
        Plugins.BEFORE_SWAP_FLAG |
        Plugins.AFTER_SWAP_FLAG |
        Plugins.DYNAMIC_FEE |
        Plugins.BEFORE_FLASH_FLAG
    );

  /// @notice Boolean flag to enable/disable ReflexAfterSwap functionality at plugin level
  bool public reflexEnabled;

  constructor(
    address _pool,
    address _factory,
    address _pluginFactory,
    AlgebraFeeConfiguration memory _config,
    address _reflexRouter,
    bytes32 _configId,
    address _feeDiscountRegistry
  )
    AlgebraBasePlugin(_pool, _factory, _pluginFactory)
    DynamicFeePlugin(_config)
    ReflexAfterSwap(_reflexRouter, _configId)
    FeeDiscountPlugin(_feeDiscountRegistry)
  {}

  // ###### REFLEX CONTROL ######

  /// @notice Enable or disable ReflexAfterSwap functionality
  /// @param _enabled True to enable, false to disable
  /// @dev Only callable by addresses with ALGEBRA_BASE_PLUGIN_MANAGER role
  function setReflexEnabled(bool _enabled) external {
    _authorize();
    reflexEnabled = _enabled;
    emit ReflexEnabled(_enabled);
  }

  /// @notice Check if ReflexAfterSwap functionality is currently enabled
  /// @return True if enabled, false if disabled
  function isReflexEnabled() external view returns (bool) {
    return reflexEnabled;
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
  function beforeModifyPosition(
    address,
    address,
    int24,
    int24,
    int128 liquidity,
    bytes calldata
  ) external override onlyPool returns (bytes4, uint24) {
    if (liquidity < 0) {
      _checkStatusOnBurn();
    } else {
      _checkStatus();
    }
    return (IAlgebraPlugin.beforeModifyPosition.selector, 0);
  }

  /// @dev unused
  function afterModifyPosition(address, address, int24, int24, int128, uint256, uint256, bytes calldata) external override onlyPool returns (bytes4) {
    _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
    return IAlgebraPlugin.afterModifyPosition.selector;
  }

  function beforeSwap(
    address sender,
    address recipient,
    bool,
    int256,
    uint160,
    bool,
    bytes calldata
  ) external override onlyPool returns (bytes4, uint24, uint24) {
    _checkStatus();
    _writeTimepoint();
    uint88 volatilityAverage = _getAverageVolatilityLast();
    uint24 fee = _getCurrentFee(volatilityAverage);
    if (sender == reflexRouter) {
      fee = _applyFeeDiscount(reflexRouter, pool, fee);
    } else {
      fee = _applyFeeDiscount(tx.origin, pool, fee);
    }
    return (IAlgebraPlugin.beforeSwap.selector, fee, 0);
  }

  function afterSwap(
    address,
    address recipient,
    bool zeroToOne,
    int256,
    uint160,
    int256 amount0Out,
    int256 amount1Out,
    bytes calldata
  ) external override onlyPool returns (bytes4) {
    _updateVirtualPoolTick(zeroToOne);
    // Only trigger ReflexAfterSwap if it's enabled
    if (reflexEnabled) {
      bytes32 triggerPoolId = bytes32(uint256(uint160(msg.sender)));
      _reflexAfterSwap(triggerPoolId, amount0Out, amount1Out, zeroToOne, tx.origin);
    }
    return IAlgebraPlugin.afterSwap.selector;
  }

  /// @dev unused
  function beforeFlash(address, address, uint256, uint256, bytes calldata) external override onlyPool returns (bytes4) {
    _checkStatus();
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
}
