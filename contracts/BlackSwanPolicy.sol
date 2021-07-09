// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./BlackSwanERC20.sol";
import "./BlackSwanFund.sol";
import "./libraries/SafeMath.sol";
import "./libraries/SafeMathInt.sol";
import "./AddressBook.sol";

interface ILiquidityOracle {
	function getData() external returns (uint256, bool);

	function getUsdcVolume() external view returns (uint256);
}

contract BlackSwanPolicy is OwnableUpgradeable {
	using SafeMath for uint256;
	using SafeMathInt for int256;
	event LogRebalance(
		uint256 indexed epoch,
		uint256 supplyDelta,
		uint256 timestampSec
	);
	//AddressBook to get addresses
	AddressBook public addressBook;

	//Store rebalance datas
	struct RebalanceData {
		uint256 timestamp;
		uint256 liquidityPercentage;
	}
	mapping(uint256 => RebalanceData) public rebalanceDatas;
	// The number of rebalance cycles since inception
	uint256 public epoch;
	// Target Equilibrium for liquidity
	int256 public liquidityTargetEquilibrium;

	//Below equilibrium buffer level
	uint256 public bufferZone;

	// More than this much time must pass between rebase operations.
	uint256 public minRebalanceTimeIntervalSec;

	// Block timestamp of last rebase operation
	uint256 public lastRebalanceTimestampSec;

	// The rebalance window begins this many seconds into the minRebaseTimeInterval period.
	// For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
	uint256 public rebalanceWindowOffsetSec;

	// The length of the time window where a rebase operation is allowed to execute, in seconds.
	uint256 public rebalanceWindowLengthSec;

	// Due to the expression in computeSupplyDelta(), MAX_RATE * MAX_SUPPLY must fit into an int256.
	// Both are 18 decimals fixed point numbers.

	// MAX_SUPPLY = MAX_INT256
	uint256 private constant MAX_SUPPLY = type(uint256).max;

	constructor(int256 _liquidityTargetEquilibrium, AddressBook _addressBook)
		public
	{
		__Ownable_init();
		addressBook = _addressBook;
		liquidityTargetEquilibrium = _liquidityTargetEquilibrium;
		epoch = 0;
		bufferZone = 75;
		minRebalanceTimeIntervalSec = 1 days;
		rebalanceWindowOffsetSec = 85440; // 11:44PM UTC
		rebalanceWindowLengthSec = 16 minutes; // offset until midnight
	}

	modifier onlyOrchestrator() {
		require(
			_msgSender() == addressBook.getAddress("ORCHESTRATOR"),
			"Only Orchestrator can call this method"
		);
		_;
	}

	function rebalance() external onlyOrchestrator {
		require(inRebalanceWindow(), "Not in rebalance window");
		require(
			lastRebalanceTimestampSec.add(minRebalanceTimeIntervalSec) <=
				block.timestamp,
			"Min rebalance time should pass since last rebalance"
		);
		BlackSwanERC20 blackSwan =
			BlackSwanERC20(addressBook.getAddress("BLACKSWAN"));
		ILiquidityOracle liquidityOracle =
			ILiquidityOracle(addressBook.getAddress("LIQUIDITY_ORACLE"));
		(uint256 liquidityVolume, bool volumeValid) = liquidityOracle.getData();
		require(volumeValid);
		epoch = epoch + 1;
		uint256 currentSupply = blackSwan.totalSupply();
		uint256 liquidityPercentage =
			(liquidityVolume * 100 * 1e18) / (currentSupply);
		int256 liquidityDifference =
			int256(liquidityPercentage) - liquidityTargetEquilibrium;
		RebalanceData memory currentData =
			RebalanceData(block.timestamp, liquidityPercentage);
		rebalanceDatas[epoch] = currentData;

		if (liquidityDifference > 0) {
			int256 liquidityIntDifference =
				int256(liquidityDifference) / int256(10);
			uint256 supplyDelta =
				(currentSupply * uint256(liquidityIntDifference)) /
					(100 * 1e18);

			uint256 newTotalSupply =
				blackSwan.rebalance(epoch, supplyDelta, true);
			uint256 stableCoinVolume = liquidityOracle.getUsdcVolume();
			// When it's above equilibrium sell for 0.5% of usdc
			uint256 usdcAmount = (500 * stableCoinVolume) / 100000;
			BlackSwanFund(addressBook.getAddress("FUND_ADDRESS"))
				.swapSwanToUsdc(usdcAmount);

			assert(newTotalSupply <= MAX_SUPPLY);
			emit LogRebalance(epoch, supplyDelta, block.timestamp);
		} else if (liquidityDifference < 0) {
			int256 liquidityIntDifference =
				int256(liquidityDifference.abs()) / int256(10);
			uint256 supplyDelta =
				(currentSupply * uint256(liquidityIntDifference)) /
					(100 * 1e18);

			blackSwan.rebalance(epoch, 0, false);
			if (
				int256(liquidityPercentage) <
				(liquidityTargetEquilibrium * int256(bufferZone)) / 100
			) {
				BlackSwanFund(addressBook.getAddress("FUND_ADDRESS"))
					.provideLiquidity();
			}

			emit LogRebalance(epoch, supplyDelta, block.timestamp);
		}
		lastRebalanceTimestampSec = block.timestamp;
		setLiquidityEquilibrium(liquidityDifference > 0 ? true : false);
	}

	/**
	 * @return If the latest block timestamp is within the rebalance time window it, returns true.
	 *         Otherwise, returns false.
	 */
	function inRebalanceWindow() public view returns (bool) {
		return (block.timestamp.mod(minRebalanceTimeIntervalSec) >=
			rebalanceWindowOffsetSec &&
			block.timestamp.mod(minRebalanceTimeIntervalSec) <
			(rebalanceWindowOffsetSec.add(rebalanceWindowLengthSec)));
	}

	/**
	 * @dev Set liquidity target for equilibrium calculations
	 */
	function setLiquidityTarget(int256 _newTarget) external onlyOwner {
		require(_newTarget > 0);
		liquidityTargetEquilibrium = _newTarget;
	}

	/**
    @dev Set liquidity equilibrium dynamically according last 30 rebalance liquidity level
     */
	function setLiquidityEquilibrium(bool _belowEquilibrium) internal {
		uint256 tempLiquidityLevel;

		if (epoch >= 30) {
			for (uint256 i = 0; i < 30; i++) {
				tempLiquidityLevel += rebalanceDatas[epoch - i]
					.liquidityPercentage;
			}

			liquidityTargetEquilibrium = int256(tempLiquidityLevel) / 30;
		}
	}
}
