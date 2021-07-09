// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./interfaces/Interfaces.sol";
import "./libraries/TransferHelper.sol";
import "./RewardPool.sol";

contract BaseLake {
	uint256 totalProductivity;
	uint256 accAmountPerShare;
	uint256 accAmountPerShareSwan;
	uint256 public totalShare;
	uint256 public mintedShare;
	uint256 public mintedShareSwan;
	uint256 public totalShareSwan;
	uint256 public mintCumulation;

	address public shareToken;
	address public swan;
	RewardPool public rewardPool;

	string public name;
	string public symbol;
	uint8 public decimals;
	uint256 public totalSupply;
	uint256 public lastRewardBlock;

	mapping(address => uint256) public balanceOf;
	mapping(address => mapping(address => uint256)) public allowance;

	event Mint(address indexed user, uint256 amount);
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(
		address indexed owner,
		address indexed spender,
		uint256 value
	);
	struct UserInfo {
		uint256 amount; // How many tokens the user has provided.
		uint256 rewardDebt; // Reward debt.
		uint256 rewardEarn; // Reward earn and not minted
		uint256 rewardDebtSwan;
		uint256 rewardEarnSwan;
	}

	mapping(address => UserInfo) public users;

	function _setShareToken(address _shareToken) internal {
		shareToken = _shareToken;
	}

	function _setRewardPool(address _rewardPool) internal {
		rewardPool = RewardPool(_rewardPool);
	}

	// Update reward variables of the given pool to be up-to-date.
	function _update() internal virtual {
		if (totalProductivity == 0) {
			lastRewardBlock = block.number;
			return;
		}
		(uint256 swanCurrentReward, uint256 poolTokenCurrentReward) =
			_currentReward();
		uint256 multiplier = block.number - lastRewardBlock;
		accAmountPerShare =
			accAmountPerShare +
			((poolTokenCurrentReward * multiplier * 1e27) / totalProductivity);
		totalShare = totalShare + (poolTokenCurrentReward * multiplier);
		accAmountPerShareSwan =
			accAmountPerShareSwan +
			((swanCurrentReward * multiplier * 1e27) / totalProductivity);
		totalShareSwan = totalShareSwan + (swanCurrentReward * multiplier);
		lastRewardBlock = block.number;
	}

	function _currentReward() internal view virtual returns (uint256, uint256) {
		uint256 swanRewards =
			(mintedShareSwan +
				IERC20(swan).balanceOf(address(this)) -
				totalShareSwan) / 1296000;
		uint256 poolTokenRewards =
			(mintedShare + rewardPool.balance() - totalShare) / 1296000;

		return (swanRewards, poolTokenRewards);
	}

	// Audit user's reward to be up-to-date
	function _audit(address user, uint256 newAmount) internal virtual {
		UserInfo storage userInfo = users[user];
		uint256 _amount = userInfo.amount;
		if (userInfo.amount > 0) {
			uint256 pendingPoolTokens =
				(userInfo.amount * accAmountPerShare) /
					1e27 -
					userInfo.rewardDebt;
			userInfo.rewardEarn = userInfo.rewardEarn + pendingPoolTokens;
			mintCumulation = mintCumulation + pendingPoolTokens;

			uint256 pendingSwans =
				(userInfo.amount * accAmountPerShareSwan) /
					1e27 -
					userInfo.rewardDebtSwan;
			userInfo.rewardEarnSwan = userInfo.rewardEarnSwan + pendingSwans;
		}
		userInfo.amount = newAmount;
		userInfo.rewardDebtSwan =
			(userInfo.amount * accAmountPerShareSwan) /
			1e27;
		userInfo.rewardDebt = (userInfo.amount * accAmountPerShare) / 1e27;
	}

	// External function call
	// This function increase user's productivity and updates the global productivity.
	// the users' actual share percentage will calculated by:
	// Formula:     user_productivity / global_productivity
	function _increaseProductivity(address user, uint256 value)
		internal
		virtual
		returns (bool)
	{
		require(value > 0, "PRODUCTIVITY_VALUE_MUST_BE_GREATER_THAN_ZERO");

		_update();
		_audit(user, users[user].amount + value);
		totalProductivity = totalProductivity + value;
		return true;
	}

	// External function call
	// This function will decreases user's productivity by value, and updates the global productivity
	// it will record which block this is happenning and accumulates the area of (productivity * time)
	function _decreaseProductivity(address user, uint256 value)
		internal
		virtual
		returns (bool)
	{
		_update();
		_audit(user, users[user].amount - value);
		totalProductivity = totalProductivity - value;

		return true;
	}

	function _takeWithAddress(address user)
		public
		view
		returns (uint256, uint256)
	{
		UserInfo memory userInfo = users[user];
		uint256 _accAmountPerShare = accAmountPerShare;
		uint256 _accAmountPerShareSwan = accAmountPerShareSwan;
		// uint256 lpSupply = totalProductivity;
		if (totalProductivity != 0) {
			(uint256 swanCurrentReward, uint256 poolTokenCurrentReward) =
				_currentReward();
			_accAmountPerShare =
				_accAmountPerShare +
				((poolTokenCurrentReward * 1e27) / totalProductivity);
			_accAmountPerShareSwan =
				_accAmountPerShareSwan +
				(swanCurrentReward * 1e27) /
				totalProductivity;
		}
		return (
			(userInfo.amount * _accAmountPerShare) /
				1e27 +
				userInfo.rewardEarn -
				userInfo.rewardDebt,
			(userInfo.amount * _accAmountPerShareSwan) /
				1e27 +
				userInfo.rewardEarnSwan -
				userInfo.rewardDebtSwan
		);
	}

	// External function call
	// When user calls this function, it will calculate how many token will mint to user from his productivity * time
	// Also it calculates global token supply from last time the user mint to this time.
	function _mintReward(address user) internal virtual returns (uint256) {
		UserInfo storage userInfo = users[user];
		_update();
		_audit(user, userInfo.amount);
		uint256 amount = userInfo.rewardEarn;
		uint256 swanAmount = userInfo.rewardEarnSwan;
		if (amount > 0) rewardPool.transfer(msg.sender, amount);
		if (swanAmount > 0)
			TransferHelper.safeTransfer(swan, msg.sender, swanAmount);
		userInfo.rewardEarn = 0;
		userInfo.rewardEarnSwan = 0;
		mintedShare += amount;
		mintedShareSwan += swanAmount;
		return amount;
	}

	// Returns how many productivity a user has and global has.
	function getProductivity(address user)
		public
		view
		virtual
		returns (uint256, uint256)
	{
		return (users[user].amount, totalProductivity);
	}

	// Returns the current gorss product rate.
	function interestsPerBlock() public view virtual returns (uint256) {
		return accAmountPerShare;
	}

	function _mint(address to, uint256 value) internal {
		totalSupply = totalSupply + value;
		balanceOf[to] = balanceOf[to] + value;
		emit Transfer(address(0), to, value);
	}

	constructor(string memory _name, string memory _symbol) {
		name = _name;
		symbol = _symbol;
	}

	receive() external payable {}

	function _burn(address from, uint256 value) internal {
		balanceOf[from] = balanceOf[from] - value;
		totalSupply = totalSupply - value;
		emit Transfer(from, address(0), value);
	}

	function _transfer(
		address from,
		address to,
		uint256 value
	) private {
		require(to != address(0), "Can't transfer to zero address");
		require(balanceOf[from] >= value, "ERC20Token: INSUFFICIENT_BALANCE");
		balanceOf[from] = balanceOf[from] - value;
		balanceOf[to] = balanceOf[to] + value;

		_decreaseProductivity(from, value);
		_increaseProductivity(to, value);
		emit Transfer(from, to, value);
	}

	function approve(address spender, uint256 value) external returns (bool) {
		allowance[msg.sender][spender] = value;
		emit Approval(msg.sender, spender, value);
		return true;
	}

	function transfer(address to, uint256 value) external returns (bool) {
		_transfer(msg.sender, to, value);
		return true;
	}

	function transferFrom(
		address from,
		address to,
		uint256 value
	) external returns (bool) {
		require(
			allowance[from][msg.sender] >= value,
			"ERC20Token: INSUFFICIENT_ALLOWANCE"
		);
		allowance[from][msg.sender] = allowance[from][msg.sender] - value;
		_transfer(from, to, value);
		return true;
	}
}
