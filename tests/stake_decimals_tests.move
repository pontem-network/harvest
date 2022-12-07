#[test_only]
module harvest::stake_decimals_tests {
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
        StakeCoin,
        RewardCoin,
        new_account_with_stake_coins
    };
    use std::option;

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    const START_TIME: u64 = 682981200;

    #[test]
    public fun test_reward_calculation_decimals_s0_r0() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        initialize_stake_coin(&harvest_acc, 0);
        initialize_reward_coin(&harvest_acc, 0);

        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::initialize(&emergency_admin, @treasury);

        // 30 StakeCoins
        let alice_acc = new_account_with_stake_coins(@alice, 30);

        coin::register<RewardCoin>(&alice_acc);

        timestamp::update_global_time_for_test_secs(START_TIME);

        // register staking pool with 10 000 000 RewardCoins
        let reward_coins = mint_default_coin<RewardCoin>(10000000);
        let duration = 2000000;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest_acc,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        // stake 19 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 19);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        // check pool parameters after first stake
        let (reward_per_sec, accum_reward, last_updated, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@pool_storage);
        // pool_rewards_amount / duration
        // 5 RewardCoins
        assert!(reward_per_sec == 5, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME, 1);

        // check stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        assert!(unobtainable_reward == 0, 1);
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 0, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + 10);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@pool_storage, @alice);

        // check pool parameters after 10 seconds
        let (_, accum_reward, last_updated, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@pool_storage);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 2.631578947368 RewardCoins
        assert!(accum_reward == 2631578947368, 1);
        assert!(last_updated == START_TIME + 10, 1);

        // check stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        // acc_reward * stake_amount
        // 49 RewardCoins
        assert!(unobtainable_reward == 49, 1);
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 49, 1);

        // harvest from alice
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);

        // check stake amounts after harvest
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 0, 1);
        // 49 RewardCoins
        assert!(coin::value(&coins) == 49, 1);

        coin::deposit<RewardCoin>(@alice, coins);

        // stake 10 StakeCoins more from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 10);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        // check stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        // acc_reward * stake_amount
        // 76 RewardCoins
        assert!(unobtainable_reward == 76, 1);
        // 0 after harvest
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 0, 1);

        // wait one week
        timestamp::update_global_time_for_test_secs(START_TIME + 10 + WEEK_IN_SECONDS);

        // unstake 20 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, 20);
        coin::deposit<StakeCoin>(@alice, coins);

        // check pool parameters
        // note: accum_reward recalculated before total_stake was decreased by user unstake
        let (_, accum_reward, last_updated, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@pool_storage);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 104278.493647912885 RewardCoins
        assert!(accum_reward == 104278493647912885, 1);
        assert!(last_updated == START_TIME + 10 + WEEK_IN_SECONDS, 1);

        // check stake parameters after partial unstake
        // note: earned_rewards recalculated before stake_amount was decreased by user unstake
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        // acc_reward * stake_amount
        // 938506 RewardCoins
        assert!(unobtainable_reward == 938506, 1);
        // (acc_reward * stake_amount) - previous_unobtainable_reward
        // 3024000 RewardCoins
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 3024000, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + 20 + WEEK_IN_SECONDS);

        // unstake rest 9 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, 9);
        coin::deposit<StakeCoin>(@alice, coins);

        // check pool parameters after full unstake
        // note: accum_reward recalculated before total_stake was decreased by user unstake
        let (_, accum_reward, last_updated, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@pool_storage);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 104284.049203468440 RewardCoins
        assert!(accum_reward == 104284049203468440, 1);
        assert!(last_updated == START_TIME + 20 + WEEK_IN_SECONDS, 1);

        // check stake parameters
        // note: earned_rewards recalculated before stake_amount was decreased by user unstake
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        // 0 after full unstake
        assert!(unobtainable_reward == 0, 1);
        // ((acc_reward * stake_amount) - previous_unobtainable_reward) + previous_earned_reward
        // 3024050 RewardCoins
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 3024050, 1);

        // harvest from alice after unstake
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);

        // check stake amounts after harvest
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 0, 1);
        assert!(coin::value(&coins) == 3024050, 1);

        coin::deposit<RewardCoin>(@alice, coins);

        // check stake parameters after harvest
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        // 0 after full unstake
        assert!(unobtainable_reward == 0, 1);
        // 0 after harvest
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 0, 1);

        // check balances after full unstake
        let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@pool_storage);
        // 30 StakeCoins
        assert!(coin::balance<StakeCoin>(@alice) == 30, 1);
        assert!(total_staked == 0, 1);

        // 1 RewardCoin lost during calculations
        let total_rewards = (20 + WEEK_IN_SECONDS) * reward_per_sec;
        let total_earned = coin::balance<RewardCoin>(@alice);
        let losed_rewards =  total_rewards - total_earned;
        assert!(losed_rewards == 1, 1);
    }
