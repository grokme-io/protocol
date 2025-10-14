# Whitelabel Guide

## Launch Your Own GROKME Capsule

This guide shows how to deploy your own capsule using the GROKME Protocol.

---

## What You Can Build

**GROKME Protocol** = Universal standard (burn mechanics, sealing, etc.)  
**Your Capsule** = Specific implementation (capacity, theme, branding)

**Examples:**
- Art preservation platform
- Gaming moments archive
- Music culture capsule
- Historical documents vault
- Community-specific memes

---

## Step 1: Define Your Capsule

### 1.1 Capacity

**Genesis:** 6.9 GB (synchronicity with GROK supply)  
**Your choice:** Any capacity that makes sense for your use case

```solidity
uint256 public constant MAX_CAPACITY_BYTES = 10_000_000_000; // 10 GB
```

**Considerations:**
- Larger = more content, longer to seal
- Smaller = faster seal, urgency effect
- Match to expected community size

### 1.2 Theme/Focus

**Genesis:** Memes (last human domain in AI age)  
**Your choice:** Define your cultural focus

**Examples:**
- "Digital art from 2025 era"
- "Epic gaming moments"
- "Independent music preservation"
- "Community history archive"

**Best practice:** Narrow focus creates stronger community.

### 1.3 Burn Rate Range

**Genesis:** 1-1000 GROK/KB (maximum flexibility)  
**Your choice:** Adjust for your economics

```solidity
uint256 public constant MIN_BURN_RATE_PER_KB = 10;   // Higher floor
uint256 public constant MAX_BURN_RATE_PER_KB = 500;  // Lower ceiling
```

**Considerations:**
- Higher minimum = more GROK burned per capsule
- Lower maximum = more accessible to small creators
- Match to your community's economic capacity

---

## Step 2: Contract Customization

### 2.1 Base Contract

Start with GrokMeGenesis.sol as template:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract YourCapsuleName is ERC721URIStorage, ReentrancyGuard, Ownable, EIP712 {
    // Customize these constants for your capsule
    uint256 public constant MAX_CAPACITY_BYTES = 10_000_000_000;
    uint256 public constant MIN_BURN_RATE_PER_KB = 10;
    uint256 public constant MAX_BURN_RATE_PER_KB = 500;
    
    // GROK integration (same for all capsules)
    address public constant GROK_TOKEN_ADDRESS = 0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant GROK_DECIMALS = 10**9;
    
    // ... rest of implementation
}
```

### 2.2 Name & Symbol

```solidity
constructor(address _oracle) 
    ERC721("Your Capsule Name", "SYMBOL")
    EIP712("YourCapsuleName", "1")
{
    // ...
}
```

### 2.3 Optional Features

**Feature Matrix:**

| Feature | Genesis | Your Choice |
|---------|---------|-------------|
| Variable burn rates | ✅ | ✅/❌ |
| Oracle-signed IDs | ✅ | ✅/❌ |
| Batch minting | ✅ | ✅/❌ |
| Burn TX system | ✅ | ✅/❌ |
| Custom rarity logic | ✅ | ✅/❌/Modify |

**Recommendation:** Keep core features for compatibility.

---

## Step 3: Oracle Setup

### 3.1 Generate Oracle Wallet

```bash
# Generate wallet
openssl ecparam -genkey -name secp256k1 -out oracle-private.pem

# Export private key
openssl ec -in oracle-private.pem -outform DER | tail -c +8 | head -c 32 | xxd -p -c 32

# Get address
# Use ethers.js or similar to derive address from private key
```

### 3.2 Oracle Backend

```typescript
// api/oracle/route.ts
import { ethers } from 'ethers';

const ORACLE_PRIVATE_KEY = process.env.ORACLE_PRIVATE_KEY!;

