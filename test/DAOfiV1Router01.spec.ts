import chai, { expect } from 'chai'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { BigNumber, bigNumberify } from 'ethers/utils'
import { MaxUint256 } from 'ethers/constants'
import IDAOfiV1Pair from '@daofi/daofi-v1-core/build/IDAOfiV1Pair.json'

import { getFixtureWithParams } from './shared/fixtures'
import { expandTo18Decimals } from './shared/utilities'

import { ecsign } from 'ethereumjs-util'

chai.use(solidity)

const overrides = {
  gasLimit: 9999999
}
const zero = bigNumberify(0)

let tokenBase: Contract
let tokenQuote: Contract
let xDAI: Contract
let xDAIPartner: Contract
let factory: Contract
let router: Contract
let pair: Contract
let xDAIPair: Contract

describe('DAOfiV1Router01: m = 1, n = 1, fee = 3', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [wallet] = provider.getWallets()

  async function addLiquidityForPrice(
    price: number,
    tokenBase: Contract,
    tokenQuote: Contract,
    baseReserve: BigNumber,
    pair: Contract
  ) {
    // solve for s as a float, then convert to bignum
    const slopeN = await pair.m()
    const n = await pair.n()
    const s = (price * (1e6 / slopeN)) ** (1 / n)
    const quoteReserveFloat = Math.floor((slopeN * (s ** (n + 1))) / (1e6 * (n + 1)))
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    const baseAmountOut = await pair.getBaseOut(quoteReserve)
    await tokenBase.transfer(pair.address, baseReserve)
    await tokenQuote.transfer(pair.address, quoteReserve)
    await pair.deposit(wallet.address, overrides)
    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(baseReserve.sub(baseAmountOut))
    expect(reserves[1]).to.eq(quoteReserve)
  }

  beforeEach(async function() {
    const fixture = await getFixtureWithParams(provider, [wallet], 1e6, 1, 3)
    tokenBase = fixture.tokenBase
    tokenQuote = fixture.tokenQuote
    xDAI = fixture.xDAI
    xDAIPartner = fixture.xDAIPartner
    factory = fixture.factory
    router = fixture.router
    pair = fixture.pair
    xDAIPair = fixture.xDAIPair
  })

  it('priceBase', async () => {
    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = bigNumberify('9810134194000000000')
    expect(await router.priceBase(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3))
      .to.eq(baseAmountOut)
  })

  it('priceQuote', async () => {
    //We get 50 quote in liquidity from price 10 quote
    await addLiquidityForPrice(10, tokenBase, tokenQuote, expandTo18Decimals(1e6), pair)
    // the amount of base issued
    const baseAmountIn = bigNumberify('9810134194000000000')
    const quoteAmountOut = expandTo18Decimals(50)
    expect(await router.priceQuote(baseAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3))
      .to.eq(quoteAmountOut)
  })

  // it('getAmountIn: fee == 10', async () => {
  //   expect(await router.getAmountIn(bigNumberify(1), bigNumberify(100), bigNumberify(100), token0.address, token1.address)).to.eq(bigNumberify(2))
  //   await expect(router.getAmountIn(bigNumberify(0), bigNumberify(100), bigNumberify(100), token0.address, token1.address)).to.be.revertedWith(
  //     'DAOfiV1Library: INSUFFICIENT_OUTPUT_AMOUNT'
  //   )
  //   await expect(router.getAmountIn(bigNumberify(1), bigNumberify(0), bigNumberify(100), token0.address, token1.address)).to.be.revertedWith(
  //     'DAOfiV1Library: INSUFFICIENT_LIQUIDITY'
  //   )
  //   await expect(router.getAmountIn(bigNumberify(1), bigNumberify(100), bigNumberify(0), token0.address, token1.address)).to.be.revertedWith(
  //     'DAOfiV1Library: INSUFFICIENT_LIQUIDITY'
  //   )
  // })

  // it('getAmountsOut', async () => {
  //   await token0.approve(router.address, MaxUint256)
  //   await token1.approve(router.address, MaxUint256)
  //   await router.addLiquidity(
  //     token0.address,
  //     token1.address,
  //     bigNumberify(10000),
  //     bigNumberify(10000),
  //     0,
  //     0,
  //     wallet.address,
  //     MaxUint256,
  //     overrides
  //   )

  //   await expect(router.getAmountsOut(bigNumberify(2), [token0.address])).to.be.revertedWith(
  //     'DAOfiV1Library: INVALID_PATH'
  //   )
  //   const path = [token0.address, token1.address]
  //   expect(await router.getAmountsOut(bigNumberify(2), path)).to.deep.eq([bigNumberify(2), bigNumberify(1)])
  // })

  // it('getAmountsIn', async () => {
  //   await token0.approve(router.address, MaxUint256)
  //   await token1.approve(router.address, MaxUint256)
  //   await router.addLiquidity(
  //     token0.address,
  //     token1.address,
  //     bigNumberify(10000),
  //     bigNumberify(10000),
  //     0,
  //     0,
  //     wallet.address,
  //     MaxUint256,
  //     overrides
  //   )

  //   await expect(router.getAmountsIn(bigNumberify(1), [token0.address])).to.be.revertedWith(
  //     'DAOfiV1Library: INVALID_PATH'
  //   )
  //   const path = [token0.address, token1.address]
  //   expect(await router.getAmountsIn(bigNumberify(1), path)).to.deep.eq([bigNumberify(2), bigNumberify(1)])
  // })
})

