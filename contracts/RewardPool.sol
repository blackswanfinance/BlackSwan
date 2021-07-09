// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/Interfaces.sol";

contract RewardPool is Initializable, OwnableUpgradeable {
	IERC20 public token; // Reward token's address

	function initialize(address _token) public initializer {
		__Ownable_init();
		token = IERC20(_token);
	}

	function transfer(address _recipient, uint256 _amount) external onlyOwner {
		token.transfer(_recipient, _amount);
	}

	function balance() external view returns (uint256) {
		return token.balanceOf(address(this));
	}
}
