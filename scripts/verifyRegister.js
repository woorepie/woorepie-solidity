require("dotenv").config();
const { hre } = require("hardhat");
const { ethers, JsonRpcProvider, Wallet, solidityPacked, keccak256,solidityPackedKeccak256, getBytes } = require("ethers");
const tokenArtifact = require("../artifacts/contracts/WooreToken.sol/WooreToken.json");
const chainRegistryArtifact = require("../artifacts/contracts/registry/ChainRegistry.sol/ChainRegistry.json");

async function main() {
    const verifier = process.env.DEPLOYER_PRIVATE_KEY;
    const user = process.env.RECEIVER;
    const provider = new JsonRpcProvider(process.env.AMOY_RPC_URL);
    const wallet = new Wallet(verifier, provider);
    const chainRegistryAddress = process.env.REREGICHAIN
    const validityPeriod = 31536000
    const KYCHash = ethers.keccak256(ethers.toUtf8Bytes("KYC:passed"));
    const prefix = "\x19Ethereum Signed Message:\n32";

    const chainRegistry = new ethers.Contract(chainRegistryAddress, chainRegistryArtifact.abi, wallet);

    console.log(`user : ${user}`);

    const encoded = solidityPackedKeccak256(
        ["address", "bytes32", "uint256"],
        [user, KYCHash, validityPeriod]
      );
      
    const prefixedMessage = ethers.concat([
        ethers.toUtf8Bytes(prefix),
        getBytes(encoded)
    ]);
    
    // const originalPacked = solidityPacked (
    //     ["address", "bytes32", "uint256"], 
    //     [user, KYCHash, validityPeriod]
    //   );

    // const messageHash = keccak256(originalPacked);

    const hash = keccak256(prefixedMessage);
    const signature = await wallet.signingKey.sign(hash).serialized;
    


    // const messageBytes = arrayify(messageHash); ethers v5에서 사용
    // const messageBytes = getBytes(messageHash);
    
    // 3. 검증자 개인키로 해시에 서명 생성 (ERC-191 prefixed 메시지 서명)
    // const signature = await wallet.signMessage(originalPacked);
    console.log(`생성된 서명: ${signature}`);
    console.log(`생성된 해쉬: ${hash}`);

    const role = await chainRegistry.VERIFIER_ROLE();
    const has = await chainRegistry.hasRole(role, wallet.address);
    console.log("Has VERIFIER_ROLE?", has);

    const recovered = ethers.verifyMessage(encoded, signature);
    console.log("Recovered signer: ", recovered);
    console.log("Wallet address:   ", wallet.address);
    

    // const recovered = ethers.verifyMessage(originalPacked, signature);
    // const recoveredHash = ethers.hashMessage((messageHash)); // 프리픽스 추가된 해시
    // const recoveredAddress = ethers.recoverAddress(recoveredHash, signature);
    // console.log("Recovered signer: ", recoveredAddress);
    // console.log("Wallet address:  ", wallet.address);  // 둘이 일치해야 함

    const sig = ethers.Signature.from(signature); // v6 방식
    const { v, r, s } = sig;
    console.log("v: ", v);
    console.log("r: ", r);
    console.log("s: ", s);
    // await chainRegistry.verifyIdentity.staticCall(user, hash, validityPeriod, v, r, s);

    // 4. ChainRegistry.verifyIdentity 함수 호출 (서명과 사용자 주소 전달)
    const tx = await chainRegistry.verifyIdentity(user, hash, validityPeriod, signature);
    console.log(`verifyIdentity 트랜잭션 전송: ${tx.hash}`);
    await tx.wait();  // 트랜잭션 확정 대기
    console.log(`${user} 사용자 신원 등록 완료 (트랜잭션 확인됨)`);
    console.log(`🔎 Polygonscan에서 확인: https://amoy.polygonscan.com/tx/${tx.hash}`);
    }

main().catch((error) => {
    console.error(error);
    process.exit(1);
});