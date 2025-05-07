# woorepie-solidity


## Issue 성공 및 amoy.polygonscan에서 트랜잭션 확인

![image](https://github.com/user-attachments/assets/999f6cc2-80ac-4767-a633-5819dcc247c9)

```
//Issue 발행량 대조
    const amount = parseUnits("1000", 18); // decimal = 18
    const data = "0x";
    const tx = await token.issue(receiver, amount, data);
    const receipt = await tx.wait();
  
```

## Token Transfer 전송

![image](https://github.com/user-attachments/assets/92717a1f-76f8-4010-8676-14b28b4fa2da)
