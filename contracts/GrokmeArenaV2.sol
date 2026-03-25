// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title IGrokmeArenaTrophyV2
 * @notice Minimal interface for the Battle Trophy NFT contract
 */
interface IGrokmeArenaTrophyV2 {
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
    ) external returns (uint256 tokenId);

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
    ) external returns (uint256 tokenId);
}

/**
 * @title IUniswapV2Router02
 * @notice Minimal interface for Uniswap V2 Router swap functionality
 */
interface IUniswapV2Router02 {
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function WETH() external pure returns (address);
}

/**
 * @title GrokmeArenaV2
 * @author GROKME Protocol (grokme.me)
 * @notice GROKME Arena V2 — Proof-of-Culture Meme Battle Protocol with Tournaments.
 *
 * @dev A decentralized, on-chain Meme Battle smart contract. Challengers stake
 * ERC-20 tokens behind a meme and dare an opponent to bring something better.
 * The community votes. The winning meme becomes an eternal NFT. The losing
 * meme is destroyed. All staked tokens from both sides are burned.
 *
 * V2 improvements over V1:
 * - Accept & Start in one TX (skip bidding when stakes match)
 * - Raise rollback on bidding timeout (unanswered raise refunded)
 * - Settler bounty: 0.5% of pot incentivizes permissionless settlement
 * - Pull-over-push refund pattern (defense-in-depth)
 * - Native tournament bracket mode (4/8/16 participants)
 * - Full NatSpec documentation
 * - All SolidityScan V1 findings addressed
 *
 * Key properties:
 * - NO admin functions. NO owner. NO upgrade proxy. NO kill switch. NO oracle.
 * - 5% protocol fee on every deposit → auto-swapped to GROK → burned.
 * - Voting is on-chain, 1 wallet = 1 vote, token-holding verified.
 * - Settlement is permissionless — anyone can call settleBattle().
 * - All contract state is publicly verifiable on Etherscan.
 *
 * Part of the GROKME Protocol — grokme.me | arena.grokme.me
 */
