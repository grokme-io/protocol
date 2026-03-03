# Preliminary Security Findings

**Protocol:** GROKME  
**Auditor:** Internal self-audit (pre-submission baseline)  
**Date:** 2026-03-03  
**Contracts:** GrokmeArena, GrokmeArenaTrophy, GrokNFT  

> This document is the team's own analysis produced before external audit. It is provided so external auditors can skip known issues and focus on deeper edge cases and economic attack vectors.

---

## Severity Classification

| Severity | Definition |
|---|---|
| **CRITICAL** | Funds can be stolen or permanently locked |
| **HIGH** | Significant loss of funds or severe protocol malfunction under realistic conditions |
| **MEDIUM** | Limited fund loss or protocol behavior deviates from spec under specific conditions |
| **LOW** | Minor issues, best-practice violations, minimal fund impact |
| **INFORMATIONAL** | Code quality, style — no security impact |

---

## CRITICAL

### C-01: None identified

No critical vulnerabilities found. All reentrancy vectors are guarded by `nonReentrant`. Solidity 0.8.20 prevents arithmetic overflow/underflow. No direct fund-draining path was identified in any of the three contracts.

---

## MEDIUM

### M-01: `GrokNFT.mint()` — Tier Front-Running on Last Slot
**Contract:** `GrokNFT` (`0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`)  
**Function:** `mint()`  
**Status:** Low practical risk; worth documenting

**Description:**  
Tier slots are granted first-come-first-served. A mempool observer can front-run the final slot of any tier (especially UNICORN: 1 total, DIVINE: 3 total) by copying the victim's transaction with higher gas. The attacker mints the last slot; the victim's transaction reverts with `"UNICORN taken"` / `"DIVINE sold out"`.

**Impact:** Victim loses gas; attacker mints the desired tier. No funds are lost beyond gas since the `transferFrom` only executes if the tier check passes. However, the attacker pays the full burn amount — this is an expensive attack for high tiers (UNICORN = 100M GROK).

**Practical severity:** Low for LEGENDARY/DIVINE/UNICORN (high burn cost deters attackers). Higher UX risk for COMMON/RARE where burn cost is low.

**Recommendation:** Auditors may propose a commit-reveal scheme for the final slot. For GROKME's use case this is a UX inconvenience rather than a fund-loss vulnerability.

---

### M-03: `forceStartAfterTimeout()` Stake Asymmetry
**Contract:** `GrokmeArena.sol`  
**Function:** `forceStartAfterTimeout()`

**Description:**  
After `BIDDING_TIMEOUT` (24h) of inactivity, the non-pending side can force the battle to start. The pending side's last raise stands — the opponent is treated as having called without matching the raise. This can result in a materially unequal stake (e.g., challenger raised 10x, opponent times out, battle starts with challenger staking 10x more).

**Intended behavior:** Yes — the non-responding party is implicitly punished. But the calling party may force-start precisely because they believe the imbalance favors them.

**Recommendation:** Auditors should confirm whether `forceStartAfterTimeout` is intended as a griefing mitigation or whether it can itself be used as a griefing vector (deliberate timeout to force an unequal battle).

---

### M-04: `GrokNFT` — Dual Supply Cap: Per-Tier + Global Can Diverge
**Contract:** `GrokNFT` (`0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`)  
**Function:** `mint()`

**Description:**  
The contract enforces two independent supply caps:
1. **Per-tier counter** (`commonMinted < COMMON_LIMIT`, etc.)
2. **Global counter** (`currentTokenId < 690`)

The sum of all tier limits is exactly 690 (469+138+69+10+3+1 = 690), matching the global cap. However, since both checks are independent, there is a theoretical edge case: if the global cap `currentTokenId < 690` is hit before all per-tier caps are filled (impossible given the math adds up exactly), or vice versa.

**Analysis:** The math is consistent — both caps are equivalent. No divergence is possible assuming no bugs in the counter increments. Auditors should verify that `currentTokenId` increments exactly once per successful mint and that no mint path exists that increments one counter without the other.

**Current implementation:**
```solidity
uint256 tokenId = ++currentTokenId;      // global counter
totalGrokBurned += grokBurnAmount;
commonMinted++;                           // tier counter (in if-branch)
```
Both increments happen in the same function, within `nonReentrant`. Safe.

**Recommendation:** Informational — confirm via test that sum of tier minted counts always equals `currentTokenId` at any state.

---

## LOW

### L-01 (formerly H-01): Vote Manipulation via Live Balance — Multi-Wallet Coordination
**Contract:** `GrokmeArena.sol`  
**Function:** `castVote()`  
**Reclassified:** HIGH → **LOW**

