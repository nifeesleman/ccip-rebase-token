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
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Nife Esleman
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;
    bytes32 public constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdateTimestamp;

    event interestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender){}

function grantMintAndBurnRole(address _account) external onlyOwner {
    _grantRole(MINT_AND_BURN_ROLE, _account);
}

    function setInterestRate(uint256 _newInterestRate) external onlyOwner{
        // Set the interest rate
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit interestRateSet(_newInterestRate);
    }

/**
 * @notice Gets the principle balance of a user (tokens actually minted to them), excluding any accrued interest.
 * @param _user The address of the user.
 * @return The principle balance of the user.
 */
function principleBalanceOf(address _user) external view returns (uint256) {
    return super.balanceOf(_user); // Calls ERC20.balanceOf, which returns _balances[_user]
}

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        // Mint tokens to the specified address
        _mint(_to, _amount);
    }

/**
* @notice Returns the current balance of an account, including accrued interest.
* @param _user The address of the account.
* @return The total balance including interest.
*/
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the user's balance
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

/**
* @dev Calculates the growth factor due to accumulated interest since the user's last update.
* @param _user The address of the user.
* @notice The growth factor, scaled by PRECISION_FACTOR. (e.g., 1.05x growth is 1.05 * 1e18).
*/
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterestFactor)
    {
        // 1. Calculate the time elapsed since the user's balance was last effectively updated.
        uint256 timeElapsed = block.timestamp - s_userLastUpdateTimestamp[_user];

        // If no time has passed, or if the user has no locked rate (e.g., never interacted),
        // the growth factor is simply 1 (scaled by PRECISION_FACTOR).
        if (timeElapsed == 0 || s_userInterestRate[_user] == 0) {
            return PRECISION_FACTOR;
        }

        // 2. Calculate the total fractional interest accrued: UserInterestRate * TimeElapsed.
        // s_userInterestRate[_user] is the rate per second.
        // This product is already scaled appropriately if s_userInterestRate is stored scaled.
        uint256 fractionalInterest = s_userInterestRate[_user] * timeElapsed;

        // 3. The growth factor is (1 + fractional_interest_part).
        // Since '1' is represented as PRECISION_FACTOR, and fractionalInterest is already scaled, we add them.
        linearInterestFactor = PRECISION_FACTOR + fractionalInterest;
        return linearInterestFactor;
    }

    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
     * @param _user The user to mint the accrued interest to
     */
    function _mintAccuredInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        s_userLastUpdateTimestamp[_user] = block.timestamp;
        // mint accumulated interest to the user
        _mint(_user, balanceIncrease);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if( _amount == typedef(uint256).max ) {
            // If the amount is max, burn all tokens
            _amount = balanceOf(_from);}
    }
        // Burn the specified amount of tokens from the user's balance
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
        
     }

/**
 * @notice Transfers tokens from the caller to a recipient.
 * Accrued interest for both sender and recipient is minted before the transfer.
 * If the recipient is new, they inherit the sender's interest rate.
 * @param _recipient The address to transfer tokens to.
 * @param _amount The amount of tokens to transfer. Can be type(uint256).max to transfer full balance.
 * @return A boolean indicating whether the operation succeeded.
 */
function transfer(address _recipient, uint256 _amount) public override returns (bool) {
    // 1. Mint accrued interest for both sender and recipient
    _mintAccruedInterest(msg.sender);
    _mintAccruedInterest(_recipient);

    // 2. Handle request to transfer maximum balance
    if (_amount == type(uint256).max) {
        _amount = balanceOf(msg.sender); // Use the interest-inclusive balance
    }

    // 3. Set recipient's interest rate if they are new (balance is checked *before* super.transfer)
    // We use balanceOf here to check the effective balance including any just-minted interest.
    // If _mintAccruedInterest made their balance non-zero, but they had 0 principle, this still means they are "new" for rate setting.
    // A more robust check for "newness" for rate setting might be super.balanceOf(_recipient) == 0 before any interest minting for the recipient.
    // However, the current logic is: if their *effective* balance is 0 before the main transfer part, they get the sender's rate.
    if (balanceOf(_recipient) == 0 && _amount > 0) { // Ensure _amount > 0 to avoid setting rate on 0-value initial transfer
        s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
    }

    // 4. Execute the base ERC20 transfer
    return super.transfer(_recipient, _amount);
}


/**
 * @notice Transfers tokens from one address to another, on behalf of the sender,
 * provided an allowance is in place.
 * Accrued interest for both sender and recipient is minted before the transfer.
 * If the recipient is new, they inherit the sender's interest rate.
 * @param _sender The address to transfer tokens from.
 * @param _recipient The address to transfer tokens to.
 * @param _amount The amount of tokens to transfer. Can be type(uint256).max to transfer full balance.
 * @return A boolean indicating whether the operation succeeded.
 */
function transferFrom(address _sender,address _recipient, uint256 _amount) public override returns (bool) {
    // 1. Mint accrued interest for both sender and recipient
    _mintAccruedInterest(_sender);
    _mintAccruedInterest(_recipient);

    // 2. Handle request to transfer maximum balance
    if (_amount == type(uint256).max) {
        _amount = balanceOf(_sender); // Use the interest-inclusive balance
    }

 if (balanceOf(_recipient) == 0 && _amount > 0) { // Ensure _amount > 0 to avoid setting rate on 0-value initial transfer
        s_userInterestRate[_recipient] = s_userInterestRate[_sender];
    }

    return super.transferFrom(_sender,_recipient, _amount);
}

/**
 * @notice Gets the current global interest rate for the token.
 * @return The current global interest rate.
 */
function getInterestRate() external view returns (uint256) {
    return s_interestRate;
}

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
}
