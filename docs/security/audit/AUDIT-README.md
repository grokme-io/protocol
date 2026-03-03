# GROKME Protocol — Security Audit Package

**Version:** 1.0.0  
**Date:** 2026-03-03  
**Chain:** Ethereum Mainnet  
**Contact:** security@grokme.me  
**Source:** https://github.com/grokme-io/protocol

---

## Overview

GROKME is a two-component on-chain protocol on Ethereum Mainnet:

1. **GROKME Arena** (`battle.grokme.me`) — A Proof-of-Culture Meme Battle Protocol. Challengers stake ERC-20 community tokens behind a meme. Community votes on-chain. All staked tokens burn to `0x...dEaD`. Protocol fee swapped to GROK and burned. Fully renounced — no admin, no owner, no upgrade proxy.

2. **GROK NFT** (`grokme.me`) — Burn-to-Mint NFT with 6 rarity tiers (COMMON → UNICORN). Users burn a fixed amount of GROK tokens per tier to mint an ERC-721 NFT. Hard supply cap of 690 total across all tiers. No oracle, no signature scheme — pure burn-to-mint.

---

## Deployed Contracts

| Contract | Address | Description |
|---|---|---|
| `GrokmeArena` | [`0x97a38be1cE4257b80CcEc01b0F2c71810624d803`](https://etherscan.io/address/0x97a38be1cE4257b80CcEc01b0F2c71810624d803#code) | Core battle protocol. No owner. No admin. Renounced. |
| `GrokmeArenaTrophy` | [`0x33eAB69746De54Db570f21FE6099DBEf695d1C42`](https://etherscan.io/address/0x33eAB69746De54Db570f21FE6099DBEf695d1C42#code) | ERC-721 Battle Trophy. Immutable minter = Arena only. No owner. |
| `GrokNFT` | [`0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`](https://etherscan.io/address/0x5ee102ab33bcc5c49996fb48dea465ec6330e77d#code) | ERC-721 Burn-to-Mint NFT. 6 tiers, fixed burn amounts, 690 total supply. Owner retains `setContractURI()`. |
| **GROK Token** | [`0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5`](https://etherscan.io/address/0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5) | External ERC-20. Owner renounced to `0x...dEaD`. Out of scope. |

**Arena + Trophy deploy block:** 24571121 (2026-03-02)

---

## Source Files

```
contracts/mainnet/
└── GrokNFT.sol              # GROK NFT — 329 lines

# Arena contracts (separate repo, cross-referenced):
# GrokmeArena.sol            — 809 lines
# GrokmeArenaTrophy.sol      — 278 lines
```

Total auditable lines: **~1,416 Solidity**

See [`SCOPE.md`](./SCOPE.md) for exact function-level scope.

---

## Architecture

### GrokmeArena — Battle State Machine

```
OPEN → BIDDING → BATTLING → SETTLED
                           → EXPIRED  (72h no acceptance)
             → FOLDED      (fold during bidding)
```

**Flow:**
1. `issueChallenge()` — Stake tokens + submit meme hash. 5% fee burned immediately.
2. `acceptChallenge()` — Opponent stakes + poker-style bidding begins.
3. `raise()` / `call()` / `fold()` — Bidding mechanics (max 10 raises, 24h timeout).
4. `castVote()` — Token-gated, 1-wallet-1-vote during battle window.
5. `settleBattle()` — Permissionless. Burns ALL tokens to `0x...dEaD`. Mints Trophy.

### GrokNFT — Burn-to-Mint NFT (Tier-Based)

**Flow:**
1. User calls `mint(ipfsURI, grokBurnAmount)` with exact tier burn amount.
2. Contract validates tier by exact `grokBurnAmount` match, checks per-tier supply cap.
3. GROK tokens transferred directly from caller to `0x...dEaD` (burn address).
4. ERC-721 minted with sequential `tokenId`, URI set to provided IPFS URI.
5. Total supply hard-capped at 690 (sum of all tier limits).

**Tiers:**
| Tier | Supply | Burn Amount |
|---|---|---|
| COMMON | 469 | 6,900 GROK |
| RARE | 138 | 69,000 GROK |
| EPIC | 69 | 690,000 GROK |
| LEGENDARY | 10 | 1,000,000 GROK |
| DIVINE | 3 | 10,000,000 GROK |
| UNICORN | 1 | 100,000,000 GROK |

---

## Technology Stack

| Component | Detail |
|---|---|
| Solidity | 0.8.20 |
| OpenZeppelin | 4.9.x — `ReentrancyGuard`, `ERC721URIStorage`, `Ownable`, `EIP712`, `ECDSA` |
| External: Uniswap V2 Router | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` (Arena fee swap) |
| External: GROK Token | `0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5` |

---

## Key Trust Properties

**GrokmeArena + GrokmeArenaTrophy:**
- Zero admin functions, zero owner, zero upgrade proxy, zero kill switch
- All staked tokens and protocol fees burn — no funds reach any team wallet
- Settlement is permissionless — anyone can trigger after voting ends
- Trophy mint failure (try/catch) never blocks settlement

**GrokNFT:**
- No oracle, no off-chain signature scheme — fully permissionless mint
- Tier validation is purely by exact `grokBurnAmount` — no other access control
- `Ownable` is present; owner retains `setContractURI()` only (metadata pointer, not mint control)
- Supply cap is mathematical — 6 per-tier counters + global `currentTokenId < 690`
- No `receive()` or `fallback()` — ETH cannot be sent to contract

---

## Files in This Audit Package

| File | Purpose |
|---|---|
| `AUDIT-README.md` | This file |
| `SCOPE.md` | In-scope functions, out-of-scope, known issues |
| `FINDINGS.md` | Self-audit findings with severity ratings |
| `SUBMISSION-GUIDE.md` | Cyfrin Codehawks, Code4rena, Sherlock, Immunefi |
| `IMMUNEFI-BOUNTY.md` | Ready-to-publish Immunefi Bug Bounty template |
| `TRUST-BADGE.md` | Badge snippets and security page content |

---

## Related Documentation

- [Whitepaper](../../../WHITEPAPER.md)
- [Security Model](../SECURITY-MODEL.md)
- [Mathematics](../../../MATHEMATICS.md)
- [Implementations Registry](../../../implementations/)
