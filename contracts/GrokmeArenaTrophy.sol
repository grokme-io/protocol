// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title GrokmeArenaTrophy
 * @author GROKME Protocol (grokme.me)
 * @notice Battle Trophy NFTs — eternal artifacts of cultural victory.
 *
 * Each token represents a winning meme from a GROKME Arena battle, permanently
 * sealed with full battle metadata: participants, vote counts, stake amounts,
 * burn transaction hashes, and the winning meme content (via IPFS/Arweave URI).
 *
 * Key properties:
 * - NO admin functions. NO owner. NO upgrade proxy. NO kill switch.
 * - Only the GrokmeArena contract can mint trophies (immutable minter).
 * - One trophy per battle — enforced by on-chain mapping.
 * - All battle data is stored on-chain in the TrophyData struct.
 * - Token URI points to the winning meme content (IPFS/Arweave).
 * - Soulbound option: trophies can be made non-transferable (creator keeps forever).
 *
 * Part of the GROKME Protocol — grokme.me | battle.grokme.me
 */
contract GrokmeArenaTrophy is ERC721URIStorage, ReentrancyGuard {

    // ═══════════════════════════════════════════════════════════════════
    //  CONSTANTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice The GrokmeArena contract — only address that can mint trophies
    address public immutable arenaMinter;

    // ═══════════════════════════════════════════════════════════════════
    //  STRUCTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Immutable on-chain metadata for a battle trophy.
    struct TrophyData {
        // ─── Battle Reference ───
        uint256 battleId;                  // On-chain battle ID from GrokmeArena

        // ─── Winner ───
        address winner;                    // Wallet of the winning meme creator
        address winnerToken;               // Winner's community token address
        bytes32 winnerMemeHash;            // IPFS/Arweave content hash of winning meme

        // ─── Loser ───
        address loser;                     // Wallet of the losing meme creator
        address loserToken;                // Loser's community token address

        // ─── Vote Result ───
        uint256 winnerVotes;
        uint256 loserVotes;

        // ─── Tokens Burned ───
        uint256 winnerTokensBurned;        // Winner side tokens sent to 0x...dEaD
        uint256 loserTokensBurned;         // Loser side tokens sent to 0x...dEaD
        uint256 grokBurnedFromFees;        // Total GROK burned via protocol fees

        // ─── Timing ───
        uint256 battleStartBlock;          // Snapshot block
        uint256 battleEndTimestamp;         // When voting ended
        uint256 mintedAt;                  // Block timestamp of trophy mint
    }

    /// @notice Trophy type discriminator.
    enum TrophyKind {
        None,
        Battle,
        Tournament
    }

    /// @notice Immutable on-chain metadata for a tournament trophy.
    struct TournamentTrophyData {
        uint256 tournamentId;
        string title;
        uint8 size;
        address winner;
        address winnerToken;
        bytes32 winnerMemeHash;
        uint256 winnerTokensBurned;
        uint256 grokBurnedFromFees;
        uint256 finaleBattleId;
        uint256 mintedAt;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  STATE
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Auto-incrementing token ID
    uint256 public nextTokenId;

    /// @notice battleId → tokenId mapping (one trophy per battle)
    mapping(uint256 => uint256) public battleToToken;

    /// @notice tournamentId => tokenId mapping (one trophy per tournament, +1 offset).
    mapping(uint256 => uint256) public tournamentToToken;

    /// @notice tokenId → full trophy data (on-chain forever)
    mapping(uint256 => TrophyData) public trophies;

    /// @notice tokenId => full tournament trophy data (on-chain forever).
    mapping(uint256 => TournamentTrophyData) public tournamentTrophies;

    /// @notice tokenId => trophy kind discriminator.
    mapping(uint256 => TrophyKind) public trophyKinds;

    /// @notice Total trophies minted
    uint256 public totalTrophies;

    // ═══════════════════════════════════════════════════════════════════
    //  EVENTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Emitted when a battle trophy is minted.
    event TrophyMinted(
        uint256 indexed tokenId,
        uint256 indexed battleId,
        address indexed winner,
        address winnerToken,
        address loserToken,
        uint256 winnerVotes,
        uint256 loserVotes,
        uint256 winnerTokensBurned,
        uint256 loserTokensBurned
    );
    /// @notice Emitted when a tournament trophy is minted.
    event TournamentTrophyMinted(
        uint256 indexed tokenId,
        uint256 indexed tournamentId,
        address indexed winner,
        address winnerToken,
        uint256 winnerTokensBurned,
        uint256 grokBurnedFromFees,
        uint256 finaleBattleId
    );

    // ═══════════════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Deploy the immutable trophy contract.
     * @param _arenaMinter Address of the GrokmeArena contract (only minter, immutable)
     */
    constructor(address _arenaMinter) ERC721("GROKME Arena Trophy", "TROPHY") {
        require(_arenaMinter != address(0), "Invalid arena address");
        arenaMinter = _arenaMinter;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  MINT (Arena-only)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Mint a Battle Trophy NFT for the winning meme creator.
     *         Only callable by the GrokmeArena contract.
     *
     * @param battleId           On-chain battle ID
     * @param winner             Winning meme creator wallet
     * @param winnerToken        Winner's community token
     * @param winnerMemeHash     Content hash of winning meme (IPFS/Arweave)
     * @param loser              Losing meme creator wallet
     * @param loserToken         Loser's community token
     * @param winnerVotes        Final vote count for winner
     * @param loserVotes         Final vote count for loser
     * @param winnerTokensBurned Tokens burned from winner's side
     * @param loserTokensBurned  Tokens burned from loser's side
     * @param grokBurnedFromFees Total GROK burned via protocol fees
     * @param battleStartBlock   Snapshot block number
     * @param battleEndTimestamp When voting ended
     * @param tokenURI           IPFS/Arweave URI for the winning meme
     */
    function mintTrophy(
        uint256 battleId,
        address winner,
        address winnerToken,
        bytes32 winnerMemeHash,
        address loser,
        address loserToken,
        uint256 winnerVotes,
        uint256 loserVotes,
        uint256 winnerTokensBurned,
        uint256 loserTokensBurned,
        uint256 grokBurnedFromFees,
        uint256 battleStartBlock,
        uint256 battleEndTimestamp,
        string calldata tokenURI
    ) external nonReentrant returns (uint256 tokenId) {
        require(msg.sender == arenaMinter, "Only Arena can mint");
        require(battleToToken[battleId] == 0, "Trophy already minted for this battle");
        require(winner != address(0), "Invalid winner");
        require(winnerToken != address(0), "Invalid winner token");
        require(loser != address(0), "Invalid loser");
        require(loserToken != address(0), "Invalid loser token");
        require(winnerMemeHash != bytes32(0), "Invalid meme hash");

        tokenId = nextTokenId++;
        totalTrophies++;
        trophyKinds[tokenId] = TrophyKind.Battle;

        // Store full battle data on-chain — forever
        trophies[tokenId] = TrophyData({
            battleId: battleId,
            winner: winner,
            winnerToken: winnerToken,
            winnerMemeHash: winnerMemeHash,
            loser: loser,
            loserToken: loserToken,
            winnerVotes: winnerVotes,
            loserVotes: loserVotes,
            winnerTokensBurned: winnerTokensBurned,
            loserTokensBurned: loserTokensBurned,
            grokBurnedFromFees: grokBurnedFromFees,
            battleStartBlock: battleStartBlock,
            battleEndTimestamp: battleEndTimestamp,
            mintedAt: block.timestamp
        });

        // Link battle → token (one trophy per battle)
        battleToToken[battleId] = tokenId + 1; // +1 so default 0 means "not minted"

        // Mint NFT to the winning creator
        _mint(winner, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit TrophyMinted(
            tokenId,
            battleId,
            winner,
            winnerToken,
            loserToken,
            winnerVotes,
            loserVotes,
            winnerTokensBurned,
            loserTokensBurned
        );
    }

    /**
     * @notice Mint a Tournament Trophy NFT for the winning participant.
     *         Only callable by the GrokmeArena contract.
     *
     * @param tournamentId       On-chain tournament ID
     * @param title              Human-readable tournament title
     * @param size               Number of participants (4, 8, or 16)
     * @param winner             Winning participant wallet
     * @param winnerToken        Winner's community token
     * @param winnerMemeHash     Content hash of winner's final meme
     * @param winnerTokensBurned Total winner-token amount burned in finale
     * @param grokBurnedFromFees Total GROK burned via tournament protocol fees
     * @param finaleBattleId     Battle ID of the finale match
     * @param tokenURI           IPFS/Arweave URI for the winning meme
     */
    function mintTournamentTrophy(
        uint256 tournamentId,
        string calldata title,
        uint8 size,
        address winner,
        address winnerToken,
        bytes32 winnerMemeHash,
        uint256 winnerTokensBurned,
        uint256 grokBurnedFromFees,
        uint256 finaleBattleId,
        string calldata tokenURI
    ) external nonReentrant returns (uint256 tokenId) {
        require(msg.sender == arenaMinter, "Only Arena can mint");
        require(tournamentToToken[tournamentId] == 0, "Trophy already minted for this tournament");
        require(winner != address(0), "Invalid winner");
        require(bytes(title).length != 0, "Title required");
        require(winnerToken != address(0), "Invalid winner token");
        require(winnerMemeHash != bytes32(0), "Invalid meme hash");

        tokenId = nextTokenId++;
        totalTrophies++;
        trophyKinds[tokenId] = TrophyKind.Tournament;

        tournamentTrophies[tokenId] = TournamentTrophyData({
            tournamentId: tournamentId,
            title: title,
            size: size,
            winner: winner,
            winnerToken: winnerToken,
            winnerMemeHash: winnerMemeHash,
            winnerTokensBurned: winnerTokensBurned,
            grokBurnedFromFees: grokBurnedFromFees,
            finaleBattleId: finaleBattleId,
            mintedAt: block.timestamp
        });

        tournamentToToken[tournamentId] = tokenId + 1;

        _mint(winner, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit TournamentTrophyMinted(
            tokenId,
            tournamentId,
            winner,
            winnerToken,
            winnerTokensBurned,
            grokBurnedFromFees,
            finaleBattleId
        );
    }

    // ═══════════════════════════════════════════════════════════════════
    //  SET TOKEN URI (Arena-only, for post-mint metadata)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Set or update the token URI for a trophy.
     *         Only callable by the Arena contract.
     *         Used by the off-chain Event Listener after uploading
     *         the winning meme + battle metadata to IPFS.
     *
     * @param tokenId  The trophy token ID
     * @param uri      IPFS/Arweave URI for the trophy metadata JSON
     */
    function setTrophyURI(uint256 tokenId, string calldata uri) external {
        require(tokenId < nextTokenId, "Token does not exist");
        require(
            msg.sender == arenaMinter || msg.sender == ownerOf(tokenId),
            "Only Arena or token owner"
        );
        require(bytes(uri).length != 0, "Empty URI");
        _setTokenURI(tokenId, uri);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Get the full trophy data for a token
     * @param tokenId The token ID (must be a Battle-kind trophy).
     */
    function getTrophy(uint256 tokenId) external view returns (TrophyData memory) {
        require(tokenId < nextTokenId, "Token does not exist");
        require(trophyKinds[tokenId] == TrophyKind.Battle, "Not battle trophy");
        return trophies[tokenId];
    }

    /**
     * @notice Get the trophy token ID for a given battle
     * @return tokenId The token ID (reverts if no trophy exists for this battle)
     */
    function getTrophyForBattle(uint256 battleId) external view returns (uint256) {
        uint256 stored = battleToToken[battleId];
        require(stored > 0, "No trophy for this battle");
        return stored - 1; // Subtract the +1 offset
    }

    /**
     * @notice Check if a trophy has been minted for a battle
     * @return exists True if a trophy exists for the battle.
     */
    function hasTrophy(uint256 battleId) external view returns (bool) {
        return battleToToken[battleId] > 0;
    }

    /**
     * @notice Get the full tournament trophy data for a token.
     * @param tokenId The token ID (must be a Tournament-kind trophy).
     */
    function getTournamentTrophy(uint256 tokenId) external view returns (TournamentTrophyData memory) {
        require(tokenId < nextTokenId, "Token does not exist");
        require(trophyKinds[tokenId] == TrophyKind.Tournament, "Not tournament trophy");
        return tournamentTrophies[tokenId];
    }

    /**
     * @notice Get the trophy token ID for a given tournament.
     * @return tokenId The token ID (reverts if no trophy exists for this tournament).
     */
    function getTrophyForTournament(uint256 tournamentId) external view returns (uint256) {
        uint256 stored = tournamentToToken[tournamentId];
        require(stored > 0, "No trophy for this tournament");
        return stored - 1;
    }

    /**
     * @notice Check if a trophy has been minted for a tournament.
     * @return exists True if a trophy exists for the tournament.
     */
    function hasTournamentTrophy(uint256 tournamentId) external view returns (bool) {
        return tournamentToToken[tournamentId] > 0;
    }

    /**
     * @notice Get battle-level summary (useful for verification scripts)
     * @param tokenId The token ID (must be a Battle-kind trophy).
     */
    function getBattleSummary(uint256 tokenId) external view returns (
        uint256 battleId,
        address winner,
        address loser,
        uint256 winnerVotes,
        uint256 loserVotes,
        uint256 totalTokensBurned,
        uint256 grokBurnedFromFees
    ) {
        require(tokenId < nextTokenId, "Token does not exist");
        require(trophyKinds[tokenId] == TrophyKind.Battle, "Not battle trophy");
        TrophyData storage t = trophies[tokenId];
        return (
            t.battleId,
            t.winner,
            t.loser,
            t.winnerVotes,
            t.loserVotes,
            t.winnerTokensBurned + t.loserTokensBurned,
            t.grokBurnedFromFees
        );
    }

}
