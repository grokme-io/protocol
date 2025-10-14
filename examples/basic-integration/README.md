# Basic Integration Example

Complete minimal example for integrating GROKME Protocol.

---

## What's Included

- React + TypeScript components
- Wagmi + Viem for Web3
- IPFS upload helper
- Mint flow with approval
- Error handling

---

## Installation

```bash
npm install ethers wagmi viem @rainbow-me/rainbowkit ipfs-http-client
```

---

## Complete Example

### 1. Contract Configuration

```typescript
// config/contracts.ts
export const GROKME_CONFIG = {
  grokToken: {
    address: '0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5' as `0x${string}`,
    decimals: 9
  },
  genesis: {
    address: '0x...' as `0x${string}`,  // Replace with deployed address
    maxCapacity: 6_900_000_000
  }
} as const;

export const GROK_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function balanceOf(address account) external view returns (uint256)',
  'function allowance(address owner, address spender) external view returns (uint256)'
] as const;

export const GENESIS_ABI = [
  'function grokMeWithSignedId(uint256 tokenId, string memory ipfsURI, uint256 contentSizeBytes, uint256 burnRatePerKB, uint256 nonce, uint256 validUntil, bytes memory signature, bytes32 burnTx) external returns (uint256)',
  'function isCapsuleOpen() external view returns (bool)',
  'function getRemainingCapacity() external view returns (uint256)'
] as const;
```

### 2. IPFS Upload

```typescript
// lib/ipfs.ts
import { create } from 'ipfs-http-client';

const ipfs = create({
  host: 'ipfs.infura.io',
  port: 5001,
  protocol: 'https',
  headers: {
    authorization: `Basic ${Buffer.from(
      `${process.env.NEXT_PUBLIC_INFURA_PROJECT_ID}:${process.env.NEXT_PUBLIC_INFURA_API_SECRET}`
    ).toString('base64')}`
  }
});

export async function uploadFile(file: File): Promise<{
  cid: string;
  size: number;
}> {
  try {
    const added = await ipfs.add(file, {
      progress: (prog) => console.log(`Upload progress: ${prog}`)
    });
    
    return {
      cid: added.path,
      size: added.size
    };
  } catch (error) {
    console.error('IPFS upload failed:', error);
    throw new Error('Failed to upload to IPFS');
  }
}
```

### 3. Calculations

```typescript
// lib/calculations.ts
import { GROKME_CONFIG } from '@/config/contracts';

export function calculateBurnAmount(
  fileSizeBytes: number,
  burnRatePerKB: number
): bigint {
  const sizeKB = Math.ceil(fileSizeBytes / 1024);
  const grokAmount = sizeKB * burnRatePerKB;
  return BigInt(grokAmount) * BigInt(10 ** GROKME_CONFIG.grokToken.decimals);
}

export function formatGrok(amount: bigint): string {
  const decimals = GROKME_CONFIG.grokToken.decimals;
  const divisor = BigInt(10 ** decimals);
  const whole = amount / divisor;
  const fraction = amount % divisor;
  
  if (fraction === 0n) {
    return whole.toString();
  }
  
  const fractionStr = fraction.toString().padStart(decimals, '0');
  return `${whole}.${fractionStr.replace(/0+$/, '')}`;
}
```

### 4. Oracle API

```typescript
// lib/oracle.ts
export interface OracleResponse {
  tokenId: number;
  nonce: number;
  validUntil: number;
  signature: `0x${string}`;
}

export async function requestOracleSignature(params: {
  userAddress: string;
  burnRate: number;
  contentSize: number;
}): Promise<OracleResponse> {
  const response = await fetch('/api/oracle/request-signature', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(params)
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Oracle request failed: ${error}`);
  }
  
  return response.json();
}
```

### 5. Mint Hook

```typescript
// hooks/useMintNFT.ts
import { useState } from 'react';
import { useAccount, usePublicClient, useWalletClient } from 'wagmi';
import { GROKME_CONFIG, GROK_ABI, GENESIS_ABI } from '@/config/contracts';
import { uploadFile } from '@/lib/ipfs';
import { calculateBurnAmount } from '@/lib/calculations';
import { requestOracleSignature } from '@/lib/oracle';

