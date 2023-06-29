/**
 * @title Staking Smart Contract
 * @author MobiFi
 * @notice  The code is forked from synthetix and modified by MobiFi, you can use it at your own risk
 * https://github.com/Synthetixio/synthetix
 * https://docs.synthetix.io/contracts/source/contracts/stakingrewards
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

// use the raw code base with v2.3.0 otherwise it throws out error
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/math/SafeMath.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/token/ERC20/ERC20Detailed.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/token/ERC20/SafeERC20.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Inheritance
import "./RewardsDistributionRecipient.sol";
import "./Pausable.sol";

contract StakingRewards is
    RewardsDistributionRecipient,
    ReentrancyGuard,
    Pausable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /***********************************************************************
     *  VARIABLES
     ***********************************************************************/

    IERC20 public rewardsToken; // Object that holds information about the reward pool like wallet address
    IERC20 public stakingToken; // Object that holds information about the staking contract like wallet address
    uint256 public periodFinish = 0; // Duration that the token has been staked
    uint256 public rewardRate = 5; // Interest rate
    uint256 public rewardsDuration = 7 days; // Duration based on the interest will be calculated
    uint256 public stakingStart;
    uint256 public maxStakeAmount = 5000 ether; // Maximum amount of tokens the user is allowed to stake at a given time

    address[] public stakers;

    mapping(address => uint256) public userRewardPerTokenPaid;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _startStakeDate;
    mapping(address => bool) public hasParticipatedInTheStakingProgram;

    /***********************************************************************
     *  CONSTRUCTOR
     *  initializes the contract with the addresses of the owner,
     *  rewards distribution, rewards token, and staking token.
     *  _owner and _rewardsDistribution address can be the same address.
     ***********************************************************************/
    constructor(
        address _owner,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken
    ) public Owned(_owner) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        rewardsDistribution = _rewardsDistribution;
        stakingStart = block.timestamp;
    }

    /***********************************************************************
     * ONLY-OWNER FUNCTIONS
     *
     * These functions can only be called by the owner of the smart contract
     * 
     ***********************************************************************/
    function adjustMaxStakeAmount(
        uint256 _newMaxStakeAmount
    ) external onlyOwner {
        maxStakeAmount = _newMaxStakeAmount;
    }

    /***********************************************************************
     * READ-ONLY FUNCTIONS
     *
     * Various view functions are provided to retrieve information
     * about the contract state,
     * such as total supply, user balances, rewards per token, earned rewards,
     * and reward duration i.e., read-only functions
     ***********************************************************************/

    // This external view function returns the total supply of staked tokens
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // This external view function returns the balance of staked tokens for a given account
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // This fuctions checks if the user has exeeded the max reward period: [rewardsDuration] days.
    // If yes he will get interest rate for [rewardsDuration] days if not we need to compute
    // his staking duration until the emergencywithdraw = (TODAY - WHEN USED STARTED staking)
    function lastTimeRewardApplicable() public view returns (uint256) {
        return
            block.timestamp < stakingStart.add(rewardsDuration)
                ? block.timestamp
                : stakingStart.add(rewardsDuration);
    }

    // This public view function calculates the rewards earned by an account based
    // on the staked amount and stake duration
    function calculateAccountRewards(
        uint256 amount,
        uint256 stakeDuration
    ) public view returns (uint256) {
        return
            amount.div(100).mul(rewardRate).mul(stakeDuration).div(
                rewardsDuration
            );
    }

    // This public view function returns the stake duration for a given account
    function getUserStakeDuration(
        address account
    ) public view returns (uint256) {
        if (_startStakeDate[account] > lastTimeRewardApplicable()) {
            return 0;
        } else {
            return lastTimeRewardApplicable().sub(_startStakeDate[account]);
        }
    }

    function userHasParticipatedInTheStakingProgram(
        address account
    ) public view returns (bool) {
        return hasParticipatedInTheStakingProgram[account];
    }

    // This public view function returns the current block timestamp
    function getCurrentBlockTime() public view returns (uint256) {
        return block.timestamp;
    }

    // This public view function calculates the rewards earned by an account
    // based on their staked amount and stake duration
    function earned(address account) public view returns (uint256) {
        return
            calculateAccountRewards(
                _balances[account],
                getUserStakeDuration(account)
            );
    }

    // This external view function returns the total rewards that can
    // be earned over the rewards duration
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    // This external view function returns the start date of staking for a given account
    function getStartDateAccountStake(
        address account
    ) external view returns (uint256) {
        return _startStakeDate[account];
    }

    // This public view function returns the amount of rewards available in the contract
    function getRewardsAmount() public view returns (uint256) {
        if (address(stakingToken) == address(rewardsToken)) {
            return rewardsToken.balanceOf(address(this)).sub(_totalSupply);
        } else {
            return rewardsToken.balanceOf(address(this));
        }
    }

    /**
     * @dev Returns the balance of unclaimed rewards for an account.
     * @param account The address of the account.
     * @return The unclaimed rewards balance.
     */
    function getUnclaimedRewardsBalanceForAccount(
        address account
    ) public view returns (uint256) {
        // Get the cumulative rewards earned
        uint256 cumulativeRewards = calculateAccountRewards(
            _balances[account],
            getUserStakeDuration(account)
        );

        // Calculate the unclaimed rewards by this user
        uint256 unclaimedRewards = cumulativeRewards >=
            userRewardPerTokenPaid[account]
            ? cumulativeRewards.sub(userRewardPerTokenPaid[account])
            : 0;

        return unclaimedRewards;
    }

    /**
     * @dev Determines whether a user can stake a certain amount of tokens based on the available rewards.
     * @param amount The amount of tokens to be staked.
     * @return A boolean indicating whether the user can stake the specified amount.
     */
    function gateKeeper(uint256 amount) public view returns (bool) {
        // Calculate the remaining stake duration based on the staking start time and rewards duration
        uint256 timeSinceStart = block.timestamp.sub(stakingStart);
        uint256 stakeDuration = rewardsDuration > timeSinceStart
            ? rewardsDuration.sub(timeSinceStart)
            : 0;
        // Check if the stake duration is greater than 0 and the current block timestamp is within the staking duration.
        // If `true`, we proceed on to calculate the amount of rewards available in the reward pool as well as
        // the amount of rewards needed based on the amount the user wants to stake
        if (
            stakeDuration > 0 &&
            block.timestamp < stakingStart.add(rewardsDuration)
        ) {
            // Calculate the rewards needed for the specified amount based on the reward rate and stake duration
            uint256 rewardsNeeded = amount
                .div(100)
                .mul(rewardRate)
                .mul(stakeDuration)
                .div(rewardsDuration);
            // Get the current MOFI rewards balance in the contract
            uint256 rewardsBalance = rewardsToken.balanceOf(address(this));
            // Check if the MOFI rewards balance is greater than or equal to the rewards needed
            return rewardsBalance >= rewardsNeeded;
        } else {
            // If the stake duration is zero or the current block timestamp is outside the staking duration, return [false]
            return false;
        }
    }

    /***********************************************************************
     * FUNCTIONS
     *
     * These functions enable users to interact with the contract and
     * perform actions such as
     * stake: Stake a specified amount of tokens.
     * withdraw: Withdraw a specified amount of staked tokens.
     * getReward: Claim earned rewards.
     * exit: Withdraw all staked tokens and claim all earned rewards.
     ***********************************************************************/

    /***********************************************************************
     * Function: stake
     * Staking plays the role of depositing. It takes an amount of tokens
     * from a wallet A and it transfers it to deployer of the contract (i.e. wallet B),
     * where it will be held for a period of time in order
     * to produce a return to the user A paid by the user B.
     *
     * Inputs
     * 1. the amount of tokens to be deposited
     *
     * Outputs
     * 1. An updated balance of tokens which are currently staked
     ***********************************************************************/
    function stake(
        uint256 amount
    ) external nonReentrant notPaused rewardsBalanceSufficient(amount) {
        // This line checks if the amount to be staked is greater than zero. If it is not, it throws
        // an exception with the error message "Cannot stake 0". This ensures that the amount being
        // staked is a positive value
        require(amount > 0, "Cannot stake 0");

        // This line ensures that the msg.sender does not have an existing stake. It checks if the
        // balance of the msg.sender is zero. If the balance is not zero, it throws an exception with
        // the error message "You already have a stake. Please withdraw to stake another amount."
        // This prevents users from staking additional amounts without first withdrawing their previous stake
        require(
            _balances[msg.sender] == 0,
            "You already have a stake. Please withdraw to stake another amount."
        );
        // This line checks if the sum of the current balance of the msg.sender and the amount being staked is
        // less than or equal to the maxStakeAmount. If the sum exceeds the maxStakeAmount, it throws an
        // exception with the error message "Exceeds maximum stake amount".
        // This ensures that the user does not exceed the maximum allowed stake amount
        require(
            maxStakeAmount >= _balances[msg.sender].add(amount),
            "Exceeds maximum stake amount"
        );

        // Update total amount of staking token
        _totalSupply = _totalSupply.add(amount);
        // store balance current staking action plus staked amount
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        // store start staking time
        _startStakeDate[msg.sender] = block.timestamp;
        userRewardPerTokenPaid[msg.sender] = 0;
        // Add user to stakers array if they're not already in it
        if (_balances[msg.sender] == amount) {
            stakers.push(msg.sender);
        }

        if (!hasParticipatedInTheStakingProgram[msg.sender]) {
            hasParticipatedInTheStakingProgram[msg.sender] = true;
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /***********************************************************************
     * Function: withdraw
     *
     * Input
     * 1. the amount of tokens to be deposited
     *
     * Process
     * It takes an amount of tokens
     * from the deployer of the contract (i.e. wallet B) and it transfers
     * it back to the wallet A
     *
     * Output
     * 1. An updated balance of tokens which are currently staked
     ***********************************************************************/

    function withdraw(uint256 amount) public nonReentrant {
        // This line checks if the amount is greater than zero. If it is not, it throws an exception with the error
        // message "Cannot withdraw 0". This ensures that the amount to be withdrawn is a positive value
        require(amount > 0, "Cannot withdraw 0");

        // Check if the staker has any rewards they haven't claimed yet
        uint256 unclaimedRewards = getUnclaimedRewardsBalanceForAccount(
            msg.sender
        );

        // If they have any unclaimed rewards, we add this number to the mapping of the rewards
        // paid out to this particular user. This servers the purpose
        // of keeping track of the rewards paid out to each user
        if (unclaimedRewards > 0) {
            userRewardPerTokenPaid[msg.sender] = userRewardPerTokenPaid[
                msg.sender
            ].add(unclaimedRewards);

            // We then send said rewards earned on the staked tokens to the staker's wallet address
            rewardsToken.safeTransfer(msg.sender, unclaimedRewards);
        }

        // Calculate the reduced stake duration based on the partial withdrawal
        uint256 reducedStakeDuration = 0;

        // If the user's balance (_balances[msg.sender]) is greater than the withdrawal amount (amount), it means
        // the user is not withdrawing their entire stake. In that case, the function [getUserStakeDuration]
        // is called to get the stake duration for the user.
        if (_balances[msg.sender] > amount) {
            // The stake duration is then calculated by multiplying the user's stake duration with the difference
            // between their current balance and the withdrawal amount, and dividing it by their current balance.
            // The resulting value is stored in the [reducedStakeDuration] variable
            reducedStakeDuration = getUserStakeDuration(msg.sender)
                .mul(_balances[msg.sender].sub(amount))
                .div(_balances[msg.sender]);
        }

        // Update the total supply and balance of the msg.sender after the withdrawal. The amount is subtracted
        // from both _totalSupply and _balances[msg.sender] to reflect the reduced staking amount
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        // Remove user from stakers array if they've withdrawn all their tokens
        if (_balances[msg.sender] == 0) {
            for (uint i = 0; i < stakers.length; i++) {
                if (stakers[i] == msg.sender) {
                    stakers[i] = stakers[stakers.length - 1];
                    stakers.pop();
                    break;
                }
            }
        }

        // The stake start date for the msg.sender is updated. It is set to the current timestamp (lastTimeRewardApplicable())
        // minus the reducedStakeDuration. This ensures that the stake start date is adjusted based on the partial withdrawal
        _startStakeDate[msg.sender] = lastTimeRewardApplicable().sub(
            reducedStakeDuration
        );
        // Transfer the amount of tokens the user staked back to them
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant {
        // Calculate the newly earned rewards by this user
        uint256 unclaimedRewards = getUnclaimedRewardsBalanceForAccount(
            msg.sender
        );

        if (unclaimedRewards > 0) {
            userRewardPerTokenPaid[msg.sender] = userRewardPerTokenPaid[
                msg.sender
            ].add(unclaimedRewards);

            rewardsToken.safeTransfer(msg.sender, unclaimedRewards);
            emit RewardPaid(msg.sender, unclaimedRewards);
        }
    }

    function exit() external {
        getReward();
        withdraw(_balances[msg.sender]);
    }

    /***********************************************************************
     * INTERNAL FUNCTIONS
     ***********************************************************************/
    modifier rewardsBalanceSufficient(uint256 amount) {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < stakers.length; i++) {
            address account = stakers[i];
            uint256 stakeUserDuration = stakingStart.add(rewardsDuration).sub(
                _startStakeDate[account]
            );
            totalRewards = totalRewards.add(
                calculateAccountRewards(_balances[account], stakeUserDuration)
            );
        }

        uint256 stakeDuration = stakingStart.add(rewardsDuration).sub(
            block.timestamp
        );

        uint256 newRewards = calculateAccountRewards(amount, stakeDuration);

        uint256 rewardsAmount = getRewardsAmount();

        require(
            rewardsAmount >= totalRewards,
            "rewards balance is not sufficient to accept new staking"
        );
        _;
    }

    /***********************************************************************
     * RESTRICTED FUNCTIONS
     *
     * Functions that can only be called by specific roles, such as the owner or rewards distributor
     * recoverERC20: Allows the owner to recover ERC20 tokens accidentally sent to the contract.
     * emergencyWithdraw:
     * restartStakingProgram:
     ***********************************************************************/

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyOwner {
        require(
            tokenAddress != address(stakingToken),
            "Cannot withdraw the staking token"
        );
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 totalWithdrawRewards = 0;
        // Iterate through all stakers
        for (uint i = 0; i < stakers.length; i++) {
            // Transfer staked tokens back to staker

            // The amount of MOFIs the user had deposited
            uint amountToRefund = _balances[stakers[i]];

            // Compute the interest rate to be received based
            // on the dates that the user has been in the program (until emergency reward)
            uint userRewards = calculateAccountRewards(
                _balances[stakers[i]],
                getUserStakeDuration(stakers[i])
            ).sub(userRewardPerTokenPaid[stakers[i]]);

            totalWithdrawRewards = totalWithdrawRewards.add(userRewards);

            _balances[stakers[i]] = 0;

            _totalSupply = _totalSupply.sub(amountToRefund);
            periodFinish = block.timestamp;
            stakingToken.safeTransfer(stakers[i], amountToRefund);
            rewardsToken.safeTransfer(stakers[i], userRewards);
        }

        emit EmergencyWithdraw(block.timestamp);
    }

    /**
    
     */
    function restartStakingProgram(
        uint256 _rewardsRate,
        uint256 _rewardsDuration
    ) external onlyRewardsDistribution {
        require(
            block.timestamp > _rewardsDuration,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardRate = _rewardsRate;
        rewardsDuration = _rewardsDuration;
        stakingStart = block.timestamp;
        periodFinish = stakingStart.add(rewardsDuration);
        emit RewardsDurationUpdated(rewardsDuration);
        emit RewardAdded(_rewardsRate);
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event EmergencyWithdraw(uint256 timeblock);
}
