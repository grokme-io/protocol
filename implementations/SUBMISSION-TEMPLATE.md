# Implementation Submission Template

Add your GROKME Protocol capsule to the public registry.

---

## The Process

**This is NOT a permission request. This is community recognition.**

Anyone can use GROKME Protocol (permissionless, open source). This registry is optional visibility for implementations that follow the standard.

---

## How to Submit

**Step 1:** Build your capsule
- Use contract baukasten from `/contracts/templates/`
- Select modules you need
- Configure your parameters
- Deploy yourself (Sepolia first!)

**Step 2:** Fork this repository

**Step 3:** Create directory: `implementations/your-project-name/`

**Step 4:** Add files:
- `CAPSULE.md` (your capsule documentation)
- `metadata.json` (structured data)

**Step 5:** Create Pull Request with this template:

---

## Pull Request Template

```markdown
# [Implementation] Your Project Name

## Declaration

This is an independent implementation of GROKME Protocol.

**I declare:**
- Contract deployed and verified independently
- No affiliation with protocol claimed
- Source code publicly available
- Follows protocol principles to best of knowledge

**Public verification via GitHub** (open review, not approval process)

## Basic Information

**Project Name:** Your Capsule Name  
**Website:** https://your-domain.com  
**Status:** Active / Launching Soon  
**Launch Date:** YYYY-MM-DD

## Contract Details

**Network:** Ethereum Mainnet  
**Address:** 0x...  
**Verified:** [Etherscan Link]  
**Owner:** 0x000...dEaD (renounced)

## Capsule Specifications

**Capacity:** X bytes  
**Theme/Focus:** Description  
**Burn Rate Range:** Min-Max GROK/KB  
**Max Content Size:** X bytes per NFT

## Modules Used

From Protocol Baukasten:
- [ ] Variable Burn Rates
- [ ] Oracle System
- [ ] Batch Minting
- [ ] Burn TX Tracking
- [ ] Custom Metadata
- [ ] Other (specify)

## Infrastructure

**IPFS Strategy:** (Pinata / Self-hosted / IPFS Cluster / Other)  
**Oracle:** (Self-hosted / Third-party / None)  
**Frontend:** (Tech stack)

## Community

**Target Audience:** Description  
**Social Links:** (optional)

## Verification

**Smart Contract Source:** [GitHub or Etherscan]  
**Deployment Transaction:** [Etherscan link]  
**First Mint Transaction:** [Etherscan link]

## Description

[2-3 paragraphs explaining your capsule's mission, community, and unique approach]

---

**By submitting this PR, I confirm all information is accurate and the implementation follows GROKME Protocol principles.**
```

---

## Files to Include

### 1. CAPSULE.md

Document your specific capsule (see `grokme-me/GROK-NFT.md` as example).

**Sections:**
- Overview & specifications
- Cultural focus/theme
- Why this capsule exists
- Community target
- Technical details
- Post-seal plans

### 2. metadata.json

```json
{
  "implementation": {
    "name": "YOUR CAPSULE",
    "website": "https://...",
    "status": "active",
    "submittedDate": "YYYY-MM-DD",
    "launchDate": "YYYY-MM-DD"
  },
  "capsule": {
    "capacity": 10000000000,
    "capacityUnit": "bytes",
    "theme": "Your theme",
    "description": "Short description"
  },
  "contract": {
    "address": "0x...",
    "network": "Ethereum Mainnet",
    "chainId": 1,
    "verified": true,
    "renounced": true,
    "deploymentDate": "YYYY-MM-DD"
  },
  "economics": {
    "burnRateMin": 1,
    "burnRateMax": 1000,
    "burnRateUnit": "GROK/KB",
    "maxContentSize": 12582912,
    "maxContentSizeUnit": "bytes"
  },
  "modules": {
    "variableBurnRates": true,
    "oracleSystem": true,
    "batchMinting": true,
    "burnTxTracking": false,
    "customMetadata": false
  },
  "infrastructure": {
    "ipfs": "Strategy description",
    "oracle": "Oracle setup",
    "frontend": "Tech stack",
    "database": "Database (if any)"
  },
  "social": {
    "twitter": "URL or null",
    "discord": "URL or null",
    "telegram": "URL or null"
  },
  "team": {
    "maintainers": "Team/community name",
    "contact": "email@domain.com"
  },
  "verification": {
    "protocolCompliant": true,
    "grokToken": "0x8390a1DA07e376ef7aDd4Be859BA74Fb83aA02D5",
    "burnAddress": "0x000000000000000000000000000000000000dEaD",
    "zeroExtraction": true,
    "postHuman": true,
    "selfSealing": true
  }
}
```

---

## Public Verification

### Automated Checks

Anyone can run verification script:

```bash
node scripts/verify-implementation.js --contract 0x...
```

Checks:
- ✅ GROK Token address = 0x8390...02D5
- ✅ Burn address = 0x000...dEaD
- ✅ Contract verified on Etherscan
- ✅ Owner = 0x000...dEaD (renounced)
- ✅ No admin functions exist

### Open Review

**GitHub discussion:**
- Technical review (contract code)
- Principle compliance (follows protocol?)
- Documentation quality
- Red flags check

**No authority approves.**  
**Contributors with merge access merge based on technical merit.**

**Timeline:** Usually 1-2 weeks

### If Technical Consensus

Any maintainer can merge PR:
- ✅ Listed in IMPLEMENTATIONS.md
- ✅ Discoverable in `/implementations/`
- ✅ Shown on grokme.io (when live)

**This is registry listing, not endorsement.**

---

## After Listing

Your implementation gets:
- Registry visibility
- Discoverability in `/implementations/`
- Link in protocol docs
- Listing on grokme.io (optional showcase)

**What the protocol IS:**
- Open source code (free to use)
- Mathematical standard (verifiable)
- Documentation (comprehensive)
- GitHub repository (open collaboration)

**What the protocol is NOT:**
- A company (no legal entity)
- A service (no deployments offered)
- A foundation (no organization)
- A community (just code + contributors)

**You build. You deploy. You own. You preserve.**

---

## Questions?

**Technical:** Open GitHub Discussion  
**Submission Issues:** Create Issue with "submission" label  
**General:** Check [/docs/implementation/WHITELABEL-GUIDE.md](../docs/implementation/WHITELABEL-GUIDE.md)

---

**Submit your capsule. Join the protocol. Preserve your culture.**

