import { ethers } from 'ethers'
import { deployContract } from 'ethereum-waffle'
import DAOfiV1Router01 from '../build/contracts/DAOfiV1Router01.sol/DAOfiV1Router01.json'

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.JSONRPC_URL || 'https://data-seed-prebsc-1-s1.binance.org:8545'
  )
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', provider)
  console.log('Wallet:', wallet.address)
  const router = await deployContract(
    wallet,
    DAOfiV1Router01,
    [
      // factory BSC
      '0x6B5437490EA99305C5acae19fE37454b3Ff199bF',
      // WBNB
      '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'
    ],
    {
      gasLimit: 8000000,
      gasPrice: ethers.utils.parseUnits('20', 'gwei')
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
