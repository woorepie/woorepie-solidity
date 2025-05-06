require("dotenv").config();
const { ethers } = require("hardhat");
const tokenArtifact = require("../artifacts/contracts/WooreToken.sol/WooreToken.json");

async function main() {
    const from = process.env.RECEIVER_PRIVATE_KEY;
    const to = process.env.WALLET;
    const provider = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL);
    const wallet = new ethers.Wallet(from, provider);

    console.log("to:", to);

    const tokenAddress = process.env.WOORETOKEN;
    const token = new ethers.Contract(tokenAddress, tokenArtifact.abi, wallet);

    const amount = ethers.parseUnits("100", 18); // 100 토큰 (decimals=18)
    const tx = await token.transfer(to, amount);
    console.log(`트랜잭션 전송됨! 해시: ${tx.hash}`);
    await tx.wait();
    console.log(`✅ Transferred 100 tokens to ${to}`);
    console.log(`🔎 Polygonscan에서 확인: https://amoy.polygonscan.com/tx/${tx.hash}`);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});