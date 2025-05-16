// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';

import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol';

import './plugins/FarmingProxyPlugin.sol';

contract AlgebraFarmingProxyPlugin is FarmingProxyPlugin {
  uint8 public constant defaultPluginConfig = uint8(Plugins.AFTER_SWAP_FLAG);

  constructor(address _pool, address _factory, address _pluginFactory) AlgebraBasePlugin(_pool, _factory, _pluginFactory) {}

  function afterSwap(address, address, bool zeroToOne, int256, uint160, int256, int256, bytes calldata) external override onlyPool returns (bytes4) {
    _updateVirtualPoolTick(zeroToOne);
    return IAlgebraPlugin.afterSwap.selector;
  }
}
