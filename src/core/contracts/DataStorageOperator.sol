// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import './interfaces/IAlgebraFactory.sol';
import './interfaces/IDataStorageOperator.sol';

import './libraries/DataStorage.sol';
import './libraries/Sqrt.sol';
import './libraries/AdaptiveFee.sol';

import './libraries/Constants.sol';

contract DataStorageOperator is IDataStorageOperator {
  using DataStorage for DataStorage.Timepoint[65535];

  DataStorage.Timepoint[65535] public override timepoints;
  AdaptiveFee.Configuration public feeConfig;

  address private immutable pool;
  address private immutable factory;

  modifier onlyPool() {
    require(msg.sender == pool, 'only pool can call this');
    _;
  }

  modifier onlyFactory() {
    require(msg.sender == factory, 'only factory can call this');
    _;
  }

  constructor(address _pool) {
    factory = msg.sender;
    pool = _pool;
  }

  function initialize(uint32 time, int24 tick) external override onlyPool {
    return timepoints.initialize(time, tick);
  }

  function changeFeeConfiguration(AdaptiveFee.Configuration calldata _feeConfig) external override {
    require(msg.sender == factory || msg.sender == IAlgebraFactory(factory).owner());
    feeConfig = _feeConfig;
  }

  function getSingleTimepoint(
    uint32 time,
    uint32 secondsAgo,
    int24 tick,
    uint16 index,
    uint128 liquidity
  )
    external
    view
    override
    onlyPool
    returns (
      int56 tickCumulative,
      uint160 secondsPerLiquidityCumulative,
      uint112 volatilityCumulative,
      uint256 volumePerAvgLiquidity
    )
  {
    uint16 oldestIndex;
    // check if we have overflow in the past
    if (timepoints[addmod(index, 1, 65535)].initialized) {
      oldestIndex = uint16(addmod(index, 1, 65535));
    }

    DataStorage.Timepoint memory result = timepoints.getSingleTimepoint(time, secondsAgo, tick, index, oldestIndex, liquidity);
    (tickCumulative, secondsPerLiquidityCumulative, volatilityCumulative, volumePerAvgLiquidity) = (
      result.tickCumulative,
      result.secondsPerLiquidityCumulative,
      result.volatilityCumulative,
      result.volumePerLiquidityCumulative
    );
  }

  function getTimepoints(
    uint32 time,
    uint32[] memory secondsAgos,
    int24 tick,
    uint16 index,
    uint128 liquidity
  )
    external
    view
    override
    onlyPool
    returns (
      int56[] memory tickCumulatives,
      uint160[] memory secondsPerLiquidityCumulatives,
      uint112[] memory volatilityCumulatives,
      uint256[] memory volumePerAvgLiquiditys
    )
  {
    return timepoints.getTimepoints(time, secondsAgos, tick, index, liquidity);
  }

  function getAverages(
    uint32 time,
    int24 tick,
    uint16 index,
    uint128 liquidity
  ) external view override onlyPool returns (uint112 TWVolatilityAverage, uint256 TWVolumePerLiqAverage) {
    return timepoints.getAverages(time, tick, index, liquidity);
  }

  function write(
    uint16 index,
    uint32 blockTimestamp,
    int24 tick,
    uint128 liquidity,
    uint128 volumePerLiquidity
  ) external override onlyPool returns (uint16 indexUpdated) {
    return timepoints.write(index, blockTimestamp, tick, liquidity, volumePerLiquidity);
  }

  function calculateVolumePerLiquidity(
    uint128 liquidity,
    int256 amount0,
    int256 amount1
  ) external pure override returns (uint128 volumePerLiquidity) {
    uint256 volume = Sqrt.sqrt(amount0) * Sqrt.sqrt(amount1);
    uint256 volumeShifted;
    if (volume >= 2**192) volumeShifted = (type(uint256).max) / (liquidity > 0 ? liquidity : 1);
    else volumeShifted = (volume << 64) / (liquidity > 0 ? liquidity : 1);
    if (volumeShifted >= 100000 << 64) return 100000 << 64;
    volumePerLiquidity = uint128(volumeShifted);
  }

  function WINDOW() external pure override returns (uint32) {
    return DataStorage.WINDOW;
  }

  function getFee(
    uint32 _time,
    int24 _tick,
    uint16 _index,
    uint128 _liquidity
  ) external view override onlyPool returns (uint16 fee) {
    (uint88 volatilityAverage, uint256 volumePerLiqAverage) = timepoints.getAverages(_time, _tick, _index, _liquidity);

    return uint16(AdaptiveFee.getFee(volatilityAverage / 15, volumePerLiqAverage, feeConfig));
  }
}