**Why lower than initially assessed:**  
Flash loans cannot exploit this — each wallet is a separate transaction, not a single atomic call. A real attack requires: (1) multiple wallets each holding ≥ `minVoterBalance` of the staked community token, (2) gas cost for every vote tx, (3) the token transfer between wallets between blocks. For the meme battle use case — where both staked tokens are community tokens with real holders — coordinating N wallets while spending real tokens is economically unattractive: the attacker pays for the tokens and gas but gains nothing material (no funds to extract; all tokens burn regardless of outcome).

**The real control:** `minVoterBalance` is set by the challenger at `issueChallenge()`. Setting it to a meaningful fraction of circulating supply makes multi-wallet coordination prohibitively expensive. This puts risk control in the hands of participants, not the protocol.

**Residual risk:** Genuine — a whale with many wallets and abundant tokens *could* sway a low-stakes battle. Accepted V1 design limitation, documented in K-02.

**Recommendation:** No code change required. Document `minVoterBalance` guidance for challengers.

---

### L-02 (formerly H-02): Protocol Fee Swap Silent Fallback
**Contract:** `GrokmeArena.sol`  
**Function:** `_burnProtocolFee()`  
**Reclassified:** HIGH → **LOW** (near Informational)

**Why lower than initially assessed:**  
No funds are at risk. When the Uniswap swap fails (no WETH liquidity pair for the staked token), the catch block burns the fee token directly to `DEAD_ADDRESS`. The fee is destroyed in all cases — the only difference is *which* token burns. There is no path for an attacker to extract the fee. The impact is that `totalGrokBurned` and `battleGrokFees[battleId]` stay at 0 for that battle, and the Trophy records `grokBurnedFromFees = 0`. This is a marketing invariant deviation, not a fund-loss bug.

**The `ProtocolFeeBurned` event** already signals this: `grokBurned = 0` is emitted in the fallback path, making it observable on-chain.

**Recommendation:** Acceptable as-is. Optionally emit a distinct `ProtocolFeeDirectBurn` event in the catch block for cleaner off-chain analytics.

---

### L-03 (formerly M-02): `castVote()` Lacks `nonReentrant`
**Contract:** `GrokmeArena.sol`  
**Function:** `castVote()`  
**Reclassified:** MEDIUM → **LOW**

**Why safe:** The only external call is `IERC20.balanceOf()` — a pure view function. `hasVoted[battleId][msg.sender] = true` is set *before* this call (CEI pattern). No reentrancy path exists. `nonReentrant` would add ~200 gas per vote with zero security benefit given the current code.

**Recommendation:** Add `nonReentrant` for defense-in-depth consistency. Safe either way.

---

### L-04: `safeApprove` Double-Reset Pattern on Every Fee Burn
**Contract:** `GrokmeArena.sol`  
**Function:** `_burnProtocolFee()`

```solidity
IERC20(token).safeApprove(address(uniswapRouter), 0);
IERC20(token).safeApprove(address(uniswapRouter), feeAmount);
```

Correct pattern for USDT-style tokens. No security impact; slightly higher gas per fee burn. `safeIncreaseAllowance` is the modern alternative but introduces no security difference here.

---

### L-05: `snapshotBlock` Stored But Not Enforced — Misleading Naming
**Contract:** `GrokmeArena.sol`

`b.snapshotBlock = block.number` is stored at battle start but `castVote()` uses current `balanceOf()`. The name implies snapshot-based voting (standard in governance). NatSpec should explicitly state this is an informational anchor for off-chain verification only.

---

### L-06: Unbounded `minVoterBalance` — Challenger Can Prevent All Votes
**Contract:** `GrokmeArena.sol`  
**Function:** `issueChallenge()`

A challenger could set `minVoterBalance = type(uint256).max`, making it impossible for anyone to vote. Result: 0–0 tie, resolved in challenger's favor (K-03). Self-defeating (challenger burns their own stake), but possible. Consider capping at a reasonable % of token supply.

---

### L-07: Trophy `setTrophyURI()` — Token Owner Can Overwrite Arena-Set URI
**Contract:** `GrokmeArenaTrophy.sol`

Trophy holders (winners) can update the `tokenURI` of their own trophy. The on-chain `TrophyData` struct (immutable battle proof) is unaffected — only the URI pointer to off-chain metadata can change. Document explicitly that the immutable record is `getTrophy()`, not `tokenURI()`.

---

### L-08: `GrokNFT` — No `receive()` or `fallback()` — ETH Silently Reverts
**Contract:** `GrokNFT` (`0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`)

The deployed contract has no `receive()` or `fallback()` function. ETH sent directly to the contract will revert at the EVM level. No owner rescue function exists. Intended behavior — documented for completeness.

---

### ~~L-09: GrokNFT Owner Can Change Collection Metadata URI~~ — **RESOLVED**
**Contract:** `GrokNFT` (`0x5ee102ab33bcc5c49996fb48dea465ec6330e77d`)  
**Status:** ✅ `renounceOwnership()` called — owner is now `0x000...dEaD`. `setContractURI()` permanently disabled. Contract is fully immutable.

