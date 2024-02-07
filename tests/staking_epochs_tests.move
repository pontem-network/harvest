#[test_only]
module harvest::staking_epochs_tests_move {
    use std::option;

    use aptos_framework::coin;
    use aptos_framework::stake::withdraw;
    use aptos_framework::timestamp;

    use harvest::stake;
    use harvest::stake_test_helpers::{amount, mint_default_coin, StakeCoin as S, RewardCoin as R, new_account_with_stake_coins};
    use harvest::stake_tests::initialize_test;

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    const START_TIME: u64 = 682981200;

    fun print_epoch(epoch: u64) {
        let (rewards_amount, reward_per_sec, accum_reward, start_time, last_update_time, end_time, distributed, ended_at, is_ghost)
            = stake::get_epoch_info<S, R>(@harvest, epoch);
        std::debug::print(&aptos_std::string_utils::format1(&b"Epoch INFO: {}", epoch));
        std::debug::print(&aptos_std::string_utils::format1(&b"rewards_amount = {}", rewards_amount));
        std::debug::print(&aptos_std::string_utils::format1(&b"reward_per_sec = {}", reward_per_sec));
        std::debug::print(&aptos_std::string_utils::format1(&b"accum_reward = {}", accum_reward));
        std::debug::print(&aptos_std::string_utils::format1(&b"start_time = {}", start_time));
        std::debug::print(&aptos_std::string_utils::format1(&b"last_update_time = {}", last_update_time));
        std::debug::print(&aptos_std::string_utils::format1(&b"end_time = {}", end_time));
        std::debug::print(&aptos_std::string_utils::format1(&b"distributed = {}", distributed));
        std::debug::print(&aptos_std::string_utils::format1(&b"ended_at = {}", ended_at));
        std::debug::print(&aptos_std::string_utils::format1(&b"is_ghost = {}\n", is_ghost));
    }
    fun print_line() {
        std::debug::print(&std::string::utf8(b"============================================================================"));
    }

    /// epoch duration      | #1 10   |
    /// epoch reward        |    10   |
    #[test]
    public fun test_creaate_different_epochs() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        coin::register<R>(&alice_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(amount<R>(0, 1000));
        let duration = 10;
        stake::register_pool<S, R>(&harvest, reward_coins, duration, option::none());

        // stake 100 from alice
        stake::stake<S, R>(&alice_acc, @harvest, coin::withdraw<S>(&alice_acc, amount<S>(100, 0)));

        print_epoch(0);
        print_line();

        // wait 5 sec
        timestamp::update_global_time_for_test_secs(START_TIME + 5);

        // create new epoch, take some rewards from previous
        let reward_coins = mint_default_coin<R>(amount<R>(0, 10));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 10);

        print_epoch(0);
        print_epoch(1);
        print_line();

        // wait 10 sec
        timestamp::update_global_time_for_test_secs(START_TIME + 5 + 10);

        // create new epoch, take some rewards from previous
        let reward_coins = mint_default_coin<R>(amount<R>(0, 10));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 10);

        print_epoch(0);
        print_epoch(1);
        print_epoch(2);
        print_line();

        // wait 3610 sec
        timestamp::update_global_time_for_test_secs(START_TIME + 5 + 10 + 3610);

        // create new epoch, take some rewards from previous
        let reward_coins = mint_default_coin<R>(amount<R>(0, 10));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 10);

        print_epoch(0);
        print_epoch(1);
        print_epoch(2);
        print_epoch(3);
        print_epoch(4);
        print_line();

        // wait 10 sec
        timestamp::update_global_time_for_test_secs(START_TIME + 5 + 10 + 3610 + 10);

        let rewards = stake::harvest<S, R>(&alice_acc, @harvest);
        std::debug::print(&aptos_std::string_utils::format1(&b"coin::value(&rewards) = {}", coin::value(&rewards)));
        // assert!(coin::value(&rewards) == amount<R>(0, 1030), 1);
        coin::deposit(@alice, rewards);

        // // stake 100 StakeCoins from alice
        // let coins =
        //     coin::withdraw<S>(&alice_acc, amount<S>(100, 0));
        // stake::stake<S, R>(&alice_acc, @harvest, coins);

        // // check stake earned and pool accum_reward
        // let (_, accum_reward, _, _, _) =
        //     stake::get_pool_info<S, R>(@harvest);
        // assert!(accum_reward == 0, 1);
        // assert!(stake::get_pending_user_rewards<S, R>(@harvest, @alice) == 0, 1);
        //
        // // wait one week
        // timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS);
        //
        // // check stake earned
        // assert!(stake::get_pending_user_rewards<S, R>(@harvest, @alice) == amount<R>(604800, 0), 1);
        //
        // // check get_pending_user_rewards calculations didn't affect pool accum_reward
        // let (_, accum_reward, _, _, _) =
        //     stake::get_pool_info<S, R>(@harvest);
        // assert!(accum_reward == 0, 1);
        //
        // // unstake all 100 StakeCoins from alice
        // let coins =
        //     stake::unstake<S, R>(&alice_acc, @harvest, amount<S>(100, 0));
        // coin::deposit(@alice, coins);
        //
        // // wait one week
        // timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS + WEEK_IN_SECONDS);
        //
        // // check stake earned didn't change a week after full unstake
        // assert!(stake::get_pending_user_rewards<S, R>(@harvest, @alice) == amount<R>(604800, 0), 1);
        //
        // // harvest from alice
        // let coins =
        //     stake::harvest<S, R>(&alice_acc, @harvest);
        // assert!(coin::value(&coins) == amount<R>(604800, 0), 1);
        // coin::deposit<R>(@alice, coins);
        //
        // // check earned calculations after harvest
        // assert!(stake::get_pending_user_rewards<S, R>(@harvest, @alice) == 0, 1);
    }

    #[test]
    public fun test_reward_is_not_accumulating_in_ghost_epoch() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 100000000);
        coin::register<R>(&alice_acc);

        // create pool
        let reward_coins = mint_default_coin<R>(157680000000000);
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins, duration, option::none());

        // stake some coins
        let coins =
            coin::withdraw<S>(&alice_acc, 100000000);
        stake::stake<S, R>(&alice_acc, @harvest, coins);

        // check accum reward
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let (_, accum_reward, last_updated, _, _) = stake::get_pool_info<S, R>(@harvest);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == 0, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME, 1);

        print_epoch(0);

        // wait half of duration & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration / 2);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let (_, accum_reward, last_updated, _, _) = stake::get_pool_info<S, R>(@harvest);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == 78840000000000, 1);
        assert!(accum_reward == 788400000000000000, 1);
        assert!(last_updated == START_TIME + duration / 2, 1);

        // wait full duration & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let (_, accum_reward, last_updated, _, _) = stake::get_pool_info<S, R>(@harvest);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == 157680000000000, 1);
        assert!(accum_reward == 1576800000000000000, 1);
        assert!(last_updated == START_TIME + duration, 1);

        // wait full duration + 1 sec & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration + 1);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let (_, accum_reward, last_updated, _, _) = stake::get_pool_info<S, R>(@harvest);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == 157680000000000, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME + duration + 1, 1);

        // wait full duration + 200 weeks & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration + WEEK_IN_SECONDS * 200);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let (_, accum_reward, last_updated, _, _) = stake::get_pool_info<S, R>(@harvest);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == 157680000000000, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME + duration + WEEK_IN_SECONDS * 200, 1);
    }
}
