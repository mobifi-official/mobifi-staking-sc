/**
 * @title Staking Smart Contract
 * @author MobiFi
 * @notice  The code is forked from synthetix and modified by MobiFi, you can use it at your own risk
 * https://github.com/Synthetixio/synthetix
 * https://docs.synthetix.io/contracts/source/contracts/stakingrewards
 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;

// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/math/SafeMath.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/token/ERC20/ERC20Detailed.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/token/ERC20/SafeERC20.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v2.3.0/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Inheritance
import "./interfaces/IStakingRewards.sol";
import "./RewardsDistributionRecipient.sol";
import "./Pausable.sol";

// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingRewards is
    IStakingRewards,
    RewardsDistributionRecipient,
    ReentrancyGuard,
    Pausable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 14 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    // Will be used to record when the staking program started
    uint256 public stakingStart;
    // Maximum amount of tokens the user is allowed to stake for the duration of the program
    uint256 public maxStakeAmount = 10000 ether;

    uint256 public maxStakingCapForProgram;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public hasParticipatedInTheStakingProgram;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Constructor function
     * @param _owner The address of the contract owner
     * @param _rewardsDistribution The address of the rewards distribution contract. It can be the same as [owner] above
     * @param _rewardsToken The address of the rewards token contract
     * @param _stakingToken The address of the staking token contract
     * @param _maxStakingCapForProgram The maximum staking cap for the program
     */
    constructor(
        address _owner,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken,
        uint256 _maxStakingCapForProgram
    ) public Owned(_owner) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        rewardsDistribution = _rewardsDistribution;
        stakingStart = block.timestamp;
        maxStakingCapForProgram = _maxStakingCapForProgram;
    }

    /* ========== VIEWS ========== */

    /**

    * @dev Returns the total supply of staked tokens.
    * @return The total supply of staked tokens.
    */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**

    * @dev Returns the balance of staked tokens for a specific account.
    * @param account The address of the account.
    * @return The balance of staked tokens for the account.
    */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /**

    * @dev Returns the last time rewards were applicable.
    * @return The last time rewards were applicable.
    */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @dev Returns whether a given user, identified by their address has participated
     * in the staking program. By `participated in the staking program", we mean if
     * they have staked at-least once. This information is required in the MoBiFi FE
     * app to how the relevant cards in the wallet page depending on what this method
     * returns
     * @param account The address of the account.
     * @return Whether or not a user has staked at-least once
     */
    function userHasParticipatedInTheStakingProgram(
        address account
    ) public view returns (bool) {
        return hasParticipatedInTheStakingProgram[account];
    }

    /**

    * @dev Returns the current reward per token.
    * @return The current reward per token.
    */
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(_totalSupply)
            );
    }

    /**

    * @dev Returns the amount of rewards earned by an account.
    * @param account The address of the account.
    * @return The amount of rewards earned by the account.
    */
    function earned(address account) public view returns (uint256) {
        return
            _balances[account]
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    /**

    * @dev Returns the total reward amount for the specified duration.
    * @return The total reward amount for the duration.
    */
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @dev Staking plays the role of depositing. It takes an amount of tokens
     * from a wallet A and it transfers it to deployer of the contract (i.e. wallet B),
     * where it will be held for a period of time in order
     * to produce a return to the user A paid by the user B.
     * @param amount --> the amount of tokens to be deposited
     *
     */
    function stake(
        uint256 amount
    )
        external
        nonReentrant
        notPaused
        rewardsProgramIsStillOngoing
        gateKeeper(amount)
        updateReward(msg.sender)
    {
        // This line checks if the amount to be staked is greater than zero. If it is not, it throws
        // an exception with the error message "Cannot stake 0".
        require(amount > 0, "Cannot stake 0");

        // Calculate the remaining available stake amount by subtracting the current staked amount
        // from the maxStakeAmount variable
        uint256 remainingStakeAmount = maxStakeAmount.sub(
            _balances[msg.sender]
        );

        // Check if the remaining stake amount is greater than or equal to the amount being staked
        require(remainingStakeAmount >= amount, "Exceeds maximum stake amount");

        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        if (!hasParticipatedInTheStakingProgram[msg.sender]) {
            hasParticipatedInTheStakingProgram[msg.sender] = true;
        }
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /**

    * @dev Withdraws a specified amount of staking tokens from the contract and transfers them back to the sender.
    * @param amount The amount of staking tokens to withdraw.
    */
    function withdraw(
        uint256 amount
    ) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**

    * @dev Claims and transfers the accumulated rewards to the sender.
    */
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**

    * @dev Withdraws the full staking balance and claims the accumulated rewards.
    */
    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**

    @dev Notifies the contract about the new reward amount to be distributed to stakers.
    In other words, it sets the reward amount for the upcoming rewards period
    Only the rewards distribution address can call this function.
    @param reward The amount of reward to be distributed.
    */ 
    function notifyRewardAmount(
        uint256 reward
    ) external onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        require(
            rewardRate <= balance.div(rewardsDuration),
            "Provided reward too high"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

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

    /**
    * @dev Adjusts the maximum stake amount allowed per user.
    * @param _newMaxStakeAmount The new maximum stake amount.
     Only callable by the contract owner.
    */
    function adjustMaxStakeAmount(
        uint256 _newMaxStakeAmount
    ) external onlyOwner {
        maxStakeAmount = _newMaxStakeAmount;
    }

    /**

    * @dev Adjusts the staking cap for the program.
    * @param _newCap The new staking cap for the program.
    Only callable by the contract owner.
    */
    function adjustStakingCapForProgram(uint256 _newCap) external onlyOwner {
        maxStakingCapForProgram = _newCap;
    }

    /* ========== MODIFIERS ========== */

    /**

    @dev Modifier that updates the reward variables before executing the function.
    It calculates and updates the rewardPerTokenStored and lastUpdateTime.
    If the account is not the zero address, it also updates the rewards and userRewardPerTokenPaid for the account.
    */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // This modifier is used to check whether the staking program is still ongoing
    // If it is not, it returns `false`, and the user will not be able to continue
    // with the staking activity
    modifier rewardsProgramIsStillOngoing() {
        // Calculate the remaining stake duration based on the staking start time and rewards duration
        uint256 timeSinceStart = block.timestamp.sub(stakingStart);
        uint256 stakeDuration = rewardsDuration > timeSinceStart
            ? rewardsDuration.sub(timeSinceStart)
            : 0;
        // Check if the stake duration is greater than 0 and the current block timestamp is within the staking duration.
        bool programIsStillOngoing = stakeDuration > 0 &&
            block.timestamp < stakingStart.add(rewardsDuration);

        require(programIsStillOngoing, "staking program duration has ended");
        _;
    }

    modifier gateKeeper(uint256 amount) {
        // Calculate the remaining available staking capacity by subtracting the total staked amount from the maxStakingCapForProgram
        uint256 remainingStakingCapacity = maxStakingCapForProgram.sub(
            _totalSupply
        );

        // Check if the remaining staking capacity is greater than or equal to the amount being staked
        require(
            remainingStakingCapacity >= amount,
            "staking cap for this program has been reached"
        );

        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
}
