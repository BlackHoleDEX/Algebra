// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol';

import '@cryptoalgebra/integral-periphery/contracts/interfaces/ISwapRouter.sol';

import '../interfaces/IBasePluginV1Factory.sol';
import '../interfaces/IAlgebraVirtualPool.sol';
import '../interfaces/plugins/IFarmingPlugin.sol';

import '../base/AlgebraBasePlugin.sol';


/// @title Algebra Integral 1.2.1 managed swap fee plugin
/// @notice This plugin get fees value from the swap router and apply that fees to swap
abstract contract FarmingProxyPlugin is AlgebraBasePlugin, IFarmingPlugin {
  using Plugins for uint8;

  uint8 private constant defaultPluginConfig = uint8(Plugins.BEFORE_SWAP_FLAG);

  uint96 public nonce;
  address public router; // TODO rename?
  mapping(address => bool) public whitelistedAddresses;

  struct PluginData {
    uint24 fee;
    uint96 nonce;
    bytes signature;
  }

  function isWhitelisted(address _address) public view returns (bool) {
    return whitelistedAddresses[_address];
  }

  function setStakerAddress(address _router) external  {
    _authorize();
    router = _router;
  }

  function getFee(bytes calldata pluginData) internal returns (uint24 fee){
    bytes memory signature;
    (fee, nonce, signature) = _parsePluginData(pluginData);
     
  }

  function _parsePluginData(bytes calldata pluginData) internal returns(uint24, uint96, bytes memory) {
    PluginData memory data = abi.decode(pluginData, (PluginData));
    return (data.fee, data.nonce, data.signature);
  }

}
