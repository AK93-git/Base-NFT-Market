// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  BaseNFTMarket.sol
  - ERC721 NFT mint
  - Simple fixed-price listings
  - ERC-2981 royalties
  - Events for indexing
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BaseNFTMarket is ERC721URIStorage, ERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    struct Listing {
        address seller;
        uint256 price; // in wei
    }

    uint256 public nextTokenId = 1;

    // tokenId => Listing
    mapping(uint256 => Listing) public listings;

    event Minted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event Unlisted(address indexed seller, uint256 indexed tokenId);
    event Sold(address indexed buyer, address indexed seller, uint256 indexed tokenId, uint256 price);

    constructor(
        string memory name_,
        string memory symbol_,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator // e.g. 500 = 5% (basis points out of 10000)
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(royaltyReceiver != address(0), "royalty receiver = 0");
        require(royaltyFeeNumerator <= 2000, "royalty too high"); // cap 20% for sanity
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    // ---------------------------
    // Mint
    // ---------------------------
    function mint(address to, string calldata uri) external returns (uint256 tokenId) {
        require(to != address(0), "to = 0");
        tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit Minted(to, tokenId, uri);
    }

    // Optional: owner can set royalty config
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        require(receiver != address(0), "receiver = 0");
        require(feeNumerator <= 2000, "royalty too high");
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // ---------------------------
    // Listings
    // ---------------------------
    function list(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "not owner");
        require(price > 0, "price = 0");
        require(
            getApproved(tokenId) == address(this) || isApprovedForAll(msg.sender, address(this)),
            "market not approved"
        );

        listings[tokenId] = Listing({seller: msg.sender, price: price});
        emit Listed(msg.sender, tokenId, price);
    }

    function unlist(uint256 tokenId) external {
        Listing memory l = listings[tokenId];
        require(l.seller != address(0), "not listed");
        require(l.seller == msg.sender, "not seller");

        delete listings[tokenId];
        emit Unlisted(msg.sender, tokenId);
    }

    function buy(uint256 tokenId) external payable nonReentrant {
        Listing memory l = listings[tokenId];
        require(l.seller != address(0), "not listed");
        require(msg.value == l.price, "wrong value");
        require(l.seller != msg.sender, "seller = buyer");

        // clear listing first (checks-effects-interactions)
        delete listings[tokenId];

        // Royalty info (ERC-2981)
        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, msg.value);

        uint256 sellerAmount = msg.value - royaltyAmount;

        // Transfer NFT
        // Seller must have approved market, checked in list()
        _safeTransfer(l.seller, msg.sender, tokenId, "");

        // Payouts
        if (royaltyAmount > 0) {
            (bool rOk, ) = payable(royaltyReceiver).call{value: royaltyAmount}("");
            require(rOk, "royalty transfer failed");
        }

        (bool sOk, ) = payable(l.seller).call{value: sellerAmount}("");
        require(sOk, "seller transfer failed");

        emit Sold(msg.sender, l.seller, tokenId, msg.value);
    }


    // Overrides

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
