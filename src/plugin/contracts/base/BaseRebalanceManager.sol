// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/alm-vault/contracts/interfaces/IAlgebraVault.sol';
import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';
import '@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol';
import '@cryptoalgebra/integral-core/contracts/libraries/FullMath.sol';
import '@cryptoalgebra/integral-core/contracts/base/common/Timestamp.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import '@openzeppelin/contracts/utils/math/Math.sol';

import '../interfaces/IRebalanceManager.sol';

import './AlgebraBasePlugin.sol';

// import 'hardhat/console.sol';

abstract contract BaseRebalanceManager is IRebalanceManager, Timestamp {
  bytes32 public constant ALGEBRA_BASE_PLUGIN_MANAGER = keccak256('ALGEBRA_BASE_PLUGIN_MANAGER');

  // address public pool;
  // function _blockTimestamp() internal pure returns(uint32) {
  //     return 0;
  // }
  // function _authorize() internal pure {
  //     return;
  // }
  // result.currentTick = int24(0); // 0
  // result.currentPriceAccountingDecimals = 0; // 32
  // result.slowAvgPriceAccountingDecimals = 0; // 64
  // result.fastAvgPriceAccountingDecimals = 0; // 96
  // result.totalPairedInDeposit = 0; // 128
  // result.percentageOfDepositToken = 0; // 160
  // result.totalDepositToken = 0; // 192
  // result.totalPairedToken = 0; // 224
  // result.result.percentageOfDepositTokenUnused = 0; // 256
  // result.failedToObtainTWAP = False; // 288
  // result.sameBlock = False; // 320
  struct TwapResult {
    uint256 currentPriceAccountingDecimals;
    uint256 slowAvgPriceAccountingDecimals;
    uint256 fastAvgPriceAccountingDecimals;
    uint256 totalPairedInDeposit;
    uint256 totalDepositToken;
    uint256 totalPairedToken;
    int24 currentTick;
    uint16 percentageOfDepositTokenUnused; // 10000 = 100%
    uint16 percentageOfDepositToken; // 10000 = 100%
    bool failedToObtainTWAP;
    bool sameBlock;
  }
  struct Ranges {
    int24 baseLower;
    int24 baseUpper;
    int24 limitLower;
    int24 limitUpper;
  }
  enum State {
    OverInventory,
    Normal,
    UnderInventory,
    Special
  }
  //                                                                     этот статус можно офнуть
  enum DecideStatus {
    Normal,
    Special,
    PendingRebalanceNeeded,
    NoNeed,
    ToSoon,
    NoNeedWithPending,
    FailedToObtainTWAPOrExtremeVolatility
  }
  enum UpdateStatus {
    Status0,
    Status1
  }

  struct Thresholds {
    uint16 depositTokenUnusedThreshold; // STORAGE[0xb] = 100    (1%)
    uint16 simulate; // 9300 93% maybe for moving a position towards price without changing the config
    uint16 normalThreshold; // 80% (for what? normal trigger?)
    uint16 underInventoryThreshold; // STORAGE[0xf] = 7700        Probably means 77% for under-inventory (opposite of _simulate)
    uint16 overInventoryThreshold; // STORAGE[0xd] = 9100        91% (over-inv trigger?)
    uint16 priceChangeThreshold; // STORAGE[0x8] = 100, в коде если пендинг, то 100, а если не пендинг то 50
    uint16 extremeVolatility; // STORAGE[0x4] = 2500 (25%)
    uint16 highVolatility; // STORAGE[0x5] = 500 (5%)
    uint16 someVolatility; // STORAGE[0x6] = 100 (1%)
    uint16 dtrDelta; // STORAGE[0x7] = 300
    uint16 baseLowPct; // STORAGE[0x1c] = 2000
    uint16 baseHighPct; // STORAGE[0x1d] = 1000
    uint16 limitReservePct; // STORAGE[0x1e] = 500
  }

  // TODO: не забыть у твап не падать, а возвращать false если не получилось взять его
  // TODO: норм упаковать
  address public vault;
  bool public isAlmInitialized;
  bool public paused;
  bool public allowToken1;
  State public state;
  uint32 public lastRebalanceTimestamp;
  uint256 public lastRebalanceCurrentPrice;
  Thresholds public thresholds;

  address public pairedToken; // STORAGE[0x16] bytes 0 to 19
  uint8 public pairedTokenDecimals; // = 18 STORAGE[0x17]
  address public depositToken; // STORAGE[0x18] bytes 0 to 19
  uint8 public depositTokenDecimals; // STORAGE[0x19]
  uint8 public decimalsSum; // STORAGE[0x1a] // это че? (сумма decimals depositToken и pairedToken) а нахуя?
  uint8 public tokenDecimals; // pairedTokenDecimals ? в чем отличие
  int24 public tickSpacing;
  address public factory;
  address public pool;

  function setPriceChangeThreshold(uint16 _priceChangeThreshold) external {
    _authorize();
    require(_priceChangeThreshold < 10000, 'Invalid price change threshold');
    thresholds.priceChangeThreshold = _priceChangeThreshold;
    // нужно эмитить ивент?
  }

  function setPercentages(uint16 _baseLowPct, uint16 _baseHighPct, uint16 _limitReservePct) external {
    _authorize();
    require(_baseLowPct >= 100 && _baseLowPct <= 10000, 'Invalid base low percent');
    require(_baseHighPct >= 100 && _baseHighPct <= 10000, 'Invalid base high percent');
    require(_limitReservePct >= 100 && _baseLowPct <= 10000 - thresholds.simulate, 'Invalid limit reserve percent');
    thresholds.baseLowPct = _baseLowPct;
    thresholds.baseHighPct = _baseHighPct;
    thresholds.limitReservePct = _limitReservePct;
  }

  function setTriggers(uint16 _simulate, uint16 _normalThreshold, uint16 _underInventoryThreshold, uint16 _overInventoryThreshold) external {
    _authorize();
    require(_underInventoryThreshold > 6000, '_underInventoryThreshold must be > 6000');
    require(_normalThreshold > _underInventoryThreshold, '_normalThreshold must be > _underInventoryThreshold');
    require(_overInventoryThreshold > _normalThreshold, '_overInventoryThreshold must be > _normalThreshold');
    require(_simulate > _overInventoryThreshold, 'Simulate must be > _overInventoryThreshold');
    require(_simulate < 9500, 'Simulate must be < 9500');
    thresholds.simulate = _simulate;
    thresholds.normalThreshold = _normalThreshold;
    thresholds.underInventoryThreshold = _underInventoryThreshold;
    thresholds.overInventoryThreshold = _overInventoryThreshold;
  }

  function setDtrDelta(uint16 _dtrDelta) external {
    _authorize();
    require(_dtrDelta <= 10000, '_dtrDelta must be <= 10000');
    thresholds.dtrDelta = _dtrDelta;
  }

  function setHighVolatility(uint16 _highVolatility) external {
    _authorize();
    require(_highVolatility >= thresholds.someVolatility, '_highVolatility must be >= someVolatility');
    thresholds.highVolatility = _highVolatility;
  }

  function setSomeVolatility(uint16 _someVolatility) external {
    _authorize();
    require(_someVolatility <= 300, '_someVolatility must be <= 300');
    thresholds.someVolatility = _someVolatility;
  }

  function setExtremeVolatility(uint16 _extremeVolatility) external {
    _authorize();
    require(_extremeVolatility >= thresholds.highVolatility, '_extremeVolatility must be >= highVolatility');
    thresholds.extremeVolatility = _extremeVolatility;
  }

  function setDepositTokenUnusedThreshold(uint16 _depositTokenUnusedThreshold) external {
    _authorize();
    require(
      _depositTokenUnusedThreshold >= 100 && _depositTokenUnusedThreshold <= 10000,
      '_depositTokenUnusedThreshold must be 100 <= _depositTokenUnusedThreshold <= 10000'
    );
    thresholds.depositTokenUnusedThreshold = _depositTokenUnusedThreshold;
  }

  function setVault(address _vault) external {
    _authorize();
    vault = _vault;
  }

  // TODO: написать obtainTWAPAndRebalance()

  function obtainTWAPAndRebalance(
    int24 currentTick,
    int24 slowTwapTick,
    int24 fastTwapTick,
    uint32 lastBlockTimestamp
  ) external {
    // console.log('entered obtainTWAPAndRebalance');
    TwapResult memory twapResult = _obtainTWAPs(currentTick, slowTwapTick, fastTwapTick, lastBlockTimestamp);
    // console.log("TWAP RESULT START");
		// console.log(twapResult.currentPriceAccountingDecimals);
		// console.log(twapResult.slowAvgPriceAccountingDecimals);
		// console.log(twapResult.fastAvgPriceAccountingDecimals);
		// console.log(twapResult.totalPairedInDeposit);
		// console.log(twapResult.totalDepositToken);
		// console.log(twapResult.totalPairedToken);
		// console.logInt(twapResult.currentTick);
		// console.log(twapResult.percentageOfDepositTokenUnused);
		// console.log(twapResult.percentageOfDepositToken);
		// console.log(twapResult.failedToObtainTWAP);
		// console.log(twapResult.sameBlock);
		// console.log("TWAP RESULT END");
    _rebalance(twapResult);
  }

  function _rebalance(TwapResult memory obtainTWAPsResult) internal {
    // require(!paused, 'Pausable: paused');
    if (paused) return;
    if (vault == address(0)) return;

    (DecideStatus decideStatus, State newState) = _decideRebalance(obtainTWAPsResult);
    // console.log('rebalance entered');
    // console.log('decide status: ', uint256(decideStatus));
    // console.log('newState: ', uint256(newState));

    // TODO: сделать тут просто возвращаение результата, чтобы если ребаланс не нужен был, то вся транза не падала
    // require(decideStatus != DecideStatus.NoNeed, "no need");
    // require(decideStatus != DecideStatus.ToSoon, "too soon");
    if (decideStatus == DecideStatus.NoNeed || decideStatus == DecideStatus.ToSoon) return;

    if (decideStatus != DecideStatus.PendingRebalanceNeeded) {
      if (decideStatus != DecideStatus.NoNeedWithPending) {
        if (decideStatus != DecideStatus.FailedToObtainTWAPOrExtremeVolatility) {
          Ranges memory ranges = decideStatus == DecideStatus.Normal
            ? _getRangesWithState(newState, obtainTWAPsResult)
            : _getRangesWithoutState(obtainTWAPsResult);

          // struct Ranges {
          //         int24 baseLower;
          //         int24 baseUpper;
          //         int24 limitLower;
          //         int24 limitUpper;
          // }
          // console.log('RANGES START');
          // console.logInt(ranges.baseLower);
          // console.logInt(ranges.baseUpper);
          // console.logInt(ranges.limitLower);
          // console.logInt(ranges.limitUpper);
          // console.log('RANGES END');

          // require(ranges.baseUpper - ranges.baseLower > 300 &&
          //                 ranges.limitUpper - ranges.limitLower > 300, 'positions are concentrated too much');
          if (ranges.baseUpper - ranges.baseLower <= 300 || ranges.limitUpper - ranges.limitLower <= 300) return;

          // что за v10 и v11? как их достать? (1 из них success call'a, а второй?)
          // v10, /* bool */ v11 = address(_gnosis >> 8).execTransactionFromModule(_vault, 0, 128, 0, 164, v12, v12, v12, v12, v12, v9).gas(msg.gas);

          // TODO: swapquantity ?
          try IAlgebraVault(vault).rebalance(ranges.baseLower, ranges.baseUpper, ranges.limitLower, ranges.limitUpper, 1) {
            lastRebalanceTimestamp = _blockTimestamp();
            lastRebalanceCurrentPrice = obtainTWAPsResult.currentPriceAccountingDecimals;
          } catch {
            state = State.Special;
            _pause();
          }
        } else {
          IAlgebraVault(vault).setDepositMax(0, 0);
          // pendingRebalanceTimestamp = 0;
          state = State.Special;
          _pause();
        }
      } else {
        // pendingRebalanceTimestamp = 0;
        lastRebalanceTimestamp = _blockTimestamp();
        lastRebalanceCurrentPrice = obtainTWAPsResult.currentPriceAccountingDecimals;
      }
    } else {
      // pendingRebalanceTimestamp = _blockTimestamp();
    }

    // чекируем decideStatus
    // если нужен ребаланс
    // вызываем getrangeswithstate или getRangesWithoutState, получаем ренжи
    // IAlgebraVault(vault).rebalance(ranges.tick1, ranges.tick2, ....);
  }

  function _obtainTWAPs(
    int24 currentTick,
    int24 slowTwapTick,
    int24 fastTwapTick,
    uint32 lastBlockTimestamp
  ) internal view returns (TwapResult memory twapResult) {
    // достать проценты, хуенты
    // достать резервы токенычей
    // собрать TwapResult

    // struct TwapResult {
    //         uint256 currentPriceAccountingDecimals; done
    //         uint256 slowAvgPriceAccountingDecimals; done
    //         uint256 fastAvgPriceAccountingDecimals; done
    //         uint256 totalPairedInDeposit; done
    //         uint256 totalDepositToken; done
    //         uint256 totalPairedToken; done
    //         int24 currentTick; done
    //         uint16 percentageOfDepositTokenUnused; // 10000 = 100% done
    //         uint16 percentageOfDepositToken; // 10000 = 100% done
    //         bool failedToObtainTWAP; // всегда false прост done
    //         bool sameBlock; done
    // }

    // console.log('entered obtain twaps');
    twapResult.failedToObtainTWAP = false;

    twapResult.currentTick = currentTick;
    twapResult.sameBlock = _blockTimestamp() == lastBlockTimestamp;
    bool _allowToken1 = allowToken1;
    // console.log("allowToken1: ", allowToken1);
    if (_allowToken1) {
      // почему они эту строку наверх не вынесли?
      (uint256 amount0, uint256 amount1) = IAlgebraVault(vault).getTotalAmounts();
      twapResult.totalPairedToken = amount0;
      twapResult.totalDepositToken = amount1;
    } else {
      (uint256 amount0, uint256 amount1) = IAlgebraVault(vault).getTotalAmounts();
      twapResult.totalPairedToken = amount1;
      twapResult.totalDepositToken = amount0;
    }
    // console.log('after getTotalAmounts obtain twaps');

    address _depositToken = depositToken;
    address _pairedToken = pairedToken;

    uint8 _pairedTokenDecimals = pairedTokenDecimals;

    (uint256 slowPrice, uint256 fastPrice, uint256 currentPriceAccountingDecimals) = _getTwapPrices(
      _depositToken,
      _pairedToken,
      _pairedTokenDecimals,
      slowTwapTick,
      fastTwapTick,
      twapResult.currentTick
    );
    twapResult.slowAvgPriceAccountingDecimals = slowPrice;
    twapResult.fastAvgPriceAccountingDecimals = fastPrice;

    // uint256 slowPrice = _getPriceAccountingDecimals(_depositToken, _pairedToken, uint128(10 ** _pairedTokenDecimals), slowTwapTick);
    // twapResult.slowAvgPriceAccountingDecimals = slowPrice;
    // uint256 fastPrice = _getPriceAccountingDecimals(_depositToken, _pairedToken, uint128(10 ** _pairedTokenDecimals), fastTwapTick);
    // twapResult.fastAvgPriceAccountingDecimals = fastPrice;

    // console.log('2');

    // uint256 currentPriceAccountingDecimals = _getPriceAccountingDecimals(_depositToken, _pairedToken, uint128(10 ** _pairedTokenDecimals), twapResult.currentTick);
    // console.log('2.5');
    // console.log("currentPriceAccountingDecimals: ", currentPriceAccountingDecimals);
    // console.log("twapResult.totalPairedToken: ", twapResult.totalPairedToken);
    // console.log("_pairedTokenDecimals: ", _pairedTokenDecimals);
    twapResult.currentPriceAccountingDecimals = currentPriceAccountingDecimals;
    uint256 totalPairedInDepositWithDecimals = currentPriceAccountingDecimals * twapResult.totalPairedToken;
    uint256 totalPairedInDeposit = totalPairedInDepositWithDecimals / (10 ** _pairedTokenDecimals);
    twapResult.totalPairedInDeposit = totalPairedInDeposit;

    // console.log('3');

    // console.log('totalPairedInDeposit: ', totalPairedInDeposit);
    if (totalPairedInDeposit == 0) {
      twapResult.percentageOfDepositToken = 10000;
    } else {
      uint256 totalTokensAmount = twapResult.totalDepositToken + twapResult.totalPairedInDeposit;
      // // console.log("totalTokensAmount: ", totalTokensAmount);
      if (totalTokensAmount == 0) {
        twapResult.failedToObtainTWAP = true;
        return twapResult;
      }
      // uint256 totalDepositTokenMultipliedByFactor = 10000 * twapResult.totalDepositToken;
      uint16 percentageOfDepositToken = uint16((twapResult.totalDepositToken * 10000) / totalTokensAmount);
      twapResult.percentageOfDepositToken = percentageOfDepositToken;
    }

    // console.log('4');

    uint256 depositTokenBalance = _getDepositTokenVaultBalance();
    // console.log('depositTokenBalance: ', depositTokenBalance);

    if (depositTokenBalance > 0) {
      uint256 totalTokensAmount = twapResult.totalDepositToken + twapResult.totalPairedInDeposit;
      // console.log('totalTokensAmount: ', totalTokensAmount);
      // uint256 totalDepositTokenMultipliedByFactor = depositTokenBalance * 10000;
      // че за v42 и v43, надо чекнуть первоначальный декомпайл
      // V42 = v41 / v40 = (10000 * depositTokenBalance) / (result.totalDepositToken + result.totalPairedInDeposit)
      twapResult.percentageOfDepositTokenUnused = uint16((depositTokenBalance * 10000) / totalTokensAmount);
    } else {
      // че за v44
      // v42 = v44 = 0;
      twapResult.percentageOfDepositTokenUnused = 0;
    }
  }

  function _decideRebalance(TwapResult memory twapResult) internal returns (DecideStatus, State) {
    // тут мы более глобально чекаем, получилось ли достать твап, какая ща волатильность
    // куча куча ифов, в итоге в одном из случаев вызываем
    // вычисления на основе twapResult И UpdateStatus, юзается вспомогательная функция _calcPercentageDiff
    // UpdateStatus updStatus = _updateStatus(twapResult);
    if (twapResult.failedToObtainTWAP) {
      return (DecideStatus.FailedToObtainTWAPOrExtremeVolatility, State.Special);
    }

    uint256 fastSlowDiff = _calcPercentageDiff(twapResult.fastAvgPriceAccountingDecimals, twapResult.slowAvgPriceAccountingDecimals);
    uint256 fastCurrentDiff = _calcPercentageDiff(twapResult.fastAvgPriceAccountingDecimals, twapResult.currentPriceAccountingDecimals);
    // console.log('fastSlowDiff: ', fastSlowDiff);
    // console.log('fastCurrentDiff: ', fastCurrentDiff);

    bool isExtremeVolatility = fastSlowDiff >= thresholds.extremeVolatility || fastCurrentDiff >= thresholds.extremeVolatility;
    if (!isExtremeVolatility) {
      bool isHighVolatility = fastSlowDiff >= thresholds.highVolatility || fastCurrentDiff >= thresholds.highVolatility;
      if (!isHighVolatility) {
        if (
          !((state == State.OverInventory || state == State.Normal) &&
            lastRebalanceCurrentPrice != 0 &&
            twapResult.percentageOfDepositToken < thresholds.underInventoryThreshold - thresholds.dtrDelta)
        ) {
          (bool needToRebalance, State newState) = _updateStatus(twapResult);
          // console.log('needToRebalance: ', needToRebalance);
          // console.log('newState: ', uint256(newState));
          // needToRebalance = true;
          // newState = State.Normal;
          if (needToRebalance) {
            if (fastCurrentDiff < thresholds.someVolatility) {
              // console.log('fastCurrentDiff < thresholds.someVolatility');
              return (DecideStatus.Normal, newState); // normal rebalance
            } else {
              return (DecideStatus.ToSoon, newState); // too soon
            }
          } else {
            return (DecideStatus.NoNeedWithPending, newState); // pending rebalance but no rebalance needed??? (this is when twapResult.percentageOfToken1 is less than 1%)
          }
        } else {
          // State == NORMAL || OVER
          // И Это не первый ребаланс
          // И percentageOfDepositToken меньше чем _underInventoryPct - _dtrDelta (??) - значит очень мало депозит токенов, то:
          // ----> переходим дальше в итоге выставляя status = SPECIAL
          // тут как будто ничо не происходит
          // типа тут сетятся v19, v21, v23, v25
          // но дальше с ними ничо не происходит
          // только в гносис записываем v23, который итак равен гносису
          // v19 = v20 = 21;
          // v21 = v22 = 3;
          // v23 = v24 = bytes31(_gnosis);
          // v25 = v26 = 1;
        }
      } else {
        // handle high volatility
        // Если fastSlowDiff >= _highVolatility ИЛИ fastCurrentDiff => _highVolatility (5%), то считаем, что сейчас высокая волатильность.
        if (state != State.Special) {
          // Проверяем, что сейчас Status != SPECIAL, иначе - ребаланс не делается

          if (fastCurrentDiff >= thresholds.someVolatility && twapResult.sameBlock) {
            // Если fastCurrentDiff >= _someVolatility (low? - 1%):
            // Проверяем, что последний timepoint был записан не в том же блоке, в котором мы исполняем транзакцию, иначе - ребаланс не делается
            return (DecideStatus.ToSoon, State.Special);
          } else {
            // Иначе ------> переходим дальше в итоге выставляя status = SPECIAL
            // то же самое, как будто нихуя не происходит
            // v19 = v30 = 21;
            // v21 = v31 = 3;
            // v23 = v32 = bytes31(_gnosis);
            // v25 = v33 = 1;
          }
        } else {
          // special -> noneed
          return (DecideStatus.NoNeed, State.Special);
        }
      }
      state = State.Special;
      // какой-то спешл кейс, из-за него вызывается rebalanceWithoutState
      return (DecideStatus.Special, State.Special); // выяснить чо он означает
    } else {
      // Если fastSlowDiff >= _extremeVolatility ИЛИ fastCurrentDiff => _extremeVolatility (25%), то считаем, что сейчас экстремальная волатильность и ребаланс не делается
      return (DecideStatus.FailedToObtainTWAPOrExtremeVolatility, State.Special);
    }
  }

  function _updateStatus(TwapResult memory twapResult) internal view returns (bool, State) {
    // тут мы сравниваем уже все проценты и решаем в какой стейт мы будем рабаланситься (и будем ли вообще)
    // вычисления на оснвое twapResult, сохранение результата в сторадж, видимо нужно из-за двухэтапной ребалансировки (можно ли объединить в одну функцию?)
    // внутри вызываетя вспомогательная функция _calcPercentageDiff
    // v0 = state == 3 ? true : !lastRebalanceCurrentPrice
    if (state != State.Special && lastRebalanceCurrentPrice != 0) {
      if (state != State.Normal) {
        if (state != State.OverInventory) {
          if (twapResult.percentageOfDepositToken <= thresholds.simulate) {
            // if less than 93%
            // console.log('twapResult.percentageOfDepositToken <= thresholds.simulate');
            if (twapResult.percentageOfDepositToken >= thresholds.normalThreshold) {
              // if greater than 80% (REBALANCE TO NORMAL)
              // sqrtStatus = 1;
              // state == UnderInventory || state == Special
              // 80% <= twapResult.percentageOfDepositToken <= 93%
              // типа из андеринветори или спешл ребалансим в НОРМАЛ
              return (true, State.Normal);
            }
            // else {
            //   return (true, State.UnderInventory);
            // }
          } else {
            // sqrtStatus = 1;
            // state == UnderInventory || state == Special
            // twapResult.percentageOfDepositToken >= 93%
            return (true, State.OverInventory);
          }
        } else if (twapResult.percentageOfDepositToken >= thresholds.underInventoryThreshold) {
          // if greater than 77%
          if (twapResult.percentageOfDepositToken <= thresholds.overInventoryThreshold) {
            // if less than 91% (REBALANCE TO NORMAL)
            // sqrtStatus = 1;
            // state == OverInventory
            // 77% <= twapResult.percentageOfDepositToken <= 91%
            // типа из оверинвентори в НОРМАЛ
            return (true, State.Normal);
          }
          // WHAT IF GREATER THAN 91%? (STAYING OVER-INVENTORY)
          // else {
          //   return (true, State.OverInventory);
          // }
        } else {
          // state == OverInventory
          // twapResult.percentageOfDepositToken <= 77%
          // из оверинвентори хуячимся в андеринвентори
          return (true, State.UnderInventory);
        }

        // TODO: unreachable код, подумать чо с ним делать (тесты все проходят)
        uint256 priceChange = _calcPercentageDiff(lastRebalanceCurrentPrice, twapResult.currentPriceAccountingDecimals); // percentage diff between lastRebalanceCurrentPrice and currentPriceAccountingDecimals
        // console.log('priceChange: ', priceChange);
        // console.log('priceChange: ', priceChange);
        // console.log('threshold: ', thresholds.priceChangeThreshold);
        if (priceChange > thresholds.priceChangeThreshold) {
          // CASES:
          // 1. we are still under-inventory and price changed by more than (1/0.5)%
          // 2. we are still over-inventory and price changed by more than (1/0.5)%

          // console.log('priceChange > thresholds.priceChangeThreshold');
          return (true, state);
        }
      } else if (twapResult.percentageOfDepositToken <= thresholds.simulate) {
        if (twapResult.percentageOfDepositToken < thresholds.underInventoryThreshold) {
          // state == Normal
          // twapResult.percentageOfDepositToken < 77% <= 93 %
          return (true, State.UnderInventory);
        }
      } else {
        // state == Normal
        // twapResult.percentageOfDepositToken > 93%
        return (true, State.OverInventory);
      }

      if (twapResult.percentageOfDepositTokenUnused <= thresholds.depositTokenUnusedThreshold) {
        // if less than 1%
        // console.log('twapResult.percentageOfDepositTokenUnused <= thresholds.depositTokenUnusedThreshold');
        return (false, State.Normal); // no rebalance needed
      } else {
        // CASES:
        // 1. state == Normal and 75% < twapResult.percentageOfDepositToken < 93%
        return (true, state);
      }
    } else {
      if (twapResult.percentageOfDepositToken <= thresholds.simulate) {
        // if less than 93%
        if (twapResult.percentageOfDepositToken >= thresholds.underInventoryThreshold) {
          // if greater than 77% (REBALANCE TO NORMAL)
          // state == Special OR not lastRebalanceCurrentPrice
          // 77% <= twapResult.percentageOfDepositToken <= 93%
          return (true, State.Normal);
        } else {
          // state == Special OR not lastRebalanceCurrentPrice
          // twapResult.percentageOfDepositToken <= 77%
          return (true, State.UnderInventory);
        }
      } else {
        // state == Special OR not lastRebalanceCurrentPrice
        // twapResult.percentageOfDepositToken > 93%
        return (true, State.OverInventory);
      }
    }

    // сюда по идее никогда не попадаем (точно??) точно
    return (false, State.Normal);
  }

  function _getRangesWithState(State newState, TwapResult memory twapResult) internal view returns (Ranges memory ranges) {
    // scope to prevent stack too deep
    {
      // console.log('entered _getRangesWithState');
      // State _state = state;
      bool _allowToken1 = allowToken1;
      int24 _tickSpacing = tickSpacing;
      uint8 _tokenDecimals = tokenDecimals;

      (uint256 upperPriceBound, uint256 targetPrice, uint256 lowerPriceBound) = _getPriceBounds(newState, twapResult, _allowToken1);
      // console.log('upperPriceBound: ', upperPriceBound);
      // console.log('targetPrice: ', targetPrice);
      // console.log('lowerPriceBound: ', lowerPriceBound);

      // console.log('tickSpacing');
      // console.logInt(_tickSpacing);
      int24 roundedTick = roundTickToTickSpacing(_tickSpacing, twapResult.currentTick);
      bool currentTickIsRound = roundedTick == twapResult.currentTick;

      int24 commonTick;
      int24 tickForLowerPrice;
      if (newState == State.Normal) {
        // If HEALTHY status (NORMAL) use target price
        //                                                                                                                    тут targetPrice без decimals (если deposittoken = token0)
        //                                                                                                                    и с decimals если deposittoken = token1, без X96 или X192
        int24 targetTick = getTickAtPrice(_tokenDecimals, targetPrice);
        // console.log('targetTick');
        // console.logInt(targetTick);
        commonTick = roundTickToTickSpacingConsideringNegative(_tickSpacing, targetTick);
      } else {
        // console.log('entered else in newState == State.Normal');
        commonTick = roundTickToTickSpacingConsideringNegative(_tickSpacing, twapResult.currentTick);
      }

      int24 upperTick = getTickAtPrice(_tokenDecimals, upperPriceBound);
      // console.log('upperTick');
      // console.logInt(upperTick);
      int24 tickForHigherPrice = roundTickToTickSpacingConsideringNegative(_tickSpacing, upperTick);
      // console.log('tickForHigherPrice');
      // console.logInt(tickForHigherPrice);

      if (lowerPriceBound == 0) {
        // Under-inventory state probably
        // if depositToken == token0, надо бы это в сторадж наверное засунуть
        // console.log('entered lowerPriceBound == 0');
        int24 lowerTick = _allowToken1 ? TickMath.MIN_TICK : TickMath.MAX_TICK;
        tickForLowerPrice = (lowerTick / _tickSpacing) * _tickSpacing; // adjust to tick spacing
      } else {
        int24 lowerTick = getTickAtPrice(_tokenDecimals, lowerPriceBound);
        tickForLowerPrice = roundTickToTickSpacingConsideringNegative(_tickSpacing, lowerTick);
      }
      if (!_allowToken1) {
        // if deposittoken == token0
        // console.log('TICKS');
        // console.logInt(int24(commonTick));
        // console.logInt(int24(tickForLowerPrice));
        // console.logInt(int24(tickForHigherPrice));
        // console.logInt(int24(commonTick));
        // console.log('TICKS END');
        ranges.baseLower = int24(commonTick);
        ranges.baseUpper = int24(tickForLowerPrice);
        ranges.limitLower = int24(tickForHigherPrice);
        ranges.limitUpper = int24(commonTick);

        // if (varg0 != 2) {
        //     v19 = 0x437d(int24(_gnosis >> 176), 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffff27618);
        //     v18.word2 = int24(v19);
        // }
        // assert(varg0 <= 3);
        // if (varg0 == 2) {
        //     if (v4) {
        //         v20 = v21 = MEM[varg1];
        //     } else {
        //         v20 = v22 = v18.word0;
        //     }
        //     v18.word0 = int24(v20);
        //     if (v4) {
        //         v23 = v24 = MEM[varg1] - int24(_gnosis >> 176);
        //     } else {
        //         v23 = v25 = v18.word3;
        //     }
        //     v18.word3 = int24(v23);
        // }

        if (newState != State.UnderInventory) {
          // if not under-inventory
          // we do not use v16 because if Token0 then we reverse the structure of ticks
          int24 roundedMinTick = roundTickToTickSpacing(_tickSpacing, TickMath.MIN_TICK);
          ranges.limitLower = int24(roundedMinTick); // use MIN tick
        } else {
          // if under-inventorys
          ranges.baseLower = currentTickIsRound ? twapResult.currentTick : ranges.baseLower; // if tick is round set currentTick (useless operation?)
          ranges.limitUpper = currentTickIsRound ? twapResult.currentTick - _tickSpacing : ranges.limitUpper; // tick - tick spacing if round (avoid having the same tick if its round??)
        }

        if (newState == State.OverInventory) {
          // if over-inventory
          ranges.limitUpper = currentTickIsRound ? twapResult.currentTick : _tickSpacing + ranges.limitUpper;
          ranges.baseLower = currentTickIsRound ? _tickSpacing + twapResult.currentTick : _tickSpacing + ranges.baseLower;
          ranges.baseUpper = int24(ranges.baseUpper + _tickSpacing);
        }
      } else {
        ranges.baseLower = int24(tickForLowerPrice);
        ranges.baseUpper = int24(commonTick);
        ranges.limitLower = int24(commonTick);
        ranges.limitUpper = int24(tickForHigherPrice);

        if (newState != State.UnderInventory) {
          ranges.limitUpper = roundTickToTickSpacing(_tickSpacing, TickMath.MAX_TICK);
        }

        if (lowerPriceBound > 0 && newState != State.OverInventory) {
          ranges.baseLower = int24(ranges.baseLower + _tickSpacing);
        }

        if (newState == State.Normal) {
          ranges.baseUpper = int24(_tickSpacing + ranges.baseUpper);
          ranges.limitLower = int24(_tickSpacing + ranges.limitLower);
        }

        if (newState == State.UnderInventory) {
          ranges.baseUpper = currentTickIsRound ? twapResult.currentTick : _tickSpacing + ranges.baseUpper;
          ranges.limitLower = currentTickIsRound ? _tickSpacing + twapResult.currentTick : _tickSpacing + ranges.limitLower;
        }

        if (newState == State.OverInventory) {
          ranges.baseUpper = currentTickIsRound ? twapResult.currentTick - _tickSpacing : ranges.baseUpper;
          ranges.limitLower = currentTickIsRound ? twapResult.currentTick : ranges.limitLower;
        }
      }
    }
    // просто возвращаем? (НЕ ПРОСТО ОКАЗЫВАЕТСЯ ВОЗВРАЩАЕМ)
    // TODO: пофиксить stackTooDeep
    if (newState == State.OverInventory) {
      (ranges.baseLower, ranges.baseUpper, ranges.limitLower, ranges.limitUpper) = (
        ranges.limitLower,
        ranges.limitUpper,
        ranges.baseLower,
        ranges.baseUpper
      );
      // v49.word0 = int24(MEM[64 + v17]);
      // v49.word1 = int24(MEM[96 + v17]);
      // v49.word2 = int24(MEM[v17]);
      // v49.word3 = int24(MEM[32 + v17]);
    }
  }

  function _getRangesWithoutState(TwapResult memory twapResult) internal view returns (Ranges memory ranges) {
    // возвращает что-то типа
    // result.baseLower = currentTick
    // result.baseUpper = maxUpperTick
    // result.limitLower = minLowerTick
    // result.limitUpper = currentTick - tickSpacing

    int24 _tickSpacing = tickSpacing;
    bool _allowToken1 = allowToken1;

    // внутри юзается roundTickToTickSpacingCondigeringNegative, roundTickToTickSpacing
    int24 tickRoundedDown = roundTickToTickSpacingConsideringNegative(_tickSpacing, twapResult.currentTick);
    int24 tickRounded = roundTickToTickSpacing(_tickSpacing, twapResult.currentTick);
    // console.log('ticks in _getRangesWithoutState');
    // console.logInt(tickRoundedDown);
    // console.logInt(tickRounded);

    if (!_allowToken1) {
      if (twapResult.currentTick == tickRounded) {
        tickRoundedDown = twapResult.currentTick;
      }

      ranges.baseLower = tickRoundedDown;
      int24 maxTickRounded = roundTickToTickSpacing(_tickSpacing, TickMath.MAX_TICK); // round MaxUpperTick
      ranges.baseUpper = maxTickRounded;
      int24 minTickRounded = roundTickToTickSpacing(_tickSpacing, TickMath.MIN_TICK); // round MinLowerTick
      ranges.limitLower = minTickRounded;
      if (twapResult.currentTick == tickRounded) {
        tickRoundedDown = twapResult.currentTick - _tickSpacing;
      }
      ranges.limitUpper = tickRoundedDown;
    } else {
      int24 minTickRounded = roundTickToTickSpacing(_tickSpacing, TickMath.MIN_TICK);
      ranges.baseLower = minTickRounded;

      if (twapResult.currentTick == tickRounded) {
        ranges.baseUpper = twapResult.currentTick;
      } else {
        ranges.baseUpper = tickRoundedDown + _tickSpacing;
      }

      if (twapResult.currentTick == tickRounded) {
        ranges.limitLower = _tickSpacing + twapResult.currentTick;
      } else {
        ranges.limitLower = tickRoundedDown + _tickSpacing;
      }
      int24 maxTickRounded = roundTickToTickSpacing(_tickSpacing, TickMath.MAX_TICK); // round MaxUpperTick
      ranges.limitUpper = maxTickRounded;
    }
  }

  //                                                                                                                                     поч uint128?                    поч uint256?
  //                                                                                        потому что это не decimals, а 10 ** decimals
  function _getPriceAccountingDecimals(
    address token0,
    address token1,
    uint128 token1decimals,
    /*uint256*/ int24 averageTick
  ) private pure returns (uint256 price) {
    uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(averageTick);
    if (uint160(sqrtPriceX96) > type(uint128).max) {
      uint256 priceX128 = FullMath.mulDiv(uint160(sqrtPriceX96), uint160(sqrtPriceX96), uint256(type(uint64).max) + 1);
      return
        token1 < token0
          ? FullMath.mulDiv(priceX128, token1decimals, uint256(type(uint128).max) + 1)
          : FullMath.mulDiv(uint256(type(uint128).max) + 1, token1decimals, priceX128);
    } else {
      // console.log(token0, token1);
      // console.log(token1decimals);
      // console.logInt(int256(averageTick));
      // console.log(sqrtPriceX96);
      // console.log(token1 < token0);
      // if (token1 < token0) {
      //         v5 = v6 = MulDiv(uint192.max + 1, token1decimals, uint160(sqrtPrice96) * uint160(sqrtPrice96));
      // } else {
      //         v5 = v7 = MulDiv(uint160(sqrtPrice96) * uint160(sqrtPrice96), token1decimals, uint192.max + 1);
      // }
      return
        token1 < token0
          ? FullMath.mulDiv(uint256(sqrtPriceX96) * uint256(sqrtPriceX96), token1decimals, uint256(type(uint192).max) + 1)
          : FullMath.mulDiv(uint256(type(uint192).max) + 1, token1decimals, uint256(sqrtPriceX96) * uint256(sqrtPriceX96));
    }
  }

  // как будто у там эти функци вообще не нужны, мы берем твап из бейз плагина, не делаем лишних коллов
  // // пока не очень понятно как она работает и что возвращает
  // // TODO: реализовать getTwapMaybe, внутри вызывается только getTimepoints у пула
  // function _getTWAPMaybe(uint256 secondsAgo, address pool) private {

  // }

  // // пока не очень понятно как она работает и что возвращает
  // // TODO: реализовать getTwap, внутри вызывается только getTimepoints у пула
  // function _getTWAP(uint32 varg0, address varg1) private {

  // }

  // function _getDepositTokenDecimals() internal virtual view returns (uint8) {
  //         return IERC20Metadata(depositToken).decimals();
  // }

  // function _getPairedTokenDecimals() internal virtual view returns (uint8) {
  //         return IERC20Metadata(depositToken).decimals();
  // }

  function _authorize() internal view {
    require(IAlgebraFactory(factory).hasRoleOrOwner(ALGEBRA_BASE_PLUGIN_MANAGER, msg.sender));
  }

  function _getTwapPrices(
    address _depositToken,
    address _pairedToken,
    uint8 _pairedTokenDecimals,
    int24 slowTwapTick,
    int24 fastTwapTick,
    int24 currentTick
  ) internal view virtual returns (uint256, uint256, uint256) {
    return (
      _getPriceAccountingDecimals(_depositToken, _pairedToken, uint128(10 ** _pairedTokenDecimals), slowTwapTick),
      _getPriceAccountingDecimals(_depositToken, _pairedToken, uint128(10 ** _pairedTokenDecimals), fastTwapTick),
      _getPriceAccountingDecimals(_depositToken, _pairedToken, uint128(10 ** _pairedTokenDecimals), currentTick)
    );
  }

  function _getPairedTokenDecimals() internal view virtual returns (uint8) {
    return IERC20Metadata(pairedToken).decimals();
  }

  function _getDepositTokenDecimals() internal view virtual returns (uint8) {
    return IERC20Metadata(depositToken).decimals();
  }

  function _getDepositTokenVaultBalance() internal view virtual returns (uint256) {
    return IERC20Metadata(depositToken).balanceOf(vault);
  }

  function _calcPercentageDiff(uint256 a, uint256 b) private pure returns (uint256) {
    return b > a ? ((b - a) * 10000) / b : ((a - b) * 10000) / a;
  }

  function roundTickToTickSpacing(int24 _tickSpacing, int24 _tick) private pure returns (int24) {
    return (_tick / _tickSpacing) * _tickSpacing;
  }

  function roundTickToTickSpacingConsideringNegative(int24 _tickSpacing, int24 _tick) private pure returns (int24) {
    int24 roundedTick = roundTickToTickSpacing(_tickSpacing, _tick);
    if (_tick < 0) {
      return roundedTick - _tickSpacing;
    } else {
      return roundedTick;
    }
  }

  //                                                                                                                                                                    upper             target    lower
  function _getPriceBounds(State _state, TwapResult memory twapResult, bool _allowToken1) private view returns (uint256, uint256, uint256) {
    uint256 targetPrice = twapResult.currentPriceAccountingDecimals;
    // тут чтобы убрать require нужно тогда прокидывать, видимо
    require(targetPrice != 0, 'middlePrice must be > 0');
    require(twapResult.totalDepositToken > 0, 'no deposit tokens in the vault. need manual rebalance');
    // if (targetPrice == 0 || twapResult.totalDepositToken == 0) return (0, 0, 0);

    uint256 lowerPriceBound = 0;
    if (_state != State.UnderInventory) {
      // if not under-inventory (because if under - we place lower as Min)
      // v4 = _calcPart(baseLowPct, twapResult.currentPriceAccountingDecimals); // 20% of currentPriceAccountingDecimals
      // v2 = v5 = _SafeSub(v4, v1); // lower price bound (-20%)
      // currentPrice - 20% (почему не сделать twapResult.currentPriceAccountingDecimals * 0.8?)
      // console.log('baselowpct: ', thresholds.baseLowPct);
      lowerPriceBound = targetPrice - _calcPart(thresholds.baseLowPct, targetPrice);
    }
    // v6 = _calcPart(baseHighPct, v1); // 10% of currentPriceAccountingDecimals
    // v7 = v8 = _SafeAdd(v6, v1); // upper price bound (+10%)
    // currentPriceAccountingDecimals + 10%
    uint256 upperPriceBound = targetPrice + _calcPart(thresholds.baseHighPct, targetPrice);
    // console.log('targetPrice: ', targetPrice);
    // console.log('upperPriceBound: ', upperPriceBound);

    // console.log('state????: ', uint256(_state));
    if (_state == State.Normal) {
      // console.log('mi tut???');
      // console.log('twapResult.totalDepositToken: ', twapResult.totalDepositToken);
      // console.log('twapResult.totalPairedInDeposit: ', twapResult.totalPairedInDeposit);
      uint256 totalTokens = twapResult.totalDepositToken + twapResult.totalPairedInDeposit;
      uint256 partOfTotalTokens = _calcPart(totalTokens, thresholds.limitReservePct); // 5% of totalTokensInToken0
      // console.log('limitReservePct: ', thresholds.limitReservePct);
      // console.log('partOfTotalTokens: ', partOfTotalTokens);
      // TODO: убрать этот require
      require(twapResult.totalPairedInDeposit > partOfTotalTokens, 'not enough quote token');
      uint256 excess = twapResult.totalPairedInDeposit - partOfTotalTokens;
      uint256 partOfExcess = excess * thresholds.baseLowPct; // 20% of excess
      uint256 excessCoef = partOfExcess / twapResult.totalDepositToken;
      if (excessCoef != 0) {
        targetPrice += _calcPart(excessCoef, targetPrice);
      }
    }
    // ета залупа в каком случае срабатывает? (!allowToken1    -> depositToken = Token0)
    // как связано какой депозит токен и то, убираем ли мы decimals или нет?
    // console.log('targetPrice before remove decimals: ', targetPrice);
    // console.log('lowerPriceBound before remove decimals: ', lowerPriceBound);
    // console.log('upperPriceBound before remove decimals: ', upperPriceBound);
    // console.log('decimalsSum: ', decimalsSum);
    // console.log(_allowToken1);
    if (!_allowToken1) {
      // console.log('??????');
      targetPrice = _removeDecimals(targetPrice, decimalsSum); // targetPrice
      lowerPriceBound = _removeDecimals(lowerPriceBound, decimalsSum); // lowerPriceBound
      upperPriceBound = _removeDecimals(upperPriceBound, decimalsSum); // upperPriceBound
      // console.log('targetPrice after remove decimals: ', targetPrice);
      // console.log('lowerPriceBound after remove decimals: ', lowerPriceBound);
      // console.log('upperPriceBound after remove decimals: ', upperPriceBound);
    }

    return (upperPriceBound, targetPrice, lowerPriceBound);
  }

  function _calcPart(uint256 base, uint256 part) private pure returns (uint256) {
    return (base * part) / 10000;
  }

  function _removeDecimals(uint256 amount, uint8 decimals) private pure returns (uint256) {
    // console.log('amount: ', amount);
    // console.log('decimals: ', decimals);
    return amount != 0 ? (10 ** decimals) / amount : amount;
  }

  function _pause() private {
    paused = true;
  }

  function unpause() public payable /* onlyowner */ {
    paused = false;
  }

  function getTickAtPrice(uint8 _tokenDecimals, uint256 _price) private pure returns (int24) {
    uint160 sqrtPriceX96 = getSqrtPriceX96(_tokenDecimals, _price);
    // console.log("_tokenDecimals: ", _tokenDecimals);
    return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
  }

  function getSqrtPriceX96(uint8 _tokenDecimals, uint256 _price) private pure returns (uint160) {
    // price мы получаем из getRangesWithState, а там мы можем получить
    // если state == normal, то без decimals, а если не normal, то с decimals
    // и типа если price >= 10 ** tokenDecimals, то мы получили цену с decimals (ну и ХУЕТА)
    // console.log(_price >= 10 ** _tokenDecimals);
    return
      _price >= 10 ** _tokenDecimals
        ? getSqrtPriceX96FromPriceWithDecimals(_tokenDecimals, _price)
        : getSqrtPriceX96FromPriceWithoutDecimals(_tokenDecimals, _price);
  }

  function getSqrtPriceX96FromPriceWithDecimals(uint8 _tokenDecimals, uint256 _price) private pure returns (uint160) {
    return uint160((Math.sqrt(_price) << 96) / Math.sqrt(10 ** _tokenDecimals));
  }

  function getSqrtPriceX96FromPriceWithoutDecimals(uint8 _tokenDecimals, uint256 _price) private pure returns (uint160) {
    return uint160(Math.sqrt((_price << 192) / 10 ** _tokenDecimals));
  }
}
