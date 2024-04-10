#[test_only]
module harvest::whitelist_tests {
    use std::option;

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_test_helpers::{
        new_account,
        initialize_reward_coin,
        initialize_stake_coin,
        mint_default_coin,
        StakeCoin as S,
        RewardCoin as R,
        new_account_with_stake_coins
    };

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    const START_TIME: u64 = 682981200;

    public fun initialize_test(): (signer, signer) {
        genesis::setup();

        timestamp::update_global_time_for_test_secs(START_TIME);

        let harvest = new_account(@harvest);

        // create coins for pool to be valid
        initialize_reward_coin(&harvest, 6);
        initialize_stake_coin(&harvest, 6);

        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::initialize(&emergency_admin, @treasury);
        (harvest, emergency_admin)
    }

    #[test]
    public fun test_stake_with_whitelist_enabled() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 500000000);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[@alice]);

        // check no stakes
        assert!(!stake::stake_exists<S, R>(@harvest, @alice), 1);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<S>(&alice_acc, 500000000);
        stake::stake<S, R>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @alice) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 500000000, 1);

        // check stake
        assert!(stake::stake_exists<S, R>(@harvest, @alice), 1);
    }

    #[test]
    public fun test_stake_two_users_with_whitelist_enabled() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 500000000);
        let bob_acc = new_account_with_stake_coins(@bob, 500000000);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[@alice, @bob]);

        // check no stakes
        assert!(!stake::stake_exists<S, R>(@harvest, @alice), 1);
        assert!(!stake::stake_exists<S, R>(@harvest, @bob), 1);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(stake::is_whitelisted<S, R>(@harvest, @bob), 1);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<S>(&alice_acc, 500000000);
        stake::stake<S, R>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @alice) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 500000000, 1);

        // stake 500 StakeCoins from bob
        let coins =
            coin::withdraw<S>(&bob_acc, 500000000);
        stake::stake<S, R>(&bob_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @bob) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 1000000000, 1);

        // check stake
        assert!(stake::stake_exists<S, R>(@harvest, @alice), 1);
        assert!(stake::stake_exists<S, R>(@harvest, @bob), 1);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NOT_WHITELISTED)]
    public fun test_stake_from_not_whitelisted_user_should_fail() {
        let (harvest, _) = initialize_test();

        let bob_acc = new_account_with_stake_coins(@bob, 500000000);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[@alice]);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(!stake::is_whitelisted<S, R>(@harvest, @bob), 1);

        // stake 500 StakeCoins from bob
        let coins =
            coin::withdraw<S>(&bob_acc, 500000000);
        stake::stake<S, R>(&bob_acc, @harvest, coins);
    }

    #[test]
    public fun test_add_two_users_later_to_whitelist() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 500000000);
        let bob_acc = new_account_with_stake_coins(@bob, 500000000);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[@0x41, @0x42]);

        // check whitelist
        assert!(!stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(!stake::is_whitelisted<S, R>(@harvest, @bob), 1);

        stake::add_into_whitelist<S, R>(&harvest, vector[@alice, @bob]);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(stake::is_whitelisted<S, R>(@harvest, @bob), 1);

        // check no stakes
        assert!(!stake::stake_exists<S, R>(@harvest, @alice), 1);
        assert!(!stake::stake_exists<S, R>(@harvest, @bob), 1);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<S>(&alice_acc, 500000000);
        stake::stake<S, R>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @alice) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 500000000, 1);

        // stake 500 StakeCoins from bob
        let coins =
            coin::withdraw<S>(&bob_acc, 500000000);
        stake::stake<S, R>(&bob_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @bob) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 1000000000, 1);

        // check stake
        assert!(stake::stake_exists<S, R>(@harvest, @alice), 1);
        assert!(stake::stake_exists<S, R>(@harvest, @bob), 1);
    }

    #[test]
    public fun test_user_can_harvest_and_unstake_after_been_removed_from_whitelist() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 500000000);
        coin::register<R>(&alice_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[@alice, @bob]);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<S>(&alice_acc, 500000000);
        stake::stake<S, R>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @alice) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 500000000, 1);

        // remove alice from whitelist
        stake::remove_from_whitelist<S, R>(&harvest, @alice);

        // check whitelist
        assert!(!stake::is_whitelisted<S, R>(@harvest, @alice), 1);

        // wait one week with empty pool
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS);

        let coins = stake::unstake<S, R>(&alice_acc, @harvest, 500000000);
        assert!(coin::value(&coins) == 500000000, 1);
        coin::deposit(@alice, coins);

        let rewards = stake::harvest<S, R>(&alice_acc, @harvest);
        assert!(coin::value(&rewards) > 0, 1);
        coin::deposit(@alice, rewards);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NOT_WHITELISTED)]
    public fun test_stake_from_removed_from_whitelist_user_should_fail() {
        let (harvest, _) = initialize_test();

        let bob_acc = new_account_with_stake_coins(@bob, 500000000);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[@alice, @bob]);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(stake::is_whitelisted<S, R>(@harvest, @bob), 1);

        // remove from whilelist
        stake::remove_from_whitelist<S, R>(&harvest, @bob);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(!stake::is_whitelisted<S, R>(@harvest, @bob), 1);

        // stake 500 StakeCoins from bob
        let coins =
            coin::withdraw<S>(&bob_acc, 500000000);
        stake::stake<S, R>(&bob_acc, @harvest, coins);
    }

    #[test]
    public fun test_whitelist_are_deactivated_when_no_users_left() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 500000000);
        let bob_acc = new_account_with_stake_coins(@bob, 500000000);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[@bob]);

        // check whitelist
        assert!(!stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(stake::is_whitelisted<S, R>(@harvest, @bob), 1);
        assert!(!stake::is_whitelisted<S, R>(@harvest, @0x12345), 1);

        // remove bob, deactivate whitelist
        stake::remove_from_whitelist<S, R>(&harvest, @bob);

        // check whitelist
        assert!(stake::is_whitelisted<S, R>(@harvest, @alice), 1);
        assert!(stake::is_whitelisted<S, R>(@harvest, @bob), 1);
        assert!(stake::is_whitelisted<S, R>(@harvest, @0x12345), 1);

        // check no stakes
        assert!(!stake::stake_exists<S, R>(@harvest, @alice), 1);
        assert!(!stake::stake_exists<S, R>(@harvest, @bob), 1);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<S>(&alice_acc, 500000000);
        stake::stake<S, R>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @alice) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 500000000, 1);

        // stake 500 StakeCoins from bob
        let coins =
            coin::withdraw<S>(&bob_acc, 500000000);
        stake::stake<S, R>(&bob_acc, @harvest, coins);
        assert!(stake::get_user_stake<S, R>(@harvest, @bob) == 500000000, 1);
        assert!(stake::get_pool_total_stake<S, R>(@harvest) == 1000000000, 1);

        // check stake
        assert!(stake::stake_exists<S, R>(@harvest, @alice), 1);
        assert!(stake::stake_exists<S, R>(@harvest, @bob), 1);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_POOL)]
    public fun test_attempt_to_add_to_whitelist_when_no_pool_should_fail() {
        let (harvest, _) = initialize_test();
        stake::add_into_whitelist<S, R>(&harvest, vector[@alice]);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_POOL)]
    public fun test_attempt_to_remove_from_whitelist_when_no_pool_should_fail() {
        let (harvest, _) = initialize_test();
        stake::remove_from_whitelist<S, R>(&harvest, @alice);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_POOL)]
    public fun test_check_whitelist_when_no_pool_should_fail() {
        stake::is_whitelisted<S, R>(@harvest, @alice);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_POOL)]
    public fun test_attempt_to_add_to_whitelist_using_non_pool_owner_acc_should_fail() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account(@alice);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        stake::add_into_whitelist<S, R>(&alice_acc, vector[@alice]);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_POOL)]
    public fun test_attempt_to_remove_from_whitelist_using_non_pool_owner_acc_should_fail() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account(@alice);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(15768000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        stake::remove_from_whitelist<S, R>(&alice_acc, @alice);
    }
}