/// Collection of entrypoints to handle staking pools.
module harvest::scripts {
    use std::signer;
    use std::option;

    use aptos_framework::coin;

    use harvest::stake;

    // todo: update register_pool func params
    /// Register new staking pool with staking coin `S` and reward coin `R`.
    ///     * `pool_owner` - account which will be used as a pool storage.
    ///     * `reward_per_sec` - how many reward coins `R` to grant to stake owners every second.
    public entry fun register_pool<S, R>(pool_owner: &signer, reward_per_sec: u64) {
        stake::register_pool<S, R>(pool_owner, reward_per_sec, option::none());
    }

    /// Register new staking pool with staking coin `S` and reward coin `R`, and deposit reward coins `R` at the same time.
    ///     * `pool_owner` - account which will be used as a pool storage.
    ///     * `reward_per_sec` - how many reward coins `R` to grant to stake owners every second.
    ///     * `rewards_amount` - how many reward coins `R` to deposit at the time of registering a pool.
    public entry fun register_pool_with_rewards<S, R>(pool_owner: &signer, reward_per_sec: u64, rewards_amount: u64) {
        register_pool<S, R>(pool_owner, reward_per_sec);

        let pool_addr = signer::address_of(pool_owner);
        deposit_reward_coins<S, R>(pool_owner, pool_addr, rewards_amount);
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
        stake::deposit_reward_coins<S, R>(pool_addr, reward_coins);
    }

    /// Enable "emergency state" for a pool on a `pool_addr` address. This state cannot be disabled
    /// and removes all operations except for `emergency_unstake()`, which unstakes all the coins for a user.
    public entry fun enable_emergency<S, R>(admin: &signer, pool_addr: address) {
        stake::enable_emergency<S, R>(admin, pool_addr);
    }

    // todo: repair emergency_unstake
    // /// Unstake all the coins of the user. Only callable in "emergency state".
    // public entry fun emergency_unstake<S, R>(user: &signer, pool_addr: address) {
    //     let stake_coins = stake::emergency_unstake<S, R>(user, pool_addr);
    //     // wallet should exist
    //     coin::deposit(signer::address_of(user), stake_coins);
    // }
}