export function useMintNFT() {
  const [status, setStatus] = useState<string>('');
  const [isLoading, setIsLoading] = useState(false);
  
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  
  async function mint(file: File, burnRate: number) {
    if (!address || !walletClient || !publicClient) {
      throw new Error('Wallet not connected');
    }
    
    setIsLoading(true);
    
    try {
      // Step 1: Upload to IPFS
      setStatus('Uploading to IPFS...');
      const { cid, size } = await uploadFile(file);
      const ipfsURI = `ipfs://${cid}`;
      
      // Step 2: Calculate burn amount
      const burnAmount = calculateBurnAmount(size, burnRate);
      
      // Step 3: Request oracle signature
      setStatus('Requesting signature...');
      const oracleData = await requestOracleSignature({
        userAddress: address,
        burnRate,
        contentSize: size
      });
      
      // Step 4: Check allowance
      setStatus('Checking GROK approval...');
      const currentAllowance = await publicClient.readContract({
        address: GROKME_CONFIG.grokToken.address,
        abi: GROK_ABI,
        functionName: 'allowance',
        args: [address, GROKME_CONFIG.genesis.address]
      });
      
      // Step 5: Approve if needed
      if (currentAllowance < burnAmount) {
        setStatus('Approving GROK...');
        const approveTx = await walletClient.writeContract({
          address: GROKME_CONFIG.grokToken.address,
          abi: GROK_ABI,
          functionName: 'approve',
          args: [GROKME_CONFIG.genesis.address, burnAmount]
        });
        
        await publicClient.waitForTransactionReceipt({ hash: approveTx });
      }
      
      // Step 6: Mint NFT
      setStatus('Minting NFT...');
      const mintTx = await walletClient.writeContract({
        address: GROKME_CONFIG.genesis.address,
        abi: GENESIS_ABI,
        functionName: 'grokMeWithSignedId',
        args: [
          BigInt(oracleData.tokenId),
          ipfsURI,
          BigInt(size),
          BigInt(burnRate),
          BigInt(oracleData.nonce),
          BigInt(oracleData.validUntil),
          oracleData.signature,
          '0x0000000000000000000000000000000000000000000000000000000000000000'
        ]
      });
      
      setStatus('Waiting for confirmation...');
      const receipt = await publicClient.waitForTransactionReceipt({ hash: mintTx });
      
      setStatus('Success!');
      
      return {
        tokenId: oracleData.tokenId,
        txHash: receipt.transactionHash,
        ipfsURI,
        cid
      };
    } catch (error) {
      console.error('Mint failed:', error);
      setStatus(`Error: ${(error as Error).message}`);
      throw error;
    } finally {
      setIsLoading(false);
    }
  }
  
  return { mint, status, isLoading };
}
```

### 6. UI Component

```typescript
// components/MintForm.tsx
'use client';

import { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { useMintNFT } from '@/hooks/useMintNFT';
import { calculateBurnAmount, formatGrok } from '@/lib/calculations';

export function MintForm() {
  const [file, setFile] = useState<File | null>(null);
  const [burnRate, setBurnRate] = useState(100);
  const [preview, setPreview] = useState<string | null>(null);
  
  const { address } = useAccount();
  const { mint, status, isLoading } = useMintNFT();
  
  // Create preview
  useEffect(() => {
    if (!file) {
      setPreview(null);
      return;
    }
    
    const reader = new FileReader();
    reader.onloadend = () => setPreview(reader.result as string);
    reader.readAsDataURL(file);
  }, [file]);
  
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    
    if (!file || !address) return;
    
    try {
      const result = await mint(file, burnRate);
      alert(`Minted Token #${result.tokenId}!\nTx: ${result.txHash}`);
      
      // Reset form
      setFile(null);
      setPreview(null);
    } catch (error) {
      alert(`Mint failed: ${(error as Error).message}`);
    }
  }
  
  const burnAmount = file ? calculateBurnAmount(file.size, burnRate) : 0n;
  const sizeKB = file ? Math.ceil(file.size / 1024) : 0;
  
  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {/* File Upload */}
      <div>
        <label className="block text-sm font-medium mb-2">
          Select File
        </label>
        <input
          type="file"
          accept="image/*"
          onChange={(e) => setFile(e.target.files?.[0] || null)}
          className="block w-full"
          disabled={isLoading}
        />
      </div>
      
      {/* Preview */}
      {preview && (
        <div>
          <img 
            src={preview} 
            alt="Preview" 
            className="max-w-xs rounded"
          />
        </div>
      )}
      
      {/* Burn Rate Slider */}
      <div>
        <label className="block text-sm font-medium mb-2">
          Burn Rate: {burnRate} GROK/KB
        </label>
        <input
          type="range"
          min="1"
          max="1000"
          value={burnRate}
          onChange={(e) => setBurnRate(Number(e.target.value))}
          className="w-full"
          disabled={isLoading}
        />
        <div className="flex justify-between text-xs text-gray-500">
          <span>Budget (1)</span>
          <span>Standard (100)</span>
          <span>Premium (500)</span>
          <span>Max (1000)</span>
        </div>
      </div>
      
      {/* Cost Summary */}
      {file && (
        <div className="bg-gray-100 dark:bg-gray-800 p-4 rounded space-y-1">
          <div className="flex justify-between">
            <span>File Size:</span>
            <span className="font-mono">{sizeKB} KB</span>
          </div>
          <div className="flex justify-between">
            <span>Burn Rate:</span>
            <span className="font-mono">{burnRate} GROK/KB</span>
          </div>
          <div className="flex justify-between font-bold text-lg">
            <span>Total Burn:</span>
            <span className="font-mono">{formatGrok(burnAmount)} GROK</span>
          </div>
        </div>
      )}
      
      {/* Status */}
      {status && (
        <div className="text-sm text-gray-600 dark:text-gray-400">
          {status}
        </div>
      )}
      
      {/* Submit */}
      <button
        type="submit"
        disabled={!file || !address || isLoading}
        className="w-full bg-blue-600 text-white py-2 px-4 rounded disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isLoading ? 'Minting...' : 'Mint NFT'}
      </button>
      
      {!address && (
        <p className="text-sm text-red-600">
          Please connect your wallet first
        </p>
      )}
    </form>
  );
}
```

### 7. Backend Oracle (Example)

```typescript
// app/api/oracle/request-signature/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { ethers } from 'ethers';

