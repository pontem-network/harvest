#[test_only]
module harvest::scripts_tests {
    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use harvest::scripts;
    use harvest::stake;
    use harvest::stake_test_helpers::{StakeCoin, RewardCoin, new_account, initialize_default_stake_reward_coins, new_account_with_stake_coins, mint_coins};
    use aptos_framework::genesis;

    const ONE_COIN: u64 = 1000000;

    const WEEK_IN_SECONDS: u64 = 604800;

    #[test]
    fun test_scripts_end_to_end() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let pool_address = @harvest;

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        scripts::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 10);

        let reward_coins = mint_coins<RewardCoin>(1000 * ONE_COIN);
        coin::register<RewardCoin>(&harvest_acc);
        coin::deposit(@harvest, reward_coins);

        scripts::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest_acc, @harvest, 1000 * ONE_COIN);

        let (reward_per_sec, accum_reward, last_updated, reward_coin_amount) =
            stake::get_pool_info<StakeCoin, RewardCoin>(pool_address);
        assert!(reward_per_sec == 10, 1);
        assert!(accum_reward == 0, 2);
        assert!(last_updated == 682981200, 3);
        assert!(reward_coin_amount == 1000 * ONE_COIN, 4);

        let alice_acc = new_account_with_stake_coins(@alice, 100 * ONE_COIN);

        // check empty balances
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(pool_address, @alice) == 0, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(pool_address, @bob) == 0, 1);

        scripts::stake<StakeCoin, RewardCoin>(&alice_acc, pool_address, 10 * ONE_COIN);

        assert!(coin::balance<StakeCoin>(@alice) == 90 * ONE_COIN, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(pool_address, @alice) == 10 * ONE_COIN, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(pool_address) == 10 * ONE_COIN, 1);

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(start_time + WEEK_IN_SECONDS);

        scripts::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 5 * ONE_COIN);

        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 5 * ONE_COIN, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest) == 5 * ONE_COIN, 1);

        coin::register<RewardCoin>(&alice_acc);

        scripts::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);

        assert!(coin::balance<RewardCoin>(@alice) == 6048000, 1);
    }
}
