module dgen_owner::lp_pool {
    use aptos_framework::coin;

    use harvest::scripts;
    use liquidswap_lp::lp_coin::LP;

    use dgen_owner::dgen::DGEN;

    const ERR_LP_COIN_NOT_INITIALIZED: u64 = 1;

    public entry fun register_lp_pool<X, Y, Curve>(pool_owner: &signer, reward_per_sec: u64) {
        assert!(coin::is_coin_initialized<LP<X, Y, Curve>>(), ERR_LP_COIN_NOT_INITIALIZED);
        scripts::register_pool<LP<X, Y, Curve>, DGEN>(pool_owner, reward_per_sec);
    }

    public entry fun deposit_rewards<X, Y, Curve>(account: &signer, pool_addr: address, amount: u64) {
        scripts::deposit_reward_coins<LP<X, Y, Curve>, DGEN>(account, pool_addr, amount);
    }

    public entry fun stake<X, Y, Curve>(user: &signer, pool_addr: address, amount: u64) {
        scripts::stake<LP<X, Y, Curve>, DGEN>(user, pool_addr, amount);
    }

    public entry fun unstake<X, Y, Curve>(user: &signer, pool_addr: address, amount: u64) {
        scripts::unstake<LP<X, Y, Curve>, DGEN>(user, pool_addr, amount);
    }

    public entry fun harvest<X, Y, Curve>(user: &signer, pool_addr: address) {
        scripts::harvest<LP<X, Y, Curve>, DGEN>(user, pool_addr);
    }
}
