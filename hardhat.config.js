require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
module.exports = {
  solidity: "0.8.18",
  settings:{
    optimizer: {
      enabled: true,
      runs: 100,
    },
    viaIR: true
  },
  networks: {
    "telos-testnet": {
      url: "https://testnet.telos.net/evm",
      accounts: [process.env.PRIVATE_KEY]
    },
    "zeta-testnet": {
      url: "https://rpc.ankr.com/zetachain_evm_athens_testnet",
      accounts: [process.env.PRIVATE_KEY]
    },

    "bitfinity-testnet": {
      url: "https://testnet.bitfinity.network/",
      accounts: [process.env.PRIVATE_KEY]
    },
  },
};