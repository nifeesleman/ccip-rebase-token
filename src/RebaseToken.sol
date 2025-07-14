// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
/**
 * @title RebaseToken
 * @author Nife Esleman
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */

contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;

    event setInterestRate(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    function setInterestRate(uint256 _newInterestRate) external {
        // Set the interest rate
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit interestRateSet(_newInterestRate);
    }

    function mint(address _to, uint256 _amount) external {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        // Mint tokens to the specified address
        _mint(_to, _amount);
    }

function balanceOf(address _user) public view override returns (uint256) {
    // Get the user's balance
    return super.balanceOf(_user)*_calculateAccruedInterest(_user);
}
        
function _mintAccuredInterest(address _user) internal {
        
/**
 * @notice Gets the locked-in interest rate for a specific user.
 * @param _user The address of the user.
 * @return The user's specific interest rate.
 */
    function getUserInterestRate(address _user) external view returns (uint256) {
        // Return the user's interest rate
        // In this case, it is the global interest rate
        return s_userInterestRate[_user];
}
