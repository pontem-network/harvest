#[test_only]
module lp_staking_admin::lp_staking_tests {
    use std::option;
    use std::string::utf8;

    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::{Self, AptosCoin};

    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_test_helpers::{Self, new_account};
    use liquidswap::curves::Uncorrelated;
    use liquidswap::router;
    use liquidswap_lp::lp_coin::LP;
    use test_helpers::test_pool;

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    struct BTC {}

    struct USDT {}

    #[test]
    fun test_liquidswap_staking_e2e() {
        let aptos_framework = stake_test_helpers::new_account(@aptos_framework);

        let (burn_cap, mint_cap)= aptos_coin::initialize_for_test(&aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        test_pool::initialize_liquidity_pool();

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        let lp_staking_admin_acc = stake_test_helpers::new_account(@lp_staking_admin);
        let harvest_acc = stake_test_helpers::new_account(@harvest);
        let alice_acc = stake_test_helpers::new_account(@alice);

        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::initialize(&emergency_admin, @treasury);

        // Registering AptosCoin on harvest account and mint.
        let minted_aptos_coins = coin::mint(100000000000000, &mint_cap);
        coin::register<AptosCoin>(&harvest_acc);
        coin::deposit(@harvest, minted_aptos_coins);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);

        // get LP coins
        stake_test_helpers::initialize_coin<BTC>(
            &lp_staking_admin_acc,
            utf8(b"BTC"),
            utf8(b"BTC"),
            6
        );
        stake_test_helpers::initialize_coin<USDT>(
            &lp_staking_admin_acc,
            utf8(b"USDT"),
            utf8(b"USDT"),
            6
        );

        router::register_pool<BTC, USDT, Uncorrelated>(&harvest_acc);

        let btc_coins = stake_test_helpers::mint_coin<BTC>(&lp_staking_admin_acc, 100000000);
        let usdt_coins = stake_test_helpers::mint_coin<USDT>(&lp_staking_admin_acc, 10000000000);
        let (btc_rem, usdt_rem, lp_coins) =
            router::add_liquidity<BTC, USDT, Uncorrelated>(btc_coins, 100000000, usdt_coins, 10000000000);
        coin::destroy_zero(btc_rem);
        coin::destroy_zero(usdt_rem);

        coin::register<AptosCoin>(&alice_acc);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&alice_acc);

        // register stake pool with 500 APT rewards. 0,0001 APT coins per second reward
        let aptos_coins = coin::withdraw<AptosCoin>(&harvest_acc, 50000000000);
        let duration = 5000000;
        stake::register_pool<LP<BTC, USDT, Uncorrelated>, AptosCoin>(&harvest_acc,
            aptos_coins, duration, option::none());

        // stake 999.999 LP from alice
        stake::stake<LP<BTC, USDT, Uncorrelated>, AptosCoin>(&alice_acc, @harvest, lp_coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(@alice) == 0, 1);
        assert!(stake::get_user_stake<LP<BTC, USDT, Uncorrelated>, AptosCoin>(@harvest, @alice) == 999999000, 1);
        assert!(stake::get_pool_total_stake<LP<BTC, USDT, Uncorrelated>, AptosCoin>(@harvest) == 999999000, 1);

        // wait one week
        timestamp::update_global_time_for_test_secs(start_time + 604800);

        // harvest from alice
        let coins =
            stake::harvest<LP<BTC, USDT, Uncorrelated>, AptosCoin>(&alice_acc, @harvest);
        assert!(stake::get_pending_user_rewards<LP<BTC, USDT, Uncorrelated>, AptosCoin>(@harvest, @alice) == 0, 1);
        // ~60.47 APT coins
        assert!(coin::value(&coins) == 6047999951, 1);
        coin::deposit(@alice, coins);

        // unstake all 999.999 LP coins from alice
        let coins =
            stake::unstake<LP<BTC, USDT, Uncorrelated>, AptosCoin>(&alice_acc, @harvest, 999999000);
        assert!(coin::value(&coins) == 999999000, 1);
        assert!(stake::get_user_stake<LP<BTC, USDT, Uncorrelated>, AptosCoin>(@harvest, @alice) == 0, 1);
        assert!(stake::get_pool_total_stake<LP<BTC, USDT, Uncorrelated>, AptosCoin>(@harvest) == 0, 1);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(@alice, coins);

        // 0.00000049 APT lost during calculations
        let (reward_per_sec, _, _, _, _) = stake::get_pool_info<LP<BTC, USDT, Uncorrelated>, AptosCoin>(@harvest);
        let total_rewards = WEEK_IN_SECONDS * reward_per_sec;
        let losed_rewards = total_rewards - coin::balance<AptosCoin>(@alice);

        assert!(losed_rewards == 49, 1);
    }
}
