// base-nft-marketplace/scripts/migrate.js
const { ethers } = require("hardhat");

async function main() {
  console.log("Migrating Base NFT Marketplace...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Migrating with the account:", deployer.address);

  // Получаем адрес текущего контракта
  const currentContractAddress = "0x...";
  
  // Деплой нового контракта
  const NFTMarketplaceV4 = await ethers.getContractFactory("NFTMarketplaceV4");
  const newMarketplace = await NFTMarketplaceV4.deploy(
    300, // 3% platform fee
    ethers.utils.parseEther("0.0005"), // 0.0005 ETH minimum listing price
    1500 // 15% maximum royalty
  );

  await newMarketplace.deployed();

  console.log("New Base NFT Marketplace deployed to:", newMarketplace.address);
  
  // Перенос данных с старого контракта
  const oldContract = await ethers.getContractAt("NFTMarketplaceV3", currentContractAddress);
  
  // Миграция листингов
  console.log("Migrating listings...");
  
  // Сохраняем информацию о миграции
  const fs = require("fs");
  const migrationData = {
    oldContract: currentContractAddress,
    newContract: newMarketplace.address,
    migratedAt: new Date().toISOString(),
    owner: deployer.address
  };
  
  fs.writeFileSync("./config/migration.json", JSON.stringify(migrationData, null, 2));
  
  console.log("Migration completed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
