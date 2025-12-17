// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import './AlgebraBasePluginV3.sol';
import './interfaces/IBasePluginV3Deployer.sol';
import './interfaces/plugins/ISecurityPlugin.sol';

contract BasePluginV3Deployer is IBasePluginV3Deployer {
  function deployPlugin(
    address pool,
    address algebraFactory,
    address pluginFactory,
    AlgebraFeeConfiguration calldata defaultFeeConfiguration,
    address reflexRouter,
    bytes32 reflexConfigId,
    address feeDiscountRegistry
  ) external override returns (address) {
    return
      address(
        new AlgebraBasePluginV3(pool, algebraFactory, pluginFactory, defaultFeeConfiguration, reflexRouter, reflexConfigId, feeDiscountRegistry)
      );
  }
}
