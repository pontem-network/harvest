#[test_only]
module harvest::emergency_tests {

    use aptos_framework::coin;

    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_test_helpers::{new_account_with_stake_coins, RewardCoin, StakeCoin};
    use harvest::stake_tests::initialize_test;

    /// this is number of decimals in both StakeCoin and RewardCoin by default, named like that for readability
    const ONE_COIN: u64 = 1000000;

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_stake_with_emergency() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_unstake_with_emergency() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);

        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_harvest_with_emergency() {
        let (harvest, _) = initialize_test();

        let _ = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);

        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);
        coin::deposit(@alice, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_stake_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::enable_global_emergency_lock(&emergency_admin);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_unstake_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::enable_global_emergency_lock(&emergency_admin);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);

        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_harvest_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::enable_global_emergency_lock(&emergency_admin);

        let _ = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);

        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);
        coin::deposit(@alice, reward_coins);
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
        let (harvest, _) = initialize_test();

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);
        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);
    }

    #[test]
    fun test_unstake_everything_in_case_of_emergency() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest, @harvest);

        let coins = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        coin::deposit(@alice, coins);

        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 3);
    }

    #[test]
    fun test_emergency_is_local_to_a_pool() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1 * ONE_COIN);
        stake::register_pool<RewardCoin, StakeCoin>(&harvest, 1 * ONE_COIN);

        stake::enable_emergency<RewardCoin, StakeCoin>(&harvest, @harvest);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 3);
    }
}
