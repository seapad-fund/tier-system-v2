// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers, upgrades} = require("hardhat");
const fs = require("fs");
const {WALLETS} = require("../consts/wallet");
const {TOKEN} = require("../consts/token");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploying V1
  const Staking = await ethers.getContractFactory("Staking");
  const stakingInstance = await upgrades.deployProxy(Staking, [
    TOKEN.DEMO_TOKEN,
    TOKEN.DEMO_TOKEN,
    WALLETS.TREASURY,
    WALLETS.MANAGER,
    WALLETS.PROVIDER,
    2,
    WALLETS.WITHDRAW,
  ]);
  await stakingInstance.waitForDeployment();

  console.log(
    "Staking contract deployed to: ",
    await stakingInstance.getAddress()
  );

  // Write contract addresses to file
  let data = `const STAKING_ADDRESS = "${await stakingInstance.getAddress()}";\n\nmodule.exports = {STAKING_ADDRESS};`;
  fs.writeFileSync("contract-address.js", data);
  console.log("\nContract addresses have been write to contract-address.js\n");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
