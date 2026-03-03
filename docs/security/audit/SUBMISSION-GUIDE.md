# Audit Submission Guide

**Protocol:** GROKME  
**Public repo:** https://github.com/grokme-io/protocol  
**Target platforms:** Cyfrin Codehawks, Code4rena, Sherlock, Immunefi  

No upfront audit fee required for any of these options.

---

## Platform Comparison

| Platform | Model | Cost | Report | Turnaround |
|---|---|---|---|---|
| **Cyfrin Codehawks** | Competitive contest | Sponsor-funded prize pool | Public on GitHub | 2–4 weeks |
| **Code4rena** | Competitive contest | Sponsor-funded prize pool | Public post-contest | 2–4 weeks |
| **Sherlock** | Competitive + optional insurance | Sponsor-funded | Public | 2–4 weeks |
| **Immunefi** | Bug bounty (ongoing) | Pay-per-valid-bug | Researcher reports private | Ongoing |

**Recommended sequence:**
1. **Immunefi** — launch immediately, zero upfront cost (see `IMMUNEFI-BOUNTY.md`)
2. **Cyfrin Codehawks** — lowest barrier for a formal contest, First Flights option
3. **Code4rena or Sherlock** — when a funded prize pool is ready

---

## 1. Cyfrin Codehawks

**URL:** https://codehawks.cyfrin.io  
**Contact:** https://codehawks.cyfrin.io/become-a-sponsor

### What to prepare

The `grokme-io/protocol` repo is already public and contains the contracts. Make sure these are present and up to date:

```
contracts/mainnet/GrokNFT.sol          ← in this repo
# Arena contracts: link to grokme-me-chain or copy into contracts/mainnet/
contracts/mainnet/GrokmeArena.sol
contracts/mainnet/GrokmeArenaTrophy.sol
docs/security/audit/                   ← this package
```

### Submission form fields

| Field | Value |
|---|---|
| Protocol name | GROKME Protocol |
| GitHub repo | https://github.com/grokme-io/protocol |
| Audit README | `docs/security/audit/AUDIT-README.md` |
| nSLOC | ~850 (run `cloc contracts/mainnet/`) |
| Known issues | Paste content of `docs/security/audit/SCOPE.md` → "Known Issues" section |
| Etherscan (Arena) | https://etherscan.io/address/0x97a38be1cE4257b80CcEc01b0F2c71810624d803#code |
| Etherscan (Trophy) | https://etherscan.io/address/0x33eAB69746De54Db570f21FE6099DBEf695d1C42#code |
| Test command | `npx hardhat test` (from grokme-me-chain repo) |

### First Flights (free option)

Cyfrin runs free community reviews for open-source protocols with strong fundamentals. Apply via the sponsor form and mark "Interested in First Flights". Good fit for GROKME given the renounced, no-admin design.

---

## 2. Code4rena

**URL:** https://code4rena.com  
**Contact:** sponsors@code4rena.com or Discord: https://discord.gg/code4rena

### Steps

1. DM or email `sponsors@code4rena.com`:
   - Subject: `Audit request — GROKME Protocol (Ethereum Mainnet, ~850 nSLOC)`
   - Attach: `AUDIT-README.md`, `SCOPE.md`
   - Include Etherscan links for all deployed contracts
2. C4 team schedules contest window (typically 1–2 weeks)
3. Fund prize pool — minimum ~$15,000 USDC for a standard contest; negotiate for smaller protocols

### Note on repo

`grokme-io/protocol` is already public. Ensure contracts are verified on Etherscan and all source files are in the repo before contest start.

---

## 3. Sherlock

**URL:** https://www.sherlock.xyz/protocols  

### Steps

1. Fill the protocol intake form at https://www.sherlock.xyz/protocols
2. Key fields:
   - Protocol type: DeFi / NFT hybrid — Meme Battle + Burn-to-Mint
   - TVL: No TVL — all funds burn to dead address
   - Admin keys: None on Arena/Trophy; oracle on GrokNFT
   - LOC: ~850 nSLOC
3. Sherlock evaluates and schedules a contest
4. Optional: Sherlock protocol coverage (ongoing insurance premium) — separate from audit

**Why Sherlock is a good fit:** Strong track record on economic/game-theoretic analysis, which is the primary residual risk for GROKME's voting mechanics (H-01).

---

## 4. Immunefi Bug Bounty

See **`IMMUNEFI-BOUNTY.md`** for the complete program template.

**Quick start:**
1. Register at https://immunefi.com/build
2. Copy-paste the program from `IMMUNEFI-BOUNTY.md`
3. Fund vault with minimum $1,000–$5,000 USDC
4. Publish (Immunefi reviews within 2–5 business days)

Zero upfront cost beyond the vault funding. You only pay for valid, triaged bug reports.

---

## 5. Free / Community Options

### Pashov Audit Group
**URL:** https://github.com/pashov/audits  
Solo auditor, strong ERC-20 + NFT track record. Occasional free reviews for public-good or interesting protocols. DM: @pashovkrum on Twitter/X.

### Guardian Audits
**URL:** https://guardianaudits.com  
Community submission form for free "Guardian Audit" reviews.

### Solodit
**URL:** https://solodit.xyz  
Not an audit platform, but registering your contracts and linking audit reports increases visibility with the security community.

---

## Pre-Submission Checklist

- [ ] `contracts/mainnet/` in `grokme-io/protocol` contains all three contracts
- [ ] All contracts verified on Etherscan (source publicly readable)
- [ ] `docs/security/audit/FINDINGS.md` complete with all known issues
- [ ] `docs/security/audit/SCOPE.md` clearly marks what is in/out of scope
- [ ] Tests pass: `npx hardhat test` (from `grokme-me-chain`)
- [ ] Immunefi program created (even as draft) for ongoing coverage
- [ ] Submission email/DM sent to at least one competitive platform
