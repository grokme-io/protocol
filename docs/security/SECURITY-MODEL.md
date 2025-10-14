# Security Model

## GROKME Protocol Security Architecture

Maximum security through minimal attack surface.

---

## Core Principle

```
What doesn't exist cannot be exploited.
```

GROKME achieves security not by defending features, but by not having features to defend.

---

## 1. Contract-Level Security

### 1.1 No Admin Functions

**Traditional contracts:**
```solidity
function pause() external onlyOwner { ... }
function setFee() external onlyOwner { ... }
function withdraw() external onlyOwner { ... }
function upgrade() external onlyOwner { ... }
```

**GROKME contracts:**
```solidity
// NONE OF THE ABOVE EXIST
```

**Attack surface:** Zero.

**Verification:**
```bash
# Search contract for admin functions
grep -i "onlyOwner\|onlyAdmin\|onlyRole" GrokMeGenesis.sol
# Result: Only in Ownable.sol (for renouncement)

# Verify ownership renounced
cast call $CONTRACT_ADDRESS "owner()(address)"
# Must return: 0x000000000000000000000000000000000000dEaD
```

### 1.2 No Proxy Pattern

**Proxy contracts allow upgrades:**
```solidity
// Dangerous: Can change implementation
contract Proxy {
    address implementation;
    function upgrade(address newImpl) external { ... }
}
```

**GROKME:**
```solidity
// Direct deployment, no proxy
contract GrokMeGenesis { ... }
```

**Immutable:** Contract code cannot change.

### 1.3 No Pause Mechanism

**Pausable contracts:**
```solidity
function pause() external onlyOwner {
    _paused = true;
}
```

**GROKME:**
```solidity
// No pause function exists
// Minting only stops at capacity (mathematical)
```

**Result:** Unstoppable until seal.

---

## 2. Reentrancy Protection

### 2.1 ReentrancyGuard

**All state-changing functions:**
```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GrokMeGenesis is ReentrancyGuard {
    function grokMeWithSignedId(...) 
        external 
        nonReentrant  // ← Protection
        capsuleOpen 
        returns (uint256) 
    {
        // State changes before external calls
        totalBytesMinted += contentSizeBytes;
        totalGrokBurned += grokAmount;
        
        // External calls come after
        _safeMint(msg.sender, tokenId);
    }
}
```

### 2.2 Checks-Effects-Interactions

**Pattern followed rigorously:**

```solidity
// 1. CHECKS
require(bytes(ipfsURI).length > 0, "Empty URI");
require(contentSizeBytes > 0, "Zero size");
require(!_usedNonces[nonce], "Nonce already used");

// 2. EFFECTS
_usedNonces[nonce] = true;
totalBytesMinted += contentSizeBytes;
totalGrokBurned += grokAmount;

// 3. INTERACTIONS
require(grokToken.transferFrom(...), "Burn failed");
_safeMint(msg.sender, tokenId);
```

**No state changes after external calls.**

---

## 3. Signature Security

### 3.1 EIP-712 Structured Data

**Why EIP-712?**
- Prevents signature replay across different contracts
- Domain separation (name, version, chainId, contract address)
- Human-readable signed data
- Wallet support (MetaMask, etc.)

**Implementation:**
```solidity
bytes32 public constant TOKEN_ID_ASSIGNMENT_TYPEHASH = keccak256(
    "TokenIdAssignment(uint256 tokenId,uint256 burnRatePerKB,uint256 nonce,address userAddress,uint256 validUntil)"
);

function grokMeWithSignedId(..., bytes memory signature) external {
    // Build struct hash
    bytes32 structHash = keccak256(abi.encode(
        TOKEN_ID_ASSIGNMENT_TYPEHASH,
        tokenId,
        burnRatePerKB,
        nonce,
        msg.sender,
        validUntil
    ));
    
    // Hash with domain
    bytes32 hash = _hashTypedDataV4(structHash);
    
    // Recover signer
    address signer = hash.recover(signature);
    
    // Verify
    require(signer == oracle, "Invalid signature");
}
```

