// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import 'algebra/contracts/interfaces/IAlgebraFactory.sol';
import 'algebra/contracts/interfaces/IAlgebraPool.sol';
import './PeripheryImmutableState.sol';
import '../interfaces/IPoolInitializer.sol';

/// @title Creates and initializes V3 Pools
abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    /// @inheritdoc IPoolInitializer
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint160 sqrtPriceX96
    ) external payable override returns (address pool) {
        require(token0 < token1);

        pool = IAlgebraFactory(factory).poolByPair(token0, token1);

        if (pool == address(0)) {
            pool = IAlgebraFactory(factory).createPool(token0, token1);

            IAlgebraPool(pool).initialize(sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing, , , , , , , ) = IAlgebraPool(pool).globalState();
            if (sqrtPriceX96Existing == 0) {
                IAlgebraPool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
