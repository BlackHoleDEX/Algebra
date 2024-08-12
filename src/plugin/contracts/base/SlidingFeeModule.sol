// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IAlgebraPool} from '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol';
import {Timestamp} from '@cryptoalgebra/integral-core/contracts/base/common/Timestamp.sol';
import {TickMath} from '@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol';

import 'hardhat/console.sol';

abstract contract SlidingFeeModule is Timestamp {
    struct FeeFactors {
        uint128 zeroToOneFeeFactor;
        uint128 oneToZeroFeeFactor;
    }

    uint64 internal constant FEE_FACTOR_SHIFT = 96;

    FeeFactors public s_feeFactors;

    uint256 public s_priceChangeFactor = 1;

    event PriceChangeFactor(uint256 priceChangeFactor);

    constructor() {
        FeeFactors memory feeFactors = FeeFactors(
            uint128(1 << FEE_FACTOR_SHIFT),
            uint128(1 << FEE_FACTOR_SHIFT)
        );

        s_feeFactors = feeFactors;
    }

    function _getFeeAndUpdateFactors(
        int24 currenTick,
        int24 lastTick,
        uint16 poolFee,
        bool zeroToOne
    ) internal returns (uint16) {
        FeeFactors memory currentFeeFactors;

        // console.log('current price: ', currentPrice);
        // console.log('last price: ', lastPrice);
        // console.log('zero to one: ', zeroToOne);

        // ❗❗❗
        // раньше было currentPrice = 0, я так понял проверка на то, инициализирована ли была цена
        // теперь currentTick = 0 - валидное значение, возможно стоит передавать доп аргумент
        if (lastTick == 0) {
            return poolFee;
        }

        currentFeeFactors = _calculateFeeFactors(currenTick, lastTick);

        s_feeFactors = currentFeeFactors;

        uint16 adjustedFee = zeroToOne ?
            uint16((poolFee * currentFeeFactors.zeroToOneFeeFactor) >> FEE_FACTOR_SHIFT) :
            uint16((poolFee * currentFeeFactors.oneToZeroFeeFactor) >> FEE_FACTOR_SHIFT);

        return adjustedFee;
    }

    function _calculateFeeFactors(
        int24 currentTick,
        int24 lastTick
    ) internal view returns (FeeFactors memory feeFactors) {
        console.log('currentTick: ');
        console.logInt(int256(currentTick));
        console.log('lastTick: ');
        console.logInt(int256(lastTick));
        // price change is positive after zeroToOne prevalence
        int256 priceChangeRatio = int256(uint256(TickMath.getSqrtRatioAtTick(currentTick - lastTick))) - int256(1 << FEE_FACTOR_SHIFT); // (currentPrice - lastPrice) / lastPrice
        console.log('priceChangeRatio: ');
        console.logInt(priceChangeRatio);
        int128 feeFactorImpact = int128(priceChangeRatio * int256(s_priceChangeFactor));

        feeFactors = s_feeFactors;

        // if there were zeroToOne prevalence in the last price change,
        // in result price has increased
        // we need to increase zeroToOneFeeFactor
        // and vice versa
        int128 newZeroToOneFeeFactor = int128(feeFactors.zeroToOneFeeFactor) + feeFactorImpact;

        if ((int128(-2) << FEE_FACTOR_SHIFT) < newZeroToOneFeeFactor && newZeroToOneFeeFactor < int128(uint128(2) << FEE_FACTOR_SHIFT)) {
            feeFactors = FeeFactors(
                uint128(newZeroToOneFeeFactor),
                uint128(int128(feeFactors.oneToZeroFeeFactor) - feeFactorImpact)
            );
        } else if (newZeroToOneFeeFactor <= 0) {
            // In this case price has decreased that much so newZeroToOneFeeFactor is less than 0
            // So we set it to the minimal value == 0
            // It means that there were too much oneToZero prevalence and we want to decrease it
            // Basically price change is -100%
            feeFactors = FeeFactors(
                uint128(2 << FEE_FACTOR_SHIFT),
                0
            );
        } else {
            // In this case priceChange is big enough that newZeroToOneFeeFactor is greater than 2
            // So we set it to the maximum value
            // It means that there were too much zeroToOne prevalence and we want to decrease it
            feeFactors = FeeFactors(
                0,
                uint128(2 << FEE_FACTOR_SHIFT)
            );
        }
    }
}