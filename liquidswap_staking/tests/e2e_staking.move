#[test_only]
module dgen_owner::e2e_staking {
    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use harvest::stake;
    use liquidswap::curves::Uncorrelated;
    use liquidswap_lp::lp_coin::LP;

    use dgen_owner::dgen::DGEN;
    use dgen_owner::lovely_helpers::{create_account, initialize_btc_usdt_coins, mint_coins, create_pool_with_liquidity, BTC, USDT};

    #[test(dgen_owner = @dgen_owner, harvest = @harvest/*, alice = @alice*/)]
    public fun test_e2e_staking(harvest: &signer, dgen_owner: &signer, /*alice: &signer*/) {
        genesis::setup();

        let (dgen_owner_acc, dgen_owner_addr) = create_account(dgen_owner);
        let (harvest_acc/*, harvest_addr*/, _) = create_account(harvest);
        // let (alice_acc, alice_addr) = create_account(alice);

        // mint DGEN coins for pool reward
        // let dgen_coins = mint_dgen_coins(&dgen_owner_acc, 1000000000);

        // mint LP coins for pool stake
        initialize_btc_usdt_coins(&dgen_owner_acc);

        let btc_coins = mint_coins<BTC>(100000000);
        let usd_coins = mint_coins<USDT>(10000000000);

        let lp_coins = create_pool_with_liquidity<BTC, USDT>(&dgen_owner_acc, btc_coins, usd_coins);

        // remove us
        std::debug::print(&coin::value(&lp_coins));
        coin::deposit(dgen_owner_addr, lp_coins);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        stake::register_pool<LP<BTC, USDT, Uncorrelated>, DGEN>(&harvest_acc, 1000000);
    }
}