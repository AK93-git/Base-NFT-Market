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
// Добавить структуру:
struct Auction {
    uint256 tokenId;
    address seller;
    uint256 startingPrice;
    uint256 reservePrice;
    uint256 duration;
    uint256 startTime;
    uint256 currentBid;
    address highestBidder;
    bool ended;
    bool active;
}

// Добавить функции:
function createAuction(
    uint256 tokenId,
    uint256 startingPrice,
    uint256 reservePrice,
    uint256 duration
) external {
    // Создание аукциона
}

function placeBid(
    uint256 tokenId,
    uint256 amount
) external payable {
    // Размещение ставки
}

function endAuction(uint256 tokenId) external {
    // Завершение аукциона
}
// Добавить структуры:
struct Rating {
    uint256 tokenId;
    address reviewer;
    uint256 score; // 1-10 scale
    string comment;
    uint256 timestamp;
    bool verifiedPurchase;
}

struct Review {
    uint256 tokenId;
    address reviewer;
    string text;
    uint256 timestamp;
    uint256 helpfulCount;
    bool verified;
}

struct NFTStats {
    uint256 totalRatings;
    uint256 averageRating;
    uint256 totalReviews;
    uint256 totalSales;
    uint256 totalVolume;
}

// Добавить маппинги:
mapping(uint256 => Rating[]) public nftRatings;
mapping(uint256 => Review[]) public nftReviews;
mapping(uint256 => NFTStats) public nftStatistics;

// Добавить события:
event RatingSubmitted(
    uint256 indexed tokenId,
    address indexed reviewer,
    uint256 score,
    string comment
);

event ReviewSubmitted(
    uint256 indexed tokenId,
    address indexed reviewer,
    string text
);

event ReviewHelpful(
    uint256 indexed tokenId,
    uint256 reviewIndex,
    address indexed voter
);

// Добавить функции:
function submitRating(
    uint256 tokenId,
    uint256 score,
    string memory comment
) external {
    require(score >= 1 && score <= 10, "Score must be between 1 and 10");
    require(ownerOf(tokenId) != msg.sender, "Creator cannot rate their own NFT");
    require(isNFTSold(tokenId), "NFT must be sold to rate");
    
    Rating memory rating = Rating({
        tokenId: tokenId,
        reviewer: msg.sender,
        score: score,
        comment: comment,
        timestamp: block.timestamp,
        verifiedPurchase: true
    });
    
    nftRatings[tokenId].push(rating);
    
    // Update statistics
    NFTStats storage stats = nftStatistics[tokenId];
    stats.totalRatings++;
    stats.averageRating = (stats.averageRating * (stats.totalRatings - 1) + score) / stats.totalRatings;
    
    emit RatingSubmitted(tokenId, msg.sender, score, comment);
}

function submitReview(
    uint256 tokenId,
    string memory text
) external {
    require(bytes(text).length > 0, "Review text cannot be empty");
    require(ownerOf(tokenId) != msg.sender, "Creator cannot review their own NFT");
    require(isNFTSold(tokenId), "NFT must be sold to review");
    
    Review memory review = Review({
        tokenId: tokenId,
        reviewer: msg.sender,
        text: text,
        timestamp: block.timestamp,
        helpfulCount: 0,
        verified: true
    });
    
    nftReviews[tokenId].push(review);
    
    // Update statistics
    NFTStats storage stats = nftStatistics[tokenId];
    stats.totalReviews++;
    
    emit ReviewSubmitted(tokenId, msg.sender, text);
}

function markReviewHelpful(
    uint256 tokenId,
    uint256 reviewIndex
) external {
    require(reviewIndex < nftReviews[tokenId].length, "Invalid review index");
    
    Review storage review = nftReviews[tokenId][reviewIndex];
    review.helpfulCount++;
    
    emit ReviewHelpful(tokenId, reviewIndex, msg.sender);
}

function getNFTRatings(uint256 tokenId) external view returns (Rating[] memory) {
    return nftRatings[tokenId];
}

function getNFTReviews(uint256 tokenId) external view returns (Review[] memory) {
    return nftReviews[tokenId];
}

function getNFTStats(uint256 tokenId) external view returns (NFTStats memory) {
    return nftStatistics[tokenId];
}

