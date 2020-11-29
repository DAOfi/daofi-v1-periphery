import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import ERC20 from '../build/contracts/test/ERC20.sol/ERC20.json'

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.JSONRPC_URL || 'https://sokol.poa.network'
  )
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', provider)
  console.log('wallet', wallet.address)

  const tokenA = await deployContract(
    wallet,
    ERC20,
    [
      ethers.utils.parseEther('1000000000')
    ],
    {
      chainId: process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : 0x4d,
      gasLimit: 9999999,
      gasPrice: ethers.utils.parseUnits('120', 'gwei')
    }
  )
  console.log('deployed tokenA', tokenA.address)

  const tokenB = await deployContract(
    wallet,
    ERC20,
    [
      ethers.utils.parseEther('1000000000')
    ],
    {
      chainId: process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : 0x4d,
      gasLimit: 9999999,
      gasPrice: ethers.utils.parseUnits('120', 'gwei')
    }
  )
  console.log('deployed tokenB', tokenB.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
