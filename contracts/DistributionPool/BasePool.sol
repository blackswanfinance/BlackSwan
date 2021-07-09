// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "../interfaces/Interfaces.sol";
import "../libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BasePool is OwnableUpgradeable {
	uint256 totalProductivity;

	uint256 accAmountPerShareSwan;

	uint256 public mintedShareSwan;
	uint256 public totalShareSwan;
	uint256 public mintCumulation;

	address public shareToken;
	address public swan;
	string public name;
	string public symbol;
	uint8 public decimals;
	uint256 public totalSupply;
	uint256 public lastRewardBlock;
	uint256 public rewardsPerBlock;
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
		uint256 rewardEarnSwan; // Reward earn and not minted
		uint256 rewardDebtSwan;
	}

	mapping(address => UserInfo) public users;

	function _setShareToken(address _shareToken) internal {
		shareToken = _shareToken;
	}

	function setRewardsPerBlock(uint256 _rewardsPerBlock) external onlyOwner {
		rewardsPerBlock = _rewardsPerBlock;
	}

	// Update reward variables of the given pool to be up-to-date.
	function _update() internal virtual {
		if (totalProductivity == 0) {
			lastRewardBlock = block.number;
			return;
		}
		uint256 rewardBalance =
			mintedShareSwan +
				IERC20(swan).balanceOf(address(this)) -
				totalShareSwan;

		uint256 multiplier = block.number - lastRewardBlock;
		uint256 rewardsToShare = multiplier * rewardsPerBlock;
		if (rewardsToShare > rewardBalance) {
			rewardsToShare = rewardBalance;
		}
		accAmountPerShareSwan =
			accAmountPerShareSwan +
			((rewardsToShare * 1e27) / totalProductivity);
		totalShareSwan = totalShareSwan + rewardsToShare;
		lastRewardBlock = block.number;
	}

	// Audit user's reward to be up-to-date
	function _audit(address user, uint256 newAmount) internal virtual {
		UserInfo storage userInfo = users[user];
		if (userInfo.amount > 0) {
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

	function takeWithAddress(address user) public view returns (uint256) {
		UserInfo memory userInfo = users[user];
		uint256 _accAmountPerShare = accAmountPerShareSwan;
		// uint256 lpSupply = totalProductivity;
		uint256 pending;
		if (totalProductivity != 0) {
			uint256 rewardBalance =
				mintedShareSwan +
					IERC20(swan).balanceOf(address(this)) -
					totalShareSwan;

			uint256 multiplier = block.number - lastRewardBlock;
			uint256 rewardsToShare = multiplier * rewardsPerBlock;
			if (rewardsToShare > rewardBalance) {
				rewardsToShare = rewardBalance;
			}
			_accAmountPerShare =
				_accAmountPerShare +
				((rewardsToShare * 1e27) / totalProductivity);
			pending =
				(userInfo.amount * _accAmountPerShare) /
				1e27 -
				userInfo.rewardDebtSwan;
		}
		return pending + userInfo.rewardEarnSwan;
	}

	// External function call
	// When user calls this function, it will calculate how many token will mint to user from his productivity * time
	// Also it calculates global token supply from last time the user mint to this time.
	function _mintReward(address user) internal virtual returns (uint256) {
		UserInfo storage userInfo = users[user];
		_update();
		_audit(user, userInfo.amount);
		uint256 swanAmount = users[user].rewardEarnSwan;
		if (swanAmount > 0)
			TransferHelper.safeTransfer(swan, msg.sender, swanAmount);
		userInfo.rewardEarnSwan = 0;
		mintedShareSwan += swanAmount;
		return swanAmount;
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
		return accAmountPerShareSwan;
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
