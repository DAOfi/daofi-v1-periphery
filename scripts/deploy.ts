import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import UniswapV2Router02 from '../build/UniswapV2Router02.json'

async function main() {
  const provider = new ethers.providers.JsonRpcProvider('https://dai.poa.network', 100)
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', provider)
  console.log('wallet', wallet.address)
  const router = await deployContract(
    wallet,
    UniswapV2Router02,
    [
      '0x5CE34689DFdE06053e048ba11A76198c4E4e7A77',
      '0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d'
    ],
    {
      chainId: 100,
      gasLimit: 9999999,
      gasPrice: ethers.utils.parseUnits('120', 'gwei')
    }
  )
  console.log('deployed router', await router.addressPromise)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });