const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GrokmeArenaTrophy", function () {
  let trophy;
  let arena; // simulated arena (deployer acts as minter)
  let winner, loser, random;

  // ── Helpers (same pattern as GrokmeArena.test.js) ──
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

  const BATTLE_ID = 42;
  const WINNER_VOTES = 8234;
  const LOSER_VOTES = 4102;
  const WINNER_BURNED = ethers.utils.parseEther("8000000"); // 8M tokens
  const LOSER_BURNED = ethers.utils.parseEther("24000000"); // 24M tokens
  const GROK_FEE_BURNED = ethers.utils.parseEther("500000"); // 500K GROK
  const SNAPSHOT_BLOCK = 19000000;
  const BATTLE_END = Math.floor(Date.now() / 1000);
  const MEME_HASH = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("grok-laser-eyes.png"));
  const TOKEN_URI = "ipfs://QmWinningMemeHash123456789";

  beforeEach(async function () {
    [arena, winner, loser, random] = await ethers.getSigners();

    const Trophy = await ethers.getContractFactory("GrokmeArenaTrophy");
    trophy = await Trophy.deploy(arena.address);
    await trophy.deployed();
  });

  // ═══════════════════════════════════════════════════════════════════
  //  DEPLOYMENT
  // ═══════════════════════════════════════════════════════════════════

  describe("Deployment", function () {
    it("should set correct name and symbol", async function () {
      expect(await trophy.name()).to.equal("GROKME Arena Trophy");
      expect(await trophy.symbol()).to.equal("TROPHY");
    });

    it("should set arena minter correctly", async function () {
      expect(await trophy.arenaMinter()).to.equal(arena.address);
    });

    it("should start with 0 trophies", async function () {
      eq(await trophy.totalTrophies(), 0);
      eq(await trophy.nextTokenId(), 0);
    });

    it("should reject zero address as minter", async function () {
      const Trophy = await ethers.getContractFactory("GrokmeArenaTrophy");
      await expectRevert(
        Trophy.deploy(ethers.constants.AddressZero),
        "Invalid arena address"
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  MINTING
  // ═══════════════════════════════════════════════════════════════════

  describe("Minting", function () {
    async function mintTrophy(battleId = BATTLE_ID) {
      return trophy.connect(arena).mintTrophy(
        battleId,
        winner.address,
        winner.address, // winnerToken (simplified: using wallet as token for tests)
        MEME_HASH,
        loser.address,
        loser.address, // loserToken
        WINNER_VOTES,
        LOSER_VOTES,
        WINNER_BURNED,
        LOSER_BURNED,
        GROK_FEE_BURNED,
        SNAPSHOT_BLOCK,
        BATTLE_END,
        TOKEN_URI
      );
    }

    it("should mint a trophy to the winner", async function () {
      await mintTrophy();

      expect(await trophy.ownerOf(0)).to.equal(winner.address);
      eq(await trophy.totalTrophies(), 1);
      eq(await trophy.nextTokenId(), 1);
    });

    it("should store the token URI", async function () {
      await mintTrophy();
      expect(await trophy.tokenURI(0)).to.equal(TOKEN_URI);
    });

    it("should store complete trophy data on-chain", async function () {
      await mintTrophy();

      const t = await trophy.getTrophy(0);
      eq(t.battleId, BATTLE_ID);
      expect(t.winner).to.equal(winner.address);
      expect(t.winnerMemeHash).to.equal(MEME_HASH);
      expect(t.loser).to.equal(loser.address);
      eq(t.winnerVotes, WINNER_VOTES);
      eq(t.loserVotes, LOSER_VOTES);
      eq(t.winnerTokensBurned, WINNER_BURNED);
      eq(t.loserTokensBurned, LOSER_BURNED);
      eq(t.grokBurnedFromFees, GROK_FEE_BURNED);
      eq(t.battleStartBlock, SNAPSHOT_BLOCK);
      eq(t.battleEndTimestamp, BATTLE_END);
      expect(t.mintedAt.gt(0)).to.equal(true);
    });

    it("should emit TrophyMinted event", async function () {
      const tx = await mintTrophy();
      await expectEvent(tx, "TrophyMinted");
    });

    it("should link battle to token via battleToToken mapping", async function () {
      await mintTrophy();
      expect(await trophy.hasTrophy(BATTLE_ID)).to.equal(true);
      eq(await trophy.getTrophyForBattle(BATTLE_ID), 0);
    });

    it("should increment token IDs correctly for multiple battles", async function () {
      await mintTrophy(1);
      await mintTrophy(2);
      await mintTrophy(3);

      eq(await trophy.totalTrophies(), 3);
      eq(await trophy.nextTokenId(), 3);

      expect(await trophy.ownerOf(0)).to.equal(winner.address);
      expect(await trophy.ownerOf(1)).to.equal(winner.address);
      expect(await trophy.ownerOf(2)).to.equal(winner.address);

      eq(await trophy.getTrophyForBattle(1), 0);
      eq(await trophy.getTrophyForBattle(2), 1);
      eq(await trophy.getTrophyForBattle(3), 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  ACCESS CONTROL
  // ═══════════════════════════════════════════════════════════════════

  describe("Access Control", function () {
    it("should reject minting from non-arena address", async function () {
      await expectRevert(
        trophy.connect(random).mintTrophy(
          BATTLE_ID, winner.address, winner.address, MEME_HASH,
          loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
          WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
          SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
        ),
        "Only Arena can mint"
      );
    });

    it("should reject minting from winner themselves", async function () {
      await expectRevert(
        trophy.connect(winner).mintTrophy(
          BATTLE_ID, winner.address, winner.address, MEME_HASH,
          loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
          WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
          SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
        ),
        "Only Arena can mint"
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  DUPLICATE PREVENTION
  // ═══════════════════════════════════════════════════════════════════

  describe("Duplicate Prevention", function () {
    it("should prevent minting two trophies for the same battle", async function () {
      await trophy.connect(arena).mintTrophy(
        BATTLE_ID, winner.address, winner.address, MEME_HASH,
        loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
        WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
        SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
      );

      await expectRevert(
        trophy.connect(arena).mintTrophy(
          BATTLE_ID, winner.address, winner.address, MEME_HASH,
          loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
          WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
          SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
        ),
        "Trophy already minted for this battle"
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  VALIDATION
  // ═══════════════════════════════════════════════════════════════════

  describe("Validation", function () {
    it("should reject zero address as winner", async function () {
      await expectRevert(
        trophy.connect(arena).mintTrophy(
          BATTLE_ID, ethers.constants.AddressZero, winner.address, MEME_HASH,
          loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
          WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
          SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
        ),
        "Invalid winner"
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  VIEW FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════

  describe("View Functions", function () {
    beforeEach(async function () {
      await trophy.connect(arena).mintTrophy(
        BATTLE_ID, winner.address, winner.address, MEME_HASH,
        loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
        WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
        SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
      );
    });

    it("getTrophy should return full data", async function () {
      const t = await trophy.getTrophy(0);
      eq(t.battleId, BATTLE_ID);
      expect(t.winner).to.equal(winner.address);
    });

    it("getTrophy should revert for non-existent token", async function () {
      await expectRevert(trophy.getTrophy(999), "Token does not exist");
    });

    it("getTrophyForBattle should return correct token ID", async function () {
      eq(await trophy.getTrophyForBattle(BATTLE_ID), 0);
    });

    it("getTrophyForBattle should revert for battle without trophy", async function () {
      await expectRevert(trophy.getTrophyForBattle(999), "No trophy for this battle");
    });

    it("hasTrophy should return true for minted battle", async function () {
      expect(await trophy.hasTrophy(BATTLE_ID)).to.equal(true);
    });

    it("hasTrophy should return false for non-minted battle", async function () {
      expect(await trophy.hasTrophy(999)).to.equal(false);
    });

    it("getBattleSummary should return correct totals", async function () {
      const [battleId, w, l, wVotes, lVotes, totalBurned, grokFees] =
        await trophy.getBattleSummary(0);

      eq(battleId, BATTLE_ID);
      expect(w).to.equal(winner.address);
      expect(l).to.equal(loser.address);
      eq(wVotes, WINNER_VOTES);
      eq(lVotes, LOSER_VOTES);
      eq(totalBurned, WINNER_BURNED.add(LOSER_BURNED));
      eq(grokFees, GROK_FEE_BURNED);
    });

    it("getBattleSummary should revert for non-existent token", async function () {
      await expectRevert(trophy.getBattleSummary(999), "Token does not exist");
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  ERC-721 STANDARD
  // ═══════════════════════════════════════════════════════════════════

  describe("ERC-721 Standard", function () {
    beforeEach(async function () {
      await trophy.connect(arena).mintTrophy(
        BATTLE_ID, winner.address, winner.address, MEME_HASH,
        loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
        WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
        SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
      );
    });

    it("should support ERC-721 interface", async function () {
      // ERC-721 interface ID
      expect(await trophy.supportsInterface("0x80ac58cd")).to.equal(true);
    });

    it("should allow trophy transfer by owner", async function () {
      await trophy.connect(winner).transferFrom(winner.address, random.address, 0);
      expect(await trophy.ownerOf(0)).to.equal(random.address);
    });

    it("should track balance correctly", async function () {
      eq(await trophy.balanceOf(winner.address), 1);

      // Mint another trophy for a different battle
      await trophy.connect(arena).mintTrophy(
        99, winner.address, winner.address, MEME_HASH,
        loser.address, loser.address, WINNER_VOTES, LOSER_VOTES,
        WINNER_BURNED, LOSER_BURNED, GROK_FEE_BURNED,
        SNAPSHOT_BLOCK, BATTLE_END, TOKEN_URI
      );

      eq(await trophy.balanceOf(winner.address), 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  NO ADMIN FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════

  describe("No Admin Functions", function () {
    it("should have no owner/admin capability", async function () {
      // GrokmeArenaTrophy does NOT inherit Ownable
      // Verify there's no owner() function
      expect(trophy.owner).to.be.undefined;
    });

    it("should have immutable minter (cannot be changed)", async function () {
      // arenaMinter is immutable — set in constructor, cannot change
      expect(await trophy.arenaMinter()).to.equal(arena.address);
      // No function to change it exists
      expect(trophy.setMinter).to.be.undefined;
      expect(trophy.transferOwnership).to.be.undefined;
    });
  });
});
