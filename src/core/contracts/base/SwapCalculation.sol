// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '../libraries/PriceMovementMath.sol';
import '../libraries/LowGasSafeMath.sol';
import '../libraries/SafeCast.sol';
import './AlgebraPoolBase.sol';

/// @title Algebra swap calculation abstract contract
/// @notice Contains _calculateSwap encapsulating internal logic of swaps
abstract contract SwapCalculation is AlgebraPoolBase {
  using TickManagement for mapping(int24 => TickManagement.Tick);
  using SafeCast for uint256;
  using LowGasSafeMath for uint256;
  using LowGasSafeMath for int256;

  struct SwapCalculationCache {
    uint256 communityFee; // The community fee of the selling token, uint256 to minimize casts
    bool crossedAnyTick; //  If we have already crossed at least one active tick
    int256 amountRequiredInitial; // The initial value of the exact input\output amount
    int256 amountCalculated; // The additive amount of total output\input calculated through the swap
    uint256 totalFeeGrowthInput; // The initial totalFeeGrowth + the fee growth during a swap
    uint256 totalFeeGrowthOutput; // The initial totalFeeGrowth for output token, should not change during swap
    bool exactInput; // Whether the exact input or output is specified
    uint24 fee; // The current fee value in hundredths of a bip, i.e. 1e-6
    int24 prevInitializedTick; // The previous initialized tick in linked list
    int24 nextInitializedTick; // The next initialized tick in linked list
    uint24 pluginFee;
  }

  struct PriceMovementCache {
    uint256 stepSqrtPrice; // The Q64.96 sqrt of the price at the start of the step, uint256 to minimize casts
    uint256 nextTickPrice; // The Q64.96 sqrt of the price calculated from the _nextTick_, uint256 to minimize casts
    uint256 input; // The additive amount of tokens that have been provided
    uint256 output; // The additive amount of token that have been withdrawn
    uint256 feeAmount; // The total amount of fee earned within a current step
  }

  struct FeesAmount {
    uint256 communityFeeAmount;
    uint256 pluginFeeAmount;
  }

  // Add these structs at the top of the contract or in a separate file
  struct CalculateSwapParams {
    uint24 overrideFee;
    uint24 pluginFee;
    bool zeroToOne;
    int256 amountRequired;
    uint160 limitSqrtPrice;
  }

  struct SwapResult {
    int256 amount0;
    int256 amount1;
    uint160 currentPrice;
    int24 currentTick;
    uint128 currentLiquidity;
  }

  // Replace the function signature
  function _calculateSwap(CalculateSwapParams memory params) internal returns (SwapResult memory result, FeesAmount memory fees) {
    if (params.amountRequired == 0) revert zeroAmountRequired();
    if (params.amountRequired == type(int256).min) revert invalidAmountRequired();

    SwapCalculationCache memory cache;
    (cache.amountRequiredInitial, cache.exactInput, cache.pluginFee) = (params.amountRequired, params.amountRequired > 0, params.pluginFee);

    // Load from one storage slot
    (result.currentLiquidity, cache.prevInitializedTick, cache.nextInitializedTick) = (liquidity, prevTickGlobal, nextTickGlobal);

    // Load from one storage slot too
    (result.currentPrice, result.currentTick, cache.fee, cache.communityFee) = (
      globalState.price,
      globalState.tick,
      globalState.lastFee,
      globalState.communityFee
    );

    if (result.currentPrice == 0) revert notInitialized();

    if (params.overrideFee != 0) {
      cache.fee = params.overrideFee + params.pluginFee;
      if (cache.fee >= 1e6) revert incorrectPluginFee();
    } else {
      if (params.pluginFee != 0) {
        cache.fee += params.pluginFee;
        if (cache.fee >= 1e6) revert incorrectPluginFee();
      }
    }

    if (params.zeroToOne) {
      if (params.limitSqrtPrice >= result.currentPrice || params.limitSqrtPrice <= TickMath.MIN_SQRT_RATIO) revert invalidLimitSqrtPrice();
      cache.totalFeeGrowthInput = totalFeeGrowth0Token;
    } else {
      if (params.limitSqrtPrice <= result.currentPrice || params.limitSqrtPrice >= TickMath.MAX_SQRT_RATIO) revert invalidLimitSqrtPrice();
      cache.totalFeeGrowthInput = totalFeeGrowth1Token;
    }

    int256 amountRequired = params.amountRequired;
    PriceMovementCache memory step;

    unchecked {
      // swap until there is remaining input or output tokens or we reach the price limit
      do {
        int24 nextTick = params.zeroToOne ? cache.prevInitializedTick : cache.nextInitializedTick;
        step.stepSqrtPrice = result.currentPrice;
        step.nextTickPrice = TickMath.getSqrtRatioAtTick(nextTick);

        (result.currentPrice, step.input, step.output, step.feeAmount) = PriceMovementMath.movePriceTowardsTarget(
          params.zeroToOne,
          result.currentPrice,
          (params.zeroToOne == (step.nextTickPrice < params.limitSqrtPrice)) ? params.limitSqrtPrice : uint160(step.nextTickPrice),
          result.currentLiquidity,
          amountRequired,
          cache.fee
        );

        if (cache.exactInput) {
          amountRequired -= (step.input + step.feeAmount).toInt256();
          cache.amountCalculated = cache.amountCalculated.sub(step.output.toInt256());
        } else {
          amountRequired += step.output.toInt256();
          cache.amountCalculated = cache.amountCalculated.add((step.input + step.feeAmount).toInt256());
        }

        if (cache.communityFee > 0) {
          uint256 delta = (step.feeAmount.mul(cache.communityFee)) / Constants.COMMUNITY_FEE_DENOMINATOR;
          step.feeAmount -= delta;
          fees.communityFeeAmount += delta;
        }

        if (cache.pluginFee > 0 && cache.fee > 0) {
          uint256 delta = FullMath.mulDiv(step.feeAmount, cache.pluginFee, cache.fee);
          step.feeAmount -= delta;
          fees.pluginFeeAmount += delta;
        }

        if (result.currentLiquidity > 0) cache.totalFeeGrowthInput += FullMath.mulDiv(step.feeAmount, Constants.Q128, result.currentLiquidity);

        if (result.currentPrice == step.nextTickPrice) {
          if (!cache.crossedAnyTick) {
            cache.crossedAnyTick = true;
            cache.totalFeeGrowthOutput = params.zeroToOne ? totalFeeGrowth1Token : totalFeeGrowth0Token;
          }

          int128 liquidityDelta;
          if (params.zeroToOne) {
            (liquidityDelta, cache.prevInitializedTick, ) = ticks.cross(nextTick, cache.totalFeeGrowthInput, cache.totalFeeGrowthOutput);
            liquidityDelta = -liquidityDelta;
            (result.currentTick, cache.nextInitializedTick) = (nextTick - 1, nextTick);
          } else {
            (liquidityDelta, , cache.nextInitializedTick) = ticks.cross(nextTick, cache.totalFeeGrowthOutput, cache.totalFeeGrowthInput);
            (result.currentTick, cache.prevInitializedTick) = (nextTick, nextTick);
          }
          result.currentLiquidity = LiquidityMath.addDelta(result.currentLiquidity, liquidityDelta);
        } else if (result.currentPrice != step.stepSqrtPrice) {
          result.currentTick = TickMath.getTickAtSqrtRatio(result.currentPrice);
          break;
        }
      } while (amountRequired != 0 && result.currentPrice != params.limitSqrtPrice);

      int256 amountSpent = cache.amountRequiredInitial - amountRequired;
      (result.amount0, result.amount1) = params.zeroToOne == cache.exactInput
        ? (amountSpent, cache.amountCalculated)
        : (cache.amountCalculated, amountSpent);
    }

    (globalState.price, globalState.tick) = (result.currentPrice, result.currentTick);

    if (cache.crossedAnyTick) {
      (liquidity, prevTickGlobal, nextTickGlobal) = (result.currentLiquidity, cache.prevInitializedTick, cache.nextInitializedTick);
    }
    if (params.zeroToOne) {
      totalFeeGrowth0Token = cache.totalFeeGrowthInput;
    } else {
      totalFeeGrowth1Token = cache.totalFeeGrowthInput;
    }
  }
}
