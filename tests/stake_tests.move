#[test_only]
module harvest::stake_tests {
    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use harvest::stake;
    use harvest::staking_test_helpers::{create_account, initialize_reward_coin, initialize_stake_coin, to_u128, mint_coins, StakeCoin, RewardCoin};

    // todo: add test of registration two different pools at same time from different users

    // todo: deposit reward coins on pool register?
    #[test(harvest = @harvest, alice = @alice)]
    public fun test_register(harvest: &signer, alice: &signer) {
        genesis::setup();

        let (harvest_acc, _) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);

        // create coins for pool to be valid
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        let reward_per_sec_rate = 1000000;
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, reward_per_sec_rate);

        // check pool statistics
        let (reward_per_sec, accum_reward, last_updated, reward_amount) =
            stake::get_pool_info<StakeCoin, RewardCoin>(alice_addr);
        assert!(reward_per_sec == reward_per_sec_rate, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == start_time, 1);
        assert!(reward_amount == 0, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(alice_addr) == 0, 1);
    }

    // todo: deposit reward coins on pool register?
    #[test(harvest = @harvest, alice = @alice)]
    public fun test_deposit_reward_coins(harvest: &signer, alice: &signer) {
        genesis::setup();

        let (harvest_acc, _) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint reward coins
        let reward_coins = mint_coins<RewardCoin>(1000000000);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, 1000000);

        // deposit reward coins
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&alice_acc, reward_coins);

        let (_, _, _, reward_amount) = stake::get_pool_info<StakeCoin, RewardCoin>(alice_addr);
        assert!(reward_amount == 1000000000, 1);
    }

    #[test(harvest = @harvest, alice = @alice, bob = @bob)]
    public fun test_stake_and_unstake(harvest: &signer, alice: &signer, bob: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);
        let (bob_acc, bob_addr) = create_account(bob);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint StakeCoins coins for alice and bob
        let stake_coins_1 = mint_coins<StakeCoin>(900000000);
        let stake_coins_2 = mint_coins<StakeCoin>(99000000);
        coin::register<StakeCoin>(&alice_acc);
        coin::register<StakeCoin>(&bob_acc);
        coin::deposit(alice_addr, stake_coins_1);
        coin::deposit(bob_addr, stake_coins_2);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // check empty balances
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(harvest_addr, alice_addr) == 0, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(harvest_addr, bob_addr) == 0, 1);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);
        assert!(coin::balance<StakeCoin>(alice_addr) == 400000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(harvest_addr, alice_addr) == 500000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(harvest_addr) == 500000000, 1);

        // stake 99 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 99000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, harvest_addr, coins);
        assert!(coin::balance<StakeCoin>(bob_addr) == 0, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(harvest_addr, bob_addr) == 99000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(harvest_addr) == 599000000, 1);

        // stake 300 StakeCoins more from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 300000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);
        assert!(coin::balance<StakeCoin>(alice_addr) == 100000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(harvest_addr, alice_addr) == 800000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(harvest_addr) == 899000000, 1);

        // unstake 400 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, 400000000);
        assert!(coin::value(&coins) == 400000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(harvest_addr, alice_addr) == 400000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(harvest_addr) == 499000000, 1);
        coin::deposit<StakeCoin>(alice_addr, coins);

        // unstake all 99 StakeCoins from bob
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&bob_acc, harvest_addr, 99000000);
        assert!(coin::value(&coins) == 99000000, 1);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(harvest_addr, bob_addr) == 0, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(harvest_addr) == 400000000, 1);
        coin::deposit<StakeCoin>(bob_addr, coins);
    }

    #[test(harvest = @harvest, alice = @alice, bob = @bob)]
    public fun test_reward_calculation(harvest: &signer, alice: &signer, bob: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);
        let (bob_acc, bob_addr) = create_account(bob);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint StakeCoins coins for alice and bob
        let stake_coins_1 = mint_coins<StakeCoin>(900000000);
        let stake_coins_2 = mint_coins<StakeCoin>(99000000);
        coin::register<StakeCoin>(&alice_acc);
        coin::register<StakeCoin>(&bob_acc);
        coin::deposit(alice_addr, stake_coins_1);
        coin::deposit(bob_addr, stake_coins_2);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);

        // check stake parameters
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        assert!(unobtainable_reward == 0, 1);
        assert!(earned_reward == 0, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(harvest_addr, alice_addr);

        // check pool parameters
        let (_, accum_reward, last_updated, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(harvest_addr);
        // (reward_per_sec_rate * time passed / total_staked) + previous period
        assert!(accum_reward == to_u128(1000000), 1);
        assert!(last_updated == start_time + 10, 1);

        // check alice's stake
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        assert!(unobtainable_reward == to_u128(100000000), 1);
        assert!(earned_reward == 100000000, 1);

        // stake 50 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 50000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, harvest_addr, coins);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, bob_addr);
        // stake amount * pool accum_reward
        // accumulated benefit that does not belong to bob
        assert!(unobtainable_reward == to_u128(50000000), 1);
        assert!(earned_reward == 0, 1);

        // stake 100 StakeCoins more from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 20);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(harvest_addr, bob_addr);

        // check pool parameters
        let (_, accum_reward, last_updated, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(harvest_addr);
        assert!(accum_reward == 1400000, 1);
        assert!(last_updated == start_time + 20, 1);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        assert!(unobtainable_reward == to_u128(280000000), 1);
        assert!(earned_reward == 180000000, 1);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, bob_addr);
        assert!(unobtainable_reward == to_u128(70000000), 1);
        assert!(earned_reward == 20000000, 1);

        // unstake 100 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, 100000000);
        coin::deposit<StakeCoin>(alice_addr, coins);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        assert!(unobtainable_reward == to_u128(140000000), 1);
        assert!(earned_reward == 180000000, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 30);

        // synthetic recalculate
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        stake::recalculate_user_stake<StakeCoin, RewardCoin>(harvest_addr, bob_addr);

        // check pool parameters
        let (_, accum_reward, last_updated, _) =
            stake::get_pool_info<StakeCoin, RewardCoin>(harvest_addr);
        assert!(accum_reward == 2066666, 1);
        assert!(last_updated == start_time + 30, 1);

        // check alice's stake parameters
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        assert!(unobtainable_reward == 206666600, 1);
        assert!(earned_reward == 246666600, 1);

        // check bob's stake parameters
        let (unobtainable_reward, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, bob_addr);
        assert!(unobtainable_reward == 103333300, 1);
        assert!(earned_reward == 53333300, 1);
    }

    #[test(harvest = @harvest, alice = @alice, bob = @bob)]
    public fun test_harvest(harvest: &signer, alice: &signer, bob: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);
        let (bob_acc, bob_addr) = create_account(bob);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint StakeCoins coins for alice and bob
        let stake_coins_1 = mint_coins<StakeCoin>(100000000);
        let stake_coins_2 = mint_coins<StakeCoin>(100000000);
        coin::register<StakeCoin>(&alice_acc);
        coin::register<StakeCoin>(&bob_acc);
        coin::deposit(alice_addr, stake_coins_1);
        coin::deposit(bob_addr, stake_coins_2);

        // mint RewardCoins for pool
        let reward_coins = mint_coins<RewardCoin>(300000000);
        coin::register<RewardCoin>(&alice_acc);
        coin::register<RewardCoin>(&bob_acc);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);
        // todo: only admin can deposit rewards in pool?
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest_acc, reward_coins);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // harvest from alice
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, harvest_addr);

        // check amounts
        let (_, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 100000000, 1);

        coin::deposit<RewardCoin>(alice_addr, coins);

        // stake 100 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, harvest_addr, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 20);

        // harvest from alice
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, harvest_addr);

        // check amounts
        let (_, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, alice_addr);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 50000000, 1);

        coin::deposit<RewardCoin>(alice_addr, coins);

        // harvest from bob
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&bob_acc, harvest_addr);

        // check amounts
        let (_, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, bob_addr);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 50000000, 1);

        coin::deposit<RewardCoin>(bob_addr, coins);

        // unstake 100 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, 100000000);
        coin::deposit<StakeCoin>(bob_addr, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 30);

        // harvest from bob
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&bob_acc, harvest_addr);

        // check amounts
        let (_, earned_reward) =
            stake::get_user_stake_info<StakeCoin, RewardCoin>(harvest_addr, bob_addr);
        assert!(earned_reward == 0, 1);
        assert!(coin::value(&coins) == 100000000, 1);

        coin::deposit<RewardCoin>(bob_addr, coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_deposit_reward_coins_fails_if_pool_does_not_exist(harvest: &signer) {
        let (harvest_acc, _) = create_account(harvest);

        // mint reward coins
        initialize_reward_coin(&harvest_acc, 6);
        let reward_coins = mint_coins<RewardCoin>(100);

        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest_acc, reward_coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_stake_fails_if_pool_does_not_exist(harvest: &signer) {
        let (harvest_acc, harvest_addr) = create_account(harvest);

        // mint stake coins
        initialize_stake_coin(&harvest_acc, 6);
        let stake_coins = mint_coins<StakeCoin>(100);

        // stake when no pool
        stake::stake<StakeCoin, RewardCoin>(&harvest_acc, harvest_addr, stake_coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_unstake_fails_if_pool_does_not_exist(harvest: &signer) {
        let (harvest_acc, harvest_addr) = create_account(harvest);

        // unstake when no pool
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&harvest_acc, harvest_addr, 12345);
        coin::deposit<StakeCoin>(harvest_addr, coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_harvest_fails_if_pool_does_not_exist(harvest: &signer) {
        let (harvest_acc, harvest_addr) = create_account(harvest);

        // harvest when no pool
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&harvest_acc, harvest_addr);
        coin::deposit<RewardCoin>(harvest_addr, coins);
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

    #[test(harvest = @harvest, alice = @alice)]
    #[expected_failure(abort_code = 101 /* ERR_POOL_ALREADY_EXISTS */)]
    public fun test_register_fails_if_pool_already_exists(harvest: &signer, alice: &signer) {
        genesis::setup();

        let (harvest_acc, _) = create_account(harvest);
        let (alice_acc, _) = create_account(alice);

        // create coins for pool to be valid
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool twice
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, 1000000);
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, 1000000);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 102 /* ERR_REWARD_CANNOT_BE_ZERO */)]
    public fun test_register_fails_if_reward_is_zero(harvest: &signer) {
        let (harvest_acc, _) = create_account(harvest);

        // register staking pool with zero reward
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 0);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_unstake_fails_if_stake_not_exists(harvest: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // unstake when stake not exists
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&harvest_acc, harvest_addr, 12345);
        coin::deposit<StakeCoin>(harvest_addr, coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_harvest_fails_if_stake_not_exists(harvest: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // harvest when stake not exists
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&harvest_acc, harvest_addr);
        coin::deposit<RewardCoin>(harvest_addr, coins);
    }

    #[test(harvest = @harvest, alice = @alice)]
    #[expected_failure(abort_code = 104 /* ERR_NOT_ENOUGH_BALANCE */)]
    public fun test_unstake_fails_if_not_enough_balance(harvest: &signer, alice: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint StakeCoins coins for alice
        let stake_coins = mint_coins<StakeCoin>(99000000);
        coin::register<StakeCoin>(&alice_acc);
        coin::deposit(alice_addr, stake_coins);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // stake 99 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 99000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);

        // unstake more than staked from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, 99000001);
        coin::deposit<StakeCoin>(alice_addr, coins);
    }

    // todo: only admin can deposit rewards in pool?
    // #[test(harvest = @harvest, alice = @alice)]
    // #[expected_failure(abort_code = 105 /* ERR_NO_PERMISSIONS */)]
    // public fun test_deposit_reward_coins_fails_if_executed_not_by_admin(harvest: &signer, alice: &signer) {
    //     genesis::setup();
    //
    //     let (harvest_acc, _) = create_account(harvest);
    //     let (alice_acc, _) = create_account(alice);
    //
    //     // create coins for pool
    //     initialize_reward_coin(&harvest_acc, 6);
    //     initialize_stake_coin(&harvest_acc, 6);
    //
    //     // mint reward coins
    //     let reward_coins = mint_coins<RewardCoin>(1000000000);
    //
    //     // register staking pool
    //     stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);
    //
    //     // deposit reward coins from non admin account
    //     stake::deposit_reward_coins<StakeCoin, RewardCoin>(&alice_acc, reward_coins);
    // }

    #[test(harvest = @harvest, alice = @alice)]
    #[expected_failure(abort_code = 106 /* ERR_NOT_ENOUGH_DGEN_BALANCE */)]
    public fun test_harvest_fails_if_not_enough_pool_liq_balance(harvest: &signer, alice: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint StakeCoins coins for alice
        let stake_coins = mint_coins<StakeCoin>(100000000);
        coin::register<StakeCoin>(&alice_acc);
        coin::deposit(alice_addr, stake_coins);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // harvest from alice when no RewardCoins in pool
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, harvest_addr);
        coin::deposit<RewardCoin>(alice_addr, coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 107 /* ERR_AMOUNT_CANNOT_BE_ZERO */)]
    public fun test_stake_fails_if_amount_is_zero(harvest: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // stake 0 StakeCoins
        coin::register<StakeCoin>(&harvest_acc);
        let coins =
            coin::withdraw<StakeCoin>(&harvest_acc, 0);
        stake::stake<StakeCoin, RewardCoin>(&harvest_acc, harvest_addr, coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 107 /* ERR_AMOUNT_CANNOT_BE_ZERO */)]
    public fun test_unstake_fails_if_amount_is_zero(harvest: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);

        // unstake 0 StakeCoin
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&harvest_acc, harvest_addr, 0);
        coin::deposit<StakeCoin>(harvest_addr, coins);
    }

    #[test(harvest = @harvest, alice = @alice)]
    #[expected_failure(abort_code = 108 /* ERR_NOTHING_TO_HARVEST */)]
    public fun test_harvest_fails_if_nothing_to_harvest_1(harvest: &signer, alice: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint StakeCoins coins for alice
        let stake_coins = mint_coins<StakeCoin>(100000000);
        coin::register<StakeCoin>(&alice_acc);
        coin::deposit(alice_addr, stake_coins);

        // mint RewardCoins for pool
        let reward_coins = mint_coins<RewardCoin>(300000000);
        coin::register<RewardCoin>(&alice_acc);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);
        // todo: only admin can deposit rewards in pool?
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest_acc, reward_coins);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);

        // harvest from alice at the same second
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, harvest_addr);
        coin::deposit<RewardCoin>(alice_addr, coins);
    }

    #[test(harvest = @harvest, alice = @alice)]
    #[expected_failure(abort_code = 108 /* ERR_NOTHING_TO_HARVEST */)]
    public fun test_harvest_fails_if_nothing_to_harvest_2(harvest: &signer, alice: &signer) {
        genesis::setup();

        let (harvest_acc, harvest_addr) = create_account(harvest);
        let (alice_acc, alice_addr) = create_account(alice);

        // create coins for pool
        initialize_reward_coin(&harvest_acc, 6);
        initialize_stake_coin(&harvest_acc, 6);

        // mint StakeCoins coins for alice
        let stake_coins = mint_coins<StakeCoin>(100000000);
        coin::register<StakeCoin>(&alice_acc);
        coin::deposit(alice_addr, stake_coins);

        // mint RewardCoins for pool
        let reward_coins = mint_coins<RewardCoin>(300000000);
        coin::register<RewardCoin>(&alice_acc);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool with rewards
        let reward_per_sec_rate = 10000000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, reward_per_sec_rate);
        // todo: only admin can deposit rewards in pool?
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest_acc, reward_coins);

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, harvest_addr, coins);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        // harvest from alice twice at the same second
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, harvest_addr);
        coin::deposit<RewardCoin>(alice_addr, coins);
        let coins =
            stake::harvest<StakeCoin, RewardCoin>(&alice_acc, harvest_addr);
        coin::deposit<RewardCoin>(alice_addr, coins);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 110 /* ERR_IS_NOT_COIN */)]
    public fun test_register_fails_if_stake_coin_is_not_coin(harvest: &signer) {
        genesis::setup();

        let (harvest_acc, _) = create_account(harvest);

        // create only reward coin
        initialize_reward_coin(&harvest_acc, 6);

        // register staking pool without stake coin
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);
    }

    #[test(harvest = @harvest)]
    #[expected_failure(abort_code = 110 /* ERR_IS_NOT_COIN */)]
    public fun test_register_fails_if_reward_coin_is_not_coin(harvest: &signer) {
        genesis::setup();

        let (harvest_acc, _) = create_account(harvest);

        // create only stake coin
        initialize_stake_coin(&harvest_acc, 6);

        // register staking pool without reward coin
        stake::register_pool<StakeCoin, RewardCoin>(&harvest_acc, 1000000);
    }
}