function isNFTSold(uint256 tokenId) internal view returns (bool) {
    // Implementation would check if NFT was sold
    return true;
}
    
    // Новые структуры для аукционов
    struct Auction {
        uint256 tokenId;
        address seller;
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 duration;
        uint256 startTime;
        uint256 currentBid;
        address highestBidder;
        bool ended;
        bool active;
        uint256 auctionId;
    }
    
    struct Bid {
        uint256 auctionId;
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }
    

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(address => uint256[]) public userAuctions;
    

    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address seller,
        uint256 startingPrice,
        uint256 duration
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address bidder,
        uint256 amount
    );
    
    event AuctionEnded(
        uint256 indexed auctionId,
        address winner,
        uint256 finalAmount
    );
    
    // Новые функции для аукционов
    function createAuction(
        uint256 tokenId,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 duration
    ) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(startingPrice > 0, "Starting price must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        
        uint256 auctionId = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));
        
        auctions[auctionId] = Auction({
            tokenId: tokenId,
            seller: msg.sender,
            startingPrice: startingPrice,
            reservePrice: reservePrice,
            duration: duration,
            startTime: block.timestamp,
            currentBid: 0,
            highestBidder: address(0),
            ended: false,
            active: true,
            auctionId: auctionId
        });
        
        userAuctions[msg.sender].push(auctionId);
        
        emit AuctionCreated(auctionId, tokenId, msg.sender, startingPrice, duration);
    }
    
    function placeBid(
        uint256 auctionId,
        uint256 amount
    ) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(!auction.ended, "Auction ended");
        require(block.timestamp < auction.startTime + auction.duration, "Auction expired");
        require(amount > auction.currentBid, "Bid must be higher than current bid");
        require(amount >= auction.startingPrice, "Bid must meet starting price");
        require(msg.value >= amount, "Insufficient funds");
        
        // Возврат предыдущему бидеру
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.currentBid);
        }
        
        auction.currentBid = amount;
        auction.highestBidder = msg.sender;
        
        auctionBids[auctionId].push(Bid({
            auctionId: auctionId,
            bidder: msg.sender,
            amount: amount,
            timestamp: block.timestamp
        }));
        
        emit BidPlaced(auctionId, msg.sender, amount);
    }
    
    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.startTime + auction.duration, "Auction not expired");
        require(!auction.ended, "Auction already ended");
        
        auction.ended = true;
        auction.active = false;
        
        if (auction.currentBid >= auction.reservePrice && auction.highestBidder != address(0)) {
            // Передача NFT победителю
            transferFrom(auction.seller, auction.highestBidder, auction.tokenId);
            // Передача средств продавцу
            payable(auction.seller).transfer(auction.currentBid);
            
            emit AuctionEnded(auctionId, auction.highestBidder, auction.currentBid);
        } else {
            // Возврат NFT продавцу если нет действительных ставок
            transferFrom(auction.seller, auction.seller, auction.tokenId);
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }
    
    function cancelAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(auction.seller == msg.sender, "Not seller");
        require(!auction.ended, "Auction already ended");
        
        auction.active = false;
        auction.ended = true;
        

        transferFrom(auction.seller, auction.seller, auction.tokenId);
    }
    
    function getAuctionInfo(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }
    
    function getAuctionBids(uint256 auctionId) external view returns (Bid[] memory) {
        return auctionBids[auctionId];
    }
    
    function getUserAuctions(address user) external view returns (uint256[] memory) {
        return userAuctions[user];
    }
    
    function getActiveAuctions() external view returns (uint256[] memory) {
        // Возвращает активные аукционы
        return new uint256[](0);
    }
 
function listNFT(uint256 tokenId, uint256 price) external {
    require(ownerOf(tokenId) == msg.sender, "Not owner");
    require(price > 0, "Price must be greater than 0");
    require(listings[tokenId].active == false, "Already listed");
    
    // Добавленная проверка
    require(tokenId > 0, "Invalid token ID");
    require(ownerOf(tokenId) != address(0), "Token does not exist");
    
    listings[tokenId] = Listing({
        tokenId: tokenId,
        seller: msg.sender,
        price: price,
        active: true
    });

    emit NFTListed(listingIdCounter++, tokenId, msg.sender, price);
}
}
