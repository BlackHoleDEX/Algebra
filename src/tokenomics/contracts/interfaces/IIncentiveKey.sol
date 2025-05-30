// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import 'algebra/contracts/interfaces/IERC20Minimal.sol';
import 'algebra/contracts/interfaces/IAlgebraPool.sol';

interface IIncentiveKey {
    /// @param rewardToken The token being distributed as a reward
    /// @param bonusRewardToken The bonus token being distributed as a reward
    /// @param pool The Algebra pool
    /// @param startTime The time when the incentive program begins
    /// @param endTime The time when rewards stop accruing
    struct IncentiveKey {
        IERC20Minimal rewardToken;
        IERC20Minimal bonusRewardToken;
        IAlgebraPool pool;
        uint256 startTime;
        uint256 endTime;
    }
}