---

## INFORMATIONAL

### I-01: `totalGrokBurned` (Arena) Does Not Count Fee-Token Fallback Burns
When Uniswap swap fails, fee token burns directly but `totalGrokBurned` is not incremented. Technically correct (tracks GROK specifically) but callers treating it as "total value burned" will undercount.

### I-02: `battleToToken` Off-by-One Offset in Trophy
`battleToToken[battleId] = tokenId + 1` distinguishes "not minted" (stored 0) from "token 0" (stored 1). `getTrophyForBattle()` returns `stored - 1`. Correct but unusual — auditors should verify the subtraction path handles the "not minted" case (returns `revert`, not token ID 0 for an unminted battle).

### I-03: `GrokNFT` uses `GROK_TOKEN.transferFrom` Without `SafeERC20`
```solidity
require(GROK_TOKEN.transferFrom(msg.sender, BURN_ADDRESS, grokBurnAmount), "Burn failed");
```
GROK token returns `bool` on `transferFrom`, so the `require()` check is correct. `SafeERC20.safeTransferFrom` is the modern best practice but has no practical difference here since `GROK_TOKEN` is `immutable` and the token is known-safe.

### I-04: No Event Emitted When `GrokNFT` Ownership Renounced
`renounceOwnership()` emits `OwnershipTransferred(owner, address(0))` via OpenZeppelin — this is correct. Informational note only.

### I-05: `SETTLEMENT_WINDOW` Constant Defined But Never Used
`GrokmeArena.sol` line ~84: `uint256 public constant SETTLEMENT_WINDOW = 24 hours;` — not referenced anywhere. Should be removed to avoid confusion.

### I-06: `GrokNFT` — `tokenBurnAmount` Mapping Enables Tier Verification Off-Chain
`tokenBurnAmount[tokenId]` records the exact GROK burned per token. This allows any observer to verify a token's tier from on-chain data alone (`burnAmount → tier`). No security impact — informational note on good design.

---

## Summary Table

| ID | Severity | Title | Status |
|---|---|---|---|
| L-01 | LOW | Vote manipulation via live balance (reclassified from HIGH) | Accepted design, K-02 |
| L-02 | LOW | Fee swap fallback (reclassified from HIGH) | No fund loss, observable via event |
| L-03 | LOW | `castVote()` lacks `nonReentrant` (reclassified from MEDIUM) | Safe by CEI |
| M-01 | MEDIUM | GrokNFT tier front-running on last slot | Low practical risk |
| M-03 | MEDIUM | `forceStartAfterTimeout` stake asymmetry | Needs auditor validation |
| M-04 | MEDIUM | Dual supply cap consistency (per-tier + global) | Mathematically safe, confirm via test |
| L-04 | LOW | Double-approve on every fee burn | Correct, suboptimal |
| L-05 | LOW | `snapshotBlock` misleading — not enforced | Doc fix |
| L-06 | LOW | Unbounded `minVoterBalance` griefing | Self-defeating |
| L-07 | LOW | Trophy URI mutable by token owner | Intentional |
| L-08 | LOW | No ETH recovery in GrokNFT | Intentional |
| ~~L-09~~ | ~~LOW~~ | ~~GrokNFT owner `setContractURI()`~~ | ✅ **RESOLVED** — ownership renounced |
| I-01 | INFO | Arena `totalGrokBurned` undercounts on fallback | Correct by definition |
| I-02 | INFO | Trophy `battleToToken` off-by-one | Correct, unusual |
| I-03 | INFO | `transferFrom` without SafeERC20 | No risk (immutable token) |
| I-04 | INFO | Renounce event via OpenZeppelin | Correct |
| I-05 | INFO | Unused `SETTLEMENT_WINDOW` constant | Cleanup |
| I-06 | INFO | `tokenBurnAmount` enables off-chain tier verification | Good design |

---

## Recommended Focus for External Auditors

1. **L-01** — Confirm multi-wallet vote attack cost is prohibitive for any realistic token; validate that `minVoterBalance` guidance is sufficient
2. **L-02** — Enumerate realistic tokens with no WETH V2 pool; confirm `ProtocolFeeBurned(grokBurned=0)` event is sufficient signal
3. **M-03** — Game-theoretic analysis of `forceStartAfterTimeout` as a griefing vector
4. **M-01** — Confirm tier front-running is infeasible at high tiers; assess COMMON/RARE UX risk
5. **Arena × Trophy cross-contract** — Verify constructor arg validation at deploy time (immutable at construction)
6. **Fee-on-transfer tokens** — Edge cases in `_depositWithFee()` balance-delta for rebasing or deflationary tokens
7. **GrokNFT supply cap** — Confirm `currentTokenId` and per-tier counters always in sync (M-04)