// describe('fee-on-transfer tokens', () => {
//   const provider = new MockProvider({
//     hardfork: 'istanbul',
//     mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
//     gasLimit: 9999999
//   })
//   const [wallet] = provider.getWallets()
//   const loadFixture = createFixtureLoader(provider, [wallet])

//   let DTT: Contract
//   let xDAI: Contract
//   let router: Contract
//   let pair: Contract
//   beforeEach(async function() {
//     const fixture = await loadFixture(v2Fixture)

//     xDAI = fixture.xDAI
//     router = fixture.router02

//     DTT = await deployContract(wallet, DeflatingERC20, [expandTo18Decimals(10000)])

//     // make a DTT<>xDAI pair
//     await fixture.factoryV2.createPair(DTT.address, xDAI.address, xDAI.address, wallet.address, expandTo18Decimals(1), 1, 3)
//     const pairAddress = await fixture.factoryV2.getPair(DTT.address, xDAI.address)
//     pair = new Contract(pairAddress, JSON.stringify(IUniswapV2Pair.abi), provider).connect(wallet)
//   })

//   afterEach(async function() {
//     expect(await provider.getBalance(router.address)).to.eq(0)
//   })

//   async function addLiquidity(DTTAmount: BigNumber, xDAIAmount: BigNumber) {
//     await DTT.approve(router.address, MaxUint256)
//     await router.addLiquidityxDAI(DTT.address, DTTAmount, DTTAmount, xDAIAmount, wallet.address, MaxUint256, {
//       ...overrides,
//       value: xDAIAmount
//     })
//   }

//   it('removeLiquidityxDAISupportingFeeOnTransferTokens', async () => {
//     const DTTAmount = expandTo18Decimals(1)
//     const xDAIAmount = expandTo18Decimals(4)
//     await addLiquidity(DTTAmount, xDAIAmount)

//     const DTTInPair = await DTT.balanceOf(pair.address)
//     const xDAIInPair = await xDAI.balanceOf(pair.address)
//     const liquidity = await pair.balanceOf(wallet.address)
//     const totalSupply = await pair.totalSupply()
//     const NaiveDTTExpected = DTTInPair.mul(liquidity).div(totalSupply)
//     const xDAIExpected = xDAIInPair.mul(liquidity).div(totalSupply)

//     await pair.approve(router.address, MaxUint256)
//     await router.removeLiquidityxDAISupportingFeeOnTransferTokens(
//       DTT.address,
//       liquidity,
//       NaiveDTTExpected,
//       xDAIExpected,
//       wallet.address,
//       MaxUint256,
//       overrides
//     )
//   })

//   it('removeLiquidityxDAIWithPermitSupportingFeeOnTransferTokens', async () => {
//     const DTTAmount = expandTo18Decimals(1)
//       .mul(100)
//       .div(99)
//     const xDAIAmount = expandTo18Decimals(4)
//     await addLiquidity(DTTAmount, xDAIAmount)

//     const expectedLiquidity = expandTo18Decimals(2)

//     const nonce = await pair.nonces(wallet.address)
//     const digest = await getApprovalDigest(
//       pair,
//       { owner: wallet.address, spender: router.address, value: expectedLiquidity.sub(MINIMUM_LIQUIDITY) },
//       nonce,
//       MaxUint256
//     )
//     const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(wallet.privateKey.slice(2), 'hex'))

//     const DTTInPair = await DTT.balanceOf(pair.address)
//     const xDAIInPair = await xDAI.balanceOf(pair.address)
//     const liquidity = await pair.balanceOf(wallet.address)
//     const totalSupply = await pair.totalSupply()
//     const NaiveDTTExpected = DTTInPair.mul(liquidity).div(totalSupply)
//     const xDAIExpected = xDAIInPair.mul(liquidity).div(totalSupply)

//     await pair.approve(router.address, MaxUint256)
//     await router.removeLiquidityxDAIWithPermitSupportingFeeOnTransferTokens(
//       DTT.address,
//       liquidity,
//       NaiveDTTExpected,
//       xDAIExpected,
//       wallet.address,
//       MaxUint256,
//       false,
//       v,
//       r,
//       s,
//       overrides
//     )
//   })

