# Cross-chain-rebase-token

1. A protocol that allows users to deposit into a vault and receive an equal amount of rebase tokens that represent their balance in the vault.
2. Rebase token where the balanceOf function is dynamic to show the increasing balance with time.
    - Balance increases linearly with time
    - mint tokens to our users everytime they perform an action(minting, burning , bridging)
3.  Interest rate 
    - Set an interest rate for each user based on the global interest rate at the time of depositing money in the vault 
    - The global interest rate decreases gradually in order to reward early adopters.
    - Increase token adoption