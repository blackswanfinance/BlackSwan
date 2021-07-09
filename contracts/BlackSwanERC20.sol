// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./AddressBook.sol";

contract BlackSwanERC20 is ERC20Upgradeable, OwnableUpgradeable {
	uint256 public founderOneAllocation;
	uint256 public founderTwoAllocation;
	uint256 public founderOneMonthlyClaim;
	uint256 public founderTwoMonthlyClaim;
	uint256 public founderOneLastClaim;
	uint256 public founderTwoLastClaim;
	uint256 public developmentAllocation;
	uint256 public developmentMonhlyClaim;
	uint256 public developmentLastClaim;

	AddressBook public addressBook;
	uint256 public buyLimit;
	uint256 public sellLimit;
	modifier onlyMonetaryPolicy() {
		require(
			_msgSender() == addressBook.getAddress("POLICY"),
			"Only Monetary Policy can call this method"
		);
		_;
	}
	modifier onlyFund() {
		require(
			_msgSender() == addressBook.getAddress("FUND_ADDRESS"),
			"Only Fund can call this method"
		);
		_;
	}

	uint256 private constant MAX_SUPPLY = type(uint256).max; // (2^128) - 1
	event LogRebalance(uint256 indexed epoch, uint256 totalSupply);
	event LogMonetaryPolicyUpdated(address monetaryPolicy);
	event EmergencyFundSupplied(uint256 timestamp, uint256 amount);

	function initialize(
		address _owner,
		uint256 _initialSupply,
		uint256 _founderOneAllocation,
		uint256 _founderTwoAllocation,
		uint256 _developmentAllocation,
		AddressBook _addressBook
	) public initializer {
		__ERC20_init("BlackSwan", "SWAN");
		__Ownable_init();
		_mint(_owner, _initialSupply);
		founderOneAllocation = _founderOneAllocation;
		founderTwoAllocation = _founderTwoAllocation;
		developmentAllocation = _developmentAllocation;
		founderOneMonthlyClaim = _founderOneAllocation / 24;
		founderTwoMonthlyClaim = _founderTwoAllocation / 24;
		developmentMonhlyClaim = _developmentAllocation / 24;
		addressBook = _addressBook;
		buyLimit = (1000 * totalSupply()) / 10**6;
		sellLimit = (1000 * totalSupply()) / 10**6;

		emit Transfer(address(0), _msgSender(), totalSupply());
	}

	function claimFounderDividend() external {
		address founderOne = addressBook.getAddress("FOUNDER_ONE");
		address founderTwo = addressBook.getAddress("FOUNDER_TWO");
		address development = addressBook.getAddress("DEVELOPMENT");
		require(
			(_msgSender() == founderOne &&
				block.timestamp >= founderOneLastClaim + 30 days) ||
				(_msgSender() == founderTwo &&
					block.timestamp >= founderTwoLastClaim + 30 days) ||
				(_msgSender() == development &&
					block.timestamp >= developmentLastClaim + 30 days),
			"Only founders can call this method and should passed 30 days since last call"
		);
		if (_msgSender() == founderOne) {
			if (founderOneAllocation >= founderOneMonthlyClaim) {
				_mint(_msgSender(), founderOneMonthlyClaim);
				founderOneAllocation -= founderOneMonthlyClaim;
				founderOneLastClaim = block.timestamp;
			} else if (founderOneAllocation > 0) {
				_mint(_msgSender(), founderOneAllocation);
				founderOneAllocation = 0;
				founderOneLastClaim = block.timestamp;
			}
		} else if (_msgSender() == founderTwo) {
			if (founderTwoAllocation >= founderTwoMonthlyClaim) {
				_mint(_msgSender(), founderTwoMonthlyClaim);
				founderTwoAllocation -= founderTwoMonthlyClaim;
				founderTwoLastClaim = block.timestamp;
			} else if (founderTwoAllocation > 0) {
				_mint(_msgSender(), founderTwoAllocation);
				founderTwoAllocation = 0;
				founderOneLastClaim = block.timestamp;
			}
		} else if (_msgSender() == development) {
			if (developmentAllocation >= developmentMonhlyClaim) {
				_mint(_msgSender(), developmentMonhlyClaim);
				developmentAllocation -= developmentMonhlyClaim;
				developmentLastClaim = block.timestamp;
			} else if (developmentAllocation > 0) {
				_mint(_msgSender(), developmentAllocation);
				developmentAllocation = 0;
				developmentLastClaim = block.timestamp;
			}
		}
	}

	/**
	 * @dev Notifies token contract about a new rebase cycle.
	 * @param supplyDelta The number of new tokens to add into circulation via expansion.
	 * @return The total number of token after the supply adjustment.
	 */
	function rebalance(
		uint256 epoch,
		uint256 supplyDelta,
		bool isLiquidityAbove
	) external onlyMonetaryPolicy returns (uint256) {
		if (isLiquidityAbove) {
			if (supplyDelta == 0) {
				emit LogRebalance(epoch, totalSupply());
				return totalSupply();
			}
			_mint(addressBook.getAddress("SWAN_LAKE"), supplyDelta);
		}
		emit LogRebalance(epoch, totalSupply());
		return totalSupply();
	}

	function emergencyFundSupply(uint256 _amount) external onlyFund {
		_mint(addressBook.getAddress("FUND_ADDRESS"), _amount);
		emit EmergencyFundSupplied(block.timestamp, _amount);
	}

	function _isSell(address sender, address recipient)
		internal
		view
		returns (bool)
	{
		// Transfer to pair from non-router address is a sell swap

		return
			sender != addressBook.getAddress("UNISWAP_ROUTER") &&
			recipient == addressBook.getAddress("UNISWAP_PAIR");
	}

	function _isBuy(address sender) internal view returns (bool) {
		// Transfer from pair is a buy swap
		return sender == addressBook.getAddress("UNISWAP_PAIR");
	}

	function updateBuyLimit(uint256 limit) external onlyOwner {
		// Buy limit can only be 0.1% or disabled, set to 0 to disable
		uint256 maxLimit = (1000 * totalSupply()) / 10**6;
		require(limit == maxLimit || limit == 0, "Buy limit out of bounds");

		buyLimit = limit;
	}

	function _validateTransfer(
		address sender,
		address recipient,
		uint256 amount
	) private view {
		// Excluded addresses don't have limits

		if (_isBuy(sender) && buyLimit != 0) {
			require(amount <= buyLimit, "Buy amount exceeds limit");
		} else if (_isSell(sender, recipient) && sellLimit != 0) {
			require(amount <= sellLimit, "Sell amount exceeds limit");
		}
	}

	function transfer(address recipient, uint256 amount)
		public
		virtual
		override
		returns (bool)
	{
		_validateTransfer(_msgSender(), recipient, amount);
		return super.transfer(recipient, amount);
	}

	function updateSellLimit(uint256 limit) external onlyOwner {
		// Min sell limit is 0.1%, max is 0.5%. Set to 0 to disable
		uint256 minLimit = (1000 * totalSupply()) / 10**6;
		uint256 maxLimit = (5000 * totalSupply()) / 10**6;

		require(
			(limit <= maxLimit && limit >= minLimit) || limit == 0,
			"Sell limit out of bounds"
		);

		sellLimit = limit;
	}
}
