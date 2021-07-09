// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AddressBook is OwnableUpgradeable {
	mapping(bytes32 => address) public addresses;

	constructor() {
		__Ownable_init();
	}

	function getAddress(string memory name) external view returns (address) {
		return addresses[keccak256(bytes(name))];
	}

	function setAddress(string memory name, address addr) external onlyOwner {
		addresses[keccak256(bytes(name))] = addr;
	}
}
