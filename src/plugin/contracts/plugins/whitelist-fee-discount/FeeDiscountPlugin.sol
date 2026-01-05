// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';

import '../../base/AlgebraBasePlugin.sol';

import '../../interfaces/plugins/whitelist-fee-discount/IFeeDiscountPlugin.sol';
import '../../interfaces/plugins/whitelist-fee-discount/IFeeDiscountRegistry.sol';

/// @title Algebra Integral 1.2 fee discount plugin
abstract contract FeeDiscountPlugin is AlgebraBasePlugin, IFeeDiscountPlugin {
  uint16 private constant FEE_DISCOUNT_DENOMINATOR = 1000;

  address public override feeDiscountRegistry;

  uint8 private constant defaultPluginConfig = uint8(Plugins.BEFORE_SWAP_FLAG);

  constructor(address _feeDiscountRegistry) {
    feeDiscountRegistry = _feeDiscountRegistry;
  }

  function _applyFeeDiscount(address user, address pool, uint24 fee) internal returns (uint24 updatedFee) {
    uint16 feeDiscount = IFeeDiscountRegistry(feeDiscountRegistry).feeDiscounts(user, pool);
    updatedFee = uint24((uint256(fee) * (FEE_DISCOUNT_DENOMINATOR - feeDiscount)) / FEE_DISCOUNT_DENOMINATOR);
  }

  function setFeeDiscountRegistry(address _feeDiscountRegistry) external override {
    _authorize();
    feeDiscountRegistry = _feeDiscountRegistry;
    emit FeeDiscountRegistry(_feeDiscountRegistry);
  }
}
