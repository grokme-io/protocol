const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GrokmeArena", function () {
  let arena, grok, pepe, weth, router;
  let deployer, challenger, opponent, voter1, voter2, voter3, outsider;

  const HOUR = 3600;
  const DURATION_48H = 48 * HOUR;
  const MEME_HASH_1 = ethers.utils.formatBytes32String("QmGrokLaserEyes");
  const MEME_HASH_2 = ethers.utils.formatBytes32String("QmCosmicFrog");
  const ZERO_ADDRESS = ethers.constants.AddressZero;
  const DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";

  const Status = { Open: 0, Bidding: 1, Battling: 2, Settled: 3, Expired: 4, Folded: 5 };
  const Team = { None: 0, Challenger: 1, Opponent: 2 };

  // ── Helpers ──

  async function expectRevert(promise, reason) {
    try { await promise; expect.fail("Expected revert"); }
    catch (e) { expect(e.message).to.include(reason); }
  }

  async function expectEvent(tx, name) {
    const r = await tx.wait();
    expect(r.events.some(e => e.event === name)).to.equal(true, `Missing event: ${name}`);
  }

  function bn(v) { return ethers.BigNumber.from(v); }
  function eq(a, b) { expect(a.toString()).to.equal(bn(b).toString()); }
  function gt(a, b) { expect(bn(a).gt(bn(b))).to.equal(true, `${a} not > ${b}`); }

  // ── Setup ──

  async function deploy() {
    [deployer, challenger, opponent, voter1, voter2, voter3, outsider] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    grok = await MockERC20.deploy("GROK", "GROK", 9);
    pepe = await MockERC20.deploy("PEPE", "PEPE", 18);
    weth = await MockERC20.deploy("WETH", "WETH", 18);

    const MockRouter = await ethers.getContractFactory("MockUniswapV2Router");
    router = await MockRouter.deploy(weth.address);
    await grok.mint(router.address, ethers.utils.parseUnits("1000000000", 9));

    // Deploy Trophy with deployer as temporary minter (for Arena tests,
    // trophy mint fails silently via try/catch — that's fine)
    const Trophy = await ethers.getContractFactory("GrokmeArenaTrophy");
    const trophy = await Trophy.deploy(deployer.address);

    const Arena = await ethers.getContractFactory("GrokmeArena");
    arena = await Arena.deploy(grok.address, router.address, trophy.address);

    const gAmt = ethers.utils.parseUnits("100000000", 9);
    const pAmt = ethers.utils.parseUnits("1000000000", 18);
    await grok.mint(challenger.address, gAmt);
    await grok.mint(opponent.address, gAmt);
    await grok.mint(voter1.address, gAmt);
    await grok.mint(voter2.address, gAmt);
    await pepe.mint(opponent.address, pAmt);
    await pepe.mint(voter3.address, pAmt);

    await grok.connect(challenger).approve(arena.address, ethers.constants.MaxUint256);
    await grok.connect(opponent).approve(arena.address, ethers.constants.MaxUint256);
    await pepe.connect(opponent).approve(arena.address, ethers.constants.MaxUint256);
  }

  beforeEach(deploy);

  // Helper: advance time
  async function advanceTime(seconds) {
    await ethers.provider.send("evm_increaseTime", [seconds]);
    await ethers.provider.send("evm_mine");
  }

  // Helper: full setup to Battling state
  async function setupBattle(battleId) {
    const gStake = ethers.utils.parseUnits("10000000", 9);
    const pStake = ethers.utils.parseUnits("500000000", 18);
    if (battleId === undefined) {
      await arena.connect(challenger).issueChallenge(grok.address, gStake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
      await arena.connect(challenger).call(0, 0);
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DEPLOYMENT
  // ═══════════════════════════════════════════════════════════════

  describe("Deployment", function () {
    it("sets immutables correctly", async function () {
      expect(await arena.grokToken()).to.equal(grok.address);
      expect(await arena.uniswapRouter()).to.equal(router.address);
      expect(await arena.weth()).to.equal(weth.address);
      eq(await arena.nextBattleId(), 0);
    });

    it("reverts on zero GROK address", async function () {
      const A = await ethers.getContractFactory("GrokmeArena");
      await expectRevert(A.deploy(ZERO_ADDRESS, router.address, deployer.address), "Invalid GROK address");
    });

    it("reverts on zero router address", async function () {
      const A = await ethers.getContractFactory("GrokmeArena");
      await expectRevert(A.deploy(grok.address, ZERO_ADDRESS, deployer.address), "Invalid router address");
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  ISSUE CHALLENGE
  // ═══════════════════════════════════════════════════════════════

  describe("issueChallenge", function () {
    const stake = ethers.utils.parseUnits("10000000", 9);

    it("creates targeted challenge correctly", async function () {
      await arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      const b = await arena.getBattle(0);
      expect(b.challenger).to.equal(challenger.address);
      expect(b.challengerToken).to.equal(grok.address);
      eq(b.status, Status.Open);
      expect(b.challengerMemeHash).to.equal(MEME_HASH_1);
    });

    it("creates open challenge (targetToken = 0)", async function () {
      await arena.connect(challenger).issueChallenge(grok.address, stake, ZERO_ADDRESS, DURATION_48H, MEME_HASH_1, 0);
      const t = await arena.getBattleTiming(0);
      eq(t.duration, DURATION_48H);
    });

    it("deducts 5% protocol fee from stake", async function () {
      await arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      const b = await arena.getBattle(0);
      eq(b.challengerStake, stake.mul(9500).div(10000));
    });

    it("burns GROK fee directly to dead address", async function () {
      const before = await grok.balanceOf(DEAD_ADDRESS);
      await arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      const after = await grok.balanceOf(DEAD_ADDRESS);
      eq(after.sub(before), stake.mul(500).div(10000));
    });

    it("swaps non-GROK fee via router and tracks totalGrokBurned", async function () {
      await pepe.mint(challenger.address, ethers.utils.parseUnits("100000000", 18));
      await pepe.connect(challenger).approve(arena.address, ethers.constants.MaxUint256);
      const burnedBefore = await arena.totalGrokBurned();
      await arena.connect(challenger).issueChallenge(pepe.address, ethers.utils.parseUnits("100000000", 18), grok.address, DURATION_48H, MEME_HASH_1, 0);
      const burnedAfter = await arena.totalGrokBurned();
      gt(burnedAfter, burnedBefore);
    });

    it("increments nextBattleId", async function () {
      await arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      eq(await arena.nextBattleId(), 1);
    });

    it("emits ChallengeIssued", async function () {
      const tx = await arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      await expectEvent(tx, "ChallengeIssued");
    });

    it("reverts: zero token", async function () {
      await expectRevert(arena.connect(challenger).issueChallenge(ZERO_ADDRESS, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0), "Invalid token");
    });

    it("reverts: zero amount", async function () {
      await expectRevert(arena.connect(challenger).issueChallenge(grok.address, 0, pepe.address, DURATION_48H, MEME_HASH_1, 0), "Stake must be > 0");
    });

    it("reverts: zero meme hash", async function () {
      await expectRevert(arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, ethers.constants.HashZero, 0), "Meme hash required");
    });

    it("reverts: duration < 5min", async function () {
      await expectRevert(arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, 4 * 60, MEME_HASH_1, 0), "Duration: 5min-35d");
    });

    it("reverts: duration > 35 days", async function () {
      await expectRevert(arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, 36 * 24 * HOUR, MEME_HASH_1, 0), "Duration: 5min-35d");
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  ACCEPT CHALLENGE
  // ═══════════════════════════════════════════════════════════════

  describe("acceptChallenge", function () {
    const gStake = ethers.utils.parseUnits("10000000", 9);
    const pStake = ethers.utils.parseUnits("500000000", 18);

    beforeEach(async function () {
      await arena.connect(challenger).issueChallenge(grok.address, gStake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
    });

    it("accepts with correct token and enters Bidding", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
      const b = await arena.getBattle(0);
      expect(b.opponent).to.equal(opponent.address);
      expect(b.opponentToken).to.equal(pepe.address);
      eq(b.status, Status.Bidding);
    });

    it("sets pendingResponse to challenger", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
      const t = await arena.getBattleTiming(0);
      expect(t.pendingResponse).to.equal(challenger.address);
    });

    it("deducts 5% fee from opponent", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
      eq((await arena.getBattle(0)).opponentStake, pStake.mul(9500).div(10000));
    });

    it("emits ChallengeAccepted", async function () {
      const tx = await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
      await expectEvent(tx, "ChallengeAccepted");
    });

    it("reverts: not open (already accepted)", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
      await expectRevert(arena.connect(outsider).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2), "Not open");
    });

    it("reverts: expired (72h+)", async function () {
      await advanceTime(72 * HOUR + 1);
      await expectRevert(arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2), "Challenge expired");
    });

    it("reverts: self-accept", async function () {
      await expectRevert(arena.connect(challenger).acceptChallenge(0, grok.address, gStake, MEME_HASH_2), "Cannot accept own challenge");
    });

    it("reverts: wrong target token", async function () {
      await expectRevert(arena.connect(opponent).acceptChallenge(0, grok.address, gStake, MEME_HASH_2), "Must use target token");
    });

    it("open challenge: any token works", async function () {
      await arena.connect(challenger).issueChallenge(grok.address, gStake, ZERO_ADDRESS, DURATION_48H, MEME_HASH_1, 0);
      await arena.connect(opponent).acceptChallenge(1, grok.address, gStake, MEME_HASH_2);
      expect((await arena.getBattle(1)).opponent).to.equal(opponent.address);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  POKER: RAISE / CALL / FOLD
  // ═══════════════════════════════════════════════════════════════

  describe("Poker Mechanics", function () {
    const gStake = ethers.utils.parseUnits("10000000", 9);
    const pStake = ethers.utils.parseUnits("500000000", 18);
    const raiseAmt = ethers.utils.parseUnits("5000000", 9);
    const pRaise = ethers.utils.parseUnits("200000000", 18);

    beforeEach(async function () {
      await arena.connect(challenger).issueChallenge(grok.address, gStake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
    });

    // ── call ──

    it("call(0) starts battle immediately", async function () {
      await arena.connect(challenger).call(0, 0);
      eq((await arena.getBattle(0)).status, Status.Battling);
    });

    it("call with extra tokens adds to stake", async function () {
      const before = (await arena.getBattle(0)).challengerStake;
      await arena.connect(challenger).call(0, raiseAmt);
      gt((await arena.getBattle(0)).challengerStake, before);
    });

    it("call emits BattleStarted", async function () {
      const tx = await arena.connect(challenger).call(0, 0);
      await expectEvent(tx, "BattleStarted");
    });

    it("call reverts if not your turn", async function () {
      await expectRevert(arena.connect(opponent).call(0, 0), "Not your turn");
    });

    // ── raise ──

    it("raise increases stake and flips turn", async function () {
      await arena.connect(challenger).raise(0, raiseAmt);
      const t = await arena.getBattleTiming(0);
      expect(t.pendingResponse).to.equal(opponent.address);
      eq(t.raiseCount, 1);
    });

    it("opponent can re-raise", async function () {
      await arena.connect(challenger).raise(0, raiseAmt);
      await arena.connect(opponent).raise(0, pRaise);
      eq((await arena.getBattleTiming(0)).raiseCount, 2);
      expect((await arena.getBattleTiming(0)).pendingResponse).to.equal(challenger.address);
    });

    it("MAX_RAISE_ROUNDS enforced", async function () {
      // Mint extra tokens so we don't run out during 10 raises
      await grok.mint(challenger.address, ethers.utils.parseUnits("500000000", 9));
      await pepe.mint(opponent.address, ethers.utils.parseUnits("5000000000", 18));
      const smallG = ethers.utils.parseUnits("1000000", 9);
      const smallP = ethers.utils.parseUnits("50000000", 18);
      for (let i = 0; i < 10; i++) {
        const who = i % 2 === 0 ? challenger : opponent;
        const amt = i % 2 === 0 ? smallG : smallP;
        await arena.connect(who).raise(0, amt);
      }
      await expectRevert(arena.connect(challenger).raise(0, smallG), "Max raises reached");
    });

    it("raise reverts if not your turn", async function () {
      await expectRevert(arena.connect(opponent).raise(0, pRaise), "Not your turn");
    });

    it("raise burns 5% fee", async function () {
      const before = await grok.balanceOf(DEAD_ADDRESS);
      await arena.connect(challenger).raise(0, raiseAmt);
      eq((await grok.balanceOf(DEAD_ADDRESS)).sub(before), raiseAmt.mul(500).div(10000));
    });

    // ── fold ──

    it("fold refunds both sides and sets Folded", async function () {
      const cBefore = await grok.balanceOf(challenger.address);
      const oBefore = await pepe.balanceOf(opponent.address);
      await arena.connect(challenger).fold(0);
      eq((await arena.getBattle(0)).status, Status.Folded);
      eq((await arena.getBattle(0)).challengerStake, 0);
      eq((await arena.getBattle(0)).opponentStake, 0);
      gt(await grok.balanceOf(challenger.address), cBefore);
      gt(await pepe.balanceOf(opponent.address), oBefore);
    });

    it("fold emits events", async function () {
      const tx = await arena.connect(challenger).fold(0);
      await expectEvent(tx, "Folded");
      await expectEvent(tx, "StakeRefunded");
    });

    it("fold reverts if not your turn", async function () {
      await expectRevert(arena.connect(opponent).fold(0), "Not your turn");
    });

    it("fold does NOT refund protocol fees", async function () {
      const deadBefore = await grok.balanceOf(DEAD_ADDRESS);
      await arena.connect(challenger).fold(0);
      // dead address balance should not decrease
      const deadAfter = await grok.balanceOf(DEAD_ADDRESS);
      expect(deadAfter.gte(deadBefore)).to.equal(true);
      gt(deadAfter, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  BIDDING TIMEOUT
  // ═══════════════════════════════════════════════════════════════

  describe("Bidding Timeout", function () {
    beforeEach(async function () {
      const gStake = ethers.utils.parseUnits("10000000", 9);
      const pStake = ethers.utils.parseUnits("500000000", 18);
      await arena.connect(challenger).issueChallenge(grok.address, gStake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      await arena.connect(opponent).acceptChallenge(0, pepe.address, pStake, MEME_HASH_2);
    });

    it("force-starts after 24h timeout", async function () {
      await advanceTime(24 * HOUR + 1);
      await arena.connect(opponent).forceStartAfterTimeout(0);
      eq((await arena.getBattle(0)).status, Status.Battling);
    });

    it("reverts before timeout", async function () {
      await expectRevert(arena.connect(opponent).forceStartAfterTimeout(0), "Timeout not reached");
    });

    it("reverts if called by pending responder", async function () {
      await advanceTime(24 * HOUR + 1);
      await expectRevert(arena.connect(challenger).forceStartAfterTimeout(0), "You are the pending responder");
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  EXPIRE CHALLENGE
  // ═══════════════════════════════════════════════════════════════

  describe("expireChallenge", function () {
    const stake = ethers.utils.parseUnits("10000000", 9);

    beforeEach(async function () {
      await arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
    });

    it("expires after 72h, refunds stake (not fee)", async function () {
      const before = await grok.balanceOf(challenger.address);
      await advanceTime(72 * HOUR + 1);
      await arena.connect(outsider).expireChallenge(0);
      eq((await arena.getBattle(0)).status, Status.Expired);
      eq((await arena.getBattle(0)).challengerStake, 0);
      gt(await grok.balanceOf(challenger.address), before);
    });

    it("fee stays burned after expire", async function () {
      const deadBefore = await grok.balanceOf(DEAD_ADDRESS);
      await advanceTime(72 * HOUR + 1);
      await arena.connect(outsider).expireChallenge(0);
      expect((await grok.balanceOf(DEAD_ADDRESS)).gte(deadBefore)).to.equal(true);
    });

    it("reverts before 72h", async function () {
      await expectRevert(arena.connect(outsider).expireChallenge(0), "Not expired yet");
    });

    it("reverts if not open (already accepted)", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, ethers.utils.parseUnits("100000000", 18), MEME_HASH_2);
      await advanceTime(72 * HOUR + 1);
      await expectRevert(arena.connect(outsider).expireChallenge(0), "Not open");
    });

    it("callable by anyone (permissionless)", async function () {
      await advanceTime(72 * HOUR + 1);
      await arena.connect(outsider).expireChallenge(0);
      eq((await arena.getBattle(0)).status, Status.Expired);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  VOTING
  // ═══════════════════════════════════════════════════════════════

  describe("castVote", function () {
    beforeEach(async function () {
      await setupBattle();
    });

    it("GROK holder votes for challenger", async function () {
      await arena.connect(voter1).castVote(0, Team.Challenger);
      eq((await arena.getBattle(0)).challengerVotes, 1);
    });

    it("PEPE holder votes for opponent", async function () {
      await arena.connect(voter3).castVote(0, Team.Opponent);
      eq((await arena.getBattle(0)).opponentVotes, 1);
    });

    it("emits VoteCast", async function () {
      const tx = await arena.connect(voter1).castVote(0, Team.Challenger);
      await expectEvent(tx, "VoteCast");
    });

    it("reverts: double vote", async function () {
      await arena.connect(voter1).castVote(0, Team.Challenger);
      await expectRevert(arena.connect(voter1).castVote(0, Team.Challenger), "Already voted");
    });

    it("reverts: voting ended", async function () {
      await advanceTime(DURATION_48H + 1);
      await expectRevert(arena.connect(voter1).castVote(0, Team.Challenger), "Voting ended");
    });

    it("reverts: no tokens held", async function () {
      await expectRevert(arena.connect(outsider).castVote(0, Team.Challenger), "Must hold team token");
    });

    it("GROK holder cannot vote for PEPE team", async function () {
      await expectRevert(arena.connect(voter1).castVote(0, Team.Opponent), "Must hold team token");
    });

    it("PEPE holder cannot vote for GROK team", async function () {
      await expectRevert(arena.connect(voter3).castVote(0, Team.Challenger), "Must hold team token");
    });

    it("same-token duel: any holder votes for either side", async function () {
      const s = ethers.utils.parseUnits("10000000", 9);
      await arena.connect(challenger).issueChallenge(grok.address, s, ZERO_ADDRESS, DURATION_48H, MEME_HASH_1, 0);
      await arena.connect(opponent).acceptChallenge(1, grok.address, s, MEME_HASH_2);
      await arena.connect(challenger).call(1, 0);
      await arena.connect(voter1).castVote(1, Team.Opponent);
      eq((await arena.getBattle(1)).opponentVotes, 1);
    });

    it("respects minVoterBalance", async function () {
      const s = ethers.utils.parseUnits("10000000", 9);
      const minBal = ethers.utils.parseUnits("999999999", 9);
      await arena.connect(challenger).issueChallenge(grok.address, s, pepe.address, DURATION_48H, MEME_HASH_1, minBal);
      // battleId = 1 (0 was created in beforeEach)
      await arena.connect(opponent).acceptChallenge(1, pepe.address, ethers.utils.parseUnits("100000000", 18), MEME_HASH_2);
      await arena.connect(challenger).call(1, 0);
      await expectRevert(arena.connect(voter1).castVote(1, Team.Challenger), "Below min voter balance");
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  SETTLEMENT
  // ═══════════════════════════════════════════════════════════════

  describe("settleBattle", function () {
    beforeEach(async function () {
      await setupBattle();
    });

    it("challenger wins with more votes", async function () {
      await arena.connect(voter1).castVote(0, Team.Challenger);
      await arena.connect(voter2).castVote(0, Team.Challenger);
      await arena.connect(voter3).castVote(0, Team.Opponent);
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      const b = await arena.getBattle(0);
      eq(b.winner, Team.Challenger);
      eq(b.status, Status.Settled);
    });

    it("opponent wins with more votes", async function () {
      await arena.connect(voter1).castVote(0, Team.Challenger);
      await pepe.mint(voter2.address, ethers.utils.parseUnits("1000000", 18));
      await arena.connect(voter2).castVote(0, Team.Opponent);
      await arena.connect(voter3).castVote(0, Team.Opponent);
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      eq((await arena.getBattle(0)).winner, Team.Opponent);
    });

    it("tie → challenger wins (first-mover advantage)", async function () {
      await arena.connect(voter1).castVote(0, Team.Challenger);
      await arena.connect(voter3).castVote(0, Team.Opponent);
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      eq((await arena.getBattle(0)).winner, Team.Challenger);
    });

    it("zero votes → challenger wins by default", async function () {
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      eq((await arena.getBattle(0)).winner, Team.Challenger);
    });

    it("burns ALL staked tokens to dead address", async function () {
      await arena.connect(voter1).castVote(0, Team.Challenger);
      const gDead = await grok.balanceOf(DEAD_ADDRESS);
      const pDead = await pepe.balanceOf(DEAD_ADDRESS);
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      gt(await grok.balanceOf(DEAD_ADDRESS), gDead);
      gt(await pepe.balanceOf(DEAD_ADDRESS), pDead);
      eq((await arena.getBattle(0)).challengerStake, 0);
      eq((await arena.getBattle(0)).opponentStake, 0);
    });

    it("increments totalBattlesSettled", async function () {
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      eq(await arena.totalBattlesSettled(), 1);
    });

    it("permissionless: anyone can settle", async function () {
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      eq((await arena.getBattle(0)).status, Status.Settled);
    });

    it("reverts: voting still active", async function () {
      await expectRevert(arena.connect(outsider).settleBattle(0), "Voting still active");
    });

    it("reverts: already settled", async function () {
      await advanceTime(DURATION_48H);
      await arena.connect(outsider).settleBattle(0);
      await expectRevert(arena.connect(outsider).settleBattle(0), "Not in battle");
    });

    it("emits BattleSettled", async function () {
      await advanceTime(DURATION_48H);
      const tx = await arena.connect(outsider).settleBattle(0);
      await expectEvent(tx, "BattleSettled");
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  SWAP FAILURE FALLBACK
  // ═══════════════════════════════════════════════════════════════

  describe("Protocol Fee — Swap Failure", function () {
    it("burns fee token directly if Uniswap swap fails", async function () {
      await router.setShouldFail(true);
      await pepe.mint(challenger.address, ethers.utils.parseUnits("100000000", 18));
      await pepe.connect(challenger).approve(arena.address, ethers.constants.MaxUint256);

      const deadBefore = await pepe.balanceOf(DEAD_ADDRESS);
      await arena.connect(challenger).issueChallenge(pepe.address, ethers.utils.parseUnits("100000000", 18), grok.address, DURATION_48H, MEME_HASH_1, 0);
      gt(await pepe.balanceOf(DEAD_ADDRESS), deadBefore);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  FEE-ON-TRANSFER TOKENS
  // ═══════════════════════════════════════════════════════════════

  describe("Fee-on-Transfer Tokens", function () {
    it("correctly accounts for actual received amount", async function () {
      const FeeToken = await ethers.getContractFactory("MockFeeToken");
      const feeToken = await FeeToken.deploy();
      await feeToken.mint(challenger.address, ethers.utils.parseEther("1000000"));
      await feeToken.connect(challenger).approve(arena.address, ethers.constants.MaxUint256);
      await grok.mint(router.address, ethers.utils.parseUnits("1000000000", 9));

      const amount = ethers.utils.parseEther("1000000");
      // 10% transfer tax → contract receives 900000
      // 5% protocol fee on 900000 = 45000
      // Stake = 855000
      await arena.connect(challenger).issueChallenge(feeToken.address, amount, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      const received = amount.mul(9000).div(10000);
      const expectedStake = received.mul(9500).div(10000);
      eq((await arena.getBattle(0)).challengerStake, expectedStake);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  VIEW FUNCTIONS
  // ═══════════════════════════════════════════════════════════════

  describe("View Functions", function () {
    const stake = ethers.utils.parseUnits("10000000", 9);

    beforeEach(async function () {
      await arena.connect(challenger).issueChallenge(grok.address, stake, pepe.address, DURATION_48H, MEME_HASH_1, 0);
    });

    it("isChallengeAcceptable = true when open", async function () {
      expect(await arena.isChallengeAcceptable(0)).to.equal(true);
    });

    it("isChallengeAcceptable = false after expiry", async function () {
      await advanceTime(72 * HOUR + 1);
      expect(await arena.isChallengeAcceptable(0)).to.equal(false);
    });

    it("isSettleable = false during voting", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, ethers.utils.parseUnits("100000000", 18), MEME_HASH_2);
      await arena.connect(challenger).call(0, 0);
      expect(await arena.isSettleable(0)).to.equal(false);
    });

    it("isSettleable = true after voting", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, ethers.utils.parseUnits("100000000", 18), MEME_HASH_2);
      await arena.connect(challenger).call(0, 0);
      await advanceTime(DURATION_48H);
      expect(await arena.isSettleable(0)).to.equal(true);
    });

    it("hasWalletVoted tracks correctly", async function () {
      await arena.connect(opponent).acceptChallenge(0, pepe.address, ethers.utils.parseUnits("100000000", 18), MEME_HASH_2);
      await arena.connect(challenger).call(0, 0);
      expect(await arena.hasWalletVoted(0, voter1.address)).to.equal(false);
      await arena.connect(voter1).castVote(0, Team.Challenger);
      expect(await arena.hasWalletVoted(0, voter1.address)).to.equal(true);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  FULL E2E
  // ═══════════════════════════════════════════════════════════════

  describe("Full Battle End-to-End", function () {
    it("challenge → accept → raise → call → vote → settle", async function () {
      const s1 = ethers.utils.parseUnits("10000000", 9);
      const s2 = ethers.utils.parseUnits("500000000", 18);
      const r1 = ethers.utils.parseUnits("5000000", 9);
      const r2 = ethers.utils.parseUnits("200000000", 18);

      await arena.connect(challenger).issueChallenge(grok.address, s1, pepe.address, DURATION_48H, MEME_HASH_1, 0);
      await arena.connect(opponent).acceptChallenge(0, pepe.address, s2, MEME_HASH_2);
      await arena.connect(challenger).raise(0, r1);
      await arena.connect(opponent).raise(0, r2);
      await arena.connect(challenger).call(0, r1);

      eq((await arena.getBattle(0)).status, Status.Battling);

      await arena.connect(voter1).castVote(0, Team.Challenger);
      await arena.connect(voter2).castVote(0, Team.Challenger);
      await arena.connect(voter3).castVote(0, Team.Opponent);

      await advanceTime(DURATION_48H);

      const gDead = await grok.balanceOf(DEAD_ADDRESS);
      const pDead = await pepe.balanceOf(DEAD_ADDRESS);
      await arena.connect(outsider).settleBattle(0);

      const b = await arena.getBattle(0);
      eq(b.status, Status.Settled);
      eq(b.winner, Team.Challenger);
      eq(b.challengerVotes, 2);
      eq(b.opponentVotes, 1);
      gt(await grok.balanceOf(DEAD_ADDRESS), gDead);
      gt(await pepe.balanceOf(DEAD_ADDRESS), pDead);
      eq(await arena.totalBattlesSettled(), 1);
      gt(await arena.totalGrokBurned(), 0);
    });
  });
});