//   describe('swapExactTokensForTokensSupportingFeeOnTransferTokens', () => {
//     const DTTAmount = expandTo18Decimals(5)
//       .mul(100)
//       .div(99)
//     const xDAIAmount = expandTo18Decimals(10)
//     const amountIn = expandTo18Decimals(1)

//     beforeEach(async () => {
//       await addLiquidity(DTTAmount, xDAIAmount)
//     })

//     it('DTT -> xDAI', async () => {
//       await DTT.approve(router.address, MaxUint256)

//       await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
//         amountIn,
//         0,
//         [DTT.address, xDAI.address],
//         wallet.address,
//         MaxUint256,
//         overrides
//       )
//     })

//     // xDAI -> DTT
//     it('xDAI -> DTT', async () => {
//       await xDAI.deposit({ value: amountIn }) // mint xDAI
//       await xDAI.approve(router.address, MaxUint256)

//       await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
//         amountIn,
//         0,
//         [xDAI.address, DTT.address],
//         wallet.address,
//         MaxUint256,
//         overrides
//       )
//     })
//   })

//   // xDAI -> DTT
//   it('swapExactxDAIForTokensSupportingFeeOnTransferTokens', async () => {
//     const DTTAmount = expandTo18Decimals(10)
//       .mul(100)
//       .div(99)
//     const xDAIAmount = expandTo18Decimals(5)
//     const swapAmount = expandTo18Decimals(1)
//     await addLiquidity(DTTAmount, xDAIAmount)

//     await router.swapExactxDAIForTokensSupportingFeeOnTransferTokens(
//       0,
//       [xDAI.address, DTT.address],
//       wallet.address,
//       MaxUint256,
//       {
//         ...overrides,
//         value: swapAmount
//       }
//     )
//   })

//   // DTT -> xDAI
//   it('swapExactTokensForxDAISupportingFeeOnTransferTokens', async () => {
//     const DTTAmount = expandTo18Decimals(5)
//       .mul(100)
//       .div(99)
//     const xDAIAmount = expandTo18Decimals(10)
//     const swapAmount = expandTo18Decimals(1)

//     await addLiquidity(DTTAmount, xDAIAmount)
//     await DTT.approve(router.address, MaxUint256)

//     await router.swapExactTokensForxDAISupportingFeeOnTransferTokens(
//       swapAmount,
//       0,
//       [DTT.address, xDAI.address],
//       wallet.address,
//       MaxUint256,
//       overrides
//     )
//   })
// })

// describe('fee-on-transfer tokens: reloaded', () => {
//   const provider = new MockProvider({
//     hardfork: 'istanbul',
//     mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
//     gasLimit: 9999999
//   })
//   const [wallet] = provider.getWallets()
//   const loadFixture = createFixtureLoader(provider, [wallet])

//   let DTT: Contract
//   let DTT2: Contract
//   let router: Contract
//   beforeEach(async function() {
//     const fixture = await loadFixture(v2Fixture)

//     router = fixture.router02

//     DTT = await deployContract(wallet, DeflatingERC20, [expandTo18Decimals(10000)])
//     DTT2 = await deployContract(wallet, DeflatingERC20, [expandTo18Decimals(10000)])

//     // make a DTT<>xDAI pair
//     await fixture.factoryV2.createPair(DTT.address, DTT2.address, DTT2.address, wallet.address, expandTo18Decimals(1), 1, 3)
//     const pairAddress = await fixture.factoryV2.getPair(DTT.address, DTT2.address)
//   })

//   afterEach(async function() {
//     expect(await provider.getBalance(router.address)).to.eq(0)
//   })

//   async function addLiquidity(DTTAmount: BigNumber, DTT2Amount: BigNumber) {
//     await DTT.approve(router.address, MaxUint256)
//     await DTT2.approve(router.address, MaxUint256)
//     await router.addLiquidity(
//       DTT.address,
//       DTT2.address,
//       DTTAmount,
//       DTT2Amount,
//       DTTAmount,
//       DTT2Amount,
//       wallet.address,
//       MaxUint256,
//       overrides
//     )
//   }

//   describe('swapExactTokensForTokensSupportingFeeOnTransferTokens', () => {
//     const DTTAmount = expandTo18Decimals(5)
//       .mul(100)
//       .div(99)
//     const DTT2Amount = expandTo18Decimals(5)
//     const amountIn = expandTo18Decimals(1)

//     beforeEach(async () => {
//       await addLiquidity(DTTAmount, DTT2Amount)
//     })

//     it('DTT -> DTT2', async () => {
//       await DTT.approve(router.address, MaxUint256)

//       await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
//         amountIn,
//         0,
//         [DTT.address, DTT2.address],
//         wallet.address,
//         MaxUint256,
//         overrides
//       )
//     })
//   })
// })
