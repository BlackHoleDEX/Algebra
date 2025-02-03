// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';

import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol';

import '../interfaces/plugins/IFeeDiscountPlugin.sol';
import '../interfaces/plugins/IFeeDiscountRegistry.sol';

import '../base/BasePlugin.sol';

/// @title Algebra Integral 1.2 fee discount plugin
abstract contract FeeDiscountPlugin is BasePlugin, IFeeDiscountPlugin {
  using Plugins for uint8;

  uint8 private constant defaultPluginConfig = uint8(Plugins.BEFORE_SWAP_FLAG);
  uint16 private constant FEE_DISCOUNT_DENOMINATOR = 1000;

  address public override feeDiscountRegistry;

  function _applyFeeDiscount(address pool, address user, uint24 fee) internal returns (uint24 updatedFee) {
    uint24 feeDiscount = IFeeDiscountRegistry(feeDiscountRegistry).feeDiscounts(pool, user);
    updatedFee = uint24((uint256(fee) * (FEE_DISCOUNT_DENOMINATOR - feeDiscount)) / FEE_DISCOUNT_DENOMINATOR);
  }

  function setFeeDiscountRegistry(address _feeDiscountRegistry) external override {
    require(msg.sender == pluginFactory || IAlgebraFactory(factory).hasRoleOrOwner(ALGEBRA_BASE_PLUGIN_MANAGER, msg.sender));
    feeDiscountRegistry = _feeDiscountRegistry;
    emit FeeDiscountRegistry(_feeDiscountRegistry);
  }
}
