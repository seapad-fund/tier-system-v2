const {ethers, upgrades} = require("hardhat");
const artifacts = require("../artifacts/contracts/Staking.sol/Staking.json");
const BSC_MANAGER_PRIVATE_KEY = process.env.BSC_MANAGER_PRIVATE_KEY;

async function main() {
  const [deployer] = await ethers.getSigners();
  const abi = artifacts.abi;
  const stakingAddress = "0x47CEB7E6259a2d39fF9Cf87e4f9c7F39207bc776";
  const provider = new ethers.JsonRpcProvider(
    "https://data-seed-prebsc-1-s1.binance.org:8545/"
  );
  const signer = new ethers.Wallet(BSC_MANAGER_PRIVATE_KEY, provider);
  const staking = new ethers.Contract(stakingAddress, abi, signer);
  const minStakeAmount = await staking.minStakeAmount();
  console.log(minStakeAmount);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
