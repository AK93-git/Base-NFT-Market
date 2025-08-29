// base-nft-marketplace/test/nft-marketplace.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Base NFT Marketplace", function () {
  let marketplace;
  let nft;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    
    // Деплой NFT контракта
    const NFT = await ethers.getContractFactory("BaseNFT");
    nft = await NFT.deploy();
    await nft.deployed();
    
    // Деплой Marketplace контракта
    const Marketplace = await ethers.getContractFactory("NFTMarketplaceV3");
    marketplace = await Marketplace.deploy(
      250, // 2.5% platform fee
      ethers.utils.parseEther("0.001"), // 0.001 ETH minimum listing price
      1000 // 10% maximum royalty
    );
    await marketplace.deployed();
    
    // Майнинг NFT для владельца
    await nft.mint(owner.address, 1);
    await nft.mint(owner.address, 2);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await marketplace.owner()).to.equal(owner.address);
    });

    it("Should initialize with correct parameters", async function () {
      expect(await marketplace.platformFeePercentage()).to.equal(250);
      expect(await marketplace.minimumListingPrice()).to.equal(ethers.utils.parseEther("0.001"));
      expect(await marketplace.maximumRoyaltyPercentage()).to.equal(1000);
    });
  });

  describe("Listing", function () {
    it("Should create a listing", async function () {
      await nft.approve(marketplace.address, 1);
      
      await expect(marketplace.listNFT(1, ethers.utils.parseEther("0.1"), addr1.address, 500))
        .to.emit(marketplace, "NFTListed");
    });

    it("Should fail to create listing with insufficient price", async function () {
      await nft.approve(marketplace.address, 1);
      
      await expect(marketplace.listNFT(1, ethers.utils.parseEther("0.0001"), addr1.address, 500))
        .to.be.revertedWith("Price too low");
    });
  });

  describe("Buying", function () {
    beforeEach(async function () {
      await nft.approve(marketplace.address, 1);
      await marketplace.listNFT(1, ethers.utils.parseEther("0.1"), addr1.address, 500);
    });

    it("Should complete a purchase", async function () {
      await expect(marketplace.connect(addr2).buyNFT(1, { value: ethers.utils.parseEther("0.1") }))
        .to.emit(marketplace, "NFTSold");
    });
  });

  describe("Auctions", function () {
    it("Should create an auction", async function () {
      await nft.approve(marketplace.address, 1);
      
      await expect(marketplace.createAuction(1, ethers.utils.parseEther("0.05"), 
        ethers.utils.parseEther("0.1"), 3600))
        .to.emit(marketplace, "AuctionCreated");
    });
  });
});
