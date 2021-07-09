// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.1;

import "../BlackSwanERC20.sol";

contract BlackSwanERC20Test is BlackSwanERC20 {
	function mint(address to, uint256 _amount) external {
		_mint(to, _amount);
	}
}
