// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.1;
pragma experimental ABIEncoderV2;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
	function totalSupply() external view returns (uint256);

	function balanceOf(address account) external view returns (uint256);

	function decimals() external view returns (uint8);

	function transfer(address recipient, uint256 amount)
		external
		returns (bool);

	function allowance(address owner, address spender)
		external
		view
		returns (uint256);

	function approve(address spender, uint256 amount) external returns (bool);

	function transferFrom(
		address sender,
		address recipient,
		uint256 amount
	) external returns (bool);

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(
		address indexed owner,
		address indexed spender,
		uint256 value
	);
}

interface IUniswapV2Pair {
	function getReserves()
		external
		view
		returns (
			uint112 reserve0,
			uint112 reserve1,
			uint32 blockTimestampLast
		);
}

interface IUniswapV2Router01 {
	function factory() external pure returns (address);

	function WETH() external pure returns (address);

	function addLiquidity(
		address tokenA,
		address tokenB,
		uint256 amountADesired,
		uint256 amountBDesired,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	)
		external
		returns (
			uint256 amountA,
			uint256 amountB,
			uint256 liquidity
		);

	function addLiquidityETH(
		address token,
		uint256 amountTokenDesired,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	)
		external
		payable
		returns (
			uint256 amountToken,
			uint256 amountETH,
			uint256 liquidity
		);

	function removeLiquidity(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountA, uint256 amountB);

	function removeLiquidityETH(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountToken, uint256 amountETH);

	function removeLiquidityWithPermit(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external returns (uint256 amountA, uint256 amountB);

	function removeLiquidityETHWithPermit(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external returns (uint256 amountToken, uint256 amountETH);

	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapTokensForExactTokens(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapExactETHForTokens(
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external payable returns (uint256[] memory amounts);

	function swapTokensForExactETH(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapExactTokensForETH(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapETHForExactTokens(
		uint256 amountOut,
		address[] calldata path,
		address to,
		uint256 deadline
	) external payable returns (uint256[] memory amounts);

	function quote(
		uint256 amountA,
		uint256 reserveA,
		uint256 reserveB
	) external pure returns (uint256 amountB);

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) external pure returns (uint256 amountOut);

	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) external pure returns (uint256 amountIn);

	function getAmountsOut(uint256 amountIn, address[] calldata path)
		external
		view
		returns (uint256[] memory amounts);

	function getAmountsIn(uint256 amountOut, address[] calldata path)
		external
		view
		returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
	function removeLiquidityETHSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountETH);

	function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external returns (uint256 amountETH);

	function swapExactTokensForTokensSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external;

	function swapExactETHForTokensSupportingFeeOnTransferTokens(
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external payable;

	function swapExactTokensForETHSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external;
}

interface IERC2917 is IERC20 {
	/// @dev This emit when interests amount per block is changed by the owner of the contract.
	/// It emits with the old interests amount and the new interests amount.
	event InterestRatePerBlockChanged(uint256 oldValue, uint256 newValue);

	/// @dev This emit when a users' productivity has changed
	/// It emits with the user's address and the the value after the change.
	event ProductivityIncreased(address indexed user, uint256 value);

	/// @dev This emit when a users' productivity has changed
	/// It emits with the user's address and the the value after the change.
	event ProductivityDecreased(address indexed user, uint256 value);

	/// @dev Return the current contract's interests rate per block.
	/// @return The amount of interests currently producing per each block.
	function interestsPerBlock() external view returns (uint256);

	/// @notice Change the current contract's interests rate.
	/// @dev Note the best practice will be restrict the gross product provider's contract address to call this.
	/// @return The true/fase to notice that the value has successfully changed or not, when it succeed, it will emite the InterestRatePerBlockChanged event.
	function changeInterestRatePerBlock(uint256 value) external returns (bool);

	/// @notice It will get the productivity of given user.
	/// @dev it will return 0 if user has no productivity proved in the contract.
	/// @return user's productivity and overall productivity.
	function getProductivity(address user)
		external
		view
		returns (uint256, uint256);

	/// @notice increase a user's productivity.
	/// @dev Note the best practice will be restrict the callee to prove of productivity's contract address.
	/// @return true to confirm that the productivity added success.
	function increaseProductivity(address user, uint256 value)
		external
		returns (bool);

	/// @notice decrease a user's productivity.
	/// @dev Note the best practice will be restrict the callee to prove of productivity's contract address.
	/// @return true to confirm that the productivity removed success.
	function decreaseProductivity(address user, uint256 value)
		external
		returns (bool);

	/// @notice take() will return the interests that callee will get at current block height.
	/// @dev it will always calculated by block.number, so it will change when block height changes.
	/// @return amount of the interests that user are able to mint() at current block height.
	function take() external view returns (uint256);

	/// @notice similar to take(), but with the block height joined to calculate return.
	/// @dev for instance, it returns (_amount, _block), which means at block height _block, the callee has accumulated _amount of interests.
	/// @return amount of interests and the block height.
	function takeWithBlock() external view returns (uint256, uint256);

	/// @notice mint the avaiable interests to callee.
	/// @dev once it mint, the amount of interests will transfer to callee's address.
	/// @return the amount of interests minted.
	function mint() external returns (uint256);
}

interface MultiSigWallet {
	function submitTransaction(
		address destination,
		uint256 value,
		bytes calldata data
	) external returns (uint256);

	function addOwner(address owner) external;

	function replaceOwner(address owner, address newOwner) external;

	function changeRequirement(uint256 _required) external;
}