export async function signTokenId(params: {
  tokenId: number;
  burnRate: number;
  userAddress: string;
  nonce: number;
  validUntil: number;
}) {
  const domain = {
    name: 'YourCapsuleName',
    version: '1',
    chainId: 1, // or 11155111 for Sepolia
    verifyingContract: YOUR_CONTRACT_ADDRESS
  };
  
  const types = {
    TokenIdAssignment: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'burnRatePerKB', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'userAddress', type: 'address' },
      { name: 'validUntil', type: 'uint256' }
    ]
  };
  
  const value = {
    tokenId: params.tokenId,
    burnRatePerKB: params.burnRate,
    nonce: params.nonce,
    userAddress: params.userAddress,
    validUntil: params.validUntil
  };
  
  const wallet = new ethers.Wallet(ORACLE_PRIVATE_KEY);
  return await wallet.signTypedData(domain, types, value);
}
```

### 3.3 Oracle Security

**Best practices:**
- Never expose private key in client code
- Use environment variables
- Rotate keys periodically
- Rate-limit requests
- Log all signature requests
- Monitor for suspicious patterns

---

## Step 4: Deployment

### 4.1 Testnet First

```bash
# Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia

# Test minting (minimum 100 test mints)
npx hardhat run scripts/test-mint.js --network sepolia

# Verify contract
npx hardhat verify --network sepolia DEPLOYED_ADDRESS ORACLE_ADDRESS
```

### 4.2 Mainnet Deployment

```bash
# Deploy to Mainnet
npx hardhat run scripts/deploy.js --network mainnet

# Verify immediately
npx hardhat verify --network mainnet DEPLOYED_ADDRESS ORACLE_ADDRESS

