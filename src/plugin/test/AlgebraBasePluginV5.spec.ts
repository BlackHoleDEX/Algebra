import { Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from './shared/expect';
import { AlgebraBasePluginV5Fixture } from './shared/fixtures';
import { PLUGIN_FLAGS, encodePriceSqrt, expandTo18Decimals, getMaxTick, getMinTick } from './shared/utilities';

import { MockPool, AlgebraBasePluginV5, BasePluginV5Factory, SecurityRegistry, FeeDiscountRegistry, MockFactory } from '../typechain';

import snapshotGasCost from './shared/snapshotGasCost';

describe('AlgebraBasePluginV5', () => {
  let wallet: Wallet, other: Wallet;

  let plugin: AlgebraBasePluginV5; 
  let mockPool: MockPool; // mock of AlgebraPool
  let pluginFactory: BasePluginV5Factory;
  let securityRegistry: SecurityRegistry;
  let feeDiscountRegistry: FeeDiscountRegistry;
  let mockFactory: MockFactory;
  async function initializeAtZeroTick(pool: MockPool) {
    await pool.initialize(encodePriceSqrt(1, 1));
  }

  before('prepare signers', async () => {
    [wallet, other] = await (ethers as any).getSigners();
  });

  beforeEach('deploy test AlgebaraSecurityPlugin', async () => {
    ({ plugin, mockPool, pluginFactory, securityRegistry, feeDiscountRegistry, mockFactory } = await loadFixture(AlgebraBasePluginV5Fixture));
  });

  // plain tests for hooks functionality
  describe('#Hooks', () => {
    it('only pool can call hooks', async () => {
      const errorMessage = 'Only pool can call this';
      await expect(plugin.beforeInitialize(wallet.address, 100)).to.be.revertedWith(errorMessage);
      await expect(plugin.afterInitialize(wallet.address, 100, 100)).to.be.revertedWith(errorMessage);
      await expect(plugin.beforeModifyPosition(wallet.address, wallet.address, 100, 100, 100, '0x')).to.be.revertedWith(errorMessage);
      await expect(plugin.afterModifyPosition(wallet.address, wallet.address, 100, 100, 100, 100, 100, '0x')).to.be.revertedWith(errorMessage);
      await expect(plugin.beforeSwap(wallet.address, wallet.address, true, 100, 100, false, '0x')).to.be.revertedWith(errorMessage);
      await expect(plugin.afterSwap(wallet.address, wallet.address, true, 100, 100, 100, 100, '0x')).to.be.revertedWith(errorMessage);
      await expect(plugin.beforeFlash(wallet.address, wallet.address, 100, 100, '0x')).to.be.revertedWith(errorMessage);
      await expect(plugin.afterFlash(wallet.address, wallet.address, 100, 100, 100, 100, '0x')).to.be.revertedWith(errorMessage);
    });

    describe('not implemented hooks', async () => {
      let defaultConfig: bigint;

      beforeEach('connect plugin to pool', async () => {
        defaultConfig = await plugin.defaultPluginConfig();
        await mockPool.setPlugin(plugin);
      });


      it('resets config after afterModifyPosition', async () => {
        await mockPool.initialize(encodePriceSqrt(1, 1));
        await mockPool.setPluginConfig(PLUGIN_FLAGS.AFTER_POSITION_MODIFY_FLAG);
        expect((await mockPool.globalState()).pluginConfig).to.be.eq(PLUGIN_FLAGS.AFTER_POSITION_MODIFY_FLAG);
        await mockPool.mint(wallet.address, wallet.address, 0, 60, 100, '0x');
        expect((await mockPool.globalState()).pluginConfig).to.be.eq(defaultConfig);
      });

      it('resets config after afterFlash', async () => {
        await mockPool.setPluginConfig(PLUGIN_FLAGS.AFTER_FLASH_FLAG);
        expect((await mockPool.globalState()).pluginConfig).to.be.eq(PLUGIN_FLAGS.AFTER_FLASH_FLAG);
        await mockPool.flash(wallet.address, 100, 100, '0x');
        expect((await mockPool.globalState()).pluginConfig).to.be.eq(defaultConfig);
      });
    });

  });

  describe('#SecurityPlugin', () => {
    let defaultConfig: bigint;

    beforeEach('initialize pool', async () => {
      defaultConfig = await plugin.defaultPluginConfig();
      await mockPool.setPlugin(plugin);
      await mockPool.initialize(encodePriceSqrt(1, 1));
    });

    describe('ENABLE status', async () => {
      it('works correct', async () => {
        await expect(mockPool.swapToTick(10)).to.not.be.reverted;
        await expect(mockPool.mint(wallet.address, wallet.address, 0, 60, 100, '0x')).not.to.be.reverted;
        await expect(mockPool.burn(0, 60, 1000, '0x')).not.to.be.reverted; 
        await expect(mockPool.flash(wallet.address, 100, 100, '0x')).not.to.be.reverted; 
      });
    });

    describe('BURN_ONLY status', async () => {
      it('works correct', async () => {
        await securityRegistry.setGlobalStatus(1)
        await expect(mockPool.swapToTick(10)).to.be.revertedWithCustomError(plugin,'BurnOnly'); 
        await expect(mockPool.mint(wallet.address, wallet.address, 0, 60, 100, '0x')).to.be.revertedWithCustomError(plugin,'BurnOnly'); 
        await expect(mockPool.burn(0, 60, 1000, '0x')).to.not.be.reverted;
        await expect(mockPool.flash(wallet.address, 100, 100, '0x')).to.be.revertedWithCustomError(plugin,'BurnOnly'); 
        expect((await mockPool.globalState()).pluginConfig).to.be.eq(defaultConfig);
      });
    });

    describe('DISABLED status', async () => {
      it('works correct', async () => {
        await securityRegistry.setGlobalStatus(2)
        await expect(mockPool.swapToTick(10)).to.be.revertedWithCustomError(plugin,'PoolDisabled');
        await expect(mockPool.mint(wallet.address, wallet.address, 0, 60, 100, '0x')).to.be.revertedWithCustomError(plugin,'PoolDisabled');
        await expect(mockPool.burn(0, 60, 1000, '0x')).to.be.revertedWithCustomError(plugin,'PoolDisabled');
        await expect(mockPool.flash(wallet.address, 100, 100, '0x')).to.be.revertedWithCustomError(plugin,'PoolDisabled');
        expect((await mockPool.globalState()).pluginConfig).to.be.eq(defaultConfig);

      });
    });
  })

  describe('AlgebaraSecurityPlugin external methods', () => {
     
    it('set registry contract works correct', async () => {
      await plugin.setSecurityRegistry(ZeroAddress);
      await expect(plugin.setSecurityRegistry(securityRegistry)).to.emit(plugin, 'SecurityRegistry');
      expect(await plugin.getSecurityRegistry()).to.be.eq(securityRegistry);
    });

    it('only owner can set registry address', async () => {
      await expect(plugin.connect(other).setSecurityRegistry(ZeroAddress)).to.be.reverted;
    });

  });

  describe('#SecurtityRegistry', () => {

    describe('#setPoolStatus', async () => {
      it('works correct', async () => {
        await securityRegistry.setPoolsStatus([mockPool], [1]);
        expect(await securityRegistry.poolStatus(mockPool)).to.be.eq(1);
        await securityRegistry.setPoolsStatus([mockPool], [2]);
        expect(await securityRegistry.poolStatus(mockPool)).to.be.eq(2);
        await securityRegistry.setPoolsStatus([mockPool], [0]);
        expect(await securityRegistry.poolStatus(mockPool)).to.be.eq(0);
      });

      it('add few pools updates isPoolStatusOverrided var', async () => {
        await securityRegistry.setPoolsStatus([mockPool, wallet], [1, 1]);
        expect(await securityRegistry.isPoolStatusOverrided()).to.be.eq(true);
        await securityRegistry.setPoolsStatus([mockPool, wallet], [1, 1]);
        await securityRegistry.setPoolsStatus([mockPool, wallet], [0, 0]);
        expect(await securityRegistry.isPoolStatusOverrided()).to.be.eq(false);
        await securityRegistry.setPoolsStatus([mockPool, wallet], [1, 1]);
        await securityRegistry.setPoolsStatus([mockPool, wallet], [0, 1]);
        expect(await securityRegistry.isPoolStatusOverrided()).to.be.eq(true);

      });

      it('only owner can set all pool status', async () => {
        await expect(securityRegistry.connect(other).setPoolsStatus([mockPool], [1])).to.be.reverted
        await mockFactory.grantRole(await securityRegistry.GUARD(), other.address);
        await expect(securityRegistry.connect(other).setPoolsStatus([mockPool], [0])).to.be.reverted
        await expect(securityRegistry.connect(other).setPoolsStatus([mockPool], [1])).to.be.reverted
      });

      it('address with guard role can set DISABLED pool status', async () => {
        await mockFactory.grantRole(await securityRegistry.GUARD(), other.address);
        await expect(securityRegistry.connect(other).setPoolsStatus([mockPool], [2])).to.emit(securityRegistry, 'PoolStatus');
        expect(await securityRegistry.poolStatus(mockPool)).to.be.eq(2);
      });
    });


    describe('#setGlobalStatus', async () => {
        it('works correct', async () => {
          await securityRegistry.setGlobalStatus(1);
          expect(await securityRegistry.globalStatus()).to.be.eq(1);
          await securityRegistry.setGlobalStatus(2);
          expect(await securityRegistry.globalStatus()).to.be.eq(2);
          await securityRegistry.setGlobalStatus(0);
          expect(await securityRegistry.globalStatus()).to.be.eq(0);
        });

        it('only owner can set all pool status', async () => {
          await expect(securityRegistry.connect(other).setGlobalStatus(1)).to.be.reverted
          await mockFactory.grantRole(await securityRegistry.GUARD(), other.address);
          await expect(securityRegistry.connect(other).setGlobalStatus(1)).to.be.reverted
          await expect(securityRegistry.connect(other).setGlobalStatus(0)).to.be.reverted
        });

        it('address with guard role can set DISABLED pool status', async () => {
          await mockFactory.grantRole(await securityRegistry.GUARD(), other.address);
          await expect(securityRegistry.connect(other).setGlobalStatus(2)).to.emit(securityRegistry, 'GlobalStatus');
          expect(await securityRegistry.globalStatus()).to.be.eq(2);
        });
    });

    describe('#getPoolStatus', async () => {
      it('pool status overrides global status, if global status is ENABLED ', async () => {
        await securityRegistry.setGlobalStatus(0);
        await securityRegistry.setPoolsStatus([mockPool], [1]);
        expect(await securityRegistry.getPoolStatus(mockPool)).to.be.eq(1);

        await securityRegistry.setGlobalStatus(0);
        await securityRegistry.setPoolsStatus([mockPool], [2]);
        expect(await securityRegistry.getPoolStatus(mockPool)).to.be.eq(2);
      });

      it('global status overrides pool status, if global status is BURN_ONLY or DISABLED ', async () => {
        await securityRegistry.setGlobalStatus(2);
        await securityRegistry.setPoolsStatus([mockPool], [1]);
        expect(await securityRegistry.getPoolStatus(mockPool)).to.be.eq(2);

        await securityRegistry.setGlobalStatus(1);
        await securityRegistry.setPoolsStatus([mockPool], [2]);
        expect(await securityRegistry.getPoolStatus(mockPool)).to.be.eq(1);
      });

  });
  });

  describe('#FeeDiscountPlugin', () => {
    let defaultConfig: bigint;
    let defaultFee: bigint;

    beforeEach('initialize pool', async () => {
      defaultConfig = await plugin.defaultPluginConfig();
      await mockPool.setPlugin(plugin);
      await mockPool.initialize(encodePriceSqrt(1, 1));
      defaultFee = 100n;
    });

    describe('default fee discount 0% ', async () => {
      it('works correct', async () => {
        await mockPool.swapToTick(10); 
        let overrideFee = await mockPool.overrideFee()
 
        expect(overrideFee).to.be.eq(defaultFee);
      });
    });

    describe('fee discount 30%', async () => {
      it('works correct', async () => {
        await feeDiscountRegistry.setFeeDiscount(wallet.address, [await mockPool.getAddress()], [300])
        await mockPool.swapToTick(10); 
        let overrideFee = await mockPool.overrideFee()
 
        expect(overrideFee).to.be.eq(defaultFee * 7n / 10n);
      });
    });

    describe('fee discount 50%', async () => {
      it('works correct', async () => {
        await feeDiscountRegistry.setFeeDiscount(wallet.address, [await mockPool.getAddress()], [500])
        await mockPool.swapToTick(10); 
        let overrideFee = await mockPool.overrideFee()
 
        expect(overrideFee).to.be.eq(defaultFee * 1n / 2n);
      });
    });

    describe('fee discount 100%', async () => {
      it('works correct', async () => {
        await feeDiscountRegistry.setFeeDiscount(wallet.address, [await mockPool.getAddress()], [1000])
        await mockPool.swapToTick(10); 
        let overrideFee = await mockPool.overrideFee()
 
        expect(overrideFee).to.be.eq(defaultFee * 0n);
      });
    });
  })

  describe('AlgebarFeeDiscountPlugin external methods', () => {
     
    it('set registry contract works correct', async () => {
      await plugin.setFeeDiscountRegistry(ZeroAddress);
      await expect(plugin.setFeeDiscountRegistry(feeDiscountRegistry)).to.emit(plugin, 'FeeDiscountRegistry');
      expect(await plugin.feeDiscountRegistry()).to.be.eq(feeDiscountRegistry);
    });

    it('only owner can set registry address', async () => {
      await expect(plugin.connect(other).setFeeDiscountRegistry(ZeroAddress)).to.be.reverted;
    });

  });

  describe('#FeeDiscountRegistry', () => {

    describe('#setFeeDiscount', async () => {
      it('works correct', async () => {
        await feeDiscountRegistry.setFeeDiscount(wallet.address, [await mockPool.getAddress()], [500])
        await feeDiscountRegistry.setFeeDiscount(other.address, [await mockPool.getAddress()], [400])
        expect(await feeDiscountRegistry.feeDiscounts(wallet.address, await mockPool.getAddress())).to.be.eq(500);
        expect(await feeDiscountRegistry.feeDiscounts(other.address, await mockPool.getAddress())).to.be.eq(400);        
      });

      it('only owner or with fee discount manager can set discounts', async () => {
        await expect(feeDiscountRegistry.connect(other).setFeeDiscount(wallet.address, [await mockPool.getAddress()], [500])).to.be.reverted
        await mockFactory.grantRole(await feeDiscountRegistry.FEE_DISCOUNT_MANAGER(), other.address);
        await expect(feeDiscountRegistry.connect(other).setFeeDiscount(wallet.address, [await mockPool.getAddress()], [500])).to.not.be.reverted
        await expect(feeDiscountRegistry.connect(wallet).setFeeDiscount(wallet.address, [await mockPool.getAddress()], [500])).to.not.be.reverted
      });

    });

  });
});
