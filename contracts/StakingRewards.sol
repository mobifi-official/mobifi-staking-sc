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
// import "./interfaces/IStakingRewards.sol"; // TODO: match the logic for this interface
import "./RewardsDistributionRecipient.sol";
import "./Pausable.sol";
import "hardhat/console.sol";

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

    uint256 public constant maxStakeAmount = 5000 ether;

    address[] public stakers;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _startStakeDate;

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
     * READ-ONLY FUNCTIONS
     *
     * Various view functions are provided to retrieve information
     * about the contract state,
     * such as total supply, user balances, rewards per token, earned rewards,
     * and reward duration i.e., read-only functions
     ***********************************************************************/

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // This fuctions checks if the user has exeeded the max reward period (i.365 day).
    // If yes he will get interest rate for 365 days if not we need to compute
    // his staking duration until the emergencywithdraw = (TODAY - WHEN USED STARTED staking)
    function lastTimeRewardApplicable() public view returns (uint256) {
        return
            block.timestamp < stakingStart.add(rewardsDuration)
                ? block.timestamp
                : stakingStart.add(rewardsDuration);
    }

    function calculateAccountRewards(
        uint256 amount,
        uint256 stakeDuration
    ) public view returns (uint256) {
        if (amount < 0) {
            return 0;
        } else {
            return
                amount.div(100).mul(rewardRate).mul(stakeDuration).div(
                    rewardsDuration
                );
        }
    }

    function getUserStakeDuration(
        address account
    ) public view returns (uint256) {
        return lastTimeRewardApplicable().sub(_startStakeDate[account]);
    }

    function getCurrentBlockTime() public view returns (uint256) {
        return block.timestamp;
    }

    function earned(address account) public view returns (uint256) {
        return
            calculateAccountRewards(
                _balances[account],
                getUserStakeDuration(account)
            );
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function getStartDateAccountStake(
        address account
    ) external view returns (uint256) {
        return _startStakeDate[account];
    }

    function getRewardsAmount() public view returns (uint256) {
        if (address(stakingToken) == address(rewardsToken)) {
            return rewardsToken.balanceOf(address(this)).sub(_totalSupply);
        } else {
            return rewardsToken.balanceOf(address(this));
        }
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
        require(amount > 0, "Cannot stake 0");

        require(
            _balances[msg.sender] <= 0,
            "You already stake please exit to stake another amount"
        );

        require(
            maxStakeAmount >= _balances[msg.sender].add(amount),
            "Exceeds maximum stake amount"
        );

        // update total amount of staking token
        _totalSupply = _totalSupply.add(amount);
        // store balance current staking action plus staked amount
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        // store start staking time
        _startStakeDate[msg.sender] = block.timestamp;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        userRewardPerTokenPaid[msg.sender] = 0;

        // Add user to stakers array if they're not already in it
        if (_balances[msg.sender] == amount) {
            stakers.push(msg.sender);
        }

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
        require(amount > 0, "Cannot withdraw 0");

        // update total suplay of staking token
        _totalSupply = _totalSupply.sub(amount);
        // update account balance
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _startStakeDate[msg.sender] = 0;

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

        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);

        // Check if user has any rewards, and send them to thir wallet address
        uint256 reward = calculateAccountRewards(
            _balances[msg.sender],
            getUserStakeDuration(msg.sender)
        );
        if (reward > 0) {
            rewards[msg.sender] = 0;
            userRewardPerTokenPaid[msg.sender] = userRewardPerTokenPaid[
                msg.sender
            ].add(reward);

            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
        //_startStakeDate[msg.sender] = 0;
    }

    function getReward() public nonReentrant {
        uint256 reward = calculateAccountRewards(
            _balances[msg.sender],
            getUserStakeDuration(msg.sender)
        );
        if (reward > 0) {
            rewards[msg.sender] = 0;
            userRewardPerTokenPaid[msg.sender] = userRewardPerTokenPaid[
                msg.sender
            ].add(reward);

            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
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
