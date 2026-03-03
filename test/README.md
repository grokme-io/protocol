# Test Suite

**Framework:** Hardhat + Chai  
**Coverage:** GrokmeArena (68 tests), GrokmeArenaTrophy (27 tests), GrokNFT (38 tests)  
**Status:** All passing

---

## Run Tests

```bash
# From grokme-me-chain repo (contracts + Hardhat config live there)
npm install
npx hardhat test test/GrokmeArena.test.js
npx hardhat test test/GrokmeArenaTrophy.test.js
npx hardhat test test/GrokNFT.test.js

# All at once
npx hardhat test
```

---

## GrokNFT — 38 Tests

| Suite | Tests |
|---|---|
| Deployment | 6 |
| `mint()` — Tier Validation | 8 |
| `mint()` — Burn Mechanics | 6 |
| `mint()` — ERC-721 Properties | 6 |
| Supply Caps | 5 |
| Owner — `setContractURI()` | 3 |
| Security | 4 |
| View Functions | 5 |

**Key security scenarios covered:**
- All 6 tiers mint correctly with exact burn amount
- Invalid tier amount reverts with `"Invalid tier"`
- Empty URI reverts with `"Empty URI"`
- Exact GROK amount transferred from caller to `DEAD_ADDRESS`
- `totalGrokBurned` accumulates correctly across mints
- `tokenBurnAmount[tokenId]` records per-token tier proof
- UNICORN limit (1) and DIVINE limit (3) enforced
- Per-tier counters increment only for their tier
- `currentTokenId` == sum of all tier counters (supply consistency)
- No ETH accepted (no `receive()` / `fallback()`)
- `mint()` is permissionless — any user can mint any tier
- Owner can `setContractURI()` — non-owner reverts
- `renounceOwnership()` permanently disables `setContractURI()`
- ERC-721 transfer works post-mint
- `Grokked` event emits correct args including tier string

---

## GrokmeArena — 68 Tests

| Suite | Tests |
|---|---|
| Deployment | 3 |
| `issueChallenge()` | 9 |
| `acceptChallenge()` | 8 |
| Bidding — `call()` / `raise()` / `fold()` | 12 |
| `forceStartAfterTimeout()` | 3 |
| `expireChallenge()` | 5 |
| `castVote()` | 9 |
| `settleBattle()` | 10 |
| Edge Cases (fee-on-transfer, fallback burn) | 2 |
| View Functions | 5 |
| Full Integration (challenge → settle) | 1 |

**Key security scenarios covered:**
- 5% protocol fee deducted and burned on every deposit
- GROK fee burned directly (no swap) when token == GROK
- Non-GROK fee swapped via Uniswap → GROK → dead address
- Fee token burned directly when Uniswap swap fails (no liquidity)
- `MAX_RAISE_ROUNDS` enforced — bidding cannot be griefed indefinitely
- `BIDDING_TIMEOUT` — force-start after 24h inactivity
- Double vote rejected (`hasVoted` mapping)
- Vote without token holding rejected
- `minVoterBalance` threshold enforced
- Same-token duel: any holder can vote for either side
- Tie → challenger wins (documented first-mover advantage)
- Settlement burns 100% of staked tokens from both sides
- Settlement is permissionless (called by `outsider` in tests)
- Trophy mint failure (try/catch) does NOT block settlement

---

## GrokmeArenaTrophy — 27 Tests

| Suite | Tests |
|---|---|
| Deployment | 4 |
| `mintTrophy()` — happy path | 5 |
| `mintTrophy()` — access control | 5 |
| Data integrity | 4 |
| `getTrophy()` / `getTrophyForBattle()` | 4 |
| ERC-721 standard | 3 |
| Admin/owner assertions | 2 |

**Key security scenarios covered:**
- Only `arenaMinter` (immutable) can call `mintTrophy()`
- Zero address as winner rejected
- One trophy per battle (duplicate battle ID rejected)
- `battleToToken` off-by-one offset correct
- Full `TrophyData` struct stored on-chain and retrievable
- No owner/admin capability confirmed
- ERC-721 transfer works; balance tracking correct
