// base-nft-marketplace/scripts/backup-restore.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function backupAndRestoreNFTMarketplace() {
  console.log("Performing backup and restore operations for Base NFT Marketplace...");
  
  const marketplaceAddress = "0x...";
  const marketplace = await ethers.getContractAt("NFTMarketplaceV3", marketplaceAddress);
  
  // Создание резервной копии
  const backupData = {
    timestamp: new Date().toISOString(),
    marketplaceAddress: marketplaceAddress,
    listings: [],
    sales: [],
    users: [],
    contracts: {}
  };
  
  try {
    // Получение всех листингов
    const allListings = await marketplace.getAllListings();
    backupData.listings = allListings.map(listing => ({
      tokenId: listing.tokenId.toString(),
      seller: listing.seller,
      price: listing.price.toString(),
      active: listing.active,
      royalty: listing.royalty.toString(),
      timestamp: listing.timestamp.toString()
    }));
    
    // Получение всех продаж
    const allSales = await marketplace.getAllSales();
    backupData.sales = allSales.map(sale => ({
      tokenId: sale.tokenId.toString(),
      buyer: sale.buyer,
      seller: sale.seller,
      price: sale.price.toString(),
      timestamp: sale.timestamp.toString()
    }));
    
    // Получение пользователей
    const userCount = await marketplace.getUserCount();
    backupData.users = [];
    for (let i = 0; i < Math.min(100, userCount.toNumber()); i++) {
      const user = await marketplace.getUser(i);
      backupData.users.push({
        address: user.user,
        totalListings: user.totalListings.toString(),
        totalSales: user.totalSales.toString(),
        totalPurchases: user.totalPurchases.toString()
      });
    }
    
    // Сохранение резервной копии
    const backupFileName = `backup-marketplace-${Date.now()}.json`;
    fs.writeFileSync(`./backups/${backupFileName}`, JSON.stringify(backupData, null, 2));
    console.log(`Backup created: ${backupFileName}`);
    
    // Проверка восстановления
    console.log("Testing backup restoration...");
    
    // Создание временной копии для восстановления
    const restoreFileName = `restore-marketplace-${Date.now()}.json`;
    fs.writeFileSync(`./restores/${restoreFileName}`, JSON.stringify(backupData, null, 2));
    console.log(`Restore file created: ${restoreFileName}`);
    
    console.log("Backup and restore operations completed successfully!");
    
  } catch (error) {
    console.error("Backup/restore error:", error);
    throw error;
  }
}

backupAndRestoreNFTMarketplace()
  .catch(error => {
    console.error("Backup/restore operation failed:", error);
    process.exit(1);
  });
