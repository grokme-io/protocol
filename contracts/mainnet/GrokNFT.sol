// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GrokNFT
 * @notice Burn-to-Mint NFT — 6 rarity tiers, fixed GROK burn amounts per tier.
 * @dev Deployed: 0x5ee102ab33bcc5c49996fb48dea465ec6330e77d (Ethereum Mainnet)
 *      No oracle. No signature scheme. Fully permissionless mint.
 *      Owner retains setContractURI() only — zero mint control.
 */
contract GrokNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    
    uint256 constant GROK_DECIMALS = 1e9;
    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    // Tier Limits
    uint256 constant COMMON_LIMIT = 469;
    uint256 constant RARE_LIMIT = 138;
    uint256 constant EPIC_LIMIT = 69;
    uint256 constant LEGENDARY_LIMIT = 10;
    uint256 constant DIVINE_LIMIT = 3;
    uint256 constant UNICORN_LIMIT = 1;
    
    // Tier Burns (GROK has 9 decimals)
    uint256 constant COMMON_BURN = 6_900 * GROK_DECIMALS;
    uint256 constant RARE_BURN = 69_000 * GROK_DECIMALS;
    uint256 constant EPIC_BURN = 690_000 * GROK_DECIMALS;
    uint256 constant LEGENDARY_BURN = 1_000_000 * GROK_DECIMALS;
    uint256 constant DIVINE_BURN = 10_000_000 * GROK_DECIMALS;
    uint256 constant UNICORN_BURN = 100_000_000 * GROK_DECIMALS;
    
    IERC20 public immutable GROK_TOKEN;
    
    uint256 public currentTokenId;
    uint256 public totalGrokBurned;
    uint256 public commonMinted;
    uint256 public rareMinted;
    uint256 public epicMinted;
    uint256 public legendaryMinted;
    uint256 public divineMinted;
    uint256 public unicornMinted;
    
    mapping(uint256 => uint256) public tokenBurnAmount;
    
    string private _contractURI;
    
    event Grokked(uint256 indexed tokenId, address indexed creator, uint256 grokBurned, string tier, string ipfsURI);
    
    constructor(
        address _grokTokenAddress,
        string memory _name,
        string memory _symbol,
        string memory initialContractURI
    ) ERC721(_name, _symbol) Ownable() {
        require(_grokTokenAddress != address(0), "Invalid");
        GROK_TOKEN = IERC20(_grokTokenAddress);
        _contractURI = initialContractURI;
        _transferOwnership(msg.sender);
    }
    
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
    
    function setContractURI(string memory newURI) external onlyOwner {
        _contractURI = newURI;
    }
    
    function mint(string memory ipfsURI, uint256 grokBurnAmount) external nonReentrant returns (uint256) {
        require(currentTokenId < 690, "Sold out");
        require(bytes(ipfsURI).length > 0, "Empty URI");
        
        string memory tier;
        
        if (grokBurnAmount == COMMON_BURN) {
            require(commonMinted < COMMON_LIMIT, "COMMON sold out");
            commonMinted++;
            tier = "COMMON";
        } else if (grokBurnAmount == RARE_BURN) {
            require(rareMinted < RARE_LIMIT, "RARE sold out");
            rareMinted++;
            tier = "RARE";
        } else if (grokBurnAmount == EPIC_BURN) {
            require(epicMinted < EPIC_LIMIT, "EPIC sold out");
            epicMinted++;
            tier = "EPIC";
        } else if (grokBurnAmount == LEGENDARY_BURN) {
            require(legendaryMinted < LEGENDARY_LIMIT, "LEGENDARY sold out");
            legendaryMinted++;
            tier = "LEGENDARY";
        } else if (grokBurnAmount == DIVINE_BURN) {
            require(divineMinted < DIVINE_LIMIT, "DIVINE sold out");
            divineMinted++;
            tier = "DIVINE";
        } else if (grokBurnAmount == UNICORN_BURN) {
            require(unicornMinted < UNICORN_LIMIT, "UNICORN taken");
            unicornMinted++;
            tier = "UNICORN";
        } else {
            revert("Invalid tier");
        }
        
        require(GROK_TOKEN.transferFrom(msg.sender, BURN_ADDRESS, grokBurnAmount), "Burn failed");
        
        uint256 tokenId = ++currentTokenId;
        totalGrokBurned += grokBurnAmount;
        tokenBurnAmount[tokenId] = grokBurnAmount;
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, ipfsURI);
        
        emit Grokked(tokenId, msg.sender, grokBurnAmount, tier, ipfsURI);
        
        return tokenId;
    }
}
