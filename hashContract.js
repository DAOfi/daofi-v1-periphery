const Web3 = require('web3')
const pair = require('@daofi/daofi-v1-core/build/UniswapV2Pair.json')
console.log("hash of UniswapV2Pair bytecode")
console.log(Web3.utils.keccak256('0x'+ pair.bytecode.toString()))