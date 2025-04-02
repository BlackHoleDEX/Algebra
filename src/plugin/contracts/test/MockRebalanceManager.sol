// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import '../RebalanceManager.sol';

contract MockRebalanceManager is RebalanceManager {
  uint256 public depositTokenBalance;
  uint256 public slowPrice;
  uint256 public fastPrice;
  uint256 public currentPrice;
  uint8 public depositDecimals;
  uint8 public pairedDecimals;

  constructor(address _vault, uint32 _minTimeBetweenRebalances, Thresholds memory _thresholds) RebalanceManager(_vault, _minTimeBetweenRebalances, _thresholds) {}

  function setDepositTokenBalance(uint256 _depositTokenBalance) public {
    depositTokenBalance = _depositTokenBalance;
  }

  function setState(State _state) public {
    state = _state;
  }

  function setLastRebalanceCurrentPrice(uint256 _lastRebalanceCurrentPrice) public {
    lastRebalanceCurrentPrice = _lastRebalanceCurrentPrice;
  }

  function setDecimals(uint8 _depositDecimals, uint8 _pairedDecimals) public {
    (depositTokenDecimals, pairedTokenDecimals) = (_depositDecimals, _pairedDecimals);

    decimalsSum = _depositDecimals + _pairedDecimals;
    // console.log('decimals sum: ', decimalsSum);
    tokenDecimals = allowToken1 ? _pairedDecimals : _depositDecimals;
  }

  function _getDepositTokenVaultBalance() internal view override returns (uint256) {
    return depositTokenBalance;
  }

  function _getDepositTokenDecimals() internal view override returns (uint8) {
    return depositDecimals;
  }

  function _getPairedTokenDecimals() internal view override returns (uint8) {
    return pairedDecimals;
  }
}
