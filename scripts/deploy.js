// base-nft-marketplace/scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying NFT Marketplace...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Получаем адрес контракта NFT
  const NFTContract = await ethers.getContractFactory("NFTMarketplaceV2");
  
  // Деплой с параметрами: platformFee, minimumPrice, maxRoyalty
  const marketplace = await NFTContract.deploy(
    250, // 2.5% platform fee
    ethers.utils.parseEther("0.001"), // 0.001 ETH minimum listing price
    1000 // 10% maximum royalty
  );

  await marketplace.deployed();

  console.log("NFT Marketplace deployed to:", marketplace.address);
  
  // Сохраняем адрес для дальнейшего использования
  const fs = require("fs");
  const data = {
    marketplace: marketplace.address,
    owner: deployer.address
  };
  
  fs.writeFileSync("./config/deployment.json", JSON.stringify(data, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
