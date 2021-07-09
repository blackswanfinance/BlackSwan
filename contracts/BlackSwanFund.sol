// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
pragma experimental ABIEncoderV2;

import "./libraries/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/Interfaces.sol";
import "./BlackSwanERC20.sol";
import "./AddressBook.sol";

contract BlackSwanFund is OwnableUpgradeable {
	using SafeMath for uint256;

	AddressBook public addressBook;
	uint256[] public rewardDistrubitionPercentage = [
		250000000000,
		200000000000,
		200000000000,
		75000000000,
		50000000000,
		50000000000,
		25000000000,
		25000000000,
		20000000000,
		20000000000,
		10000000000,
		10000000000,
		10000000000,
		10000000000,
		10000000000,
		10000000000,
		10000000000,
		5000000000,
		5000000000,
		5000000000
	];
	uint256 public initialRewardValue;
	uint256 public daysAfterBelowEquilibrium;
	uint256 public slippage;
	uint256 public liquidityMinAmount;

	event LiquidityProvided(
		address poolAddress,
		uint256 stableCoinAmount,
		uint256 swanAmount
	);
	event TokensSwapped(
		address poolAddress,
		uint256 stableCoinAmount,
		uint256 swanAmount
	);

	constructor(AddressBook _addressBook) {
		__Ownable_init();
		addressBook = _addressBook;
		slippage = 99;
		liquidityMinAmount = 99;
	}

	/**
    @dev Function that swap tokens through Uniswap router
    @param _usdcAmount usdc amount that we would get
     */
	function swapSwanToUsdc(uint256 _usdcAmount) public onlyOwner {
		daysAfterBelowEquilibrium = 0;
		IUniswapV2Router02 uniswapRouterContract =
			IUniswapV2Router02(addressBook.getAddress("UNISWAP_ROUTER"));

		address blackSwanAddress = addressBook.getAddress("BLACKSWAN");
		address usdcAddress = addressBook.getAddress("USDC");
		(uint256 reserve0, uint256 reserve1) =
			getReserves(blackSwanAddress, usdcAddress);
		uint256 swanAmount = getAmountIn(_usdcAmount, reserve0, reserve1);
		uint256 fundSwanAmount =
			IERC20(blackSwanAddress).balanceOf(address(this));
		if (swanAmount > fundSwanAmount) {
			_emergencyFundCall(swanAmount - fundSwanAmount);
		}
		address[] memory path = new address[](2);
		path[0] = blackSwanAddress;
		path[1] = addressBook.getAddress("USDC");
		IERC20(blackSwanAddress).approve(
			address(uniswapRouterContract),
			swanAmount
		);
		uniswapRouterContract.swapExactTokensForTokens(
			swanAmount,
			(_usdcAmount * slippage) / 100,
			path,
			address(this),
			block.timestamp
		);
		emit TokensSwapped(
			address(uniswapRouterContract),
			_usdcAmount,
			swanAmount
		);
	}

	/**
    @dev Function that provide liquidity to pools in exchange get 
    * BPT then provide it to swan lake during below equibrium situations
     */
	function provideLiquidity() public onlyOwner {
		address rewardPool = addressBook.getAddress("REWARD_POOL");
		if (rewardPool == address(0x0)) return;
		setInitialRewardValue();
		if (daysAfterBelowEquilibrium <= 19) {
			uint256 stableCoinAmount =
				(initialRewardValue *
					rewardDistrubitionPercentage[daysAfterBelowEquilibrium]) /
					1e12; // divide to 1e12 to bring down usdc's decimals which is 6
			daysAfterBelowEquilibrium = daysAfterBelowEquilibrium + 1;
			IUniswapV2Router02 uniswapRouterContract =
				IUniswapV2Router02(addressBook.getAddress("UNISWAP_ROUTER"));
			address swanAddress = addressBook.getAddress("BLACKSWAN");
			address usdcAddress = addressBook.getAddress("USDC");
			(uint256 reserve0, uint256 reserve1) =
				getReserves(swanAddress, usdcAddress);
			uint256 swanAmount = (stableCoinAmount * reserve0) / reserve1;

			uint256 fundSwanAmount =
				IERC20(swanAddress).balanceOf(address(this));
			if (swanAmount > fundSwanAmount) {
				_emergencyFundCall(swanAmount - fundSwanAmount);
			}
			IERC20(usdcAddress).approve(
				address(uniswapRouterContract),
				stableCoinAmount
			);
			IERC20(swanAddress).approve(
				address(uniswapRouterContract),
				swanAmount
			);
			address rewardPoolTemp = rewardPool;
			uint256 stableCoinAmountTemp = stableCoinAmount;
			uniswapRouterContract.addLiquidity(
				swanAddress,
				usdcAddress,
				swanAmount,
				stableCoinAmount,
				(swanAmount * liquidityMinAmount) / 100,
				(stableCoinAmountTemp * liquidityMinAmount) / 100,
				rewardPoolTemp,
				block.timestamp
			);

			emit LiquidityProvided(
				addressBook.getAddress("UNISWAP_PAIR"),
				stableCoinAmount,
				swanAmount
			);
		}
	}

	// given an output amount of an asset and pair reserves, returns a required input amount of the other asset
	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) internal pure returns (uint256 amountIn) {
		require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
		require(
			reserveIn > 0 && reserveOut > 0,
			"UniswapV2Library: INSUFFICIENT_LIQUIDITY"
		);
		uint256 numerator = reserveIn.mul(amountOut).mul(1000);
		uint256 denominator = reserveOut.sub(amountOut).mul(997);
		amountIn = (numerator / denominator).add(1);
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

	function setInitialRewardValue() internal {
		if (daysAfterBelowEquilibrium == 0) {
			initialRewardValue = IERC20(addressBook.getAddress("USDC"))
				.balanceOf(address(this));
		}
	}

	function _emergencyFundCall(uint256 _amount) internal {
		BlackSwanERC20 bSwan =
			BlackSwanERC20(addressBook.getAddress("BLACKSWAN"));
		bSwan.emergencyFundSupply(_amount);
	}

	function setSlippageAndMinLiquidityAmount(
		uint256 _slippage,
		uint256 _liquidityMinAmount
	) external {
		require(_msgSender() == addressBook.getAddress("SETTER"));
		slippage = _slippage;
		liquidityMinAmount = _liquidityMinAmount;
	}

	function recoverFunds() external {
		require(_msgSender() == addressBook.getAddress("SETTER"));
		address rewardPool = addressBook.getAddress("REWARD_POOL");
		if (rewardPool == address(0x0)) return;
		uint256 stableCoinAmount =
			IERC20(addressBook.getAddress("USDC")).balanceOf(address(this));
		address swanAddress = addressBook.getAddress("BLACKSWAN");
		address usdcAddress = addressBook.getAddress("USDC");
		(uint256 reserve0, uint256 reserve1) =
			getReserves(swanAddress, usdcAddress);
		IUniswapV2Router02 uniswapRouterContract =
			IUniswapV2Router02(addressBook.getAddress("UNISWAP_ROUTER"));

		uint256 swanAmount = (stableCoinAmount * reserve0) / reserve1;

		uint256 fundSwanAmount = IERC20(swanAddress).balanceOf(address(this));
		if (swanAmount > fundSwanAmount) {
			_emergencyFundCall(swanAmount - fundSwanAmount);
		}
		IERC20(usdcAddress).approve(
			address(uniswapRouterContract),
			stableCoinAmount
		);
		IERC20(swanAddress).approve(address(uniswapRouterContract), swanAmount);
		address rewardPoolTemp = rewardPool;
		uint256 stableCoinAmountTemp = stableCoinAmount;
		uniswapRouterContract.addLiquidity(
			swanAddress,
			usdcAddress,
			swanAmount,
			stableCoinAmount,
			(swanAmount * liquidityMinAmount) / 100,
			(stableCoinAmountTemp * liquidityMinAmount) / 100,
			rewardPoolTemp,
			block.timestamp
		);
	}
}
