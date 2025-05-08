const hre = require("hardhat");
const { ethers, JsonRpcProvider, Wallet } = require("ethers");

async function main() {
//   const [deployer] = await hre.ethers.getSigners();

    const provider = new JsonRpcProvider(process.env.AMOY_RPC_URL);
    const wallet = new Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);


    console.log("Deploying contracts with:", wallet.address);

    // 1. ChainRegistry 배포
    const ChainRegistry = await hre.ethers.getContractFactory("ChainRegistry", wallet);
    const registry = await ChainRegistry.deploy();
    await registry.waitForDeployment();

    console.log("ChainRegistry deployed to:", await registry.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
