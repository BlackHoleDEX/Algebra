// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IRebalanceManager {
	function obtainTWAPAndRebalance(
		int24 currentTick,
        int24 slowTwapTick,
        int24 fastTwapTick,
        uint32 lastBlockTimestamp,
        bool failedToObtainTWAP
	) external;
}
