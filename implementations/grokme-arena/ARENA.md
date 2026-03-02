# GROKME ARENA
## Proof-of-Culture Protocol
### The On-Chain Meme Battle Standard

**STATUS:** 🟡 In active development — Challenges launching Q2 2026  
**WEBSITE:** [arena.grokme.me](https://arena.grokme.me)  
**ARENA CONTRACT:** `0x97a38be1cE4257b80CcEc01b0F2c71810624d803`  
**TROPHY NFT CONTRACT:** `0x33eAB69746De54Db570f21FE6099DBEf695d1C42`  
**GROK TOKEN:** `0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5`  
**DEPLOY BLOCK:** 24571121 · March 2026  
**PROTOCOL:** [GROKME Protocol](https://github.com/grokme-io/protocol)

---

> *"We don't gamble. We prove culture. The better meme wins. The proof is eternal."*

---

## Overview

GROKME Arena is the first application built on the GROKME Protocol beyond NFT minting. It is a fully on-chain Meme Battle platform — the **Proof-of-Culture (PoC)** standard for meme communities to compete, prove cultural dominance, and contribute deflationary pressure to their own tokens simultaneously.

A challenger creates a meme, stakes tokens on it, and dares an opponent to bring something better. The community votes. The winning meme becomes an eternal Trophy NFT. The losing meme is destroyed. All staked tokens from both sides burn.

**The meme is the weapon. The tokens are the stakes. The blockchain is the judge.**

---

## Protocol Compliance

GROKME Arena burns GROK on every battle — regardless of which tokens fight:

| CHECK | STATUS |
|-------|--------|
| Uses GROK burn mechanics | ✅ 5% of every stake auto-swapped to GROK → burned |
| Burns to `0x000...dEaD` | ✅ 100% of staked tokens + protocol fee |
| Post-human design | ✅ Arena contract renounced — no admin key, no upgrade proxy |
| Contract verified | ✅ Etherscan verified |
| Zero extraction | ✅ Nobody receives tokens. Winner gets NFT, not tokens. |

---

## How It Works — Five Phases

| PHASE | NAME | DESCRIPTION |
|-------|------|-------------|
| 01 | CHALLENGE | A holder uploads a meme, stakes tokens, challenges a rival community |
| 02 | ACCEPT & RAISE | Opponent answers with their meme and matching or higher stake — poker-style bidding |
| 03 | BATTLE | Both memes go public, campaigns begin, the viral war ignites |
| 04 | VOTING | On-chain, snapshot-verified, provably unfakeable community voting determines the winner |
| 05 | SETTLEMENT | Winning meme minted as eternal Trophy NFT. Losing meme destroyed. All tokens burn. |

### Phase 1 — THE CHALLENGE

Any ERC-20 meme token holder issues a Battle Challenge via the Arena smart contract:

- **The Meme** — image or video uploaded to GROKME Arena, stored as a GROKME Capsule
- **The Stake** — ERC-20 tokens deposited into non-custodial escrow
- **The Target** — a specific rival community, or an **Open Challenge** (any token can answer, including same-token duels)
- **Battle Duration** — 24h, 48h, or 72h voting window

Unanswered targeted challenges expire after 72h — tokens are refunded minus the 5% protocol fee (already burned). The unanswered challenge is recorded permanently on-chain: *"[Community X] was challenged and didn't show up."*

### Phase 2 — ACCEPT & RAISE (Poker-Style Bidding)

| ACTION | WHAT HAPPENS |
|--------|-------------|
| **MATCH** | Opponent matches the challenger's stake. Battle starts immediately. |
| **RAISE** | Opponent exceeds the stake. Challenger must respond. |
| **CALL** | Challenger matches the raised amount. Battle starts. |
| **FOLD** | Challenger withdraws. Tokens returned. Fold recorded permanently on-chain. |
| **RE-RAISE** | Challenger exceeds the opponent's raise. |

The bidding cycle continues until both sides are locked at equal USD-equivalent value (via Chainlink price feeds). Maximum 3 raise rounds. If a side goes silent, `forceStartAfterTimeout()` can be called by anyone after the timeout — the non-responding side is treated as having called.

### Phase 3 — THE BATTLE

Once locked, the battle page goes live. Both memes face each other publicly. Both communities unleash their viral campaigns across X, Telegram, Discord, Reddit, TikTok. The battle page displays both memes, total tokens at stake, live vote counts, and countdown timer.

Both memes are stored as **GROKME Capsules** from the moment the battle begins — decentralized, immutable, censorship-resistant.

### Phase 4 — PROVABLY UNFAKEABLE VOTING

Five independent anti-manipulation layers:

1. **Renounced Contract** — no admin key, no `onlyOwner`, no upgrade path. Mathematically impossible to manipulate.
2. **On-chain votes** — every `castVote()` emits a public `VoteCast(battleId, voterAddress, team, tokenBalance)` event. Anyone can independently tally from Etherscan.
3. **Balance snapshot** — token balances at the snapshot block determine eligibility. Prevents buying tokens mid-battle.
4. **Anti-Sybil** — 1 wallet = 1 vote. Minimum token balance threshold. Voters for Team A must hold Team A's token at snapshot. Cross-voting impossible.
5. **Permissionless settlement** — `settleBattle()` is callable by **anyone** after the voting window. No human gatekeeper.

### Phase 5 — SETTLEMENT

`settleBattle()` executes automatically with no human intervention:

**Winner:**
- Vote counts finalized on-chain permanently
- Winning meme minted as **GROKME Battle Trophy NFT** — contains the meme, battle metadata, vote counts, burn tx hashes, creator wallet
- Trophy NFT sent to winning creator's wallet

**Loser:**
- Losing meme destroyed — not preserved, not stored permanently
- Exists only as ghost metadata: a record that a meme was submitted, fought, and lost

**Both Stakes:**
- Challenger's tokens → `0x000...dEaD` (permanent burn)
- Opponent's tokens → `0x000...dEaD` (permanent burn)

---

## GROK Protocol Fee — Every Battle Burns GROK

A fixed 5% of every stake deposited is automatically swapped to GROK via Uniswap V2 and sent to `0x000...dEaD`. This happens at deposit — not at settlement.

```
FrogLord stakes 50,000,000 PEPE (~$5,000):
  → 2,500,000 PEPE (5%) → swap → ~$250 GROK → burned immediately
  → 47,500,000 PEPE locked in escrow

ShibArmy stakes 200,000,000 SHIB (~$5,000):
  → 10,000,000 SHIB (5%) → swap → ~$250 GROK → burned immediately
  → 190,000,000 SHIB locked in escrow

Battle settles → 47.5M PEPE burned + 190M SHIB burned
GROK burned from fees: ~$500 worth

Result: PEPE ↓ + SHIB ↓ + GROK ↓  Everyone wins tokenomically.
```

The fee is **non-refundable** — even if the challenge expires unanswered, even if someone folds. This is the cost of stepping into the Arena.

---

## Smart Contract Functions

| FUNCTION | DESCRIPTION |
|----------|-------------|
| `issueChallenge(token, amount, targetToken, duration, memeHash, minVoterBal)` | Create challenge. If `targetToken == address(0)` → Open Challenge |
| `acceptChallenge(battleId, token, amount, memeHash)` | Accept and optionally raise |
| `raise(battleId, additionalAmount)` | Raise the stake during bidding |
| `call(battleId, additionalAmount)` | Match a raise and lock both sides |
| `fold(battleId)` | Withdraw from bidding — recorded permanently |
| `forceStartAfterTimeout(battleId)` | Force start if opponent goes silent |
| `castVote(battleId, team)` | Cast one on-chain vote |
| `settleBattle(battleId)` | Permissionless settlement after voting window |

---

## Token Economics Example — GROK vs PEPE

| PARAMETER | TEAM GROK | TEAM PEPE |
|-----------|-----------|-----------|
| Initial Stake | 5,000,000 GROK (~$2,500) | — |
| Raise | — | 24,000,000 PEPE (~$4,000) |
| Call | +3,000,000 GROK (total ~$4,000) | — |
| Final Locked | 8,000,000 GROK | 24,000,000 PEPE |
| Result (example) | **Trophy NFT minted** ✅ | Meme destroyed ❌ |
| Token Outcome | 8M GROK → `0x...dEaD` | 24M PEPE → `0x...dEaD` |

---

## Roadmap

| PHASE | STATUS | DELIVERABLES |
|-------|--------|--------------|
| Contracts | ✅ Complete | Arena + Trophy deployed on Ethereum Mainnet (Block 24571121). 100/100 tests passing. |
| Frontend | ✅ Live | arena.grokme.me — Arena landing page, challenge lockdown during dev phase |
| Genesis Battle | 🔜 Q2 2026 | First public battle: GROK vs. PEPE. First Trophy NFT minted. |
| Challenge Board | 🔜 Q2 2026 | Public challenge creation enabled. Open Challenge Board live. |
| Community Expansion | Q2 2026 | Outreach to top ETH meme communities. Community profiles. Legends Hall. |
| Fan Staking | Q2 2026 | Any community member can add tokens to the battle pot. |
| Multi-Chain | Q3 2026 | Base Chain deployment for low-gas battles. |
| Protocol Standard | Q4 2026 | Open-source Battle Contract SDK for other communities to self-host. |

---

## Links

- **Arena:** [arena.grokme.me](https://arena.grokme.me)
- **Arena Contract (Etherscan):** [0x97a38be1...1c803](https://etherscan.io/address/0x97a38be1cE4257b80CcEc01b0F2c71810624d803)
- **Trophy NFT Contract (Etherscan):** [0x33eAB697...1C42](https://etherscan.io/address/0x33eAB69746De54Db570f21FE6099DBEf695d1C42)
- **GROKME Protocol:** [github.com/grokme-io/protocol](https://github.com/grokme-io/protocol)
- **GROKME.ME (NFT):** [grokme.me](https://grokme.me)

---

*The culture that burns together, lasts forever.*
