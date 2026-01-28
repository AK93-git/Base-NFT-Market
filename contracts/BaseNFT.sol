// base-nft-marketplace/contracts/BaseNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BaseNFT is ERC721 {
    uint256 public nextTokenId;
    
    constructor() ERC721("BaseNFT", "BNFT") {}
    
    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
        nextTokenId++;
    }
    
    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
        nextTokenId++;
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked("ipfs://", uint256(tokenId).toString()));
    }
    
    function getTotalSupply() public view returns (uint256) {
        return nextTokenId;
    }
}
