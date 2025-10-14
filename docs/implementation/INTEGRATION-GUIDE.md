# Integration Guide

## Integrating GROKME Protocol into Your Application

This guide shows how to integrate GROKME Protocol into your frontend application.

---

## Prerequisites

- Node.js 18+
- Ethereum wallet integration (RainbowKit, WalletConnect, etc.)
- IPFS upload capability (Pinata, NFT.Storage, or self-hosted)
- Basic understanding of Web3/ethers.js

---

## Step 1: Install Dependencies

```bash
npm install ethers wagmi viem
npm install @rainbow-me/rainbowkit  # Or your preferred wallet library
npm install ipfs-http-client         # For IPFS upload
```

---

## Step 2: Contract ABIs

Create `abis/GROK.json`:
```json
[
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function balanceOf(address account) external view returns (uint256)",
  "function decimals() external view returns (uint8)",
  "function allowance(address owner, address spender) external view returns (uint256)"
]
```

Create `abis/GrokMeGenesis.json`:
```json
[
  "function grokMeWithSignedId(uint256 tokenId, string memory ipfsURI, uint256 contentSizeBytes, uint256 burnRatePerKB, uint256 nonce, uint256 validUntil, bytes memory signature, bytes32 burnTx) external returns (uint256)",
  "function isCapsuleOpen() external view returns (bool)",
  "function getRemainingCapacity() external view returns (uint256)",
  "function getCompletionPercentage() external view returns (uint256)",
  "function totalGrokBurned() external view returns (uint256)",
  "function totalBytesMinted() external view returns (uint256)"
]
```

---

## Step 3: Configure Contracts

```typescript
// config/contracts.ts
export const CONTRACTS = {
  GROK_TOKEN: {
    address: '0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5',
    decimals: 9
  },
  GROKME_GENESIS: {
    address: '0x...',  // Deployed Genesis contract address
    maxCapacity: 6_900_000_000,  // 6.9 GB
    minBurnRate: 1,
    maxBurnRate: 1000
  }
} as const;
```

---

## Step 4: Upload to IPFS

```typescript
// lib/ipfs.ts
import { create } from 'ipfs-http-client';

const ipfs = create({
  host: 'ipfs.infura.io',
  port: 5001,
  protocol: 'https'
});

export async function uploadToIPFS(file: File): Promise<{
  cid: string;
  size: number;
}> {
  const result = await ipfs.add(file);
  return {
    cid: result.path,
    size: result.size
  };
}
```

---

## Step 5: Request Oracle Signature

```typescript
// lib/oracle.ts
export async function requestTokenId(params: {
  address: string;
  burnRate: number;
  contentSize: number;
}): Promise<{
  tokenId: number;
  nonce: number;
  validUntil: number;
  signature: string;
}> {
  const response = await fetch('/api/oracle/request-token-id', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(params)
  });
  
  if (!response.ok) {
    throw new Error('Failed to get oracle signature');
  }
  
  return response.json();
}
```

---

## Step 6: Calculate Burn Amount

```typescript
// lib/calculations.ts
import { CONTRACTS } from '@/config/contracts';

export function calculateBurnAmount(
  fileSizeBytes: number,
  burnRatePerKB: number
): bigint {
  // Round up to nearest KB
  const sizeKB = Math.ceil(fileSizeBytes / 1024);
  
  // Calculate GROK amount
  const grokAmount = sizeKB * burnRatePerKB;
  
  // Convert to wei (9 decimals)
  return BigInt(grokAmount) * BigInt(10 ** CONTRACTS.GROK_TOKEN.decimals);
}
```

---

## Step 7: Mint NFT Flow

```typescript
// hooks/useMintNFT.ts
import { useAccount, usePublicClient, useWalletClient } from 'wagmi';
import { parseUnits } from 'viem';
import GROK_ABI from '@/abis/GROK.json';
import GENESIS_ABI from '@/abis/GrokMeGenesis.json';
import { CONTRACTS } from '@/config/contracts';

export function useMintNFT() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  
  async function mint(params: {
    file: File;
    burnRate: number;
  }) {
    if (!address || !walletClient) throw new Error('Wallet not connected');
    
    // 1. Upload to IPFS
    const { cid, size } = await uploadToIPFS(params.file);
    const ipfsURI = `ipfs://${cid}`;
    
    // 2. Calculate burn amount
    const burnAmount = calculateBurnAmount(size, params.burnRate);
    
    // 3. Request oracle signature
    const oracleData = await requestTokenId({
      address,
      burnRate: params.burnRate,
      contentSize: size
    });
    
    // 4. Check current allowance
    const currentAllowance = await publicClient.readContract({
      address: CONTRACTS.GROK_TOKEN.address,
      abi: GROK_ABI,
      functionName: 'allowance',
      args: [address, CONTRACTS.GROKME_GENESIS.address]
    });
    
    // 5. Approve GROK if needed
    if (currentAllowance < burnAmount) {
      const approveTx = await walletClient.writeContract({
        address: CONTRACTS.GROK_TOKEN.address,
        abi: GROK_ABI,
        functionName: 'approve',
        args: [CONTRACTS.GROKME_GENESIS.address, burnAmount]
      });
      
      await publicClient.waitForTransactionReceipt({ hash: approveTx });
    }
    
    // 6. Mint NFT
    const mintTx = await walletClient.writeContract({
      address: CONTRACTS.GROKME_GENESIS.address,
      abi: GENESIS_ABI,
      functionName: 'grokMeWithSignedId',
      args: [
        oracleData.tokenId,
        ipfsURI,
        size,
        params.burnRate,
        oracleData.nonce,
        oracleData.validUntil,
        oracleData.signature,
        '0x0000000000000000000000000000000000000000000000000000000000000000'
      ]
    });
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash: mintTx });
    
    return {
      tokenId: oracleData.tokenId,
      txHash: receipt.transactionHash,
      ipfsURI
    };
  }
  
  return { mint };
}
```

---

## Step 8: UI Component

```typescript
// components/MintForm.tsx
'use client';

