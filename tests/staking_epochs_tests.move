#[test_only]
module harvest::staking_epochs_tests_move {
    use std::option;

    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use harvest::stake;
    use harvest::stake_test_helpers::{amount, mint_default_coin, StakeCoin as S, RewardCoin as R, new_account_with_stake_coins};
    use harvest::stake_tests::initialize_test;

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    const START_TIME: u64 = 682981200;

    // Deposit reward on different epoch stages test

    #[test]
    public fun test_deposit_twice_same_sec() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        coin::register<R>(&alice_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        let duration = 500;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        // check 0 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(rewards_amount == amount<R>(1000, 0), 1);
        assert!(reward_per_sec == amount<R>(2, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME, 1);
        assert!(last_update_time == START_TIME, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // stake 100 from alice
        stake::stake<S, R>(&alice_acc, @harvest, coin::withdraw<S>(&alice_acc, amount<S>(100, 0)));

        // create new epoch, take some rewards from previous
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 500);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        assert!(curr_epoch == 1, 0);

        // check 0 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(accum_reward == 0, 1);
        assert!(last_update_time == START_TIME, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == START_TIME, 1);

        // check 1 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 1);
        // 1000 new + 1000 from prev epoch
        assert!(rewards_amount == amount<R>(2000, 0), 1);
        assert!(reward_per_sec == amount<R>(4, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME, 1);
        assert!(last_update_time == START_TIME, 1);
        assert!(end_time == START_TIME + 500, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // wait full second epoch
        timestamp::update_global_time_for_test_secs(START_TIME + 500);

        // check all rewards was distributed
        let rew = stake::harvest<S, R>(&alice_acc, @harvest);
        assert!(coin::value(&rew) == amount<R>(2000, 0), 1);

        // check 1 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 1);
        assert!(accum_reward == 2000_0000_000000, 1);
        assert!(last_update_time == START_TIME + 500, 1);
        assert!(end_time == START_TIME + 500, 1);
        assert!(distributed == amount<R>(2000, 0), 1);
        assert!(ended_at == START_TIME + 500, 1);

        coin::deposit(@alice, rew);
    }

    #[test]
    public fun test_deposit_rew_on_unfinished_rew_epoch() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        coin::register<R>(&alice_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        let duration = 500;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        // check 0 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(rewards_amount == amount<R>(1000, 0), 1);
        assert!(reward_per_sec == amount<R>(2, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME, 1);
        assert!(last_update_time == START_TIME, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // stake 100 from alice
        stake::stake<S, R>(&alice_acc, @harvest, coin::withdraw<S>(&alice_acc, amount<S>(100, 0)));

        // wait half of epoch
        timestamp::update_global_time_for_test_secs(START_TIME + 250);

        // create new epoch, take some rewards from previous
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 500);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        assert!(curr_epoch == 1, 0);

        // check 0 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(accum_reward == 500_0000_000000, 1);
        assert!(last_update_time == START_TIME + 250, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == amount<R>(500, 0), 1);
        assert!(ended_at == START_TIME + 250, 1);

        // check 1 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 1);
        // 1000 new + 500 from prev epoch
        assert!(rewards_amount == amount<R>(1500, 0), 1);
        assert!(reward_per_sec == amount<R>(3, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME + 250, 1);
        assert!(last_update_time == START_TIME + 250, 1);
        assert!(end_time == START_TIME + 250 + 500, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // wait full epoch 1
        timestamp::update_global_time_for_test_secs(START_TIME + 250 + 500);

        // check all rewards was distributed
        let rew = stake::harvest<S, R>(&alice_acc, @harvest);
        assert!(coin::value(&rew) == amount<R>(2000, 0), 1);

        // check 1 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 1);
        assert!(accum_reward == 1500_0000_000000, 1);
        assert!(last_update_time == START_TIME + 250 + 500, 1);
        assert!(end_time == START_TIME + 250 + 500, 1);
        assert!(distributed == amount<R>(1500, 0), 1);
        assert!(ended_at == START_TIME + 250 + 500, 1);

        coin::deposit(@alice, rew);
    }

    #[test]
    public fun test_deposit_rew_on_finished_this_sec_rew_epoch() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        coin::register<R>(&alice_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        let duration = 500;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        // check 0 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(rewards_amount == amount<R>(1000, 0), 1);
        assert!(reward_per_sec == amount<R>(2, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME, 1);
        assert!(last_update_time == START_TIME, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // stake 100 from alice
        stake::stake<S, R>(&alice_acc, @harvest, coin::withdraw<S>(&alice_acc, amount<S>(100, 0)));

        // wait full epoch
        timestamp::update_global_time_for_test_secs(START_TIME + 500);

        // create new epoch
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 500);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        assert!(curr_epoch == 2, 0);

        // check 0 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(accum_reward == 1000_0000_000000, 1);
        assert!(last_update_time == START_TIME + duration, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == amount<R>(1000, 0), 1);
        assert!(ended_at == START_TIME + duration, 1);

        // Below epoch appeared as a result of an edge case when the epoch creation
        // transaction came at the second of the end of the previous epoch

        // check 1 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 1);
        assert!(rewards_amount == 0, 1);
        assert!(reward_per_sec == 0, 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME + 500, 1);
        assert!(last_update_time == START_TIME + 500, 1);
        assert!(end_time == START_TIME + 500, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == START_TIME + 500, 1);

        // check 2 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 2);
        assert!(rewards_amount == amount<R>(1000, 0), 1);
        assert!(reward_per_sec == amount<R>(2, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME + 500, 1);
        assert!(last_update_time == START_TIME + 500, 1);
        assert!(end_time == START_TIME + 500 + 500, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // wait full epoch 2
        timestamp::update_global_time_for_test_secs(START_TIME + 500 + 500);

        // check all rewards was distributed
        let rew = stake::harvest<S, R>(&alice_acc, @harvest);
        assert!(coin::value(&rew) == amount<R>(2000, 0), 1);

        // check 1 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 2);
        assert!(accum_reward == 1000_0000_000000, 1);
        assert!(last_update_time == START_TIME + 500 + 500, 1);
        assert!(end_time == START_TIME + 500 + 500, 1);
        assert!(distributed == amount<R>(1000, 0), 1);
        assert!(ended_at == START_TIME + 500 + 500, 1);

        coin::deposit(@alice, rew);
    }

    #[test]
    public fun test_deposit_rew_on_long_time_ago_finished_rew_epoch() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        coin::register<R>(&alice_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        let duration = 500;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        // check 0 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(rewards_amount == amount<R>(1000, 0), 1);
        assert!(reward_per_sec == amount<R>(2, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME, 1);
        assert!(last_update_time == START_TIME, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // stake 100 from alice
        stake::stake<S, R>(&alice_acc, @harvest, coin::withdraw<S>(&alice_acc, amount<S>(100, 0)));

        // wait full epoch + one year
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS * 52);

        // create new epoch
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 500);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        assert!(curr_epoch == 2, 0);

        // check 0 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(accum_reward == 1000_0000_000000, 1);
        assert!(last_update_time == START_TIME + WEEK_IN_SECONDS * 52, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == amount<R>(1000, 0), 1);
        assert!(ended_at == START_TIME + WEEK_IN_SECONDS * 52, 1);

        // check 1 (ghost) epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 1);
        assert!(rewards_amount == 0, 1);
        assert!(reward_per_sec == 0, 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME + duration, 1);
        assert!(last_update_time == START_TIME + WEEK_IN_SECONDS * 52, 1);
        assert!(end_time == START_TIME + WEEK_IN_SECONDS * 52, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == START_TIME + WEEK_IN_SECONDS * 52, 1);

        // check 2 epoch fields
        let (rewards_amount, reward_per_sec, accum_reward,start_time,
            last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 2);
        assert!(rewards_amount == amount<R>(1000, 0), 1);
        assert!(reward_per_sec == amount<R>(2, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(start_time == START_TIME + WEEK_IN_SECONDS * 52, 1);
        assert!(last_update_time == START_TIME + WEEK_IN_SECONDS * 52, 1);
        assert!(end_time == START_TIME + WEEK_IN_SECONDS * 52 + 500, 1);
        assert!(distributed == 0, 1);
        assert!(ended_at == 0, 1);

        // wait full epoch 2
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS * 52 + 500);

        // check all rewards was distributed
        let rew = stake::harvest<S, R>(&alice_acc, @harvest);
        assert!(coin::value(&rew) == amount<R>(2000, 0), 1);

        // check 2 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 2);
        assert!(accum_reward == 1000_0000_000000, 1);
        assert!(last_update_time == START_TIME + WEEK_IN_SECONDS * 52 + 500, 1);
        assert!(end_time == START_TIME + WEEK_IN_SECONDS * 52 + 500, 1);
        assert!(distributed == amount<R>(1000, 0), 1);
        assert!(ended_at == START_TIME + WEEK_IN_SECONDS * 52 + 500, 1);

        coin::deposit(@alice, rew);
    }

    #[test]
    public fun test_rewards_accumulating_after_ghost_epoch() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        coin::register<R>(&alice_acc);

        // create pool
        let reward_coins = mint_default_coin<R>(amount<R>(157680000, 0));
        let duration = 15768000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        // stake some coins
        let coins =
            coin::withdraw<S>(&alice_acc, amount<S>(100, 0));
        stake::stake<S, R>(&alice_acc, @harvest, coins);

        // check accum reward
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        let (_, _, accum_reward, _, last_updated, _, _, _)
            = stake::get_epoch_info<S, R>(@harvest, curr_epoch);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == 0, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME, 1);
        assert!(curr_epoch == 0, 1);

        // wait half of duration & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration / 2);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        let (_, _, accum_reward, _, last_updated, _, _, _)
            = stake::get_epoch_info<S, R>(@harvest, curr_epoch);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == amount<R>(78840000, 0), 1);
        assert!(accum_reward == 788400000000000000, 1);
        assert!(last_updated == START_TIME + duration / 2, 1);
        assert!(curr_epoch == 0, 1);

        // wait full duration & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        let (_, _, accum_reward, _, last_updated, _, _, _)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == amount<R>(157680000, 0), 1);
        assert!(accum_reward == 1576800000000000000, 1);
        assert!(last_updated == START_TIME + duration, 1);
        assert!(curr_epoch == 1, 1);

        // wait full duration + 1 sec & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration + 1);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        let (_, _, accum_reward, _, last_updated, _, _, _)
            = stake::get_epoch_info<S, R>(@harvest, curr_epoch);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == amount<R>(157680000, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME + duration + 1, 1);
        assert!(curr_epoch == 1, 1);

        // wait full duration + 200 weeks & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration + WEEK_IN_SECONDS * 200);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        let (_, _, accum_reward, _, last_updated, _, _, _)
            = stake::get_epoch_info<S, R>(@harvest, curr_epoch);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == amount<R>(157680000, 0), 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME + duration + WEEK_IN_SECONDS * 200, 1);
        assert!(curr_epoch == 1, 1);

        // check user can get rewards after ghost epoch

        // create new epoch
        let reward_coins = mint_default_coin<R>(amount<R>(150, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 150);

        // wait full epoch duration & check accum reward
        timestamp::update_global_time_for_test_secs(START_TIME + duration + WEEK_IN_SECONDS * 200 + 150);
        stake::recalculate_user_stake<S, R>(@harvest, @alice);
        let curr_epoch = stake::get_pool_current_epoch<S, R>(@harvest);
        let (_, _, accum_reward, _, last_updated, _, _, _)
            = stake::get_epoch_info<S, R>(@harvest, 2);
        let reward_val = stake::get_pending_user_rewards<S, R>(@harvest, @alice);
        assert!(reward_val == amount<R>(157680000, 0) + amount<R>(150, 0), 1);
        assert!(accum_reward == 1500000000000, 1);
        assert!(last_updated == START_TIME + duration + WEEK_IN_SECONDS * 200 + 150, 1);
        assert!(curr_epoch == 3, 1);

        let gain = stake::harvest<S, R>(&alice_acc, @harvest);
        assert!(coin::value(&gain) == amount<R>(157680000, 0) + amount<R>(150, 0), 1);
        coin::deposit(@alice, gain);
    }

    // tests with few users

    #[test]
    public fun test_few_users_rewards_changing() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        let bob_acc = new_account_with_stake_coins(@bob, amount<S>(100, 0));
        coin::register<R>(&alice_acc);
        coin::register<R>(&bob_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        let duration = 5_000_000;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        // stake 100 from alice
        stake::stake<S, R>(&alice_acc, @harvest, coin::withdraw<S>(&alice_acc, amount<S>(100, 0)));

        // wait half of first epoch
        timestamp::update_global_time_for_test_secs(START_TIME + duration / 2);

        // stake 100 from bob
        stake::stake<S, R>(&bob_acc, @harvest, coin::withdraw<S>(&bob_acc, amount<S>(100, 0)));

        // wait till the end of first epoch
        timestamp::update_global_time_for_test_secs(START_TIME + duration);

        // create new epoch
        let reward_coins = mint_default_coin<R>(amount<R>(5000, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 500);
        assert!(stake::get_pool_current_epoch<S, R>(@harvest) == 2, 0);

        // wait half of second epoch
        timestamp::update_global_time_for_test_secs(START_TIME + duration + 500 / 2);

        // unstake for alice
        let coins = stake::unstake<S, R>(&alice_acc, @harvest, amount<S>(100, 0));
        coin::deposit(@alice, coins);

        // wait till the end of second epoch
        timestamp::update_global_time_for_test_secs(START_TIME + duration + 500);

        let coins = stake::unstake<S, R>(&bob_acc, @harvest, amount<S>(100, 0));
        coin::deposit(@bob, coins);

        let rewards = stake::harvest<S, R >(&alice_acc, @harvest);
        assert!(coin::value(&rewards) == amount<R>(2000, 0), 1);
        coin::deposit(@alice, rewards);

        let rewards = stake::harvest<S, R >(&bob_acc, @harvest);
        assert!(coin::value(&rewards) == amount<R>(4000, 0), 1);
        coin::deposit(@bob, rewards);

        // check 0 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 0);
        assert!(accum_reward == 7_500000000000, 1);
        assert!(last_update_time == START_TIME + duration, 1);
        assert!(end_time == START_TIME + duration, 1);
        assert!(distributed == amount<R>(1000, 0), 1);
        assert!(ended_at == START_TIME + duration, 1);

        // check 1 (ghost) epoch fields
        let (rewards_amount, reward_per_sec, accum_reward, _, _, _, _, _)
            = stake::get_epoch_info<S, R>(@harvest, 1);
        assert!(rewards_amount == 0, 1);
        assert!(reward_per_sec == 0, 1);
        assert!(accum_reward == 0, 1);

        // check 2 epoch fields
        let (_, _, accum_reward, _, last_update_time,end_time, distributed, ended_at)
            = stake::get_epoch_info<S, R>(@harvest, 2);
        assert!(accum_reward == 37_500000000000, 1);
        assert!(last_update_time == START_TIME + duration + 500, 1);
        assert!(end_time == START_TIME + duration + 500, 1);
        assert!(distributed == amount<R>(5000, 0), 1);
        assert!(ended_at == START_TIME + duration + 500, 1);
    }

    #[test]
    public fun test_few_rew_epochs_no_users_then_two_users() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, amount<S>(100, 0));
        let bob_acc = new_account_with_stake_coins(@bob, amount<S>(100, 0));
        coin::register<R>(&alice_acc);
        coin::register<R>(&bob_acc);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        let duration = 500;
        stake::register_pool<S, R>(&harvest, reward_coins,
            duration, 0, option::none(), vector[]);

        // wait till the end of first epoch and a minute more
        timestamp::update_global_time_for_test_secs(START_TIME + duration + 60);

        // create new epoch
        let reward_coins = mint_default_coin<R>(amount<R>(1000, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 500);
        assert!(stake::get_pool_current_epoch<S, R>(@harvest) == 2, 0);

        // wait till the end of first epoch and a minute more
        timestamp::update_global_time_for_test_secs(START_TIME + duration * 2 + 120);

        // create new epoch
        let reward_coins = mint_default_coin<R>(amount<R>(1200, 0));
        stake::deposit_reward_coins<S, R>(&alice_acc, @harvest, reward_coins, 6_000_000);
        assert!(stake::get_pool_current_epoch<S, R>(@harvest) == 4, 0);

        // wait 1/3 of third epoch
        timestamp::update_global_time_for_test_secs(START_TIME + duration * 2 + 120 + 2_000_000);

        // stake 100 from alice
        stake::stake<S, R>(&alice_acc, @harvest, coin::withdraw<S>(&alice_acc, amount<S>(100, 0)));
        // stake 100 from bob
        stake::stake<S, R>(&bob_acc, @harvest, coin::withdraw<S>(&bob_acc, amount<S>(100, 0)));

        // wait 2/3 of third epoch
        timestamp::update_global_time_for_test_secs(START_TIME + duration * 2 + 120 + 4_000_000);

        let stake_coins = stake::unstake<S, R>(&bob_acc, @harvest, amount<S>(100, 0));
        coin::deposit(@bob, stake_coins);

        // wait till the end of third epoch and a week more
        timestamp::update_global_time_for_test_secs(START_TIME + duration * 2 + 120 + 6_000_000 + WEEK_IN_SECONDS);

        let stake_coins = stake::unstake<S, R>(&alice_acc, @harvest, amount<S>(100, 0));
        coin::deposit(@alice, stake_coins);

        let alice_rewards = stake::harvest<S, R>(&alice_acc, @harvest);
        // as alice were in epoch only 2/3 of time and 1/3 with bob
        // ((1200 / 3) * 0) + ((1200 / 3) * 0.5) + ((1200 / 3) * 1) = 600
        assert!(coin::value(&alice_rewards) == amount<R>(600,0), 1);
        coin::deposit(@alice, alice_rewards);

        let bob_rewards = stake::harvest<S, R>(&bob_acc, @harvest);
        // as bob were in epoch only with alice and 1/3 of epoch time
        // ((1200 / 3) * 0) + ((1200 / 3) * 0.5) + ((1200 / 3) * 0) = 200
        assert!(coin::value(&bob_rewards) == amount<R>(200,0), 1);
        coin::deposit(@bob, bob_rewards);
    }
}
