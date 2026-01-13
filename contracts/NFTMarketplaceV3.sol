// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketplaceV2 is ERC721, Ownable, ReentrancyGuard {
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
        uint256 royalty;
        uint256 createdAt;
    }

    struct Bid {
        uint256 tokenId;
        address bidder;
        uint256 amount;
        uint256 createdAt;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Bid[]) public bids;
    mapping(address => uint256[]) public userListings;
    mapping(address => uint256[]) public userBids;
    
    uint256 public listingFee;
    uint256 public bidFee;
    address public feeCollector;
    
    // Events
    event NFTListed(uint256 indexed listingId, uint256 indexed tokenId, address seller, uint256 price, uint256 royalty);
    event NFTSold(uint256 indexed listingId, uint256 indexed tokenId, address buyer, address seller, uint256 price);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    event BidAccepted(uint256 indexed tokenId, address bidder, uint256 amount);
    event ListingCancelled(uint256 indexed listingId, uint256 indexed tokenId);
    event FeeUpdated(uint256 newListingFee, uint256 newBidFee, address newFeeCollector);

    constructor() ERC721("BaseNFT", "BNFT") {
        listingFee = 0;
        bidFee = 0;
        feeCollector = address(0);
    }

    function setFees(uint256 _listingFee, uint256 _bidFee, address _feeCollector) external onlyOwner {
        listingFee = _listingFee;
        bidFee = _bidFee;
        feeCollector = _feeCollector;
        emit FeeUpdated(_listingFee, _bidFee, _feeCollector);
    }

    function listNFT(uint256 tokenId, uint256 price, uint256 royalty) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(price > 0, "Price must be greater than 0");
        require(royalty <= 10000, "Royalty too high"); // 100% max
        
        // Transfer NFT to marketplace
        transferFrom(msg.sender, address(this), tokenId);
        
        uint256 listingId = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));
        
        listings[listingId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true,
            royalty: royalty,
            createdAt: block.timestamp
        });
        
        userListings[msg.sender].push(listingId);
        
        emit NFTListed(listingId, tokenId, msg.sender, price, royalty);
    }

    function buyNFT(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient funds");
        
        // Calculate fees
        uint256 feeAmount = (listing.price * listingFee) / 10000;
        uint256 sellerAmount = listing.price - feeAmount;
        
        // Transfer fees
        if (feeAmount > 0 && feeCollector != address(0)) {
            payable(feeCollector).transfer(feeAmount);
        }
        
        // Transfer remaining to seller
        payable(listing.seller).transfer(sellerAmount);
        
        // Transfer NFT to buyer
        transferFrom(address(this), msg.sender, listing.tokenId);
        
        // Mark listing as inactive
        listing.active = false;
        
        emit NFTSold(listingId, listing.tokenId, msg.sender, listing.seller, listing.price);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not seller");
        
        // Return NFT to seller
        transferFrom(address(this), listing.seller, listing.tokenId);
        
        // Mark listing as inactive
        listing.active = false;
        
        emit ListingCancelled(listingId, listing.tokenId);
    }

    function placeBid(uint256 tokenId, uint256 amount) external payable nonReentrant {
        require(amount > 0, "Bid amount must be greater than 0");
        require(msg.value >= amount, "Insufficient funds");
        
        // Store bid
        uint256 bidId = bids[tokenId].length;
        bids[tokenId].push(Bid({
            tokenId: tokenId,
            bidder: msg.sender,
            amount: amount,
            createdAt: block.timestamp,
            active: true
        }));
        
        userBids[msg.sender].push(tokenId);
        
        emit BidPlaced(tokenId, msg.sender, amount);
    }

    function acceptBid(uint256 tokenId, uint256 bidId) external nonReentrant {
        require(msg.sender == ownerOf(tokenId), "Not owner");
        
        Bid storage bid = bids[tokenId][bidId];
        require(bid.active, "Bid not active");
        require(bid.amount > 0, "Invalid bid amount");
        
        // Calculate fees
        uint256 feeAmount = (bid.amount * bidFee) / 10000;
        uint256 sellerAmount = bid.amount - feeAmount;
        
        // Transfer fees
        if (feeAmount > 0 && feeCollector != address(0)) {
            payable(feeCollector).transfer(feeAmount);
        }
        
        // Transfer remaining to seller
        payable(msg.sender).transfer(sellerAmount);
        
        // Transfer NFT to bidder
        transferFrom(address(this), bid.bidder, tokenId);
        
       
        bid.active = false;
        
        emit BidAccepted(tokenId, bid.bidder, bid.amount);
    }

    function getListingInfo(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getBidsForToken(uint256 tokenId) external view returns (Bid[] memory) {
        return bids[tokenId];
    }

    function getUserListings(address user) external view returns (uint256[] memory) {
        return userListings[user];
    }

    function getUserBids(address user) external view returns (uint256[] memory) {
        return userBids[user];
    }

    function getActiveListings() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < 1000000; i++) {
            if (listings[i].active) {
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < 1000000; i++) {
            if (listings[i].active) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }
}
