require("dotenv").config();
const { ethers, JsonRpcProvider, Wallet } = require("ethers");
const tokenArtifact = require("../artifacts/contracts/WooreToken.sol/WooreToken.json");
const chainRegistryArtifact = require("../artifacts/contracts/registry/ChainRegistry.sol/ChainRegistry.json");

async function main() {
    const verifier = process.env.DEPLOYER_PRIVATE_KEY;
    const user = process.env.RECEIVER;
    const provider = new JsonRpcProvider(process.env.AMOY_RPC_URL);
    const wallet = new Wallet(verifier, provider);
    const chainRegistryAddress = process.env.NEWREGI;
    const validityPeriod = 31536000;
    const KYCHash = ethers.keccak256(ethers.toUtf8Bytes("KYC:passed"));

    const chainRegistry = new ethers.Contract(chainRegistryAddress, chainRegistryArtifact.abi, wallet);

    console.log(`user : ${user}`);
    console.log(`KYCHash : ${KYCHash}`);

    // ✅ 컨트랙트와 동일한 방식으로 해시 생성
    // Solidity: keccak256(abi.encode(user, verificationHash, validityPeriod))
    const messageHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
            ["address", "bytes32", "uint256"],
            [user, KYCHash, validityPeriod]
        )
    );

    console.log(`생성된 메시지 해시: ${messageHash}`);

    // ✅ ethers의 signMessage 사용 (자동으로 EIP-191 prefix 추가)
    const signature = await wallet.signMessage(ethers.getBytes(messageHash));
    console.log(`생성된 서명: ${signature}`);

    // 검증 테스트
    const role = await chainRegistry.VERIFIER_ROLE();
    const has = await chainRegistry.hasRole(role, wallet.address);
    console.log("Has VERIFIER_ROLE?", has);

    // ✅ 서명 검증 테스트
    const recovered = ethers.verifyMessage(ethers.getBytes(messageHash), signature);
    console.log("Recovered signer: ", recovered);
    console.log("Wallet address:   ", wallet.address);
    console.log("Signatures match: ", recovered.toLowerCase() === wallet.address.toLowerCase());

    try {
        // ChainRegistry.verifyIdentity 함수 호출
        const tx = await chainRegistry.verifyIdentity(user, KYCHash, validityPeriod, signature);
        console.log(`verifyIdentity 트랜잭션 전송: ${tx.hash}`);
        await tx.wait();
        console.log(`${user} 사용자 신원 등록 완료 (트랜잭션 확인됨)`);
        console.log(`🔎 Polygonscan에서 확인: https://amoy.polygonscan.com/tx/${tx.hash}`);

       // 등록 결과 확인
       const [isValid, status, validUntil, lastSync] = await chainRegistry.getIdentityStatus(user);
       console.log(`\n=== 등록 결과 ===`);
       console.log(`Valid: ${isValid}`);
       console.log(`Status: ${status}`);
       console.log(`Valid Until: ${new Date(Number(validUntil) * 1000)}`);
       console.log(`Last Sync: ${Number(lastSync)}`);


    } catch (error) {
        console.error("트랜잭션 실패:", error.message);
        
        // 추가 디버깅 정보
        if (error.message.includes("revert")) {
            console.log("\n=== 디버깅 정보 ===");
            console.log("1. VERIFIER_ROLE 확인됨:", has);
            console.log("2. 서명 매치 확인됨:", recovered.toLowerCase() === wallet.address.toLowerCase());
            console.log("3. 사용된 서명:", signature);
        }
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});