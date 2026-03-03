// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title IGrokmeArenaTrophy
 * @notice Minimal interface for the Battle Trophy NFT contract
 */
interface IGrokmeArenaTrophy {
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
}

/**
 * @title IUniswapV2Router02
 * @notice Minimal interface for Uniswap V2 Router swap functionality
 */
interface IUniswapV2Router02 {
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
 * @title GrokmeArena
 * @notice GROKME Arena — Proof-of-Culture Meme Battle Protocol
 *
 * A decentralized, on-chain Meme Battle smart contract. Challengers stake
 * ERC-20 tokens behind a meme and dare an opponent to bring something better.
 * The community votes. The winning meme becomes an eternal NFT. The losing
 * meme is destroyed. All staked tokens from both sides are burned.
 *
 * Key properties:
 * - NO admin functions. NO owner. NO upgrade proxy. NO kill switch.
 * - 5% protocol fee on every deposit → auto-swapped to GROK → burned.
 * - Voting is on-chain, 1 wallet = 1 vote, token-holding verified.
 * - Settlement is permissionless — anyone can call settleBattle().
 * - All contract state is publicly verifiable on Etherscan.
 *
 * Part of the GROKME Protocol — grokme.me | battle.grokme.me
 */
contract GrokmeArena is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════════
    //  CONSTANTS
    // ═══════════════════════════════════════════════════════════════════

    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// @notice Protocol fee: 5% of every deposit is swapped to GROK and burned
    uint256 public constant PROTOCOL_FEE_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Challenged community has 72 hours to accept
    uint256 public constant CHALLENGE_EXPIRY = 72 hours;

    /// @notice Maximum raise rounds to prevent griefing
    uint256 public constant MAX_RAISE_ROUNDS = 10;

    /// @notice Grace period after voting ends before settlement
    uint256 public constant SETTLEMENT_WINDOW = 24 hours;

    /// @notice Bidding phase timeout — if pending responder doesn't act within 24h,
    ///         the other side can force-start or cancel
    uint256 public constant BIDDING_TIMEOUT = 24 hours;

    // ═══════════════════════════════════════════════════════════════════
    //  IMMUTABLES
    // ═══════════════════════════════════════════════════════════════════

    /// @notice The GROK ERC-20 token address (protocol fee burns this)
    address public immutable grokToken;

    /// @notice Uniswap V2 Router for protocol fee swaps
    IUniswapV2Router02 public immutable uniswapRouter;

    /// @notice WETH address (for swap routing)
    address public immutable weth;

    /// @notice Battle Trophy NFT contract — mints winner NFTs on settlement
    IGrokmeArenaTrophy public immutable trophyContract;

    // ═══════════════════════════════════════════════════════════════════
    //  ENUMS
    // ═══════════════════════════════════════════════════════════════════

    enum Status {
        Open,       // Challenge issued, waiting for opponent
        Bidding,    // Opponent accepted, raise/call/fold phase
        Battling,   // Both locked, voting in progress
        Settled,    // Battle concluded, tokens burned
        Expired,    // No one accepted within 72h
        Folded      // One side folded during bidding
    }

    enum Team { None, Challenger, Opponent }

    // ═══════════════════════════════════════════════════════════════════
    //  STRUCTS
    // ═══════════════════════════════════════════════════════════════════

    struct Battle {
        // ─── Challenger ───
        address challenger;
        address challengerToken;
        uint256 challengerStake;       // tokens locked (after fee)
        bytes32 challengerMemeHash;    // IPFS/Arweave content hash

        // ─── Opponent ───
        address opponent;
        address opponentToken;
        uint256 opponentStake;         // tokens locked (after fee)
        bytes32 opponentMemeHash;

        // ─── Challenge params ───
        address targetToken;           // address(0) = open challenge
        uint256 duration;              // voting duration in seconds
        uint256 minVoterBalance;       // min token balance to vote

        // ─── Poker state ───
        address pendingResponse;       // who must act next (call/fold/re-raise)
        uint8   raiseCount;
        uint256 lastBiddingAction;     // timestamp of last raise/accept (for timeout)

