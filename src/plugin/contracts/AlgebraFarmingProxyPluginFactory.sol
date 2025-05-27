// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';

import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol';

import './AlgebraFarmingProxyPlugin.sol';

contract AlgebraFarmingProxyPluginFactory {
  function createAlgebraProxyPlugin(address _pool, address _factory, address _pluginFactory) external returns (address) {
    address algebraProxyPlugin = address(new AlgebraFarmingProxyPlugin(_pool, _factory, _pluginFactory));
    return algebraProxyPlugin;
  }
}
