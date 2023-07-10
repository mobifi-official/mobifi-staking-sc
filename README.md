# Intro 
soon to be completed

# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract. The original contract is forked from [Sythen](http://synthetix.io) 

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```

/* This is a Solidity smart contract for a staking rewards system. 
It allows users to stake tokens and earn rewards over time, based 
on the amount of tokens they have staked. The contract leverages 
OpenZeppelin libraries for secure and efficient implementation.*/

/* ===== how to use this contract ===== */
Using Remix:
1. Create a new workspace, delete the files in the Contracts folder. then create the exact folder structure as in this repo.
2. Compile and deploy the contact, setting the owenr, distributor and staking token and reward token address

/* ===== calculate the reward program ==== */
Project team need to decide the reward period and reward amount so that engineer can calcualte annual interest rate and set the rewardRate.
For example:
To calculate the amount of XYZ tokens needed to achieve an annual interest rate of 5% for a period of 7 days
Annual interest rate = 5% = 0.05
Weekly interest rate = Annual interest rate / number of weeks in a year = 0.05 / 52 ≈ 0.000961538 (52 weeks in a year)
Reward tokens needed for 7 days = Total staked amount * Weekly interest rate
For example:
if the total staked amount is 100,000 XYZ tokens:
Reward tokens needed for 7 days = 100,000 * 0.000961538 ≈ 96.1538 XYZ tokens
So, you would need to put approximately 96.1538 XYZ tokens as a reward for a 7-day period to achieve an annual interest rate of 5%.
Keep in mind that the total staked amount (_totalSupply) can change over time as users stake and unstake their token (maxStakingCapForProgram is the cap)
You should monitor and adjust the reward tokens accordingly based on the current total staked amount when funding the contract. 
=> Please note that the reawrd is calculated for the entire pool, i.e., the more a user stake, and earlier they stake, the more reward they can earn. 

Continue from step 2...
3. Set the reward duration by calling "setRewardsDuration" function, unit is second
4. Fund the contract. Use an account to send some reward token to the contract address. You will be able to see the contract balance on etherscan.
5. Set the maxStakeAmount, it will limit the cap per user they can stake for the entire staking program.
7. Set the maxStakingCapForProgram, it will set the maximum token can be staked for the entire staking program. 
8. Notify reward amount. call the "notifyRewardAmount" function,to set the reward amount for the upcoming rewards period. Call this fundtion also kicks off the staking program. It will requre step 3 to be set as a requirement.
9. User can start to interact with the contract, but before the can stake their token, they need to call the "approve" function in the ERC20 token contract to approve this staking contract to interact with it. Then it can call the "stake" function to stake token.