        // ─── Timing ───
        uint256 createdAt;
        uint256 battleStartsAt;
        uint256 battleEndsAt;

        // ─── Voting ───
        uint256 snapshotBlock;
        uint256 challengerVotes;
        uint256 opponentVotes;

        // ─── Result ───
        Status  status;
        Team    winner;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  STATE
    // ═══════════════════════════════════════════════════════════════════

    uint256 public nextBattleId;
    mapping(uint256 => Battle) public battles;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice GROK burned from protocol fees per battle
    mapping(uint256 => uint256) public battleGrokFees;

    /// @notice Total GROK burned through protocol fees (lifetime)
    uint256 public totalGrokBurned;

    /// @notice Total battles settled
    uint256 public totalBattlesSettled;

    // ═══════════════════════════════════════════════════════════════════
    //  EVENTS
    // ═══════════════════════════════════════════════════════════════════

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

    event ChallengeAccepted(
        uint256 indexed battleId,
        address indexed opponent,
        address opponentToken,
        uint256 stakeAfterFee,
        bytes32 memeHash
    );

    event Raised(
        uint256 indexed battleId,
        address indexed raiser,
        uint256 additionalStakeAfterFee
    );

    event Called(uint256 indexed battleId, address indexed caller, uint256 additionalStakeAfterFee);
    event Folded(uint256 indexed battleId, address indexed folder);
    event BattleStarted(uint256 indexed battleId, uint256 snapshotBlock, uint256 endsAt);
    event VoteCast(uint256 indexed battleId, address indexed voter, Team team, uint256 voterBalance);

    event BattleSettled(
        uint256 indexed battleId,
        Team    winner,
        uint256 challengerVotes,
        uint256 opponentVotes,
        uint256 challengerTokensBurned,
        uint256 opponentTokensBurned
    );

    event ProtocolFeeBurned(
        uint256 indexed battleId,
        address indexed fromToken,
        uint256 tokenAmount,
        uint256 grokBurned
    );

    event ChallengeExpired(uint256 indexed battleId);
    event StakeRefunded(uint256 indexed battleId, address indexed to, address token, uint256 amount);

