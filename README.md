# CryptoBank

A simple Ethereum smart contract that simulates a basic crypto bank where users can deposit and withdraw Ether.

This project was developed as part of my Solidity learning journey using **Remix IDE**. The goal was to understand Solidity fundamentals and common smart contract development patterns before moving to Foundry-based projects.

---

## Features

* Deposit Ether into the contract.
* Withdraw previously deposited Ether.
* Store individual user balances using a mapping.
* Configurable maximum balance per user.
* Administrator role for managing the maximum allowed balance.
* Deposit and withdrawal events.

---

## Solidity Concepts Practiced

* State variables
* Constructors
* Mappings
* Events
* Modifiers
* Payable functions
* Ether transfers
* Access control
* Checks-Effects-Interactions (CEI) pattern

---

## Contract Overview

### Deposit

Users can deposit Ether into the contract as long as their total balance does not exceed the configured maximum balance.

### Withdraw

Users can withdraw their own Ether.

The withdrawal implementation follows the **Checks-Effects-Interactions (CEI)** pattern to reduce the risk of reentrancy attacks.

### Administration

The administrator can modify the maximum balance allowed for each user.

---

## Security Notes

This project is intended for educational purposes.

Current implementation includes:

* CEI (Checks-Effects-Interactions) pattern.
* Ether transfers using `call`.

Future versions will include additional improvements such as:

* Custom Errors instead of `require()`
* NatSpec documentation

---

## Project Status

✅ Learning Project

This contract represents one of my first Solidity exercises. It is intentionally kept simple while applying Solidity best practices learned during the development process.

---

## Compiler

```solidity
pragma solidity ^0.8.24;
```

---

## License

LGPL-3.0-only