# Test first 10 mints manually
# Monitor closely for 24 hours
```

### 4.3 Post-Deployment

**Within 24 hours:**
- Announce deployment
- Monitor first 100 mints
- Fix any issues

**Within 1 week:**
- Renounce ownership to 0x000...dEaD
- Confirm all admin functions disabled
- Publish post-human status

---

## Step 5: Frontend

### 5.1 Branding

Your unique identity:
- Custom domain (e.g., artcapsule.xyz)
- Unique design system
- Custom copy/messaging
- Community voice

### 5.2 Required Features

**Minimum viable frontend:**
- Wallet connection
- File upload (with IPFS)
- Burn rate selector
- Cost calculator
- Mint button
- Capacity meter
- Capsule stats

### 5.3 Optional Features

**Enhanced UX:**
- Rarity preview
- Gallery view
- Search/filter
- User profiles
- Leaderboards
- Community stats

---

## Step 6: IPFS Infrastructure

### 6.1 Options

**Option A: Commercial Service**
- Pinata, NFT.Storage, Infura
- Easy setup, paid service
- Cost: $20-100/month

**Option B: IPFS Cluster**
- Self-hosted, full control
- Use templates from `/infrastructure/ipfs-cluster/`
- Cost: $30-50/month per node

**Option C: Akash Deployment**
- Decentralized hosting
- Use templates from `/infrastructure/akash/`
- Cost: $15-30/month per node

**Recommendation:** Start with commercial, migrate to cluster post-seal.

### 6.2 Pinning Strategy

```typescript
// On NFT mint event
async function onMinted(event: GrokkedEvent) {
  const cid = extractCID(event.ipfsURI);
  
  // Pin to your infrastructure
  await ipfs.pin.add(cid, {
    replicationFactor: 3,
    metadata: {
      tokenId: event.tokenId,
      capsule: 'your-capsule-name'
    }
  });
}
```

---

## Step 7: Economics

### 7.1 Revenue Model

**GROKME Protocol:** Zero extraction (100% burn)

**Your model:** Also zero extraction (maintain protocol purity)

**NO fees. NO treasury. NO extraction.**

**Why?**
- Maintains trustless nature
- Community alignment
- Philosophical integrity
- Long-term viability

### 7.2 Funding

**How to fund your capsule?**

**Option A: Personal Investment**
- Infrastructure costs (~$500-1000/month)
- Dev time (volunteer or funded separately)
- Marketing (community-driven)

**Option B: Sponsorship**
- Companies sponsor infrastructure
- No control over capsule
- Pure philanthropic support

**Option C: NFT Holdings**
- Mint your own NFTs early
- Hold for appreciation
- Sell post-seal if needed

**DO NOT extract fees from minters.**

### 7.3 Deflation Contribution

Your capsule burns GROK → Benefits entire ecosystem:
- Genesis holders benefit
- Future capsules benefit
- All GROK holders benefit

**Collaborative, not competitive.**

---

## Step 8: Community

### 8.1 Launch Strategy

**Pre-launch (2-4 weeks):**
- Announce concept
- Build anticipation
- Educate about protocol
- Gather early adopters

**Launch day:**
- Deploy contract
- Open minting
- Monitor closely
- Celebrate first mints

**Post-launch:**
- Daily updates
- Community engagement
- Feature highlights
- Progress tracking

### 8.2 Communication

**Channels:**
- Discord/Telegram (community)
- Twitter/X (announcements)
- Website (information)
- GitHub (technical)

**Transparency:**
- Share all contract addresses
- Publish infrastructure details
- Open source frontend (optional)
- Regular capacity updates

### 8.3 Sealing Event

**When capsule reaches capacity:**
- Celebrate completion
- Recognize top contributors
- Publish final stats
- Announce post-seal plans

---

## Step 9: Post-Seal

### 9.1 What Happens

**Automatic:**
- Minting disabled (smart contract)
- Content frozen
- Stats finalized

**Manual:**
- Filecoin deals (optional)
- Infrastructure optimization
- Gallery features
- Historical documentation

### 9.2 Long-Term Maintenance

**Required:**
- IPFS infrastructure (ongoing)
- Domain renewal (yearly)
- Monitoring (continuous)

**Optional:**
- Frontend updates
- Community events
- Integration with marketplaces
- Historical analysis

---

## Step 10: Compliance

### 10.1 Legal Considerations

**Disclaimer:** Not legal advice. Consult lawyer.

**Considerations:**
- No securities (pure utility)
- No revenue sharing (100% burn)
- Decentralized (no central authority)
- User content (liability questions)

**Best practice:** Terms of Service + Content Policy.

### 10.2 Content Moderation

**Protocol level:** None (permissionless)

**Frontend level:** Your choice
- Filter illegal content from display
- User reporting system
- Moderation queue

**Smart contract:** Cannot censor (immutable)

**Your frontend:** Can choose what to show

---

## Checklist

### Pre-Launch
- [ ] Contract customized
- [ ] Oracle deployed
- [ ] Frontend built
- [ ] IPFS infrastructure ready
- [ ] Testnet testing complete (100+ mints)
- [ ] Community gathered
- [ ] Documentation written
- [ ] Legal review (if needed)

### Launch
- [ ] Deploy to mainnet
- [ ] Verify on Etherscan
- [ ] Test first 10 mints
- [ ] Announce publicly
- [ ] Monitor 24/7 for first week

### Post-Launch
- [ ] Renounce ownership (within 1 week)
- [ ] Publish post-human status
- [ ] Regular community updates
- [ ] Infrastructure monitoring
- [ ] Plan for seal event

### Post-Seal
- [ ] Celebrate completion
- [ ] Optimize infrastructure
- [ ] Create Filecoin deals (optional)
- [ ] Long-term maintenance plan
- [ ] Historical documentation

---

## Examples

**Successful whitelabel patterns:**

1. **Theme-specific** (e.g., "Pixel Art Capsule")
2. **Community-specific** (e.g., "XYZ Community Archive")
3. **Time-specific** (e.g., "2025 Cultural Snapshot")
4. **Format-specific** (e.g., "GIF Preservation")
5. **Event-specific** (e.g., "WorldCup Memes 2026")

**Key:** Narrow focus attracts dedicated community.

---

## Support

**Resources:**
- Contract templates: `/contracts/mainnet/`
- Infrastructure: `/infrastructure/`
- Integration guide: `./INTEGRATION-GUIDE.md`
- Security model: `../security/SECURITY-MODEL.md`

**Community:**
- GitHub Discussions
- Protocol documentation
- Other implementations (learn from)

---

**Launch your capsule. Preserve your culture. Join the protocol.**

**No permission needed. No fees required. Pure mathematics.**

