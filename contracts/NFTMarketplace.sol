# base-nft-marketplace/contracts/NFTMarketplace.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721, Ownable {
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingIdCounter;

    event NFTListed(uint256 indexed listingId, uint256 indexed tokenId, address seller, uint256 price);
    event NFTSold(uint256 indexed listingId, uint256 indexed tokenId, address buyer, address seller, uint256 price);

    constructor() ERC721("BaseNFT", "BNFT") {}

    function listNFT(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(listings[tokenId].active == false, "Already listed");
        
        listings[tokenId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit NFTListed(listingIdCounter++, tokenId, msg.sender, price);
    }

    function buyNFT(uint256 tokenId) external payable {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Not for sale");
        require(msg.value >= listing.price, "Insufficient funds");
        
        transferFrom(listing.seller, msg.sender, tokenId);
        payable(listing.seller).transfer(listing.price);
        
        listing.active = false;
        emit NFTSold(listingIdCounter, tokenId, msg.sender, listing.seller, listing.price);
    }

    function cancelListing(uint256 tokenId) external {
        require(listings[tokenId].seller == msg.sender, "Not seller");
        listings[tokenId].active = false;
    }
}
