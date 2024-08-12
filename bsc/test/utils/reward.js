const {toBigInt, toNumber} = require("ethers");

const ONE_YEAR = 31536000;

const rewardCalculation = (
  timestamp,
  lastUpdatedTime,
  stakedAmount,
  apy,
  lockPeriod
) => {
  let timeElapsed = timestamp - lastUpdatedTime;
  if (timeElapsed > lockPeriod) {
    timeElapsed = lockPeriod;
  }
  let baseReward =
    (stakedAmount * apy.rate * timeElapsed) /
    (toBigInt(10 ** toNumber(apy.decimals)) * toBigInt(ONE_YEAR));

  return baseReward;
};

module.exports = {rewardCalculation};
