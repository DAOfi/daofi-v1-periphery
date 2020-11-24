import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { BigNumber, Contract } from 'ethers'
import { ethers } from 'hardhat'
import { getFixtureWithParams } from './shared/fixtures'
import { expandTo18Decimals, getReserveForStartPrice } from './shared/utilities'

const zero = ethers.BigNumber.from(0)

let tokenBase: Contract
let tokenQuote: Contract
let xDAI: Contract
let xDAIPartner: Contract
let factory: Contract
let router: Contract
let pair: Contract
let xDAIPair: Contract
let wallet: SignerWithAddress

describe('DAOfiV1Router01: m = 1, n = 1, fee = 3', () => {
  async function addLiquidity(
    baseReserve: BigNumber,
    quoteReserve: BigNumber,
  ) {
    if (baseReserve.gt(zero))
      await tokenBase.transfer(pair.address, baseReserve)
    if (quoteReserve.gt(zero))
      await tokenQuote.transfer(pair.address, quoteReserve)
    await pair.deposit(wallet.address)
  }

  beforeEach(async function() {
    wallet = (await ethers.getSigners())[0]
    const fixture = await getFixtureWithParams(wallet, 1e6, 1, 3)
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
    await addLiquidity(expandTo18Decimals(1e9), zero)
    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = ethers.BigNumber.from('9999000000000000000')
    expect(await router.priceBase(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3))
      .to.eq(baseAmountOut)
  })

  it('priceQuote', async () => {
    // //We get 50 quote in liquidity from price 10 quote, with 10 base issued
    // await addLiquidityForPrice(10, tokenBase, tokenQuote, expandTo18Decimals(1e6), pair)
    // // the amount of base issued
    // const baseAmountIn = ethers.BigNumber.from('9999000000000000000')
    // const quoteAmountOut = expandTo18Decimals(50)
    // expect(await router.priceQuote(baseAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3))
    //   .to.eq(quoteAmountOut)
  })

  it('getBaseOut', async () => {
    // //We get 50 quote in liquidity from price 10 quote, with 10 base issued
    // await addLiquidityForPrice(10, tokenBase, tokenQuote, expandTo18Decimals(1e6), pair)
    // // the amount of base issued
    // const baseAmountIn = ethers.BigNumber.from('9999000000000000000')
    // const quoteAmountOut = expandTo18Decimals(50)
    // expect(await router.priceQuote(baseAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3))
    //   .to.eq(quoteAmountOut)
  })

  it('getQuoteOut', async () => {
    // //We get 50 quote in liquidity from price 10 quote, with 10 base issued
    // await addLiquidityForPrice(10, tokenBase, tokenQuote, expandTo18Decimals(1e6), pair)
    // // the amount of base issued
    // const baseAmountIn = ethers.BigNumber.from('9999000000000000000')
    // const quoteAmountOut = expandTo18Decimals(50)
    // expect(await router.priceQuote(baseAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 3))
    //   .to.eq(quoteAmountOut)
  })
})