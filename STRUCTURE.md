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
│   │   ├── GENESIS.md              Full docs
│   │   └── metadata.json           Structured data
│   ├── coming-soon/                In development
│   ├── SUBMISSION-TEMPLATE.md      How to submit
│   └── README.md                   Registry guide
│
├── contracts/                       Smart Contracts
│   ├── templates/                  Baukasten System
│   │   ├── modules/                Individual modules
│   │   └── README.md               Assembly guide
│   ├── mainnet/
│   │   ├── GrokMeGenesis.sol      Reference implementation
│   │   └── README.md              GROK + Genesis docs
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
│   └── security/                   Security model
│       └── SECURITY-MODEL.md      Attack surface analysis
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

**Updated:** October 2025  
**Maintained by:** Open source contributors (GitHub)

