#[test_only]
module staking_admin::liq_stake_tests {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::genesis;
    use liquidswap::curves::Uncorrelated;
    use liquidswap::liquidity_pool;
    use liquidswap_lp::lp_coin::LP;
    use test_coins::coins::{Self, USDT, BTC};
    use test_helpers::test_pool;

    use staking_admin::liq_stake;
    use aptos_framework::timestamp;

    // multiplier to account six decimal places for LP, LIQ and USDT coins
    const SIX_DECIMALS: u64 = 1000000;

    // multiplier to account eight decimal places for BTC coin
    const EIGHT_DECIMALS: u64 = 100000000;

    public fun create_account(account_address: address): (signer, address) {
        let new_acc = account::create_account_for_test(account_address);
        let new_addr = signer::address_of(&new_acc);

        (new_acc, new_addr)
    }

    public fun btc_usdt_pool_with_999_liqudity(): Coin<LP<BTC, USDT, Uncorrelated>> {
        let (coins_owner_acc, coins_owner_addr) = create_account(@test_coins);
        let (lp_owner, _) = create_account(@0x42);

        coins::register_coins(&coins_owner_acc);

        genesis::setup();
        test_pool::initialize_liquidity_pool();

        // create a new pool in Liquidswap
        liquidity_pool::register<BTC, USDT, Uncorrelated>(&lp_owner);

        // mint coins for LP
        let btc_amount = 1 * EIGHT_DECIMALS; // 1 BTC
        let usdt_amount = 10000 * SIX_DECIMALS; // 10 000 USDT
        coin::register<BTC>(&coins_owner_acc);
        coin::register<USDT>(&coins_owner_acc);
        coins::mint_coin<BTC>(&coins_owner_acc, coins_owner_addr, btc_amount);
        coins::mint_coin<USDT>(&coins_owner_acc, coins_owner_addr, usdt_amount);

        let coin_btc = coin::withdraw<BTC>(&coins_owner_acc, btc_amount);
        let coin_usdt = coin::withdraw<USDT>(&coins_owner_acc, usdt_amount);

        // mint 999,999 LP coins
        test_pool::mint_liquidity<BTC, USDT, Uncorrelated>(&lp_owner, coin_btc, coin_usdt);

        // return 999 LP coins
        coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&lp_owner, 999 * SIX_DECIMALS)
    }

    public fun create_account_with_lp_coins(
        account_address: address,
        coins: Coin<LP<BTC, USDT, Uncorrelated>>
    ): (signer, address) {
        let (new_acc, new_addr) = create_account(account_address);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&new_acc);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(new_addr, coins);

        (new_acc, new_addr)
    }

    #[test]
    public fun test_initialize() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        genesis::setup();

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // initialize staking pool
        let reward_per_sec_rate = 10 * SIX_DECIMALS; // 10 LIQ
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);

        // check pool statistics
        let (reward_per_sec, acc_reward, last_updated) =
            liq_stake::get_pool_info<BTC, USDT, Uncorrelated>();
        assert!(reward_per_sec == reward_per_sec_rate, 1);
        assert!(acc_reward == 0, 1);
        assert!(last_updated == start_time, 1);
        assert!(liq_stake::get_pool_total_staked<BTC, USDT, Uncorrelated>() == 0, 1);
        assert!(liq_stake::get_pool_total_earned<BTC, USDT, Uncorrelated>() == 0, 1);
        assert!(liq_stake::get_pool_total_paid<BTC, USDT, Uncorrelated>() == 0, 1);
    }

    #[test]
    public fun test_stake_and_unstake() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // create lp coins
        let lp_coin = btc_usdt_pool_with_999_liqudity();
        let lp_coin_part = coin::extract(&mut lp_coin, 99 * SIX_DECIMALS);

        // create alice and bob with LP coins
        let (alice_acc, alice_addr) =
            create_account_with_lp_coins(@0x10, lp_coin);
        let (bob_acc, bob_addr) =
            create_account_with_lp_coins(@0x11, lp_coin_part);

        // initialize staking pool
        let reward_per_sec_rate = 10 * SIX_DECIMALS; // 10 LIQ
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);

        // check empty balances
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 0, 1);
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 0, 1);

        // stake 500 LP from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 500 * SIX_DECIMALS);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 400 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 500 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_pool_total_staked<BTC, USDT, Uncorrelated>() == 500 * SIX_DECIMALS, 1);

        // stake 99 LP from bob
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&bob_acc, 99 * SIX_DECIMALS);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&bob_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(bob_addr) == 0, 1);
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 99 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_pool_total_staked<BTC, USDT, Uncorrelated>() == 599 * SIX_DECIMALS, 1);

        // stake 300 LP more from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 300 * SIX_DECIMALS);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 100 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 800 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_pool_total_staked<BTC, USDT, Uncorrelated>() == 899 * SIX_DECIMALS, 1);

        // unstake 400 LP from alice
        let coins =
            liq_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 400 * SIX_DECIMALS);
        assert!(coin::value(&coins) == 400 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 400 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_pool_total_staked<BTC, USDT, Uncorrelated>() == 499 * SIX_DECIMALS, 1);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);

        // unstake all 99 LP from bob
        let coins =
            liq_stake::unstake<BTC, USDT, Uncorrelated>(&bob_acc, 99 * SIX_DECIMALS);
        assert!(coin::value(&coins) == 99 * SIX_DECIMALS, 1);
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 0, 1);
        assert!(liq_stake::get_pool_total_staked<BTC, USDT, Uncorrelated>() == 400 * SIX_DECIMALS, 1);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(bob_addr, coins);
    }

    #[test]
    public fun test_reward_calculation() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // create lp coins
        let lp_coin = btc_usdt_pool_with_999_liqudity();
        let lp_coin_part = coin::extract(&mut lp_coin, 99 * SIX_DECIMALS);

        // create alice and bob with LP coins
        let (alice_acc, alice_addr) =
            create_account_with_lp_coins(@0x10, lp_coin);
        let (bob_acc, bob_addr) =
            create_account_with_lp_coins(@0x11, lp_coin_part);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // initialize staking pool
        let reward_per_sec_rate = 10 * SIX_DECIMALS; // 10 LIQ
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);

        // stake 100 LP from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * SIX_DECIMALS);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);

        // check stake parameters
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
        assert!(unobtainable_reward == 0, 1);
        assert!(earned_reward == 0, 1);
        assert!(harvested_reward == 0, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // synthetic recalculate
        liq_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(alice_addr);

        // check pool parameters
        let (_, acc_reward, last_updated) =
            liq_stake::get_pool_info<BTC, USDT, Uncorrelated>();
        // (reward_per_sec_rate * time passed / total_staked) + previous period
        assert!(acc_reward == 1 * SIX_DECIMALS, 1);
        assert!(last_updated == start_time + 10, 1);
        assert!(liq_stake::get_pool_total_earned<BTC, USDT, Uncorrelated>() == 100 * SIX_DECIMALS, 1);

        // check alice's stake
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
        assert!(unobtainable_reward == 100 * SIX_DECIMALS, 1);
        assert!(earned_reward == 100 * SIX_DECIMALS, 1);
        assert!(harvested_reward == 0, 1);

        // stake 50 LP from bob
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&bob_acc, 50 * SIX_DECIMALS);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&bob_acc, coins);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
        // stake amount * pool acc_reward
        // accumulated benefit that does not belong to bob
        assert!(unobtainable_reward == 50 * SIX_DECIMALS, 1);
        assert!(earned_reward == 0, 1);
        assert!(harvested_reward == 0, 1);

        // stake 100 LP more from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 100 * SIX_DECIMALS);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 20);

        // synthetic recalculate
        liq_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
        liq_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(bob_addr);

        // check pool parameters
        let (_, acc_reward, last_updated) =
            liq_stake::get_pool_info<BTC, USDT, Uncorrelated>();
        assert!(acc_reward == 1400000, 1);
        assert!(last_updated == start_time + 20, 1);
        assert!(liq_stake::get_pool_total_earned<BTC, USDT, Uncorrelated>() == 200 * SIX_DECIMALS, 1);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
        assert!(unobtainable_reward == 280 * SIX_DECIMALS, 1);
        assert!(earned_reward == 180 * SIX_DECIMALS, 1);
        assert!(harvested_reward == 0, 1);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
        assert!(unobtainable_reward == 70 * SIX_DECIMALS, 1);
        assert!(earned_reward == 20 * SIX_DECIMALS, 1);
        assert!(harvested_reward == 0, 1);

        // unstake 100 LP from alice
        let coins =
            liq_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 100 * SIX_DECIMALS);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
        assert!(unobtainable_reward == 140 * SIX_DECIMALS, 1);
        assert!(earned_reward == 180 * SIX_DECIMALS, 1);
        assert!(harvested_reward == 0, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 30);

        // synthetic recalculate
        liq_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
        liq_stake::recalculate_user_stake<BTC, USDT, Uncorrelated>(bob_addr);

        // check pool parameters
        let (_, acc_reward, last_updated) =
            liq_stake::get_pool_info<BTC, USDT, Uncorrelated>();
        assert!(acc_reward == 2066666, 1);
        assert!(last_updated == start_time + 30, 1);
        assert!(liq_stake::get_pool_total_earned<BTC, USDT, Uncorrelated>() == 299999900, 1);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(alice_addr);
        assert!(unobtainable_reward == 206666600, 1);
        assert!(earned_reward == 246666600, 1);
        assert!(harvested_reward == 0, 1);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward, harvested_reward) =
            liq_stake::get_user_stake_info<BTC, USDT, Uncorrelated>(bob_addr);
        assert!(unobtainable_reward == 103333300, 1);
        assert!(earned_reward == 53333300, 1);
        assert!(harvested_reward == 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_stake_fails_if_pool_does_not_exist() {
        // create lp coins
        let lp_coin = btc_usdt_pool_with_999_liqudity();

        // create alice with LP coins
        let (alice_acc, _) =
            create_account_with_lp_coins(@0x10, lp_coin);

        // stake from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 12345);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_unstake_fails_if_pool_does_not_exist() {
        let (alice_acc, alice_addr) = create_account(@0x10);

        // unstake from alice
        let coins =
            liq_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 12345);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_pool_total_staked_fails_if_pool_does_not_exist() {
        liq_stake::get_pool_total_staked<BTC, USDT, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_pool_total_earned_fails_if_pool_does_not_exist() {
        liq_stake::get_pool_total_earned<BTC, USDT, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_pool_total_paid_fails_if_pool_does_not_exist() {
        liq_stake::get_pool_total_paid<BTC, USDT, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_user_stake_fails_if_pool_does_not_exist() {
        let (_, alice_addr) = create_account(@0x10);

        liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_POOL_ALREADY_EXISTS */)]
    public fun test_initialize_fails_if_pool_already_exists() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        genesis::setup();

        // initialize staking pool twice
        let reward_per_sec_rate = 10 * SIX_DECIMALS; // 10 LIQ
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);
    }

    #[test]
    #[expected_failure(abort_code = 102 /* ERR_REWARD_CANNOT_BE_ZERO */)]
    public fun test_initialize_fails_if_reward_is_zero() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // initialize staking pool with zero reward
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, 0);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_unstake_fails_if_stake_not_exists() {
        let (staking_admin_acc, _) = create_account(@staking_admin);
        let (alice_acc, alice_addr) = create_account(@0x10);

        genesis::setup();

        // initialize staking pool
        let reward_per_sec_rate = 10 * SIX_DECIMALS; // 10 LIQ
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);

        // unstake from alice
        let coins =
            liq_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 40);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 104 /* ERR_NOT_ENOUGH_BALANCE */)]
    public fun test_unstake_fails_if_not_enough_balance() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // create lp coins
        let lp_coin = btc_usdt_pool_with_999_liqudity();

        // create alice with LP coins
        let (alice_acc, alice_addr) =
            create_account_with_lp_coins(@0x10, lp_coin);

        // initialize staking pool
        let reward_per_sec_rate = 10 * SIX_DECIMALS; // 10 LIQ
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc, reward_per_sec_rate);

        // stake from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 999 * SIX_DECIMALS);
        liq_stake::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 0, 1);
        assert!(liq_stake::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 999 * SIX_DECIMALS, 1);

        // unstake more than staked from alice
        let coins =
            liq_stake::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 1000 * SIX_DECIMALS);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 105 /* ERR_NO_PERMISSIONS */)]
    public fun test_initialize_fails_if_executed_not_by_admin() {
        let (alice_acc, _) = create_account(@0x10);

        // initialize staking pool
        let reward_per_sec_rate = 10 * SIX_DECIMALS; // 10 LIQ
        liq_stake::initialize<BTC, USDT, Uncorrelated>(&alice_acc, reward_per_sec_rate);
    }
}
