import "openzeppelin-contracts/token/ERC20/ERC20.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IERC20Ownable is IERC20 {
	function mint(address to, uint256 amount) external;
}

contract SuccinctToken is ERC20Burnable, Ownable, IERC20Ownable {
    constructor() ERC20("Succinct", "S") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}


contract GnosisUSD is ERC20 {
	constructor(uint256 initialSupply, address minter) ERC20("GnosisSuccinctBucks", "GnoSB") {
		_mint(minter, initialSupply);
	}

	function decimals() public view virtual override returns (uint8) {
		return 0;
	}

	function mint(address to, uint256 amount) public {
		_mint(to, amount);
	}
}

contract RopstenUSD is ERC20 {
	constructor(uint256 initialSupply, address minter) ERC20("RopstenSuccinctBucks", "RSB") {
		_mint(minter, initialSupply);
	}

	function decimals() public view virtual override returns (uint8) {
		return 0;
	}

	function mint(address to, uint256 amount) public {
		_mint(to, amount);
	}
}

contract GoerliUSD is ERC20 {
	constructor(uint256 initialSupply, address minter) ERC20("GoerliSuccinctBucks", "GSB") {
		_mint(minter, initialSupply);
	}

	function decimals() public view virtual override returns (uint8) {
		return 0;
	}

	function mint(address to, uint256 amount) public {
		_mint(to, amount);
	}
}
