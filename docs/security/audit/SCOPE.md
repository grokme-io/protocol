# Audit Scope

**Protocol:** GROKME  
**Chain:** Ethereum Mainnet  
**Solidity:** 0.8.20 / OpenZeppelin 4.9.x  

---

## In-Scope Contracts

### 1. GrokmeArena — `0x97a38be1cE4257b80CcEc01b0F2c71810624d803`

All external/public state-changing functions:

| Function | Risk Category | Notes |
|---|---|---|
| `issueChallenge()` | Token transfer, fee logic | Fee-on-transfer safety via balance delta |
| `acceptChallenge()` | Token transfer, state transition | Targeted token validation |
| `raise()` | Token transfer, turn enforcement | `pendingResponse` check |
| `call()` | Token transfer, battle start | `additionalAmount = 0` valid |
| `fold()` | Token refund, state change | Refunds both sides minus burned fees |
| `expireChallenge()` | Token refund, permissionless | 72h window |
| `castVote()` | Sybil resistance, token balance check | Live balance, not snapshot |
| `settleBattle()` | Burn all tokens, winner determination, Trophy mint | Permissionless |
| `forceStartAfterTimeout()` | Bidding timeout bypass | 24h inactivity |
| `_burnProtocolFee()` | Uniswap V2 swap → GROK burn | `amountOutMin=0`, try/catch fallback |
| `_depositWithFee()` | Fee-on-transfer token safety | balance-before/after delta |
| `_startBattle()` | Snapshot block, timer start | `block.number` for snapshot |
| `_mintTrophy()` | Cross-contract call to Trophy | try/catch — silent on failure |

Key state:
- `battles` mapping — primary state store
- `hasVoted[battleId][wallet]` — vote deduplication
- `battleGrokFees[battleId]` — per-battle GROK fee tracking
- `totalGrokBurned` — global counter

### 2. GrokmeArenaTrophy — `0x33eAB69746De54Db570f21FE6099DBEf695d1C42`

| Function | Risk Category | Notes |
|---|---|---|
| `mintTrophy()` | Access control, one-per-battle | `msg.sender == arenaMinter` |
| `setTrophyURI()` | Access control | Arena or token owner can set |
| `getTrophy()` / `getTrophyForBattle()` | View — off-by-one | `battleToToken` uses `+1` offset |

### 3. GrokNFT — `0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`

| Function | Risk Category | Notes |
|---|---|---|
| `mint(ipfsURI, grokBurnAmount)` | Tier validation, token burn, supply cap | Primary mint — exact amount matching |
| `setContractURI(newURI)` | Metadata control | `onlyOwner` — metadata pointer only |

Key state:
- `currentTokenId` — sequential mint counter, hard cap at 690
- `commonMinted` / `rareMinted` / `epicMinted` / `legendaryMinted` / `divineMinted` / `unicornMinted` — per-tier counters
- `tokenBurnAmount[tokenId]` — burn amount recorded per token
- `totalGrokBurned` — global burn counter
- `_contractURI` — owner-settable metadata URI

---

## Out of Scope

- **GROK Token** (`0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5`) — external, owner renounced
- **Uniswap V2 Router** — external protocol
- **OpenZeppelin standard library** — audited upstream
- **Frontend / off-chain indexer / API / oracle backend** — not smart contract scope
- **GrokHeritageNFT** — not part of this audit engagement
- **`contracts/mainnet/GrokNFT.sol` in this repo** — that is an unreleased future version; the deployed contract at `0x5ee102ab...` is the audit target
- **Gas optimization** — not a focus for this protocol
- **Economic/tokenomics attacks on GROK price** — accepted market risk

---

## Known Issues — Do Not Report

The following are **intentional design choices**. Submissions covering these will be closed as `Won't Fix`:

### K-01: `amountOutMin = 0` in Uniswap swap
**Location:** `GrokmeArena._burnProtocolFee()`  
**Rationale:** Swap output (GROK) goes directly to `0x...dEaD`. MEV sandwich gives attackers zero benefit — our GROK still burns. Maximum attacker gain = marginally more GROK in their own sandwich, all at their cost.

### K-02: Live balance check in `castVote()` — not snapshot-based
**Location:** `GrokmeArena.castVote()`  
**Rationale:** Snapshot voting requires GROK token to implement `ERC20Votes` — external contract, cannot be modified. `snapshotBlock` is stored on-chain for off-chain verification. Known V1 limitation.

### K-03: Tie-breaking favors challenger
**Location:** `GrokmeArena.settleBattle()`  
**Rationale:** First-mover advantage. Challenger accepted initial risk. Documented.

### K-04: Trophy mint failure is silent
**Location:** `GrokmeArena._mintTrophy()` — `try {} catch {}`  
**Rationale:** Settlement burn must not be blocked by trophy issues. Trophy is a bonus, not a protocol guarantee. Tokens already burned before trophy mint attempt.

### K-05: `SETTLEMENT_WINDOW` constant defined but unused
**Location:** `GrokmeArena.sol` line ~84  
**Rationale:** Remnant of earlier design. No security impact — cleanup item only.

### K-06: `mint()` uses exact `grokBurnAmount` matching — no partial amounts
**Location:** `GrokNFT.mint()`  
**Rationale:** Tier assignment is determined by exact match against six constants. Any amount not matching a tier constant reverts with `"Invalid tier"`. This is intentional — no ambiguity about which tier is being minted.

### K-07: `totalGrokBurned` in Arena undercounts when Uniswap swap falls back
**Location:** `GrokmeArena._burnProtocolFee()` catch block  
**Rationale:** Counter tracks GROK burned specifically. When swap fails, the fee token is burned directly instead. Counter is technically correct by definition.

### K-08: `GrokNFT` ownership renounced — fully immutable
**Location:** `GrokNFT` `0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`  
**Status:** ✅ `renounceOwnership()` has been called. Owner = `0x000...dEaD`. `setContractURI()` is permanently inaccessible. No owner powers remain.

---

## Attack Surface Summary

| Category | Contracts | Residual Risk |
|---|---|---|
| Reentrancy | Arena (all token ops), GrokNFT mint | Low — `nonReentrant` on all |
| Integer overflow | All | None — Solidity 0.8.20 |
| Access control | Trophy (minter only) | Low — immutable `arenaMinter`, no other privileged roles |
| Front-running votes | Arena `castVote()` | Low — live balance, multi-wallet only, see L-01 |
| Fee swap MEV | Arena `_burnProtocolFee()` | Low — accepted K-01 |
| Griefing / bidding stall | Arena | Low — `BIDDING_TIMEOUT` + `MAX_RAISE_ROUNDS` |
| Supply cap bypass | GrokNFT | Low — 6 per-tier counters + global `currentTokenId < 690` |
| Tier front-running | GrokNFT | Low — last slot of rare tier susceptible to mempool race |
| Centralization | GrokNFT | None — ownership renounced to `0x000...dEaD` |
