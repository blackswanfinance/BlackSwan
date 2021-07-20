// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/Interfaces.sol";
import "./AddressBook.sol";

contract LiquidityOracle is OwnableUpgradeable {
	struct LiquidityData {
		uint256 timestamp;
		uint256 liquidityVolume;
	}
	struct CumulativeLiquidityData {
		uint256 cumulativeLiquidities;
		uint256 counter;
	}

	AddressBook public addressBook;
	mapping(uint256 => LiquidityData[]) public liqiuidityDatas;
	mapping(uint256 => CumulativeLiquidityData) public cumulativeLiquidityDatas;

	function initialize(AddressBook _addressBook) public initializer {
		__Ownable_init();
		addressBook = _addressBook;
	}

	function getData() external view returns (uint256, bool) {
		uint256 todayTimestamp = block.timestamp / 1 days;
		LiquidityData[] memory todayDatas = liqiuidityDatas[todayTimestamp];
		CumulativeLiquidityData memory cumulativeData =
			cumulativeLiquidityDatas[todayTimestamp];
		if (cumulativeData.counter == 0) {
			return (0, true);
		}

		return (
			cumulativeData.cumulativeLiquidities / cumulativeData.counter,
			true
		);
	}

	function update() external {
		uint256 todayTimestamp = block.timestamp / 1 days;
		CumulativeLiquidityData storage cumulativeData =
			cumulativeLiquidityDatas[todayTimestamp];
		address swanAddress = addressBook.getAddress("BLACKSWAN");
		address usdcAddress = addressBook.getAddress("USDC");
		AggregatorV3Interface usdcUsdOracle =
			AggregatorV3Interface(addressBook.getAddress("USDC_USD_ORACLE"));
		int256 usdcUsdPrice = usdcUsdOracle.latestAnswer();
		(, uint256 tempLiquidityData) = getReserves(swanAddress, usdcAddress);
		cumulativeData.cumulativeLiquidities += ((2 *
			tempLiquidityData *
			uint256(usdcUsdPrice)) / 1e8);
		cumulativeData.counter += 1;
		LiquidityData memory newData =
			LiquidityData(block.timestamp, tempLiquidityData);
		liqiuidityDatas[todayTimestamp].push(newData);
	}

	function getUsdcVolume() public view returns (uint256) {
		address swanAddress = addressBook.getAddress("BLACKSWAN");
		address usdcAddress = addressBook.getAddress("USDC");
		(, uint256 usdcVolume) = getReserves(swanAddress, usdcAddress);
		return usdcVolume;
	}

	function getDataForParticularTimestamp(uint256 _timestamp)
		public
		view
		returns (LiquidityData[] memory)
	{
		return liqiuidityDatas[_timestamp];
	}

	// returns sorted token addresses, used to handle return values from pairs sorted in this order
	function sortTokens(address tokenA, address tokenB)
		internal
		pure
		returns (address token0, address token1)
	{
		require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
		(token0, token1) = tokenA < tokenB
			? (tokenA, tokenB)
			: (tokenB, tokenA);
		require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
	}

	// fetches and sorts the reserves for a pair
	function getReserves(address tokenA, address tokenB)
		internal
		view
		returns (uint256 reserveA, uint256 reserveB)
	{
		(address token0, ) = sortTokens(tokenA, tokenB);
		(uint256 reserve0, uint256 reserve1, ) =
			IUniswapV2Pair(addressBook.getAddress("UNISWAP_PAIR"))
				.getReserves();
		(reserveA, reserveB) = tokenA == token0
			? (reserve0, reserve1)
			: (reserve1, reserve0);
	}

	function swanPrice() public view returns (uint256) {
		address swanAddress = addressBook.getAddress("BLACKSWAN");
		address usdcAddress = addressBook.getAddress("USDC");
		(uint256 swanReserve, uint256 usdcReserve) =
			getReserves(swanAddress, usdcAddress);
		return (usdcReserve * 1e18) / swanReserve;
	}

	function swanMarketCap(uint256 _totalSupply)
		external
		view
		returns (uint256)
	{
		AggregatorV3Interface usdcUsdOracle =
			AggregatorV3Interface(addressBook.getAddress("USDC_USD_ORACLE"));
		int256 usdcUsdPrice = usdcUsdOracle.latestAnswer();
		uint256 swanPriceInUsd = (swanPrice() * uint256(usdcUsdPrice)) / 1e8;
		return (_totalSupply * swanPriceInUsd) / 1e18;
	}
}