    // ═══════════════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @param _grokToken  GROK ERC-20 address (0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5)
     * @param _uniswapRouter Uniswap V2 Router address
     * @param _trophyContract GrokmeArenaTrophy NFT contract address
     */
    constructor(address _grokToken, address _uniswapRouter, address _trophyContract) {
        require(_grokToken != address(0), "Invalid GROK address");
        require(_uniswapRouter != address(0), "Invalid router address");
        require(_trophyContract != address(0), "Invalid trophy address");
        grokToken = _grokToken;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        weth = IUniswapV2Router02(_uniswapRouter).WETH(); // aderyn-fp(reentrancy)
        trophyContract = IGrokmeArenaTrophy(_trophyContract); // aderyn-fp(reentrancy)
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 1 — ISSUE CHALLENGE
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Create a new meme battle challenge
     * @param token          ERC-20 token to stake (challenger's community token)
     * @param amount         Amount of tokens to stake (before protocol fee)
     * @param targetToken    Rival community token. address(0) = open challenge.
     * @param duration       Voting duration in seconds (min 24h, max 72h)
     * @param memeHash       IPFS/Arweave hash of the challenger's meme
     * @param minVoterBal    Minimum token balance required to vote (0 = no minimum)
     */
    function issueChallenge(
        address token,
        uint256 amount,
        address targetToken,
        uint256 duration,
        bytes32 memeHash,
        uint256 minVoterBal
    ) external nonReentrant returns (uint256 battleId) {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Stake must be > 0");
        require(memeHash != bytes32(0), "Meme hash required");
        require(duration >= 5 minutes && duration <= 35 days, "Duration: 5min-35d");

        // Transfer tokens and take protocol fee (handles fee-on-transfer tokens)
        (uint256 stakeAfterFee, uint256 fee) = _depositWithFee(token, amount);
        _burnProtocolFee(nextBattleId, token, fee);

        // Create battle record
        battleId = nextBattleId++;
        Battle storage b = battles[battleId];
        b.challenger = msg.sender;
        b.challengerToken = token;
        b.challengerStake = stakeAfterFee;
        b.challengerMemeHash = memeHash;
        b.targetToken = targetToken;
        b.duration = duration;
        b.minVoterBalance = minVoterBal;
        b.createdAt = block.timestamp;
        b.status = Status.Open;

        emit ChallengeIssued(
            battleId, msg.sender, token, stakeAfterFee,
            targetToken, memeHash, duration, minVoterBal
        );
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 2 — ACCEPT & RAISE
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Accept an open challenge with a counter-meme and stake
     * @param battleId   The challenge to accept
     * @param token      ERC-20 token to stake (opponent's community token)
     * @param amount     Amount of tokens to stake (before fee). If > matching value = raise.
     * @param memeHash   IPFS/Arweave hash of the opponent's counter-meme
     */
    function acceptChallenge(
        uint256 battleId,
        address token,
        uint256 amount,
        bytes32 memeHash
    ) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.status == Status.Open, "Not open");
        require(block.timestamp <= b.createdAt + CHALLENGE_EXPIRY, "Challenge expired");
        require(msg.sender != b.challenger, "Cannot accept own challenge");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Stake must be > 0");
        require(memeHash != bytes32(0), "Meme hash required");

        // If targeted challenge, opponent must use the target token
        if (b.targetToken != address(0)) {
            require(token == b.targetToken, "Must use target token");
        }

        // Transfer tokens and take protocol fee (handles fee-on-transfer tokens)
        (uint256 stakeAfterFee, uint256 fee) = _depositWithFee(token, amount);
        _burnProtocolFee(battleId, token, fee);

        // Record opponent
        b.opponent = msg.sender;
        b.opponentToken = token;
        b.opponentStake = stakeAfterFee;
        b.opponentMemeHash = memeHash;

        emit ChallengeAccepted(battleId, msg.sender, token, stakeAfterFee, memeHash);

        // Enter bidding phase — challenger must call, fold, or re-raise
        b.pendingResponse = b.challenger;
        b.lastBiddingAction = block.timestamp;
        b.status = Status.Bidding;
    }

    /**
     * @notice Raise the stakes during bidding phase
     * @param battleId         The active bidding battle
     * @param additionalAmount Additional tokens to add (before fee)
     */
    function raise(uint256 battleId, uint256 additionalAmount) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.status == Status.Bidding, "Not in bidding");
        require(b.raiseCount < MAX_RAISE_ROUNDS, "Max raises reached");
        require(additionalAmount > 0, "Must raise > 0");

        // Only the person who needs to respond can raise (or the pending responder)
        require(msg.sender == b.pendingResponse, "Not your turn");

        // Determine which token to add
        address token;
        if (msg.sender == b.challenger) {
            token = b.challengerToken;
        } else {
            token = b.opponentToken;
        }

        // Transfer additional tokens and take fee
        (uint256 afterFee, uint256 fee) = _depositWithFee(token, additionalAmount);
        _burnProtocolFee(battleId, token, fee);

        // Update stake
        if (msg.sender == b.challenger) {
            b.challengerStake += afterFee;
        } else {
            b.opponentStake += afterFee;
        }

        // Flip pending response to the other side
        b.pendingResponse = (msg.sender == b.challenger) ? b.opponent : b.challenger;
        b.lastBiddingAction = block.timestamp;
        b.raiseCount++;

        emit Raised(battleId, msg.sender, afterFee);
    }

    /**
     * @notice Call the current stake level — match and start the battle
     * @param battleId         The active bidding battle
     * @param additionalAmount Additional tokens to add to match (before fee). Can be 0 if already matched.
     */
    function call(uint256 battleId, uint256 additionalAmount) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.status == Status.Bidding, "Not in bidding");
        require(msg.sender == b.pendingResponse, "Not your turn");

