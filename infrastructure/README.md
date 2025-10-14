# Infrastructure Templates

Deployment templates for GROKME Protocol infrastructure.

## Contents

### IPFS Cluster
Distributed storage infrastructure for eternal content preservation.

- **cluster-config.yaml** - Production cluster configuration
- **docker-compose.yml** - Local 3-node cluster for testing
- **README.md** - Setup and deployment guide

See [/docs/infrastructure/IPFS-CLUSTER.md](../docs/infrastructure/IPFS-CLUSTER.md)

### Akash Network
Decentralized cloud deployment templates.

- **cluster-node.yaml** - Deploy IPFS Cluster node on Akash
- **monitoring.yaml** - Prometheus + Grafana stack (planned)
- **README.md** - Deployment instructions

See [/docs/infrastructure/AKASH-DEPLOYMENT.md](../docs/infrastructure/AKASH-DEPLOYMENT.md)

### Monitoring
Observability stack for infrastructure health.

- Coming soon: Prometheus, Grafana, AlertManager configs

## Security Notice

**NEVER commit secrets to version control:**

- ❌ Cluster secrets
- ❌ Private keys
- ❌ API tokens
- ❌ Wallet credentials

All templates use placeholders (`YOUR_SECRET_HERE`). Replace before deployment.

## Quick Start

### Local Testing (IPFS Cluster)

```bash
cd ipfs-cluster/

# Set cluster secret
export CLUSTER_SECRET=$(od -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')

# Start 3-node cluster
docker-compose up -d

# Check status
docker exec grokme-cluster-1 ipfs-cluster-ctl peers ls

# Add content
echo "Hello GROKME" > test.txt
docker exec grokme-cluster-1 ipfs-cluster-ctl add /test.txt

# Verify replication (should show 3 nodes)
docker exec grokme-cluster-1 ipfs-cluster-ctl status <CID>
```

### Production Deployment (Akash)

```bash
cd akash/

# 1. Install Akash CLI
curl https://raw.githubusercontent.com/akash-network/node/main/install.sh | bash

# 2. Create wallet
akash keys add my-wallet

# 3. Fund wallet with AKT tokens

# 4. Edit cluster-node.yaml
#    - Replace CLUSTER_SECRET
#    - Replace CLUSTER_PEERNAME
#    - Replace BOOTSTRAP peers

# 5. Deploy
akash tx deployment create cluster-node.yaml --from my-wallet

# 6. Accept bid
akash query market lease list --owner <your-address>
akash tx market lease create --dseq <seq> --provider <provider>

# 7. Monitor
akash provider lease-logs --dseq <seq> --provider <provider>
```

## Cost Estimates

| Infrastructure | Provider | Monthly Cost |
|----------------|----------|--------------|
| IPFS Cluster (3 nodes) | Self-hosted | $240 |
| IPFS Cluster (3 nodes) | Akash | $90-120 |
| Monitoring stack | Self-hosted | $40 |
| Monitoring stack | Akash | $15-20 |

**Akash savings:** ~60-70% vs. traditional hosting

## Architecture

```
┌──────────────────────────────────────┐
│        IPFS Cluster Control          │
│    (3-5 peers, global distribution)  │
└────────┬────────┬───────────┬────────┘
         │        │           │
    ┌────▼──┐ ┌──▼────┐ ┌────▼───┐
    │ EU    │ │ US    │ │ Asia   │
    │ Node  │ │ Node  │ │ Node   │
    └───────┘ └───────┘ └────────┘
         │        │           │
    ┌────▼──┐ ┌──▼────┐ ┌────▼───┐
    │ IPFS  │ │ IPFS  │ │ IPFS   │
    │500GB  │ │500GB  │ │500GB   │
    └───────┘ └───────┘ └────────┘
```

**Replication:** 3x minimum per content  
**Availability:** 99.9999% (six nines)  
**Self-healing:** Automatic on node failure

## Resources

- **IPFS Cluster:** https://ipfscluster.io/
- **Akash Network:** https://akash.network/
- **IPFS:** https://ipfs.io/
- **Prometheus:** https://prometheus.io/
- **Grafana:** https://grafana.com/

## Support

For infrastructure questions:
- See main documentation in `/docs/infrastructure/`
- Review configuration examples in this directory
- Check issue tracker for known problems

**Remember:** All infrastructure is optional. The protocol itself lives on-chain. These tools enable implementations.

