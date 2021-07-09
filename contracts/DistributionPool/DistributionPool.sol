// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./BasePool.sol";
import "../AddressBook.sol";

contract DistributionPool is BasePool {
	IERC20 public token; // Token address which is Pool token it is the same token for rewards and stake
	uint256 public totalFees;
	uint256 feeAmount;
	AddressBook public addressBook;
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
		AddressBook _addressBook
	) BasePool(_name, _symbol) {
		__Ownable_init();
		token = IERC20(_token);
		swan = _swanToken;
		_setShareToken(_swanToken);
		addressBook = _addressBook;
		decimals = token.decimals();
		feeAmount = 5;
	}

	function stake(uint256 _amount) external {
		require(
			token.transferFrom(_msgSender(), address(this), _amount),
			"transferFrom failed, make sure you approved token transfer"
		);
		address feeCollector = addressBook.getAddress("FEE_COLLECTOR");
		uint256 stakeAmount = (_amount * (100 - feeAmount)) / 100;
		_mint(_msgSender(), stakeAmount); // mint Staking token for staker
		totalFees += (_amount - stakeAmount);
		token.transfer(feeCollector, (_amount - stakeAmount));
		_increaseProductivity(_msgSender(), stakeAmount);
		emit Staked(_msgSender(), address(token), stakeAmount);
	}

	function withdrawStake(uint256 _amount) external {
		(uint256 userProductivity, ) = getProductivity(_msgSender());
		require(userProductivity >= _amount, "Not enough token staked");
		_burn(_msgSender(), _amount);
		_decreaseProductivity(_msgSender(), _amount);
		_mintReward(_msgSender());
		token.transfer(_msgSender(), _amount);
		emit StakeWithdraw(_msgSender(), address(token), _amount);
	}

	function claimRewards() external {
		_mintReward(_msgSender());
	}
}
