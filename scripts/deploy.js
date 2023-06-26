// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const owner = "0x05327Df98EbE78dcfc1A0DB5CBDdA3344DE89f12";
  const rewardsDistribution = "0x05327Df98EbE78dcfc1A0DB5CBDdA3344DE89f12";

  const rewardsToken = "0x06c9A93c08095141f0B75eA212C1733BD68d8723";
  const stakingToken = "0x06c9A93c08095141f0B75eA212C1733BD68d8723";

  const StakingRewards = await hre.ethers.getContractFactory("StakingRewards");
  const stakingRewards = await StakingRewards.deploy(owner, rewardsDistribution, rewardsToken, stakingToken);

  await stakingRewards.deployed();

  console.log(
    `Contract 'StakingRewards' deployed to ${stakingRewards.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
