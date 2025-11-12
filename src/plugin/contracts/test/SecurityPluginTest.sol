// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.20;

import '../plugins/SecurityPlugin.sol';
import '../plugins/SecurityRegistry.sol';
import '../base/BasePlugin.sol';

contract SecurityPluginTest is SecurityPlugin {
  constructor(
    address pool,
    address factory,
    address pluginFactory,
    address securityRegistry
  ) AlgebraBasePlugin(pool, factory, pluginFactory) SecurityPlugin(securityRegistry) {
    // AlgebraBasePlugin already runs BasePlugin(pool, pluginFactory),
    // so no extra constructor calls are needed.
  }

  // implement the single compulsory hook
  function defaultPluginConfig() external pure override returns (uint8) {
    return 0;
  }

  function swap() external {
    _checkStatus();
  }

  function mint() external {
    _checkStatus();
  }

  function burn() external {
    _checkStatusOnBurn();
  }
}
