/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const XDAI_PRIVATE_KEY = "YOUR XDAI PRIVATE KEY";

module.exports = {
  solidity: "0.6.6",
  networks: {
    xdai: {
      url: `https://dai.poa.network`,
      accounts: [`0x${XDAI_PRIVATE_KEY}`]
    }
  }
};
