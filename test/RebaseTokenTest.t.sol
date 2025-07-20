// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        // Impersonate the 'owner' address for deployments and role granting
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();

        // Deploy Vault: requires IRebaseToken.
        // Direct casting (IRebaseToken(rebaseToken)) is invalid.
        // Correct way: cast rebaseToken to address, then to IRebaseToken.
        vault = new Vault(IRebaseToken(address(rebaseToken)));

        // Grant the MINT_AND_BURN_ROLE to the Vault contract.
        // The grantMintAndBurnRole function expects an address.
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        vm.assume(success); // Optionally, assume the transfer succeeds
    }

    // Test if interest accrues linearly after a deposit.
    // 'amount' will be a fuzzed input.
    function testDepositLinear(uint256 amount) public {
        // vm.assume(amount > 1e5);
        // Constrain the fuzzed 'amount' to a practical range.
        // Min: 0.00001 ETH (1e5 wei), Max: type(uint96).max to avoid overflows.
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. User deposits 'amount' ETH
        vm.startPrank(user); // Actions performed as 'user'
        vm.deal(user, amount); // Give 'user' the 'amount' of ETH to deposit
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank(); // Stop impersonating 'user'
    }

    function testDepositRevertsOnZeroValue() public {
        vm.deal(user, 1 ether); // give user some ETH
        vm.prank(user);
        vm.expectRevert(Vault.Vault_DepositAmountIsZero.selector);
        vault.deposit{value: 0}();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. User deposits 'amount' ETH
        vm.startPrank(user); // Actions performed as 'user'
        console.log("User's ETH balance before deposit:", user.balance);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);
        console.log("User's ETH balance before redeem:", user.balance);

        vault.redeem(amount);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertEq(endBalance, 0);
        console.log("User's ETH balance after redeem:", user.balance);
        assertEq(address(user).balance, amount);
        vm.stopPrank(); //
    }

    function testRedeemAllTokens() public {
        uint256 depositAmount = 1 ether;
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        vault.redeem(type(uint256).max);

        assertEq(user.balance, balanceBefore + depositAmount);
        assertEq(rebaseToken.balanceOf(user), 0);
    }

    function testRedeemPartialAmount() public {
        uint256 depositAmount = 2 ether;
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        uint256 redeemAmount = 1 ether;
        vm.prank(user);
        vault.redeem(redeemAmount);

        assertEq(rebaseToken.balanceOf(user), depositAmount - redeemAmount);
        assertEq(user.balance, redeemAmount); // if user started at 0
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        // 1. User deposits 'amount' ETH
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);
        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        // 1. User deposits 'amount' ETH
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2BalanceBefore = rebaseToken.balanceOf(user2);
        assertEq(user2BalanceBefore, 0);
        assertEq(userBalance, amount);

        // owner decreases interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 2. User transfers 'amountToSend' to 'user2'
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 user2BalanceAfter = rebaseToken.balanceOf(user2);
        assertEq(user2BalanceAfter, amountToSend);
        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        assertEq(userBalanceAfter, amount - amountToSend);

        // check if interest rate is still 4e10
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
        // vm.stopPrank();
    }

    function testCannotSetTheInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(Ownable.OwnableUnauthorizedAccount.selector));
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testcannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.mint(user, 100);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.burn(user, 100);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseToken(), address(rebaseToken));
    }

    function testprincipleBalanceOf(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 principleBalance = rebaseToken.principleBalanceOf(user);
        assertEq(principleBalance, amount);
        vm.warp(block.timestamp + 1 hours);
        uint256 newPrincipleBalance = rebaseToken.principleBalanceOf(user);
        assertEq(newPrincipleBalance, amount);
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }

    function testGrantMintAndBurnRole() public {
        // Grant the MINT_AND_BURN_ROLE to the Vault contract.
        vm.prank(owner);
        rebaseToken.grantMintAndBurnRole(address(vault));
        assertTrue(rebaseToken.hasRole(rebaseToken.MINT_AND_BURN_ROLE(), address(vault)));
    }

    function testTransferFrom(address _sender, address _recipient, uint256 _amount) public {
        _sender = makeAddr("sender");
        _recipient = makeAddr("recipient");
        _amount = bound(_amount, 1e5, type(uint96).max);

        // 1. User deposits 'amount' ETH
        vm.deal(_sender, _amount);
        vm.prank(_sender);
        vault.deposit{value: _amount}();

        // 2. Approve the recipient to transfer tokens on behalf of the sender
        vm.prank(_sender);
        rebaseToken.approve(_recipient, _amount);

        // 3. Transfer tokens from sender to recipient
        vm.prank(_recipient);
        rebaseToken.transferFrom(_sender, _recipient, _amount);

        uint256 senderBalanceAfter = rebaseToken.balanceOf(_sender);
        uint256 recipientBalanceAfter = rebaseToken.balanceOf(_recipient);

        assertEq(senderBalanceAfter, 0);
        assertEq(recipientBalanceAfter, _amount);
    }
}
