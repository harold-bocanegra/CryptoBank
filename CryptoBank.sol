// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.8.24;

/// @notice Thrown when a function is called while the contract is paused.
error ContractPaused();

/// @notice Thrown when a withdrawal exceeds the user's daily withdrawal limit.
error DailyWithdrawalLimitExceeded(uint256 currentAmount, uint256 requestedAmount, uint256 dailyWithdrawalLimit);

/// @notice Thrown when the requested amount is greater than the user balance.
error InsufficientBalance(uint256 available, uint256 requested);

/// @notice Thrown when a transaction index does not exist for an account.
error InvalidTransactionIndex();

/// @notice Thrown when an account exceeds the maximum allowed balance.
error MaxUserBalanceExceeded(
    address user,
    uint256 currentBalance,
    uint256 attemptedDeposit,
    uint256 maxBalance
);

/// @notice Thrown when a non-admin account calls an admin-only function.
error OnlyAdminAllowed();

/// @notice Thrown when a protected function is called reentrantly.
error ReentrantCall();

/// @notice Thrown when the Ether transfer to the caller fails.
error TransferFailed();

/// @notice Thrown when a zero address is provided where a valid address is required.
error ZeroAddress();

/**
 * @title CryptoBank
 * @author Harold Bocanegra
 * @notice A simple crypto bank that allows users to deposit and withdraw Ether while providing basic administrative controls.
 * @dev Uses the Checks-Effects-Interactions pattern to mitigate reentrancy attacks.
 */
