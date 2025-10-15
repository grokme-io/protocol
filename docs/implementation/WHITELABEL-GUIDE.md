# Whitelabel Guide

## Launch Your Own GROKME Capsule

This guide shows how to deploy your own capsule using the GROKME Protocol.

---

## What You Can Build

Build your own cultural preservation platform using GROKME Protocol standards.

**Examples:**
- Art preservation platform
- Gaming moments archive
- Music culture capsule
- Historical documents vault
- Community-specific archive

**Important:** GrokMeGenesis is the dedicated contract for grokme.me (meme preservation). You build YOUR OWN contract using the protocol templates.

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

## Step 2: Build Your Contract

### 2.1 Use Protocol Templates

GROKME Protocol provides contract templates in [`/contracts/templates/`](../../contracts/templates/):

**Required Core Modules:**
- Core Burn Mechanism (100% to 0x000...dEaD)
- Self-Sealing Logic (capacity-based finality)
- Post-Human Design (renounced ownership)

**Optional Enhancement Modules:**
- Variable Burn Rates
- Oracle System (anti-front-running)
- Batch Minting
- Burn TX Tracking
- Custom Metadata

See [`/contracts/templates/README.md`](../../contracts/templates/README.md) for complete baukasten documentation.

### 2.2 Build Your Contract

Assemble your own contract from protocol modules:

```solidity
import "./modules/CoreBurn.sol";
import "./modules/SelfSealing.sol";
import "./modules/VariableBurnRates.sol";

contract YourCapsule is 
    ERC721URIStorage,
    CoreBurn,
    SelfSealing,
    VariableBurnRates 
{
    constructor(address _oracle) 
        ERC721("YOUR CAPSULE", "SYMBOL")
    {
        // Initialize modules
    }
}
```

**You handle:**
- Module selection
- Contract assembly
- Deployment (Sepolia + Mainnet)
- Etherscan verification
- Ownership renouncement

**Protocol provides:**
- Open source templates (free)
- Documentation (free)
- Automatic verification (free)
- GROKME Certified badge (free)
- Community support (GitHub)

**No permission. No registration. No fees.**

### 2.4 Name & Symbol

```solidity
constructor(address _oracle) 
    ERC721("Your Capsule Name", "SYMBOL")
    EIP712("YourCapsuleName", "1")
{
    // ...
}
```

### 2.5 Module Selection

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
- Easy setup, managed service

**Option B: IPFS Cluster**
- Self-hosted, full control
- Use templates from `/infrastructure/ipfs-cluster/`

**Option C: Akash Deployment**
- Decentralized hosting
- Use templates from `/infrastructure/akash/`

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
- Infrastructure maintenance
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

### Protocol Resources (Free)

- Contract templates: `/contracts/templates/`
- Infrastructure: `/infrastructure/`
- Integration guide: `./INTEGRATION-GUIDE.md`
- Security model: `../security/SECURITY-MODEL.md`
- GitHub Discussions
- Community documentation

### Development Assistance (Paid)

**Important:** The protocol does not provide development services.

Independent developers are available who can help with:
- ✅ Contract development & assembly
- ✅ Implementation architecture
- ✅ Ensuring certification compliance
- ✅ Infrastructure setup
- ✅ Launch support

**Contact:** mail@grokme.io

**Note:** These are independent contractors, not protocol team. Services are paid separately.

---

**Launch your capsule. Preserve your culture. Join the protocol.**

**No permission needed. Pure mathematics.**

