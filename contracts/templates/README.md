# GROKME Protocol Contract Templates

Modular smart contract templates for building GROKME-compliant cultural preservation platforms.

---

## Overview

**Baukasten System** - Build your implementation by combining protocol-compliant modules.

**Important:** GrokMeGenesis is the dedicated contract for grokme.me (meme preservation). Build YOUR OWN contract using these templates.

---

## Module Structure

```
contracts/templates/
├── core/                   Required base modules
│   ├── CoreBurn.sol       100% GROK burn mechanism
│   ├── SelfSealing.sol    Capacity-based finality
│   └── PostHuman.sol      Renounced ownership pattern
│
├── enhancements/          Optional feature modules
│   ├── VariableBurnRates.sol   Creator-chosen burn rates
│   ├── OracleSystem.sol        Anti-front-running
│   ├── BatchMinting.sol        Gas-efficient bulk mints
│   ├── BurnTxTracking.sol      Transaction verification
│   └── RaritySystem.sol        On-chain rarity calculation
│
├── examples/              Complete implementations
│   ├── BasicCapsule.sol        Minimal implementation
│   ├── AdvancedCapsule.sol     All features enabled
│   └── CustomCapsule.sol       Custom modifications
│
└── README.md              This file
```

---

## Core Modules (Required)

### 1. CoreBurn.sol

**Purpose:** 100% GROK burn to 0x000...dEaD

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract CoreBurn {
    IERC20 public constant GROK_TOKEN = IERC20(0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5);
address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    uint256 public totalGrokBurned;
    
    event GrokBurned(
        address indexed burner,
        uint256 amount,
        uint256 tokenId
    );
    
function _burnGrok(uint256 amount) internal {
    require(
            GROK_TOKEN.transferFrom(msg.sender, BURN_ADDRESS, amount),
            "GROK burn failed"
    );
        
    totalGrokBurned += amount;
        emit GrokBurned(msg.sender, amount, 0); // Override tokenId in child
    }
    
    function GROK_TOKEN_ADDRESS() external pure returns (address) {
        return address(GROK_TOKEN);
    }
}
```

### 2. SelfSealing.sol

**Purpose:** Capacity-based finality mechanism

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract SelfSealing {
    uint256 public immutable MAX_CAPACITY_BYTES;
    uint256 public totalBytesMinted;
    
    event CapacityUpdated(uint256 totalBytes, uint256 maxCapacity);
    event CapsuleSealed(uint256 finalBytes, uint256 timestamp);
    
    constructor(uint256 _maxCapacity) {
        require(_maxCapacity > 0, "Capacity must be positive");
        MAX_CAPACITY_BYTES = _maxCapacity;
    }
    
modifier capsuleOpen() {
    require(totalBytesMinted < MAX_CAPACITY_BYTES, "Capsule sealed");
    _;
}

    function _addBytes(uint256 bytes_) internal {
        totalBytesMinted += bytes_;
        emit CapacityUpdated(totalBytesMinted, MAX_CAPACITY_BYTES);
        
        if (totalBytesMinted >= MAX_CAPACITY_BYTES) {
            emit CapsuleSealed(totalBytesMinted, block.timestamp);
        }
    }
    
    function isCapsuleOpen() public view returns (bool) {
    return totalBytesMinted < MAX_CAPACITY_BYTES;
}

    function getRemainingCapacity() public view returns (uint256) {
    if (totalBytesMinted >= MAX_CAPACITY_BYTES) return 0;
    return MAX_CAPACITY_BYTES - totalBytesMinted;
    }
    
    function getCompletionPercentage() public view returns (uint256) {
        return (totalBytesMinted * 100) / MAX_CAPACITY_BYTES;
    }
}
```

### 3. PostHuman.sol

