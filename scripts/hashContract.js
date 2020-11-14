const Web3 = require('web3')
const pair = require('@daofi/daofi-v1-core/build/DAOfiV1Pair.json')
console.log("hash of DAOfiV1Pair bytecode")
console.log(Web3.utils.keccak256('0x'+ pair.bytecode.toString()))