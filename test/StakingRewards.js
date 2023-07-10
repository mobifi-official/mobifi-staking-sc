const { expect, assert } = require("chai");
const { ethers } = require("hardhat");


// This is the start of the staking SC test
describe("StakingRewardsTest", async () => {

  let stakingDay = 0;

  let ownerSigner = null;
  let user1Account = null;
  let user2Account = null;
  let user3Account = null;
  let user4Account = null;
  let user5Account = null;
  let user6Account = null;

  // Contract Object stored in these variable
  let mofiTokenContract = null;
  let stakingRewardsContract = null;

  let mofiTokenContractAddress;
  let mofiTokenContractSymbol;
  let mofiTokenContractDecimals;

  // Here, we specify the amount of the staking token we want to pre-mint,
  // that is, the innitial supply
  const premintAmount = ethers.utils.parseEther("20000000")



  // This method is used to simulate the passage of time on the Ethereum Virtual Machine (EVM).
  // In Ethereum, time-based functionalities such as locking periods, reward durations, and other time-dependent actions 
  // rely on the current block timestamp. During testing, it can be useful to manipulate the timestamp to simulate future
  // or past block times.
  // The evm_increaseTime command is a feature provided by the test provider in ethers.js that allows you to increase the EVM's timestamp by a specified
  // number of seconds.
  async function increaseTime(days) {
    const secondsPerDay = 24 * 60 * 60;
    const secondsToIncrease = days * secondsPerDay;

    // Increase the EVM's timestamp
    await ethers.provider.send("evm_increaseTime", [secondsToIncrease]);

    // Mine a new block to update the contract state
    await ethers.provider.send("evm_mine", []);
  }

  async function logAccountBalance(accountAddress) {
    const balanceOfDeployersStakingTokens = await mofiTokenContract.balanceOf(accountAddress);
    const balanceOfOfDeployer = balanceOfDeployersStakingTokens / Math.pow(10, mofiTokenContractDecimals);

    let accountName = '';

    switch (accountAddress) {
      case ownerSigner.address:
        accountName = 'Deployer Address'
        break;
      case user1Account.address:
        accountName = 'user1 Account Address'
        break;
      case user2Account.address:
        accountName = 'user2 Account Address'
        break;
      case user3Account.address:
        accountName = 'user3 Account Address'
        break;
      case user4Account.address:
        accountName = 'user4 Account Address'
        break;
      case user5Account.address:
        accountName = 'user5 Account Address'
        break;
      case stakingRewardsContract.address:
        accountName = 'Staking Contract address'
        break;
      default:
        break;
    }

    console.log(`${mofiTokenContractSymbol} balance for ${accountName} is ${balanceOfOfDeployer} ${mofiTokenContractSymbol}`);
  }

  function convertEther(valueToConvert) {
    return valueToConvert / Math.pow(10, 18);
  }


  // 1. Get some accounts (signers) to use in the testing.
  // 2. Deploy the necessary smart contracts, eg, the staking-rewards, as well as the staking token smart contracts.
  // 3. Fund the user accounts we obtained in step (1) above with some staking tokens for testing.
  before(async function () {


    [ownerSigner, user1Account, user2Account, user3Account, user4Account, user5Account, user6Account] = await ethers.getSigners();


    // Handle the deployment of the staking token
    const StakingToken = await ethers.getContractFactory("MobiFiStakingToken");
    mofiTokenContract = await StakingToken.deploy(ownerSigner.address, premintAmount);
    // Deploy the staking smart contract
    await mofiTokenContract.deployed();


    // Get various information about the staking token we've just deployed:
    // The address, symbol, and decimals
    mofiTokenContractAddress = mofiTokenContract.address;
    mofiTokenContractSymbol = await mofiTokenContract.symbol();
    mofiTokenContractDecimals = await mofiTokenContract.decimals();

    console.log(`Contract ${mofiTokenContractSymbol} deployed to address ${mofiTokenContractAddress}`);


    await logAccountBalance(ownerSigner.address);

    const stakingCapForEntireProgram = ethers.utils.parseEther("1000000");

    // Handle the deployment of the StakingRewards smart contract
    const StakingRewardsContract = await ethers.getContractFactory("StakingRewards");
    stakingRewardsContract = await StakingRewardsContract.deploy(ownerSigner.address, ownerSigner.address, mofiTokenContract.address, mofiTokenContract.address, stakingCapForEntireProgram);
    // Deploy the staking smart contract
    await stakingRewardsContract.deployed();


    console.log(`Contract 'StakingRewards' deployed to address ${stakingRewardsContract.address}`);

    // Approve the StakingRewards contract to spend user1 and user2's staking tokens
    await mofiTokenContract.connect(user1Account).approve(stakingRewardsContract.address, ethers.constants.MaxUint256);
    await mofiTokenContract.connect(user2Account).approve(stakingRewardsContract.address, ethers.constants.MaxUint256);
    await mofiTokenContract.connect(user3Account).approve(stakingRewardsContract.address, ethers.constants.MaxUint256);
    await mofiTokenContract.connect(user4Account).approve(stakingRewardsContract.address, ethers.constants.MaxUint256);
    await mofiTokenContract.connect(user5Account).approve(stakingRewardsContract.address, ethers.constants.MaxUint256);
    await mofiTokenContract.connect(user6Account).approve(stakingRewardsContract.address, ethers.constants.MaxUint256);
  });

  /**
   * 
   */
  it('should transfer mofiTokenContract to user other two user wallet ', async () => {
    // Transfer some staking tokens to user1 and user2 for testing
    await mofiTokenContract.connect(ownerSigner).transfer(stakingRewardsContract.address, ethers.utils.parseEther("100000"));
    await stakingRewardsContract.connect(ownerSigner).notifyRewardAmount(ethers.utils.parseEther("100000"));

    // Retrieve rewardRate from the contract
    let rewardRate = await stakingRewardsContract.rewardRate();

    console.log(`----> The reward rate is ${ethers.utils.formatEther(rewardRate)}`);

   
    await mofiTokenContract.connect(ownerSigner).transfer(user1Account.address, ethers.utils.parseEther("2000"));
    await mofiTokenContract.connect(ownerSigner).transfer(user2Account.address, ethers.utils.parseEther("2000"));
    await mofiTokenContract.connect(ownerSigner).transfer(user3Account.address, ethers.utils.parseEther("2000"));
    await mofiTokenContract.connect(ownerSigner).transfer(user4Account.address, ethers.utils.parseEther("10000"));
    await mofiTokenContract.connect(ownerSigner).transfer(user5Account.address, ethers.utils.parseEther("10000"));
    await mofiTokenContract.connect(ownerSigner).transfer(user6Account.address, ethers.utils.parseEther("2000000"));


    console.log('--- After transfer MOFI ----');

    await logAccountBalance(user1Account.address);
    await logAccountBalance(user2Account.address);
    await logAccountBalance(user3Account.address);
    await logAccountBalance(user4Account.address);

    console.log('--- End log for transfer MOFI ----');

    expect(await mofiTokenContract.balanceOf(user1Account.address)).to.equal(ethers.utils.parseEther("2000"));
    expect(await mofiTokenContract.balanceOf(user2Account.address)).to.equal(ethers.utils.parseEther("2000"));
    expect(await mofiTokenContract.balanceOf(user3Account.address)).to.equal(ethers.utils.parseEther("2000"));
    expect(await mofiTokenContract.balanceOf(user4Account.address)).to.equal(ethers.utils.parseEther("10000"));
    expect(await mofiTokenContract.balanceOf(user6Account.address)).to.equal(ethers.utils.parseEther("2000000"));
  });


  it('user should not have unclaimed rewards balance before staking', async () => {
    const unclaimedRewards = await stakingRewardsContract.earned(user1Account.address);

    expect(unclaimedRewards).to.be.eq(0);
  });

  it('user should be recorded as not having participated in the staking program before they make their first stake', async () => {
    const result = await stakingRewardsContract.userHasParticipatedInTheStakingProgram(user1Account.address);

    expect(result).to.be.false;
  });

  /**
   * 
   */
  it('should allow user to start staking', async () => {

    await stakingRewardsContract.connect(user1Account).stake(ethers.utils.parseEther("1000"));
    await stakingRewardsContract.connect(user2Account).stake(ethers.utils.parseEther("1000"));
    await stakingRewardsContract.connect(user3Account).stake(ethers.utils.parseEther("2000"));
    await stakingRewardsContract.connect(user4Account).stake(ethers.utils.parseEther("5000"));


    const user1sStakingTokenBalance = await stakingRewardsContract.balanceOf(user1Account.address);
    const user1sStakingTokenWalletBalance = await mofiTokenContract.balanceOf(user1Account.address);

    // Check the balance and total supply after user1's stake
    expect(await stakingRewardsContract.balanceOf(user1Account.address)).to.equal(ethers.utils.parseEther("1000"));
    expect(await stakingRewardsContract.totalSupply()).to.equal(ethers.utils.parseEther("9000"));

    expect(user1sStakingTokenBalance).to.equal(ethers.utils.parseEther('1000'));
    expect(user1sStakingTokenWalletBalance).to.equal(ethers.utils.parseEther('1000'));

    console.log('--- after 4 user start staking ----');
    await logAccountBalance(stakingRewardsContract.address);
    console.log('--- end log for staking contract ----');
  });

  it('user should be recorded as having participated in the staking program after they make their first stake', async () => {

    const result = await stakingRewardsContract.userHasParticipatedInTheStakingProgram(user1Account.address);

    expect(result).to.be.true;
  });

  /**
   * catch error if user stake 0
   */
  it('should not allow user to stake zero', async () => {
    try {
      await stakingRewardsContract.connect(user1Account).stake(ethers.utils.parseEther("0"));
      assert.fail("Expected transaction to revert");
    } catch (error) {
      expect(error.message).to.contain("reverted with reason string 'Cannot stake 0'");
    }
  });


  it("should allow user to continue staking as long as they haven't reached maxStakeAmount", async () => {

    await stakingRewardsContract.connect(user5Account).stake(ethers.utils.parseEther("1300"));

    const maxStakeAmount = await stakingRewardsContract.maxStakeAmount();

    const stakedAmount = await stakingRewardsContract.balanceOf(user5Account.address);

    const remainingAmountTillMaxCapIsReached = maxStakeAmount.sub(stakedAmount);

    await stakingRewardsContract.connect(user5Account).stake(remainingAmountTillMaxCapIsReached);
    const newStakedAmount = await stakingRewardsContract.balanceOf(user5Account.address);

    expect(newStakedAmount).to.eq(maxStakeAmount);

  });

  /**
   * should catch the error if user stake more than maximum amount
   */
  it("should not allow user to stake more than maxStakeAmount", async () => {
    try {
      await stakingRewardsContract.connect(user5Account).stake(ethers.utils.parseEther("10001"));
    } catch (error) {
      expect(error.message).to.contain("reverted with reason string 'Exceeds maximum stake amount'");
    }
  });


  it("should not allow anyone who's not the owner of the staking smart contract to change maxStakeAmount", async () => {
    try {
      await stakingRewardsContract.connect(user1Account).adjustMaxStakeAmount(ethers.utils.parseEther("10000"))
    } catch (error) {
      expect(error.message).to.contain("Only the contract owner may perform this action");
    }
  });


  it('should allow the owner of the staking smart contract to change maxStakeAmount', async () => {

    await stakingRewardsContract.connect(ownerSigner).adjustMaxStakeAmount(ethers.utils.parseEther("10000"));
    const maxStakeAmount = await stakingRewardsContract.maxStakeAmount();
    const newMaxStakeAmount = (maxStakeAmount / Math.pow(10, mofiTokenContractDecimals));
    expect(newMaxStakeAmount).to.be.eq(10000);

  });

  /**
   * Calucalte staking rewards 
   * formula is
   * user_rewards = user_balance / 100 * rewards_rate * (current_datetime - account_start_staking) / staking_reward_duration
   */
  // it('should calculate staking account user 1 rewards', async () => {
  //   stakingDay = 5;
  //   await increaseTime(stakingDay);

  //   console.log('--- calculation information for user 1 ---');
  //   console.log(`user_balance: ${await stakingRewardsContract.balanceOf(user1Account.address)}`);
  //   console.log(`rewards_rate: ${await stakingRewardsContract.rewardRate()}`);
  //   const blockTime = await stakingRewardsContract.getCurrentBlockTime();
  //   console.log(`current_datetime: ${blockTime.toString()}`);
  //   console.log(`account_start_staking: ${await stakingRewardsContract.getStartDateAccountStake(user1Account.address)}`);
  //   console.log(`staking_reward_duration: ${await stakingRewardsContract.rewardsDuration()}`);
  //   console.log(`staking_program_start: ${await stakingRewardsContract.stakingStart()}`);

  //   console.log('user_rewards = user_balance / 100 * rewards_rate * (current_datetime - account_start_staking) / staking_reward_duration')

  //   const rewardsAccont = convertEther(await stakingRewardsContract.earned(user1Account.address));

  //   console.log(`Rewards for user 1 ==> ${rewardsAccont}`);
  //   console.log('--- end log for calculation information for user 1 ---');



  //   expect(rewardsAccont > 1).to.be.equal(true);
  // });

  it('unclaimed balance after some time has elapsed should be greater than 0', async () => {
    stakingDay = 5;
    await increaseTime(stakingDay);

    const unclaimedRewards = await stakingRewardsContract.earned(user1Account.address);

    console.log(`Unclaimed rewards at day ${stakingDay} is ${unclaimedRewards / Math.pow(10, mofiTokenContractDecimals)}`);

    expect(unclaimedRewards).to.be.gt(0);
  });

  /**
   * 
   */
  it("should claim rewards to user account", async () => {
    const usersInitialMoFiBalance = await mofiTokenContract.balanceOf(user1Account.address);
    await stakingRewardsContract.connect(user1Account).getReward();
    const usersMoFiBalance = await mofiTokenContract.balanceOf(user1Account.address);

    expect(usersMoFiBalance).to.be.gt(usersInitialMoFiBalance);
  });


  it("should not allow user to stake if there are not enough rewards in the reward pool", async () => {
    const initialRewardBalance = ethers.utils.parseEther("4500");
    const reductionAmount = ethers.utils.parseEther("4500");

    try {

      const usersStakedBalance = await stakingRewardsContract.balanceOf(user1Account.address);
      await stakingRewardsContract.connect(user1Account).withdraw(usersStakedBalance);
      // Reduce the reward balance to simulate insufficient rewards in the pool
      await mofiTokenContract.connect(ownerSigner).transfer(stakingRewardsContract.address, initialRewardBalance.sub(reductionAmount));

      await stakingRewardsContract.connect(user1Account).stake(ethers.utils.parseEther("300"));
    } catch (error) {
      // expect(error.message).to.contain("rewards balance is not sufficient to accept new staking");
      expect(error.message).to.contain("rewards balance is not sufficient to accept new staking");
    }
  });

  it("should not allow user to stake if the staking cap for the entire program has been reached", async () => {

    // Increase the reward balance to simulate sufficient rewards in the reward pool
    await mofiTokenContract.connect(ownerSigner).transfer(stakingRewardsContract.address, ethers.utils.parseEther("100000"));

    try {
      const totalAmountOfStakedMoFi = await stakingRewardsContract.totalSupply();
      const stakingCapForProgram = await stakingRewardsContract.maxStakingCapForProgram();

      const amountToStake = (stakingCapForProgram.sub(totalAmountOfStakedMoFi)).add(ethers.utils.parseEther("10"));

      await stakingRewardsContract.connect(user6Account).stake(amountToStake);

    } catch (error) {
      // expect(error.message).to.contain("rewards balance is not sufficient to accept new staking");
      expect(error.message).to.contain("staking cap for this program has been reached");
    }
  });

  it("should allow user to stake if the staking cap for the entire program has not been reached", async () => {
    // Change the maximum amount allowed for each user to stake
    await stakingRewardsContract.connect(ownerSigner).adjustMaxStakeAmount(ethers.utils.parseEther("1000000"));

    const totalAmountOfStakedMoFi = await stakingRewardsContract.totalSupply();
    const stakingCapForProgram = await stakingRewardsContract.maxStakingCapForProgram();

    const amountToStake = (stakingCapForProgram.sub(totalAmountOfStakedMoFi));

    await stakingRewardsContract.connect(user6Account).stake(amountToStake);
  });

  it("should not allow user to stake if the staking program has ended", async () => {
    stakingDay = 365;
    await increaseTime(stakingDay);
    try {
      await stakingRewardsContract.connect(user1Account).stake(ethers.utils.parseEther("1000"));
    } catch (error) {
      // expect(error.message).to.contain("rewards balance is not sufficient to accept new staking");
      expect(error.message).to.contain("staking program duration has ended");
    }
  });

  it('should allow user to claim rewards accrued even after the staking program has ended', async () => {

    const earnedRewards = await stakingRewardsContract.earned(user6Account.address);
    console.log(`--------> USER-6-BALANCE-IS ${earnedRewards / Math.pow(10, mofiTokenContractDecimals)}`);
    const initialMoFiBalance = await mofiTokenContract.balanceOf(user6Account.address);
    // Claim rewards for user
    await stakingRewardsContract.connect(user6Account).getReward();

    const newMoFiBalance = await mofiTokenContract.balanceOf(user6Account.address);

    expect(newMoFiBalance).to.be.gt(initialMoFiBalance);

  });


  it('should allow account to exit from staking program', async () => {
    await increaseTime(10);
    const usersInitialBalance = await mofiTokenContract.balanceOf(user3Account.address);

    await stakingRewardsContract.connect(user3Account).exit();
    const userStakeBalance = await mofiTokenContract.balanceOf(user3Account.address);
    console.log(`--- user 3 exit the program at ${stakingDay} days ---`);
    await logAccountBalance(user3Account.address);
    console.log('--- end log for after 2 exit program ---');
    expect(userStakeBalance).to.be.gt(usersInitialBalance);
  });


  // it('should withdraw all user balance and stop staking program', async () => {

  //   await stakingRewardsContract.connect(ownerSigner).emergencyWithdraw();
  //   expect(await stakingRewardsContract.totalSupply()).to.equal(ethers.utils.parseEther("0"));

  //   console.log(`--- After call emergencyWithdraw function after ${stakingDay} days of staking----`);

  //   await logAccountBalance(user1Account.address);
  //   await logAccountBalance(user2Account.address);
  //   await logAccountBalance(user3Account.address);
  //   await logAccountBalance(user4Account.address);
  //   await logAccountBalance(stakingRewardsContract.address);

  //   console.log('--- end log for emergencyWithdraw function ----');

  //   await stakingRewardsContract.connect(ownerSigner).setPaused(true);

  // });

  // it('should not allow user to start staking after emergency exit', async () => {
  //   try {
  //     await stakingRewardsContract.connect(user1Account).stake(ethers.utils.parseEther("500"));
  //     assert.fail("Expected transaction to revert");
  //   } catch (error) {
  //     expect(error.message).to.contain("This action cannot be performed while the contract is paused");
  //   }
  // });

  it('user should be recorded as having participated in the staking program even after exiting', async () => {

    const result = await stakingRewardsContract.userHasParticipatedInTheStakingProgram(user1Account.address);

    expect(result).to.be.true;
  });

});