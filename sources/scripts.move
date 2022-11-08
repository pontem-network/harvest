module harvest::scripts {
    use harvest::stake;
    use aptos_framework::coin;
    use std::signer;

    public entry fun register_pool<S, R>(pool_owner: &signer, reward_per_sec: u64) {
        stake::register_pool<S, R>(pool_owner, reward_per_sec);
    }

    public entry fun stake<S, R>(user: &signer, pool_addr: address, amount: u64) {
        let coins = coin::withdraw<S>(user, amount);
        stake::stake<S, R>(user, pool_addr, coins);
    }

    public entry fun unstake<S, R>(user: &signer, pool_addr: address, amount: u64) {
        let coins = stake::unstake<S, R>(user, pool_addr, amount);
        // wallet should exist
        coin::deposit(signer::address_of(user), coins);
    }

    public entry fun harvest<S, R>(user: &signer, pool_addr: address) {
        let rewards = stake::harvest<S, R>(user, pool_addr);

        let user_addr = signer::address_of(user);
        if (!coin::is_account_registered<R>(user_addr)) {
            coin::register<R>(user);
        };

        coin::deposit(user_addr, rewards);
    }

    // public entry fun deposit_reward_coins<S, R>(depositor: &signer, pool_addr: address, amount: u64) {
    //     let reward_coins = coin::withdraw<R>(depositor, amount);
    //     stake::deposit_reward_coins<S, R>(depositor, reward_coins);
    // }
}
