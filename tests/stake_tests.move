#[test_only]
module harvest::stake_tests {
    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use harvest::stake;
    use harvest::stake_test_helpers::{new_account, initialize_reward_coin, initialize_stake_coin, to_u128, mint_coins, StakeCoin, RewardCoin, initialize_default_stake_reward_coins, new_account_with_stake_coins};

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    /// this is number of decimals in both StakeCoin and RewardCoin by default, named like that for readability
    const ONE_COIN: u64 = 1000000;

    // todo: add test of registration two different pools at same time from different users

    #[test]
    public fun test_register() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        let alice_acc = new_account(@alice);

        // create coins for pool to be valid
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        let reward_per_sec_rate = 1000000;
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, reward_per_sec_rate);

        // check pool statistics
        let (reward_per_sec, accum_reward, last_updated, reward_amount, s_scale, r_scale) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@alice);
        assert!(reward_per_sec == reward_per_sec_rate, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == start_time, 1);
        assert!(reward_amount == 0, 1);
        assert!(s_scale == 1000000, 1);
        assert!(r_scale == 1000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@alice) == 0, 1);
    }

    #[test]
    public fun test_deposit_reward_coins() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint reward coins
        let reward_coins = mint_coins<RewardCoin>(1000000000);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // deposit reward coins
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(@harvest, reward_coins);

        let (_, _, _, reward_amount, _, _) = stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(reward_amount == 1000000000, 1);
    }

    #[test]
    public fun test_stake_and_unstake() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 900000000);
        let bob_acc = new_account_with_stake_coins(@bob, 99000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // check empty balances
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @bob) == 0, 1);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(coin::balance<StakeCoin>(@alice) == 400000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 500000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest) == 500000000, 1);

        // stake 99 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 99000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);
        assert!(coin::balance<StakeCoin>(@bob) == 0, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @bob) == 99000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest) == 599000000, 1);

        // stake 300 StakeCoins more from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 300000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(coin::balance<StakeCoin>(@alice) == 100000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 800000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest) == 899000000, 1);

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(start_time + WEEK_IN_SECONDS);

        // unstake 400 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 400000000);
        assert!(coin::value(&coins) == 400000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 400000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest) == 499000000, 1);
        coin::deposit<StakeCoin>(@alice, coins);

        // unstake all 99 StakeCoins from bob
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&bob_acc, @harvest, 99000000);
        assert!(coin::value(&coins) == 99000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @bob) == 0, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest) == 400000000, 1);
        coin::deposit<StakeCoin>(@bob, coins);
    }

    #[test]
    public fun test_stake_lockup_period() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 1000000);
        let bob_acc = new_account_with_stake_coins(@bob, 1000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // stake from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check alice stake unlock time
        let (_, _, unlock_time) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unlock_time == start_time + WEEK_IN_SECONDS, 1);

        // wait 100 seconds
        timestamp::update_global_time_for_test_secs(start_time + 100);

        // stake from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 500000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        // check bob stake unlock time
        let (_, _, unlock_time) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(unlock_time == start_time + WEEK_IN_SECONDS + 100, 1);

        // stake more from alice before lockup period end
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check alice stake unlock time updated
        let (_, _, unlock_time) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unlock_time == start_time + WEEK_IN_SECONDS + 100, 1);

        // wait one week
        timestamp::update_global_time_for_test_secs(start_time + 100 + WEEK_IN_SECONDS);

        // unstake from alice after lockup period end
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 1000000);
        coin::deposit(@alice, coins);

        // wait 100 seconds
        timestamp::update_global_time_for_test_secs(start_time + 200 + WEEK_IN_SECONDS);

        // partial unstake from bob after lockup period end
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&bob_acc, @harvest, 250000);
        coin::deposit(@bob, coins);

        // wait 100 seconds
        timestamp::update_global_time_for_test_secs(start_time + 300 + WEEK_IN_SECONDS);

        // stake more from bob after lockup period end
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 500000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        // check bob stake unlock time updated
        let (_, _, unlock_time) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(unlock_time == start_time + WEEK_IN_SECONDS + 300 + WEEK_IN_SECONDS, 1);

        // wait 1 year
        timestamp::update_global_time_for_test_secs(start_time + 31536000);

        // unstake from bob almost year after lockup period end
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&bob_acc, @harvest, 250000);
        coin::deposit(@bob, coins);

        // stake from alice after year of rest
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check alice stake unlock time
        let (_, _, unlock_time) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unlock_time == start_time + 31536000 + WEEK_IN_SECONDS, 1);
    }

    #[test]
    public fun test_reward_calculation() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 900000000);
        let bob_acc = new_account_with_stake_coins(@bob, 99000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == 0, 1);
        assert!(earned_reward == 0, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        // (reward_per_sec_rate * time passed / total_staked) + previous period
        assert!(accum_reward == to_u128(1000000), 1);
        assert!(last_updated == start_time + 10, 1);

        // check alice's stake
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == to_u128(100000000), 1);
        assert!(earned_reward == 100000000, 1);

        // stake 50 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 50000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        // stake amount * pool accum_reward
        // accumulated benefit that does not belong to bob
        assert!(unobtainable_reward == to_u128(50000000), 1);
        assert!(earned_reward == 0, 1);

        // stake 100 StakeCoins more from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 20);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @bob);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 1400000, 1);
        assert!(last_updated == start_time + 20, 1);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == to_u128(280000000), 1);
        assert!(earned_reward == 180000000, 1);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(unobtainable_reward == to_u128(70000000), 1);
        assert!(earned_reward == 20000000, 1);

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(start_time + 20 + WEEK_IN_SECONDS);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @bob);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 24193400000, 1);
        assert!(last_updated == start_time + 20 + WEEK_IN_SECONDS, 1);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == to_u128(4838680000000), 1);
        assert!(earned_reward == 4838580000000, 1);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(unobtainable_reward == to_u128(1209670000000), 1);
        assert!(earned_reward == 1209620000000, 1);

        // unstake 100 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100000000);
        coin::deposit<StakeCoin>(@alice, coins);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == to_u128(2419340000000), 1);
        assert!(earned_reward == 4838580000000, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 30 + WEEK_IN_SECONDS);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @bob);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 24194066666, 1);
        assert!(last_updated == start_time + 30 + WEEK_IN_SECONDS, 1);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward1, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == 2419406666600, 1);
        assert!(earned_reward1 == 4838646666600, 1);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward2, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(unobtainable_reward == 1209703333300, 1);
        assert!(earned_reward2 == 1209653333300, 1);

        // 0.0001 RewardCoin lost during calculations
        let total_rewards = (30 + WEEK_IN_SECONDS) * reward_per_sec_rate;
        let total_earned = earned_reward1 + earned_reward2;
        let losed_rewards =  total_rewards - total_earned;

        assert!(losed_rewards == 100, 1);
    }

    #[test]
    public fun test_reward_calculation_works_well_when_pool_is_empty() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 100000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);

        // wait one week with empty pool
        timestamp::update_global_time_for_test_secs(start_time + WEEK_IN_SECONDS);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == start_time, 1);

        // stake from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == 0, 1);
        assert!(earned_reward == 0, 1);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == start_time + WEEK_IN_SECONDS, 1);

        // wait one week with stake
        timestamp::update_global_time_for_test_secs(start_time + (WEEK_IN_SECONDS * 2));

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);

        // check stake parameters, here we count on that user receives reward for one week only
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        // 604800 seconds * 10 rew_per_second, all coins belong to user
        assert!(unobtainable_reward == 6048000000000, 1);
        assert!(earned_reward == 6048000000000, 1);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        // 604800 seconds * 10 rew_per_second / 100 total_staked
        assert!(accum_reward == 60480000000, 1);
        assert!(last_updated == start_time + (WEEK_IN_SECONDS * 2), 1);

        // unstake from alice
        let coins
            = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100000000);
        coin::deposit(@alice, coins);

        // check stake parameters
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        // 604800 seconds * 10 rew_per_second, all coins belong to user
        assert!(unobtainable_reward == 0, 1);
        assert!(earned_reward == 6048000000000, 1);

        // check pool parameters
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        // 604800 seconds * 10 rew_per_second / 100 total_staked
        assert!(accum_reward == 60480000000, 1);
        assert!(last_updated == start_time + (WEEK_IN_SECONDS * 2), 1);

        // wait few more weeks with empty pool
        timestamp::update_global_time_for_test_secs(start_time + (WEEK_IN_SECONDS * 5));

        // stake again from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check stake parameters, user should not be able to claim rewards for period after unstake
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == 6048000000000, 1);
        assert!(earned_reward == 6048000000000, 1);

        // check pool parameters, pool should not accumulate rewards when no stakes in it
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 60480000000, 1);
        assert!(last_updated == start_time + (WEEK_IN_SECONDS * 5), 1);

        // wait one week after stake
        timestamp::update_global_time_for_test_secs(start_time + (WEEK_IN_SECONDS * 6));

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);

        // check stake parameters, user should not be able to claim rewards for period after unstake
        let (unobtainable_reward, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(unobtainable_reward == 12096000000000, 1);
        assert!(earned_reward == 12096000000000, 1);

        // check pool parameters, pool should not accumulate rewards when no stakes in it
        let (_, accum_reward, last_updated, _, _, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@harvest);
        assert!(accum_reward == 120960000000, 1);
        assert!(last_updated == start_time + (WEEK_IN_SECONDS * 6), 1);
    }

    #[test]
    public fun test_harvest() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 100000000);
        let bob_acc = new_account_with_stake_coins(@bob, 100000000);

        // mint RewardCoins for pool
        let reward_coins = mint_coins<RewardCoin>(30000000000000);
        coin::register<RewardCoin>(&alice_acc);
        coin::register<RewardCoin>(&bob_acc);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(@harvest, reward_coins);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // harvest from alice
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);

        // check amounts
        let (_, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 100000000, 1);

        coin::deposit<RewardCoin>(@alice, coins);

        // stake 100 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(start_time + 10 + WEEK_IN_SECONDS);

        // harvest from alice
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);

        // check amounts
        let (_, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 3024000000000, 1);

        coin::deposit<RewardCoin>(@alice, coins);

        // harvest from bob
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@bob, @harvest);

        // check amounts
        let (_, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 3024000000000, 1);

        coin::deposit<RewardCoin>(@bob, coins);

        // unstake 100 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100000000);
        coin::deposit<StakeCoin>(@bob, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 20 + WEEK_IN_SECONDS);

        // harvest from bob
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@bob, @harvest);

        // check amounts
        let (_, earned_reward, _) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 100000000, 1);

        coin::deposit<RewardCoin>(@bob, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_deposit_reward_coins_fails_if_pool_does_not_exist() {
        let harvest_acc = new_account(@harvest);

        // mint reward coins
        initialize_reward_coin(&harvest_acc, 6);
        let reward_coins = mint_coins<RewardCoin>(100);

        stake::deposit_reward_coins<StakeCoin, RewardCoin>(@harvest, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_stake_fails_if_pool_does_not_exist() {
        let harvest_acc = new_account(@harvest);

        // mint stake coins
        initialize_stake_coin(&harvest_acc, 6);
        let stake_coins = mint_coins<StakeCoin>(100);

        // stake when no pool
        stake::stake<StakeCoin, RewardCoin>(&harvest_acc, @harvest, stake_coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_unstake_fails_if_pool_does_not_exist() {
        let harvest_acc = new_account(@harvest);

        // unstake when no pool
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&harvest_acc, @harvest, 12345);
        coin::deposit<StakeCoin>(@harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_harvest_fails_if_pool_does_not_exist() {
        new_account(@harvest);

        // harvest when no pool
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@harvest, @harvest);
        coin::deposit<RewardCoin>(@harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_pool_total_staked_fails_if_pool_does_not_exist() {
        stake::get_pool_total_stake<StakeCoin, RewardCoin>(@harvest);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_user_stake_fails_if_pool_does_not_exist() {
        stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice);
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_POOL_ALREADY_EXISTS */)]
    public fun test_register_fails_if_pool_already_exists() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        let alice_acc = new_account(@alice);

        // create coins for pool to be valid
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool twice
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, 1000000);
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, 1000000);
    }

    #[test]
    #[expected_failure(abort_code = 102 /* ERR_REWARD_CANNOT_BE_ZERO */)]
    public fun test_register_fails_if_reward_is_zero() {
        let harvest_acc = new_account(@harvest);

        // register staking pool with zero reward
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 0);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_unstake_fails_if_stake_not_exists() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // unstake when stake not exists
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&harvest_acc, @harvest, 12345);
        coin::deposit<StakeCoin>(@harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_harvest_fails_if_stake_not_exists() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // harvest when stake not exists
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@harvest, @harvest);
        coin::deposit<RewardCoin>(@harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 104 /* ERR_NOT_ENOUGH_S_BALANCE */)]
    public fun test_unstake_fails_if_not_enough_balance() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 99000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // stake 99 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 99000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(start_time + WEEK_IN_SECONDS);

        // unstake more than staked from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 99000001);
        coin::deposit<StakeCoin>(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 105 /* ERR_NOT_ENOUGH_REWARDS */)]
    public fun test_harvest_fails_if_not_enough_pool_reward_balance() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 100000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // harvest from alice when no RewardCoins in pool
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);
        coin::deposit<RewardCoin>(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 106 /* ERR_AMOUNT_CANNOT_BE_ZERO */)]
    public fun test_stake_fails_if_amount_is_zero() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // stake 0 StakeCoins
        coin::register<StakeCoin>(&harvest_acc);
        let coins =
            coin::withdraw<StakeCoin>(&harvest_acc, 0);
        stake::stake<StakeCoin, RewardCoin>(&harvest_acc, @harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 106 /* ERR_AMOUNT_CANNOT_BE_ZERO */)]
    public fun test_unstake_fails_if_amount_is_zero() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // unstake 0 StakeCoin
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&harvest_acc, @harvest, 0);
        coin::deposit<StakeCoin>(@harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 107 /* ERR_NOTHING_TO_HARVEST */)]
    public fun test_harvest_fails_if_nothing_to_harvest_1() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 100000000);

        // mint RewardCoins for pool
        let reward_coins = mint_coins<RewardCoin>(300000000);
        coin::register<RewardCoin>(&alice_acc);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(@harvest, reward_coins);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // harvest from alice at the same second
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);
        coin::deposit<RewardCoin>(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 107 /* ERR_NOTHING_TO_HARVEST */)]
    public fun test_harvest_fails_if_nothing_to_harvest_2() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 100000000);

        // mint RewardCoins for pool
        let reward_coins = mint_coins<RewardCoin>(300000000);
        coin::register<RewardCoin>(&alice_acc);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(@harvest, reward_coins);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // harvest from alice twice at the same second
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);
        coin::deposit<RewardCoin>(@alice, coins);
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);
        coin::deposit<RewardCoin>(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 108 /* ERR_IS_NOT_COIN */)]
    public fun test_register_fails_if_stake_coin_is_not_coin() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        // create only reward coin
        initialize_reward_coin(&harvest_acc, 6);

        // register staking pool without stake coin
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);
    }

    #[test]
    #[expected_failure(abort_code = 108 /* ERR_IS_NOT_COIN */)]
    public fun test_register_fails_if_reward_coin_is_not_coin() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);

        // create only stake coin
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool without reward coin
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);
    }

    #[test]
    #[expected_failure(abort_code = 109 /* ERR_TOO_EARLY_UNSTAKE */)]
    public fun test_unstake_fails_if_executed_before_lockup_end() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 1000000);

        // mint RewardCoins for pool
        let reward_coins = mint_coins<RewardCoin>(30000000000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(@harvest, reward_coins);

        // stake from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // wait almost a week
        timestamp::update_global_time_for_test_secs(start_time + WEEK_IN_SECONDS - 1);

        // unstake from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 1000000);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_stake_with_emergency() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest_acc, @harvest);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_unstake_with_emergency() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest_acc, @harvest);

        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_harvest_with_emergency() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let _ = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest_acc, @harvest);

        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(@alice, @harvest);
        coin::deposit(@alice, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 112)]
    fun test_cannot_enable_emergency_with_non_admin_account() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&alice_acc, @harvest);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_enable_emergency_twice() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1 * ONE_COIN);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest_acc, @harvest);
        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest_acc, @harvest);
    }

    #[test]
    fun test_unstake_everything_in_case_of_emergency() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1 * ONE_COIN);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);

        stake::enable_emergency<StakeCoin, RewardCoin>(&harvest_acc, @harvest);

        let coins = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        coin::deposit(@alice, coins);

        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 0, 3);
    }

    #[test]
    fun test_emergency_is_local_to_a_pool() {
        genesis::setup();

        let harvest_acc = new_account(@harvest);
        initialize_default_stake_reward_coins(&harvest_acc);

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1 * ONE_COIN);
        stake::register_pool<RewardCoin, StakeCoin>(&harvest_acc, 1 * ONE_COIN);

        stake::enable_emergency<RewardCoin, StakeCoin>(&harvest_acc, @harvest);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 3);
    }
}
