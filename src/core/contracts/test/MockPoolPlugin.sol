// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;
pragma abicoder v1;

import '../interfaces/plugin/IAlgebraPlugin.sol';
import '../interfaces/plugin/IAlgebraDynamicFeePlugin.sol';
import '../interfaces/IAlgebraPool.sol';
import '../libraries/Plugins.sol';
import './TestERC20.sol';

contract MockPoolPlugin is IAlgebraPlugin, IAlgebraDynamicFeePlugin {
  address public pool;
  uint8 public selectorsDisableConfig;
  uint24 public overrideFee;
  uint24 public pluginFee;
  bool public isDisabled;

  constructor(address _pool) {
    pool = _pool;
  }

  event BeforeInitialize(address sender, uint160 sqrtPriceX96);
  event AfterInitialize(address sender, uint160 sqrtPriceX96, int24 tick);
  event BeforeModifyPosition(address sender, address recipient, int24 bottomTick, int24 topTick, int128 desiredLiquidityDelta, bytes data);
  event AfterModifyPosition(
    address sender,
    address recipient,
    int24 bottomTick,
    int24 topTick,
    int128 desiredLiquidityDelta,
    uint256 amount0,
    uint256 amount1,
    bytes data
  );
  event BeforeSwap(
    address sender,
    address recipient,
    bool zeroToOne,
    int256 amountRequired,
    uint160 limitSqrtPrice,
    bool withPaymentInAdvance,
    bytes data
  );
  event AfterSwap(
    address sender,
    address recipient,
    bool zeroToOne,
    int256 amountRequired,
    uint160 limitSqrtPrice,
    int256 amount0,
    int256 amount1,
    bytes data
  );
  event BeforeFlash(address sender, address recipient, uint256 amount0, uint256 amount1, bytes data);
  event AfterFlash(address sender, address recipient, uint256 amount0, uint256 amount1, uint256 paid0, uint256 paid1, bytes data);

  function defaultPluginConfig() external view override returns (uint8) {}

  function getCurrentFee() external pure override returns (uint16 fee) {
    return 220;
  }

  function setSelectorDisable(uint8 newSelectorsDisableConfig) external {
    selectorsDisableConfig = newSelectorsDisableConfig;
  }

  function handlePluginFee(uint256, uint256) external view override returns (bytes4 selector) {
    if (isDisabled) return selector;
    return IAlgebraPlugin.handlePluginFee.selector;
  }

  function setPluginFees(uint24 _overrideFee, uint24 _pluginFee) external {
    (overrideFee, pluginFee) = (_overrideFee, _pluginFee);
  }

  function disablePluginFeeHandle() external {
    isDisabled = true;
  }

  /// @notice The hook called before the state of a pool is initialized
  /// @param sender The initial msg.sender for the initialize call
  /// @param sqrtPriceX96 The sqrt(price) of the pool as a Q64.96
  /// @return bytes4 The function selector for the hook
  function beforeInitialize(address sender, uint160 sqrtPriceX96) external override returns (bytes4) {
    emit BeforeInitialize(sender, sqrtPriceX96);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.DYNAMIC_FEE)) return IAlgebraPlugin.beforeInitialize.selector;
    return IAlgebraPlugin.defaultPluginConfig.selector;
  }

  /// @notice The hook called after the state of a pool is initialized
  /// @param sender The initial msg.sender for the initialize call
  /// @param sqrtPriceX96 The sqrt(price) of the pool as a Q64.96
  /// @param tick The current tick after the state of a pool is initialized
  /// @return bytes4 The function selector for the hook
  function afterInitialize(address sender, uint160 sqrtPriceX96, int24 tick) external override returns (bytes4) {
    emit AfterInitialize(sender, sqrtPriceX96, tick);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.AFTER_INIT_FLAG)) return IAlgebraPlugin.afterInitialize.selector;
    return IAlgebraPlugin.defaultPluginConfig.selector;
  }

  /// @notice The hook called before a position is modified
  /// @param sender The initial msg.sender for the modify position call
  /// @return bytes4 The function selector for the hook
  function beforeModifyPosition(
    address sender,
    address recipient,
    int24 bottomTick,
    int24 topTick,
    int128 desiredLiquidityDelta,
    bytes calldata data
  ) external override returns (bytes4, uint24) {
    emit BeforeModifyPosition(sender, recipient, bottomTick, topTick, desiredLiquidityDelta, data);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.BEFORE_POSITION_MODIFY_FLAG))
      return (IAlgebraPlugin.beforeModifyPosition.selector, pluginFee);
    return (IAlgebraPlugin.defaultPluginConfig.selector, pluginFee);
  }

  /// @notice The hook called after a position is modified
  /// @param sender The initial msg.sender for the modify position call
  /// @return bytes4 The function selector for the hook
  function afterModifyPosition(
    address sender,
    address recipient,
    int24 bottomTick,
    int24 topTick,
    int128 desiredLiquidityDelta,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external override returns (bytes4) {
    emit AfterModifyPosition(sender, recipient, bottomTick, topTick, desiredLiquidityDelta, amount0, amount1, data);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.AFTER_POSITION_MODIFY_FLAG)) return IAlgebraPlugin.afterModifyPosition.selector;
    return IAlgebraPlugin.defaultPluginConfig.selector;
  }

  /// @notice The hook called before a swap
  /// @param sender The initial msg.sender for the swap call
  /// @return bytes4 The function selector for the hook
  function beforeSwap(
    address sender,
    address recipient,
    bool zeroToOne,
    int256 amountRequired,
    uint160 limitSqrtPrice,
    bool withPaymentInAdvance,
    bytes calldata data
  ) external override returns (bytes4, uint24, uint24) {
    emit BeforeSwap(sender, recipient, zeroToOne, amountRequired, limitSqrtPrice, withPaymentInAdvance, data);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.BEFORE_SWAP_FLAG)) return (IAlgebraPlugin.beforeSwap.selector, overrideFee, pluginFee);
    return (IAlgebraPlugin.defaultPluginConfig.selector, overrideFee, pluginFee);
  }

  /// @notice The hook called after a swap
  /// @param sender The initial msg.sender for the swap call
  /// @return bytes4 The function selector for the hook
  function afterSwap(
    address sender,
    address recipient,
    bool zeroToOne,
    int256 amountRequired,
    uint160 limitSqrtPrice,
    int256 amount0,
    int256 amount1,
    bytes calldata data
  ) external override returns (bytes4) {
    emit AfterSwap(sender, recipient, zeroToOne, amountRequired, limitSqrtPrice, amount0, amount1, data);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.AFTER_SWAP_FLAG)) return IAlgebraPlugin.afterSwap.selector;
    return IAlgebraPlugin.defaultPluginConfig.selector;
  }

  /// @notice The hook called before flash
  /// @param sender The initial msg.sender for the flash call
  /// @param amount0 The amount of token0 being requested for flash
  /// @param amount1 The amount of token1 being requested for flash
  /// @return bytes4 The function selector for the hook
  function beforeFlash(address sender, address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external override returns (bytes4) {
    emit BeforeFlash(sender, recipient, amount0, amount1, data);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.BEFORE_FLASH_FLAG)) return IAlgebraPlugin.beforeFlash.selector;
    return IAlgebraPlugin.defaultPluginConfig.selector;
  }

  /// @notice The hook called after flash
  /// @param sender The initial msg.sender for the flash call
  /// @param amount0 The amount of token0 being requested for flash
  /// @param amount1 The amount of token1 being requested for flash
  /// @return bytes4 The function selector for the hook
  function afterFlash(
    address sender,
    address recipient,
    uint256 amount0,
    uint256 amount1,
    uint256 paid0,
    uint256 paid1,
    bytes calldata data
  ) external override returns (bytes4) {
    emit AfterFlash(sender, recipient, amount0, amount1, paid0, paid1, data);
    if (!Plugins.hasFlag(selectorsDisableConfig, Plugins.AFTER_FLASH_FLAG)) return IAlgebraPlugin.afterFlash.selector;
    return IAlgebraPlugin.defaultPluginConfig.selector;
  }

  function swap() external {
    IAlgebraPool(pool).swap(address(this), true, 10000, 4295128740, '');
  }

  function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
    require(amount0Delta > 0 || amount1Delta > 0, 'Zero liquidity swap'); // swaps entirely within 0-liquidity regions are not supported

    (address token, uint256 amountToPay) = amount0Delta > 0
      ? (IAlgebraPool(pool).token0(), uint256(amount0Delta))
      : (IAlgebraPool(pool).token1(), uint256(amount1Delta));

    TestERC20(token).transfer(pool, amountToPay);
  }

  function mint() external {
    IAlgebraPool(pool).mint(address(this), address(this), -60, 60, 1000, '');
  }

  function algebraMintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
    if (amount0Owed > 0) TestERC20(IAlgebraPool(pool).token0()).transfer(pool, amount0Owed);
    if (amount1Owed > 0) TestERC20(IAlgebraPool(pool).token1()).transfer(pool, amount1Owed);
  }
}
