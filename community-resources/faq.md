# Frequently Asked Questions

Common questions about GROKME Protocol and GROK NFT.

---

## General Protocol

### What is GROKME?

An open standard for eternal cultural preservation using cryptography and token economics.

Like HTTP is a standard for websites, GROKME is a standard for permanent archives.

### Who controls GROKME?

Nobody. The protocol is code. Implementations are autonomous.

No team. No company. No governance.

### Is this a project or company?

Neither. It's an open protocol standard.

Like TCP/IP or HTTP. Anyone can implement it.

### How is this sustainable without a team?

One-time burn creates permanent storage. No ongoing development needed.

Code runs autonomously. IPFS infrastructure is distributed.

### Can GROKME be shut down?

No. Smart contracts are renounced. IPFS is distributed. Blockchain is permanent.

Mathematical impossibility, not legal promise.

---

## GROK Token

### Why GROK specifically?

1. Already renounced to 0x000...dEaD (no manipulation)
2. Philosophical alignment (Heinlein's "to grok")
3. Community-proven (survived since 2023)
4. Perfect energy carrier properties

### Where can I get GROK?

GROK trades as "Grok (grokoneth.meme)" across the crypto ecosystem.

DEX: Uniswap (primary liquidity)
CEX: MEXC, Gate.io, KCEX, BloFin, BingX, CoinW
Market Data: CoinMarketCap, CoinGecko, DexTools, DexScreener

Contract: `0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5`

Verify on Etherscan before purchasing.

### What happens to burned GROK?

100% goes to `0x000...dEaD` (burn address).

Permanently destroyed. Verifiable on-chain.

Zero extraction. No treasury. No fees.

### Will GROK price increase?

The protocol makes no predictions or promises.

GROK serves as utility (energy for preservation).

Economics are observable on-chain.

---

## GROK NFT

### What is GROK NFT?

First implementation of GROKME Protocol.

690-NFT self-sealing preservation capsule for memes.

Live on Ethereum Mainnet since November 2025. Over 305M GROK burned.

### Where can I use it?

**Mainnet:** grokme.me (live since November 2025)  
**Test:** staging.grokme.me (Sepolia testnet)

### How long until it fills?

Unknown. Depends on participation.

Could be days, weeks, or months.

Fills at its own pace. No time pressure.

### What happens when it fills?

Minting stops forever. Capsule sealed.

All NFTs remain accessible. Zero ongoing costs.

Content becomes eternal museum.

### Can I test before minting on mainnet?

Yes! Visit staging.grokme.me (Sepolia testnet).

Free test GROK from faucet.

Full functionality available for testing.

---

## Technical

### How does self-sealing work?

Smart contract modifier checks capacity:

```solidity
modifier capsuleOpen() {
    require(totalBytesMinted < MAX_CAPACITY, "Sealed");
    _;
}
```

When capacity reached, minting function cannot execute.

Mathematical finality.

### Is the contract upgradeable?

No. Not a proxy pattern.

Immutable deployment. No upgrade path possible.

### Who owns the contract?

Owner is renounced to `0x000...dEaD` immediately after launch.

No admin. No control. Autonomous forever.

### How is content stored?

Files uploaded to IPFS (content-addressed storage).

NFT metadata contains IPFS CID.

Multi-node cluster with 3x replication minimum.

### What if IPFS nodes go down?

Content-addressed storage (CID) means:
- Anyone can pin the content
- Multiple nodes have copies
- Filecoin provides economic incentive

Distributed by design. No single point of failure.

### Can content be deleted?

No. Once sealed:
- Smart contract cannot be modified
- IPFS content is pinned
- Blockchain metadata is permanent

Mathematical impossibility.

---

## Minting & Economics

### How much does minting cost?

**GROK burn:**
```
Total = File Size (KB) × Rate (1-1000 GROK/KB)
```

Your choice of rate. Higher = rarer.

**Plus gas:**
Ethereum network fees (varies).

### How is rarity determined?

Based on total GROK burned:
- ⚪ COMMON: 0-5k
- 🟢 UNCOMMON: 5k-25k
- 🔵 RARE: 25k-100k
- 🟣 EPIC: 100k-500k
- 🟠 LEGENDARY: 500k+

Plus: Special token IDs, mint position, file size, milestones.

All transparent. All on-chain.

### Are there any fees?

Zero. 100% of GROK goes to 0x000...dEaD.

No team cut. No treasury. No protocol fee.

Only Ethereum gas costs (network-level).

### Can I mint multiple NFTs?

Yes. No limit per wallet.

Each mint is independent.

### What file types are supported?

Common formats: JPG, PNG, GIF, MP4, WEBM.

See implementation-specific docs for complete list.

### What's the maximum file size?

Depends on remaining capsule capacity.

Genesis: 690 NFTs total in the capsule.

Individual file size limits set by implementation.

---

## After Minting

### Can I sell my NFT?

Yes. Standard ERC-721.

Tradeable on any NFT marketplace (OpenSea, etc.)

### Can I transfer it?

Yes. Standard ERC-721 `transferFrom()` function.

Full ownership. No restrictions.

### What if I lose my wallet?

NFT follows standard rules:
- Lose keys = lose access
- Use hardware wallet
- Backup seed phrase

No recovery mechanism (by design).

### Can content be modified after minting?

No. IPFS is content-addressed.

CID is cryptographic hash of content.

Changing content = different CID = different NFT.

### What happens after the capsule seals?

- Minting stops forever
- Existing NFTs remain accessible
- Content stays on IPFS
- Transfers still work
- Zero ongoing costs

Eternal museum state.

---

## Verification

### How do I verify a capsule is legitimate?

Check contract against criteria:
- ✅ Owner = 0x000...dEaD?
- ✅ Burn address = 0x000...dEaD?
- ✅ Extraction rate = 0%?

All verifiable on Etherscan.

Automatic verification planned.

### Can there be fake GROKME capsules?

Yes. Anyone can deploy a contract.

**Always verify:**
1. Owner renounced?
2. Burn address correct?
3. Zero extraction?

Don't trust. Verify.

### Where is the official list?

GitHub: [implementations/ directory](../implementations/)

Registry planned at grokme.io/registry

---

## Future

### Will there be more capsules?

Active and upcoming:
- **GROKME ARENA** (meme battles) — Smart contracts complete, launching Q1/Q2 2026. Every battle burns GROK.
- **[REDACTED]** — Major new capsule in development. Significant GROK burn expected. Announcement soon.
- **GROKME ART** (visual art) — Planned
- **GROKME MUSIC** (audio) — Planned

Anyone can build custom capsules using the open protocol.

### Can I build my own capsule?

Yes! Protocol is open (MIT License).

Use templates in `/contracts/templates/`

No permission needed. Get auto-verified if you follow standard.

### Will GROK NFT get updates?

No. Once sealed, it's frozen forever.

No updates. No changes. Eternal.

That's the entire point.

### What's the long-term vision?

The protocol is complete and autonomous. The ecosystem is expanding:

- GROK NFT: Live on mainnet, 305M+ GROK burned
- GROKME Arena: On-chain meme battles, contracts complete
- [REDACTED]: Major new capsule in development
- Open standard: Anyone can build on the protocol

Community contributions drive growth.

---

## Concerns & Risks

### What if Ethereum fails?

Content exists on IPFS (independent of Ethereum).

Metadata is on blockchain (distributed).

Multiple layers of permanence.

### What if GROK token becomes worthless?

Protocol utility remains.

Burns still create permanence.

Token price doesn't affect functionality.

### What if nobody uses it?

Genesis is first implementation. Outcome unknown.

Protocol exists regardless of usage.

Code is permanent. Adoption is organic.

### Is this a scam?

Verify yourself:
- Code is open source
- Contracts are renounced
- No extraction (0%)
- No promises made

Don't trust. Verify.

### What are the risks?

**Smart contract risk:**
Code is auditable. No admin functions = minimal attack surface.

**IPFS risk:**
Distributed storage. Multiple nodes. Economic incentives (Filecoin).

**Ethereum risk:**
Blockchain permanence. Distributed consensus.

Standard crypto risks apply.

---

## Community & Support

### Is there a Discord/Telegram?

No official channels. Protocol has no "official" anything.

Community may create channels. None are endorsed.

### How do I get help?

- Read docs: [GitHub](https://github.com/grokme-io/protocol)
- Technical issues: GitHub Issues
- General questions: Community forums

No official support (no team to provide it).

### Can I contribute?

Yes! Protocol is open source (MIT).

- Improve docs
- Build tools
- Create content
- Help others understand

No approval needed.

### Who do I contact?

Nobody. There's no team.

For technical questions: Read docs.
For bugs: GitHub issues.
For discussion: Community forums.

---

## Philosophical

### Why "GROKME"?

From Robert Heinlein's "Stranger in a Strange Land" (1961).

"Grok" = to understand so completely, observer becomes observed.

Burning GROK proves you've grokked the value.

Perfect philosophical alignment.

### Why preservation over destruction?

Energy transforms, doesn't vanish.

GROK burn → Cultural preservation.

Temporary becomes eternal.

### Is this really permanent?

As permanent as mathematics allows.

Blockchain consensus + cryptography + economic incentives.

Not human promises. Physical laws.

---

## Still Have Questions?

**Technical:**
- Read [WHITEPAPER.md](../WHITEPAPER.md)
- Read [MATHEMATICS.md](../MATHEMATICS.md)
- Check GitHub Issues

**General:**
- Read [protocol-explainer.md](protocol-explainer.md)
- Read [genesis-overview.md](genesis-overview.md)

**Can't find answer:**
- Ask in community forums
- Open GitHub Discussion

---

**Version:** 2.0  
**Last Updated:** February 2026  
**License:** MIT