### 3.2 Replay Protection

**Nonce system:**
```solidity
mapping(uint256 => bool) private _usedNonces;

require(!_usedNonces[nonce], "Nonce already used");
_usedNonces[nonce] = true;
```

**Each signature usable exactly once.**

### 3.3 Time Expiration

```solidity
require(block.timestamp <= validUntil, "Signature expired");
```

**Old signatures cannot be used.**

**Recommended validity:** 5-10 minutes.

---

## 4. Integer Safety

### 4.1 Solidity 0.8+ Automatic Checks

**Built-in overflow/underflow protection:**
```solidity
pragma solidity ^0.8.20;  // Automatic checks enabled

uint256 total = type(uint256).max;
total += 1;  // Reverts automatically (overflow)
```

**No SafeMath needed.**

### 4.2 Explicit Bounds Checking

```solidity
require(contentSizeBytes <= MAX_CONTENT_SIZE, "Content too large");
require(burnRatePerKB >= MIN_BURN_RATE_PER_KB, "Rate too low");
require(burnRatePerKB <= MAX_BURN_RATE_PER_KB, "Rate too high");
require(totalBytesMinted + contentSizeBytes <= MAX_CAPACITY_BYTES, "Exceeds capacity");
```

**All inputs validated.**

---

## 5. Oracle Security

### 5.1 Oracle Role

**What oracle does:**
- Assigns random token IDs (prevents front-running)
- Signs assignments with EIP-712
- Validates burn rates

**What oracle does NOT do:**
- Control minting (users mint)
- Hold funds (no treasury)
- Determine rarity (on-chain calculation)
- Censor content (permissionless protocol)

### 5.2 Oracle Compromise Scenarios

**If oracle compromised:**

**Attack 1:** Sign invalid token IDs
- **Impact:** Mints fail (signature verification fails)
- **Damage:** None (no funds at risk)

**Attack 2:** Sign same token ID twice
- **Impact:** Second mint fails (token already exists)
- **Damage:** None (first-come-first-served)

**Attack 3:** Sign with expired timestamp
- **Impact:** Mint fails (expired check)
- **Damage:** None

**Conclusion:** Oracle compromise cannot steal funds or break protocol.

### 5.3 Oracle Key Management

**Best practices:**
- Hardware wallet (Ledger/Trezor)
- Encrypted storage
- No cloud exposure
- Regular key rotation
- Multi-sig backup (optional)

**Monitoring:**
- Log all signature requests
- Alert on anomalies
- Rate limiting
- Geographic restrictions (optional)

---

## 6. GROK Token Security

### 6.1 Token Properties

**Immutable:**
- Owner: 0x000...dEaD (renounced)
- Supply: Fixed at 6.9B
- No minting function
- No pause mechanism
- Standard ERC-20

**Verification:**
```bash
# Check owner
cast call $GROK_TOKEN "owner()(address)"
# Must return: 0x000...dEaD

# Check no mint function
cast sig "mint(address,uint256)"
# Should not exist in contract

# Verify on Etherscan
open https://etherscan.io/address/0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5#code
```

### 6.2 Burn Verification

**Every burn is verifiable:**
```bash
# Check GROK burned by contract
cast call $GROK_TOKEN "balanceOf(address)(uint256)" 0x000000000000000000000000000000000000dEaD

# Verify specific burn transaction
cast tx $BURN_TX_HASH
# Check: to == 0x000...dEaD
```

**100% transparency.**

---

## 7. Frontend Security

### 7.1 Client-Side Validation

**Never trust user input:**
```typescript
// Validate file size
if (file.size > MAX_FILE_SIZE) {
  throw new Error('File too large');
}

// Validate burn rate
if (burnRate < MIN_RATE || burnRate > MAX_RATE) {
  throw new Error('Invalid burn rate');
}

// Validate address
if (!ethers.isAddress(address)) {
  throw new Error('Invalid address');
}
```

