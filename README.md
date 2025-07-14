# Cross-chain Rebase Token

1. A protocol that allow user to deposite into a vault and in return, recieve rebase tokens that represent their underlying balance.
2. Rebase token -> balanceOf function is dynammic to show the changing balance with time.
     - Balance increases linearly with time 
     - Mint tokens to our users every time they perform an action(minting, burning, transferring, or.....bridging)
3. Interest rate
    - Indivuelly set an interest rate or each user based on some global interest rate of the protocol at the same time the user deposits into vault.
    - This global interest rate can only decrease to incetivese/reward early adopters.
    -Increase token adoption!