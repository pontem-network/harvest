/// Collection of entrypoints to handle staking pools.
module harvest::scripts {
    use std::option;
    use std::signer;

    use aptos_framework::coin;

    use harvest::stake;
    use aptos_token::token;

    // todo: add boost entry + tests
    // todo: add claim entry + tests

    // todo: update this function
    /// Register new staking pool with staking coin `S` and reward coin `R`.
    ///     * `pool_owner` - account which will be used as a pool storage.
    ///     * `amount` - reward amount in R coins.
    ///     * `duration` - pool life duration, can be increased by depositing more rewards.
    public entry fun register_pool<S, R>(pool_owner: &signer, amount: u64, duration: u64) {
        let rewards = coin::withdraw<R>(pool_owner, amount);
        stake::register_pool<S, R>(pool_owner, rewards, duration, option::none());
    }

    /// Stake an `amount` of `Coin<S>` to the pool of stake coin `S` and reward coin `R` on the address `pool_addr`.
    ///     * `user` - stake owner.
    ///     * `pool_addr` - address of the pool to stake.
    ///     * `amount` - amount of `S` coins to stake.
    public entry fun stake<S, R>(user: &signer, pool_addr: address, amount: u64) {
        let coins = coin::withdraw<S>(user, amount);
        stake::stake<S, R>(user, pool_addr, coins);
    }

    /// Unstake an `amount` of `Coin<S>` from a pool of stake coin `S` and reward coin `R` on the address `pool_addr`.
    ///     * `user` - stake owner.
    ///     * `pool_addr` - address of the pool to unstake.
    ///     * `amount` - amount of `S` coins to unstake.
    public entry fun unstake<S, R>(user: &signer, pool_addr: address, amount: u64) {
        let coins = stake::unstake<S, R>(user, pool_addr, amount);
        // wallet should exist
        coin::deposit(signer::address_of(user), coins);
    }

    /// Collect `user` rewards on the pool at the `pool_addr`.
    ///     * `user` - owner of the stake used to receive the rewards.
    ///     * `pool_addr` - address of the pool.
    public entry fun harvest<S, R>(user: &signer, pool_addr: address) {
        let rewards = stake::harvest<S, R>(user, pool_addr);
        let user_addr = signer::address_of(user);

        if (!coin::is_account_registered<R>(user_addr)) {
            coin::register<R>(user);
        };

        coin::deposit(user_addr, rewards);
    }

    /// Deposit more `Coin<R>` rewards to the pool.
    ///     * `depositor` - account with the `R` reward coins in the balance.
    ///     * `pool_addr` - address of the pool.
    ///     * `amount` - amount of the reward coin `R` to deposit.
    public entry fun deposit_reward_coins<S, R>(depositor: &signer, pool_addr: address, amount: u64) {
        let reward_coins = coin::withdraw<R>(depositor, amount);
        stake::deposit_reward_coins<S, R>(depositor, pool_addr, reward_coins);
    }

    /// Enable "emergency state" for a pool on a `pool_addr` address. This state cannot be disabled
    /// and removes all operations except for `emergency_unstake()`, which unstakes all the coins for a user.
    ///     * `admin` - current emergency admin account.
    ///     * `pool_addr` - address of the the pool.
    public entry fun enable_emergency<S, R>(admin: &signer, pool_addr: address) {
        stake::enable_emergency<S, R>(admin, pool_addr);
    }

    // todo: recheck this script
    // todo: create test with nft
    /// Unstake all the coins of the user and deposit to user account.
    /// Only callable in "emergency state".
    ///     * `user` - user account which has stake.
    ///     * `pool_addr` - address of the pool.
    public entry fun emergency_unstake<S, R>(user: &signer, pool_addr: address) {
        let (stake_coins, nft) = stake::emergency_unstake<S, R>(user, pool_addr);
        // wallet should exist
        coin::deposit(signer::address_of(user), stake_coins);
        if (option::is_some(&nft)) {
            token::deposit_token(user, option::extract(&mut nft));
        };

        option::destroy_none(nft);
    }

    /// Withdraw and deposit rewards to treasury.
    ///     * `treasury` - treasury account.
    ///     * `pool_addr` - pool address.
    ///     * `amount` - amount to withdraw.
    public entry fun withdraw_reward_to_treasury<S, R>(treasury: &signer, pool_addr: address, amount: u64) {
        let treasury_addr = signer::address_of(treasury);
        let rewards = stake::withdraw_to_treasury<S, R>(treasury, pool_addr, amount);

        if (!coin::is_account_registered<R>(treasury_addr)) {
            coin::register<R>(treasury);
        };

        coin::deposit(treasury_addr, rewards);
    }
}