### 7.2 RPC Security

**Don't trust single RPC:**
```typescript
// Use multiple RPC providers
const providers = [
  new ethers.JsonRpcProvider('https://eth-mainnet.g.alchemy.com/...'),
  new ethers.JsonRpcProvider('https://mainnet.infura.io/...'),
  new ethers.JsonRpcProvider('https://rpc.ankr.com/eth')
];

// Verify responses match
const results = await Promise.all(
  providers.map(p => p.getBlockNumber())
);

if (new Set(results).size > 1) {
  throw new Error('RPC mismatch - potential attack');
}
```

### 7.3 IPFS Security

**Content verification:**
```typescript
// After upload, verify CID
const uploaded = await ipfs.add(file);
const retrieved = await ipfs.cat(uploaded.cid);

// Hash must match
const uploadedHash = sha256(file);
const retrievedHash = sha256(retrieved);

if (uploadedHash !== retrievedHash) {
  throw new Error('IPFS corruption detected');
}
```

---

## 8. Audit Process

### 8.1 Pre-Audit Checklist

- [ ] All functions documented (NatSpec)
- [ ] No admin functions remain
- [ ] ReentrancyGuard on all state changes
- [ ] Integer bounds checked
- [ ] Signature verification correct
- [ ] Test coverage > 95%
- [ ] Gas optimization complete
- [ ] No compiler warnings
- [ ] Solhint/Slither clean

### 8.2 Audit Focus Areas

**Critical:**
1. Burn mechanism (GROK actually burned?)
2. Oracle signature verification
3. Reentrancy protection
4. Integer overflow/underflow
5. Capacity tracking accuracy

**Important:**
6. Nonce replay protection
7. Signature expiration
8. Token ID uniqueness
9. Self-sealing logic
10. Event emissions

**Nice-to-have:**
11. Gas optimization
12. Code clarity
13. Documentation completeness

### 8.3 Post-Audit

- [ ] Fix all critical issues
- [ ] Fix all high issues
- [ ] Review medium issues (fix if feasible)
- [ ] Document low issues (accepted risks)
- [ ] Publish audit report
- [ ] Implement continuous monitoring

---

## 9. Monitoring

### 9.1 On-Chain Monitoring

**Key metrics:**
```typescript
// Monitor continuously
setInterval(async () => {
  const stats = {
    totalBurned: await contract.totalGrokBurned(),
    totalBytes: await contract.totalBytesMinted(),
    capacityRemaining: await contract.getRemainingCapacity(),
    highestTokenId: await contract.highestMintedTokenId()
  };
  
  // Alert on anomalies
  if (stats.totalBurned < expectedMinimum) {
    alert('CRITICAL: Burn amount suspiciously low!');
  }
}, 60000); // Every minute
```

### 9.2 Event Monitoring

```typescript
// Listen for all Grokked events
contract.on('Grokked', (tokenId, creator, grokBurned, burnRate, contentSize, ipfsURI, burnTx) => {
  // Log to database
  await db.mints.insert({
    tokenId,
    creator,
    grokBurned: grokBurned.toString(),
    burnRate,
    contentSize,
    ipfsURI,
    burnTx,
    timestamp: Date.now()
  });
  
  // Check for anomalies
  if (grokBurned.toString() === '0') {
    alert('CRITICAL: Zero burn detected!');
  }
});
```

### 9.3 IPFS Monitoring

```typescript
// Verify content availability
async function checkAvailability(cid: string) {
  const gateways = [
    'https://ipfs.io/ipfs/',
    'https://cloudflare-ipfs.com/ipfs/',
    'https://dweb.link/ipfs/'
  ];
  
  const results = await Promise.allSettled(
    gateways.map(gw => fetch(`${gw}${cid}`, { method: 'HEAD' }))
  );
  
  const available = results.filter(r => r.status === 'fulfilled').length;
  
  if (available < 2) {
    alert(`WARNING: ${cid} only on ${available} gateways!`);
  }
}
```

