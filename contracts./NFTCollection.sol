// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTCollection is ERC721, Ownable {
    struct Collection {
        string name;
        string description;
        address creator;
        uint256 royaltyPercentage;
        uint256 totalNFTs;
        bool active;
    }
    
    struct CollectionNFT {
        uint256 tokenId;
        address collectionId;
        uint256 royaltyPercentage;
    }
    
    mapping(address => Collection) public collections;
    mapping(uint256 => CollectionNFT) public collectionNFTs;
    mapping(address => uint256[]) public userCollections;
    
    event CollectionCreated(address indexed collectionId, string name, address creator, uint256 royalty);
    event NFTAddedToCollection(uint256 indexed tokenId, address indexed collectionId, uint256 royalty);
    event CollectionUpdated(address indexed collectionId, string name, uint256 royalty);
    
    constructor() ERC721("BaseNFTCollection", "BNFTC") {}
    
    function createCollection(
        string memory name,
        string memory description,
        uint256 royaltyPercentage
    ) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(royaltyPercentage <= 10000, "Royalty too high");
        
        address collectionId = address(uint160(uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp)))));
        
        collections[collectionId] = Collection({
            name: name,
            description: description,
            creator: msg.sender,
            royaltyPercentage: royaltyPercentage,
            totalNFTs: 0,
            active: true
        });
        
        userCollections[msg.sender].push(collectionId);
        
        emit CollectionCreated(collectionId, name, msg.sender, royaltyPercentage);
    }
    
    function addNFTToCollection(
        uint256 tokenId,
        address collectionId,
        uint256 royaltyPercentage
    ) external {
        require(collections[collectionId].creator == msg.sender, "Not collection creator");
        require(royaltyPercentage <= 10000, "Royalty too high");
        require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
        
        collectionNFTs[tokenId] = CollectionNFT({
            tokenId: tokenId,
            collectionId: collectionId,
            royaltyPercentage: royaltyPercentage
        });
        
        collections[collectionId].totalNFTs++;
        
        emit NFTAddedToCollection(tokenId, collectionId, royaltyPercentage);
    }
    
    function updateCollection(
        address collectionId,
        string memory name,
        uint256 royaltyPercentage
    ) external {
        require(collections[collectionId].creator == msg.sender, "Not collection creator");
        require(royaltyPercentage <= 10000, "Royalty too high");
        
        collections[collectionId].name = name;
        collections[collectionId].royaltyPercentage = royaltyPercentage;
        
        emit CollectionUpdated(collectionId, name, royaltyPercentage);
    }
    
    function getCollectionInfo(address collectionId) external view returns (Collection memory) {
        return collections[collectionId];
    }
    
    function getCollectionNFTs(address collectionId) external view returns (uint256[] memory) {
        // Реализация в будущем
        return new uint256[](0);
    }
}
