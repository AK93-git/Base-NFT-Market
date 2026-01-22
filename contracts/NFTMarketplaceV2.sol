// base-nft-marketplace/contracts/NFTMarketplaceV2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NFTMarketplaceV2 is ERC721, Ownable, ReentrancyGuard {
    using Address for address payable;

    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
        address royaltyRecipient;
        uint256 royaltyPercentage;
        uint256 createdAt;
    }

    struct Sale {
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 price;
        uint256 royaltyAmount;
        uint256 platformFee;
        uint256 timestamp;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256[]) public sellerSales;
    

    uint256 public platformFeePercentage;
    uint256 public minimumListingPrice;
    uint256 public maximumRoyaltyPercentage;
    uint256 public nextSaleId;
    uint256 public nextListingId;
    
   
    uint256 public totalVolume;
    uint256 public totalTrades;
    
   
    event NFTListed(
        uint256 indexed listingId, 
        uint256 indexed tokenId, 
        address seller, 
        uint256 price,
        uint256 royaltyPercentage,
        uint256 createdAt
    );
    
    event NFTSold(
        uint256 indexed saleId,
        uint256 indexed tokenId, 
        address buyer, 
        address seller, 
        uint256 price, 
        uint256 royaltyAmount,
        uint256 platformFee,
        uint256 timestamp
    );
    
    event ListingCancelled(uint256 indexed listingId, uint256 indexed tokenId, address seller);
    event FeeUpdated(uint256 newFee);
    event PriceUpdated(uint256 indexed listingId, uint256 newPrice);
    event RoyaltyUpdated(uint256 indexed listingId, address newRecipient, uint256 newPercentage);

    constructor(
        uint256 _platformFeePercentage,
        uint256 _minimumListingPrice,
        uint256 _maximumRoyaltyPercentage
    ) ERC721("BaseNFT", "BNFT") {
        platformFeePercentage = _platformFeePercentage;
        minimumListingPrice = _minimumListingPrice;
        maximumRoyaltyPercentage = _maximumRoyaltyPercentage;
    }
    
    // Функция для установки комиссии платформы
    function setPlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10000, "Fee too high"); // Maximum 100%
        platformFeePercentage = newFee;
        emit FeeUpdated(newFee);
    }
    

    function setMinimumListingPrice(uint256 newPrice) external onlyOwner {
        minimumListingPrice = newPrice;
    }
    

    function setMaximumRoyaltyPercentage(uint256 newPercentage) external onlyOwner {
        require(newPercentage <= 10000, "Royalty too high"); // Maximum 100%
        maximumRoyaltyPercentage = newPercentage;
    }
    
    // Создание листинга NFT
    function listNFT(
        uint256 tokenId,
        uint256 price,
        address royaltyRecipient,
        uint256 royaltyPercentage
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(listings[tokenId].active == false, "Already listed");
        require(price >= minimumListingPrice, "Price too low");
        require(royaltyPercentage <= maximumRoyaltyPercentage, "Royalty too high");
        require(royaltyRecipient != address(0), "Invalid royalty recipient");
        
        listings[tokenId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true,
            royaltyRecipient: royaltyRecipient,
            royaltyPercentage: royaltyPercentage,
            createdAt: block.timestamp
        });
        
        emit NFTListed(
            nextListingId++,
            tokenId,
            msg.sender,
            price,
            royaltyPercentage,
            block.timestamp
        );
    }
    
    // Покупка NFT
    function buyNFT(uint256 tokenId) external payable nonReentrant {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Not for sale");
        require(msg.value >= listing.price, "Insufficient funds");
        
        // Расчет комиссий
        uint256 platformFee = (listing.price * platformFeePercentage) / 10000;
        uint256 royaltyAmount = (listing.price * listing.royaltyPercentage) / 10000;
        uint256 sellerAmount = listing.price - platformFee - royaltyAmount;
        
        // Перевод средств
        payable(listing.seller).sendValue(sellerAmount);
        payable(owner()).sendValue(platformFee);
        payable(listing.royaltyRecipient).sendValue(royaltyAmount);
        
        // Передача NFT
        transferFrom(listing.seller, msg.sender, tokenId);
        
        // Отметить листинг как завершенный
        listing.active = false;
        
        // Записать продажу
        uint256 saleId = nextSaleId++;
        sales[saleId] = Sale({
            tokenId: tokenId,
            buyer: msg.sender,
            seller: listing.seller,
            price: listing.price,
            royaltyAmount: royaltyAmount,
            platformFee: platformFee,
            timestamp: block.timestamp
        });
        
        sellerSales[listing.seller].push(saleId);
        
        // Обновить статистику
        totalVolume += listing.price;
        totalTrades++;
        
        emit NFTSold(
            saleId,
            tokenId,
            msg.sender,
            listing.seller,
            listing.price,
            royaltyAmount,
            platformFee,
            block.timestamp
        );
    }
    
    // Отмена листинга
    function cancelListing(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Not listed");
        
        listing.active = false;
        emit ListingCancelled(listing.tokenId, tokenId, msg.sender);
    }
    
    // Обновление цены листинга
    function updateListingPrice(uint256 tokenId, uint256 newPrice) external {
        Listing storage listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Not active");
        require(newPrice >= minimumListingPrice, "Price too low");
        
        listing.price = newPrice;
        emit PriceUpdated(listing.tokenId, newPrice);
    }
    
    // Обновление роялти
    function updateRoyaltyInfo(
        uint256 tokenId,
        address newRecipient,
        uint256 newPercentage
    ) external {
        Listing storage listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Not active");
        require(newPercentage <= maximumRoyaltyPercentage, "Royalty too high");
        require(newRecipient != address(0), "Invalid recipient");
        
        listing.royaltyRecipient = newRecipient;
        listing.royaltyPercentage = newPercentage;
        emit RoyaltyUpdated(listing.tokenId, newRecipient, newPercentage);
    }
    
    // Получение информации о продаже
    function getSaleInfo(uint256 saleId) external view returns (Sale memory) {
        return sales[saleId];
    }
    
    // Получение статистики продаж
    function getMarketplaceStats() external view returns (
        uint256 volume,
        uint256 trades,
        uint256 totalListings,
        uint256 activeListings
    ) {
        uint256 active = 0;
        for (uint256 i = 0; i < type(uint256).max; i++) {
            if (listings[i].active) active++;
        }
        return (totalVolume, totalTrades, i, active);
    }
    
    // Получение истории продаж продавца
    function getSellerSales(address seller) external view returns (uint256[] memory) {
        return sellerSales[seller];
    }
    
    // Получение информации о листинге
    function getListingInfo(uint256 tokenId) external view returns (Listing memory) {
        return listings[tokenId];
    }
}
