// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '../base/AlgebraBasePlugin.sol';
import '../interfaces/plugins/IAlmPlugin.sol';
import '../interfaces/IRebalanceManager.sol';

// import 'hardhat/console.sol';

abstract contract AlmPlugin is AlgebraBasePlugin, IAlmPlugin {
    address public rebalanceManager;
    uint32 public slowTwapPeriod;
    uint32 public fastTwapPeriod;

  function initializeALM(address _rebalanceManager, uint32 _slowTwapPeriod, uint32 _fastTwapPeriod) external {
    _authorize();
    require(_rebalanceManager != address(0), '_rebalanceManager must be non zero address');
    require(_slowTwapPeriod >= _fastTwapPeriod, '_slowTwapPeriod must be >= _fastTwapPeriod');
    rebalanceManager = _rebalanceManager;
    slowTwapPeriod = _slowTwapPeriod;
    fastTwapPeriod = _fastTwapPeriod;
  }

    function _obtainTWAPAndRebalance(
        int24 currentTick,
        int24 slowTwapTick,
        int24 fastTwapTick,
        uint32 lastBlockTimestamp,
        bool failedToObtainTWAP
    ) internal {
        IRebalanceManager(rebalanceManager).obtainTWAPAndRebalance(currentTick, slowTwapTick, fastTwapTick, lastBlockTimestamp, failedToObtainTWAP);
    }
}
