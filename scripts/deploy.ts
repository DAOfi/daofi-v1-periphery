import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import DAOfiV1Router01 from '../build/contracts/DAOfiV1Router01.sol/DAOfiV1Router01.json'

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.JSONRPC_URL || 'https://sokol.poa.network'
  )
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', provider)
  console.log('Wallet:', wallet.address)
  const router = await deployContract(
    wallet,
    DAOfiV1Router01,
    [
      // factory
      '0x725a65f6806E9Ee9594C6e47F198e65aF7C4E3CE',
      // WXDAI on sokol
      '0x705581f5830Cfd11715020543f5309ADEBdbd074',
    ],
    {
      chainId: process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : 0x4D, // default to sokol (77)
      gasLimit: 9999999,
      gasPrice: ethers.utils.parseUnits('120', 'gwei')
    }
  )
  console.log('Router deployted at:', router.address)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  });
