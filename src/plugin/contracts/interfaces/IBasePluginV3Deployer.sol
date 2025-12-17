// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '../base/AlgebraFeeConfiguration.sol';

interface IBasePluginV3Deployer {
  function deployPlugin(
    address pool,
    address algebraFactory,
    address pluginFactory,
    AlgebraFeeConfiguration calldata defaultFeeConfiguration,
    address reflexRouter,
    bytes32 reflexConfigId,
    address feeDiscountRegistry
  ) external returns (address);
}