//
//     #[test]
//     public fun test_reward_calculation_decimals_s2_r8() {
//         genesis::setup();
//
//         let harvest_acc = new_account(@harvest);
//
//         initialize_stake_coin(&harvest_acc, 2);
//         initialize_reward_coin(&harvest_acc, 8);
//
//         let emergency_admin = new_account(@stake_emergency_admin);
//         stake_config::initialize(&emergency_admin, @treasury);
//
//         // 30 StakeCoins
//         let alice_acc = new_account_with_stake_coins(@alice, 3000);
//
//         coin::register<RewardCoin>(&alice_acc);
//
//         timestamp::update_global_time_for_test_secs(START_TIME);
//
//         // register staking pool, deposit 10 000 000 RewardCoins
//         let reward_coins = mint_default_coin<RewardCoin>(1000000000000000);
//         let duration = 5000000;
//         stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_coins, duration, option::none());
//
//         // stake 19.99 StakeCoins from alice
//         let coins =
//             coin::withdraw<StakeCoin>(&alice_acc, 1999);
//         stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//         // check pool parameters after first stake
//         let (reward_per_sec, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // pool_rewards_amount / duration
//         // 2 RewardCoins
//         assert!(reward_per_sec == 200000000, 1);
//         assert!(accum_reward == 0, 1);
//         assert!(last_updated == START_TIME, 1);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         assert!(unobtainable_reward == 0, 1);
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // wait 10 seconds
//         timestamp::update_global_time_for_test_secs(START_TIME + 10);
//
//         // synthetic recalculate
//         stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);
//
//         // check pool parameters after 10 seconds
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 1.00050025 RewardCoins
//         assert!(accum_reward == 100050025, 1);
//         assert!(last_updated == START_TIME + 10, 1);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 19.99999999 RewardCoins
//         assert!(unobtainable_reward == 1999999999, 1);
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 1999999999, 1);
//
//         // harvest from alice
//         let coins =
//             stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//
//         // check stake amounts after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//         // 19.9999999999 RewardCoins
//         assert!(coin::value(&coins) == 1999999999, 1);
//
//         coin::deposit<RewardCoin>(@alice, coins);
//
//         // stake 10 StakeCoins more from alice
//         let coins =
//             coin::withdraw<StakeCoin>(&alice_acc, 1000);
//         stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 30,00500249 RewardCoins
//         assert!(unobtainable_reward == 3000500249, 1);
//         // 0 after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // wait one week
//         timestamp::update_global_time_for_test_secs(START_TIME + 10 + WEEK_IN_SECONDS);
//
//         // unstake 20 StakeCoins from alice
//         let coins =
//             stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 2000);
//         coin::deposit<StakeCoin>(@alice, coins);
//
//         // check pool parameters
//         // note: accum_reward recalculated before total_stake was decreased by user unstake
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 40334.44498174 RewardCoins
//         assert!(accum_reward == 4033444498174, 1);
//         assert!(last_updated == START_TIME + 10 + WEEK_IN_SECONDS, 1);
//
//         // check stake parameters after partial unstake
//         // note: earned_rewards recalculated before stake_amount was decreased by user unstake
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 402941.10536758 RewardCoins
//         assert!(unobtainable_reward == 40294110536758, 1);
//         // (acc_reward * stake_amount) - previous_unobtainable_reward
//         // 1209599.99999989 RewardCoins
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 120959999999989, 1);
//
//         // wait 10 seconds
//         timestamp::update_global_time_for_test_secs(START_TIME + 20 + WEEK_IN_SECONDS);
//
//         // unstake rest 9.99 StakeCoins from alice
//         let coins =
//             stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 999);
//         coin::deposit<StakeCoin>(@alice, coins);
//
//         // check pool parameters after full unstake
//         // note: accum_reward recalculated before total_stake was decreased by user unstake
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 40336.44698374 RewardCoins
//         assert!(accum_reward == 4033644698374, 1);
//         assert!(last_updated == START_TIME + 20 + WEEK_IN_SECONDS, 1);
//
//         // check stake parameters
//         // note: earned_rewards recalculated before stake_amount was decreased by user unstake
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // 0 after full unstake
//         assert!(unobtainable_reward == 0, 1);
//         // ((acc_reward * stake_amount) - previous_unobtainable_reward) + previous_earned_reward
//         // 1209619.99999987 RewardCoins
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 120961999999987, 1);
//
//         // harvest from alice after unstake
//         let coins =
//             stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//
//         // check stake amounts after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//         assert!(coin::value(&coins) == 120961999999987, 1);
//
//         coin::deposit<RewardCoin>(@alice, coins);
//
//         // check stake parameters after harvest
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // 0 after full unstake
//         assert!(unobtainable_reward == 0, 1);
//         // 0 after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // check balances after full unstake
//         let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest);
//         // 30 StakeCoins
//         assert!(coin::balance<StakeCoin>(@alice) == 3000, 1);
//         assert!(total_staked == 0, 1);
//
//         // 0.00000014 RewardCoin lost during calculations
//         let total_rewards = (20 + WEEK_IN_SECONDS) * reward_per_sec;
//         let total_earned = coin::balance<RewardCoin>(@alice);
//         let losed_rewards =  total_rewards - total_earned;
//         assert!(losed_rewards == 14, 1);
//     }
//
//     #[test]
//     public fun test_reward_calculation_decimals_s6_r10() {
//         genesis::setup();
//
//         let harvest_acc = new_account(@harvest);
//
//         initialize_stake_coin(&harvest_acc, 6);
//         initialize_reward_coin(&harvest_acc, 10);
//
//         let emergency_admin = new_account(@stake_emergency_admin);
//         stake_config::initialize(&emergency_admin, @treasury);
//
//         // 30 StakeCoins
//         let alice_acc = new_account_with_stake_coins(@alice, 30000000);
//
//         coin::register<RewardCoin>(&alice_acc);
//
//         timestamp::update_global_time_for_test_secs(START_TIME);
//
//         // register staking pool, deposit 1 000 000 RewardCoins
//         let reward_coins = mint_default_coin<RewardCoin>(10000000000000000);
//         let duration = 1000000;
//         stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_coins, duration, option::none());
//
//         // stake 19.999999 StakeCoins from alice
//         let coins =
//             coin::withdraw<StakeCoin>(&alice_acc, 19999999);
//         stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//         // check pool parameters after first stake
//         let (reward_per_sec, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // pool_rewards_amount / duration
//         // 1 RewardCoin
//         assert!(reward_per_sec == 10000000000, 1);
//         assert!(accum_reward == 0, 1);
//         assert!(last_updated == START_TIME, 1);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         assert!(unobtainable_reward == 0, 1);
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // wait 10 seconds
//         timestamp::update_global_time_for_test_secs(START_TIME + 10);
//
//         // synthetic recalculate
//         stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);
//
//         // check pool parameters after 10 seconds
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 0.5000000250 RewardCoins
//         assert!(accum_reward == 5000000250, 1);
//         assert!(last_updated == START_TIME + 10, 1);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 9.99999999999 RewardCoins
//         assert!(unobtainable_reward == 99999999999, 1);
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 99999999999, 1);
//
//         // harvest from alice
//         let coins =
//             stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//
//         // check stake amounts after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//         // 9.9999999999 RewardCoins
//         assert!(coin::value(&coins) == 99999999999, 1);
//
//         coin::deposit<RewardCoin>(@alice, coins);
//
//         // stake 10 StakeCoins more from alice
//         let coins =
//             coin::withdraw<StakeCoin>(&alice_acc, 10000000);
//         stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 15.0000002499 RewardCoins
//         assert!(unobtainable_reward == 150000002499, 1);
//         // 0 after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // wait one week
//         timestamp::update_global_time_for_test_secs(START_TIME + 10 + WEEK_IN_SECONDS);
//
//         // unstake 20 StakeCoins from alice
//         let coins =
//             stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 20000000);
//         coin::deposit<StakeCoin>(@alice, coins);
//
//         // check pool parameters
//         // note: accum_reward recalculated before total_stake was decreased by user unstake
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 20160.5006720250 RewardCoins
//         assert!(accum_reward == 201605006720250, 1);
//         assert!(last_updated == START_TIME + 10 + WEEK_IN_SECONDS, 1);
//
//         // check stake parameters after partial unstake
//         // note: earned_rewards recalculated before stake_amount was decreased by user unstake
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 201604.9865597493 RewardCoins
//         assert!(unobtainable_reward == 2016049865597493, 1);
//         // (acc_reward * stake_amount) - previous_unobtainable_reward
//         // 604799.9999999994 RewardCoins
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 6047999999999994, 1);
//
//         // wait 10 seconds
//         timestamp::update_global_time_for_test_secs(START_TIME + 20 + WEEK_IN_SECONDS);
//
//         // unstake rest 9.999999 StakeCoins from alice
//         let coins =
//             stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 9999999);
//         coin::deposit<StakeCoin>(@alice, coins);
//
//         // check pool parameters after full unstake
//         // note: accum_reward recalculated before total_stake was decreased by user unstake
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 20161.5006721250 RewardCoins
//         assert!(accum_reward == 201615006721250, 1);
//         assert!(last_updated == START_TIME + 20 + WEEK_IN_SECONDS, 1);
//
//         // check stake parameters
//         // note: earned_rewards recalculated before stake_amount was decreased by user unstake
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // 0 after full unstake
//         assert!(unobtainable_reward == 0, 1);
//         // ((acc_reward * stake_amount) - previous_unobtainable_reward) + previous_earned_reward
//         // 604809.9999999994 RewardCoins
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 6048099999999994, 1);
//
//         // harvest from alice after unstake
//         let coins =
//             stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//
//         // check stake amounts after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//         assert!(coin::value(&coins) == 6048099999999994, 1);
//         coin::deposit<RewardCoin>(@alice, coins);
//
//         // check stake parameters after harvest
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // 0 after full unstake
//         assert!(unobtainable_reward == 0, 1);
//         // 0 after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // check balances after full unstake
//         let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest);
//         // 30 StakeCoins
//         assert!(coin::balance<StakeCoin>(@alice) == 30000000, 1);
//         assert!(total_staked == 0, 1);
//
//         // 0.0000000007 RewardCoin lost during calculations
//         let total_rewards = (20 + WEEK_IN_SECONDS) * reward_per_sec;
//         let total_earned = coin::balance<RewardCoin>(@alice);
//         let losed_rewards =  total_rewards - total_earned;
//         assert!(losed_rewards == 7, 1);
//     }
//
//     #[test]
//     public fun test_reward_calculation_decimals_s8_r2() {
//         genesis::setup();
//
//         let harvest_acc = new_account(@harvest);
//
//         initialize_stake_coin(&harvest_acc, 8);
//         initialize_reward_coin(&harvest_acc, 2);
//
//         let emergency_admin = new_account(@stake_emergency_admin);
//         stake_config::initialize(&emergency_admin, @treasury);
//
//         // 30 StakeCoins
//         let alice_acc = new_account_with_stake_coins(@alice, 3000000000);
//
//         coin::register<RewardCoin>(&alice_acc);
//
//         timestamp::update_global_time_for_test_secs(START_TIME);
//
//         // register staking pool, deposit 10 000 004 RewardCoins
//         let reward_coins = mint_default_coin<RewardCoin>(1000000400);
//         let duration = 2857144;
//         stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_coins, duration, option::none());
//
//         // stake 19.99999999 StakeCoins from alice
//         let coins =
//             coin::withdraw<StakeCoin>(&alice_acc, 1999999999);
//         stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//         // check pool parameters after first stake
//         let (reward_per_sec, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // pool_rewards_amount / duration
//         // 3.5 RewardCoins
//         assert!(reward_per_sec == 350, 1);
//         assert!(accum_reward == 0, 1);
//         assert!(last_updated == START_TIME, 1);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         assert!(unobtainable_reward == 0, 1);
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // wait 10 seconds
//         timestamp::update_global_time_for_test_secs(START_TIME + 10);
//
//         // synthetic recalculate
//         stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);
//
//         // check pool parameters after 10 seconds
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 1.75 RewardCoins
//         assert!(accum_reward == 175, 1);
//         assert!(last_updated == START_TIME + 10, 1);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 34.99 RewardCoins
//         assert!(unobtainable_reward == 3499, 1);
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 3499, 1);
//
//         // harvest from alice
//         let coins =
//             stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//
//         // check stake amounts after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//         // 34.99 RewardCoins
//         assert!(coin::value(&coins) == 3499, 1);
//
//         coin::deposit<RewardCoin>(@alice, coins);
//
//         // stake 10 StakeCoins more from alice
//         let coins =
//             coin::withdraw<StakeCoin>(&alice_acc, 1000000000);
//         stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//         // check stake parameters
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 52.49 RewardCoins
//         assert!(unobtainable_reward == 5249, 1);
//         // 0 after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // wait one week
//         timestamp::update_global_time_for_test_secs(START_TIME + 10 + WEEK_IN_SECONDS);
//
//         // unstake 20 StakeCoins from alice
//         let coins =
//             stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 2000000000);
//         coin::deposit<StakeCoin>(@alice, coins);
//
//         // check pool parameters
//         // note: accum_reward recalculated before total_stake was decreased by user unstake
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 70561.75 RewardCoins
//         assert!(accum_reward == 7056175, 1);
//         assert!(last_updated == START_TIME + 10 + WEEK_IN_SECONDS, 1);
//
//         // check stake parameters after partial unstake
//         // note: earned_rewards recalculated before stake_amount was decreased by user unstake
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // acc_reward * stake_amount
//         // 705617,49 RewardCoins
//         assert!(unobtainable_reward == 70561749, 1);
//         // (acc_reward * stake_amount) - previous_unobtainable_reward
//         // 2116800.00 RewardCoins
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 211680000, 1);
//
//         // wait 10 seconds
//         timestamp::update_global_time_for_test_secs(START_TIME + 20 + WEEK_IN_SECONDS);
//
//         // unstake rest 9.99999999 StakeCoins from alice
//         let coins =
//             stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 999999999);
//         coin::deposit<StakeCoin>(@alice, coins);
//
//         // check pool parameters after full unstake
//         // note: accum_reward recalculated before total_stake was decreased by user unstake
//         let (_, accum_reward, last_updated, _, _) =
//             stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
//         // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
//         // 70565.25 RewardCoins
//         assert!(accum_reward == 7056525, 1);
//         assert!(last_updated == START_TIME + 20 + WEEK_IN_SECONDS, 1);
//
//         // check stake parameters
//         // note: earned_rewards recalculated before stake_amount was decreased by user unstake
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // 0 after full unstake
//         assert!(unobtainable_reward == 0, 1);
//         // ((acc_reward * stake_amount) - previous_unobtainable_reward) + previous_earned_reward
//         // 2116835.00 RewardCoins
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 211683500, 1);
//
//         // harvest from alice after unstake
//         let coins =
//             stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//
//         // check stake amounts after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//         assert!(coin::value(&coins) == 211683500, 1);
//
//         coin::deposit<RewardCoin>(@alice, coins);
//
//         // check stake parameters after harvest
//         let (unobtainable_reward, _) =
//             stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
//         // 0 after full unstake
//         assert!(unobtainable_reward == 0, 1);
//         // 0 after harvest
//         assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
//
//         // check balances after full unstake
//         let total_staked = stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest);
//         // 30 StakeCoins
//         assert!(coin::balance<StakeCoin>(@alice) == 3000000000, 1);
//         assert!(total_staked == 0, 1);
//
//         // 0.01 RewardCoin lost during calculations
//         let total_rewards = (20 + WEEK_IN_SECONDS) * reward_per_sec;
//         let total_earned = coin::balance<RewardCoin>(@alice);
//         let losed_rewards =  total_rewards - total_earned;
//         assert!(losed_rewards == 1, 1);
//     }

    #[test]
    public fun test_reward_calculation_case_1() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        initialize_stake_coin(&harvest_acc, 8);
        initialize_reward_coin(&harvest_acc, 0);

        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::initialize(&emergency_admin, @treasury);

        // 20 StakeCoins
        let alice_acc = new_account_with_stake_coins(@alice, 2000000000);

        // 30 StakeCoins
        let bob_acc = new_account_with_stake_coins(@bob, 3000000000);

        // 10 StakeCoins
        let carol_acc = new_account_with_stake_coins(@0x1234, 1000000000);

        coin::register<RewardCoin>(&alice_acc);
        coin::register<RewardCoin>(&bob_acc);

        timestamp::update_global_time_for_test_secs(START_TIME);

        // register staking pool with 100 RewardCoins
        let reward_coins = mint_default_coin<RewardCoin>(100);
        let duration = 100;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest_acc,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        // wait 15 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + 15);

        // stake 20 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 2000000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        // check pool parameters after first stake
        let (reward_per_sec, accum_reward, last_updated, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@pool_storage);
        // pool_rewards_amount / duration
        // 1 RewardCoins
        assert!(reward_per_sec == 1, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME + 15, 1);

        // check alice stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        assert!(unobtainable_reward == 0, 1);
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 0, 1);

        // wait 15 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + 30);

        // stake 30 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 3000000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @pool_storage, coins);

        // check pool parameters after new stake and 15 seconds
        let (_, accum_reward, last_updated, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@pool_storage);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 0.75 RewardCoins
        assert!(accum_reward == 750000000000, 1);
        assert!(last_updated == START_TIME + 30, 1);

        // check alice stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        assert!(unobtainable_reward == 0, 1);
        // acc_reward * stake_amount
        // 15 RewardCoins
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 15, 1);

        // check bob stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @bob);
        // acc_reward * stake_amount
        // todo: manual unobtainable_reward calculation result is 22.5, check twice that next reward calculation will be fair
        // 22 RewardCoins
        assert!(unobtainable_reward == 22, 1);
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @bob) == 0, 1);

        // wait 25 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + 55);

        // stake 10 StakeCoins from carol
        let coins =
            coin::withdraw<StakeCoin>(&carol_acc, 1000000000);
        stake::stake<StakeCoin, RewardCoin>(&carol_acc, @pool_storage, coins);

        // check pool parameters after new stake and 25 seconds
        let (_, accum_reward, last_updated, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@pool_storage);
        // (reward_per_sec_rate * time passed / total_staked) + accum_reward(previous)
        // 1.25 RewardCoins
        assert!(accum_reward == 1250000000000, 1);
        assert!(last_updated == START_TIME + 55, 1);

        // check alice stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @alice);
        assert!(unobtainable_reward == 0, 1);
        // acc_reward * stake_amount
        // 25 RewardCoins
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 25, 1);

        // check bob stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @bob);
        // acc_reward * stake_amount
        // 22 RewardCoins
        assert!(unobtainable_reward == 22, 1);
        // (acc_reward * stake_amount) - unobtainable_reward
        // todo: 15.5 manual result. maybe add some another test for this
        // 15 RewardCoins
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @bob) == 15, 1);

        // check carol stake parameters
        let (unobtainable_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@pool_storage, @0x1234);
        // acc_reward * stake_amount
        // 12 RewardCoins
        assert!(unobtainable_reward == 12, 1);
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @0x1234) == 0, 1);

        // harvest from alice
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);

        // check stake amounts after harvest
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @alice) == 0, 1);
        assert!(coin::value(&coins) == 25, 1);

        coin::deposit<RewardCoin>(@alice, coins);

        // harvest from bob
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&bob_acc, @pool_storage);

        // check stake amounts after harvest
        assert!(stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@pool_storage, @bob) == 0, 1);
        assert!(coin::value(&coins) == 15, 1);

        coin::deposit<RewardCoin>(@bob, coins);
    }
}
