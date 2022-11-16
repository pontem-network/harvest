#[test_only]
module harvest::emergency_tests {

    use aptos_framework::coin;

    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_test_helpers::{new_account_with_stake_coins, RewardCoin, StakeCoin, new_account};
    use harvest::stake_tests::initialize_test;

    /// this is number of decimals in both StakeCoin and RewardCoin by default, named like that for readability
    const ONE_COIN: u64 = 1000000;

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_stake_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_unstake_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);

        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_harvest_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);

        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        coin::deposit(@alice, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_stake_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::enable_global_emergency(&emergency_admin);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_unstake_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::enable_global_emergency(&emergency_admin);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_harvest_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::enable_global_emergency(&emergency_admin);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        coin::deposit(@alice, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_enable_local_emergency_if_global_is_enabled() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::enable_global_emergency(&emergency_admin);

        let _ = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
    }

    #[test]
    #[expected_failure(abort_code = 112)]
    fun test_cannot_enable_emergency_with_non_admin_account() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&alice_acc, @harvest);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_enable_emergency_twice() {
        let (harvest, emergency_admin) = initialize_test();

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
    }

    #[test]
    fun test_unstake_everything_in_case_of_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);

        let coins = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        coin::deposit(@alice, coins);

        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@harvest, @alice), 3);
    }

    #[test]
    fun test_emergency_is_local_to_a_pool() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);
        stake::register_pool<RewardCoin, StakeCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<RewardCoin, StakeCoin>(&emergency_admin, @harvest);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 3);
    }

    #[test]
    #[expected_failure(abort_code = 204)]
    fun test_cannot_enable_global_emergency_twice() {
        let (harvest, emergency_admin) = initialize_test();

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake_config::enable_global_emergency(&emergency_admin);
        stake_config::enable_global_emergency(&emergency_admin);
    }

    #[test]
    fun test_unstake_everything_in_case_of_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);

        stake_config::enable_global_emergency(&emergency_admin);

        let coins = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        coin::deposit(@alice, coins);

        let exists = stake::stake_exists<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(!exists, 3);
    }

    #[test]
    #[expected_failure(abort_code = 201)]
    fun test_cannot_enable_global_emergency_with_non_admin_account() {
        let (_, _) = initialize_test();
        let alice = new_account(@alice);
        stake_config::enable_global_emergency(&alice);
    }

    #[test]
    #[expected_failure(abort_code = 201)]
    fun test_cannot_change_admin_with_non_admin_account() {
        let (_, _) = initialize_test();
        let alice = new_account(@alice);
        stake_config::set_emergency_admin_address(&alice, @alice);
    }

    #[test]
    fun test_enable_emergency_with_changed_admin_account() {
        let (_, emergency_admin) = initialize_test();
        stake_config::set_emergency_admin_address(&emergency_admin, @alice);

        let alice = new_account(@alice);
        stake::register_pool<StakeCoin, RewardCoin>(&alice, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&alice, @alice);

        assert!(stake::is_local_emergency<StakeCoin, RewardCoin>(@alice), 1);
        assert!(stake::is_emergency<StakeCoin, RewardCoin>(@alice), 2);
        assert!(!stake_config::is_global_emergency(), 3);
    }

    #[test]
    fun test_enable_global_emergency_with_changed_admin_account_no_pool() {
        let (_, emergency_admin) = initialize_test();
        stake_config::set_emergency_admin_address(&emergency_admin, @alice);

        let alice = new_account(@alice);
        stake_config::enable_global_emergency(&alice);

        assert!(stake_config::is_global_emergency(), 3);
    }

    #[test]
    fun test_enable_global_emergency_with_changed_admin_account_with_pool() {
        let (_, emergency_admin) = initialize_test();
        stake_config::set_emergency_admin_address(&emergency_admin, @alice);

        let alice = new_account(@alice);
        stake::register_pool<StakeCoin, RewardCoin>(&alice, 1 * ONE_COIN);
        stake_config::enable_global_emergency(&alice);

        assert!(!stake::is_local_emergency<StakeCoin, RewardCoin>(@alice), 1);
        assert!(stake::is_emergency<StakeCoin, RewardCoin>(@alice), 2);
        assert!(stake_config::is_global_emergency(), 3);
    }
}
