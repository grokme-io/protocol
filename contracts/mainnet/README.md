# Smart Contracts: Mainnet

## Two Contracts, One Protocol

**GROK Token** (Energy Source) + **GrokNFT** (First Capsule) = GROKME Protocol

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
Dead Balance: Significant portion already burned
```

No admin can manipulate. Pure mathematics.

**2. Philosophical Alignment**

"Grok" from Heinlein (1961): Complete understanding where observer becomes observed.

Not chosen for meme. Chosen for meaning.

**3. Synchronicity**

```
6.9 billion GROK supply
        690 NFTs Genesis capsule
```

The numbers echo. Discovered, not designed.

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

## GrokNFT Contract

**Address:** [`0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`](https://etherscan.io/address/0x5ee102ab33bcc5c49996fb48dea465ec6330e77d#code)  
**Network:** Ethereum Mainnet  
**Standard:** ERC-721  
**Status:** 🟢 LIVE since November 2025 | 305M+ GROK burned  
**Audit package:** [`docs/security/audit/`](../../docs/security/audit/)

### Design Philosophy

No oracle. No signature scheme. No off-chain dependencies.  
The simplest possible design that achieves the goal: **burn GROK, mint NFT.**

Chosen deliberately over the oracle-based concept (see `contracts/archive/`) because:
- Zero oracle attack surface
- Fully permissionless — no backend required to mint
- Auditable in minutes, not hours
- Mathematical supply guarantees (tier limits + global cap)

### Architecture

```solidity
contract GrokNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    // Permissionless burn-to-mint. No oracle. No proxy. No upgrade.
}
```

### Tiers

| Tier | Supply | GROK Burn | Total GROK |
|---|---|---|---|
| COMMON | 469 | 6,900 | 3,236,100 |
| RARE | 138 | 69,000 | 9,522,000 |
| EPIC | 69 | 690,000 | 47,610,000 |
| LEGENDARY | 10 | 1,000,000 | 10,000,000 |
| DIVINE | 3 | 10,000,000 | 30,000,000 |
| UNICORN | 1 | 100,000,000 | 100,000,000 |
| **TOTAL** | **690** | | **~200M GROK** |

### Mint Function

```solidity
function mint(string memory ipfsURI, uint256 grokBurnAmount)
    external nonReentrant returns (uint256)
```

1. Check `currentTokenId < 690` (global cap)
2. Match `grokBurnAmount` to tier constant — revert if no match (`"Invalid tier"`)
3. Check per-tier supply cap
4. `GROK_TOKEN.transferFrom(msg.sender, BURN_ADDRESS, grokBurnAmount)` — burn
5. Mint ERC-721 with sequential `tokenId`, set IPFS URI

### Security Properties

✅ **Reentrancy** — `nonReentrant` on `mint()`  
✅ **Integer overflow** — Solidity 0.8.20 built-in  
✅ **No oracle** — zero off-chain trust assumption  
✅ **No proxy** — immutable bytecode  
✅ **No pause** — unstoppable  
✅ **Burn verified** — `require(transferFrom(...))` — reverts on failure  
✅ **Supply caps** — per-tier counters + global `currentTokenId < 690`

Owner power: `setContractURI()` only (collection metadata for OpenSea). Zero effect on minting.

### Integration

```javascript
// 1. Approve GROK
const COMMON_BURN = ethers.parseUnits('6900', 9); // 6,900 GROK (9 decimals)
await grokToken.approve(GROK_NFT_ADDRESS, COMMON_BURN);

// 2. Mint
const tx = await grokNFT.mint(ipfsURI, COMMON_BURN);
await tx.wait();
```

### Events

```solidity
event Grokked(
    uint256 indexed tokenId,
    address indexed creator,
    uint256 grokBurned,
    string tier,
    string ipfsURI
);
```

---

## License

Both contracts: MIT License

**GROK Token:** Deployed 2023 (ownerless)  
**GrokNFT:** Deployed November 2025  
**GrokmeArena:** Deployed 2026-03-02 (renounced)  
**GrokmeArenaTrophy:** Deployed 2026-03-02 (renounced)

---

**Mathematical permanence through cryptographic proof.**

