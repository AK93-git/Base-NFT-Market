require("dotenv").config();
const fs = require("fs");
const path = require("path");

async function main() {
  const depPath = path.join(__dirname, "..", "deployments.json");
  const deployments = JSON.parse(fs.readFileSync(depPath, "utf8"));
  const addr = deployments.contracts.NFTMarketplace;

  const [a, b] = await ethers.getSigners();
  const m = await ethers.getContractAt("NFTMarketplace", addr);

  console.log("Marketplace:", addr);

  // Mint NFT to A
  const tokenURI = process.env.TOKEN_URI || "ipfs://example";
  const tx1 = await m.connect(a).mint(a.address, tokenURI);
  const r1 = await tx1.wait();
  const tokenId = r1.events.find((e) => e.event === "Minted").args.tokenId.toString();
  console.log("Minted tokenId:", tokenId);

  // Approve + list
  await (await m.connect(a).approve(m.address, tokenId)).wait();
  const price = ethers.utils.parseEther("0.01");
  const expiresAt = 0; // or Math.floor(Date.now()/1000)+3600
  await (await m.connect(a).list(tokenId, price, expiresAt)).wait();
  console.log("Listed");

  // Buy by B
  await (await m.connect(b).buy(tokenId, { value: price })).wait();
  console.log("Bought by:", b.address);

  const owner = await m.ownerOf(tokenId);
  console.log("Owner now:", owner);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
