// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./BlackSwanPolicy.sol";
import "./AddressBook.sol";

contract Orchestrator {
	AddressBook public addressBook;

	constructor(AddressBook _addressBook) public {
		addressBook = _addressBook;
	}

	function rebalance() external {
		BlackSwanPolicy(addressBook.getAddress("POLICY")).rebalance();
	}
}