contract CryptoBank {

    struct DailyWithdrawalInfo {
        uint256 day;
        uint256 amount;
    }

    struct Transaction {
        uint256 amount;
        uint256 fee;
        uint256 timestamp;
        bool isDeposit;
    }

    bool public paused;
    uint256 public maxUserBalance;
    uint256 public dailyWithdrawalLimit;
    address public admin;

    uint256 private _depositCount;
    uint256 private _feesCharged;
    uint256 private _totalDeposited;
    uint256 private _totalWithdrawn;
    uint256 private _unlocked = 1;
    uint256 private _withdrawCount;
    mapping(address => uint256) private _balances;
    mapping(address => DailyWithdrawalInfo) private _dailyWithdrawals;
    mapping(address => Transaction[]) private _history;

    /// @notice Emitted when a user deposits Ether.
    event EtherDeposited(address indexed user, uint256 etherAmount);

    /// @notice Emitted when a user withdraws Ether.
    event EtherWithdrawn(address indexed user, uint256 etherAmount);

    /// @notice Emitted when the admin role is transferred.
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    /// @notice Emitted when the contract is paused.
    event ContractWasPaused(address indexed admin);

    /// @notice Emitted when the contract is unpaused.
    event ContractWasUnpaused(address indexed admin);

    /// @notice Emitted when the daily withdrawal limit is configured.
    event DailyWithdrawalLimitSet(uint256 limit);

    /// @notice Emitted when the daily withdrawal limit is updated.
    event DailyWithdrawalLimitUpdated(uint256 newLimit);

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
     * @notice Prevents reentrant calls to a function.
     */
    modifier nonReentrant() {
        if (_unlocked != 1) {
            revert ReentrantCall();
        }

        _unlocked = 2;

        _;

        _unlocked = 1;
    }

    /**
     * @notice Restricts function execution when the contract is not paused.
     */
    modifier whenNotPaused() {
        if (paused) {
            revert ContractPaused();
        }
        _;
    }

    /**
     * @notice Restricts withdrawals when the daily limit is exceeded.
     * @param amount Amount of Ether to withdraw.
     */
    modifier withinDailyWithdrawalLimit(uint256 amount) {
        uint256 currentDay = block.timestamp / 1 days;
        DailyWithdrawalInfo storage info = _dailyWithdrawals[msg.sender];
        if (info.day != currentDay) {
            info.day = currentDay;
            info.amount = 0;
        }
        if (info.amount + amount > dailyWithdrawalLimit) {
            revert DailyWithdrawalLimitExceeded(info.amount, amount, dailyWithdrawalLimit);
        }

        info.amount += amount;

        _;
    }

    /**
     * @notice Deploys the contract.
     * @param maxUserBalance_ Maximum Ether balance allowed per user.
     * @param dailyWithdrawalLimit_ Maximum Ether amount that a user can withdraw per day.
     * @param admin_ Address that will manage the contract.
     */
    constructor(uint256 maxUserBalance_, uint256 dailyWithdrawalLimit_, address admin_) {
        if (admin_ == address(0)) {
            revert ZeroAddress();
        }
        maxUserBalance = maxUserBalance_;
        dailyWithdrawalLimit = dailyWithdrawalLimit_;
        admin = admin_;

        emit DailyWithdrawalLimitUpdated(dailyWithdrawalLimit_);
    }

    /**
     * @notice Deposits Ether into the user's account.
     * @dev Increases the caller's balance by msg.value
     */
    function depositEther() external payable whenNotPaused {
        uint256 userBalance = _balances[msg.sender];
        uint256 newBalance = userBalance + msg.value;
        if (newBalance > maxUserBalance) {
            revert MaxUserBalanceExceeded(msg.sender, userBalance, msg.value, maxUserBalance);
        }

        _balances[msg.sender] = newBalance;

        _totalDeposited += msg.value;
        _depositCount++;

        _history[msg.sender].push(
            Transaction({
                amount: msg.value,
                fee: 0,
                timestamp: block.timestamp,
                isDeposit: true
            })
        );

        emit EtherDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws Ether from the caller's account.
     * @param amount Amount of ETH to withdraw
     * @dev Uses the Checks-Effects-Interactions pattern and a reentrancy guard to mitigate reentrancy attacks.
     */
    function withdrawEther(uint256 amount) external whenNotPaused nonReentrant withinDailyWithdrawalLimit(amount) {

        // Avoid Reentrancy attacks
        // CEI pattern: 1. Checks (validate balance)    2. Effects (update balance)    3. Interactions (transfer ether)

        // Validation
        uint256 userBalance = _balances[msg.sender];
        if (amount > userBalance) {
            revert InsufficientBalance(userBalance, amount);
        }
        
        uint256 fee = amount / 100;
        uint256 amountToTransfer = amount - fee;

        // Update balance
        unchecked {
            _balances[msg.sender] = userBalance - amount;
        }

        _feesCharged += fee;
        _totalWithdrawn += amount;
        _withdrawCount++;

        // Transfer Ether
        (bool success,) = msg.sender.call{value: amountToTransfer}("");
        if (!success) {
            revert TransferFailed();
        }

        _history[msg.sender].push(
            Transaction({
                amount: amount,
                fee: fee,
                timestamp: block.timestamp,
                isDeposit: false
            })
        );

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

    /**
     * @notice Returns the Ether balance held by the contract.
     * @return Current contract balance in wei.
     */
    function bankBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Transfers the admin role to a new account.
     * @param newAdmin Address of the new admin.
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert ZeroAddress();
        }

        address previousAdmin = admin;

        admin = newAdmin;

        emit AdminTransferred(previousAdmin, newAdmin);
    }

    /**
     * @notice Pauses the contract.
     * @dev Can only be called by the contract admin.
     */
    function pause() external onlyAdmin {
        if (!paused) {
            paused = true;
        }

        emit ContractWasPaused(msg.sender);
    }

    /**
     * @notice Unpauses the contract.
     * @dev Can only be called by the contract admin.
     */
    function unpause() external onlyAdmin {
        if (paused) {
            paused = false;
        }

        emit ContractWasUnpaused(msg.sender);
    }

    /**
     * @notice Returns the total amount of Ether deposited into the contract.
     * @return Total deposited amount in wei.
     */
    function totalDeposited() external view returns (uint256) {
        return _totalDeposited;
    }

    /**
     * @notice Returns the total amount of Ether withdrawn from the contract.
     * @return Total withdrawn amount in wei.
     */
    function totalWithdrawn() external view returns (uint256) {
        return _totalWithdrawn;
    }

    /**
     * @notice Returns the total number of deposits made into the contract.
     * @return Number of deposits.
     */
    function depositCount() external view returns (uint256) {
        return _depositCount;
    }

    /**
     * @notice Returns the total number of withdrawals made from the contract.
     * @return Number of withdrawals.
     */
    function withdrawCount() external view returns (uint256) {
        return _withdrawCount;
    }

    /**
     * @notice Updates the daily withdrawal limit.
     * @dev Can only be called by the contract admin.
     * @param newLimit New daily withdrawal limit in wei.
     */
    function setDailyWithdrawalLimit(uint256 newLimit) external onlyAdmin {
        dailyWithdrawalLimit = newLimit;

        emit DailyWithdrawalLimitUpdated(newLimit);
    }

    /**
     * @notice Returns the number of transactions made by an account.
     * @param account Address to query.
     * @return Number of transactions.
     */
    function transactionCount(address account) external view returns (uint256) {
        return _history[account].length;
    }

    /**
     * @notice Returns a transaction from an account history.
     * @param account Address to query.
     * @param index Transaction index in the account history.
     * @return amount Transaction amount in wei.
     * @return fee Fee charged for the transaction in wei.
     * @return timestamp Transaction timestamp.
     * @return isDeposit True if the transaction is a deposit, false if it is a withdrawal.
     */
    function transactionAt(address account, uint256 index) external view
    returns (
        uint256 amount,
        uint256 fee,
        uint256 timestamp,
        bool isDeposit
    ) {
        if (index >= _history[account].length) {
            revert InvalidTransactionIndex();
        }

        Transaction storage txInfo = _history[account][index];

        return (
            txInfo.amount,
            txInfo.fee,
            txInfo.timestamp,
            txInfo.isDeposit
        );
    }

    /**
     * @notice Returns the total fees collected by the contract.
     * @return Total fees charged in wei.
     */
    function totalFeesCharged() external view returns (uint256) {
        return _feesCharged;
    }
}