# Repository Structure

---

## Directory Structure

```
protocol/
│
├── Core Documents (Protocol Level)
│   ├── README.md                    Protocol landing page
│   ├── WHITEPAPER.md                Complete specification
│   ├── MATHEMATICS.md               Scientific proofs
│   ├── PHILOSOPHY.md                Heinlein's vision
│   ├── IMPLEMENTATIONS.md           Registry overview
│   └── LICENSE                      MIT
│
├── implementations/                 Submitted Capsules
│   ├── grokme-me/                  First capsule
│   │   ├── GROK-NFT.md             Full docs
│   │   └── metadata.json           Structured data
│   ├── coming-soon/                In development
│   ├── SUBMISSION-TEMPLATE.md      How to submit
│   └── README.md                   Registry guide
│
├── test/                            Test Suite (Hardhat + Chai)
│   ├── GrokNFT.test.js             38 tests — all 6 tiers, burn mechanics, supply caps
│   ├── GrokmeArena.test.js         68 tests — full state machine coverage
│   ├── GrokmeArenaTrophy.test.js   27 tests — access control + data integrity
│   └── README.md                   Test descriptions + run instructions
│
├── contracts/                       Smart Contracts
│   ├── templates/                  Baukasten System
│   │   ├── modules/                Individual modules
│   │   └── README.md               Assembly guide
│   ├── mainnet/
│   │   ├── GrokNFT.sol            Deployed contract (tier-based, no oracle)
│   │   └── README.md              GROK + GrokNFT docs
│   ├── archive/                   Unreleased concept versions
│   │   ├── GrokNFT-oracle-concept.sol  EIP-712 oracle variant (not deployed)
│   │   └── GrokNFT-oracle-concept.sol.README  Why it was archived
│   ├── interfaces/
│   └── libraries/
│
├── docs/                            Technical Documentation
│   ├── architecture/               System design
│   ├── implementation/             Integration guides
│   │   ├── INTEGRATION-GUIDE.md   Developer integration
│   │   └── WHITELABEL-GUIDE.md    Capsule deployment
│   ├── infrastructure/             Infrastructure guides
│   │   ├── IPFS-CLUSTER.md        Storage architecture
│   │   └── AKASH-DEPLOYMENT.md    Decentralized hosting
│   └── security/                   Security model & audit
│       ├── SECURITY-MODEL.md      Attack surface analysis
│       └── audit/                 Audit submission package
│           ├── AUDIT-README.md    Project overview & deployed addresses
│           ├── SCOPE.md           In-scope functions & known issues
│           ├── FINDINGS.md        Self-audit findings (severity-rated)
│           ├── SUBMISSION-GUIDE.md Cyfrin, Code4rena, Sherlock, Immunefi
│           ├── IMMUNEFI-BOUNTY.md Bug bounty program template
│           └── TRUST-BADGE.md     Badge snippets & security page copy
│
├── infrastructure/                  Deployment Templates
│   ├── ipfs-cluster/              Storage cluster
│   │   ├── cluster-config.yaml    Production config
│   │   └── docker-compose.yml     Local testing
│   ├── akash/                     Decentralized cloud
│   │   └── cluster-node.yaml     Node deployment
│   ├── monitoring/                (Planned)
│   └── README.md                  Infrastructure overview
│
├── examples/                        Code Examples
│   ├── basic-integration/         React + Wagmi
│   ├── whitelabel-template/       (Planned)
│   ├── frontend-examples/         (Planned)
│   └── README.md
│
└── scripts/                         Utility Scripts
    └── README.md                   (Planned)
```

---

## Key Concepts

### Baukasten System

**Capsules are assembled from modules:**

Required:
- Core Burn
- Self-Sealing
- Post-Human

Optional:
- Variable Burn Rates
- Oracle System
- Batch Minting
- Burn TX Tracking
- Custom Metadata

**See:** `/contracts/templates/`

### Submission Process

1. Build capsule (using baukasten)
2. Deploy & verify
3. Renounce ownership
4. Submit PR with docs + metadata
5. Community review
6. If approved → Listed on grokme.io

**See:** `/implementations/SUBMISSION-TEMPLATE.md`

---

## For Different Audiences

### Developers
→ `/docs/implementation/`

### Philosophers
→ `PHILOSOPHY.md`

### Mathematicians
→ `MATHEMATICS.md`

### Implementers
→ `/contracts/templates/`  
→ `/implementations/SUBMISSION-TEMPLATE.md`

### Infrastructure Operators
→ `/infrastructure/`  
→ `/docs/infrastructure/`

---

**Updated:** February 2026  
**Maintained by:** Open source contributors (GitHub)

