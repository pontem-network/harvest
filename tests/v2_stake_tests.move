#[test_only]
module harvest::v2_stake_tests {
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;
    use liquidswap::curves::Uncorrelated;
    use liquidswap_lp::lp_coin::LP;

    use harvest::v2_stake;
    use harvest::staking_test_helpers::{create_account, initialize_btc_usdt_coins, mint_coins, BTC, USDT, create_pool_with_liquidity};

    #[test(harvest = @harvest)]
    public fun test_initialize(harvest: &signer) {
        let harvest_addr = signer::address_of(harvest);

        create_account(harvest_addr);
        v2_stake::initialize(harvest);
    }

    #[test(harvest = @harvest, test_user = @test_user)]
    public fun test_register(harvest: &signer, test_user: &signer) {
        genesis::setup();

        let harvest_addr = signer::address_of(harvest);
        let test_user_addr = signer::address_of(test_user);

        create_account(harvest_addr);
        create_account(test_user_addr);

        initialize_btc_usdt_coins(harvest);

        let btc_coins_liq = mint_coins<BTC>(100000000);
        let usdt_coins_liq = mint_coins<USDT>(10000000000);

        let lps = create_pool_with_liquidity<BTC, USDT>(
            test_user,
            btc_coins_liq,
            usdt_coins_liq,
        );
        coin::register<LP<BTC, USDT, Uncorrelated>>(test_user);
        coin::deposit(test_user_addr, lps);

        let start_time = 682981200;
        timestamp::fast_forward_seconds(start_time);

        let reward_per_sec_rate = 10000000;
        v2_stake::initialize(harvest);
        v2_stake::register<BTC, USDT, Uncorrelated>(test_user, reward_per_sec_rate);

        //
        // // create lp coins for pool to be valid
        // let lp_coin = btc_usdt_pool_with_999_liqudity();
        // let (_, _) = create_account_with_lp_coins(@0x12, lp_coin);
        //
        // let start_time = 682981200;
        // timestamp::update_global_time_for_test_secs(start_time);
        //
        // // register staking pool
        // let reward_per_sec_rate = 10 * ONE_DGEN;
        // v2_stake::initialize(&staking_admin_acc);
        // v2_stake::register<BTC, USDT, Uncorrelated>(&alice_acc, reward_per_sec_rate);

        // check pool statistics
        // let (reward_per_sec, accum_reward, last_updated) =
        //     v2_stake::get_pool_info<BTC, USDT, Uncorrelated>();
        // assert!(reward_per_sec == reward_per_sec_rate, 1);
        // assert!(accum_reward == 0, 1);
        // assert!(last_updated == start_time, 1);
        // assert!(v2_stake::get_pool_total_stake<BTC, USDT, Uncorrelated>() == 0, 1);
    }

