import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { BigNumber, Contract } from 'ethers'
import { ethers } from 'hardhat'
import { Fixture, getTokenFixture, getETHFixture } from './shared/fixtures'
import { expandTo18Decimals, getReserveForStartPrice } from './shared/utilities'

const zero = ethers.BigNumber.from(0)
const MaxUint256 = ethers.constants.MaxUint256

let tokenFixture: Fixture
let ethFixture: Fixture
let wallet: SignerWithAddress
let baseReserve: BigNumber
let quoteReserve: BigNumber
let quoteReserveFloat: number
let expectedBaseOutput: BigNumber
let expectedBaseReserve: BigNumber

describe('DAOfiV1Router01: m = 1, n = 1, fee = 0', () => {
  beforeEach(async function () {
    wallet = (await ethers.getSigners())[0]
    baseReserve = expandTo18Decimals(1e9)
    expectedBaseOutput = ethers.BigNumber.from('9810134194000000000')
    expectedBaseReserve = baseReserve.sub(expectedBaseOutput)
    quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1)
    quoteReserve = expandTo18Decimals(quoteReserveFloat)
    tokenFixture = await getTokenFixture(wallet, 1e6, 1, 0, quoteReserveFloat)
    ethFixture = await getETHFixture(wallet, 1e6, 1, 0, quoteReserveFloat)
  })

  it('removeLiquidity:', async () => {
    const { router, pair, tokenBase, tokenQuote } = tokenFixture

    await expect(router.removeLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseReserve,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(pair, 'Withdraw')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, wallet.address)
    expect(await tokenBase.balanceOf(wallet.address)).to.eq(baseReserve)
    expect(await tokenQuote.balanceOf(wallet.address)).to.eq(await tokenQuote.totalSupply())
    expect(await tokenBase.balanceOf(pair.address)).to.eq(zero)
    expect(await tokenQuote.balanceOf(pair.address)).to.eq(zero)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(zero)
    expect(reserves[1]).to.eq(zero)
  })

  it('removeLiquidityETH:', async () => {
    const { router, pair, tokenBase, WETH } = ethFixture

    await expect(router.removeLiquidityETH({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      amountBase: baseReserve,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(pair, 'Withdraw')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, router.address)
    expect(await tokenBase.balanceOf(wallet.address)).to.eq(baseReserve)
    expect(await WETH.balanceOf(wallet.address)).to.eq(await WETH.totalSupply())
    expect(await tokenBase.balanceOf(pair.address)).to.eq(zero)
    expect(await WETH.balanceOf(pair.address)).to.eq(zero)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(zero)
    expect(reserves[1]).to.eq(zero)
  })

  it('price:', async () => {
    const { tokenBase, tokenQuote, router } = tokenFixture

    const price = ethers.BigNumber.from('9810134194000000000')
    expect(await router.price(tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(price)
  })

  it('getBaseOut:', async () => {
    const { tokenBase, tokenQuote, router } = tokenFixture

    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = ethers.BigNumber.from('4060021791989190426')
    expect(await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(
      baseAmountOut
    )
  })

  it('getQuoteOut:', async () => {
    const { tokenBase, tokenQuote, router } = tokenFixture
    const quoteAmountOut = ethers.BigNumber.from('49999949999999999999')
    expect(await router.getQuoteOut(expectedBaseOutput, tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(
      quoteAmountOut
    )
  })

  it('swap: quote for base and back to quote', async () => {
    const { router, tokenBase, tokenQuote, pair } = tokenFixture
    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 0)

    await tokenQuote.approve(router.address, quoteAmountIn)
    await expect(router.swapExactTokensForTokens({
      sender: wallet.address,
      to: wallet.address,
      tokenIn: tokenQuote.address,
      tokenOut: tokenBase.address,
      amountIn: quoteAmountIn,
      amountOut: baseAmountOut,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(tokenBase, 'Transfer')
      .withArgs(pair.address, wallet.address, baseAmountOut)
      .to.emit(pair, 'Swap')
      .withArgs(pair.address, router.address, tokenQuote.address, tokenBase.address, quoteAmountIn, baseAmountOut, wallet.address)
  })

  it('swap: multiple swaps', async () => {
    const { router, tokenBase, tokenQuote, pair } = tokenFixture

    let quoteAmountIn
    let baseAmountOut
    async function swap() {
      quoteAmountIn = expandTo18Decimals(1)
      baseAmountOut = await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 0)
      await tokenQuote.approve(router.address, quoteAmountIn)
      await expect(router.swapExactTokensForTokens({
        sender: wallet.address,
        to: wallet.address,
        tokenIn: tokenQuote.address,
        tokenOut: tokenBase.address,
        amountIn: quoteAmountIn,
        amountOut: baseAmountOut,
        tokenBase: tokenBase.address,
        tokenQuote: tokenQuote.address,
        slopeNumerator: 1e6,
        n: 1,
        fee: 0
      }, MaxUint256))
      .to.emit(tokenBase, 'Transfer')
      .withArgs(pair.address, wallet.address, baseAmountOut)
      .to.emit(pair, 'Swap')
      .withArgs(pair.address, router.address, tokenQuote.address, tokenBase.address, quoteAmountIn, baseAmountOut, wallet.address)
    }

    for(var i=0; i<10; i++) {
      await swap()
    }
  })

  it('swap: ETH for Tokens', async () => {
    const { router, tokenBase, WETH, pair } = ethFixture

    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = await router.getBaseOut(quoteAmountIn, tokenBase.address, WETH.address, 1e6, 1, 0)

    await expect(router.swapExactETHForTokens({
      sender: wallet.address,
      to: wallet.address,
      tokenIn: WETH.address,
      tokenOut: tokenBase.address,
      amountIn: quoteAmountIn,
      amountOut: baseAmountOut,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256, {value: quoteAmountIn}))
      .to.emit(tokenBase, 'Transfer')
      .withArgs(pair.address, wallet.address, baseAmountOut)
      .to.emit(pair, 'Swap')
      .withArgs(pair.address, router.address, WETH.address, tokenBase.address, quoteAmountIn, baseAmountOut, wallet.address)
  })

  it('swap: Tokens for ETH', async () => {
    const { router, tokenBase, WETH, pair } = ethFixture

    const quoteAmountOut = await router.getQuoteOut(expectedBaseOutput, tokenBase.address, WETH.address, 1e6, 1, 0)
    await tokenBase.approve(router.address, expectedBaseOutput)

    await expect(router.swapExactTokensForETH({
      sender: wallet.address,
      to: wallet.address,
      tokenIn: tokenBase.address,
      tokenOut: WETH.address,
      amountIn: expectedBaseOutput,
      amountOut: quoteAmountOut,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(WETH, 'Transfer')
      .withArgs(pair.address, router.address, quoteAmountOut)
      .to.emit(pair, 'Swap')
      .withArgs(pair.address, router.address, tokenBase.address, WETH.address, expectedBaseOutput, quoteAmountOut, router.address)
  })
})
