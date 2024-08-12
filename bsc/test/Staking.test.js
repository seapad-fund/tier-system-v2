const {ethers} = require("hardhat");
const {expect} = require("chai");
const {parseEther, toBigInt, parseUnits} = require("ethers");
const {rewardCalculation} = require("./utils/reward");
const {zeroAddress} = require("../consts/wallet");

describe("Staking", function () {
  let staking;
  let stakingToken;
  let rewardsToken;
  let owner,
    user1,
    user2,
    treasury1,
    treasury2,
    treasury3,
    manager1,
    provider1,
    withdrawWallet1,
    withdrawWallet2,
    treasury4;

  const TIME = {
    ONE_HOUR: 3600,
    ONE_DAY: 86400,
    ONE_YEAR: 31536000,
  };

  const MULTISIG_TYPE = {
    WITHDRAW: ethers.keccak256(ethers.toUtf8Bytes("WITHDRAW")),
    TREASURY_ROLE: ethers.keccak256(ethers.toUtf8Bytes("TREASURY_ROLE")),
    CHANGE_WALLET: ethers.keccak256(ethers.toUtf8Bytes("CHANGE_WALLET")),
  };

  const ROLE = {
    TREASURY: ethers.keccak256(ethers.toUtf8Bytes("TREASURY")),
    MANAGER: ethers.keccak256(ethers.toUtf8Bytes("MANAGER")),
    PROVIDER: ethers.keccak256(ethers.toUtf8Bytes("PROVIDER")),
  };

  const convertDecimals = (amount, unit = 9) => {
    return parseUnits(amount, unit);
  };

  before(async function () {
    [
      owner,
      user1,
      user2,
      treasury1,
      treasury2,
      treasury3,
      manager1,
      provider1,
      withdrawWallet1,
      withdrawWallet2,
      treasury4,
    ] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    stakingToken = await Token.deploy("TokenA", "TKA", 100000000000);
    rewardsToken = await Token.deploy("TokenB", "TKB", 200000000000);
    await stakingToken.waitForDeployment();
    await rewardsToken.waitForDeployment();
    let stakingAddress = await stakingToken.getAddress();
    let rewardAddress = await rewardsToken.getAddress();

    //transfer staking/reward token to accounts
    await stakingToken
      .connect(owner)
      .transfer(user1.address, convertDecimals("100000"));
    await stakingToken
      .connect(owner)
      .transfer(user2.address, convertDecimals("100000"));
    await stakingToken
      .connect(owner)
      .transfer(manager1.address, convertDecimals("100000"));
    await stakingToken
      .connect(owner)
      .transfer(provider1.address, convertDecimals("100000"));

    await rewardsToken
      .connect(owner)
      .transfer(user1.address, convertDecimals("100000"));
    await rewardsToken
      .connect(owner)
      .transfer(user2.address, convertDecimals("100000"));
    await rewardsToken
      .connect(owner)
      .transfer(manager1.address, convertDecimals("100000"));
    await rewardsToken
      .connect(owner)
      .transfer(provider1.address, convertDecimals("100000"));

    const Staking = await ethers.getContractFactory("Staking");
    staking = await Staking.deploy();
    await staking.waitForDeployment();
    await staking.initialize(
      stakingAddress,
      rewardAddress,
      [treasury1.address, treasury2.address, treasury3.address],
      [manager1.address],
      [provider1.address],
      2,
      withdrawWallet1
    );
  });

  describe("Deployment", function () {
    it("initial state", async function () {
      let stakingAddress = await staking.getAddress();
      const stakingPoolStakingBalance = await stakingToken.balanceOf(
        stakingAddress
      );
      const stakingPooRewardBalance = await rewardsToken.balanceOf(
        stakingAddress
      );
      const user1StakingBalance = await stakingToken.balanceOf(user1.address);
      const user2StakingBalance = await stakingToken.balanceOf(user2.address);

      expect(stakingPoolStakingBalance).to.equal(0);
      expect(stakingPooRewardBalance).to.equal(0);
      expect(user1StakingBalance).to.equal(convertDecimals("100000"));
      expect(user2StakingBalance).to.equal(convertDecimals("100000"));
      expect();
    });
  });

  describe("Create new staking pool", async function () {
    const poolIndex = 4;

    before(async function () {
      await staking.connect(owner).createStakingPool(5, 0, TIME.ONE_DAY);
    });

    it("should revert when create with wrong settings", async function () {
      await expect(
        staking.connect(owner).createStakingPool(0, 0, TIME.ONE_DAY)
      ).to.be.revertedWith("StakingPool: APY cannot be zero");
    });

    it("should have correct pool settings", async function () {
      let createdPool = await staking.pools(poolIndex);
      expect(createdPool.lockPeriod).to.equal(TIME.ONE_DAY);
      expect(createdPool.apy.rate).to.equal(5);
      expect(createdPool.apy.decimals).to.equal(0);
    });

    it("can be paused", async function () {
      await staking.connect(manager1).pausePool(poolIndex);
      let createdPool = await staking.pools(poolIndex);
      expect(createdPool.paused).to.equal(true);
    });

    it("can be unpaused", async function () {
      await staking.connect(manager1).unpausePool(poolIndex);
      let createdPool = await staking.pools(poolIndex);
      expect(createdPool.paused).to.equal(false);
    });

    it("should have correct settings when change", async function () {
      await staking
        .connect(owner)
        .updateStakingPool(
          poolIndex,
          TIME.ONE_DAY * 2,
          convertDecimals("1"),
          convertDecimals("1")
        );
      let createdPool = await staking.pools(poolIndex);
      expect(createdPool.lockPeriod).to.equal(TIME.ONE_DAY * 2);
      expect(createdPool.apy.decimals).to.equal(convertDecimals("1"));
      expect(createdPool.apy.rate).to.equal(convertDecimals("1"));
    });

    it("should revert when update with wrong settings", async function () {
      await expect(
        staking
          .connect(owner)
          .updateStakingPool(
            8,
            TIME.ONE_DAY,
            convertDecimals("1"),
            convertDecimals("1")
          )
      ).to.be.revertedWith("StakingPool: invalid pool index");
    });
  });

  describe("Deposit", async function () {
    before(async function () {
      let stakingAddress = await staking.getAddress();
      await rewardsToken
        .connect(manager1)
        .approve(stakingAddress, convertDecimals("2000"));
    });

    it("can deposit reward token", async function () {
      let stakingAddress = await staking.getAddress();
      let poolRewardTokenBalance = await rewardsToken.balanceOf(stakingAddress);
      await staking
        .connect(manager1)
        .depositReward(
          await rewardsToken.getAddress(),
          convertDecimals("2000")
        );
      let poolRewardTokenBalanceAfter = await rewardsToken.balanceOf(
        stakingAddress
      );

      expect(poolRewardTokenBalanceAfter).to.equal(
        poolRewardTokenBalance + convertDecimals("2000")
      );
    });

    it("should revert when amount is 0", async function () {
      await expect(
        staking
          .connect(manager1)
          .depositReward(await rewardsToken.getAddress(), convertDecimals("0"))
      ).to.be.revertedWith("StakingPool: Deposit amount cannot be zero");
    });

    it("should revert when not manager", async function () {
      await expect(
        staking
          .connect(owner)
          .depositReward(await rewardsToken.getAddress(), convertDecimals("0"))
      ).to.be.reverted;
      await expect(
        staking
          .connect(user1)
          .depositReward(await rewardsToken.getAddress(), convertDecimals("0"))
      ).to.be.reverted;
      await expect(
        staking
          .connect(provider1)
          .depositReward(await rewardsToken.getAddress(), convertDecimals("0"))
      ).to.be.reverted;
    });
  });

  describe("Stake", async function () {
    const poolIndex = 5;

    before(async function () {
      // create pool with 7 days lock period
      await staking.connect(owner).createStakingPool(1, 2, TIME.ONE_HOUR);
      let stakingAddress = await staking.getAddress();
      await stakingToken
        .connect(user1)
        .approve(stakingAddress, convertDecimals("2000"));
    });

    it("can stake token into pool", async function () {
      let stakingAddress = await staking.getAddress();
      let stakingPool = await staking.pools(poolIndex);
      let stakingPoolBalanceBefore = await stakingToken.balanceOf(
        stakingAddress
      );
      let userStakeBalanceBefore = await stakingToken.balanceOf(user1.address);

      // perform action
      await staking.connect(user1).stake(poolIndex, convertDecimals("2000"));

      let stakingPoolBalanceAfter = await stakingToken.balanceOf(
        stakingAddress
      );
      let stakingPoolAfter = await staking.pools(poolIndex);
      let currentItemIndex = await staking.currentItemIndex();
      let userStakeBalanceAfter = await stakingToken.balanceOf(user1.address);
      let stakingItem = await staking.getStakeItem(poolIndex, currentItemIndex);

      expect(userStakeBalanceAfter).to.equal(
        userStakeBalanceBefore - convertDecimals("2000")
      );
      expect(stakingPoolBalanceAfter).to.equal(
        stakingPoolBalanceBefore + convertDecimals("2000")
      );
      expect(stakingPoolAfter.totalStaked).to.equal(
        stakingPool.totalStaked + convertDecimals("2000")
      );
      expect(stakingItem.stakedAmount).to.equal(convertDecimals("2000"));
      expect(stakingItem.apy.rate).to.equal(stakingPool.apy.rate);
      expect(stakingItem.apy.decimals).to.equal(stakingPool.apy.decimals);
      expect(stakingItem.itemIndex).to.equal(currentItemIndex);
      expect(stakingItem.lockPeriod).equal(stakingPool.lockPeriod);
    });

    it("should revert when amount is 0", async function () {
      await expect(
        staking.connect(user1).stake(poolIndex, convertDecimals("0"))
      ).to.be.revertedWith(
        "StakingPool: stake amount cannot be less than mininum stake amount"
      );
    });

    it("can get user items", async function () {
      let items = await staking.getUserStakeItems(poolIndex, user1.address);
      expect(items).not.reverted;
    });

    it("can get staked users", async function () {
      let items = await staking.getAllStakedUsers();
      expect(items).not.reverted;
    });
  });

  describe("Migrate stake", async function () {
    const poolIndex = 5;

    before(async function () {
      let stakingAddress = await staking.getAddress();
      await stakingToken
        .connect(user1)
        .approve(stakingAddress, convertDecimals("5"));
    });

    it("can migrate stake for another user", async function () {
      let stakingAddress = await staking.getAddress();
      let stakingPool = await staking.pools(poolIndex);
      let stakingPoolBalanceBefore = await stakingToken.balanceOf(
        stakingAddress
      );
      let userStakeBalanceBefore = await stakingToken.balanceOf(user1.address);

      // perform action
      await staking
        .connect(provider1)
        .migrateStake(poolIndex, convertDecimals("5"), user1.address, "001");

      let stakingPoolBalanceAfter = await stakingToken.balanceOf(
        stakingAddress
      );
      let stakingPoolAfter = await staking.pools(poolIndex);

      let currentItemIndex = await staking.currentItemIndex();
      let userStakeBalanceAfter = await stakingToken.balanceOf(user1.address);
      let stakingItem = await staking.getStakeItem(poolIndex, currentItemIndex);

      expect(userStakeBalanceAfter).to.equal(
        userStakeBalanceBefore - convertDecimals("5")
      );
      expect(stakingPoolBalanceAfter).to.equal(
        stakingPoolBalanceBefore + convertDecimals("5")
      );
      expect(stakingPoolAfter.totalStaked).to.equal(
        stakingPool.totalStaked + convertDecimals("5")
      );
      expect(stakingItem.stakedAmount).to.equal(convertDecimals("5"));
      expect(stakingItem.apy.rate).to.equal(stakingPool.apy.rate);
      expect(stakingItem.apy.decimals).to.equal(stakingPool.apy.decimals);
      expect(stakingItem.itemIndex).to.equal(currentItemIndex);
    });

    it("should revert when amount is 0", async function () {
      await expect(
        staking
          .connect(provider1)
          .migrateStake(poolIndex, convertDecimals("0"), user1.address, "001")
      ).to.be.revertedWith("StakingPool: stake amount cannot be 0");
    });
  });

  describe("Claim - Harvest", async function () {
    const poolIndex = 5;
    let stakeItemIndex = await staking.currentItemIndex();

    before(async function () {
      let stakingAddress = await staking.getAddress();
      await rewardsToken
        .connect(manager1)
        .approve(stakingAddress, convertDecimals("10"));
      await staking
        .connect(manager1)
        .depositReward(await rewardsToken.getAddress(), convertDecimals("10"));
    });

    it("should revert when claim stake item from another user", async function () {
      // skip 8 days for claiming
      const aMonth = TIME.ONE_DAY * 8;

      await ethers.provider.send("evm_increaseTime", [aMonth]);
      await ethers.provider.send("evm_mine");

      await expect(
        staking.connect(user2).claim(poolIndex, stakeItemIndex)
      ).to.be.revertedWith(
        "StakingPool: This stake item belongs to another address"
      );
    });

    it("can claim stake item", async function () {
      let stakingAddress = await staking.getAddress();
      let pool = await staking.pools(poolIndex);
      let stakeItem = await staking.getStakeItem(poolIndex, stakeItemIndex);
      let rewardUserBalance = await rewardsToken.balanceOf(user1);
      let poolRewardBalance = await rewardsToken.balanceOf(stakingAddress);

      // skip 30 days
      const time = TIME.ONE_DAY * 30;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine");

      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      // claim
      await staking.connect(user1).claim(poolIndex, stakeItemIndex);

      let rewardUserBalanceAfter = await rewardsToken.balanceOf(user1);
      let poolAfter = await staking.pools(poolIndex);
      let stakeItemAfter = await staking.getStakeItem(
        poolIndex,
        stakeItemIndex
      );
      let poolRewardBalanceAfter = await rewardsToken.balanceOf(stakingAddress);

      let reward = rewardCalculation(
        toBigInt(timestamp + 1),
        stakeItem.lastUpdatedTime,
        stakeItem.stakedAmount,
        stakeItem.apy,
        stakeItem.lockPeriod
      );

      expect(poolRewardBalanceAfter).equal(poolRewardBalance - reward);
      expect(rewardUserBalanceAfter).to.equal(rewardUserBalance + reward);
      expect(stakeItemAfter.remainingReward).equal(0);
      expect(poolAfter.totalRewardClaimed).equal(
        pool.totalRewardClaimed + reward
      );
      expect(stakeItemAfter.lastUpdatedTime).equal(timestamp + 1);
    });
  });

  describe("Claim all", async function () {
    const poolIndex = 5;

    before(async function () {
      // create pool with 7 days lock period
      await staking.connect(owner).createStakingPool(1, 2, TIME.ONE_DAY * 7);
      let stakingAddress = await staking.getAddress();
      await stakingToken
        .connect(user1)
        .approve(stakingAddress, convertDecimals("20000"));
    });

    it("can stake token into pool", async function () {
      let stakingAddress = await staking.getAddress();
      let stakingPool = await staking.pools(poolIndex);
      let stakingPoolBalanceBefore = await stakingToken.balanceOf(
        stakingAddress
      );
      let userStakeBalanceBefore = await stakingToken.balanceOf(user1.address);

      // stake 4 times
      await staking.connect(user1).stake(poolIndex, convertDecimals("2000"));
      await staking.connect(user1).stake(poolIndex, convertDecimals("2000"));
      await staking.connect(user1).stake(poolIndex, convertDecimals("2000"));
      await staking.connect(user1).stake(poolIndex, convertDecimals("2000"));

      let stakingPoolBalanceAfter = await stakingToken.balanceOf(
        stakingAddress
      );
      let stakingPoolAfter = await staking.pools(poolIndex);
      let currentItemIndex = await staking.currentItemIndex();
      let userStakeBalanceAfter = await stakingToken.balanceOf(user1.address);
      let stakingItem = await staking.getStakeItem(poolIndex, currentItemIndex);

      expect(userStakeBalanceAfter).to.equal(
        userStakeBalanceBefore - convertDecimals("8000")
      );
      expect(stakingPoolBalanceAfter).to.equal(
        stakingPoolBalanceBefore + convertDecimals("8000")
      );
      expect(stakingPoolAfter.totalStaked).to.equal(
        stakingPool.totalStaked + convertDecimals("8000")
      );
      expect(stakingItem.stakedAmount).to.equal(convertDecimals("2000"));
      expect(stakingItem.apy.rate).to.equal(stakingPool.apy.rate);
      expect(stakingItem.apy.decimals).to.equal(stakingPool.apy.decimals);
      expect(stakingItem.itemIndex).to.equal(currentItemIndex);
      expect(stakingItem.lockPeriod).equal(stakingPool.lockPeriod);
    });

    it("can claim all items", async function () {
      let stakingAddress = await staking.getAddress();
      let pool = await staking.pools(poolIndex);
      let lastItemIndex = await staking.currentItemIndex();
      let firstStakeItem = await staking.getStakeItem(poolIndex, 0);
      let stakeItem = await staking.getStakeItem(poolIndex, lastItemIndex);
      let rewardUserBalance = await rewardsToken.balanceOf(user1);
      let poolRewardBalance = await rewardsToken.balanceOf(stakingAddress);

      // skip 30 days
      const time = TIME.ONE_DAY * 30;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine");

      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      await staking.connect(user1).claimAll();

      let rewardUserBalanceAfter = await rewardsToken.balanceOf(user1);
      let poolAfter = await staking.pools(poolIndex);
      let stakeItemAfter = await staking.getStakeItem(poolIndex, lastItemIndex);
      let poolRewardBalanceAfter = await rewardsToken.balanceOf(stakingAddress);

      let firstReward = rewardCalculation(
        toBigInt(timestamp + 1),
        firstStakeItem.lastUpdatedTime,
        firstStakeItem.stakedAmount,
        firstStakeItem.apy,
        firstStakeItem.lockPeriod
      );

      let reward = rewardCalculation(
        toBigInt(timestamp + 1),
        stakeItem.lastUpdatedTime,
        stakeItem.stakedAmount,
        stakeItem.apy,
        stakeItem.lockPeriod
      );

      let totalReward = rewardUserBalance + reward * toBigInt(4) + firstReward;
      expect(totalReward).is.lte(rewardUserBalanceAfter);
    });
  });

  describe("Unstake", async function () {
    const poolIndex = 5;
    let lastItemIndex;

    before(async function () {
      await staking.connect(user1).stake(poolIndex, convertDecimals("2000"));
      let pool = await staking.pools(poolIndex);
      lastItemIndex = await staking.currentItemIndex();
    });

    it("should revert when unstake stake item before lock period end", async function () {
      await expect(
        staking.connect(user1).unstake(poolIndex, lastItemIndex)
      ).to.be.revertedWith(
        "StakingPool: this stake item cannot be unstaked yet"
      );
    });

    it("should revert when unstake stake item from another user", async function () {
      // skip 8 days for claiming
      const time = TIME.ONE_DAY * 8;

      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine");

      await expect(
        staking.connect(user2).claim(poolIndex, lastItemIndex)
      ).to.be.revertedWith(
        "StakingPool: This stake item belongs to another address"
      );
    });

    it("can unstake stake item", async function () {
      let stakingAddress = await staking.getAddress();
      let pool = await staking.pools(poolIndex);
      let stakeItem = await staking.getStakeItem(poolIndex, lastItemIndex);
      let rewardUserBalance = await rewardsToken.balanceOf(user1);
      let stakingUserBalance = await stakingToken.balanceOf(user1);
      let poolStakingBalance = await stakingToken.balanceOf(stakingAddress);

      // skip 60 days
      const time = TIME.ONE_DAY * 60;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine");

      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      // unstake
      await staking.connect(user1).unstake(poolIndex, lastItemIndex);

      let rewardUserBalanceAfter = await rewardsToken.balanceOf(user1);
      let poolAfter = await staking.pools(poolIndex);
      let stakeItemAfter = await staking.getStakeItem(poolIndex, lastItemIndex);
      let stakingUserBalanceAfter = await stakingToken.balanceOf(user1);
      let poolStakingBalanceAfter = await stakingToken.balanceOf(
        stakingAddress
      );

      let reward = rewardCalculation(
        toBigInt(timestamp + 1),
        stakeItem.lastUpdatedTime,
        stakeItem.stakedAmount,
        stakeItem.apy,
        stakeItem.lockPeriod
      );

      expect(poolStakingBalanceAfter).equal(
        poolStakingBalance - stakeItem.stakedAmount
      );
      expect(stakingUserBalanceAfter).equal(
        stakingUserBalance + stakeItem.stakedAmount
      );
      expect(poolAfter.totalStaked).equal(
        pool.totalStaked - stakeItem.stakedAmount
      );
      expect(rewardUserBalanceAfter).to.equal(rewardUserBalance + reward);
      expect(stakeItemAfter.remainingReward).equal(0);
      expect(poolAfter.totalRewardClaimed).equal(
        pool.totalRewardClaimed + reward
      );
      expect(stakeItemAfter.lastUpdatedTime).equal(timestamp + 1);
      expect(stakeItemAfter.unlockTime).equal(
        toBigInt(timestamp) + toBigInt(1) + pool.lockPeriod
      );
      expect(stakeItemAfter.unstaked).equal(true);
    });

    it("should revert when claim unstaked item", async function () {
      await expect(
        staking.connect(user2).claim(poolIndex, lastItemIndex)
      ).to.be.revertedWith("StakingPool: no reward to claim");
    });
  });

  describe("Update APY", async function () {
    const poolIndex = 5;
    let lastItemIndex;

    before(async function () {
      await staking.connect(user1).stake(poolIndex, convertDecimals("1000"));
      let pool = await staking.pools(poolIndex);
      lastItemIndex = await staking.currentItemIndex();
    });

    it("should revert when apy is 0", async function () {
      await expect(
        staking.connect(owner).updateAPY([poolIndex], [0, 1], 0, 0)
      ).to.be.revertedWith("StakingPool: APY cannot be zero");
    });

    it("can update APY", async function () {
      const poolIndexes = [poolIndex];
      let pool = await staking.pools(poolIndex);
      const stakeItemIndexes = [lastItemIndex];
      let stakeItem = await staking.getStakeItem(poolIndex, lastItemIndex);

      // update APY
      await staking
        .connect(owner)
        .updateAPY(poolIndexes, stakeItemIndexes, 4, 2);

      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      let reward = rewardCalculation(
        toBigInt(timestamp),
        stakeItem.lastUpdatedTime,
        stakeItem.stakedAmount,
        stakeItem.apy,
        stakeItem.lockPeriod
      );

      let poolAfter = await staking.pools(poolIndex);
      let stakeItemAfter = await staking.getStakeItem(poolIndex, lastItemIndex);

      expect(poolAfter.apy.rate).equal(pool.apy.rate);
      expect(poolAfter.apy.decimals).equal(pool.apy.decimals);
      expect(stakeItemAfter.apy.rate).equal(4);
      expect(stakeItemAfter.apy.decimals).equal(2);
      expect(stakeItemAfter.lastUpdatedTime).equal(timestamp);
      expect(stakeItemAfter.remainingReward).equal(
        stakeItem.remainingReward + reward
      );
    });
  });

  describe("Restake reward", async function () {
    const poolIndex = 5;
    let lastItemIndex;

    before(async function () {
      await staking.connect(user1).stake(poolIndex, convertDecimals("1000"));
      let pool = await staking.pools(poolIndex);
      lastItemIndex = await staking.currentItemIndex();
    });

    it("should revert when wrong owner", async function () {
      await expect(
        staking.connect(user2).restakeReward(poolIndex, lastItemIndex)
      ).to.be.revertedWith(
        "StakingPool: This stake item belongs to another address"
      );
    });

    it("can restake item", async function () {
      let stakingAddress = await staking.getAddress();
      let stakingPool = await staking.pools(poolIndex);
      let stakeItem = await staking.getStakeItem(poolIndex, lastItemIndex);

      // skip 30 days
      const time = TIME.ONE_DAY * 30;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine");

      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      await staking.connect(user1).restakeReward(poolIndex, lastItemIndex);

      let reward = rewardCalculation(
        toBigInt(timestamp),
        stakeItem.lastUpdatedTime,
        stakeItem.stakedAmount,
        stakeItem.apy,
        stakeItem.lockPeriod
      );

      let stakeItemAfter = await staking.getStakeItem(poolIndex, lastItemIndex);

      expect(stakeItem.stakedAmount).lt(stakeItemAfter.stakedAmount);
      expect(stakeItemAfter.remainingReward).equal(convertDecimals("0"));
    });
  });

  describe("Restake", async function () {
    let poolIndex = 5;
    let lastItemIndex;

    before(async function () {
      await staking.connect(user1).stake(poolIndex, convertDecimals("500"));
      lastItemIndex = await staking.currentItemIndex();
    });

    it("can be restake", async function () {
      let stakeItem = await staking.getStakeItem(poolIndex, lastItemIndex);

      // skip 3 days
      const time = TIME.ONE_DAY * 3;
      await ethers.provider.send("evm_increaseTime", [time]);
      await ethers.provider.send("evm_mine");

      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      await staking.connect(user1).restake(poolIndex, lastItemIndex);

      let stakeItemAfter = await staking.getStakeItem(poolIndex, lastItemIndex);

      expect(stakeItemAfter.unlockTime - toBigInt(1)).equal(
        toBigInt(timestamp) + stakeItem.lockPeriod
      );
      expect(stakeItemAfter.remainingReward).equal(0);
    });
  });

  describe("Pause pool", async function () {
    let poolIndex = 5;
    let lastItemIndex;

    before(async function () {
      let pool = await staking.pools(poolIndex);
      await staking.connect(manager1).pausePool(poolIndex);
      lastItemIndex = await staking.currentItemIndex();
    });

    it("should be correct status when paused", async function () {
      pool = await staking.pools(poolIndex);
      expect(pool.paused).equal(true);
    });

    it("cannot stake when pool is paused", async function () {
      await expect(
        staking.connect(user1).stake(poolIndex, convertDecimals("1000"))
      ).to.be.revertedWith("StakingPool: Staking is paused");
    });

    it("can unpause and perform actions", async function () {
      await staking.connect(manager1).unpausePool(poolIndex);
      pool = await staking.pools(poolIndex);
      expect(pool.paused).equal(false);
    });
  });

  describe("Withdraw reward", async function () {
    let transactionIndex = 0;

    it("should revert when submit transaction with token that not in the pool", async function () {
      await expect(
        staking
          .connect(treasury1)
          .submitTransaction(
            zeroAddress,
            convertDecimals("5"),
            MULTISIG_TYPE.WITHDRAW,
            zeroAddress,
            false,
            zeroAddress
          )
      ).to.be.revertedWith(
        "StakingPool: cannot withdraw token that not in the pool"
      );
    });

    it("should revert when submit transaction with 0 amount", async function () {
      let stakingTokenAddress = await stakingToken.getAddress();
      await expect(
        staking
          .connect(treasury1)
          .submitTransaction(
            stakingTokenAddress,
            convertDecimals("0"),
            MULTISIG_TYPE.WITHDRAW,
            zeroAddress,
            false,
            zeroAddress
          )
      ).to.be.revertedWith(
        "StakingPool: cannot submit transaction with zero amount"
      );
    });

    it("should revert when submit with wrong role", async function () {
      let stakingTokenAddress = await stakingToken.getAddress();
      await expect(
        staking
          .connect(user1)
          .submitTransaction(
            stakingTokenAddress,
            convertDecimals("5"),
            MULTISIG_TYPE.WITHDRAW,
            zeroAddress,
            false,
            zeroAddress
          )
      ).to.be.reverted;
    });

    it("can submit withdraw transaction", async function () {
      let stakingTokenAddress = await stakingToken.getAddress();
      await staking
        .connect(treasury1)
        .submitTransaction(
          stakingTokenAddress,
          convertDecimals("5"),
          MULTISIG_TYPE.WITHDRAW,
          zeroAddress,
          false,
          zeroAddress
        );
      let withdrawTransaction = await staking.multisigTransactions(
        transactionIndex
      );

      expect(withdrawTransaction.txIndex).equal(toBigInt("0"));
      expect(withdrawTransaction.amount).equal(convertDecimals("5"));
      expect(withdrawTransaction.tokenAddress).equal(stakingTokenAddress);
      expect(withdrawTransaction.submitter).equal(treasury1.address);
      expect(withdrawTransaction.executed).equal(false);
      expect(withdrawTransaction.numConfirmations).equal(toBigInt("0"));
    });

    it("should revert when confirm with wrong role", async function () {
      await expect(staking.connect(user1).confirmTransaction(transactionIndex))
        .to.be.reverted;
    });

    it("can confirm transaction", async function () {
      let withdrawTransaction = await staking.multisigTransactions(
        transactionIndex
      );
      await staking.connect(treasury1).confirmTransaction(transactionIndex);
      let withdrawTransactionAfter = await staking.multisigTransactions(
        transactionIndex
      );

      expect(withdrawTransactionAfter.numConfirmations).equal(
        withdrawTransaction.numConfirmations + toBigInt("1")
      );
    });

    it("should revert when not enough confirmation", async function () {
      await expect(
        staking.connect(treasury1).executeTransaction(transactionIndex)
      ).to.be.revertedWith(
        "StakingPool: cannot execute tx, not enough confirmation"
      );
    });

    it("should revert when withdraw amount greater than contract balance", async function () {
      let stakingTokenAddress = await stakingToken.getAddress();
      await staking
        .connect(treasury1)
        .submitTransaction(
          stakingTokenAddress,
          convertDecimals("2000000"),
          MULTISIG_TYPE.WITHDRAW,
          zeroAddress,
          false,
          zeroAddress
        );
      let lastTransactionIndex = 1;
      await staking.connect(treasury1).confirmTransaction(lastTransactionIndex);
      await staking.connect(treasury3).confirmTransaction(lastTransactionIndex);

      await expect(
        staking.connect(treasury1).executeTransaction(lastTransactionIndex)
      ).to.be.revertedWith(
        "StakingPool: withdraw amount cannot be greater than total stake amount"
      );
    });

    it("can execute transaction", async function () {
      let withdrawTransaction = await staking.multisigTransactions(
        transactionIndex
      );

      await staking.connect(treasury2).confirmTransaction(transactionIndex);
      await staking.connect(treasury1).executeTransaction(transactionIndex);
      let withdrawTransactionAfter = await staking.multisigTransactions(
        transactionIndex
      );

      expect(withdrawTransactionAfter.numConfirmations).equal(
        withdrawTransaction.numConfirmations + toBigInt("1")
      );
      expect(withdrawTransactionAfter.executed).equal(true);
    });
  });

  describe("Stop emergency", async function () {
    before(async function () {
      let stakingAddress = await staking.getAddress();
      await stakingToken
        .connect(manager1)
        .approve(stakingAddress, convertDecimals("20000"));
      await staking
        .connect(manager1)
        .depositReward(
          await stakingToken.getAddress(),
          convertDecimals("20000")
        );
    });

    it("should revert when not owner", async function () {
      let userAddresses = [user1.address, user2.address, owner.address];

      await expect(staking.connect(user2).stopEmergency(userAddresses)).to.be
        .reverted;
    });

    it("should return token to users", async function () {
      let userAddresses = [user1.address, user2.address];

      await staking.connect(owner).stopEmergency(userAddresses);
      let user1Balance = await stakingToken.balanceOf(user1.address);
      let user2Balance = await stakingToken.balanceOf(user2.address);

      expect(user1Balance).equal(convertDecimals("100500"));
      expect(user2Balance).equal(convertDecimals("100000"));
    });
  });

  describe("Treasury role", async function () {
    let transactionIndex = 0;

    before(async function () {
      transactionIndex = await staking.getTransactionLength();
    });

    it("should revert when invalid transaction type", async function () {
      let stakingTokenAddress = await stakingToken.getAddress();
      await expect(
        staking
          .connect(treasury1)
          .submitTransaction(
            stakingTokenAddress,
            convertDecimals("0"),
            ethers.keccak256(ethers.toUtf8Bytes("")),
            treasury4,
            true,
            zeroAddress
          )
      ).to.be.revertedWith("StakingPool: invalid transaction type");
    });

    it("should revert when assign zero address", async function () {
      let stakingTokenAddress = await stakingToken.getAddress();
      await expect(
        staking
          .connect(treasury1)
          .submitTransaction(
            stakingTokenAddress,
            convertDecimals("0"),
            MULTISIG_TYPE.TREASURY_ROLE,
            zeroAddress,
            true,
            zeroAddress
          )
      ).to.be.revertedWith("StakingPool: user address cannot be zero address");
    });

    it("can submit grant treasury role transaction", async function () {
      await staking
        .connect(treasury1)
        .submitTransaction(
          zeroAddress,
          convertDecimals("0"),
          MULTISIG_TYPE.TREASURY_ROLE,
          treasury4,
          true,
          zeroAddress
        );

      let transaction = await staking.multisigTransactions(transactionIndex);
      const time = TIME.ONE_HOUR;
      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      expect(transaction.expiredAt).equal(timestamp + time);
      expect(transaction.treasuryUserAddress).equal(treasury4.address);
      expect(transaction.transactionType).equal(MULTISIG_TYPE.TREASURY_ROLE);
      expect(transaction.submitter).equal(treasury1.address);
      expect(transaction.executed).equal(false);
      expect(transaction.numConfirmations).equal(toBigInt("0"));
    });

    it("should revert when confirm with wrong role", async function () {
      await expect(staking.connect(user1).confirmTransaction(transactionIndex))
        .to.be.reverted;
    });

    it("can confirm transaction", async function () {
      let withdrawTransaction = await staking.multisigTransactions(
        transactionIndex
      );
      await staking.connect(treasury1).confirmTransaction(transactionIndex);
      let withdrawTransactionAfter = await staking.multisigTransactions(
        transactionIndex
      );

      expect(withdrawTransactionAfter.numConfirmations).equal(
        withdrawTransaction.numConfirmations + toBigInt("1")
      );
    });

    it("should revert when not enough confirmation", async function () {
      await expect(
        staking.connect(treasury1).executeTransaction(transactionIndex)
      ).to.be.revertedWith(
        "StakingPool: cannot execute tx, not enough confirmation"
      );
    });

    it("can execute transaction", async function () {
      await staking.connect(treasury2).confirmTransaction(transactionIndex);
      await staking.connect(treasury1).executeTransaction(transactionIndex);

      let hasTreasuryRole = await staking.hasTreasuryRole(
        ROLE.TREASURY,
        treasury4.address
      );
      let transaction = await staking.multisigTransactions(transactionIndex);

      expect(hasTreasuryRole).equal(true);
      expect(transaction.executed).equal(true);
    });
  });

  describe("Change withdraw wallet", async function () {
    let transactionIndex = 0;

    before(async function () {
      transactionIndex = await staking.getTransactionLength();
    });

    it("should revert if withdraw wallet is zero address", async function () {
      await expect(
        staking
          .connect(treasury1)
          .submitTransaction(
            zeroAddress,
            convertDecimals("0"),
            MULTISIG_TYPE.CHANGE_WALLET,
            zeroAddress,
            false,
            zeroAddress
          )
      ).to.be.revertedWith(
        "StakingPool: withdraw wallet cannot be zero address"
      );
    });

    it("can submit change wallet transaction", async function () {
      await staking
        .connect(treasury1)
        .submitTransaction(
          zeroAddress,
          convertDecimals("0"),
          MULTISIG_TYPE.CHANGE_WALLET,
          zeroAddress,
          true,
          withdrawWallet2
        );

      let transaction = await staking.multisigTransactions(transactionIndex);
      const time = TIME.ONE_HOUR;
      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      expect(transaction.expiredAt).equal(timestamp + time);
      expect(transaction.treasuryUserAddress).equal(zeroAddress);
      expect(transaction.transactionType).equal(MULTISIG_TYPE.CHANGE_WALLET);
      expect(transaction.submitter).equal(treasury1.address);
      expect(transaction.executed).equal(false);
      expect(transaction.numConfirmations).equal(toBigInt("0"));
      expect(transaction.withdrawWallet).equal(withdrawWallet2);
    });

    it("can confirm transaction", async function () {
      let transaction = await staking.multisigTransactions(transactionIndex);
      await staking.connect(treasury1).confirmTransaction(transactionIndex);
      let transactionAfter = await staking.multisigTransactions(
        transactionIndex
      );

      expect(transactionAfter.numConfirmations).equal(
        transaction.numConfirmations + toBigInt("1")
      );
    });

    it("can update withdraw wallet", async function () {
      await staking.connect(treasury2).confirmTransaction(transactionIndex);
      await staking.connect(treasury1).executeTransaction(transactionIndex);

      let withdrawWallet = await staking.withdrawWallet();
      let transaction = await staking.multisigTransactions(transactionIndex);

      expect(withdrawWallet).equal(withdrawWallet2);
      expect(transaction.executed).equal(true);
    });
  });

  describe("Update minimum stake amount", async function () {
    let poolIndex = 5;

    it("should revert when new value is zero", async function () {
      await expect(
        staking.connect(manager1).changeMinStakeAmount(convertDecimals("0"))
      ).to.be.revertedWith("StakingPool: Cannot set min stake amount to zero");
    });

    it("should update min stake amount", async function () {
      await staking
        .connect(manager1)
        .changeMinStakeAmount(convertDecimals("300"));

      let newAmount = await staking.minStakeAmount();

      expect(newAmount).equal(convertDecimals("300"));
    });

    it("can stake with new amount", async function () {
      await staking.connect(user1).stake(poolIndex, convertDecimals("320"));
      let pool = await staking.pools(poolIndex);
      let lastItemIndex = await staking.currentItemIndex();
      let stakingItem = await staking.getStakeItem(poolIndex, lastItemIndex);

      expect(stakingItem.stakedAmount).equal(convertDecimals("320"));
    });
  });

  describe("Upgrade stake item", async function () {
    it("can upgrade stake item", async function () {
      let poolIndex = 5;
      let upgradedPoolIndex = 3;
      let lastItemIndex = await staking.currentItemIndex();
      let pool = await staking.pools(poolIndex);
      let upgradedPool = await staking.pools(upgradedPoolIndex);
      let currentItem = await staking.getStakeItem(poolIndex, lastItemIndex);

      const blockNum = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNum);
      const timestamp = block.timestamp;

      // upgrade item
      await staking
        .connect(user1)
        .upgradeStakeItem(poolIndex, lastItemIndex, upgradedPoolIndex);

      let poolAfter = await staking.pools(poolIndex);
      let upgradedPoolAfter = await staking.pools(upgradedPoolIndex);
      let upgradedItem = await staking.getStakeItem(
        upgradedPoolIndex,
        lastItemIndex
      );

      let bonusTime = 0;
      if (timestamp > currentItem.unlockTime) {
        bonusTime =
          toBigInt(timestamp) - currentItem.unlockTime + toBigInt("1");
      }
      if (bonusTime > currentItem.lockPeriod) {
        bonusTime = currentItem.lockPeriod;
      }

      expect(upgradedItem.apy.rate).equal(upgradedPool.apy.rate);
      expect(upgradedItem.apy.decimals).equal(upgradedPool.apy.decimals);
      expect(upgradedItem.lockPeriod).equal(upgradedPool.lockPeriod);
      expect(upgradedItem.bonusLockedTime).equal(bonusTime);
      expect(upgradedItem.poolIndex).equal(upgradedPool.poolIndex);

      expect(poolAfter.totalStaked).equal(
        pool.totalStaked - currentItem.stakedAmount
      );
      expect(poolAfter.totalStakeItem).equal(
        pool.totalStakeItem - toBigInt("1")
      );
      expect(upgradedPoolAfter.totalStakeItem).equal(
        upgradedPool.totalStakeItem + toBigInt("1")
      );
      expect(upgradedPoolAfter.totalStaked).equal(
        upgradedPool.totalStaked + currentItem.stakedAmount
      );
    });
  });

  describe("Get user stake amount", async function () {
    it("can get user pool info", async function () {
      let poolArr = [5];
      let info = await staking.getUserStakes(user1.address, poolArr);
      expect(info.length).equal(1);
    });
  });

  describe("Stop all function", async function () {
    let poolIndex = 5;
    let upgradedPoolIndex = 3;

    it("should reject when contract is stopped", async function () {
      let lastItemIndex = await staking.currentItemIndex();

      await staking.connect(owner).changeStopAll(true);

      expect(await staking.stopAll()).equal(true);
      await expect(
        staking.connect(user1).stake(poolIndex, convertDecimals("5"))
      ).to.be.revertedWith(
        "Staking: This contract has stopped, only owner can access"
      );
      await expect(
        staking.connect(user1).unstake(poolIndex, lastItemIndex)
      ).to.be.revertedWith(
        "Staking: This contract has stopped, only owner can access"
      );
      await expect(
        staking.connect(user1).restake(poolIndex, lastItemIndex)
      ).to.be.revertedWith(
        "Staking: This contract has stopped, only owner can access"
      );
      await expect(
        staking.connect(user2).claim(poolIndex, lastItemIndex)
      ).to.be.revertedWith(
        "Staking: This contract has stopped, only owner can access"
      );
      await expect(
        staking
          .connect(user2)
          .upgradeStakeItem(poolIndex, lastItemIndex, upgradedPoolIndex)
      ).to.be.revertedWith(
        "Staking: This contract has stopped, only owner can access"
      );
      await expect(
        staking.connect(user2).restakeReward(poolIndex, lastItemIndex)
      ).to.be.revertedWith(
        "Staking: This contract has stopped, only owner can access"
      );
    });

    it("should be able to connect when contract is not stopped", async function () {
      await staking.connect(owner).changeStopAll(false);
      await staking.connect(user1).stake(poolIndex, convertDecimals("500"));

      expect(await staking.stopAll()).equal(false);
    });
  });
});