const ORACLE_PRIVATE_KEY = process.env.ORACLE_PRIVATE_KEY!;
const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_GENESIS_ADDRESS!;
const CHAIN_ID = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || '1');

export async function POST(req: NextRequest) {
  try {
    const { userAddress, burnRate, contentSize } = await req.json();
    
    // Validate inputs
    if (!ethers.isAddress(userAddress)) {
      return NextResponse.json(
        { error: 'Invalid address' },
        { status: 400 }
      );
    }
    
    if (burnRate < 1 || burnRate > 1000) {
      return NextResponse.json(
        { error: 'Invalid burn rate' },
        { status: 400 }
      );
    }
    
    // Generate random token ID
    const tokenId = Math.floor(Math.random() * 1000000);
    
    // Create unique nonce
    const nonce = Date.now() * 1000 + Math.floor(Math.random() * 1000);
    
    // Valid for 5 minutes
    const validUntil = Math.floor(Date.now() / 1000) + 300;
    
    // EIP-712 domain
    const domain = {
      name: 'GrokMeGenesis',
      version: '1',
      chainId: CHAIN_ID,
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
    
    // Message
    const value = {
      tokenId,
      burnRatePerKB: burnRate,
      nonce,
      userAddress,
      validUntil
    };
    
    // Sign
    const wallet = new ethers.Wallet(ORACLE_PRIVATE_KEY);
    const signature = await wallet.signTypedData(domain, types, value);
    
    // Log (for monitoring)
    console.log('Oracle signature issued:', {
      tokenId,
      userAddress,
      burnRate,
      timestamp: new Date().toISOString()
    });
    
    return NextResponse.json({
      tokenId,
      nonce,
      validUntil,
      signature
    });
  } catch (error) {
    console.error('Oracle error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

---

## Environment Setup

Create `.env.local`:
```bash
# Infura IPFS
NEXT_PUBLIC_INFURA_PROJECT_ID=your_project_id
NEXT_PUBLIC_INFURA_API_SECRET=your_api_secret

# Contract addresses
NEXT_PUBLIC_GENESIS_ADDRESS=0x...
NEXT_PUBLIC_CHAIN_ID=1

# Oracle (SERVER-SIDE ONLY)
ORACLE_PRIVATE_KEY=0x...
```

**⚠️ NEVER commit `.env.local` to git!**

---

## Testing

```bash
# 1. Start development server
npm run dev

# 2. Connect wallet (MetaMask)

# 3. Get test GROK
# - Testnet: Use faucet
# - Mainnet: Buy on DEX

# 4. Upload small file (e.g., 50 KB)

# 5. Set burn rate (start with 10)

# 6. Click "Mint NFT"

# 7. Approve GROK (if first time)

# 8. Confirm mint transaction

# 9. Check token on Etherscan
```

---

## Production Checklist

- [ ] Test on Sepolia with 100+ mints
- [ ] Verify oracle private key security
- [ ] Test error scenarios (insufficient GROK, expired signature, etc.)
- [ ] Implement rate limiting on oracle
- [ ] Add transaction monitoring
- [ ] Set up IPFS pinning automation
- [ ] Configure production RPC endpoints
- [ ] Add analytics/logging
- [ ] Test wallet compatibility (MetaMask, WalletConnect, Coinbase Wallet)
- [ ] Deploy to mainnet
- [ ] Monitor first 24 hours closely

---

## Next Steps

- Review [Integration Guide](../../docs/implementation/INTEGRATION-GUIDE.md)
- See [Whitelabel Guide](../../docs/implementation/WHITELABEL-GUIDE.md)
- Check [Security Model](../../docs/security/SECURITY-MODEL.md)

---

**This is a minimal example. Enhance with:**
- Better error handling
- Loading states
- Transaction history
- NFT gallery
- Rarity display
- User profiles

