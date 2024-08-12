// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers, upgrades} = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Upgrading V2
  const StakingV2 = await ethers.getContractFactory("StakingV2");
  const stakingInstance = await upgrades.upgradeProxy(
    "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
    StakingV2
  );

  console.log("Staking V2 deployed to: ", stakingInstance.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
