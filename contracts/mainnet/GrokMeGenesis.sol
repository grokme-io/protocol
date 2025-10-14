// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title GROKME GENESIS
 */
contract GrokMeGenesis is ERC721URIStorage, ReentrancyGuard, Ownable, EIP712 {
    
    using ECDSA for bytes32;
    
    // ============ CONSTANTS ============
    
    uint256 public constant GROK_DECIMALS = 10**9;
    uint256 public constant MIN_BURN_RATE_PER_KB = 1;
    uint256 public constant MAX_BURN_RATE_PER_KB = 1000;
    uint256 public constant MAX_CONTENT_SIZE = 12 * 1024 * 1024;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public immutable GROK_TOKEN_ADDRESS;
    uint256 public constant MAX_CAPACITY_BYTES = 6_900_000_000;
    
    bytes32 public constant TOKEN_ID_ASSIGNMENT_TYPEHASH = keccak256(
        "TokenIdAssignment(uint256 tokenId,uint256 burnRatePerKB,uint256 nonce,address userAddress,uint256 validUntil)"
    );
    
    // ============ STATE ============
    
    IERC20Metadata public immutable grokToken;
    uint256 public highestMintedTokenId;
    address public immutable oracle;
    mapping(uint256 => bool) private _usedNonces;
    uint256 public totalGrokBurned;
    uint256 public totalBytesMinted;
    mapping(uint256 => uint256) public tokenBurnRate;
    mapping(bytes32 => uint256) public burnTxTotal;
    mapping(bytes32 => uint256) public burnTxUsed;
    
    // ============ EVENTS ============
    
    event Grokked(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 grokBurned,
        uint256 burnRatePerKB,
        uint256 contentSize,
        string ipfsURI,
        bytes32 burnTx
    );
    
    event CapsuleSealed(
        uint256 totalBytesMinted,
        uint256 totalGrokBurned,
        uint256 totalTokens
    );
    
    event BurnTxRegistered(
        bytes32 indexed txHash,
        uint256 amount
    );
    
    // ============ MODIFIERS ============
    
    modifier capsuleOpen() {
        require(totalBytesMinted < MAX_CAPACITY_BYTES, "Capsule sealed");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(address _grokTokenAddress, address _oracle) 
        ERC721("GROKME GENESIS", "GROKME GENESIS")
        EIP712("GrokMeGenesis", "1")
    {
        require(_grokTokenAddress != address(0), "Invalid GROK address");
        require(_oracle != address(0), "Invalid oracle address");
        
        GROK_TOKEN_ADDRESS = _grokTokenAddress;
        grokToken = IERC20Metadata(_grokTokenAddress);
        oracle = _oracle;
        
        // Verify GROK has 9 decimals
        require(grokToken.decimals() == 9, "GROK must have 9 decimals");
    }
    
    // ============ MINTING FUNCTIONS ============
    
    /**
     * @notice Mint NFT
     */
    function grokMeWithSignedId(
        uint256 tokenId,
        string memory ipfsURI,
        uint256 contentSizeBytes,
        uint256 burnRatePerKB,
        uint256 nonce,
        uint256 validUntil,
        bytes memory signature,
        bytes32 burnTx
    ) external nonReentrant capsuleOpen returns (uint256) {
        // Validations
        require(bytes(ipfsURI).length > 0, "Empty URI");
        require(contentSizeBytes > 0, "Zero size");
        require(contentSizeBytes <= MAX_CONTENT_SIZE, "Content too large");
        require(totalBytesMinted + contentSizeBytes <= MAX_CAPACITY_BYTES, "Exceeds capsule capacity");
        require(burnRatePerKB >= MIN_BURN_RATE_PER_KB && burnRatePerKB <= MAX_BURN_RATE_PER_KB, "Invalid burn rate");
        require(!_usedNonces[nonce], "Nonce already used");
        require(block.timestamp <= validUntil, "Signature expired");
        require(!_exists(tokenId), "Token ID already exists");
        
        // Verify Oracle signature
        bytes32 structHash = keccak256(abi.encode(
            TOKEN_ID_ASSIGNMENT_TYPEHASH,
            tokenId,
            burnRatePerKB,
            nonce,
            msg.sender,
            validUntil
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);
        require(signer == oracle, "Invalid signature");
        
        // Mark nonce as used
        _usedNonces[nonce] = true;
        
        // Calculate GROK amount
        uint256 sizeKB = (contentSizeBytes + 1023) / 1024;
        uint256 grokAmount = sizeKB * burnRatePerKB * GROK_DECIMALS;
        
        // Handle GROK burn
        if (burnTx == bytes32(0)) {
            require(grokToken.transferFrom(msg.sender, BURN_ADDRESS, grokAmount), "GROK burn failed");
        } else {
            _applyBurnTx(burnTx, grokAmount);
        }
        
        // Update state
        totalBytesMinted += contentSizeBytes;
        totalGrokBurned += grokAmount;
        tokenBurnRate[tokenId] = burnRatePerKB;
        
        // Mint NFT
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, ipfsURI);
        
        // Track highest minted ID
        if (tokenId > highestMintedTokenId) {
            highestMintedTokenId = tokenId;
        }
        
        emit Grokked(tokenId, msg.sender, grokAmount, burnRatePerKB, contentSizeBytes, ipfsURI, burnTx);
        
        // Check if capsule is now sealed
        if (totalBytesMinted >= MAX_CAPACITY_BYTES) {
            emit CapsuleSealed(totalBytesMinted, totalGrokBurned, highestMintedTokenId + 1);
        }
        
        return tokenId;
    }
    
    /**
     * @notice Batch mint NFTs
     */
    function grokMeBatchWithSignedId(
        uint256[] memory tokenIds,
        string[] memory ipfsURIs,
        uint256[] memory contentSizes,
        uint256 burnRatePerKB,
        uint256[] memory nonces,
        uint256[] memory validUntils,
        bytes[] memory signatures,
        bytes32 burnTx
    ) external nonReentrant capsuleOpen returns (uint256[] memory) {
        require(tokenIds.length > 0, "Empty batch");
        require(tokenIds.length == ipfsURIs.length, "Length mismatch");
        require(tokenIds.length == contentSizes.length, "Length mismatch");
        require(tokenIds.length == nonces.length, "Length mismatch");
        require(tokenIds.length == validUntils.length, "Length mismatch");
        require(tokenIds.length == signatures.length, "Length mismatch");
        require(tokenIds.length <= 50, "Batch too large");
        require(burnRatePerKB >= MIN_BURN_RATE_PER_KB && burnRatePerKB <= MAX_BURN_RATE_PER_KB, "Invalid burn rate");
        
        // Calculate total size and cost
        uint256 totalSize = 0;
        uint256 totalGrokNeeded = 0;
        
        // STEP 1: Validate ALL signatures and Token IDs FIRST
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(!_usedNonces[nonces[i]], "Nonce already used");
            require(block.timestamp <= validUntils[i], "Signature expired");
            require(!_exists(tokenIds[i]), "Token already minted");
            
            // Verify Oracle signature
            bytes32 structHash = keccak256(
                abi.encode(
                    TOKEN_ID_ASSIGNMENT_TYPEHASH,
                    tokenIds[i],
                    burnRatePerKB,
                    nonces[i],
                    msg.sender,
                    validUntils[i]
                )
            );
            
            bytes32 digest = _hashTypedDataV4(structHash);
            address signer = digest.recover(signatures[i]);
            require(signer == oracle, "Invalid oracle signature");
            
            // Calculate size and cost
            require(bytes(ipfsURIs[i]).length > 0, "Empty URI");
            require(contentSizes[i] > 0, "Zero size");
            require(contentSizes[i] <= MAX_CONTENT_SIZE, "Content too large");
            
            totalSize += contentSizes[i];
            uint256 sizeKB = (contentSizes[i] + 1023) / 1024;
            totalGrokNeeded += sizeKB * burnRatePerKB * GROK_DECIMALS;
        }
        
        // STEP 2: Check capacity
        require(totalBytesMinted + totalSize <= MAX_CAPACITY_BYTES, "Exceeds capsule capacity");
        
        // STEP 3: Handle GROK burn
        if (burnTx == bytes32(0)) {
            require(grokToken.transferFrom(msg.sender, BURN_ADDRESS, totalGrokNeeded), "GROK burn failed");
        } else {
            _applyBurnTx(burnTx, totalGrokNeeded);
        }
        
        // STEP 4: Mint all NFTs
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _usedNonces[nonces[i]] = true;
            
            _safeMint(msg.sender, tokenIds[i]);
            _setTokenURI(tokenIds[i], ipfsURIs[i]);
            
            if (tokenIds[i] > highestMintedTokenId) {
                highestMintedTokenId = tokenIds[i];
            }
            
            tokenBurnRate[tokenIds[i]] = burnRatePerKB;
            
            uint256 sizeKB = (contentSizes[i] + 1023) / 1024;
            uint256 grokForThis = sizeKB * burnRatePerKB * GROK_DECIMALS;
            emit Grokked(tokenIds[i], msg.sender, grokForThis, burnRatePerKB, contentSizes[i], ipfsURIs[i], burnTx);
        }
        
        // Update state
        totalBytesMinted += totalSize;
        totalGrokBurned += totalGrokNeeded;
        
        if (totalBytesMinted >= MAX_CAPACITY_BYTES) {
            emit CapsuleSealed(totalBytesMinted, totalGrokBurned, highestMintedTokenId + 1);
        }
        
        return tokenIds;
    }
    
    // ============ BURN TX TRACKING ============
    
    /**
     * @notice Register burn transaction
     */
    function registerBurnTx(bytes32 txHash, uint256 amount) external {
        require(msg.sender == oracle, "Only oracle");
        require(txHash != bytes32(0), "Invalid tx hash");
        require(amount > 0, "Zero amount");
        require(burnTxTotal[txHash] == 0, "Already registered");
        
        burnTxTotal[txHash] = amount;
        emit BurnTxRegistered(txHash, amount);
    }
    
    function _applyBurnTx(bytes32 txHash, uint256 amount) internal {
        require(burnTxTotal[txHash] > 0, "Unknown burn tx");
        require(burnTxUsed[txHash] + amount <= burnTxTotal[txHash], "Insufficient");
        burnTxUsed[txHash] += amount;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @notice Get available amount
     */
    function getBurnTxAvailable(bytes32 txHash) external view returns (uint256) {
        uint256 total = burnTxTotal[txHash];
        uint256 used = burnTxUsed[txHash];
        if (total == 0) return 0;
        if (used >= total) return 0;
        return total - used;
    }
    
    function isCapsuleOpen() external view returns (bool) {
        return totalBytesMinted < MAX_CAPACITY_BYTES;
    }
    
    function getRemainingCapacity() external view returns (uint256) {
        if (totalBytesMinted >= MAX_CAPACITY_BYTES) return 0;
        return MAX_CAPACITY_BYTES - totalBytesMinted;
    }
    
    function getCompletionPercentage() external view returns (uint256) {
        if (totalBytesMinted >= MAX_CAPACITY_BYTES) return 100;
        return (totalBytesMinted * 100) / MAX_CAPACITY_BYTES;
    }
    
    // ============ ADMIN ============
    
    /**
     * @notice Renounce ownership
     */
    function renounceOwnership() public override onlyOwner {
        super.renounceOwnership();
    }
    
    // ============ NO ETH ============
    
    receive() external payable {
        revert("No ETH accepted");
    }
}

