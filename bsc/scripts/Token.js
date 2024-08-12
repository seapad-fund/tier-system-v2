// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers} = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // We get the contract to deploy
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy("Seapad Test", "SPT", 10000000000);
  await token.waitForDeployment();

  // const TokenB = await ethers.getContractFactory("Token");
  // const tokenB = await TokenB.deploy("TokenB", "TKB", 10000);
  // await tokenB.waitForDeployment();

  console.log("Token deployed to: ", await token.getAddress());
  console.log("Token decimals: ", await token.decimals());
  // console.log("Token B deployed to: ", await tokenB.getAddress());

  // Write contract addresses to file
  let data = `const TOKEN_ADDRESS = "${await token.getAddress()}";\n\nmodule.exports = {TOKEN_ADDRESS};`;
  fs.writeFileSync("token-contract-address.js", data);
  console.log(
    "\nContract addresses have been write to token-contract-address.js\n"
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