    // #[test]
    // public fun test_deposit_reward_coins() {
    //     let (staking_admin_acc, _) = create_account(@harvest);
    //
    //     // create lp coins for pool to be valid
    //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    //     let (_, _) = create_account_with_lp_coins(@0x12, lp_coin);
    //
    //     // mint DGEN coins
    //     let liq_coins = mint_dgen_coins(&staking_admin_acc, 100);
    //
    //     // register staking pool
    //     let reward_per_sec_rate = 10 * ONE_DGEN;
    //     v2_stake::initialize(&staking_admin_acc);
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    //
    //     v2_stake::deposit_reward_coins<BTC, USDT, Uncorrelated>(&staking_admin_acc, liq_coins);
    // }
    //
    // #[test]
    // public fun test_stake_and_unstake() {
    //     let (staking_admin_acc, _) = create_account(@harvest);
    //
    //     // create lp coins
    //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    //     let lp_coin_part = coin::extract(&mut lp_coin, 99 * ONE_LP);
    //
    //     // create alice and bob with LP coins
    //     let (alice_acc, alice_addr) =
    //         create_account_with_lp_coins(@0x10, lp_coin);
    //     let (bob_acc, bob_addr) =
    //         create_account_with_lp_coins(@0x11, lp_coin_part);
    //
    //     // register staking pool
    //     let reward_per_sec_rate = 10 * ONE_DGEN;
    //     v2_stake::initialize(&staking_admin_acc);
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    //
    //     // check empty balances
    //     assert!(v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 0, 1);
    //     assert!(v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 0, 1);
    //
    //     // stake 500 LP from alice
    //     let coins =
    //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 500 * ONE_LP);
    //     v2_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins, 604800);
    //     assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 400 * ONE_LP, 1);
    //     assert!(v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 500 * ONE_LP, 1);
    //     assert!(v2_stake::get_pool_total_stake<BTC, USDT, Uncorrelated>() == 500 * ONE_LP, 1);
    //
    //     // stake 99 LP from bob
    //     let coins =
    //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&bob_acc, 99 * ONE_LP);
    //     v2_stake::stake<BTC, USDT, Uncorrelated>(&bob_acc, coins, 604800);
    //     assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(bob_addr) == 0, 1);
    //     assert!(v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 99 * ONE_LP, 1);
    //     assert!(v2_stake::get_pool_total_stake<BTC, USDT, Uncorrelated>() == 599 * ONE_LP, 1);
    //     //
    //     // // stake 300 LP more from alice
    //     // let coins =
    //     //     coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 300 * ONE_LP);
    //     // v2_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    //     // assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 100 * ONE_LP, 1);
    //     // assert!(v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 800 * ONE_LP, 1);
    //     // assert!(v2_stake::get_pool_total_stake<BTC, USDT, Uncorrelated>() == 899 * ONE_LP, 1);
    //
    //     // // unstake 400 LP from alice
    //     // let coins =
    //     //     v2_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 400 * ONE_LP);
    //     // assert!(coin::value(&coins) == 400 * ONE_LP, 1);
    //     // assert!(v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 400 * ONE_LP, 1);
    //     // assert!(v2_stake::get_pool_total_stake<BTC, USDT, Uncorrelated>() == 499 * ONE_LP, 1);
    //     // coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    //     //
    //     // // unstake all 99 LP from bob
    //     // let coins =
    //     //     v2_stake::unstake<BTC, USDT, Uncorrelated>(&bob_acc, 99 * ONE_LP);
    //     // assert!(coin::value(&coins) == 99 * ONE_LP, 1);
    //     // assert!(v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 0, 1);
    //     // assert!(v2_stake::get_pool_total_stake<BTC, USDT, Uncorrelated>() == 400 * ONE_LP, 1);
    //     // coin::deposit<LP<BTC, USDT, Uncorrelated>>(bob_addr, coins);
    // }
    // //
    // // #[test]
    // // public fun test_reward_calculation() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // create lp coins
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //     let lp_coin_part = coin::extract(&mut lp_coin, 99 * ONE_LP);
    // //
    // //     // create alice and bob with LP coins
    // //     let (alice_acc, alice_addr) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //     let (bob_acc, bob_addr) =
    // //         create_account_with_lp_coins(@0x11, lp_coin_part);
    // //
    // //     let start_time = 682981200;
    // //     timestamp::update_global_time_for_test_secs(start_time);
    // //
    // //     // register staking pool
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     v2_stake::initialize(&staking_admin_acc);
    // //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // stake 100 LP from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * ONE_LP);
    // //     v2_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //
    // //     // check stake parameters
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
    // //     assert!(unobtainable_reward == 0, 1);
    // //     assert!(earned_reward == 0, 1);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 10);
    // //
    // //     // synthetic recalculate
    // //     v2_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
    // //
    // //     // check pool parameters
    // //     let (_, accum_reward, last_updated) =
    // //         v2_stake::get_pool_info<BTC, USDT, Uncorrelated>();
    // //     // (reward_per_sec_rate * time passed / total_staked) + previous period
    // //     assert!(accum_reward == to_u128(1 * ONE_DGEN), 1);
    // //     assert!(last_updated == start_time + 10, 1);
    // //
    // //     // check alice's stake
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
    // //     assert!(unobtainable_reward == to_u128(100 * ONE_DGEN), 1);
    // //     assert!(earned_reward == 100 * ONE_DGEN, 1);
    // //
    // //     // stake 50 LP from bob
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&bob_acc, 50 * ONE_LP);
    // //     v2_stake::stake<BTC, USDT, Uncorrelated>(&bob_acc, coins);
    // //
    // //     // check bob's stake parameters
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
    // //     // stake amount * pool accum_reward
    // //     // accumulated benefit that does not belong to bob
    // //     assert!(unobtainable_reward == to_u128(50 * ONE_DGEN), 1);
    // //     assert!(earned_reward == 0, 1);
    // //
    // //     // stake 100 LP more from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * ONE_LP);
    // //     v2_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 20);
    // //
    // //     // synthetic recalculate
    // //     v2_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
    // //     v2_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(bob_addr);
    // //
    // //     // check pool parameters
    // //     let (_, accum_reward, last_updated) =
    // //         v2_stake::get_pool_info<BTC, USDT, Uncorrelated>();
    // //     assert!(accum_reward == 1400000, 1);
    // //     assert!(last_updated == start_time + 20, 1);
    // //
    // //     // check alice's stake parameters
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
    // //     assert!(unobtainable_reward == to_u128(280 * ONE_DGEN), 1);
    // //     assert!(earned_reward == 180 * ONE_DGEN, 1);
    // //
    // //     // check bob's stake parameters
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
    // //     assert!(unobtainable_reward == to_u128(70 * ONE_DGEN), 1);
    // //     assert!(earned_reward == 20 * ONE_DGEN, 1);
    // //
    // //     // unstake 100 LP from alice
    // //     let coins =
    // //         v2_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 100 * ONE_LP);
    // //     coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    // //
    // //     // check alice's stake parameters
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
    // //     assert!(unobtainable_reward == to_u128(140 * ONE_DGEN), 1);
    // //     assert!(earned_reward == 180 * ONE_DGEN, 1);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 30);
    // //
    // //     // synthetic recalculate
    // //     v2_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
    // //     v2_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(bob_addr);
    // //
    // //     // check pool parameters
    // //     let (_, accum_reward, last_updated) =
    // //         v2_stake::get_pool_info<BTC, USDT, Uncorrelated>();
    // //     assert!(accum_reward == 2066666, 1);
    // //     assert!(last_updated == start_time + 30, 1);
    // //
    // //     // check alice's stake parameters
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
    // //     assert!(unobtainable_reward == 206666600, 1);
    // //     assert!(earned_reward == 246666600, 1);
    // //
    // //     // check bob's stake parameters
    // //     let (unobtainable_reward, earned_reward) =
    // //         v2_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
    // //     assert!(unobtainable_reward == 103333300, 1);
    // //     assert!(earned_reward == 53333300, 1);
    // // }
    //
    // #[test]
    // public fun test_unstake() {
    //     let (staking_admin_acc, _) = create_account(@harvest);
    //
    //     // create lp coins
    //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    //
    //     // create alice with LP coins
    //     let (alice_acc, alice_addr) =
    //         create_account_with_lp_coins(@0x10, lp_coin);
    //
    //     let start_time = 682981200;
    //     timestamp::update_global_time_for_test_secs(start_time);
    //
    //     // register staking pool
    //     let reward_per_sec_rate = 10 * ONE_DGEN;
    //     v2_stake::initialize(&staking_admin_acc);
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    //
    //     // stake 500 LP from alice
    //     let coins =
    //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 500 * ONE_LP);
    //     v2_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins, 604800);
    //
    //     timestamp::update_global_time_for_test_secs(start_time + 604800 + 1);
    //
    //     let coins = v2_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc,0, 1);
    //     coin::deposit(alice_addr, coins);
    //
    //
    //
    // }
    // // #[test]
    // // public fun test_harvest() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // mint DGEN coins
    // //     let liq_coins = mint_dgen_coins(&staking_admin_acc, 300 * ONE_DGEN);
    // //
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //     let lp_coin_part = coin::extract(&mut lp_coin, 100 * ONE_LP);
    // //
    // //     // create alice and bob with LP coins
    // //     let (alice_acc, alice_addr) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //     let (bob_acc, bob_addr) =
    // //         create_account_with_lp_coins(@0x11, lp_coin_part);
    // //
    // //     coin::register<DGEN>(&alice_acc);
    // //     coin::register<DGEN>(&bob_acc);
    // //
    // //     let start_time = 682981200;
    // //     timestamp::update_global_time_for_test_secs(start_time);
    // //
    // //     // register staking pool with DGEN
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     v2_stake::initialize(&staking_admin_acc);
    // //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //     stake::deposit_reward_coins<BTC, USDT, Uncorrelated>(&staking_admin_acc, liq_coins);
    // //
    // //     // stake 100 LP from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * ONE_LP);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 10);
    // //
    // //     // harvest from alice
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //
    // //     // check amounts
    // //     let (_, earned_reward) =
    // //         stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
    // //     assert!(earned_reward == 0, 1);
    // //     assert!(coin::value(&coins) == 100 * ONE_DGEN, 1);
    // //
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // //
    // //     // stake 100 LP from bob
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&bob_acc, 100 * ONE_LP);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&bob_acc, coins);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 20);
    // //
    // //     // harvest from alice
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //
    // //     // check amounts
    // //     let (_, earned_reward) =
    // //         stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
    // //     assert!(earned_reward == 0, 1);
    // //     assert!(coin::value(&coins) == 50 * ONE_DGEN, 1);
    // //
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // //
    // //     // harvest from bob
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&bob_acc);
    // //
    // //     // check amounts
    // //     let (_, earned_reward) =
    // //         stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
    // //     assert!(earned_reward == 0, 1);
    // //     assert!(coin::value(&coins) == 50 * ONE_DGEN, 1);
    // //
    // //     coin::deposit<DGEN>(bob_addr, coins);
    // //
    // //     // unstake 100 LP from alice
    // //     let coins =
    // //         stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc,  100 * ONE_LP);
    // //     coin::deposit<LP<BTC, USDT, Uncorrelated>>(bob_addr, coins);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 30);
    // //
    // //     // harvest from bob
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&bob_acc);
    // //
    // //     // check amounts
    // //     let (_, earned_reward) =
    // //         stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
    // //     assert!(earned_reward == 0, 1);
    // //     assert!(coin::value(&coins) == 100 * ONE_DGEN, 1);
    // //
    // //     coin::deposit<DGEN>(bob_addr, coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    // // public fun test_deposit_reward_coins_fails_if_pool_does_not_exist() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // mint DGEN coins
    // //     let liq_coins = mint_dgen_coins(&staking_admin_acc, 100);
    // //
    // //     stake::deposit_reward_coins<BTC, USDT, Uncorrelated>(&staking_admin_acc, liq_coins);
    // // }
    // //
    // #[test]
    // #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    // public fun test_stake_fails_if_pool_does_not_exist() {
    //     // create lp coins
    //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    //
    //     // create alice with LP coins
    //     let (alice_acc, _) =
    //         create_account_with_lp_coins(@0x10, lp_coin);
    //
    //     // stake from alice
    //     let coins =
    //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 12345);
    //     v2_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins, 604800);
    // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    // // public fun test_unstake_fails_if_pool_does_not_exist() {
    // //     let (alice_acc, alice_addr) = create_account(@0x10);
    // //
    // //     // unstake from alice
    // //     let coins =
    // //         stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 12345);
    // //     coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    // // public fun test_harvest_fails_if_pool_does_not_exist() {
    // //     let (alice_acc, alice_addr) = create_account(@0x10);
    // //
    // //     // harvest from alice
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // // }
    //
    // #[test]
    // #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    // public fun test_get_pool_total_staked_fails_if_pool_does_not_exist() {
    //     v2_stake::get_pool_total_stake<BTC, USDT, Uncorrelated>();
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    // public fun test_get_user_stake_fails_if_pool_does_not_exist() {
    //     let (_, alice_addr) = create_account(@0x10);
    //
    //     v2_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = 101 /* ERR_POOL_ALREADY_EXISTS */)]
    // public fun test_register_fails_if_pool_already_exists() {
    //     let (staking_admin_acc, _) = create_account(@harvest);
    //
    //     // create lp coins for pool to be valid
    //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    //     let (_, _) = create_account_with_lp_coins(@0x12, lp_coin);
    //
    //     // register staking pool twice
    //     let reward_per_sec_rate = 10 * ONE_DGEN;
    //     v2_stake::initialize(&staking_admin_acc);
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = 102 /* ERR_REWARD_CANNOT_BE_ZERO */)]
    // public fun test_register_fails_if_reward_is_zero() {
    //     let (staking_admin_acc, _) = create_account(@harvest);
    //
    //     // register staking pool with zero reward
    //     v2_stake::initialize(&staking_admin_acc);
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, 0);
    // }
    //
    // // #[test]
    // // #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    // // public fun test_unstake_fails_if_stake_not_exists() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //     let (alice_acc, alice_addr) = create_account(@0x10);
    // //
    // //     // create lp coins for pool to be valid
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //     let (_, _) = create_account_with_lp_coins(@0x12, lp_coin);
    // //
    // //     // register staking pool
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // unstake from alice
    // //     let coins =
    // //         stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 40);
    // //     coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    // // public fun test_harvest_fails_if_stake_not_exists() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //     let (alice_acc, alice_addr) = create_account(@0x10);
    // //
    // //     // create lp coins for pool to be valid
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //     let (_, _) = create_account_with_lp_coins(@0x12, lp_coin);
    // //
    // //     // register staking pool
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // harvest from alice
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 104 /* ERR_NOT_ENOUGH_BALANCE */)]
    // // public fun test_unstake_fails_if_not_enough_balance() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // create lp coins
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //
    // //     // create alice with LP coins
    // //     let (alice_acc, alice_addr) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //
    // //     // register staking pool
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // stake from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 999 * ONE_LP);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //     assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 0, 1);
    // //     assert!(stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 999 * ONE_LP, 1);
    // //
    // //     // unstake more than staked from alice
    // //     let coins =
    // //         stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 1000 * ONE_LP);
    // //     coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    // // }
    //
    // #[test]
    // #[expected_failure(abort_code = 105 /* ERR_NO_PERMISSIONS */)]
    // public fun test_initialize_fails_if_executed_not_by_admin() {
    //     let (alice_acc, _) = create_account(@0x10);
    //
    //     // initialize staking pool from wrong account
    //     v2_stake::initialize(&alice_acc);
    // }
    //
    // // #[test]
    // // #[expected_failure(abort_code = 105 /* ERR_NO_PERMISSIONS */)]
    // // public fun test_deposit_reward_coins_fails_if_executed_not_by_admin() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //     let (alice_acc, _) = create_account(@0x10);
    // //
    // //     // create lp coins for pool to be valid
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //     let (_, _) = create_account_with_lp_coins(@0x12, lp_coin);
    // //
    // //     // mint DGEN coins
    // //     let liq_coins = mint_dgen_coins(&staking_admin_acc, 100);
    // //
    // //     // register staking pool twice
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     stake::deposit_reward_coins<BTC, USDT, Uncorrelated>(&alice_acc, liq_coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 106 /* ERR_NOT_ENOUGH_DGEN_BALANCE */)]
    // // public fun test_harvest_fails_if_not_enough_pool_liq_balance() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // create lp coins
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //
    // //     // create alice with LP coins
    // //     let (alice_acc, alice_addr) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //
    // //     let start_time = 682981200;
    // //     timestamp::update_global_time_for_test_secs(start_time);
    // //
    // //     // register staking pool
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // stake 100 LP from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * ONE_LP);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 10);
    // //
    // //     // harvest from alice
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // // }
    //
    // // todo: stake is valid if amount is zero but lock duration is greater
    // // #[test]
    // // #[expected_failure(abort_code = 107 /* ERR_AMOUNT_CANNOT_BE_ZERO */)]
    // // public fun test_stake_fails_if_amount_is_zero() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // create lp coins
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //
    // //     // create alice with LP coins
    // //     let (alice_acc, _) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //
    // //     // register staking pool
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // stake 0 LP from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 0);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 107 /* ERR_AMOUNT_CANNOT_BE_ZERO */)]
    // // public fun test_unstake_fails_if_amount_is_zero() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // create lp coins
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //
    // //     // create alice with LP coins
    // //     let (alice_acc, alice_addr) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //
    // //     // register staking pool
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // stake from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 999 * ONE_LP);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //
    // //     // unstake 0 LP from alice
    // //     let coins =
    // //         stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 0);
    // //     coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 108 /* ERR_NOTHING_TO_HARVEST */)]
    // // public fun test_harvest_fails_if_nothing_to_harvest_1() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //
    // //     // create alice with LP coins
    // //     let (alice_acc, alice_addr) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //
    // //     let start_time = 682981200;
    // //     timestamp::update_global_time_for_test_secs(start_time);
    // //
    // //     // register staking pool with DGEN
    // //     let reward_per_sec_rate = 10 * ONE_DGEN;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //
    // //     // stake 100 LP from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * ONE_LP);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //
    // //     // harvest from alice at the same second
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // // }
    // //
    // // #[test]
    // // #[expected_failure(abort_code = 108 /* ERR_NOTHING_TO_HARVEST */)]
    // // public fun test_harvest_fails_if_nothing_to_harvest_2() {
    // //     let (staking_admin_acc, _) = create_account(@harvest);
    // //
    // //     // mint DGEN coins
    // //     let liq_coins = mint_dgen_coins(&staking_admin_acc, 300 * ONE_DGEN);
    // //
    // //     let lp_coin = btc_usdt_pool_with_999_liqudity();
    // //
    // //     // create alice with LP coins
    // //     let (alice_acc, alice_addr) =
    // //         create_account_with_lp_coins(@0x10, lp_coin);
    // //
    // //     coin::register<DGEN>(&alice_acc);
    // //
    // //     let start_time = 682981200;
    // //     timestamp::update_global_time_for_test_secs(start_time);
    // //
    // //     // register staking pool with DGEN
    // //     let reward_per_sec_rate = 10 * ONE_LP;
    // //     stake::initialize(&staking_admin_acc);
    // //     stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // //     stake::deposit_reward_coins<BTC, USDT, Uncorrelated>(&staking_admin_acc, liq_coins);
    // //
    // //     // stake 100 LP from alice
    // //     let coins =
    // //         coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * ONE_LP);
    // //     stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    // //
    // //     // wait 10 seconds
    // //     timestamp::update_global_time_for_test_secs(start_time + 10);
    // //
    // //     // harvest from alice twice at the same second
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // //     let coins =
    // //         stake::harvest<BTC, USDT, Uncorrelated>(&alice_acc);
    // //     coin::deposit<DGEN>(alice_addr, coins);
    // // }
    // //
    // #[test]
    // #[expected_failure(abort_code = 109 /* ERR_MODULE_NOT_INITIALIZED */)]
    // public fun test_register_fails_if_module_not_initialized() {
    //     let (staking_admin_acc, _) = create_account(@harvest);
    //
    //     // register staking pool before module initialization
    //     let reward_per_sec_rate = 10 * ONE_DGEN;
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = 110 /* ERR_IS_NOT_COIN */)]
    // public fun test_register_fails_if_cointype_is_not_coin() {
    //     let (staking_admin_acc, _) = create_account(@harvest);
    //
    //     // register staking pool with undeployed coins
    //     let reward_per_sec_rate = 10 * ONE_DGEN;
    //     v2_stake::initialize(&staking_admin_acc);
    //     v2_stake::register<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    // }
}
