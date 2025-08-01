// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IRebaseToken {
    /**
     * @notice Mints new tokens to a specified address.
     * @param _to The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount, uint256 _interestRate) external;

    /**
     * @notice Burns tokens from a specified address.
     * @param _from The address to burn tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external;
    function balanceOf(address _account) external view returns (uint256);
    function getUserInterestRate(address _user) external view returns (uint256);
    function getInterestRate() external view returns (uint256);

    // Note: We only include functions that the Vault contract will call.
    // Other functions from the actual RebaseToken.sol are not needed here.
}
