# Utility Scripts

Helper scripts for working with GROKME Protocol.

---

## Planned Scripts

### calculate-rarity.js
Calculate NFT rarity score from on-chain data:
```bash
node scripts/calculate-rarity.js --tokenId 42 --contract 0x...
```

### verify-contract.js
Verify implementation compliance with protocol:
```bash
node scripts/verify-contract.js --address 0x...
```

### ipfs-pin-helper.js
Batch pin NFTs to IPFS Cluster:
```bash
node scripts/ipfs-pin-helper.js --contract 0x... --cluster http://localhost:9094
```

### deployment-helper.js
Automated contract deployment with verification:
```bash
node scripts/deployment-helper.js --network mainnet --verify
```

### analytics.js
Fetch on-chain analytics for capsule:
```bash
node scripts/analytics.js --contract 0x... --output stats.json
```

---

## Current Status

Scripts will be added in Phase 2.

**For now, use:**
- Etherscan for contract verification
- Hardhat scripts for deployment
- IPFS Cluster CLI for pinning

---

**Contributions welcome. Submit PR with useful utility scripts.**

