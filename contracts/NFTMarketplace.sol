// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 

contract NFTMarketplace is ERC721URIStorage, ERC2981, Ownable, ReentrancyGuard {
    struct Listing {
        address seller;
        uint256 price;
        uint256 expiresAt; // 0 = no expiry
    }

    uint256 public nextTokenId = 1;
    mapping(uint256 => Listing) public listings;

    address public feeRecipient;
    uint96 public feeBps; // 100 = 1%, max 1000 = 10%

    event Minted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price, uint256 expiresAt);
    event Unlisted(address indexed seller, uint256 indexed tokenId);
    event ListingPriceUpdated(address indexed seller, uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event Sold(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price,
        uint256 platformFee,
        address royaltyReceiver,
        uint256 royaltyAmount
    );

    event FeeParamsUpdated(address feeRecipient, uint96 feeBps);
    event DefaultRoyaltyUpdated(address receiver, uint96 feeNumerator);
    event Burned(uint256 indexed tokenId);

    constructor(
        string memory name_,
        string memory symbol_,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address feeRecipient_,
        uint96 feeBps_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(royaltyReceiver != address(0), "royalty receiver=0");
        require(royaltyFeeNumerator <= 2000, "royalty too high");

        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
        _setFeeParams(feeRecipient_, feeBps_);
    }

    function mint(address to, string calldata uri) external returns (uint256 tokenId) {
        require(to != address(0), "to=0");

        tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit Minted(to, tokenId, uri);
    }

    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "not approved");

        if (listings[tokenId].seller != address(0)) {
            delete listings[tokenId];
        }

        _burn(tokenId);
        _resetTokenRoyalty(tokenId);

        emit Burned(tokenId);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        require(receiver != address(0), "receiver=0");
        require(feeNumerator <= 2000, "royalty too high");

        _setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltyUpdated(receiver, feeNumerator);
    }

    function setFeeParams(address feeRecipient_, uint96 feeBps_) external onlyOwner {
        _setFeeParams(feeRecipient_, feeBps_);
    }

    function _setFeeParams(address feeRecipient_, uint96 feeBps_) internal {
        require(feeRecipient_ != address(0), "feeRecipient=0");
        require(feeBps_ <= 1000, "fee too high");

        feeRecipient = feeRecipient_;
        feeBps = feeBps_;

        emit FeeParamsUpdated(feeRecipient_, feeBps_);
    }

    function list(uint256 tokenId, uint256 price, uint256 expiresAt) external {
        require(ownerOf(tokenId) == msg.sender, "not owner");
        require(price > 0, "price=0");
        require(
            getApproved(tokenId) == address(this) || isApprovedForAll(msg.sender, address(this)),
            "market not approved"
        );

        if (expiresAt != 0) {
            require(expiresAt > block.timestamp, "expiresAt in past");
        }

        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            expiresAt: expiresAt
        });

        emit Listed(msg.sender, tokenId, price, expiresAt);
    }

    function updateListingPrice(uint256 tokenId, uint256 newPrice) external {
        Listing storage l = listings[tokenId];
        require(l.seller != address(0), "not listed");
        require(l.seller == msg.sender, "not seller");
        require(newPrice > 0, "price=0");

        uint256 oldPrice = l.price;
        l.price = newPrice;

        emit ListingPriceUpdated(msg.sender, tokenId, oldPrice, newPrice);
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
        require(l.seller != msg.sender, "seller=buyer");
        require(msg.value == l.price, "wrong value");

        if (l.expiresAt != 0) {
            require(block.timestamp <= l.expiresAt, "listing expired");
        }

        delete listings[tokenId];

        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, msg.value);
        uint256 platformFee = (msg.value * feeBps) / 10000;
        uint256 sellerAmount = msg.value - royaltyAmount - platformFee;

        _safeTransfer(l.seller, msg.sender, tokenId, "");

        if (platformFee > 0) {
            (bool feeOk, ) = payable(feeRecipient).call{value: platformFee}("");
            require(feeOk, "fee transfer failed");
        }

        if (royaltyAmount > 0) {
            (bool royaltyOk, ) = payable(royaltyReceiver).call{value: royaltyAmount}("");
            require(royaltyOk, "royalty transfer failed");
        }

        (bool sellerOk, ) = payable(l.seller).call{value: sellerAmount}("");
        require(sellerOk, "seller transfer failed");

        emit Sold(msg.sender, l.seller, tokenId, msg.value, platformFee, royaltyReceiver, royaltyAmount);
    }

    function rescueETH(address to) external onlyOwner {
        require(to != address(0), "zero");

        uint256 bal = address(this).balance;
        require(bal > 0, "no ETH");

        (bool ok, ) = payable(to).call{value: bal}("");
        require(ok, "transfer failed");
    }

    function rescueERC20(address token, address to) external onlyOwner {
        require(token != address(0) && to != address(0), "zero");

        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0, "no tokens");

        bool ok = IERC20(token).transfer(to, bal);
        require(ok, "transfer failed");
    }

    function getListing(uint256 tokenId)
        external
        view
        returns (
            address seller,
            uint256 price,
            uint256 expiresAt,
            bool active
        )
    {
        Listing memory l = listings[tokenId];
        seller = l.seller;
        price = l.price;
        expiresAt = l.expiresAt;
        active = l.seller != address(0) && (l.expiresAt == 0 || block.timestamp <= l.expiresAt);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
