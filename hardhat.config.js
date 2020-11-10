/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const XDAI_PRIVATE_KEY = "b42e7dc2580efc7b156ef4b20cf254955b0b76b42fd92744b8a45e5e8f896a36";

module.exports = {
  solidity: "0.6.6",
  settings: {
    optimizer: {
      enabled: true
    }
  },
  networks: {
    xdai: {
      url: `https://dai.poa.network`,
      accounts: [`0x${XDAI_PRIVATE_KEY}`]
    }
  }
};
