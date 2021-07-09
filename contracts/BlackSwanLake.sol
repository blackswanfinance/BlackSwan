// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./LakeBase.sol";

contract BlackSwanLake is BaseLake {
	IERC20 public token; // Token address which is Pool token it is the same token for rewards and stake
	/**
	 * @dev Emitted when `staker` stake `value` tokens of `token`
	 */
	event Staked(address indexed staker, address token, uint256 value);
	/**
	 * @dev Emitted when `staker` withdraws their stake `value` tokens and contracts balance will
	 * be reduced to`remainingBalance`.
	 */
	event StakeWithdraw(address indexed staker, address token, uint256 value);

	constructor(
		string memory _name,
		string memory _symbol,
		address _token,
		address _swanToken,
		address _rewardPool
	) BaseLake(_name, _symbol) {
		token = IERC20(_token);
		swan = _swanToken;
		decimals = 18;
		rewardPool = RewardPool(_rewardPool);
	}

	function stake(uint256 _amount) external {
		require(
			token.transferFrom(msg.sender, address(this), _amount),
			"transferFrom failed, make sure you approved token transfer"
		);
		_mint(msg.sender, _amount); // mint Staking token for staker
		_increaseProductivity(msg.sender, _amount);
		emit Staked(msg.sender, address(token), _amount);
	}

	function withdrawStake(uint256 _amount) external {
		(uint256 userProductivity, ) = getProductivity(msg.sender);
		require(userProductivity >= _amount, "Not enough token staked");
		_burn(msg.sender, _amount);
		_decreaseProductivity(msg.sender, _amount);
		_mintReward(msg.sender);
		token.transfer(msg.sender, _amount);
		emit StakeWithdraw(msg.sender, address(token), _amount);
	}
	function claimRewards() external{

		_mintReward(msg.sender);
	}
}
