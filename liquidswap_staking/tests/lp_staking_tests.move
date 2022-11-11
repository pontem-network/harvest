#[test_only]
module lp_staking_admin::lp_staking_tests {
    use std::string::utf8;

    use aptos_framework::genesis;

    use dgen_admin::dgen::{Self, DGEN};
    use harvest::stake;
    use harvest::stake_test_helpers;
    use liquidswap::curves::Uncorrelated;
    use liquidswap::router;
    use liquidswap_lp::lp_coin::LP;
    use test_helpers::test_pool;
    use aptos_framework::coin;

    const ONE_COIN: u64 = 1000000;

    struct BTC {}

    struct USDT {}

    #[test]
    fun test_liquidswap_staking_e2e() {
        genesis::setup();
        test_pool::initialize_liquidity_pool();

        let lp_staking_admin = stake_test_helpers::new_account(@lp_staking_admin);
        stake_test_helpers::initialize_coin<BTC>(
            &lp_staking_admin,
            utf8(b"BTC"),
            utf8(b"BTC"),
            6
        );
        stake_test_helpers::initialize_coin<USDT>(
            &lp_staking_admin,
            utf8(b"USDT"),
            utf8(b"USDT"),
            6
        );

        let harvest = stake_test_helpers::new_account(@harvest);
        router::register_pool<BTC, USDT, Uncorrelated>(&harvest);

        let btc_coins = stake_test_helpers::mint_coins<BTC>(&lp_staking_admin, 100);
        let usdt_coins = stake_test_helpers::mint_coins<USDT>(&lp_staking_admin, 10100);
        let (btc_rem, usdt_rem, lp_coins) =
            router::add_liquidity<BTC, USDT, Uncorrelated>(btc_coins, 100, usdt_coins, 10100);
        coin::destroy_zero(btc_rem);
        coin::destroy_zero(usdt_rem);

        let dgen_admin = stake_test_helpers::new_account(@dgen_admin);
        dgen::initialize(&dgen_admin);

        stake::register_pool<LP<BTC, USDT, Uncorrelated>, DGEN>(&harvest, 10);

        let dgen_coins = coin::withdraw<DGEN>(&dgen_admin, 100000);
        stake::deposit_reward_coins<LP<BTC, USDT, Uncorrelated>, DGEN>(@harvest, dgen_coins);

        let alice = stake_test_helpers::new_account(@alice);
        stake::stake<LP<BTC, USDT, Uncorrelated>, DGEN>(&alice, @harvest, lp_coins);

        stake::unstake<LP<BTC, USDT, Uncorrelated>>(&alice, );
    }
}
