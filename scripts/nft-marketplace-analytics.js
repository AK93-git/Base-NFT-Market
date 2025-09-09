// base-nft-marketplace/scripts/analytics.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function generateNFTAnalytics() {
  console.log("Generating analytics for Base NFT Marketplace...");
  
  const marketplaceAddress = "0x...";
  const marketplace = await ethers.getContractAt("NFTMarketplaceV3", marketplaceAddress);
  
  // Получение аналитики
  const analytics = {
    timestamp: new Date().toISOString(),
    marketplaceAddress: marketplaceAddress,
    marketStats: {},
    trendingNFTs: [],
    userActivity: {},
    revenueStats: {},
    topCollections: []
  };
  
  // Статистика рынка
  const marketStats = await marketplace.getMarketStats();
  analytics.marketStats = {
    totalListings: marketStats.totalListings.toString(),
    totalSales: marketStats.totalSales.toString(),
    totalVolume: marketStats.totalVolume.toString(),
    avgListingPrice: marketStats.avgListingPrice.toString(),
    totalUsers: marketStats.totalUsers.toString()
  };
  
  // Популярные NFT
  const trendingNFTs = await marketplace.getTrendingNFTs(5);
  analytics.trendingNFTs = trendingNFTs.map(nft => ({
    tokenId: nft.tokenId.toString(),
    seller: nft.seller,
    price: nft.price.toString(),
    salesCount: nft.salesCount.toString(),
    lastSale: nft.lastSale.toString()
  }));
  
  // Активность пользователей
  const userActivity = await marketplace.getUserActivity(10);
  analytics.userActivity = userActivity.reduce((acc, user) => {
    acc[user.user] = {
      totalListings: user.totalListings.toString(),
      totalSales: user.totalSales.toString(),
      totalPurchases: user.totalPurchases.toString()
    };
    return acc;
  }, {});
  
  // Доходы
  const revenueStats = await marketplace.getRevenueStats();
  analytics.revenueStats = {
    totalRevenue: revenueStats.totalRevenue.toString(),
    platformFees: revenueStats.platformFees.toString(),
    sellerEarnings: revenueStats.sellerEarnings.toString(),
    avgTransactionValue: revenueStats.avgTransactionValue.toString()
  };
  
  // Топ коллекции
  const topCollections = await marketplace.getTopCollections(5);
  analytics.topCollections = topCollections.map(collection => ({
    collectionId: collection.collectionId,
    name: collection.name,
    totalItems: collection.totalItems.toString(),
    totalVolume: collection.totalVolume.toString(),
    avgPrice: collection.avgPrice.toString()
  }));
  
  // Сохранение аналитики
  const fileName = `analytics-${Date.now()}.json`;
  fs.writeFileSync(`./analytics/${fileName}`, JSON.stringify(analytics, null, 2));
  
  console.log("NFT analytics generated successfully!");
  console.log("File saved:", fileName);
}

generateNFTAnalytics()
  .catch(error => {
    console.error("Analytics error:", error);
    process.exit(1);
  });
