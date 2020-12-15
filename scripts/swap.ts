import { time } from 'console'
import { ethers } from 'ethers'
import DAOfiV1Router01 from '../build/contracts/DAOfiV1Router01.sol/DAOfiV1Router01.json'
import ERC20 from '../build/contracts/test/ERC20.sol/ERC20.json'

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

async function main() {
  const overrides: any = {
    gasLimit: 9999999,
    gasPrice: ethers.utils.parseUnits('200', 'gwei')
  }
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.JSONRPC_URL || 'https://sokol.poa.network',
    process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : 0x4d
  )
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', provider)
  console.log('wallet', wallet.address)
  // const factoryAddr = '0xB430A74e9fC033b833f886cb28b823053526646D'

  const tokenA = new ethers.Contract(
    '0x95D86f98c513D282B2D90eA8cd1108Ed4dF3a9a4',
    JSON.stringify(ERC20.abi),
    wallet
  )
  console.log('connected tokenA', tokenA.address)

  const tokenB = new ethers.Contract(
    '0x11165B3f4aa026AE893E25e97aC1cfcCfC47c499',
    JSON.stringify(ERC20.abi),
    wallet
  )
  console.log('connected tokenB', tokenB.address)

  const router = new ethers.Contract(
    '0xcfC788C12EA759370c6cdBfFcf076B8B8FA75764',
    JSON.stringify(DAOfiV1Router01.abi),
    wallet
  )
  console.log('connected router', router.address)

  // const baseSupply = ethers.utils.parseEther('1000000000')
  // const zero = ethers.BigNumber.from(0)
  // await tokenA.approve(router.address, baseSupply, overrides)
  // await tokenB.approve(router.address, zero, overrides)

  // await router.addLiquidity({
  //   sender: wallet.address,
  //   to: wallet.address,
  //   tokenBase: tokenA.address,
  //   tokenQuote: tokenB.address,
  //   amountBase: baseSupply,
  //   amountQuote: zero,
  //   slopeNumerator: 1e3,
  //   n: 1,
  //   fee: 3
  // }, ethers.constants.MaxUint256, overrides)

  // await sleep(12000)

  // balances before swap
  console.log('wallet tokenA balance before:', await tokenA.balanceOf(wallet.address))
  console.log('wallet tokenB balance before:', await tokenB.balanceOf(wallet.address))

  const quoteAmountIn = ethers.utils.parseEther('50')
  //const baseAmountOut = ethers.BigNumber.from('9984000000000000000')
  const baseAmountOut = await router.getBaseOut(quoteAmountIn, tokenA.address, tokenB.address, 1e3, 1, 3, overrides)
  console.log('expected output:', baseAmountOut)

  await tokenB.approve(router.address, quoteAmountIn)
  const tx = await router.swapExactTokensForTokens({
    sender: wallet.address,
    to: wallet.address,
    tokenIn: tokenB.address,
    tokenOut: tokenA.address,
    amountIn: quoteAmountIn,
    amountOut: baseAmountOut,
    slopeNumerator: 1e3,
    n: 1,
    fee: 3
  }, ethers.constants.MaxUint256, overrides)

  console.log('tx:', tx)
  await sleep(12000)

  // balances after swap
  console.log('wallet tokenA balance after:', await tokenA.balanceOf(wallet.address))
  console.log('wallet tokenB balance after:', await tokenB.balanceOf(wallet.address))
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
