const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with:", deployer.address);

  // 1. ChainRegistry 배포
  const ChainRegistry = await hre.ethers.getContractFactory("ChainRegistry");
  const registry = await ChainRegistry.deploy();
  await registry.waitForDeployment();

  console.log("ChainRegistry deployed to:", await registry.getAddress());

  // 2. WooreToken 배포
  const WooreToken = await hre.ethers.getContractFactory("WooreToken");
  const name = "STO TEST TOKEN";
  const symbol = "MST";
  const granularity = 1; // ERC1400의 최소 단위
  const controllers = []; // 필요에 따라 컨트롤러 주소 배열 입력
  const defaultPartitions = []; // 필요에 따라 파티션 배열 입력
  const registryAddress = await registry.getAddress();
  const certificateSigner = ethers.ZeroAddress; // 인증서 서명자 주소 (기본값: 0 주소)
  const certificateActivated = false; // 인증서 검증 활성화 여부 (기본값: false)

  const token = await WooreToken.deploy(
    name,
    symbol,
    granularity,
    controllers,
    defaultPartitions,
    registryAddress
  );
  await token.waitForDeployment();

  console.log("WooreToken deployed to:", await token.getAddress());

  // 배포된 주소 출력
  console.log("\nDeployed Contracts:");
  console.log("-------------------");
  console.log("ChainRegistry:", registryAddress);
  console.log("WooreToken:", await token.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
