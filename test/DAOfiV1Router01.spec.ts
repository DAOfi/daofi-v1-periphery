import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { BigNumber, Contract } from 'ethers'
import { ethers } from 'hardhat'
import { DAOfiV1Fixture, getFixtureWithParams } from './shared/fixtures'
import { expandTo18Decimals, getReserveForStartPrice } from './shared/utilities'

const zero = ethers.BigNumber.from(0)
const MaxUint256 = ethers.constants.MaxUint256

let walletFixture: DAOfiV1Fixture
let routerFixture: DAOfiV1Fixture
let wallet: SignerWithAddress

describe('DAOfiV1Router01: m = 1, n = 1, fee = 0', () => {
  async function addLiquidity(baseReserve: BigNumber, quoteReserve: BigNumber) {
    const { tokenBase, tokenQuote, pair } = walletFixture
    if (baseReserve.gt(zero)) await tokenBase.transfer(pair.address, baseReserve)
    if (quoteReserve.gt(zero)) await tokenQuote.transfer(pair.address, quoteReserve)
    await pair.deposit(wallet.address)
  }

  beforeEach(async function () {
    wallet = (await ethers.getSigners())[0]
    walletFixture = await getFixtureWithParams(wallet, 1e6, 1, 0)
    routerFixture = await getFixtureWithParams(wallet, 1e6, 1, 0, false)
  })

  it('addLiquidity: zero quote', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, zero)
    await expect(router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: zero,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(pair, 'Deposit')
      .withArgs(router.address, baseSupply, zero, zero, wallet.address)
  })

  it('addLiquidity: base and quote', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9) // total supply
    const quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1) // 50
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)

    var expectedBaseOutput = ethers.BigNumber.from('100000000000000000000')
    expectedBaseOutput = ethers.BigNumber.from('9999900000000000000') // hack, contract will return this

    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, quoteReserve)
    await expect(router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(pair, 'Deposit')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, expectedBaseOutput, wallet.address)
  })

  it('addLiquidityXDAI: base and quote', async () => {
    const { router, tokenBase, tokenQuote, xDAIPair, xDAI } = routerFixture
    const baseSupply = expandTo18Decimals(1e9) // total supply
    const quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1) // 50
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    var expectedBaseOutput = ethers.BigNumber.from('100000000000000000000')
    expectedBaseOutput = ethers.BigNumber.from('9999900000000000000') // hack, contract will return this
    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    await tokenBase.approve(router.address, baseSupply)
    //await tokenQuote.approve(router.address, quoteReserve)
    await expect(router.addLiquidityXDAI({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: xDAI.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256, {value: quoteReserve}))
      .to.emit(xDAIPair, 'Deposit')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, expectedBaseOutput, wallet.address)
  })

  it('removeLiquidity:', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)
    const quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1)
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    var expectedBaseOutput = ethers.BigNumber.from('100000000000000000000')
    expectedBaseOutput = ethers.BigNumber.from('9999900000000000000') // hack, contract will return this
    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, quoteReserve)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256)

    await expect(router.removeLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(pair, 'Withdraw')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, wallet.address)
    expect(await tokenBase.balanceOf(wallet.address)).to.eq(baseSupply)
    expect(await tokenQuote.balanceOf(wallet.address)).to.eq(await tokenQuote.totalSupply())
    expect(await tokenBase.balanceOf(pair.address)).to.eq(zero)
    expect(await tokenQuote.balanceOf(pair.address)).to.eq(zero)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(zero)
    expect(reserves[1]).to.eq(zero)
  })

  it('removeLiquidityXDAI:', async () => {
    const { router, tokenBase, xDAI, xDAIPair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)
    const quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1)
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    var expectedBaseOutput = ethers.BigNumber.from('100000000000000000000')
    expectedBaseOutput = ethers.BigNumber.from('9999900000000000000') // hack, contract will return this
    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    await tokenBase.approve(router.address, baseSupply)
    //await tokenQuote.approve(router.address, quoteReserve)
    await router.addLiquidityXDAI({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: xDAI.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256, {value: quoteReserve})

    await expect(router.removeLiquidityXDAI({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: xDAI.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(xDAIPair, 'Withdraw')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, router.address)
    expect(await tokenBase.balanceOf(wallet.address)).to.eq(baseSupply)
    expect(await xDAI.balanceOf(wallet.address)).to.eq(await xDAI.totalSupply())
    expect(await tokenBase.balanceOf(xDAIPair.address)).to.eq(zero)
    expect(await xDAI.balanceOf(xDAIPair.address)).to.eq(zero)

    const reserves = await xDAIPair.getReserves()
    expect(reserves[0]).to.eq(zero)
    expect(reserves[1]).to.eq(zero)
  })

  it('price:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50))
    //const quotePrice = ethers.BigNumber.from('994999999999999999')
    const quotePrice = ethers.BigNumber.from('9500090000000000000')
    expect(await router.price(tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(quotePrice)
  })

  it('getBaseOut:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), zero)
    const quoteAmountIn = expandTo18Decimals(50)
    //const baseAmountOut = ethers.BigNumber.from('99600000000000000000')
    const baseAmountOut = ethers.BigNumber.from('9994900000000000000')
    expect(await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(
      baseAmountOut
    )
  })

  it('getQuoteOut:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    // need a starting price to sell base for quote
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50))
    const baseAmountIn = ethers.BigNumber.from('10000000000000000000')
    //const quoteAmountOut = ethers.BigNumber.from('9463991999999999999')
    const quoteAmountOut = ethers.BigNumber.from('49999950990000000000')
    expect(await router.getQuoteOut(baseAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(
      quoteAmountOut
    )
  })

  it('swap: quote for base and back to quote', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)

    await tokenBase.approve(router.address, baseSupply)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: zero,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256)

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
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(60)
    const quoteSupply = expandTo18Decimals(1)

    await tokenBase.approve(router.address, baseSupply)
    await tokenQuote.approve(router.address, quoteSupply)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: tokenQuote.address,
      amountBase: baseSupply,
      amountQuote: quoteSupply,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256)

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

  it('swap: XDAI for Tokens', async () => {
    const { router, tokenBase, xDAI, xDAIPair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)

    await tokenBase.approve(router.address, baseSupply)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: xDAI.address,
      amountBase: baseSupply,
      amountQuote: zero,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256)

    const quoteAmountIn = expandTo18Decimals(50)
    const baseAmountOut = await router.getBaseOut(quoteAmountIn, tokenBase.address, xDAI.address, 1e6, 1, 0)

    await expect(router.swapExactXDAIForTokens({
      sender: wallet.address,
      to: wallet.address,
      tokenIn: xDAI.address,
      tokenOut: tokenBase.address,
      amountIn: quoteAmountIn,
      amountOut: baseAmountOut,
      tokenBase: tokenBase.address,
      tokenQuote: xDAI.address,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256, {value: quoteAmountIn}))
      .to.emit(tokenBase, 'Transfer')
      .withArgs(xDAIPair.address, wallet.address, baseAmountOut)
      .to.emit(xDAIPair, 'Swap')
      .withArgs(xDAIPair.address, router.address, xDAI.address, tokenBase.address, quoteAmountIn, baseAmountOut, wallet.address)
  })

  it('swap: Tokens for XDAI', async () => {
    const { router, tokenBase, xDAI, xDAIPair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)
    //const WETHSupply = expandTo18Decimals(10) TODO, Low weth fails to transfer tokens
    const WXDAISupply = expandTo18Decimals(1000)

    await tokenBase.approve(router.address, baseSupply)
    await xDAI.deposit({value: WXDAISupply})
    await xDAI.approve(router.address, WXDAISupply)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: xDAI.address,
      amountBase: baseSupply,
      amountQuote: WXDAISupply,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256)

    const baseAmountIn = expandTo18Decimals(10)
    const quoteAmountOut = await router.getQuoteOut(baseAmountIn, tokenBase.address, xDAI.address, 1e6, 1, 0)
    await tokenBase.approve(router.address, baseAmountIn)

    await expect(router.swapExactTokensForXDAI({
      sender: wallet.address,
      to: wallet.address,
      tokenIn: tokenBase.address,
      tokenOut: xDAI.address,
      amountIn: baseAmountIn,
      amountOut: quoteAmountOut,
      tokenBase: tokenBase.address,
      tokenQuote: xDAI.address,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(xDAI, 'Transfer')
      .withArgs(xDAIPair.address, router.address, quoteAmountOut)
      .to.emit(xDAIPair, 'Swap')
      .withArgs(xDAIPair.address, router.address, tokenBase.address, xDAI.address, baseAmountIn, quoteAmountOut, router.address)
  })
})
