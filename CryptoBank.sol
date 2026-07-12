// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.8.24;

contract CryptoBank {

    uint256 public maxUserBalance;
    address public admin;
    mapping(address => uint256) public userBalance;

    event EtherDeposit(address indexed user, uint256 etherAmount);
    event EtherWithdraw(address indexed user, uint256 etherAmount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not allowed");
        _;
    }

    constructor(uint256 maxUserBalance_, address admin_) {
        maxUserBalance = maxUserBalance_;
        admin = admin_;
    }

    // External functions

    // 1. Deposit
    function depositEther() external payable {
        require(userBalance[msg.sender] + msg.value <= maxUserBalance, "MaxUserBalance reached");
        userBalance[msg.sender] += msg.value;
        emit EtherDeposit(msg.sender, msg.value);
    }

    // 2. Withdraw
    function withdrawEther(uint256 amount) external {

        // Avoid Reentrancy attacks
        // CEI pattern: 1. Checks (validate balance)    2. Effects (update balance)    3. Interactions (transfer ether)

        // Validation
        require(amount <= userBalance[msg.sender], "Not enough ether");
        
        // Update balance
        userBalance[msg.sender] -= amount;

        // Transfer Ether
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit EtherWithdraw(msg.sender, amount);
    }

    // 3. Modify maxBalance
    function modifyMaxUserBalance(uint256 newMaxUserBalance) external onlyAdmin {
        maxUserBalance = newMaxUserBalance;
    }
}