---

## 10. Incident Response

### 10.1 If Vulnerability Discovered

**Step 1:** Assess severity
- Critical: Funds at risk
- High: Protocol integrity at risk
- Medium: UX/efficiency issue
- Low: Documentation/clarity issue

**Step 2:** Immediate actions
- If critical: Announce publicly (can't pause, but warn users)
- If high: Plan fix (requires new deployment if contract-level)
- If medium/low: Issue on GitHub, plan update

**Step 3:** Communication
- Transparent disclosure
- Timeline for fix
- User instructions
- Post-mortem analysis

### 10.2 Bug Bounty

**Planned:** Bug bounty program post-launch

**Scope:**
- Smart contract vulnerabilities
- Oracle compromise scenarios
- IPFS infrastructure exploits
- Frontend security issues

**Rewards:**
- Critical: $10,000+
- High: $5,000
- Medium: $1,000
- Low: $500

**Contact:** security@grokme.me (to be established)

---

## 11. Threat Model

### 11.1 Threat Actors

**1. Malicious User**
- Goal: Mint without burning GROK
- Defense: Smart contract validation
- Risk: Low (mathematically prevented)

**2. Oracle Attacker**
- Goal: Manipulate token ID assignment
- Defense: Signature verification
- Risk: Low (no funds at risk)

**3. IPFS Attacker**
- Goal: Remove content
- Defense: Multiple pins + cluster
- Risk: Low (redundancy)

**4. State Actor**
- Goal: Censor/shutdown
- Defense: Decentralization
- Risk: Medium (can pressure providers, not protocol)

**5. Time Attacker**
- Goal: Break system long-term
- Defense: Immutable contracts
- Risk: Low (quantum resistance planned)

### 11.2 Attack Scenarios

See `/docs/security/ATTACK-SCENARIOS.md` (planned)

---

## 12. Best Practices for Integrators

### 12.1 Wallet Security

```typescript
// Never store private keys in code
const signer = await provider.getSigner();

// Use hardware wallets for oracle
const ledger = new LedgerSigner(provider);

// Verify addresses
if (signer.address !== expectedAddress) {
  throw new Error('Wrong wallet connected');
}
```

### 12.2 Transaction Verification

```typescript
// Wait for confirmations
const receipt = await tx.wait(3); // 3 confirmations

// Verify event emitted
const event = receipt.events?.find(e => e.event === 'Grokked');
if (!event) {
  throw new Error('Mint event not emitted - failed');
}

// Verify token exists
const owner = await contract.ownerOf(tokenId);
if (owner !== expectedOwner) {
  throw new Error('Token ownership mismatch');
}
```

### 12.3 Error Handling

```typescript
try {
  await contract.grokMeWithSignedId(...);
} catch (error) {
  if (error.code === 'INSUFFICIENT_FUNDS') {
    // Handle: User needs more GROK
  } else if (error.message.includes('Nonce already used')) {
    // Handle: Request new signature
  } else if (error.message.includes('Capsule sealed')) {
    // Handle: Capacity reached
  } else {
    // Unknown error - log and alert
    console.error('Mint failed:', error);
  }
}
```

---

## Conclusion

**GROKME Security Philosophy:**

```
1. Eliminate attack surfaces (no admin functions)
2. Mathematical guarantees (code as law)
3. Defense in depth (multiple protections)
4. Transparency (all code public)
5. Continuous monitoring (automated checks)
```

**The most secure code is code that doesn't exist.**

**The most trustless system is one that cannot be trusted—because trust is not needed.**

---

**Review this model before deployment. Audit thoroughly. Monitor continuously.**

