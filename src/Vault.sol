// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault_DepositAmountIsZero();
    error Vault_RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint RebaseTokens.
     * @dev The deposited ETH is equivalent to the amount of RebaseTokens minted
     * to the user's address.
     */
    function deposit() external payable {
        uint256 amountToMint = msg.value;
        if (amountToMint == 0) {
            revert Vault_DepositAmountIsZero();
        }
        i_rebaseToken.mint(msg.sender, amountToMint);
        emit Deposit(msg.sender, amountToMint);
    }

    /**
     * @notice Allows a user to burn their RebaseTokens and receive a corresponding amount of ETH.
     * @param _amount The amount of RebaseTokens to redeem.
     * @dev Follows Checks-Effects-Interactions pattern. Uses low-level .call for ETH transfer.
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            // If the amount is max, burn all tokens
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // 1. Effects (State changes occur first)
        // Burn the specified amount of tokens from the caller (msg.sender)
        // The RebaseToken's burn function should handle checks for sufficient balance.
        i_rebaseToken.burn(msg.sender, _amount);

        // 2. Interactions (External calls / ETH transfer last)
        // Send the equivalent amount of ETH back to the user
        (bool success,) = payable(msg.sender).call{value: _amount}("");

        // Check if the ETH transfer succeeded
        if (!success) {
            revert Vault_RedeemFailed(); // Use the custom error
        }

        // Emit an event logging the redemption
        emit Redeem(msg.sender, _amount);
    }
    /**
     * @notice Returns the address of the RebaseToken contract.
     */

    function getRebaseToken() external view returns (address) {
        return address(i_rebaseToken);
    }
}
