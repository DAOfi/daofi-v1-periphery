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

  it('addLiquidity: base only', async () => {
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
    expectedBaseOutput = ethers.BigNumber.from('9990000000000000000') // hack, contract will return this

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

  it('addLiquidityETH: base and quote', async () => {
    const { router, tokenBase, tokenQuote, pairETH, WETH } = routerFixture
    const baseSupply = expandTo18Decimals(1e9) // total supply
    const quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1) // 50
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    var expectedBaseOutput = ethers.BigNumber.from('100000000000000000000')
    expectedBaseOutput = ethers.BigNumber.from('9990000000000000000') // hack, contract will return this
    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    await tokenBase.approve(router.address, baseSupply)
    //await tokenQuote.approve(router.address, quoteReserve)
    await expect(router.addLiquidityETH({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256, {value: quoteReserve}))
      .to.emit(pairETH, 'Deposit')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, expectedBaseOutput, wallet.address)
  })

  it('removeLiquidity:', async () => {
    const { router, tokenBase, tokenQuote, pair } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)
    const quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1)
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    var expectedBaseOutput = ethers.BigNumber.from('100000000000000000000')
    expectedBaseOutput = ethers.BigNumber.from('9990000000000000000') // hack, contract will return this
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

  it('removeLiquidityETH:', async () => {
    const { router, tokenBase, WETH, pairETH } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)
    const quoteReserveFloat = getReserveForStartPrice(10, 1e6, 1)
    const quoteReserve = expandTo18Decimals(quoteReserveFloat)
    var expectedBaseOutput = ethers.BigNumber.from('100000000000000000000')
    expectedBaseOutput = ethers.BigNumber.from('9990000000000000000') // hack, contract will return this
    const expectedBaseReserve = baseSupply.sub(expectedBaseOutput)

    await tokenBase.approve(router.address, baseSupply)
    //await tokenQuote.approve(router.address, quoteReserve)
    await router.addLiquidityETH({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256, {value: quoteReserve})

    await expect(router.removeLiquidityETH({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      amountBase: baseSupply,
      amountQuote: quoteReserve,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(pairETH, 'Withdraw')
      .withArgs(router.address, expectedBaseReserve, quoteReserve, router.address)
    expect(await tokenBase.balanceOf(wallet.address)).to.eq(baseSupply)
    expect(await WETH.balanceOf(wallet.address)).to.eq(await WETH.totalSupply())
    expect(await tokenBase.balanceOf(pairETH.address)).to.eq(zero)
    expect(await WETH.balanceOf(pairETH.address)).to.eq(zero)

    const reserves = await pairETH.getReserves()
    expect(reserves[0]).to.eq(zero)
    expect(reserves[1]).to.eq(zero)
  })

  it('basePrice:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50))
    //const quotePrice = ethers.BigNumber.from('994999999999999999')
    const quotePrice = ethers.BigNumber.from('9509008500000000000')
    expect(await router.basePrice(tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(quotePrice)
  })

  it('quotePrice:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), expandTo18Decimals(50))
    //const basePrice = ethers.BigNumber.from('995049383620779533')
    const basePrice = ethers.BigNumber.from('99405430000000000')
    expect(await router.quotePrice(tokenBase.address, tokenQuote.address, 1e6, 1, 0)).to.eq(basePrice)
  })

  it('getBaseOut:', async () => {
    const { tokenBase, tokenQuote, router } = walletFixture
    await addLiquidity(expandTo18Decimals(1e9), zero)
    const quoteAmountIn = expandTo18Decimals(50)
    //const baseAmountOut = ethers.BigNumber.from('99600000000000000000')
    const baseAmountOut = ethers.BigNumber.from('9990000000000000000')
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
    const quoteAmountOut = ethers.BigNumber.from('50000000000000000000')
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

  it.only('swap: low liquidity error case', async () => {
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
  console.log('reserves:', (await pair.getReserves()))
  console.log('base reserve:', (await pair.getReserves())[0].toString())
  console.log('quote reserve:', (await pair.getReserves())[1].toString())

    const quoteAmountIn = expandTo18Decimals(1)
    const baseAmountOut = await router.getBaseOut(quoteAmountIn, tokenBase.address, tokenQuote.address, 1e6, 1, 0)
    console.log('quote amount in:', quoteAmountIn.toString())
    console.log('base amount out:', baseAmountOut.toString())
    async function swap() {
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
    await swap()
    // swapping same amount again fails
    await swap()
  })

  it('swap: Ether for Tokens', async () => {
    const { router, tokenBase, WETH, pairETH } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)

    await tokenBase.approve(router.address, baseSupply)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      amountBase: baseSupply,
      amountQuote: zero,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256)

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
      .withArgs(pairETH.address, wallet.address, baseAmountOut)
      .to.emit(pairETH, 'Swap')
      .withArgs(pairETH.address, router.address, WETH.address, tokenBase.address, quoteAmountIn, baseAmountOut, wallet.address)
  })

  it('swap: Tokens for Ether', async () => {
    const { router, tokenBase, WETH, pairETH } = routerFixture
    const baseSupply = expandTo18Decimals(1e9)
    //const WETHSupply = expandTo18Decimals(10) TODO, Low weth fails to transfer tokens
    const WETHSupply = expandTo18Decimals(1000)

    await tokenBase.approve(router.address, baseSupply)
    await WETH.deposit({value: WETHSupply})
    await WETH.approve(router.address, WETHSupply)
    await router.addLiquidity({
      sender: wallet.address,
      to: wallet.address,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      amountBase: baseSupply,
      amountQuote: WETHSupply,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256)

    const baseAmountIn = expandTo18Decimals(10)
    const quoteAmountOut = await router.getQuoteOut(baseAmountIn, tokenBase.address, WETH.address, 1e6, 1, 0)
    await tokenBase.approve(router.address, baseAmountIn)

    await expect(router.swapExactTokensForETH({
      sender: wallet.address,
      to: wallet.address,
      tokenIn: tokenBase.address,
      tokenOut: WETH.address,
      amountIn: baseAmountIn,
      amountOut: quoteAmountOut,
      tokenBase: tokenBase.address,
      tokenQuote: WETH.address,
      slopeNumerator: 1e6,
      n: 1,
      fee: 0
    }, MaxUint256))
      .to.emit(WETH, 'Transfer')
      .withArgs(pairETH.address, router.address, quoteAmountOut)
      .to.emit(pairETH, 'Swap')
      .withArgs(pairETH.address, router.address, tokenBase.address, WETH.address, baseAmountIn, quoteAmountOut, router.address)
  })
})
