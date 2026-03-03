# Immunefi Bug Bounty Program — Setup Template

**Protocol:** GROKME  
**Platform:** https://immunefi.com/build  

Copy-paste into the Immunefi program creation form.

---

## Program Name
`GROKME Protocol`

## Project URL
`https://battle.grokme.me`

## One-liner
`Decentralized on-chain Meme Battle Protocol and Burn-to-Mint Capsule Registry on Ethereum Mainnet. All staked tokens burn. Oracle-signed minting. No admin keys on Arena/Trophy. Renounced.`

## Full Description

```
GROKME is a two-component protocol on Ethereum Mainnet:

1. GROKME Arena (battle.grokme.me)
   A Proof-of-Culture Meme Battle Protocol. Challengers stake ERC-20 community
   tokens behind a meme. The community votes on-chain (1 wallet = 1 vote, 
   token-gated). Winning meme becomes a permanent ERC-721 Trophy NFT. All 
   staked tokens from both sides burn to 0x...dEaD on settlement. A 5% 
   protocol fee on every deposit is automatically swapped to GROK and burned.
   The Arena and Trophy contracts are fully renounced — no admin keys, no owner,
   no upgrade proxy, no kill switch.

2. GROK NFT (grokme.me)
   Burn-to-Mint Cultural Capsule Registry. Users burn GROK tokens proportional
   to content size (bytes × burnRate/KB) to register an IPFS-stored digital 
   capsule as an ERC-721 NFT. Token IDs are assigned by an oracle via EIP-712
   signed messages. Capacity seals permanently at 6.9 GB total content.

Contracts:
- GrokmeArena:       0x97a38be1cE4257b80CcEc01b0F2c71810624d803
- GrokmeArenaTrophy: 0x33eAB69746De54Db570f21FE6099DBEf695d1C42
- GrokNFT:           [see github.com/grokme-io/protocol/contracts/mainnet/]
- GROK Token:        0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5 (external)

Source: https://github.com/grokme-io/protocol
Audit package: https://github.com/grokme-io/protocol/tree/main/docs/security/audit
```

---

## In-Scope Assets

```
GrokmeArena          0x97a38be1cE4257b80CcEc01b0F2c71810624d803  Ethereum Mainnet
GrokmeArenaTrophy    0x33eAB69746De54Db570f21FE6099DBEf695d1C42  Ethereum Mainnet
GrokNFT              [address]                                     Ethereum Mainnet
```

## Out of Scope

- GROK Token (`0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5`) — external contract
- Uniswap V2 Router — external protocol
- OpenZeppelin standard library
- Frontend / off-chain API / oracle backend code
- GrokHeritageNFT
- Gas optimization reports
- Issues requiring privileged access already documented as accepted design
- Economic attacks on GROK token price (external market)

---

## Bounty Amounts

### Smart Contract

| Severity | Bounty |
|---|---|
| **Critical** | Up to $10,000 USDC |
| **High** | Up to $3,000 USDC |
| **Medium** | Up to $1,000 USDC |
| **Low** | $100 USDC |

> **Note on Critical:** The Arena burns all funds — there is no treasury or extractable value for an attacker. A true Critical implies a path to minting NFTs with zero GROK burned, or permanently locking user funds with no recovery path.

---

## Severity Definitions

**Critical:**
- Minting GrokNFT without any GROK having been burned (outside the documented oracle/burnTx trust model)
- Permanent locking of any user's staked tokens in the Arena
- Complete bypass of `settleBattle()` burn (tokens survive to an attacker wallet)
- Minting multiple Trophy NFTs for the same battle

**High:**
- Battle outcome determined incorrectly (wrong winner on-chain)
- Single wallet casting more than one vote per battle without oracle/owner involvement
- Protocol fee consistently not burned (non-fallback scenario, realistic tokens)
- `totalBytesMinted` overflow causing capacity gate bypass

**Medium:**
- Specific battles permanently unresolvable (DoS on individual battle)
- `minVoterBalance` check bypassable
- `burnTxUsed` accounting manipulation allowing more burns than registered

**Low:**
- Event emission inconsistencies
- Minor access control gaps on view functions
- Issues exploitable only by the oracle/owner with no user fund impact

---

## Known Issues — Do Not Report

Reports covering the following will be closed as `Won't Fix`:

1. `amountOutMin = 0` in Uniswap swap (intentional — output burns to dead address)
2. Live balance check in `castVote()` instead of snapshot (V1 known limitation)
3. Tie-breaking favors challenger (documented design)
4. Trophy mint failure is silent try/catch (burn must not be blocked)
5. `SETTLEMENT_WINDOW` constant defined but unused (cleanup item)
6. `burnTx` path allows minting without live `transferFrom` (intended pre-burn feature)
7. `totalGrokBurned` does not count fallback fee-token burns (correct by definition)
8. `Ownable` on GrokNFT with no owner functions except renounce (pre-renounce only)

Full list: https://github.com/grokme-io/protocol/blob/main/docs/security/audit/SCOPE.md

---

## Proof of Concept Requirements

All High and Critical reports must include a working PoC:

```bash
# Hardhat fork of mainnet or Sepolia testnet
npx hardhat test test/your-poc.js --network hardhat
```

Required in every report:
1. Affected contract(s) and function(s) with line numbers
2. Step-by-step attack description
3. Working test demonstrating the issue
4. Impact assessment (what funds/behavior affected, under what conditions)
5. Suggested fix (optional but appreciated)

Reports without PoC for High/Critical will be downgraded or rejected.

---

## Program Rules

- First valid report of a unique vulnerability receives the bounty (no duplicate payments)
- Do NOT exploit vulnerabilities on mainnet — use Hardhat fork or Sepolia
- Do NOT disclose publicly before we acknowledge and respond
- Social engineering, phishing, and frontend attacks are out of scope
- Testing must not disrupt live protocol operations
- Responsible disclosure: we commit to public post-mortem after fix (if applicable)

---

## Response SLA

| Action | Commitment |
|---|---|
| Acknowledgement | 48 hours |
| Initial assessment | 7 days |
| Bounty payment (valid reports) | Within 14 days of confirmation |

**Security contact:** security@grokme.me

---

## Vault Funding

**Recommended initial vault:** $5,000–$10,000 USDC  
**Minimum to publish:** $1,000 USDC  
**Top-up trigger:** Replenish if vault falls below $2,000  
**Accepted tokens:** USDC, USDT, DAI, ETH

**Vault setup:** Generate a dedicated Immunefi vault address through the platform dashboard. Do not reuse a hot wallet address.

---

## Publication Checklist

- [ ] Vault funded (minimum $1,000 USDC)
- [ ] Etherscan links verified and contracts readable
- [ ] `grokme-io/protocol` repo public and audit package linked
- [ ] Known issues list complete and up to date
- [ ] `security@grokme.me` inbox monitored
- [ ] Response SLA confirmed with team
- [ ] Immunefi review completed (2–5 business days after submission)
