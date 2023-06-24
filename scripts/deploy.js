const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  console.log(
    "Account balance:",
    (await ethers.getBalance(deployer.address)).toString()
  );
  
  const token = await ethers.deployContract("UniswapCrossSwap");
  await token.waitForDeployment();

  console.log("Token address:", token.address);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
