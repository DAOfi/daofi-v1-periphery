import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import DAOfiV1Router01 from '../build/contracts/DAOfiV1Router01.sol/DAOfiV1Router01.json'

const kovanID = 0x2a
const xdaiID = 0x4d

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.JSONRPC_URL || 'https://kovan.poa.network'
  )
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '0x011f5d8c37def36f4bd85f8b1a8e82bf104abdaac8c0710ab70e5f86dba180cc', provider)
  console.log('wallet', wallet.address)
  const router = await deployContract(
    wallet,
    DAOfiV1Router01,
    [
      // factory
      '0xe6Aa73645c1602fECC21f97fDFA473Fb5d60d47e',
      // WXDAI
      //'0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d',
      // WETH
      '0xe9796Ea0432d158C8fd9d7168cc499c1fe572759'
    ],
    {
      chainId: process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : kovanID,
      gasLimit: 9999999,
      gasPrice: ethers.utils.parseUnits('120', 'gwei')
    }
  )
  console.log('deployed router', router.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
