// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./AddressBook.sol";
import "./interfaces/Interfaces.sol";

contract TimeLock {
	uint256 public timeLockDuration;
	uint256 public timeStarted;
	AddressBook public addressBook;
	IERC20 public token;

	constructor(AddressBook _addressBook, IERC20 _token) {
		timeLockDuration = 730 days;
		timeStarted = block.timestamp;
		addressBook = _addressBook;
		token = _token;
	}

	function withdrawLp() external {
		require(
			block.timestamp >= timeStarted + timeLockDuration,
			"Tokens lock did not release yet"
		);

		uint256 tokenBalance = token.balanceOf(address(this));
		token.transfer(addressBook.getAddress("FEE_COLLECTOR"), tokenBalance);
	}
}