**Purpose:** Renounced ownership pattern

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract PostHuman is Ownable {
    bool public isPostHuman;
    
    event TranscendedToPostHuman(uint256 timestamp);
    
    constructor() Ownable(msg.sender) {
        // Owner set temporarily for initial setup
    }
    
    function transcendToPostHuman() external onlyOwner {
        require(!isPostHuman, "Already post-human");
        
        // Renounce to burn address
        _transferOwnership(0x000000000000000000000000000000000000dEaD);
        isPostHuman = true;
        
        emit TranscendedToPostHuman(block.timestamp);
    }
    
    modifier onlyPreTranscendence() {
        require(!isPostHuman, "Cannot modify post-transcendence");
        _;
    }
}
```

---

## Enhancement Modules (Optional)

### VariableBurnRates.sol

Creator-chosen burn rates within protocol-defined range.

**Use when:** You want flexibility in pricing while maintaining burns.

### OracleSystem.sol

EIP-712 signature verification for anti-front-running token ID assignment.

**Use when:** You want to prevent malicious token ID sniping.

### BatchMinting.sol

Gas-efficient minting of multiple NFTs in one transaction.

**Use when:** You expect users to mint multiple items frequently.

### BurnTxTracking.sol

Optional burn transaction hash storage for proof verification.

**Use when:** You want explicit burn proof linkage.

### RaritySystem.sol

On-chain rarity calculation based on burn amount, position, and milestones.

**Use when:** You want deterministic rarity without oracle.

---

## Building Your Implementation

### Step 1: Choose Your Modules

**Required:**
- CoreBurn.sol (always)
- SelfSealing.sol (always)
- PostHuman.sol (always)

**Optional (pick what you need):**
- VariableBurnRates.sol
- OracleSystem.sol
- BatchMinting.sol
- BurnTxTracking.sol
- RaritySystem.sol

### Step 2: Assemble Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./core/CoreBurn.sol";
import "./core/SelfSealing.sol";
import "./core/PostHuman.sol";
import "./enhancements/VariableBurnRates.sol";
import "./enhancements/OracleSystem.sol";

contract YourCapsule is 
    ERC721URIStorage,
    ReentrancyGuard,
    CoreBurn,
    SelfSealing,
    PostHuman,
    VariableBurnRates,
    OracleSystem
{
    uint256 private _nextTokenId;
    
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxCapacity_,
        address oracle_,
        uint256 minBurnRate_,
        uint256 maxBurnRate_
    )
        ERC721(name_, symbol_)
        SelfSealing(maxCapacity_)
        VariableBurnRates(minBurnRate_, maxBurnRate_)
        OracleSystem(oracle_)
    {}
    
    function mint(
        uint256 tokenId,
        string memory ipfsURI,
        uint256 contentSizeBytes,
        uint256 burnRatePerKB,
        uint256 nonce,
        uint256 validUntil,
        bytes memory signature
    ) external nonReentrant capsuleOpen {
        // Verify oracle signature
        _verifySignature(
            tokenId,
            burnRatePerKB,
            nonce,
            msg.sender,
            validUntil,
            signature
        );
        
        // Calculate and burn GROK
        uint256 burnAmount = _calculateBurnAmount(contentSizeBytes, burnRatePerKB);
        _burnGrok(burnAmount);
        
        // Add bytes to capacity
        _addBytes(contentSizeBytes);
        
        // Mint NFT
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, ipfsURI);
        
        _nextTokenId++;
    }
}
```

### Step 3: Test on Sepolia

Deploy and test thoroughly on Sepolia testnet.

### Step 4: Deploy on Mainnet

Deploy verified contract on Ethereum Mainnet.

### Step 5: Renounce Ownership

Call `transcendToPostHuman()` to renounce to 0x000...dEaD.

### Step 6: Get Certified

Submit to grokme.io/verify for GROKME Certified badge.

---

## Example Implementations

### BasicCapsule.sol

Minimal implementation with only core modules.

**Use when:** You want simplest possible implementation.

**Features:**
- Fixed burn rate
- Manual token ID assignment
- No oracle
- No rarity system

