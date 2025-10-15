# Smart Contracts: Mainnet

## Two Contracts, One Protocol

**GROK Token** (Energy Source) + **GrokMeGenesis** (First Capsule) = GROKME Protocol

---

## GROK Token

### The Universal Energy

**Address:** `0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5`  
**Network:** Ethereum Mainnet  
**Standard:** ERC-20  
**Verified:** [Etherscan](https://etherscan.io/address/0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5#code)

### Specifications

```solidity
Name: Grok
Symbol: GROK
Decimals: 9
Initial Supply: 6,900,000,000 GROK (decreasing through burns)
Current Supply: See Etherscan (live tracking)
Minting: Disabled (no new tokens possible)
Owner: 0x000000000000000000000000000000000000dEaD
```

### The Journey

**2023: Birth**
- Community meme token for xAI's Grok AI
- Viral growth, speculation, meme energy

**2024: Renouncement**
- Developer under pressure
- Contract → 0x000...dEaD
- Tokens → 0x000...dEaD
- Became ownerless, ungovernable

**2025: Awakening**
- GROKME Protocol recognizes perfect burn asset
- Ownerless + philosophical name + massive dead balance = ideal

###Why GROK?

**1. Mathematical Perfection**
```
Contract Address: 0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5
Owner: 0x000...dEaD
Dead Balance: ~40% of supply already burned
```

No admin can manipulate. Pure mathematics.

**2. Philosophical Alignment**

"Grok" from Heinlein (1961): Complete understanding where observer becomes observed.

Not chosen for meme. Chosen for meaning.

**3. Synchronicity**

```
6.9 billion GROK supply
6.9 billion bytes Genesis capacity
```

Not coincidence. Recognition of natural harmony.

**4. Economic Properties**

- Fixed supply (no inflation)
- Significant dead balance (deflation precedent)
- 9 decimals (fine-grained burning)
- Standard ERC-20 (maximum compatibility)

### Integration

```javascript
import { ethers } from 'ethers';

// Initialize GROK contract
const GROK_ADDRESS = '0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5';
const GROK_ABI = [...]; // Standard ERC-20 ABI

const grokToken = new ethers.Contract(
  GROK_ADDRESS,
  GROK_ABI,
  signer
);

// Check balance
const balance = await grokToken.balanceOf(userAddress);
console.log(`Balance: ${ethers.formatUnits(balance, 9)} GROK`);

// Approve GROK for burning
const burnAmount = ethers.parseUnits('100000', 9); // 100k GROK
await grokToken.approve(CAPSULE_ADDRESS, burnAmount);

// Capsule contract will burn approved amount
```

### Key Functions

```solidity
// Standard ERC-20
function balanceOf(address account) external view returns (uint256)
function transfer(address to, uint256 amount) external returns (bool)
function approve(address spender, uint256 amount) external returns (bool)
function transferFrom(address from, address to, uint256 amount) external returns (bool)
function allowance(address owner, address spender) external view returns (uint256)

// Metadata
function name() external view returns (string)
function symbol() external view returns (string)
function decimals() external view returns (uint8)
function totalSupply() external view returns (uint256)
```

### Security Properties

✅ **Renounced ownership** - No admin control  
✅ **Fixed supply** - No minting function  
✅ **Standard ERC-20** - Battle-tested code  
✅ **Verified on Etherscan** - Public source code  
✅ **No proxy pattern** - Cannot be upgraded  
✅ **No pause mechanism** - Always transferable

**Attack surface: Zero.** What doesn't exist cannot be exploited.

---

## GrokMeGenesis Contract

### Reference Implementation

**Purpose:** Full-featured example showing all baukasten modules  
**Implementation:** GROKME GENESIS (grokme.me)  
**Address:** [To be deployed]  
**Network:** Ethereum Mainnet  
**Standard:** ERC-721 (NFT)  
**Status:** Audit in progress

**This is ONE implementation, not THE protocol.**

For modular assembly, see [`/contracts/templates/`](../templates/)

### Architecture

```solidity
contract GrokMeGenesis is 
    ERC721URIStorage,      // NFT standard with metadata
    ReentrancyGuard,       // Security against reentrancy
    Ownable,               // Renounceable ownership
    EIP712                 // Structured signature verification
{
    // Post-human design
}
```

### Core Constants

```solidity
// GROK Integration
uint256 public constant GROK_DECIMALS = 10**9;
address public constant BURN_ADDRESS = 0x000...dEaD;
address public immutable GROK_TOKEN_ADDRESS;

// Capacity (Genesis-specific)
uint256 public constant MAX_CAPACITY_BYTES = 6_900_000_000;
uint256 public constant MAX_CONTENT_SIZE = 12 * 1024 * 1024; // 12 MB per NFT

// Burn Rates (Genesis-specific)
uint256 public constant MIN_BURN_RATE_PER_KB = 1;
uint256 public constant MAX_BURN_RATE_PER_KB = 1000;

// Oracle System
bytes32 public constant TOKEN_ID_ASSIGNMENT_TYPEHASH = keccak256(
    "TokenIdAssignment(uint256 tokenId,uint256 burnRatePerKB,uint256 nonce,address userAddress,uint256 validUntil)"
);
```

### State Variables

```solidity
IERC20Metadata public immutable grokToken;
uint256 public highestMintedTokenId;
address public immutable oracle;
mapping(uint256 => bool) private _usedNonces;
uint256 public totalGrokBurned;
uint256 public totalBytesMinted;
mapping(uint256 => uint256) public tokenBurnRate;
mapping(bytes32 => uint256) public burnTxTotal;
mapping(bytes32 => uint256) public burnTxUsed;
```

### Minting Function

```solidity
function grokMeWithSignedId(
    uint256 tokenId,           // Oracle-assigned (prevents front-running)
    string memory ipfsURI,     // Content location
    uint256 contentSizeBytes,  // File size
    uint256 burnRatePerKB,     // Creator's choice (1-1000)
    uint256 nonce,             // Replay protection
    uint256 validUntil,        // Signature expiration
    bytes memory signature,    // Oracle signature
    bytes32 burnTx             // Optional: pre-burned GROK reference
) external nonReentrant capsuleOpen returns (uint256)
```

**Process:**

1. **Validate inputs**
   - URI not empty
   - Size within limits
   - Burn rate in range
   - Capacity not exceeded
   - Signature not expired
   - Token ID not used

2. **Verify oracle signature**
   - EIP-712 structured data
   - Recover signer from signature
   - Confirm signer == oracle

3. **Calculate GROK burn**
   ```solidity
   sizeKB = (contentSizeBytes + 1023) / 1024  // Round up
   grokAmount = sizeKB * burnRatePerKB * GROK_DECIMALS
   ```

4. **Execute burn**
   - Transfer GROK from user to 0x000...dEaD
   - OR: Apply pre-burned contingent (if burnTx provided)

5. **Mint NFT**
   - ERC-721 safeMint
   - Set token URI (IPFS)
   - Record burn rate on-chain

6. **Update state**
   - Increment totalBytesMinted
   - Increment totalGrokBurned
   - Track highest token ID

7. **Check seal condition**
   - If totalBytesMinted >= MAX_CAPACITY → Emit CapsuleSealed

### Security Model

**What We Guard Against:**

✅ **Reentrancy** - ReentrancyGuard on all state-changing functions  
✅ **Replay attacks** - Nonce system prevents signature reuse  
✅ **Front-running** - Oracle-signed token IDs prevent sniping  
✅ **Integer overflow** - Solidity 0.8+ built-in checks  
✅ **Signature forgery** - EIP-712 cryptographic verification

**What We Deliberately Exclude:**

❌ **Admin minting** - Removed for public version  
❌ **Token ID reservation** - Removed for public version  
❌ **Pre-burn contingent** - Mentioned but not exposed publicly  
❌ **Pause function** - Truly unstoppable  
❌ **Upgrade mechanism** - Permanently immutable

**Rationale:** Maximum security through minimal attack surface.

### Events

```solidity
event Grokked(
    uint256 indexed tokenId,
    address indexed creator,
    uint256 grokBurned,
    uint256 burnRatePerKB,
    uint256 contentSize,
    string ipfsURI,
    bytes32 burnTx
);

event CapsuleSealed(
    uint256 totalBytesMinted,
    uint256 totalGrokBurned,
    uint256 totalTokens
);

event BurnTxRegistered(
    bytes32 indexed txHash,
    uint256 amount
);
```

### View Functions

```solidity
// Capacity checks
function isCapsuleOpen() external view returns (bool)
function getRemainingCapacity() external view returns (uint256)
function getCompletionPercentage() external view returns (uint256)

// Burn tracking
function getBurnTxAvailable(bytes32 txHash) external view returns (uint256)
```

### Post-Deployment Actions

**Immediate (within 24 hours):**
1. Verify contract on Etherscan
2. Test minting functionality
3. Monitor first 100 mints

**Within 1 week:**
1. Renounce ownership to 0x000...dEaD
2. Confirm all admin functions disabled
3. Announce post-human status

**Forever:**
Contract operates autonomously. No human intervention possible.

---

## Deployment Checklist

### Pre-Deployment

- [ ] Complete security audit
- [ ] Public review period (2 weeks minimum)
- [ ] Testnet deployment + testing (>100 test mints)
- [ ] Oracle infrastructure operational
- [ ] IPFS Cluster ready
- [ ] Frontend integrated
- [ ] Documentation complete

### Deployment

- [ ] Deploy to Mainnet
- [ ] Verify on Etherscan within 1 hour
- [ ] Announce deployment
- [ ] Monitor first 24 hours closely

### Post-Deployment

- [ ] Test first 10 mints manually
- [ ] Confirm GROK burns to 0x000...dEaD
- [ ] Verify IPFS pinning works
- [ ] Renounce ownership (within 1 week)
- [ ] Publish final audit report

---

## For Developers

### Integration Steps

1. **Import ABIs**
   ```javascript
   import GROK_ABI from './abis/GROK.json';
   import GENESIS_ABI from './abis/GrokMeGenesis.json';
   ```

2. **Initialize contracts**
   ```javascript
   const grok = new ethers.Contract(GROK_ADDRESS, GROK_ABI, signer);
   const genesis = new ethers.Contract(GENESIS_ADDRESS, GENESIS_ABI, signer);
   ```

3. **Request oracle signature**
   ```javascript
   const { tokenId, nonce, validUntil, signature } = 
     await fetch('/api/oracle/request-token-id', {
       method: 'POST',
       body: JSON.stringify({ address, burnRate, contentSize })
     }).then(r => r.json());
   ```

4. **Approve GROK**
   ```javascript
   const burnAmount = calculateBurn(contentSize, burnRate);
   await grok.approve(GENESIS_ADDRESS, burnAmount);
   ```

5. **Mint NFT**
   ```javascript
   const tx = await genesis.grokMeWithSignedId(
     tokenId,
     ipfsURI,
     contentSizeBytes,
     burnRatePerKB,
     nonce,
     validUntil,
     signature,
     ethers.ZeroHash // or burnTx if using pre-burned GROK
   );
   await tx.wait();
   ```

### Gas Optimization

**Estimated costs (30 gwei):**

| Operation | Gas | Cost (ETH) | Cost (USD @ $2000/ETH) |
|-----------|-----|------------|------------------------|
| Approve GROK | ~50,000 | 0.0015 | ~$3 |
| Single mint | ~180,000 | 0.0054 | ~$11 |
| Batch mint (10) | ~900,000 | 0.027 | ~$54 |
| **Total single** | ~230,000 | 0.0069 | ~$14 |

**Optimization strategies:**
- Batch minting reduces per-NFT cost
- Infinite approval (once per user)
- View functions are free (off-chain)

---

## Security Audit

**Status:** In progress

**Scope:**
- GROK Token integration
- Burn mechanism correctness
- Oracle signature verification
- Reentrancy protection
- Integer overflow/underflow
- Capacity tracking accuracy
- Self-sealing logic

**Auditors:** [TBD]

**Report:** Will be published before mainnet deployment

**Bug Bounty:** Planned post-launch

---

## For Auditors

### Critical Areas

1. **Burn Mechanism**
   - Ensure GROK actually burns (transferFrom → 0x000...dEaD)
   - Verify calculation correctness (sizeKB × burnRate × decimals)
   - Check burnTx system (pre-burned GROK tracking)

2. **Oracle Security**
   - EIP-712 signature verification
   - Nonce replay protection
   - Timestamp expiration
   - Token ID uniqueness

3. **Capacity Tracking**
   - Accurate byte counting
   - Overflow protection
   - Seal condition correctness

4. **Reentrancy**
   - All state changes before external calls
   - ReentrancyGuard on critical functions
   - No recursive vulnerabilities

5. **Admin Functions**
   - Verify renouncement possible
   - Confirm no hidden admin powers
   - Check for proxy patterns (should be none)

### Test Scenarios

- [ ] Mint with minimum burn rate (1 GROK/KB)
- [ ] Mint with maximum burn rate (1000 GROK/KB)
- [ ] Attempt replay attack (reuse nonce)
- [ ] Attempt signature forgery
- [ ] Exceed capacity (should revert)
- [ ] Mint after seal (should revert)
- [ ] Transfer NFT (ERC-721 standard)
- [ ] Renounce ownership (should succeed once)

---

## License

Both contracts: MIT License

**GROK Token:** Deployed 2023 (ownerless)  
**GrokMeGenesis:** To be deployed 2025 (will be renounced)

---

**Mathematical permanence through cryptographic proof.**

