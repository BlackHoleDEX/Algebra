// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import '../RebalanceManager.sol';

contract MockRebalanceManager is RebalanceManager {
	constructor(address _vault, Thresholds memory _thresholds) RebalanceManager(_vault, _thresholds) {}
	function _getDepositTokenDecimals() internal view override returns (uint8) {
		return 18;
	}

	function _getPairedTokenDecimals() internal view override returns (uint8) {
		return 18;
	}
}