### AdvancedCapsule.sol

Full-featured implementation with all enhancement modules.

**Use when:** You want complete feature set.

**Features:**
- Variable burn rates
- Oracle-signed token IDs
- Batch minting
- Burn transaction tracking
- On-chain rarity

### CustomCapsule.sol

Template for custom modifications while maintaining protocol compliance.

**Use when:** You need specific features not in standard modules.

**Features:**
- Core protocol (guaranteed)
- Your custom logic
- Still certifiable

---

## Protocol Compliance Checklist

To pass GROKME Certification, ensure:

- [ ] Uses GROK Token: `0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5`
- [ ] Burns to: `0x000000000000000000000000000000000000dEaD`
- [ ] Has `MAX_CAPACITY_BYTES` constant
- [ ] Implements `capsuleOpen` modifier
- [ ] Inherits from `PostHuman` or similar
- [ ] Owner renounced to `0x000...dEaD`
- [ ] No admin functions
- [ ] No pause mechanism
- [ ] No proxy/upgrade pattern
- [ ] Zero extraction (100% burn)

---

## Gas Optimization Tips

### 1. Use Immutable Variables

```solidity
uint256 public immutable MAX_CAPACITY_BYTES; // Saves gas on reads
```

### 2. Pack Storage Variables

```solidity
struct MintData {
    uint128 burnAmount;      // Fits in 1 slot
    uint64 timestamp;        // with timestamp
    uint64 contentSize;      // and size
}
```

### 3. Batch Operations

Use `BatchMinting.sol` for multiple mints in one transaction.

### 4. Efficient Events

```solidity
event Grokked(uint256 indexed tokenId, uint256 amount); // Indexed for filtering
```

---

## Security Considerations

### 1. Reentrancy Protection

Always use `ReentrancyGuard` on state-changing functions:

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

function mint(...) external nonReentrant { ... }
```

### 2. Integer Overflow

Solidity 0.8+ has built-in overflow protection, but be careful with:

```solidity
uint256 sizeKB = (sizeBytes + 1023) / 1024; // Ceiling division
```

### 3. Access Control

Before renouncement, protect sensitive functions:

```solidity
function setOracle(address newOracle) external onlyOwner onlyPreTranscendence {
    oracle = newOracle;
}
```

### 4. Signature Verification

Use EIP-712 for structured signatures:

```solidity
bytes32 digest = _hashTypedDataV4(structHash);
address signer = ECDSA.recover(digest, signature);
require(signer == oracle, "Invalid signature");
```

---

## Testing

### Unit Tests

```javascript
describe("YourCapsule", function() {
  it("Should burn GROK correctly", async function() {
    const burnAmount = ethers.parseUnits("1000", 9);
    await grok.approve(capsule.address, burnAmount);
    await capsule.mint(...);
    expect(await capsule.totalGrokBurned()).to.equal(burnAmount);
  });
  
  it("Should seal at capacity", async function() {
    // Mint until capacity reached
    expect(await capsule.isCapsuleOpen()).to.be.false;
  });
  
  it("Should renounce correctly", async function() {
    await capsule.transcendToPostHuman();
    expect(await capsule.owner()).to.equal(BURN_ADDRESS);
  });
});
```

---

## Support

### Free Resources

- Read `/docs/implementation/WHITELABEL-GUIDE.md`
- Check `/docs/implementation/CERTIFICATION.md`
- Ask on GitHub Discussions

### Paid Development Assistance

**The protocol does not provide development services.**

For assistance with contract assembly, certification compliance, and implementation:
- Contact: **mail@grokme.io**
- Independent developers (not protocol team)
- Paid services

### Bug Reports

Found a bug in templates?
- Open issue on GitHub
- Submit PR with fix

---

## License

All templates: MIT License

Use freely. No attribution required. Build the future.

---

**Last Updated:** October 2025  
**Template Version:** 1.0.0  
**Compatible With:** Solidity ^0.8.20
