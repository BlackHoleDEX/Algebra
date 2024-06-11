// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import '@cryptoalgebra/integral-core/contracts/base/common/Timestamp.sol';
import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';

import '@cryptoalgebra/algebra-modular-hub-v0.8.20/contracts/interfaces/IAlgebraModularHub.sol';
import '@cryptoalgebra/algebra-modular-hub-v0.8.20/contracts/types/HookParams.sol';

import '../base/AlgebraBaseModule.sol';

import '../interfaces/plugins/IFarmingPlugin.sol';
import '../interfaces/IBasePluginV1Factory.sol';
import '../interfaces/IAlgebraVirtualPool.sol';
import '../interfaces/IAlgebraFarmingModuleFactory.sol';


contract FarmingModule is AlgebraBaseModule, IFarmingPlugin, Timestamp {
    using Plugins for uint8;

    /// @inheritdoc AlgebraModule
    string public constant override MODULE_NAME = 'Farming';

    /// @inheritdoc AlgebraModule
    uint8 public constant override DEFAULT_PLUGIN_CONFIG = uint8(Plugins.AFTER_SWAP_FLAG);

    /// @inheritdoc IFarmingPlugin
    address public override incentive;

    /// @inheritdoc IFarmingPlugin
    address public immutable override pluginFactory;

    /// @dev the address which connected the last incentive. Needed so that he can disconnect it
    address private _lastIncentiveOwner;

    constructor(address _modularHub, address _pluginFactory) AlgebraModule(_modularHub) {
        pluginFactory =  _pluginFactory;
    }

    function setIncentive(address newIncentive) external override {
        bool toConnect = newIncentive != address(0);
        bool accessAllowed;
        if (toConnect) {
            accessAllowed = msg.sender == IAlgebraFarmingModuleFactory(pluginFactory).farmingAddress();
        } else {
            // we allow the one who connected the incentive to disconnect it,
            // even if he no longer has the rights to connect incentives
            if (_lastIncentiveOwner != address(0)) accessAllowed = msg.sender == _lastIncentiveOwner;
            if (!accessAllowed) accessAllowed = msg.sender == IAlgebraFarmingModuleFactory(pluginFactory).farmingAddress();
        }
        require(accessAllowed, 'Not allowed to set incentive');

        bool isPluginConnected = IAlgebraModularHub(modularHub).moduleAddressToIndex(address(this)) != 0;
        if (toConnect) require(isPluginConnected, 'Plugin not attached');

        address currentIncentive = incentive;
        require(currentIncentive != newIncentive, 'Already active');
        if (toConnect) require(currentIncentive == address(0), 'Has active incentive');

        incentive = newIncentive;
        emit Incentive(newIncentive);

        if (toConnect) {
            _lastIncentiveOwner = msg.sender; // write creator of this incentive
        } else {
            _lastIncentiveOwner = address(0);
        }
    }

    /// @inheritdoc IFarmingPlugin
    function isIncentiveConnected(address targetIncentive) external view override returns (bool) {
        if (incentive != targetIncentive) return false;
        if (IAlgebraModularHub(modularHub).moduleAddressToIndex(address(this)) == 0) return false;
        (, , , uint8 pluginConfig) = _getPoolState();
        if (!pluginConfig.hasFlag(Plugins.AFTER_SWAP_FLAG)) return false;

        return true;
    }

    function _afterSwap(
        bytes memory params ,
        uint16 /* poolFeeCache */
    ) internal override {
        AfterSwapParams memory decodedParams = abi.decode(params, (AfterSwapParams));

        address _incentive = incentive;
        if (_incentive != address(0)) {
            (, int24 tick, , ) = _getPoolState();
            IAlgebraVirtualPool(_incentive).crossTo(tick, decodedParams.zeroToOne);
        }
    }
}
