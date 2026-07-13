// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.8.24;

error InsufficientBalance(uint256 available, uint256 requested);

error MaxUserBalanceExceeded(
    address user,
    uint256 currentBalance,
    uint256 attemptedDeposit,
    uint256 maxBalance
);

error OnlyAdminAllowed();

error TransferFailed();

contract CryptoBank {

    uint256 public maxUserBalance;
    address public admin;
    mapping(address => uint256) public userBalance;

    event EtherDeposit(address indexed user, uint256 etherAmount);
    event EtherWithdraw(address indexed user, uint256 etherAmount);

    /**
     * @notice Restricts function execution to the contract admin.
    */
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert OnlyAdminAllowed();
        }
        _;
    }

    constructor(uint256 maxUserBalance_, address admin_) {
        maxUserBalance = maxUserBalance_;
        admin = admin_;
    }

    // External functions

    // 1. Deposit
    function depositEther() external payable {
        uint256 newBalance = userBalance[msg.sender] + msg.value;
        if (newBalance > maxUserBalance) {
            revert MaxUserBalanceExceeded(msg.sender, userBalance[msg.sender], msg.value, maxUserBalance);
        }
        userBalance[msg.sender] = newBalance;
        emit EtherDeposit(msg.sender, msg.value);
    }

    // 2. Withdraw
    function withdrawEther(uint256 amount) external {

        // Avoid Reentrancy attacks
        // CEI pattern: 1. Checks (validate balance)    2. Effects (update balance)    3. Interactions (transfer ether)

        // Validation
        if (amount > userBalance[msg.sender]) {
            revert InsufficientBalance(userBalance[msg.sender], amount);
        }
        
        // Update balance
        userBalance[msg.sender] -= amount;

        // Transfer Ether
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }

        emit EtherWithdraw(msg.sender, amount);
    }

    // 3. Modify maxBalance
    function modifyMaxUserBalance(uint256 newMaxUserBalance) external onlyAdmin {
        maxUserBalance = newMaxUserBalance;
    }
}