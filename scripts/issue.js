require("dotenv").config();
const { ethers } = require("hardhat");
const { parseUnits } = require("ethers");
const tokenArtifact = require("../artifacts/contracts/WooreToken.sol/WooreToken.json");

async function main() {
    const deployer = process.env.DEPLOYER_PRIVATE_KEY;
    const receiver = process.env.RECEIVER;
    const provider = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL);
    const wallet = new ethers.Wallet(deployer, provider);
    const tokenAddress = process.env.WOORETOKEN;
    
    // console.log("deployer:", deployer);
    // console.log("receiver:", receiver);
    // console.log("provider:", provider);
    // console.log("tokenAddress:", tokenAddress);
    // console.log("tokenArtifact.abi:", tokenArtifact.abi);
      
    const token = new ethers.Contract(tokenAddress, tokenArtifact.abi, wallet);
  
  
  //   const Token = await ethers.getContractFactory("ERC1400");
  //   const token = await Token.attach(contractAddress);
    // const MINTER_ROLE = ethers.utils.id("MINTER_ROLE");
    // const isMinter = await token.hasRole(MINTER_ROLE, wallet.address);
    // if(!isMinter) {
    //     await token.addMinter(wallet.address);
    // }
  
    if(!await token.isIssuable()) {
      await token.setIssuable(true);
    }
  
    const amount = parseUnits("1000", 18); // decimal = 18
    const data = "0x";
  
    const tx = await token.issue(receiver, amount, data);
    await tx.wait();
  
    console.log(`✅ Issued 1000 tokens to ${receiver}`);
  }
  
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });

  

// async function main() {
//   const provider = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL);

//   const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY;
//   const receiverAddress = process.env.RECEIVER;
//   const deployerSigner = new ethers.Wallet(deployerPrivateKey, provider);

//   const contractAddress = process.env.WOORETOKEN;

//   console.log("Using deployer:", await deployerSigner.getAddress());
//   console.log("Receiver address:", receiverAddress);
//   console.log("Connected to ERC1400 contract at:", contractAddress);

//   const abi = [
//     "function issue(address tokenHolder, uint256 value, bytes calldata data) external",
//     "function balanceOf(address account) external view returns (uint256)",
//     "function transfer(address to, uint256 value) external returns (bool)",
//     "function getDefaultPartitions() external view returns (bytes32[])"
//   ];

//   const Token = new ethers.Contract(contractAddress, abi, deployerSigner);

//   // ========== [1] issue (발행) ==========
//   console.log("Issuing tokens...");

//   const issueAmount = ethers.parseUnits("1000", 18); // 1000 토큰
//   const issueData = "0x"; // 빈 데이터

//   const issueTx = await Token.issue(receiverAddress, issueAmount, issueData);
//   await issueTx.wait();

//   console.log(`Issued ${ethers.formatUnits(issueAmount, 18)} tokens to`, receiverAddress);

//   // ========== [2] Transfer (전송) ==========
//   console.log("Transferring tokens from receiver back to deployer...");

//   // 이제 receiverSigner 필요
//   const receiverPrivateKey = process.env.RECEIVER_PRIVATE_KEY;
//   const receiverSigner = new ethers.Wallet(receiverPrivateKey, provider);

//   // receiver 기준으로 컨트랙트 다시 연결
//   const TokenWithReceiver = Token.connect(receiverSigner);

//   const deployerAddress = await deployerSigner.getAddress();

//   const transferAmount = ethers.parseUnits("100", 18);

//   const transferTx = await TokenWithReceiver.transfer(
//     deployerAddress,
//     transferAmount
//   );
//   await transferTx.wait();

//   console.log(`Transferred ${ethers.formatUnits(transferAmount, 18)} tokens to deployer`);

//   // ========== [3] Balance 확인 ==========
//   const receiverBalance = await Token.balanceOf(receiverAddress);
//   const deployerBalance = await Token.balanceOf(deployerAddress);

//   console.log("Receiver Balance:", ethers.formatUnits(receiverBalance, 18));
//   console.log("Deployer Balance:", ethers.formatUnits(deployerBalance, 18));
// }

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });


// const hre = require("hardhat");

