// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol';

import './plugins/DynamicFeePlugin.sol';
import './plugins/VolatilityOraclePlugin.sol';
import './plugins/SlidingFeePlugin.sol';

/// @title Algebra Integral 1.2 plugin. Contains adaptive + sliding fee and twap oracle
contract CamelotBasePlugin is DynamicFeePlugin, VolatilityOraclePlugin, SlidingFeePlugin {
  using Plugins for uint8;

  /// @inheritdoc IAlgebraPlugin
  uint8 public constant override defaultPluginConfig = uint8(Plugins.AFTER_INIT_FLAG | Plugins.BEFORE_SWAP_FLAG | Plugins.DYNAMIC_FEE);

  constructor(address _pool, address _factory, address _pluginFactory) BasePlugin(_pool, _factory, _pluginFactory) {}

  // ###### HOOKS ######

  function beforeInitialize(address, uint160) external override onlyPool returns (bytes4) {
    _updatePluginConfigInPool(defaultPluginConfig);
    return IAlgebraPlugin.beforeInitialize.selector;
  }

  function afterInitialize(address, uint160, int24 tick) external override onlyPool returns (bytes4) {
    _initialize_TWAP(tick);

    IAlgebraPool(pool).setFee(_feeConfig.baseFee());
    return IAlgebraPlugin.afterInitialize.selector;
  }

  /// @dev unused
  function beforeModifyPosition(address, address, int24, int24, int128, bytes calldata) external override onlyPool returns (bytes4, uint24) {
    _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
    return (IAlgebraPlugin.beforeModifyPosition.selector, 0);
  }

  /// @dev unused
  function afterModifyPosition(address, address, int24, int24, int128, uint256, uint256, bytes calldata) external override onlyPool returns (bytes4) {
    _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
    return IAlgebraPlugin.afterModifyPosition.selector;
  }

  function beforeSwap(
    address,
    address,
    bool zeroToOne,
    int256,
    uint160,
    bool,
    bytes calldata
  ) external override onlyPool returns (bytes4, uint24, uint24) {
    uint16 newFee;
    bool _dynamicFeeEnabled = dynamicFeeEnabled;
    /// get ticks for slidiing fee calculation
    (, int24 currentTick, uint16 fee, ) = _getPoolState();
    int24 lastTick = _getLastTick();
    /// write timepoint to oracle
    _writeTimepoint();
    /// calculate volatility and dynamic fee if enabled
    if (_dynamicFeeEnabled) {
      uint88 volatilityAverage = _getAverageVolatilityLast();
      newFee = _getCurrentFee(volatilityAverage);
    }
    /// calcucalate sliding fee based on dynamic fee if enabled
    if (slidingFeeEnabled) {
      newFee = _getFeeAndUpdateFactors(zeroToOne, currentTick, lastTick, _dynamicFeeEnabled, newFee);
    }
    /// update pool state fee
    if (newFee != fee) {
      IAlgebraPool(pool).setFee(newFee);
    }
    return (IAlgebraPlugin.beforeSwap.selector, 0, 0);
  }

  function afterSwap(address, address, bool, int256, uint160, int256, int256, bytes calldata) external override onlyPool returns (bytes4) {
    _updatePluginConfigInPool(defaultPluginConfig);
    return IAlgebraPlugin.afterSwap.selector;
  }

  /// @dev unused
  function beforeFlash(address, address, uint256, uint256, bytes calldata) external override onlyPool returns (bytes4) {
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
}
