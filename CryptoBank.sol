// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.8.24;

/// @notice Thrown when the requested amount is greater than the user balance.
error InsufficientBalance(uint256 available, uint256 requested);

/// @notice Thrown when an account exceeds the maximum allowed balance.
error MaxUserBalanceExceeded(
    address user,
    uint256 currentBalance,
    uint256 attemptedDeposit,
    uint256 maxBalance
);

/// @notice Thrown when a non-admin account calls an admin-only function.
error OnlyAdminAllowed();

/// @notice Thrown when the Ether transfer to the caller fails.
error TransferFailed();

/// @notice Thrown when a zero address is provided where a valid address is required.
error ZeroAddress();

/**
 * @title CryptoBank
 * @author Harold Bocanegra
 * @notice A simple smart contract that simulates a basic crypto bank where users can deposit and withdraw Ether.
 * @dev Uses the Checks-Effects-Interactions pattern to mitigate reentrancy attacks.
 */
contract CryptoBank {

    uint256 public maxUserBalance;
    address public immutable admin;

    mapping(address => uint256) private _balances;

    event EtherDeposited(address indexed user, uint256 etherAmount);
    event EtherWithdrawn(address indexed user, uint256 etherAmount);

    /**
     * @notice Restricts function execution to the contract admin.
    */
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert OnlyAdminAllowed();
        }
        _;
    }

    /**
     * @param maxUserBalance_ Maximum Ether balance allowed per user.
     * @param admin_ Address that will manage the contract.
     */
    constructor(uint256 maxUserBalance_, address admin_) {
        if (admin_ == address(0)) {
            revert ZeroAddress();
        }
        maxUserBalance = maxUserBalance_;
        admin = admin_;
    }

    /**
     * @notice Deposits Ether into the user's account.
     * @dev Increases the user balance by msg.value
     */
    function depositEther() external payable {
        uint256 userBalance = _balances[msg.sender];
        uint256 newBalance = userBalance + msg.value;
        if (newBalance > maxUserBalance) {
            revert MaxUserBalanceExceeded(msg.sender, userBalance, msg.value, maxUserBalance);
        }
        _balances[msg.sender] = newBalance;
        emit EtherDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws Ether from the caller's account.
     * @param amount Amount of ETH to withdraw
     */
    function withdrawEther(uint256 amount) external {

        // Avoid Reentrancy attacks
        // CEI pattern: 1. Checks (validate balance)    2. Effects (update balance)    3. Interactions (transfer ether)

        // Validation
        uint256 userBalance = _balances[msg.sender];
        if (amount > userBalance) {
            revert InsufficientBalance(userBalance, amount);
        }
        
        // Update balance
        unchecked {
            _balances[msg.sender] = userBalance - amount;
        }

        // Transfer Ether
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }

        emit EtherWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Updates the maximum balance allowed per user.
     * @dev Can only be called by the contract admin.
     * @param newMaxUserBalance The new maximum balance in wei.
     */
    function modifyMaxUserBalance(uint256 newMaxUserBalance) external onlyAdmin {
        maxUserBalance = newMaxUserBalance;
    }

    /**
     * @notice Returns the Ether balance of an account.
     * @param account Address to query.
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}