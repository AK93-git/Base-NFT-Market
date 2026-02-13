const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const name = process.env.NFT_NAME || "BaseNFT";
  const symbol = process.env.NFT_SYMBOL || "BNFT";

  const royaltyReceiver = process.env.ROYALTY_RECEIVER || deployer.address;
  const royaltyFeeNumerator = Number(process.env.ROYALTY_FEE || "500"); // 5%

  const feeRecipient = process.env.FEE_RECIPIENT || deployer.address;
  const feeBps = Number(process.env.FEE_BPS || "250"); // 2.5%

  const Factory = await ethers.getContractFactory("NFTMarketplace");
  const c = await Factory.deploy(
    name,
    symbol,
    royaltyReceiver,
    royaltyFeeNumerator,
    feeRecipient,
    feeBps
  );
  await c.deployed();

  console.log("NFTMarketplace:", c.address);

  const out = {
    network: hre.network.name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    contracts: {
      NFTMarketplace: c.address
    }
  };

  const outPath = path.join(__dirname, "..", "deployments.json");
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log("Saved:", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
