require("@nomicfoundation/hardhat-toolbox");
const dotenv = require("dotenv");

dotenv.config();
console.log("WALLET:", process.env.WALLET ? "설정됨" : "설정되지 않음");
console.log("PRIVATE_KEY:", process.env.DEPLOYER_PRIVATE_KEY ? "설정됨" : "설정되지 않음");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 50,
      },
    },
  },
  networks: {
    polygon: {
      url: "https://polygon-rpc.com/",
      chainId: 137,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },  
    amoy: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: [process.env.DEPLOYER_PRIVATE_KEY], 
      chainId: 80002,
    },
  },
  etherscan: {
    apiKey: {
      polygonAmoy: process.env.POLYGONSCAN_API_KEY, 
    },
  },
};