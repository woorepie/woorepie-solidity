/*
const readline = require('readline');
const { toUtf8String } = require('ethers'); // ethers v6 기준

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  prompt: 'hex> '
});

console.log('Hex 값을 입력하세요 (Ctrl+C로 종료):');
rl.prompt();

rl.on('line', (line) => {
    if (line.startsWith('0x')) line = line.slice(2);
    let result = [];
    for (let i = 0; i < line.length; i += 64) { // 32바이트 = 64 hex chars
        const chunk = line.slice(i, i + 64);
        // 0 패딩 제거
        const noPad = chunk.replace(/(00)+$/, '');
        if (noPad.length === 0) continue;
        try {
            const text = toUtf8String('0x' + noPad);
            result.push(text);
        } catch (e) {
            // 변환 불가(바이너리 등)면 무시
        }
    console.log(result.join(''));
    rl.prompt();
    }
});
*/

const { toUtf8String } = require("ethers");

function hexDataToText(hex) {
    if (hex.startsWith('0x')) hex = hex.slice(2);
    let result = [];
    for (let i = 0; i < hex.length; i += 64) { // 32바이트 = 64 hex chars
        const chunk = hex.slice(i, i + 64);
        // 0 패딩 제거
        const noPad = chunk.replace(/(00)+$/, '');
        if (noPad.length === 0) continue;
        try {
            const text = toUtf8String('0x' + noPad);
            result.push(text);
        } catch (e) {
            // 변환 불가(바이너리 등)면 무시
        }
    }
    return result;
}

// 사용 예시
const hexString = "0x00000000000000000000000068cb00e1f06798b7531a87c8e08cd41702ce9c020000000000000000000000000000000000000000000000000000000000000000";
console.log(hexDataToText(hexString)); // 텍스트 배열로 출력