// base-nft-marketplace/scripts/backup.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function backupMarketplace() {
  console.log("Backing up Base NFT Marketplace data...");
  
  const marketplaceAddress = "0x...";
  const marketplace = await ethers.getContractAt("NFTMarketplaceV3", marketplaceAddress);
  
  // Получение всех листингов
  const listings = await marketplace.getAllListings();
  console.log("Retrieved listings:", listings.length);
  
  // Получение всех продаж
  const sales = await marketplace.getAllSales();
  console.log("Retrieved sales:", sales.length);
  
  // Получение статистики
  const stats = await marketplace.getMarketplaceStats();
  
  // Создание резервной копии
  const backupData = {
    timestamp: new Date().toISOString(),
    marketplaceAddress: marketplaceAddress,
    listings: listings,
    sales: sales,
    stats: stats,
    network: network.name
  };
  
  // Сохранение резервной копии
  const backupFileName = `backup-marketplace-${Date.now()}.json`;
  fs.writeFileSync(`./backups/${backupFileName}`, JSON.stringify(backupData, null, 2));
  
  console.log(`Backup created: ${backupFileName}`);
  
  // Создание резервной копии в формате CSV
  const csvData = "TokenId,Seller,Price,Status\n";
  listings.forEach(listing => {
    csvData += `${listing.tokenId},${listing.seller},${listing.price},${listing.active}\n`;
  });
  
  fs.writeFileSync(`./backups/marketplace-listings-${Date.now()}.csv`, csvData);
  console.log("CSV backup created");
}

backupMarketplace()
  .catch(error => {
    console.error("Backup error:", error);
    process.exit(1);
  });
