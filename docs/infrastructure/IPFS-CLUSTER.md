# IPFS Cluster: Eternal Storage Architecture

## The Permanence Challenge

**Common misconception:**
```
"Uploaded to IPFS" = "Permanent"
```

**Reality:**
```
"Pinned on active nodes" = "Available"
```

IPFS provides content-addressing, not automatic permanence.

---

## The Solution: IPFS Cluster

Based on **[ipfscluster.io](https://ipfscluster.io/)** — battle-tested infrastructure powering nft.storage and web3.storage.

### What Is IPFS Cluster?

**Distributed application** managing a swarm of IPFS daemons:

- Allocates content across multiple nodes
- Replicates for redundancy
- Tracks global pinset (conflict-free)
- Automatically rebalances on failures
- Scales to millions of pins across hundreds of nodes

**Built on libp2p** — the same networking library powering IPFS, Filecoin, and Ethereum 2.0.

---

## Architecture

### Component Layers

```
┌─────────────────────────────────────────────────┐
│         IPFS Cluster Control Layer              │
│  (Coordination, Replication, Monitoring)        │
└────────┬──────────┬──────────┬──────────────────┘
         │          │          │
    ┌────▼────┐ ┌──▼────┐ ┌───▼────┐
    │Peer EU  │ │Peer US│ │Peer Asia│
    │(Frankfurt)│(Virginia)│(Singapore)│
    └────┬────┘ └──┬────┘ └───┬────┘
         │          │          │
    ┌────▼────┐ ┌──▼────┐ ┌───▼────┐
    │IPFS Node│ │IPFS Node│ │IPFS Node│
    │+ Storage│ │+ Storage│ │+ Storage│
    │  500GB  │ │  500GB  │ │  500GB  │
    └─────────┘ └────────┘ └─────────┘
```

### How It Works

1. **Content added** to cluster (via API or event trigger)
2. **Cluster decides** which nodes should pin it (allocation strategy)
3. **Nodes pin content** asynchronously ("fire & forget")
4. **Cluster tracks** pin status across all peers
5. **Failures detected** → automatic re-pinning on healthy nodes
6. **Result:** Content permanently available, self-healing

---

## Key Features

### 1. Automatic Replication

**Configuration:**
```yaml
replication_factor_min: 3
replication_factor_max: 5
```

Every piece of content stored on **minimum 3 nodes**, up to 5 for critical data.

**Geographic distribution:**
- Europe (primary)
- North America (secondary)
- Asia (tertiary)
- Future: South America, Africa

### 2. Intelligent Allocation

**Balanced strategy:**
```yaml
allocator:
  balanced:
    allocate_by: ["region", "freespace"]
```

Cluster chooses nodes based on:
- Geographic distribution (avoid single-region failure)
- Available storage space (balance load)
- Current pin count (distribute evenly)

**Result:** No single node becomes bottleneck.

### 3. Self-Healing

**Failure detection:**
- Heartbeat monitoring (every 30 seconds)
- Peer status checking
- Pin verification queries

**Automatic recovery:**
```
Node fails → Cluster detects (< 1 minute)
          → Selects healthy node
          → Re-pins content
          → Status updated
```

**Human intervention:** Not required.

### 4. Scalability

**Current implementations handle:**
- **Millions of pins** across cluster
- **Hundreds of IPFS nodes** coordinated
- **Hundreds of pins per second** ingestion rate
- **Petabytes of data** distributed

**GROKME scale:**
- Genesis: 6.9 GB (~10,000-13,000 NFTs)
- Future capsules: TBD
- Total: Well within tested limits

### 5. No Central Server

**Raft consensus** (distributed agreement):
```
Peer 1 (Leader) ←→ Peer 2 (Follower)
       ↕                    ↕
   Peer 3 (Follower) ←→ Peer 4 (Follower)
```

- Cluster state replicated across all peers
- Leader election automatic on failure
- Conflict-free (eventually consistent)
- No single point of failure

---

## Mathematical Availability

### Probability Model

**Given:**
- N = 15 nodes globally
- R = 3 (replication factor)
- p = 0.99 (99% individual node uptime)

**Content unavailability:**
```
P(unavailable) = (1 - p)^R
               = (1 - 0.99)^3
               = (0.01)^3
               = 0.000001
               = 1 in 1,000,000 chance
```

**Availability:**
```
With 3 nodes across continents:
All 3 must fail simultaneously = (0.01)^3

Practical reality:
Requires coordinated multi-continent infrastructure collapse.
```

**Fails only if civilization ends.**

### Geographic Distribution Advantage

**With 5 continents, 3 nodes each:**

Single region outage probability: 1% per year

**Multi-region simultaneous outage:**
```
P(2 regions down) = (0.01)^2 = 0.0001
P(3 regions down) = (0.01)^3 = 0.000001
```

**Expected time to global loss:**
```
MTTF = 1 / (0.01)^5
     = 1 / 10^-10
     = 10^10 years

(Universe age: 1.38 × 10^10 years)
```

**Cosmological-scale reliability.**

---

## Implementation for GROKME

### Deployment Strategy

**Phase 1: Genesis Launch**
```
Nodes: 3 (EU, US, Asia)
Replication: 3x minimum
Storage: 1.5 TB total (500GB each)
Cost: ~$540/month
```

**Phase 2: Growth**
```
Nodes: 10 (5 continents × 2)
Replication: 3-5x
Storage: 5 TB total
Cost: ~$1,200/month
```

**Phase 3: Mature**
```
Nodes: 15-20 globally
Replication: 3-5x adaptive
Storage: 10+ TB
Cost: ~$1,800/month
```

### Cluster Configuration

**Example cluster-config.json:**
```json
{
  "cluster": {
    "peername": "grokme-cluster-eu-01",
    "secret": "<32-byte-hex-shared-secret>",
    "replication_factor_min": 3,
    "replication_factor_max": 5,
    "monitor_ping_interval": "30s"
  },
  "consensus": {
    "raft": {
      "commit_retries": 2,
      "commit_retry_delay": "200ms",
      "heartbeat_timeout": "1s",
      "election_timeout": "3s"
    }
  },
  "allocator": {
    "balanced": {
      "allocate_by": ["tag:region", "freespace"]
    }
  },
  "pintracker": {
    "stateless": {
      "max_pin_queue_size": 1000000,
      "concurrent_pins": 10
    }
  }
}
```

**Key parameters:**
- `replication_factor_min: 3` — Always 3+ copies
- `allocate_by: region` — Geographic distribution
- `concurrent_pins: 10` — Pin 10 items simultaneously
- `max_pin_queue_size: 1M` — Can queue massive pinsets

### Automatic Pinning

**On NFT mint event:**
```javascript
// Backend webhook (triggered by smart contract event)
async function onGrokked(event) {
  const { tokenId, ipfsURI } = event;
  const cid = extractCID(ipfsURI);
  
  // Add to cluster (fire & forget)
  await clusterClient.pin.add(cid, {
    name: `genesis-${tokenId}`,
    replicationFactorMin: 3,
    replicationFactorMax: 5,
    metadata: {
      tokenId,
      capsule: 'genesis',
      timestamp: Date.now()
    }
  });
  
  console.log(`✓ Pinned: ${cid} (Token #${tokenId})`);
}
```

**Cluster handles:**
- Allocation to appropriate nodes
- Asynchronous pinning
- Retry on failure
- Status tracking

---

## Monitoring & Health

### Cluster Status API

```bash
# Check cluster health
ipfs-cluster-ctl status

# Output:
# cid123... : Status: pinned
#   - peer-eu-01     | pinned
#   - peer-us-01     | pinned
#   - peer-asia-01   | pinned
```

### Automated Monitoring

**Health checks (every 5 minutes):**
```javascript
async function monitorClusterHealth() {
  const status = await clusterClient.status();
  
  for (const [cid, peerStatus] of Object.entries(status)) {
    const pinned = Object.values(peerStatus)
      .filter(s => s.status === 'pinned').length;
    
    if (pinned < 3) {
      await alert(`WARNING: ${cid} only on ${pinned} nodes!`);
      await clusterClient.pin.add(cid); // Force re-pin
    }
  }
}
```

### Dashboard Metrics

**Public dashboard (status.grokme.me):**
- Total CIDs in cluster
- Average replication factor
- Per-node health status
- Storage usage per region
- Recent pin operations
- Failure events (last 30 days)

---

## Infrastructure Approach

### Shared Cluster Infrastructure

Multiple capsules share same IPFS Cluster nodes for improved efficiency and sustainability.

**Advantages:**
- Full control (no vendor lock-in)
- Censorship-resistant
- Multi-protocol usage
- No bandwidth limits
- True permanence guarantee

---

## For Implementers

### Deploy Your Own Cluster

**Step 1: Install IPFS Cluster**
```bash
# Download latest release
wget https://dist.ipfs.io/ipfs-cluster-service/v1.0.0/ipfs-cluster-service_v1.0.0_linux-amd64.tar.gz

# Extract
tar xvf ipfs-cluster-service_v1.0.0_linux-amd64.tar.gz

# Initialize
./ipfs-cluster-service init
```

**Step 2: Configure**
```bash
# Edit ~/.ipfs-cluster/service.json
# Set replication factors, consensus, etc.
```

**Step 3: Start Daemon**
```bash
ipfs-cluster-service daemon
```

**Step 4: Add Peers**
```bash
# On second node
ipfs-cluster-service daemon --bootstrap /ip4/FIRST-NODE-IP/tcp/9096/p2p/PEER-ID
```

**Step 5: Pin Content**
```bash
ipfs-cluster-ctl pin add QmYourCID
```

### Using Docker Compose

See [`/infrastructure/ipfs-cluster/docker-compose.yml`](../../infrastructure/ipfs-cluster/docker-compose.yml) for ready-to-deploy configuration.

### Using Akash Network

See [`/infrastructure/akash/cluster-node.yaml`](../../infrastructure/akash/cluster-node.yaml) for decentralized deployment template.

---

## Security Considerations

### Cluster Secret

**Critical:** `cluster.secret` must be securely shared among all peers.

```bash
# Generate shared secret
od -vN 32 -An -tx1 /dev/urandom | tr -d ' \n'

# Store securely (e.g., password manager)
# Share via secure channel (not GitHub!)
```

### Network Security

**Firewall rules:**
```
Allow:
- 9094/tcp (API)
- 9095/tcp (Proxy API)
- 9096/tcp (Cluster swarm)

Restrict:
- API only from trusted IPs
- Swarm only from cluster peers
```

### Access Control

**Follower peers** (read-only):
```json
{
  "cluster": {
    "follower_mode": true
  }
}
```

Can store content but cannot modify pinset.

**Use case:** Community guardian nodes.

---

## Comparison: IPFS Cluster vs. Alternatives

| Feature | IPFS Cluster | Pinata | Filecoin | Self-Hosted IPFS |
|---------|--------------|--------|----------|------------------|
| **Redundancy** | 3-5x automatic | Provider-dependent | Contract-based | Manual |
| **Self-healing** | ✅ Yes | ✅ Yes | ⚠️ Manual renewal | ❌ No |
| **Geographic** | ✅ Full control | ⚠️ Limited | ✅ Configurable | ✅ Full control |
| **Censorship resistance** | ✅ High | ⚠️ Moderate | ✅ High | ✅ High |
| **Control** | ✅ Full | ❌ None | ⚠️ Contract | ✅ Full |
| **Complexity** | ⚠️ Moderate | ✅ Easy | ⚠️ Moderate | ⚠️ High |

**GROKME strategy:** IPFS Cluster for long-term infrastructure, Filecoin for post-seal economic layer.

---

## Conclusion

IPFS Cluster provides:

✅ **Civilization-grade resilience** (multi-continent redundancy)  
✅ **Self-healing** (automatic recovery)  
✅ **Geographic distribution** (survives regional collapse)  
✅ **Scalability** (millions of pins)  
✅ **No single point of failure** (distributed consensus)  
✅ **Battle-tested** (nft.storage, web3.storage)  
✅ **Open source** (auditable, forkable)

**For GROKME Protocol:**

Content survives unless civilization ends. **That's the standard.**

---

**Built on [ipfscluster.io](https://ipfscluster.io/) — powering the permanent web.**

