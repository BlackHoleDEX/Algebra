// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol';

contract MockPlugin is IAlgebraPlugin {

    uint24 public swapCalldata;
    uint128 public mintCallData;

    struct SwapCallbackData {
        bytes pluginData;
        bytes path;
        address payer;
    }

    function defaultPluginConfig() external pure returns (uint8) {
        return 0;
    }

    function beforeInitialize(address, uint160) external pure returns (bytes4) {
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    function afterInitialize(address, uint160, int24) external pure returns (bytes4) {
        return IAlgebraPlugin.afterInitialize.selector;
    }

    function beforeModifyPosition(
        address,
        address,
        int24,
        int24,
        int128 liquidity,
        bytes calldata data
    ) external returns (bytes4, uint24) {
        if(data.length != 0 && liquidity > 0) mintCallData = abi.decode(data, (uint24));
        return (IAlgebraPlugin.beforeModifyPosition.selector, 0);
    }

    function handlePluginFee(uint256, uint256) external pure returns (bytes4) {
        return IAlgebraPlugin.handlePluginFee.selector;
    }
    
    function afterModifyPosition(
        address,
        address,
        int24,
        int24,
        int128,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IAlgebraPlugin.afterModifyPosition.selector;
    }

    function beforeSwap(address, address, bool, int256, uint160, bool, bytes calldata data) external returns (bytes4, uint24, uint24) {
        SwapCallbackData memory swapData = abi.decode(data, (SwapCallbackData));
        swapCalldata = swapData.pluginData.length > 0 ? abi.decode(swapData.pluginData, (uint24)) : 0;
        return (IAlgebraPlugin.beforeSwap.selector, 0, 0);
    }

    function afterSwap(
        address,
        address,
        bool,
        int256,
        uint160,
        int256,
        int256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IAlgebraPlugin.afterSwap.selector;
    }

    function beforeFlash(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IAlgebraPlugin.beforeFlash.selector;
    }

    function afterFlash(
        address,
        address,
        uint256,
        uint256,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IAlgebraPlugin.afterFlash.selector;
    }
}
