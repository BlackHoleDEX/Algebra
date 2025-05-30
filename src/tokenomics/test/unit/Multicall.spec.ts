import { LoadFixtureFunction } from '../types'
import { algebraFixture, mintPosition, AlgebraFixtureType } from '../shared/fixtures'
import {
  getMaxTick,
  getMinTick,
  FeeAmount,
  TICK_SPACINGS,
  blockTimestamp,
  BN,
  BNe18,
  snapshotGasCost,
  ActorFixture,
  makeTimestamps,
  maxGas,
  defaultTicksArray,
  expect,
} from '../shared'
import { createFixtureLoader, provider } from '../shared/provider'
import { HelperCommands, ERC20Helper, incentiveResultToFarmAdapter } from '../helpers'
import { createTimeMachine } from '../shared/time'
import { HelperTypes } from '../helpers/types'

let loadFixture: LoadFixtureFunction

describe('unit/Multicall', () => {
  const actors = new ActorFixture(provider.getWallets(), provider)
  const incentiveCreator = actors.incentiveCreator()
  const lpUser0 = actors.lpUser0()
  const amountDesired = BNe18(10)
  const totalReward = BNe18(100)
  const bonusReward = BNe18(100)
  const erc20Helper = new ERC20Helper()
  const Time = createTimeMachine(provider)
  let helpers: HelperCommands
  let context: AlgebraFixtureType
  const multicaller = actors.traderUser2()

  before('loader', async () => {
    loadFixture = createFixtureLoader(provider.getWallets(), provider)
  })

  beforeEach('create fixture loader', async () => {
    context = await loadFixture(algebraFixture)
    helpers = HelperCommands.fromTestContext(context, actors, provider)
  })

  it('is implemented', async () => {
    const currentTime = await blockTimestamp()

    await erc20Helper.ensureBalancesAndApprovals(
      multicaller,
      [context.token0, context.token1],
      amountDesired,
      context.nft.address
    )

    await mintPosition(context.nft.connect(multicaller), {
      token0: context.token0.address,
      token1: context.token1.address,
      fee: FeeAmount.MEDIUM,
      tickLower: getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
      tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
      recipient: multicaller.address,
      amount0Desired: amountDesired,
      amount1Desired: amountDesired,
      amount0Min: 0,
      amount1Min: 0,
      deadline: currentTime + 10_000,
    })

    await erc20Helper.ensureBalancesAndApprovals(multicaller, context.rewardToken, totalReward, context.farming.address)
    await erc20Helper.ensureBalancesAndApprovals(multicaller, context.bonusRewardToken, totalReward, context.farming.address)

    const createIncentiveTx = context.farming.interface.encodeFunctionData('createIncentive', [
      {
        pool: context.pool01,
        rewardToken: context.rewardToken.address,
        bonusRewardToken: context.bonusRewardToken.address,
        
        ...makeTimestamps(currentTime + 100),
      },
      {
        tokenAmountForLevel1: 0,
        tokenAmountForLevel2: 0,
        tokenAmountForLevel3: 0,
        level1multiplier: 0,
        level2multiplier: 0,
        level3multiplier: 0,
      },
      {
        reward: totalReward,
        bonusReward: bonusReward,
        multiplierToken: context.rewardToken.address,
        enterStartTime: 0,
      }
    ])
    await context.farming.setIncentiveMaker(multicaller.address)
    await context.farming.connect(multicaller).multicall([createIncentiveTx], maxGas)

     // expect((await context.tokenomics.deposits(tokenId)).owner).to.eq(
     //   multicaller.address
     // )
  })

  // it('can be used to exit multiple tokens from one incentive', async () => {
  //   const timestamp = await blockTimestamp()
  //
  //   const incentive = await helpers.createIncentiveFlow({
  //     rewardToken: context.rewardToken,
  //     poolAddress: context.poolObj.address,
  //     totalReward,
  //     ...makeTimestamps(timestamp + 100),
  //   })
  //
  //   const params: HelperTypes.MintDepositFarm.Args = {
  //     lp: multicaller,
  //     tokensToFarm: [context.token0, context.token1],
  //     amountsToFarm: [amountDesired, amountDesired],
  //     ticks: defaultTicksArray(),
  //     createIncentiveResult: incentive,
  //   }
  //
  //   await Time.setAndMine(incentive.startTime + 1)
  //
  //   const { tokenId: tokenId0 } = await helpers.mintDepositFarmFlow(params)
  //   const { tokenId: tokenId1 } = await helpers.mintDepositFarmFlow(params)
  //   const { tokenId: tokenId2 } = await helpers.mintDepositFarmFlow(params)
  //
  //   const exitFarming = (tokenId) =>
  //     context.tokenomics.interface.encodeFunctionData('exitFarming', [incentiveResultToFarmAdapter(incentive), tokenId])
  //
  //   await context.tokenomics.connect(multicaller).multicall([exitFarming(tokenId0), exitFarming(tokenId1), exitFarming(tokenId2)])
  //
  //   const { numberOfFarms: n0 } = await context.tokenomics.deposits(tokenId0)
  //   expect(n0).to.eq(BN('0'))
  //   const { numberOfFarms: n1 } = await context.tokenomics.deposits(tokenId1)
  //   expect(n1).to.eq(BN('0'))
  //   const { numberOfFarms: n2 } = await context.tokenomics.deposits(tokenId2)
  //   expect(n2).to.eq(BN('0'))
  // })
})
