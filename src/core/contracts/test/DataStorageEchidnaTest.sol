// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import './DataStorageTest.sol';

contract DataStorageEchidnaTest {
    DataStorageTest private dataStorage;

    bool private initialized;
    uint32 private timePassed;

    constructor() {
        dataStorage = new DataStorageTest();
    }

    function initialize(
        uint32 time,
        int24 tick,
        uint128 liquidity
    ) external {
        dataStorage.initialize(DataStorageTest.InitializeParams({time: time, tick: tick, liquidity: liquidity}));
        initialized = true;
    }

    function limitTimePassed(uint32 by) private {
        require(timePassed + by >= timePassed);
        timePassed += by;
    }

    function advanceTime(uint32 by) public {
        limitTimePassed(by);
        dataStorage.advanceTime(by);
    }

    // write an timepoint, then change tick and liquidity
    function update(
        uint32 advanceTimeBy,
        int24 tick,
        uint128 liquidity
    ) external {
        limitTimePassed(advanceTimeBy);
        dataStorage.update(
            DataStorageTest.UpdateParams({advanceTimeBy: advanceTimeBy, tick: tick, liquidity: liquidity})
        );
    }

    function checkTimeWeightedResultAssertions(uint32 secondsAgo0, uint32 secondsAgo1) private view {
        require(secondsAgo0 != secondsAgo1);
        require(initialized);
        // secondsAgo0 should be the larger one
        if (secondsAgo0 < secondsAgo1) (secondsAgo0, secondsAgo1) = (secondsAgo1, secondsAgo0);

        uint32 timeElapsed = secondsAgo0 - secondsAgo1;

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo0;
        secondsAgos[1] = secondsAgo1;

        (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulatives, //TODO: volumePerLiq ????
            ,

        ) = dataStorage.getTimepoints(secondsAgos);
        int56 timeWeightedTick = (tickCumulatives[1] - tickCumulatives[0]) / timeElapsed;
        uint256 timeWeightedHarmonicMeanLiquidity = (uint256(timeElapsed) * type(uint160).max) /
            (uint256(secondsPerLiquidityCumulatives[1] - secondsPerLiquidityCumulatives[0]) << 32);
        assert(timeWeightedHarmonicMeanLiquidity <= type(uint128).max);
        assert(timeWeightedTick <= type(int24).max);
        assert(timeWeightedTick >= type(int24).min);
    }

    function echidna_indexAlwaysLtCardinality() external view returns (bool) {
        return dataStorage.index() < 65535 || !initialized;
    }

    function echidna_canAlwaysGetPoints0IfInitialized() external view returns (bool) {
        if (!initialized) {
            return true;
        }
        uint32[] memory arr = new uint32[](1);
        arr[0] = 0;
        (bool success, ) = address(dataStorage).staticcall(
            abi.encodeWithSelector(DataStorageTest.getTimepoints.selector, arr)
        );
        return success;
    }

    function checkTwoAdjacentTimepointsTickCumulativeModTimeElapsedAlways0(uint16 index) external view {
        // check that the timepoints are initialized, and that the index is not the oldest timepoint
        require(index < 65535 && index != (dataStorage.index() + 1) % 65535);

        (bool initialized0, uint32 blockTimestamp0, int56 tickCumulative0, , , , ) = dataStorage.timepoints(
            index == 0 ? 65535 - 1 : index - 1
        );
        (bool initialized1, uint32 blockTimestamp1, int56 tickCumulative1, , , , ) = dataStorage.timepoints(index);

        require(initialized0);
        require(initialized1);

        uint32 timeElapsed = blockTimestamp1 - blockTimestamp0;
        assert(timeElapsed > 0);
        assert((tickCumulative1 - tickCumulative0) % timeElapsed == 0);
    }

    function checkTimeWeightedAveragesAlwaysFitsType(uint32 secondsAgo) external view {
        require(initialized);
        require(secondsAgo > 0);
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;
        (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulatives, //TODO: volumePerLiq
            ,

        ) = dataStorage.getTimepoints(secondsAgos);

        // compute the time weighted tick, rounded towards negative infinity
        int56 numerator = tickCumulatives[1] - tickCumulatives[0];
        int56 timeWeightedTick = numerator / int56(secondsAgo);
        if (numerator < 0 && numerator % int56(secondsAgo) != 0) {
            timeWeightedTick--;
        }

        // the time weighted averages fit in their respective accumulated types
        assert(timeWeightedTick <= type(int24).max && timeWeightedTick >= type(int24).min);

        uint256 timeWeightedHarmonicMeanLiquidity = (uint256(secondsAgo) * type(uint160).max) /
            (uint256(secondsPerLiquidityCumulatives[1] - secondsPerLiquidityCumulatives[0]) << 32);
        assert(timeWeightedHarmonicMeanLiquidity <= type(uint128).max);
    }
}