import { useState } from 'react';
import { useMintNFT } from '@/hooks/useMintNFT';

export function MintForm() {
  const [file, setFile] = useState<File | null>(null);
  const [burnRate, setBurnRate] = useState(100);
  const { mint } = useMintNFT();
  
  async function handleMint() {
    if (!file) return;
    
    try {
      const result = await mint({ file, burnRate });
      console.log('Minted!', result);
    } catch (error) {
      console.error('Mint failed:', error);
    }
  }
  
  return (
    <div>
      <input
        type="file"
        onChange={(e) => setFile(e.target.files?.[0] || null)}
      />
      
      <label>
        Burn Rate (GROK/KB): {burnRate}
        <input
          type="range"
          min="1"
          max="1000"
          value={burnRate}
          onChange={(e) => setBurnRate(Number(e.target.value))}
        />
      </label>
      
      {file && (
        <div>
          <p>File: {file.name}</p>
          <p>Size: {Math.ceil(file.size / 1024)} KB</p>
          <p>Cost: {Math.ceil(file.size / 1024) * burnRate} GROK</p>
        </div>
      )}
      
      <button onClick={handleMint} disabled={!file}>
        Mint NFT
      </button>
    </div>
  );
}
```

---

## Step 9: Backend Oracle (Example)

```typescript
// api/oracle/request-token-id/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { ethers } from 'ethers';

const ORACLE_PRIVATE_KEY = process.env.ORACLE_PRIVATE_KEY!;
const CONTRACT_ADDRESS = process.env.GENESIS_CONTRACT_ADDRESS!;

export async function POST(req: NextRequest) {
  const { address, burnRate, contentSize } = await req.json();
  
  // Generate random token ID
  const tokenId = Math.floor(Math.random() * 1000000);
  
  // Create nonce
  const nonce = Date.now();
  
  // Valid for 5 minutes
  const validUntil = Math.floor(Date.now() / 1000) + 300;
  
  // EIP-712 domain
  const domain = {
    name: 'GrokMeGenesis',
    version: '1',
    chainId: 1,
    verifyingContract: CONTRACT_ADDRESS
  };
  
  // EIP-712 types
  const types = {
    TokenIdAssignment: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'burnRatePerKB', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'userAddress', type: 'address' },
      { name: 'validUntil', type: 'uint256' }
    ]
  };
  
  // Message to sign
  const value = {
    tokenId,
    burnRatePerKB: burnRate,
    nonce,
    userAddress: address,
    validUntil
  };
  
  // Sign
  const wallet = new ethers.Wallet(ORACLE_PRIVATE_KEY);
  const signature = await wallet.signTypedData(domain, types, value);
  
  return NextResponse.json({
    tokenId,
    nonce,
    validUntil,
    signature
  });
}
```

---

## Step 10: Testing

```typescript
// Test on Sepolia first!
const SEPOLIA_CONTRACTS = {
  GROK_TOKEN: '0x...',  // Testnet GROK
  GROKME_GENESIS: '0x...'  // Testnet Genesis
};

// Use small test files
const testFile = new File(['Hello GROKME'], 'test.txt', { type: 'text/plain' });

// Use low burn rate for testing
const testBurnRate = 10;

// Monitor transaction
console.log('Mint tx:', await mint({ file: testFile, burnRate: testBurnRate }));
```

---

## Security Checklist

- [ ] Never expose oracle private key
- [ ] Validate file size before upload
- [ ] Check GROK balance before minting
- [ ] Verify signature expiration
- [ ] Handle transaction failures gracefully
- [ ] Show gas estimates to users
- [ ] Implement retry logic for IPFS uploads
- [ ] Sanitize user inputs
- [ ] Rate-limit oracle requests
- [ ] Monitor for suspicious activity

---

## Common Issues

### Issue: "Nonce already used"
**Solution:** Oracle must generate unique nonces (timestamp + random).

### Issue: "Signature expired"
**Solution:** Reduce time between oracle request and mint transaction.

### Issue: "GROK burn failed"
**Solution:** Check user has sufficient GROK balance and approval.

### Issue: "Capsule sealed"
**Solution:** Check `isCapsuleOpen()` before attempting mint.

---

## Next Steps

- Review [API Reference](./API-REFERENCE.md) for complete function list
- See [Whitelabel Guide](./WHITELABEL-GUIDE.md) to deploy your own capsule
- Check [Security Model](../security/SECURITY-MODEL.md) for best practices

---

**Complete integration in production. Test thoroughly on testnet first.**

