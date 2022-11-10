#[test_only]
module harvest::stake_decimals_tests {
    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use harvest::stake;
    use harvest::stake_test_helpers::{new_account, initialize_reward_coin, initialize_stake_coin, mint_coins, StakeCoin, RewardCoin, new_account_with_stake_coins};

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    #[test]
    public fun test_reward_calculation_decimals_s6_r10() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        initialize_stake_coin(&harvest_acc, 6);
        initialize_reward_coin(&harvest_acc, 10);

        // 30 StakeCoins
        let alice_acc = new_account_with_stake_coins(@alice, 30000000);

        coin::register<RewardCoin>(&alice_acc);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // reward rate 1 RewardCoin
        let reward_per_sec_rate = 10000000000;

        // register staking pool
        let reward_coins = mint_coins<RewardCoin>(10000000000000000);
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(@harvest, reward_coins);

        // stake 19.999999 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 19999999);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check pool parameters after first stake
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == start_time, 1);

        // check stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == 0, 1);
        assert!(earned_reward == 0, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);

        // check pool parameters after 10 seconds
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 0.505000000250 RewardCoins
        assert!(accum_reward == 5000000250, 1);
        assert!(last_updated == start_time + 10, 1);

        // check stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        // acc_reward * stake_amount
        // 9.99999999999 RewardCoins
        assert!(unobtainable_reward == 99999999999, 1);
        assert!(earned_reward == 99999999999, 1);

        // harvest from alice
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);

        // check stake amounts after harvest
        let (_, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(earned_reward == 0, 1);
        // 9.9999999999 RewardCoins
        assert!(coin::value(&coins) == 99999999999, 1);

        coin::deposit<RewardCoin>(@alice, coins);

        // stake 10 StakeCoins more from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 10000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check pool parameters after second stake
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 0.505000000250 RewardCoins
        assert!(accum_reward == 5000000250, 1);
        assert!(last_updated == start_time + 10, 1);

        // check stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        // acc_reward * stake_amount
        // 15.0000002499 RewardCoins
        assert!(unobtainable_reward == 150000002499, 1);
        // 0 after harvest
        assert!(earned_reward == 0, 1);

        // wait one week
        timestamp::update_global_time_for_test_secs(start_time + 10 + WEEK_IN_SECONDS);

        // unstake 20 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 20000000);
        coin::deposit<StakeCoin>(@alice, coins);

        // check pool parameters
        // note: accum_reward recalculated before total_stake was decreased by user unstake
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 20160.5006720250 RewardCoins
        assert!(accum_reward == 201605006720250, 1);
        assert!(last_updated == start_time + 10 + WEEK_IN_SECONDS, 1);

        // check stake parameters after partial unstake
        // note: earned_rewards recalculated before total_stake was decreased by user unstake
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        // acc_reward * stake_amount
        // 201604.9865597493 RewardCoins
        assert!(unobtainable_reward == 2016049865597493, 1);
        // (acc_reward * stake_amount) - previous_unobtainable_reward
        // 604799.9999999994 RewardCoins
        assert!(earned_reward == 6047999999999994, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 20 + WEEK_IN_SECONDS);

        // unstake rest 9.999999 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 9999999);
        coin::deposit<StakeCoin>(@alice, coins);

        // check pool parameters after full unstake
        // note: accum_reward recalculated before total_stake was decreased by user unstake
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 20161.5006721250 RewardCoins
        assert!(accum_reward == 201615006721250, 1);
        assert!(last_updated == start_time + 20 + WEEK_IN_SECONDS, 1);

        // check stake parameters
        // note: earned_rewards recalculated before total_stake was decreased by user unstake
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        // 0 after full unstake
        assert!(unobtainable_reward == 0, 1);
        // ((acc_reward * stake_amount) - previous_unobtainable_reward) + previous_earned_reward
        // 604809.9999999994 RewardCoins
        assert!(earned_reward == 6048099999999994, 1);

        // harvest from alice after unstake
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);

        // check stake amounts after harvest
        let (_, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 6048099999999994, 1);

        coin::deposit<RewardCoin>(@alice, coins);

        // check stake parameters after harvest
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        // 0 after full unstake
        assert!(unobtainable_reward == 0, 1);
        // 0 after harvest
        assert!(earned_reward == 0, 1);

        // check balances after full unstake
        let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest);
        // 30 StakeCoins
        assert!(coin::balance<StakeCoin>(@alice) == 30000000, 1);
        assert!(total_staked == 0, 1);

        // 0.0000000007 RewardCoin lost during calculations
        let total_rewards = (20 + WEEK_IN_SECONDS) * reward_per_sec_rate;
        let total_earned = coin::balance<RewardCoin>(@alice);
        let losed_rewards =  total_rewards - total_earned;

        assert!(losed_rewards == 7, 1);
    }
}
