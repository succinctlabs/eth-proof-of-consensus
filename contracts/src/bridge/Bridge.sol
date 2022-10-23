// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "forge-std/console.sol";
import "../amb/interfaces/ITrustlessAMB.sol";
import "./Tokens.sol";

contract Bridge is Ownable {
	mapping(address => address) public tokenAddressConverter;

	function setMapping(address addr1, address addr2) public onlyOwner {
		tokenAddressConverter[addr1] = addr2;
	}
}

contract Deposit is Bridge {
    ITrustlessAMB homeAmb;
    address foreignWithdraw;
	uint16 chainId;
    // GAS_LIMIT is how much gas the foreignWithdraw contract will
    // have to execute the withdraw function. Foundry estimates 33536
    // so we leave some buffer.
    uint256 internal constant GAS_LIMIT = 50000;

	event DepositEvent(
		address indexed from,
		address indexed recipient,
		uint256 amount,
		address tokenAddress
	);

	constructor(ITrustlessAMB _homeAmb, address _foreignWithdraw, uint16 _chainId) {
        homeAmb = _homeAmb;
        foreignWithdraw = _foreignWithdraw;
		chainId = _chainId;
	}

	function deposit(
		address recipient,
		uint256 amount,
		address tokenAddress
	) external virtual {
		require(tokenAddressConverter[tokenAddress] != address(0), "Invalid token address");
        require(amount <= 100, "Can deposit a max of 100 tokens at a time");
		require(IERC20(tokenAddress).balanceOf(msg.sender) >= amount, "Insufficient balance");
		IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        bytes memory msgData = abi.encode(recipient, amount, tokenAddress);
        homeAmb.send(foreignWithdraw, chainId, GAS_LIMIT, msgData);
		emit DepositEvent(msg.sender, recipient, amount, tokenAddress);
	}
}

contract DepositMock is Deposit {
	constructor(ITrustlessAMB _homeAmb, address _foreignWithdraw, uint16 _chainId) Deposit(_homeAmb, _foreignWithdraw, _chainId) {
	}

	// We have a mock for testing purposes.
	function deposit(
		address recipient,
		uint256 amount,
		address tokenAddress
	) external override {
		require(tokenAddressConverter[tokenAddress] != address(0), "Invalid token address");
        require(amount <= 100, "Can deposit a max of 100 tokens at a time");
		// Do not do any of the checks involving ERC20.
		bytes memory msgData = abi.encode(recipient, amount, tokenAddress);
        homeAmb.send(foreignWithdraw, chainId, GAS_LIMIT, msgData);
		emit DepositEvent(msg.sender, recipient, amount, tokenAddress);
	}
}

contract Withdraw is Bridge {
    address homeDeposit;
    address foreignAmb;
    IERC20Ownable public token;

	event WithdrawEvent(
		address indexed from,
		address indexed recipient,
		uint256 amount,
		address tokenAddress,
		address newTokenAddress
	);

	constructor(address _foreignAmb, address _homeDeposit) {
		foreignAmb = _foreignAmb;
		homeDeposit = _homeDeposit;
        token = new SuccinctToken();
        uint256 MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        // Mint the max number of tokens to this contract
        token.mint(address(this), MAX_INT);
	}

	function receiveSuccinct(
        address srcAddress,
        bytes calldata callData
	) public {
        require(msg.sender == foreignAmb, "Only foreign amb can call this function");
        require(srcAddress == homeDeposit, "Only home deposit can trigger a message call to this contract.");
        (address recipient, uint256 amount, address tokenAddress) = abi.decode(callData, (address, uint256, address));
		address newTokenAddress = tokenAddressConverter[tokenAddress];
		require(newTokenAddress != address(0), "Invalid token address");
        token.transfer(recipient, amount);
		emit WithdrawEvent(msg.sender, recipient, amount, tokenAddress, newTokenAddress);
	}
}