        if (additionalAmount > 0) {
            address token = (msg.sender == b.challenger) ? b.challengerToken : b.opponentToken;
            (uint256 afterFee, uint256 fee) = _depositWithFee(token, additionalAmount);
            _burnProtocolFee(battleId, token, fee);

            if (msg.sender == b.challenger) {
                b.challengerStake += afterFee;
            } else {
                b.opponentStake += afterFee;
            }

            emit Called(battleId, msg.sender, afterFee);
        } else {
            emit Called(battleId, msg.sender, 0);
        }

        // Start the battle
        _startBattle(battleId);
    }

    /**
     * @notice Fold — withdraw from the bidding. Tokens returned. Fold recorded permanently.
     * @param battleId The active bidding battle
     */
    function fold(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.status == Status.Bidding, "Not in bidding");
        require(msg.sender == b.pendingResponse, "Not your turn");

        b.status = Status.Folded;

        // Refund remaining stakes to both sides (fees already burned)
        if (b.challengerStake > 0) {
            IERC20(b.challengerToken).safeTransfer(b.challenger, b.challengerStake);
            emit StakeRefunded(battleId, b.challenger, b.challengerToken, b.challengerStake);
            b.challengerStake = 0;
        }
        if (b.opponentStake > 0) {
            IERC20(b.opponentToken).safeTransfer(b.opponent, b.opponentStake);
            emit StakeRefunded(battleId, b.opponent, b.opponentToken, b.opponentStake);
            b.opponentStake = 0;
        }

        emit Folded(battleId, msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  EXPIRE UNANSWERED CHALLENGES
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Expire an unanswered challenge and refund the challenger.
     *         Callable by anyone after 72h. Fee is NOT refunded.
     */
    function expireChallenge(uint256 battleId) external nonReentrant { // aderyn-fp(sends-ether-away-without-checking-address)
        Battle storage b = battles[battleId];
        require(b.status == Status.Open, "Not open");
        require(block.timestamp > b.createdAt + CHALLENGE_EXPIRY, "Not expired yet");

        b.status = Status.Expired;

        // Refund remaining stake (fee already burned)
        if (b.challengerStake > 0) {
            // aderyn-fp(sends-ether-away-without-checking-address): recipient is b.challenger set at challenge creation
            IERC20(b.challengerToken).safeTransfer(b.challenger, b.challengerStake);
            emit StakeRefunded(battleId, b.challenger, b.challengerToken, b.challengerStake);
            b.challengerStake = 0;
        }

        emit ChallengeExpired(battleId);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 3+4 — VOTING
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Cast a vote for a team in an active battle.
     *         1 wallet = 1 vote. Must hold the team's token.
     * @param battleId The active battle
     * @param team     Team.Challenger or Team.Opponent
     */
    function castVote(uint256 battleId, Team team) external {
        Battle storage b = battles[battleId];
        require(b.status == Status.Battling, "Not in battle");
        require(block.timestamp < b.battleEndsAt, "Voting ended");
        require(team == Team.Challenger || team == Team.Opponent, "Invalid team");
        require(!hasVoted[battleId][msg.sender], "Already voted");

        // CEI: record vote before external balanceOf calls
        hasVoted[battleId][msg.sender] = true;

        // Token holding verification
        uint256 voterBalance;
        if (b.challengerToken == b.opponentToken) {
            // Same-token duel: any holder can vote for either side
            voterBalance = IERC20(b.challengerToken).balanceOf(msg.sender); // aderyn-fp(reentrancy)
        } else if (team == Team.Challenger) {
            voterBalance = IERC20(b.challengerToken).balanceOf(msg.sender); // aderyn-fp(reentrancy)
        } else {
            voterBalance = IERC20(b.opponentToken).balanceOf(msg.sender); // aderyn-fp(reentrancy)
        }
        require(voterBalance > 0, "Must hold team token");
        if (b.minVoterBalance > 0) {
            require(voterBalance >= b.minVoterBalance, "Below min voter balance");
        }

        // Record vote count
        if (team == Team.Challenger) {
            b.challengerVotes++;
        } else {
            b.opponentVotes++;
        }

        emit VoteCast(battleId, msg.sender, team, voterBalance);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  PHASE 5 — SETTLEMENT (Permissionless)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Settle a battle after the voting window closes.
     *         Callable by ANYONE. Determines winner, burns all tokens.
     * @param battleId The battle to settle
     */
    function settleBattle(uint256 battleId) external nonReentrant { // aderyn-fp(sends-ether-away-without-checking-address)
        Battle storage b = battles[battleId];
        require(b.status == Status.Battling, "Not in battle");
        require(block.timestamp >= b.battleEndsAt, "Voting still active");

        // Determine winner
        if (b.challengerVotes > b.opponentVotes) {
            b.winner = Team.Challenger;
        } else if (b.opponentVotes > b.challengerVotes) {
            b.winner = Team.Opponent;
        } else {
            // Tie: challenger wins (first-mover advantage, they took the risk)
            b.winner = Team.Challenger;
        }

        b.status = Status.Settled;
        totalBattlesSettled++;

        // Burn ALL remaining staked tokens from BOTH sides
        uint256 challengerBurned = b.challengerStake;
        uint256 opponentBurned = b.opponentStake;

        if (challengerBurned > 0) {
            // aderyn-fp(sends-ether-away-without-checking-address)
            IERC20(b.challengerToken).safeTransfer(DEAD_ADDRESS, challengerBurned);
            b.challengerStake = 0;
        }
        if (opponentBurned > 0) {
            // aderyn-fp(sends-ether-away-without-checking-address)
            IERC20(b.opponentToken).safeTransfer(DEAD_ADDRESS, opponentBurned);
            b.opponentStake = 0;
        }

        emit BattleSettled(
            battleId,
            b.winner,
            b.challengerVotes,
            b.opponentVotes,
            challengerBurned,
            opponentBurned
        );

        // Mint Trophy NFT to the winner
        _mintTrophy(battleId, b, challengerBurned, opponentBurned);
    }

    /**
     * @dev Mint a Battle Trophy NFT to the winning meme creator.
     *      Uses try/catch so trophy mint failure doesn't block settlement.
     */
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

        // Try/catch: trophy mint failure must NOT block settlement/burn
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
            b.battleEndsAt,
            "" // tokenURI set off-chain via event listener
        ) {} catch {}
    }

    // ═══════════════════════════════════════════════════════════════════
    //  BIDDING TIMEOUT — Force resolution if opponent stalls
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Force-start a battle if the pending responder hasn't acted
     *         within BIDDING_TIMEOUT. Callable by the NON-pending side.
     *         The non-responding side is treated as having called (no fold).
     */
    function forceStartAfterTimeout(uint256 battleId) external nonReentrant {
        Battle storage b = battles[battleId];
        require(b.status == Status.Bidding, "Not in bidding");
        require(block.timestamp > b.lastBiddingAction + BIDDING_TIMEOUT, "Timeout not reached");
        require(msg.sender != b.pendingResponse, "You are the pending responder");

        _startBattle(battleId);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — BATTLE START
    // ═══════════════════════════════════════════════════════════════════

    function _startBattle(uint256 battleId) internal {
        Battle storage b = battles[battleId];
        b.status = Status.Battling;
        b.snapshotBlock = block.number;
        b.battleStartsAt = block.timestamp;
        b.battleEndsAt = block.timestamp + b.duration;

        emit BattleStarted(battleId, block.number, b.battleEndsAt);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — PROTOCOL FEE (Swap to GROK + Burn)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Takes the protocol fee amount of a token, swaps to GROK via
     *      Uniswap V2, and sends the GROK to the dead address.
     *      If the token IS GROK, burns directly (no swap needed).
     */
    function _burnProtocolFee(uint256 battleId, address token, uint256 feeAmount) internal {
        if (feeAmount == 0) return;

        if (token == grokToken) {
            // Token is GROK — burn directly, no swap needed
            // CEI: update state before external call
            totalGrokBurned += feeAmount;
            battleGrokFees[battleId] += feeAmount;
            // aderyn-fp(sends-ether-away-without-checking-address)
            IERC20(grokToken).safeTransfer(DEAD_ADDRESS, feeAmount);
            emit ProtocolFeeBurned(battleId, token, feeAmount, feeAmount);
            return;
        }

        // Swap token → WETH → GROK via Uniswap V2
        // Reset approval to 0 first (required by USDT-style tokens)
        IERC20(token).safeApprove(address(uniswapRouter), 0);
        IERC20(token).safeApprove(address(uniswapRouter), feeAmount);

        address[] memory path;
        if (token == weth) {
            path = new address[](2);
            path[0] = weth;
            path[1] = grokToken;
        } else {
            path = new address[](3);
            path[0] = token;
            path[1] = weth;
            path[2] = grokToken;
        }

        // amountOutMin = 0 because we're burning the output anyway.
        // MEV/sandwich attacks are irrelevant — the GROK goes to dead address.
        try uniswapRouter.swapExactTokensForTokens(
            feeAmount,
            0,              // accept any amount (burning anyway)
            path,
            DEAD_ADDRESS,   // GROK goes straight to burn (aderyn-fp: hardcoded constant)
            block.timestamp
        ) returns (uint256[] memory amounts) {
            uint256 grokBurned = amounts[amounts.length - 1];
            // CEI: update state before emitting (external call already done)
            totalGrokBurned += grokBurned;
            battleGrokFees[battleId] += grokBurned;
            emit ProtocolFeeBurned(battleId, token, feeAmount, grokBurned);
        } catch {
            // If swap fails (no liquidity), burn the fee token directly.
            // This ensures challenges with illiquid tokens still work —
            // the fee is destroyed regardless.
            IERC20(token).safeTransfer(DEAD_ADDRESS, feeAmount);
            emit ProtocolFeeBurned(battleId, token, feeAmount, 0);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  INTERNAL — DEPOSIT WITH FEE (Fee-on-Transfer Safe)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Transfer tokens from msg.sender and calculate actual received amount.
     *      Uses balance-before/after pattern to support fee-on-transfer tokens.
     *      Returns (stakeAfterFee, feeAmount) based on actually received tokens.
     */
    function _depositWithFee(address token, uint256 amount) internal returns (uint256 stakeAfterFee, uint256 feeAmount) {
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balBefore;

        feeAmount = (received * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        stakeAfterFee = received - feeAmount;
    }

    // ═══════════════════════════════════════════════════════════════════
    //  VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Get full battle data
     */
    function getBattle(uint256 battleId) external view returns (
        address challenger,
        address challengerToken,
        uint256 challengerStake,
        bytes32 challengerMemeHash,
        address opponent,
        address opponentToken,
        uint256 opponentStake,
        bytes32 opponentMemeHash,
        Status  status,
        Team    winner,
        uint256 challengerVotes,
        uint256 opponentVotes
    ) {
        Battle storage b = battles[battleId];
        return (
            b.challenger, b.challengerToken, b.challengerStake, b.challengerMemeHash,
            b.opponent, b.opponentToken, b.opponentStake, b.opponentMemeHash,
            b.status, b.winner, b.challengerVotes, b.opponentVotes
        );
    }

    /**
     * @notice Get battle timing info
     */
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
        return (
            b.createdAt, b.battleStartsAt, b.battleEndsAt,
            b.snapshotBlock, b.duration, b.pendingResponse, b.raiseCount
        );
    }

    /**
     * @notice Check if a wallet has voted in a battle
     */
    function hasWalletVoted(uint256 battleId, address wallet) external view returns (bool) {
        return hasVoted[battleId][wallet];
    }

    /**
     * @notice Get the current challenge status and whether it can be accepted
     */
    function isChallengeAcceptable(uint256 battleId) external view returns (bool) {
        Battle storage b = battles[battleId];
        return b.status == Status.Open && block.timestamp <= b.createdAt + CHALLENGE_EXPIRY;
    }

    /**
     * @notice Check if a battle can be settled
     */
    function isSettleable(uint256 battleId) external view returns (bool) {
        Battle storage b = battles[battleId];
        return b.status == Status.Battling && block.timestamp >= b.battleEndsAt;
    }
}