contract GrokmeArenaV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════════
    //  CONSTANTS
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Universal burn address accepted by all ERC-20 tokens.
    address private constant _DEAD = 0x000000000000000000000000000000000000dEaD;

    /// @notice Protocol fee: 5% of every deposit is swapped to GROK and burned.
    uint256 private constant _PROTOCOL_FEE_BPS = 500;

    /// @notice Settler reward: 0.5% of each side's stake goes to whoever settles.
    uint256 private constant _SETTLER_REWARD_BPS = 50;

    /// @dev Basis point denominator (100% = 10_000).
    uint256 private constant _BPS = 10_000;

    /// @notice Challenged community has 72 hours to accept.
    uint256 private constant _CHALLENGE_EXPIRY = 72 hours;

    /// @notice Maximum raise rounds to prevent griefing.
    uint256 private constant _MAX_RAISE_ROUNDS = 10;

    /// @notice Bidding phase timeout — 24 hours to respond.
    uint256 private constant _BIDDING_TIMEOUT = 24 hours;

    /// @notice Uniswap swap deadline grace (5 minutes from execution).
    uint256 private constant _SWAP_DEADLINE_GRACE = 5 minutes;

    /// @notice Grace period before settleAfterGrace() becomes callable (48 hours after voting ends).
    uint256 private constant _SETTLEMENT_GRACE = 48 hours;

    /// @notice Maximum number of UTF-8 bytes allowed for a tournament title.
    uint256 private constant _MAX_TOURNAMENT_TITLE_LENGTH = 64;

    // ═══════════════════════════════════════════════════════════════════
    //  IMMUTABLES
    // ═══════════════════════════════════════════════════════════════════

    /// @notice The GROK ERC-20 token address (protocol fee burns this).
    address public immutable grokToken;

    /// @notice Uniswap V2 Router for protocol fee swaps.
    IUniswapV2Router02 public immutable uniswapRouter;

    /// @notice WETH address (for swap routing).
    address public immutable weth;

    /// @notice Battle Trophy NFT contract — mints winner NFTs on settlement.
    IGrokmeArenaTrophyV2 public immutable trophyContract;

    // ═══════════════════════════════════════════════════════════════════
    //  ENUMS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Battle lifecycle status.
    enum Status {
        Open,       // Challenge issued, waiting for opponent
        Bidding,    // Opponent accepted, raise/call/fold phase
        Battling,   // Both locked, voting in progress
        Settled,    // Battle concluded, tokens burned
        Expired,    // No one accepted within 72h
        Folded      // One side folded during bidding
    }

    /// @notice Side in a battle.
    enum Team { None, Challenger, Opponent }

    // ═══════════════════════════════════════════════════════════════════
    //  STRUCTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Full battle state. Packed for gas efficiency.
    /// @dev Fields ordered to minimize storage slots.
    struct Battle {
        // ─── Slot 1: Challenger identity ───
        address challenger;
        Status  status;             // uint8
        Team    winner;             // uint8
        uint8   raiseCount;

        // ─── Slot 2: Challenger token ───
        address challengerToken;

        // ─── Slot 3+4: Challenger amounts ───
        uint256 challengerStake;
        bytes32 challengerMemeHash;

        // ─── Slot 5: Opponent identity ───
        address opponent;

        // ─── Slot 6: Opponent token ───
        address opponentToken;

        // ─── Slot 7+8: Opponent amounts ───
        uint256 opponentStake;
        bytes32 opponentMemeHash;

        // ─── Slot 9: Challenge params ───
        address targetToken;

        // ─── Slot 10: Timing (packed as uint48) ───
        uint48  duration;
        uint48  createdAt;
        uint48  battleStartsAt;
        uint48  battleEndsAt;
        uint48  lastBiddingAction;

        // ─── Slot 11: Voting ───
        uint256 snapshotBlock;
        uint256 challengerVotes;
        uint256 opponentVotes;

        // ─── Slot 12: Pending response ───
        address pendingResponse;
        uint256 minVoterBalance;

        // ─── Slot 13: Raise rollback state ───
        uint256 challengerStakeBeforeLastRaise;
        uint256 opponentStakeBeforeLastRaise;
        address lastRaiser;
        uint256 lastRaiseAmount;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  STATE
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Auto-incrementing battle ID counter.
    uint256 public nextBattleId;

    /// @notice Battle data by ID.
    mapping(uint256 battleId => Battle) public battles;

    /// @notice Tracks whether a wallet has voted in a battle.
    mapping(uint256 battleId => mapping(address voter => bool)) public hasVoted;

    /// @notice GROK burned from protocol fees per battle.
    mapping(uint256 battleId => uint256) public battleGrokFees;

    /// @notice GROK burned from protocol fees per tournament.
    mapping(uint256 tournamentId => uint256) public tournamentGrokFees;

    /// @notice Pending refunds claimable by users (pull pattern).
    mapping(address wallet => mapping(address token => uint256)) public pendingRefunds;

    /// @dev Marks Arena battles that were created as tournament bracket matches.
    mapping(uint256 battleId => bool isTournamentBattle) private _isTournamentBattle;

    /// @notice Total GROK burned through protocol fees (lifetime).
    uint256 public totalGrokBurned;

    /// @notice Total battles settled.
    uint256 public totalBattlesSettled;

    // ═══════════════════════════════════════════════════════════════════
    //  EVENTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Emitted when a new challenge is created.
    event ChallengeIssued(
        uint256 indexed battleId,
        address indexed challenger,
        address challengerToken,
        uint256 stakeAfterFee,
        address targetToken,
        bytes32 memeHash,
        uint256 duration,
        uint256 minVoterBalance
    );

    /// @notice Emitted when an opponent accepts a challenge.
    event ChallengeAccepted(
        uint256 indexed battleId,
        address indexed opponent,
        address opponentToken,
        uint256 stakeAfterFee,
        bytes32 memeHash,
        bool    startedImmediately
    );

    /// @notice Emitted when a side raises during bidding.
    event Raised(
        uint256 indexed battleId,
        address indexed raiser,
        uint256 additionalStakeAfterFee
    );

    /// @notice Emitted when a side calls during bidding.
    event Called(uint256 indexed battleId, address indexed caller, uint256 additionalStakeAfterFee);

    /// @notice Emitted when a side folds during bidding.
    event Folded(uint256 indexed battleId, address indexed folder);

    /// @notice Emitted when voting phase begins.
    event BattleStarted(uint256 indexed battleId, uint256 snapshotBlock, uint256 endsAt);

    /// @notice Emitted when a vote is cast.
    event VoteCast(uint256 indexed battleId, address indexed voter, Team team, uint256 voterBalance);

    /// @notice Emitted when a battle is settled.
    event BattleSettled(
        uint256 indexed battleId,
        Team    winner,
        uint256 challengerVotes,
        uint256 opponentVotes,
        uint256 challengerTokensBurned,
        uint256 opponentTokensBurned,
        address settledBy,
        uint256 settlerRewardChallenger,
        uint256 settlerRewardOpponent
    );

    /// @notice Emitted when protocol fee is swapped to GROK and burned.
    event ProtocolFeeBurned(
        uint256 indexed battleId,
        address indexed fromToken,
        uint256 tokenAmount,
        uint256 grokBurned
    );

    /// @notice Emitted when tournament protocol fee is swapped to GROK and burned.
    event TournamentProtocolFeeBurned(
        uint256 indexed tournamentId,
        address indexed fromToken,
        uint256 tokenAmount,
        uint256 grokBurned
    );

    /// @notice Emitted when a challenge expires unaccepted.
    event ChallengeExpired(uint256 indexed battleId);

    /// @notice Emitted when a refund is queued for claiming.
    event RefundQueued(address indexed to, address indexed token, uint256 amount);

    /// @notice Emitted when a user claims a pending refund.
    event RefundClaimed(address indexed claimant, address indexed token, uint256 amount);

    /// @notice Emitted when trophy minting fails (non-blocking).
    event TrophyMintFailed(uint256 indexed battleId, string reason);

    /// @notice Emitted when a battle trophy mint succeeds after settlement.
    event TrophyMintSucceeded(uint256 indexed battleId, uint256 indexed tokenId);

    /// @notice Emitted when tournament trophy minting fails (non-blocking).
    event TournamentTrophyMintFailed(uint256 indexed tournamentId, string reason);

    /// @notice Emitted when a tournament trophy mint succeeds after settlement.
    event TournamentTrophyMintSucceeded(uint256 indexed tournamentId, uint256 indexed tokenId);

    /// @notice Emitted when a token swap to winner's currency fails during tournament settlement.
    ///         The original token is burned directly to 0xdEaD instead.
    ///         Frontend should display this publicly on tournament results.
    event SwapFallbackBurn(
        uint256 indexed tournamentId,
        address indexed tokenBurned,
        uint256 amountBurned,
        address intendedTargetToken
    );

    /// @notice Emitted when a raise is rolled back due to bidding timeout.
    event RaiseRolledBack(uint256 indexed battleId, address indexed raiser, uint256 amount);

    // ═══════════════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Deploy the Arena V2 contract.
    /// @dev All parameters are set as immutables — no admin, no changes after deploy.
    /// @param _grokToken GROK ERC-20 address.
    /// @param _uniswapRouter Uniswap V2 Router address.
    /// @param _trophyContract GrokmeArenaTrophyV2 NFT contract address.
    constructor(
        address _grokToken,
        address _uniswapRouter,
        address _trophyContract
    ) payable {
        require(_grokToken != address(0), "Zero GROK address");
        require(_uniswapRouter != address(0), "Zero router address");
        require(_trophyContract != address(0), "Zero trophy address");
        grokToken = _grokToken;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        weth = IUniswapV2Router02(_uniswapRouter).WETH();
        trophyContract = IGrokmeArenaTrophyV2(_trophyContract);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 1 — ISSUE CHALLENGE
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Create a new meme battle challenge.
    /// @dev Transfers tokens from caller. 5% protocol fee is swapped to GROK and burned immediately.
    /// @param token ERC-20 token to stake (challenger's community token).
    /// @param amount Amount of tokens to stake (before protocol fee).
    /// @param targetToken Rival community token. address(0) = open challenge.
    /// @param duration Voting duration in seconds (min 5 minutes, max 35 days).
    /// @param memeHash IPFS/Arweave hash of the challenger's meme.
    /// @param minVoterBal Minimum token balance required to vote (0 = no minimum).
    /// @return battleId The newly created battle ID.
    function issueChallenge(
        address token,
        uint256 amount,
        address targetToken,
        uint256 duration,
        bytes32 memeHash,
        uint256 minVoterBal
    ) external nonReentrant returns (uint256 battleId) {
        require(token != address(0), "Zero token address");
        require(amount != 0, "Stake must be > 0");
        require(memeHash != bytes32(0), "Meme hash required");
        require(duration >= 5 minutes && duration <= 35 days, "Duration: 5min-35d");

        // Deposit + fee
        (uint256 stakeAfterFee, uint256 fee) = _depositWithFee(token, amount);

        // Assign battle ID before external calls (CEI)
        battleId = nextBattleId;
        unchecked { nextBattleId = battleId + 1; }

        // Store battle state
        Battle storage b = battles[battleId];
        b.challenger = msg.sender;
        b.challengerToken = token;
        b.challengerStake = stakeAfterFee;
        b.challengerMemeHash = memeHash;
        b.targetToken = targetToken;
        b.duration = uint48(duration);
        b.minVoterBalance = minVoterBal;
        b.createdAt = uint48(block.timestamp);
        b.status = Status.Open;

        // Emit event before external call (CEI)
        emit ChallengeIssued(
            battleId, msg.sender, token, stakeAfterFee,
            targetToken, memeHash, duration, minVoterBal
        );

        // Burn protocol fee (external call — last step)
        _burnProtocolFee(battleId, token, fee);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 2 — ACCEPT & BIDDING
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Accept an open challenge with a counter-meme and stake.
    /// @dev If `startImmediately` is true, skips bidding and goes directly to voting.
    ///      Match validation is done off-chain (no oracle). Contract trusts the caller's choice.
    /// @param battleId The challenge to accept.
    /// @param token ERC-20 token to stake (opponent's community token).
    /// @param amount Amount of tokens to stake (before fee).
    /// @param memeHash IPFS/Arweave hash of the opponent's counter-meme.
    /// @param startImmediately If true, skip bidding and start battle immediately.
    function acceptChallenge(
        uint256 battleId,
        address token,
        uint256 amount,
        bytes32 memeHash,
        bool startImmediately
    ) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Open, "Not open");
        require(uint48(block.timestamp) <= b.createdAt + uint48(_CHALLENGE_EXPIRY), "Challenge expired");
        require(msg.sender != b.challenger, "Cannot accept own");
        require(token != address(0), "Zero token address");
        require(amount != 0, "Stake must be > 0");
        require(memeHash != bytes32(0), "Meme hash required");

        // Targeted challenge check
        if (b.targetToken != address(0)) {
            require(token == b.targetToken, "Must use target token");
        }

        // Deposit + fee
        (uint256 stakeAfterFee, uint256 fee) = _depositWithFee(token, amount);

        // Record opponent state (CEI — state before external calls)
        b.opponent = msg.sender;
        b.opponentToken = token;
        b.opponentStake = stakeAfterFee;
        b.opponentMemeHash = memeHash;

        // Emit event before external call
        emit ChallengeAccepted(battleId, msg.sender, token, stakeAfterFee, memeHash, startImmediately);

        if (startImmediately) {
            _startBattle(battleId);
        } else {
            b.pendingResponse = b.challenger;
            b.lastBiddingAction = uint48(block.timestamp);
            b.status = Status.Bidding;
        }

        // Burn protocol fee (external call — last step)
        _burnProtocolFee(battleId, token, fee);
    }

    /// @notice Raise the stakes during bidding phase.
    /// @dev Only the pending responder can raise. Snapshots pre-raise state for rollback.
    /// @param battleId The active bidding battle.
    /// @param additionalAmount Additional tokens to add (before fee).
    function raise(uint256 battleId, uint256 additionalAmount) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Bidding, "Not in bidding");
        require(b.raiseCount < _MAX_RAISE_ROUNDS, "Max raises reached");
        require(additionalAmount != 0, "Must raise > 0");
        require(msg.sender == b.pendingResponse, "Not your turn");

        address token = msg.sender == b.challenger ? b.challengerToken : b.opponentToken;

        // Deposit + fee
        (uint256 afterFee, uint256 fee) = _depositWithFee(token, additionalAmount);

        // Snapshot pre-raise state for potential rollback (CEI)
        b.challengerStakeBeforeLastRaise = b.challengerStake;
        b.opponentStakeBeforeLastRaise = b.opponentStake;
        b.lastRaiser = msg.sender;
        b.lastRaiseAmount = afterFee;

        // Update stake
        if (msg.sender == b.challenger) {
            b.challengerStake += afterFee;
        } else {
            b.opponentStake += afterFee;
        }

        // Flip turn
        b.pendingResponse = msg.sender == b.challenger ? b.opponent : b.challenger;
        b.lastBiddingAction = uint48(block.timestamp);
        unchecked { b.raiseCount++; }

        // Emit before external call
        emit Raised(battleId, msg.sender, afterFee);

        // Burn protocol fee (external call — last step)
        _burnProtocolFee(battleId, token, fee);
    }

    /// @notice Call the current stake level — match and start the battle.
    /// @param battleId The active bidding battle.
    /// @param additionalAmount Additional tokens to add to match (before fee). Can be 0.
    function call(uint256 battleId, uint256 additionalAmount) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Bidding, "Not in bidding");
        require(msg.sender == b.pendingResponse, "Not your turn");

        uint256 fee;
        uint256 afterFee;

        if (additionalAmount != 0) {
            address token = msg.sender == b.challenger ? b.challengerToken : b.opponentToken;
            (afterFee, fee) = _depositWithFee(token, additionalAmount);

            // Update stake (CEI)
            if (msg.sender == b.challenger) {
                b.challengerStake += afterFee;
            } else {
                b.opponentStake += afterFee;
            }

            emit Called(battleId, msg.sender, afterFee);

            // Start battle (state change)
            _startBattle(battleId);

            // Burn protocol fee (external call — last step)
            _burnProtocolFee(battleId, token, fee);
        } else {
            emit Called(battleId, msg.sender, 0);
            _startBattle(battleId);
        }
    }

    /// @notice Fold — withdraw from the bidding. Stakes refunded via claimRefund().
    /// @dev Fold is permanent and recorded on-chain. 5% protocol fee is NOT refunded.
    /// @param battleId The active bidding battle.
    function fold(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Bidding, "Not in bidding");
        require(msg.sender == b.pendingResponse, "Not your turn");

        // State change first (CEI)
        b.status = Status.Folded;
        uint256 cStake = b.challengerStake;
        uint256 oStake = b.opponentStake;
        b.challengerStake = 0;
        b.opponentStake = 0;

        emit Folded(battleId, msg.sender);

        // Queue refunds (pull pattern)
        if (cStake != 0) {
            _queueRefund(b.challenger, b.challengerToken, cStake);
        }
        if (oStake != 0) {
            _queueRefund(b.opponent, b.opponentToken, oStake);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  EXPIRE / TIMEOUT
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Expire an unanswered challenge and refund the challenger.
    /// @dev Callable by anyone after 72h. Protocol fee is NOT refunded.
    /// @param battleId The open challenge to expire.
    function expireChallenge(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Open, "Not open");
        require(uint48(block.timestamp) > b.createdAt + uint48(_CHALLENGE_EXPIRY), "Not expired yet");

        // State change first (CEI)
        b.status = Status.Expired;
        uint256 cStake = b.challengerStake;
        b.challengerStake = 0;

        emit ChallengeExpired(battleId);

        // Queue refund (pull pattern)
        if (cStake != 0) {
            _queueRefund(b.challenger, b.challengerToken, cStake);
        }
    }

    /// @notice Force-start after bidding timeout. Rolls back the unanswered raise.
    /// @dev Callable by the NON-pending side after _BIDDING_TIMEOUT.
    ///      The last unanswered raise is refunded; battle starts at pre-raise levels.
    /// @param battleId The stalled bidding battle.
    function forceStartAfterTimeout(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Bidding, "Not in bidding");
        require(uint48(block.timestamp) > b.lastBiddingAction + uint48(_BIDDING_TIMEOUT), "Timeout not reached");
        require(msg.sender != b.pendingResponse, "You are pending responder");

        // Roll back unanswered raise (CEI)
        if (b.lastRaiser != address(0) && b.lastRaiseAmount != 0) {
            address raiserToken = b.lastRaiser == b.challenger ? b.challengerToken : b.opponentToken;

            // Restore pre-raise stakes
            b.challengerStake = b.challengerStakeBeforeLastRaise;
            b.opponentStake = b.opponentStakeBeforeLastRaise;

            emit RaiseRolledBack(battleId, b.lastRaiser, b.lastRaiseAmount);

            // Queue refund for the raiser
            _queueRefund(b.lastRaiser, raiserToken, b.lastRaiseAmount);

            b.lastRaiser = address(0);
            b.lastRaiseAmount = 0;
        }

        _startBattle(battleId);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 3+4 — VOTING
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Cast a vote for a team in an active battle.
    /// @dev 1 wallet = 1 vote. Must hold the team's token at time of voting.
    /// @param battleId The active battle.
    /// @param team Team.Challenger (1) or Team.Opponent (2).
    function castVote(uint256 battleId, Team team) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Battling, "Not in battle");
        require(uint48(block.timestamp) < b.battleEndsAt, "Voting ended");
        require(team == Team.Challenger || team == Team.Opponent, "Invalid team");
        require(!hasVoted[battleId][msg.sender], "Already voted");

        // Token holding verification
        address challengerToken = b.challengerToken;
        address opponentToken = b.opponentToken;
        uint256 voterBalance;

        if (challengerToken == opponentToken) {
            // Same-token duel: any holder can vote for either side
            voterBalance = IERC20(challengerToken).balanceOf(msg.sender);
        } else if (team == Team.Challenger) {
            voterBalance = IERC20(challengerToken).balanceOf(msg.sender);
        } else {
            voterBalance = IERC20(opponentToken).balanceOf(msg.sender);
        }

        require(voterBalance != 0, "Must hold team token");

        uint256 minBal = b.minVoterBalance;
        if (minBal != 0) {
            require(voterBalance >= minBal, "Below min voter balance");
        }

        // Record vote (CEI — state change before event)
        hasVoted[battleId][msg.sender] = true;
        if (team == Team.Challenger) {
            unchecked { b.challengerVotes++; }
        } else {
            unchecked { b.opponentVotes++; }
        }

        emit VoteCast(battleId, msg.sender, team, voterBalance);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 5 — SETTLEMENT (Permissionless + Settler Bounty)
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Settle a battle after the voting window closes.
    /// @dev Callable by ANYONE. Determines winner, burns all tokens, mints trophy.
    ///      Settler receives 0.5% of each side's stake as reward.
    /// @param battleId The battle to settle.
    function settleBattle(uint256 battleId) external nonReentrant {
        _settleBattle(battleId, msg.sender);
    }

    /// @notice Settle a battle after the 48-hour grace period.
    /// @dev Identical to settleBattle() but requires an additional 48h wait.
    ///      Designed for keeper bots that settle in batches after grace.
    /// @param battleId The battle to settle.
    function settleAfterGrace(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Battling, "Not in battle");
        require(block.timestamp >= uint256(b.battleEndsAt) + _SETTLEMENT_GRACE, "Grace period not over");
        _settleBattle(battleId, msg.sender);
    }

    /// @dev Internal settlement logic shared by settleBattle() and settleAfterGrace().
    ///      Determines winner, burns stakes, pays settler bounty, mints trophy.
    /// @param battleId The battle to settle.
    /// @param settler Address that triggered settlement (receives 0.5% bounty).
    function _settleBattle(uint256 battleId, address settler) internal {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        require(b.status == Status.Battling, "Not in battle");
        require(uint48(block.timestamp) >= b.battleEndsAt, "Voting still active");

        // Determine winner (CEI — all state changes first)
        uint256 cVotes = b.challengerVotes;
        uint256 oVotes = b.opponentVotes;

        if (cVotes >= oVotes) {
            // Challenger wins (tie = challenger advantage — first-mover took the risk)
            b.winner = Team.Challenger;
        } else {
            b.winner = Team.Opponent;
        }

        b.status = Status.Settled;
        unchecked { totalBattlesSettled++; }

        // Cache storage values
        uint256 cStake = b.challengerStake;
        uint256 oStake = b.opponentStake;
        address cToken = b.challengerToken;
        address oToken = b.opponentToken;

        // Calculate settler rewards (0.5% of each side)
        uint256 cReward = (cStake * _SETTLER_REWARD_BPS) / _BPS;
        uint256 oReward = (oStake * _SETTLER_REWARD_BPS) / _BPS;
        uint256 cBurn = cStake - cReward;
        uint256 oBurn = oStake - oReward;

        // Zero stakes (CEI)
        b.challengerStake = 0;
        b.opponentStake = 0;

        // Emit event before external calls
        emit BattleSettled(
            battleId, b.winner, cVotes, oVotes,
            cBurn, oBurn, settler, cReward, oReward
        );

        // External calls — transfers (all state already finalized)
        if (cBurn != 0) {
            IERC20(cToken).safeTransfer(_DEAD, cBurn);
        }
        if (oBurn != 0) {
            IERC20(oToken).safeTransfer(_DEAD, oBurn);
        }

        // Settler rewards
        if (cReward != 0) {
            IERC20(cToken).safeTransfer(settler, cReward);
        }
        if (oReward != 0) {
            IERC20(oToken).safeTransfer(settler, oReward);
        }

        if (!_isTournamentBattle[battleId]) {
            _mintTrophy(battleId, b, cBurn, oBurn);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  CLAIM REFUNDS (Pull Pattern)
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Claim pending refunds for a specific token.
    /// @dev Pull-over-push: user must explicitly claim. Defense-in-depth against reentrancy.
    /// @param token The ERC-20 token to claim.
    function claimRefund(address token) external nonReentrant {
        require(token != address(0), "Zero token address");
        uint256 amount = pendingRefunds[msg.sender][token];
        require(amount != 0, "Nothing to claim");

        // Zero before transfer (CEI)
        pendingRefunds[msg.sender][token] = 0;

        emit RefundClaimed(msg.sender, token, amount);

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — BATTLE START
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Transition battle to Battling status and start the voting window.
    /// @param battleId The battle to start.
    function _startBattle(uint256 battleId) internal {
        Battle storage b = battles[battleId];
        b.status = Status.Battling;
        b.snapshotBlock = block.number;
        b.battleStartsAt = uint48(block.timestamp);
        b.battleEndsAt = uint48(block.timestamp) + b.duration;

        emit BattleStarted(battleId, block.number, uint256(b.battleEndsAt));
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — PROTOCOL FEE (Swap to GROK + Burn)
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Swaps the protocol fee to GROK via Uniswap V2 and burns it to 0xdEaD.
    ///      If the token IS GROK, burns directly (no swap needed).
    ///      If swap fails (no liquidity), burns the fee token directly as fallback.
    /// @param battleId The battle this fee belongs to.
    /// @param token The fee token to swap.
    /// @param feeAmount Amount of fee tokens to burn.
    function _burnProtocolFee(uint256 battleId, address token, uint256 feeAmount) internal {
        uint256 grokBurned = _swapFeeToGrokAndBurn(token, feeAmount);
        if (grokBurned != 0) {
            totalGrokBurned += grokBurned;
            battleGrokFees[battleId] += grokBurned;
        }
        emit ProtocolFeeBurned(battleId, token, feeAmount, grokBurned);
    }

    /// @dev Swap tournament protocol fee to GROK and burn. Tracks in tournamentGrokFees.
    /// @param tournamentId The tournament this fee belongs to.
    /// @param token The fee token to swap.
    /// @param feeAmount Amount of fee tokens to burn.
    function _burnTournamentProtocolFee(uint256 tournamentId, address token, uint256 feeAmount) internal {
        uint256 grokBurned = _swapFeeToGrokAndBurn(token, feeAmount);
        if (grokBurned != 0) {
            totalGrokBurned += grokBurned;
            tournamentGrokFees[tournamentId] += grokBurned;
        }
        emit TournamentProtocolFeeBurned(tournamentId, token, feeAmount, grokBurned);
    }

    /// @dev Swap fee tokens to GROK via Uniswap V2 and burn to 0xdEaD.
    ///      If the token IS GROK, burns directly (no swap).
    ///      If swap fails (no liquidity), burns the fee token directly as fallback.
    /// @param token The fee token to swap.
    /// @param feeAmount Amount of fee tokens to burn.
    /// @return grokBurned Amount of GROK actually burned (0 if fallback triggered).
    function _swapFeeToGrokAndBurn(address token, uint256 feeAmount) internal returns (uint256 grokBurned) {
        if (feeAmount == 0) return 0;
        require(token != address(0), "Zero token address");

        if (token == grokToken) {
            IERC20(grokToken).safeTransfer(_DEAD, feeAmount);
            return feeAmount;
        }

        IERC20(token).safeIncreaseAllowance(address(uniswapRouter), feeAmount);

        address cachedWeth = weth;
        address[] memory path;
        if (token == cachedWeth) {
            path = new address[](2);
            path[0] = cachedWeth;
            path[1] = grokToken;
        } else {
            path = new address[](3);
            path[0] = token;
            path[1] = cachedWeth;
            path[2] = grokToken;
        }

        uint256 amountOutMin = _getQuotedAmountOut(path, feeAmount);
        if (amountOutMin == 0) {
            IERC20(token).safeDecreaseAllowance(address(uniswapRouter), feeAmount);
            IERC20(token).safeTransfer(_DEAD, feeAmount);
            return 0;
        }

        try uniswapRouter.swapExactTokensForTokens(
            feeAmount,
            amountOutMin,
            path,
            _DEAD,
            block.timestamp + _SWAP_DEADLINE_GRACE
        ) returns (uint256[] memory amounts) {
            grokBurned = amounts[amounts.length - 1];
        } catch Error(string memory) {
            IERC20(token).safeDecreaseAllowance(address(uniswapRouter), feeAmount);
            IERC20(token).safeTransfer(_DEAD, feeAmount);
        } catch {
            IERC20(token).safeDecreaseAllowance(address(uniswapRouter), feeAmount);
            IERC20(token).safeTransfer(_DEAD, feeAmount);
        }
    }

    /// @dev Swap tokenIn to tokenOut via Uniswap V2 and burn to 0xdEaD.
    ///      If the swap fails (no liquidity / no pair), burns tokenIn directly as fallback.
    ///      This ensures settleTournament() can never be permanently bricked by an
    ///      illiquid token. The fallback emits SwapFallbackBurn so the frontend can
    ///      display this publicly on tournament results.
    /// @param tokenIn The token to swap from.
    /// @param amountIn Amount of tokenIn to burn.
    /// @param tokenOut Intended target token (winner's currency).
    /// @param contextId Tournament ID (for SwapFallbackBurn event). 0 for non-tournament.
    /// @return amountBurned Amount of tokenOut actually burned (0 if fallback triggered).
    function _swapAndBurn(address tokenIn, uint256 amountIn, address tokenOut, uint256 contextId) internal returns (uint256 amountBurned) {
        if (amountIn == 0) return 0;
        require(tokenIn != address(0), "Zero input token");
        require(tokenOut != address(0), "Zero output token");

        if (tokenIn == tokenOut) {
            IERC20(tokenOut).safeTransfer(_DEAD, amountIn);
            return amountIn;
        }

        IERC20(tokenIn).safeIncreaseAllowance(address(uniswapRouter), amountIn);

        address cachedWeth = weth;
        address[] memory path;
        if (tokenIn == cachedWeth || tokenOut == cachedWeth) {
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
        } else {
            path = new address[](3);
            path[0] = tokenIn;
            path[1] = cachedWeth;
            path[2] = tokenOut;
        }

        uint256 amountOutMin = _getQuotedAmountOut(path, amountIn);
        if (amountOutMin == 0) {
            IERC20(tokenIn).safeDecreaseAllowance(address(uniswapRouter), amountIn);
            IERC20(tokenIn).safeTransfer(_DEAD, amountIn);
            emit SwapFallbackBurn(contextId, tokenIn, amountIn, tokenOut);
            return 0;
        }

        try uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            _DEAD,
            block.timestamp + _SWAP_DEADLINE_GRACE
        ) returns (uint256[] memory amounts) {
            amountBurned = amounts[amounts.length - 1];
        } catch {
            // Swap failed — burn the original token directly.
            // Tokens are still destroyed, just not converted to winner's currency.
            IERC20(tokenIn).safeDecreaseAllowance(address(uniswapRouter), amountIn);
            IERC20(tokenIn).safeTransfer(_DEAD, amountIn);
            emit SwapFallbackBurn(contextId, tokenIn, amountIn, tokenOut);
        }
    }

    /// @dev Quote the exact-output amount for a Uniswap V2 path.
    ///      Returns 0 if the router cannot provide a quote.
    /// @param path Swap path used for the quote.
    /// @param amountIn Exact token input amount.
    /// @return amountOut Quoted amount for the last token in the path.
    function _getQuotedAmountOut(address[] memory path, uint256 amountIn) internal view returns (uint256 amountOut) {
        try uniswapRouter.getAmountsOut(amountIn, path) returns (uint256[] memory amounts) {
            if (amounts.length != 0) {
                amountOut = amounts[amounts.length - 1];
            }
        } catch Error(string memory) {
            return 0;
        } catch {
            return 0;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — DEPOSIT WITH FEE (Fee-on-Transfer Safe)
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Transfer tokens from msg.sender and calculate actual received amount.
    ///      Uses balance-before/after pattern to support fee-on-transfer tokens.
    ///      Protocol fee is 5% (500 bps) of the actually received amount.
    /// @param token ERC-20 token to transfer.
    /// @param amount Nominal amount to transfer (actual may be less for FoT tokens).
    /// @return stakeAfterFee Net amount locked as stake.
    /// @return feeAmount Amount reserved for protocol fee burn.
    function _depositWithFee(address token, uint256 amount) internal returns (uint256 stakeAfterFee, uint256 feeAmount) {
        address self = address(this);
        uint256 balBefore = IERC20(token).balanceOf(self);
        IERC20(token).safeTransferFrom(msg.sender, self, amount);
        uint256 received = IERC20(token).balanceOf(self) - balBefore;

        // Fee calculation. Precision note: for very small amounts, fee may round to 0.
        // This is acceptable — micro-stakes simply have no protocol fee.
        feeAmount = (received * _PROTOCOL_FEE_BPS) / _BPS;
        stakeAfterFee = received - feeAmount;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — REFUND QUEUE
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Queue a refund for later claiming (pull pattern).
    /// @param to Recipient address.
    /// @param token ERC-20 token address.
    /// @param amount Amount to queue.
    function _queueRefund(address to, address token, uint256 amount) internal {
        require(to != address(0), "Zero recipient");
        require(token != address(0), "Zero token address");
        pendingRefunds[to][token] += amount;
        emit RefundQueued(to, token, amount);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — TROPHY MINT
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Mint a Battle Trophy NFT to the winning meme creator.
    ///      Uses try/catch — mint failure does NOT block settlement.
    ///      Emits TrophyMintFailed on error for off-chain tracking.
    /// @param battleId The settled battle.
    /// @param b The battle storage reference.
    /// @param challengerBurned Amount of challenger tokens burned.
    /// @param opponentBurned Amount of opponent tokens burned.
    function _mintTrophy(
        uint256 battleId,
        Battle storage b,
        uint256 challengerBurned,
        uint256 opponentBurned
    ) internal {
        address winnerAddr;
        address winnerToken;
        bytes32 winnerMemeHash;
        address loserAddr;
        address loserToken;
        uint256 winnerVotes;
        uint256 loserVotes;
        uint256 winnerBurned;
        uint256 loserBurned;

        if (b.winner == Team.Challenger) {
            winnerAddr = b.challenger;
            winnerToken = b.challengerToken;
            winnerMemeHash = b.challengerMemeHash;
            loserAddr = b.opponent;
            loserToken = b.opponentToken;
            winnerVotes = b.challengerVotes;
            loserVotes = b.opponentVotes;
            winnerBurned = challengerBurned;
            loserBurned = opponentBurned;
        } else {
            winnerAddr = b.opponent;
            winnerToken = b.opponentToken;
            winnerMemeHash = b.opponentMemeHash;
            loserAddr = b.challenger;
            loserToken = b.challengerToken;
            winnerVotes = b.opponentVotes;
            loserVotes = b.challengerVotes;
            winnerBurned = opponentBurned;
            loserBurned = challengerBurned;
        }

        try trophyContract.mintTrophy(
            battleId,
            winnerAddr,
            winnerToken,
            winnerMemeHash,
            loserAddr,
            loserToken,
            winnerVotes,
            loserVotes,
            winnerBurned,
            loserBurned,
            battleGrokFees[battleId],
            b.snapshotBlock,
            uint256(b.battleEndsAt),
            ""
        ) returns (uint256 tokenId) {
            emit TrophyMintSucceeded(battleId, tokenId);
        } catch Error(string memory reason) {
            emit TrophyMintFailed(battleId, reason);
        } catch (bytes memory) {
            emit TrophyMintFailed(battleId, "Unknown trophy mint error");
        }
    }

    /// @dev Mint a Tournament Trophy NFT to the winning participant.
    ///      Uses try/catch — mint failure does NOT block settlement.
    ///      Emits TournamentTrophyMintFailed on error for off-chain tracking.
    /// @param tournamentId The settled tournament.
    /// @param t The tournament storage reference.
    /// @param winnerEntry The winning participant's entry.
    /// @param winnerTokensBurned Total winner-token amount burned in finale.
    /// @param finaleBattleId The battle ID of the finale match.
    function _mintTournamentTrophy(
        uint256 tournamentId,
        Tournament storage t,
        TournamentEntry storage winnerEntry,
        uint256 winnerTokensBurned,
        uint256 finaleBattleId
    ) internal {
        string memory title = tournamentTitles[tournamentId];

        try trophyContract.mintTournamentTrophy(
            tournamentId,
            title,
            t.size,
            winnerEntry.participant,
            winnerEntry.token,
            winnerEntry.memeHash,
            winnerTokensBurned,
            tournamentGrokFees[tournamentId],
            finaleBattleId,
            ""
        ) returns (uint256 tokenId) {
            emit TournamentTrophyMintSucceeded(tournamentId, tokenId);
        } catch Error(string memory reason) {
            emit TournamentTrophyMintFailed(tournamentId, reason);
        } catch (bytes memory) {
            emit TournamentTrophyMintFailed(tournamentId, "Unknown tournament trophy mint error");
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  TOURNAMENT — STRUCTS & STATE
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Tournament lifecycle status.
    enum TournamentStatus {
        Open,        // Accepting participants
        InProgress,  // Bracket rounds active
        Settled,     // Finale completed, tokens burned
        Expired      // Deadline passed without filling
    }

    /// @notice Tournament configuration and state.
    struct Tournament {
        address creator;                 // Who created it (permissionless, no special rights)
        uint8   size;                    // 4, 8, or 16 participants
        uint8   currentRound;            // 0 = joining, 1+ = active round
        uint8   joinedCount;             // How many have joined
        TournamentStatus status;
        uint48  voteDuration;            // Voting duration per round
        uint48  deadline;                // 0 = no deadline (open forever)
        uint48  createdAt;
        uint256 entryUsdReference;       // USD reference (display only, not enforced)
        uint256 totalPot;                // Sum of all entry stakes (after per-deposit fee)
        address winner;                  // Set after finale
        address winnerToken;             // Winner's community token
    }

    /// @notice Per-participant tournament entry.
    struct TournamentEntry {
        address participant;
        address token;
        uint256 stake;                   // After 5% fee
        bytes32 memeHash;
        bool    eliminated;              // True after losing a round
        uint256 accumulatedPot;          // Grows as they win rounds
    }

    /// @notice Per-round bracket match.
    struct TournamentMatch {
        uint256 battleId;                // Links to regular Arena battle
        uint8   participant1Index;
        uint8   participant2Index;
        uint8   winnerIndex;             // 0 = not decided yet
        bool    settled;
    }

    /// @notice Auto-incrementing tournament ID counter.
    uint256 public nextTournamentId;

    /// @notice Tournament data by ID.
    mapping(uint256 tournamentId => Tournament) public tournaments;

    /// @notice Tournament entries by tournament ID and index (0-based).
    mapping(uint256 tournamentId => mapping(uint8 index => TournamentEntry)) public tournamentEntries;

    /// @notice Tournament matches: tournamentId => round (1-based) => matchIndex (0-based).
    mapping(uint256 tournamentId => mapping(uint8 round => mapping(uint8 matchIdx => TournamentMatch))) public tournamentMatches;

    /// @notice Number of matches per round.
    mapping(uint256 tournamentId => mapping(uint8 round => uint8 matchCount)) public tournamentRoundMatchCount;

    /// @notice Track which addresses already joined a tournament.
    mapping(uint256 tournamentId => mapping(address => bool)) public hasJoinedTournament;
    /// @notice Human-readable title by tournament ID.
    mapping(uint256 tournamentId => string tournamentTitle) private tournamentTitles;

    // ═══════════════════════════════════════════════════════════════════
    //  TOURNAMENT — EVENTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Emitted when a new tournament is created.
    event TournamentCreated(
        uint256 indexed tournamentId,
        address indexed creator,
        uint8   size,
        uint256 entryUsdReference,
        uint256 voteDuration,
        uint256 deadline
    );

    /// @notice Emitted when a participant joins a tournament.
    event TournamentJoined(
        uint256 indexed tournamentId,
        address indexed participant,
        address token,
        uint256 stakeAfterFee,
        bytes32 memeHash,
        uint8   slotIndex
    );

    /// @notice Emitted when a tournament round starts.
    event TournamentRoundStarted(
        uint256 indexed tournamentId,
        uint8   round,
        uint8   matchCount
    );

    /// @notice Emitted when a tournament match winner is advanced.
    event TournamentWinnerAdvanced(
        uint256 indexed tournamentId,
        uint8   round,
        uint8   matchIndex,
        uint8   winnerParticipantIndex
    );

    /// @notice Emitted when a tournament is settled (finale burn).
    event TournamentSettled(
        uint256 indexed tournamentId,
        address indexed winner,
        address winnerToken,
        uint256 totalPotBurned,
        uint256 grokFeeBurned
    );

    /// @notice Emitted when a tournament expires (deadline passed, not full).
    event TournamentExpired(uint256 indexed tournamentId);

    // ═══════════════════════════════════════════════════════════════════
    //  TOURNAMENT — CREATE & JOIN
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Create a new tournament. Permissionless — anyone can create.
    /// @dev No special rights for the creator. All logic is deterministic.
    /// @param size Number of participants (4, 8, or 16).
    /// @param entryUsdReference USD reference price for UI display (not enforced on-chain).
    /// @param voteDuration Voting duration per round in seconds.
    /// @param deadline Unix timestamp deadline for filling slots. 0 = no deadline.
    /// @param title Human-readable tournament title.
    /// @return tournamentId The newly created tournament ID.
    function createTournament(
        uint8 size,
        uint256 entryUsdReference,
        uint256 voteDuration,
        uint256 deadline,
        string calldata title
    ) external returns (uint256 tournamentId) {
        require(size == 4 || size == 8 || size == 16, "Size must be 4, 8, or 16");
        require(voteDuration >= 5 minutes && voteDuration <= 35 days, "Duration: 5min-35d");
        require(deadline == 0 || deadline > block.timestamp, "Deadline must be future");
        require(bytes(title).length != 0, "Title required");
        require(bytes(title).length <= _MAX_TOURNAMENT_TITLE_LENGTH, "Title too long");

        tournamentId = nextTournamentId;
        unchecked { nextTournamentId = tournamentId + 1; }

        Tournament storage t = tournaments[tournamentId];
        t.creator = msg.sender;
        t.size = size;
        t.voteDuration = uint48(voteDuration);
        t.deadline = uint48(deadline);
        t.createdAt = uint48(block.timestamp);
        t.entryUsdReference = entryUsdReference;
        t.status = TournamentStatus.Open;
        tournamentTitles[tournamentId] = title;

        emit TournamentCreated(tournamentId, msg.sender, size, entryUsdReference, voteDuration, deadline);
    }

    /// @notice Join an open tournament with your token and meme.
    /// @dev 5% GROK protocol fee is burned immediately on deposit.
    ///      When all slots are filled, Round 1 starts automatically.
    /// @param tournamentId The tournament to join.
    /// @param token ERC-20 token to stake (your community token).
    /// @param amount Amount of tokens to stake (before 5% fee).
    /// @param memeHash IPFS/Arweave hash of your battle meme.
    function joinTournament(
        uint256 tournamentId,
        address token,
        uint256 amount,
        bytes32 memeHash
    ) external nonReentrant {
        Tournament storage t = tournaments[tournamentId];
        require(t.creator != address(0), "Tournament does not exist");
        require(t.status == TournamentStatus.Open, "Not open");
        require(t.joinedCount < t.size, "Tournament full");
        require(!hasJoinedTournament[tournamentId][msg.sender], "Already joined");
        require(token != address(0), "Zero token address");
        require(amount != 0, "Stake must be > 0");
        require(memeHash != bytes32(0), "Meme hash required");

        // Check deadline
        if (t.deadline != 0) {
            require(uint48(block.timestamp) <= t.deadline, "Deadline passed");
        }

        // Deposit + fee
        (uint256 stakeAfterFee, uint256 fee) = _depositWithFee(token, amount);

        // Record entry (CEI)
        uint8 slotIndex = t.joinedCount;
        t.joinedCount = slotIndex + 1;
        t.totalPot += stakeAfterFee;
        hasJoinedTournament[tournamentId][msg.sender] = true;

        TournamentEntry storage entry = tournamentEntries[tournamentId][slotIndex];
        entry.participant = msg.sender;
        entry.token = token;
        entry.stake = stakeAfterFee;
        entry.memeHash = memeHash;
        entry.accumulatedPot = stakeAfterFee;

        emit TournamentJoined(tournamentId, msg.sender, token, stakeAfterFee, memeHash, slotIndex);

        _burnTournamentProtocolFee(tournamentId, token, fee);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  TOURNAMENT — ROUND MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Start the next tournament round. Permissionless.
    /// @dev For Round 1, anyone can call once all slots are filled (status == Open).
    ///      For subsequent rounds, anyone can call after all matches in the previous round are settled.
    /// @param tournamentId The tournament.
    function startTournamentRound(uint256 tournamentId) external {
        Tournament storage t = tournaments[tournamentId];
        require(t.creator != address(0), "Tournament does not exist");
        require(
            t.status == TournamentStatus.InProgress ||
            (t.status == TournamentStatus.Open && t.joinedCount == t.size),
            "Not ready"
        );
        require(t.currentRound < _getMaxRounds(t.size), "Final round reached");

        // Verify all previous round matches are settled (no-op for Round 1 since currentRound == 0)
        uint8 prevRound = t.currentRound;
        uint8 prevMatchCount = tournamentRoundMatchCount[tournamentId][prevRound];
        for (uint8 i; i < prevMatchCount;) {
            require(tournamentMatches[tournamentId][prevRound][i].settled, "Prev round not done");
            unchecked { i++; }
        }

        _startTournamentRound(tournamentId);
    }

    /// @notice Advance the winner of a tournament match after its battle settles.
    /// @dev Reads the battle result, records winner, assigns loser's pot. Permissionless.
    /// @param tournamentId The tournament.
    /// @param round The round (1-based).
    /// @param matchIndex The match index within the round (0-based).
    function advanceTournamentWinner(
        uint256 tournamentId,
        uint8 round,
        uint8 matchIndex
    ) external {
        Tournament storage t = tournaments[tournamentId];
        require(t.creator != address(0), "Tournament does not exist");
        require(t.status == TournamentStatus.InProgress, "Not in progress");
        require(round != 0 && round <= t.currentRound, "Invalid round");
        require(matchIndex < tournamentRoundMatchCount[tournamentId][round], "Invalid match");

        TournamentMatch storage m = tournamentMatches[tournamentId][round][matchIndex];
        require(!m.settled, "Already advanced");

        // Read battle result
        Battle storage b = battles[m.battleId];
        require(b.status == Status.Settled, "Battle not settled");

        // Determine which participant won
        uint8 winnerIdx;
        uint8 loserIdx;
        if (b.winner == Team.Challenger) {
            winnerIdx = m.participant1Index;
            loserIdx = m.participant2Index;
        } else {
            winnerIdx = m.participant2Index;
            loserIdx = m.participant1Index;
        }

        // Record winner (CEI)
        m.winnerIndex = winnerIdx;
        m.settled = true;

        // Eliminate loser and transfer accumulated pot to winner
        TournamentEntry storage winnerEntry = tournamentEntries[tournamentId][winnerIdx];
        TournamentEntry storage loserEntry = tournamentEntries[tournamentId][loserIdx];

        winnerEntry.accumulatedPot += loserEntry.accumulatedPot;
        loserEntry.accumulatedPot = 0;
        loserEntry.eliminated = true;

        emit TournamentWinnerAdvanced(tournamentId, round, matchIndex, winnerIdx);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  TOURNAMENT — SETTLEMENT (Finale Mega-Burn)
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Settle a completed tournament. Permissionless.
    /// @dev Called after the finale battle is settled and winner is advanced.
    ///      Burns 5% of total pot as GROK, swaps remaining 95% to winner's token and burns it.
    /// @param tournamentId The tournament to settle.
    function settleTournament(uint256 tournamentId) external nonReentrant {
        Tournament storage t = tournaments[tournamentId];
        require(t.creator != address(0), "Tournament does not exist");
        require(t.status == TournamentStatus.InProgress, "Not in progress");

        // Verify we're at the final round and it's settled
        uint8 finalRound = _getMaxRounds(t.size);
        require(t.currentRound == finalRound, "Not at final round");

        TournamentMatch storage finaleMatch = tournamentMatches[tournamentId][finalRound][0];
        require(finaleMatch.settled, "Finale not settled");

        // Identify winner
        uint8 winnerIdx = finaleMatch.winnerIndex;
        TournamentEntry storage winnerEntry = tournamentEntries[tournamentId][winnerIdx];

        // State changes first (CEI)
        t.status = TournamentStatus.Settled;
        t.winner = winnerEntry.participant;
        t.winnerToken = winnerEntry.token;

        uint256 totalWinnerTokenBurned;

        for (uint8 i; i < t.size;) {
            TournamentEntry storage entry = tournamentEntries[tournamentId][i];
            uint256 entryStake = entry.stake;

            if (entryStake != 0) {
                uint256 entryGrokFee = (entryStake * _PROTOCOL_FEE_BPS) / _BPS;
                uint256 entryBurn = entryStake - entryGrokFee;

                entry.stake = 0;

                if (entryGrokFee != 0) {
                    _burnTournamentProtocolFee(tournamentId, entry.token, entryGrokFee);
                }

                if (entryBurn != 0) {
                    totalWinnerTokenBurned += _swapAndBurn(entry.token, entryBurn, winnerEntry.token, tournamentId);
                }
            }

            unchecked { i++; }
        }

        emit TournamentSettled(
            tournamentId,
            winnerEntry.participant,
            winnerEntry.token,
            totalWinnerTokenBurned,
            tournamentGrokFees[tournamentId]
        );

        _mintTournamentTrophy(
            tournamentId,
            t,
            winnerEntry,
            totalWinnerTokenBurned,
            finaleMatch.battleId
        );
    }

    // ═══════════════════════════════════════════════════════════════════
    //  TOURNAMENT — EXPIRE
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Expire a tournament that didn't fill before deadline. Refunds all joiners.
    /// @dev Callable by anyone after deadline. Refunds go to claimRefund() (pull pattern).
    ///      5% protocol fee (already burned on deposit) is NOT refunded.
    /// @param tournamentId The tournament to expire.
    function expireTournament(uint256 tournamentId) external nonReentrant {
        Tournament storage t = tournaments[tournamentId];
        require(t.creator != address(0), "Tournament does not exist");
        require(t.status == TournamentStatus.Open, "Not open");
        require(t.deadline != 0, "No deadline set");
        require(uint48(block.timestamp) > t.deadline, "Deadline not passed");
        require(t.joinedCount < t.size, "Tournament full, needs start");

        // State change first (CEI)
        t.status = TournamentStatus.Expired;

        emit TournamentExpired(tournamentId);

        // Queue refunds for all joiners
        for (uint8 i; i < t.joinedCount;) {
            TournamentEntry storage entry = tournamentEntries[tournamentId][i];
            uint256 refundAmount = entry.stake;
            if (refundAmount != 0) {
                entry.stake = 0;
                _queueRefund(entry.participant, entry.token, refundAmount);
            }
            unchecked { i++; }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  TOURNAMENT — INTERNAL
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Start the next round of a tournament by creating bracket battles.
    /// @param tournamentId The tournament.
    function _startTournamentRound(uint256 tournamentId) internal {
        Tournament storage t = tournaments[tournamentId];

        uint8 nextRound;
        unchecked { nextRound = t.currentRound + 1; }
        t.currentRound = nextRound;

        if (t.status == TournamentStatus.Open) {
            t.status = TournamentStatus.InProgress;
        }

        // Collect active (non-eliminated) participants in seed order
        uint8[] memory active = new uint8[](t.size);
        uint8 activeCount;
        for (uint8 i; i < t.size;) {
            if (!tournamentEntries[tournamentId][i].eliminated) {
                active[activeCount] = i;
                unchecked { activeCount++; }
            }
            unchecked { i++; }
        }

        require(activeCount >= 2, "Not enough active participants");

        // Create bracket matches: 1v8, 2v7, 3v6, 4v5 (mirrored seeding)
        uint8 matchCount;
        unchecked { matchCount = activeCount / 2; }
        tournamentRoundMatchCount[tournamentId][nextRound] = matchCount;

        for (uint8 m; m < matchCount;) {
            uint8 p1Idx = active[m];
            uint8 p2Idx = active[activeCount - 1 - m];

            TournamentEntry storage p1 = tournamentEntries[tournamentId][p1Idx];
            TournamentEntry storage p2 = tournamentEntries[tournamentId][p2Idx];

            // Create a tournament battle (uses the arena's own battle system)
            uint256 battleId = nextBattleId;
            unchecked { nextBattleId = battleId + 1; }

            Battle storage b = battles[battleId];
            b.challenger = p1.participant;
            b.challengerToken = p1.token;
            b.challengerStake = 0;  // Tokens already in tournament pot, not double-locked
            b.challengerMemeHash = p1.memeHash;
            b.opponent = p2.participant;
            b.opponentToken = p2.token;
            b.opponentStake = 0;    // Tokens already in tournament pot
            b.opponentMemeHash = p2.memeHash;
            b.duration = t.voteDuration;
            b.createdAt = uint48(block.timestamp);

            // Skip Open + Bidding — go directly to Battling
            b.status = Status.Battling;
            b.snapshotBlock = block.number;
            b.battleStartsAt = uint48(block.timestamp);
            b.battleEndsAt = uint48(block.timestamp) + t.voteDuration;
            _isTournamentBattle[battleId] = true;

            // Record the match
            TournamentMatch storage tm = tournamentMatches[tournamentId][nextRound][m];
            tm.battleId = battleId;
            tm.participant1Index = p1Idx;
            tm.participant2Index = p2Idx;

            emit BattleStarted(battleId, block.number, uint256(b.battleEndsAt));

            unchecked { m++; }
        }

        emit TournamentRoundStarted(tournamentId, nextRound, matchCount);
    }

    /// @dev Get the number of rounds for a tournament size.
    /// @param size Tournament size (4, 8, or 16).
    /// @return rounds Number of rounds (2, 3, or 4).
    function _getMaxRounds(uint8 size) internal pure returns (uint8 rounds) {
        if (size == 4) return 2;
        if (size == 8) return 3;
        return 4; // size == 16
    }

    // ═══════════════════════════════════════════════════════════════════
    //  VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Get full battle data.
    /// @param battleId The battle to query.
    /// @return challenger Challenger's wallet address.
    /// @return challengerToken Challenger's ERC-20 token.
    /// @return challengerStake Challenger's current stake (0 after settlement).
    /// @return opponent Opponent's wallet address.
    /// @return opponentToken Opponent's ERC-20 token.
    /// @return opponentStake Opponent's current stake (0 after settlement).
    /// @return status Current battle status.
    /// @return winner Winning side (None before settlement).
    /// @return challengerVotes Total votes for challenger.
    /// @return opponentVotes Total votes for opponent.
    function getBattle(uint256 battleId) external view returns (
        address challenger,
        address challengerToken,
        uint256 challengerStake,
        address opponent,
        address opponentToken,
        uint256 opponentStake,
        Status  status,
        Team    winner,
        uint256 challengerVotes,
        uint256 opponentVotes
    ) {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        return (
            b.challenger, b.challengerToken, b.challengerStake,
            b.opponent, b.opponentToken, b.opponentStake,
            b.status, b.winner,
            b.challengerVotes, b.opponentVotes
        );
    }

    /// @notice Get battle timing info.
    /// @param battleId The battle to query.
    /// @return createdAt Timestamp when challenge was created.
    /// @return battleStartsAt Timestamp when voting started.
    /// @return battleEndsAt Timestamp when voting ends.
    /// @return snapshotBlock Block number when voting snapshot was taken.
    /// @return duration Voting duration in seconds.
    /// @return pendingResponse Who must act next in bidding.
    /// @return raiseCount Number of raises so far.
    function getBattleTiming(uint256 battleId) external view returns (
        uint256 createdAt,
        uint256 battleStartsAt,
        uint256 battleEndsAt,
        uint256 snapshotBlock,
        uint256 duration,
        address pendingResponse,
        uint8   raiseCount
    ) {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        return (
            uint256(b.createdAt), uint256(b.battleStartsAt), uint256(b.battleEndsAt),
            b.snapshotBlock, uint256(b.duration), b.pendingResponse, b.raiseCount
        );
    }

    /// @notice Check if a wallet has voted in a battle.
    /// @param battleId The battle to check.
    /// @param wallet The wallet address to check.
    /// @return voted True if the wallet has voted.
    function hasWalletVoted(uint256 battleId, address wallet) external view returns (bool voted) {
        require(battles[battleId].challenger != address(0), "Battle does not exist");
        return hasVoted[battleId][wallet];
    }

    /// @notice Check if a challenge can still be accepted.
    /// @param battleId The challenge to check.
    /// @return acceptable True if the challenge is open and not expired.
    function isChallengeAcceptable(uint256 battleId) external view returns (bool acceptable) {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        return b.status == Status.Open && uint48(block.timestamp) <= b.createdAt + uint48(_CHALLENGE_EXPIRY);
    }

    /// @notice Check if a battle can be settled.
    /// @param battleId The battle to check.
    /// @return settleable True if voting has ended and battle is not yet settled.
    function isSettleable(uint256 battleId) external view returns (bool settleable) {
        Battle storage b = battles[battleId];
        require(b.challenger != address(0), "Battle does not exist");
        return b.status == Status.Battling && uint48(block.timestamp) >= b.battleEndsAt;
    }

    /// @notice Get tournament overview.
    /// @param tournamentId The tournament to query.
    /// @return creator Who created the tournament.
    /// @return size Number of participant slots.
    /// @return joinedCount How many have joined.
    /// @return currentRound Current round (0 = joining phase).
    /// @return status Tournament lifecycle status.
    /// @return totalPot Sum of all entry stakes.
    /// @return winnerAddr Winner address (zero if not settled).
    /// @return winnerTkn Winner's token (zero if not settled).
    function getTournament(uint256 tournamentId) external view returns (
        address creator,
        uint8   size,
        uint8   joinedCount,
        uint8   currentRound,
        TournamentStatus status,
        uint256 totalPot,
        address winnerAddr,
        address winnerTkn
    ) {
        Tournament storage t = tournaments[tournamentId];
        require(t.creator != address(0), "Tournament does not exist");
        return (
            t.creator, t.size, t.joinedCount, t.currentRound,
            t.status, t.totalPot, t.winner, t.winnerToken
        );
    }

    /// @notice Get a tournament participant's entry.
    /// @param tournamentId The tournament.
    /// @param index Participant index (0-based, join order).
    /// @return participant Wallet address.
    /// @return token ERC-20 token used.
    /// @return stake Stake amount (after fee). 0 after settlement.
    /// @return memeHash Content hash of the meme.
    /// @return eliminated Whether the participant has been eliminated.
    /// @return accumulatedPot Accumulated pot (grows as they win rounds).
    function getTournamentEntry(uint256 tournamentId, uint8 index) external view returns (
        address participant,
        address token,
        uint256 stake,
        bytes32 memeHash,
        bool    eliminated,
        uint256 accumulatedPot
    ) {
        require(tournaments[tournamentId].creator != address(0), "Tournament does not exist");
        TournamentEntry storage e = tournamentEntries[tournamentId][index];
        return (e.participant, e.token, e.stake, e.memeHash, e.eliminated, e.accumulatedPot);
    }

    /// @notice Get the human-readable title for a tournament.
    /// @param tournamentId The tournament to query.
    /// @return title The stored tournament title.
    function getTournamentTitle(uint256 tournamentId) external view returns (string memory title) {
        require(tournaments[tournamentId].creator != address(0), "Tournament does not exist");
        return tournamentTitles[tournamentId];
    }

    /// @notice Get a tournament match result.
    /// @param tournamentId The tournament.
    /// @param round Round number (1-based).
    /// @param matchIndex Match index within the round (0-based).
    /// @return battleId Linked Arena battle ID.
    /// @return participant1Index First participant's index.
    /// @return participant2Index Second participant's index.
    /// @return winnerIndex Winner's participant index (0 if not decided).
    /// @return matchSettled Whether the match result has been recorded.
    function getTournamentMatch(uint256 tournamentId, uint8 round, uint8 matchIndex) external view returns (
        uint256 battleId,
        uint8   participant1Index,
        uint8   participant2Index,
        uint8   winnerIndex,
        bool    matchSettled
    ) {
        require(tournaments[tournamentId].creator != address(0), "Tournament does not exist");
        TournamentMatch storage m = tournamentMatches[tournamentId][round][matchIndex];
        return (m.battleId, m.participant1Index, m.participant2Index, m.winnerIndex, m.settled);
    }

    /// @notice Get the full bracket state for a tournament round.
    /// @param tournamentId The tournament to query.
    /// @param round Round number (1-based).
    /// @return battleIds Arena battle IDs for each bracket slot.
    /// @return participant1Indices First participant index per match.
    /// @return participant2Indices Second participant index per match.
    /// @return winnerIndices Winner participant index per match (0 if undecided).
    /// @return matchSettled Whether each match has been advanced.
    function getTournamentBracket(uint256 tournamentId, uint8 round) external view returns (
        uint256[] memory battleIds,
        uint8[] memory participant1Indices,
        uint8[] memory participant2Indices,
        uint8[] memory winnerIndices,
        bool[] memory matchSettled
    ) {
        require(tournaments[tournamentId].creator != address(0), "Tournament does not exist");
        uint8 count = tournamentRoundMatchCount[tournamentId][round];
        battleIds = new uint256[](count);
        participant1Indices = new uint8[](count);
        participant2Indices = new uint8[](count);
        winnerIndices = new uint8[](count);
        matchSettled = new bool[](count);

        for (uint8 i; i < count;) {
            TournamentMatch storage m = tournamentMatches[tournamentId][round][i];
            battleIds[i] = m.battleId;
            participant1Indices[i] = m.participant1Index;
            participant2Indices[i] = m.participant2Index;
            winnerIndices[i] = m.winnerIndex;
            matchSettled[i] = m.settled;
            unchecked { i++; }
        }
    }

    /// @notice Get the number of rounds for a tournament size.
    /// @param size Tournament size (4, 8, or 16).
    /// @return rounds Number of rounds.
    function getMaxRounds(uint8 size) external pure returns (uint8 rounds) {
        return _getMaxRounds(size);
    }
}
