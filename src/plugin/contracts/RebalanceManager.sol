// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './base/BaseRebalanceManager.sol';

contract RebalanceManager is BaseRebalanceManager {
  constructor(address _vault, Thresholds memory _thresholds) {
    require(!isAlmInitialized, 'Already initialized');
    isAlmInitialized = true;
    paused = false;
    // TODO: добавить require'ов
    vault = _vault;
    pool = IAlgebraVault(vault).pool();

    tickSpacing = IAlgebraPool(pool).tickSpacing();

    bool _allowToken1 = IAlgebraVault(vault).allowToken1();

    allowToken1 = _allowToken1;
    state = State.OverInventory; // поч overinventory?
    lastRebalanceTimestamp = 0;
    lastRebalanceCurrentPrice = 0;
    thresholds = _thresholds;

    address token0 = IAlgebraVault(_vault).token0();
    address token1 = IAlgebraVault(_vault).token1();

    address _pairedToken = _allowToken1 ? token0 : token1;
    pairedToken = _pairedToken;
    uint8 _pairedTokenDecimals = _getPairedTokenDecimals();
    // console.log('_pairedTokenDecimals: ', _pairedTokenDecimals);
    pairedTokenDecimals = _pairedTokenDecimals;

    address _depositToken = _allowToken1 ? token1 : token0;
    depositToken = _depositToken;
    uint8 _depositTokenDecimals = _getDepositTokenDecimals();
    depositTokenDecimals = _depositTokenDecimals;
    // console.log('_depositTokenDecimals: ', _depositTokenDecimals);

    decimalsSum = _depositTokenDecimals + _pairedTokenDecimals;
    // console.log('decimals sum: ', decimalsSum);
    tokenDecimals = _allowToken1 ? _pairedTokenDecimals : _depositTokenDecimals;
  }
}
