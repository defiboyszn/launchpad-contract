require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
import { getHardhatConfigNetworks } from "@zetachain/networks";
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
    mumbai: {
      url: "https://alfajores-forno.celo-testnet.org",
      accounts: [process.env.PRIVATE_KEY],
    },
    ...getHardhatConfigNetworks(),
  },
};