#[test_only]
module harvest::emergency_tests {
    use std::option;
    use std::string;

    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use aptos_token::token;

    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_nft_boost_tests::{create_collecton, create_token};
    use harvest::stake_test_helpers::{new_account_with_stake_coins, mint_default_coin, RewardCoin, StakeCoin, new_account};
    use harvest::stake_tests::initialize_test;

    /// this is number of decimals in both StakeCoin and RewardCoin by default, named like that for readability
    const ONE_COIN: u64 = 1000000;

    const START_TIME: u64 = 682981200;

    #[test]
    fun test_initialize() {
        let emergency_admin = new_account(@stake_emergency_admin);

        stake_config::initialize(
            &emergency_admin,
            @treasury,
        );

        assert!(stake_config::get_treasury_admin_address() == @treasury, 1);
        assert!(stake_config::get_emergency_admin_address() == @stake_emergency_admin, 1);
        assert!(!stake_config::is_global_emergency(), 1);
    }

    #[test]
    fun test_set_treasury_admin_address() {
        let treasury_acc = new_account(@treasury);
        let emergency_admin = new_account(@stake_emergency_admin);
        let alice_acc = new_account(@alice);

        stake_config::initialize(
            &emergency_admin,
            @treasury,
        );

        stake_config::set_treasury_admin_address(&treasury_acc, @alice);
        assert!(stake_config::get_treasury_admin_address() == @alice, 1);
        stake_config::set_treasury_admin_address(&alice_acc, @treasury);
        assert!(stake_config::get_treasury_admin_address() == @treasury, 1);
    }

    #[test]
    #[expected_failure(abort_code = 200)]
    fun test_set_treasury_admin_address_from_no_permission_account_fails() {
        let emergency_admin = new_account(@stake_emergency_admin);
        let alice_acc = new_account(@alice);

        stake_config::initialize(
            &emergency_admin,
            @treasury,
        );

        stake_config::set_treasury_admin_address(&alice_acc, @treasury);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_register_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        stake_config::enable_global_emergency(&emergency_admin);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_stake_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_unstake_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, 100);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_add_rewards_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest, @pool_storage, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_harvest_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        // wait for rewards
        timestamp::update_global_time_for_test_secs(START_TIME + 100);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        coin::deposit(@alice, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_boost_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::some(boost_config)
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, nft);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_claim_with_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::some(boost_config)
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, nft);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        // remove boost
        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        token::deposit_token(&alice_acc, nft);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_stake_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake_config::enable_global_emergency(&emergency_admin);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_unstake_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        stake_config::enable_global_emergency(&emergency_admin);

        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, 100);
        coin::deposit(@alice, coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_add_rewards_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake_config::enable_global_emergency(&emergency_admin);

        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest, @pool_storage, reward_coins);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_harvest_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        // wait for rewards
        timestamp::update_global_time_for_test_secs(START_TIME + 100);

        stake_config::enable_global_emergency(&emergency_admin);

        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        coin::deposit(@alice, reward_coins);
    }

        #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_boost_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::some(boost_config)
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        stake_config::enable_global_emergency(&emergency_admin);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, nft);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_claim_with_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::some(boost_config)
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, nft);

        stake_config::enable_global_emergency(&emergency_admin);

        // remove boost
        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        token::deposit_token(&alice_acc, nft);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_enable_local_emergency_if_global_is_enabled() {
        let (harvest, emergency_admin) = initialize_test();

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake_config::enable_global_emergency(&emergency_admin);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);
    }

    #[test]
    #[expected_failure(abort_code = 111)]
    fun test_cannot_enable_emergency_with_non_admin_account() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account(@alice);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake::enable_emergency<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_enable_emergency_twice() {
        let (harvest, emergency_admin) = initialize_test();

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);
        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);
    }

    #[test]
    fun test_unstake_everything_in_case_of_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@pool_storage, @alice) == 1 * ONE_COIN, 1);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        assert!(option::is_none(&nft), 1);
        option::destroy_none(nft);
        coin::deposit(@alice, coins);

        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@pool_storage, @alice), 3);
    }

    #[test]
    fun test_unstake_everything_and_nft_in_case_of_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::some(boost_config)
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@pool_storage, @alice) == 1 * ONE_COIN, 1);
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, nft);

        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @pool_storage);

        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        assert!(option::is_some(&nft), 1);
        token::deposit_token(&alice_acc, option::extract(&mut nft));
        option::destroy_none(nft);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        coin::deposit(@alice, coins);

        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@pool_storage, @alice), 3);
    }

    #[test]
    #[expected_failure(abort_code = 110)]
    fun test_cannot_emergency_unstake_in_non_emergency() {
        let (harvest, _) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);

        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        option::destroy_none(nft);
        coin::deposit(@alice, coins);
    }

    #[test]
    fun test_emergency_is_local_to_a_pool() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        let res_acc_addr_1 = @0x51441c1d7933033cbc6cecf7e255a670adcc6cb18c88838a8b3f147f3cfb616b;
        let res_acc_addr_2 = @0x2548ca468d04206f9162f5897fc0b69de75e035fc7236a5db9874f3f0eb23718;

        // register staking pool
        let reward_coins_1 = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let reward_coins_2 = mint_default_coin<StakeCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed_1",
            reward_coins_1,
            duration,
            option::none()
        );
        stake::register_pool<RewardCoin, StakeCoin>(
            &harvest,
            b"some_seed_2",
            reward_coins_2,
            duration,
            option::none()
        );

        stake::enable_emergency<RewardCoin, StakeCoin>(&emergency_admin, res_acc_addr_2);

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, res_acc_addr_1, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(res_acc_addr_1, @alice) == 1 * ONE_COIN, 3);
    }

    #[test]
    #[expected_failure(abort_code = 202)]
    fun test_cannot_enable_global_emergency_twice() {
        let (harvest, emergency_admin) = initialize_test();

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake_config::enable_global_emergency(&emergency_admin);
        stake_config::enable_global_emergency(&emergency_admin);
    }

    #[test]
    fun test_unstake_everything_in_case_of_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        // register staking pool
        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@pool_storage, @alice) == 1 * ONE_COIN, 1);

        stake_config::enable_global_emergency(&emergency_admin);

        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        assert!(option::is_none(&nft), 1);
        option::destroy_none(nft);
        coin::deposit(@alice, coins);

        let exists = stake::stake_exists<StakeCoin, RewardCoin>(@pool_storage, @alice);
        assert!(!exists, 3);
    }

    #[test]
    fun test_unstake_everything_and_nft_in_case_of_global_emergency() {
        let (harvest, emergency_admin) = initialize_test();

        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::some(boost_config)
        );

        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, coins);
        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@pool_storage, @alice) == 1 * ONE_COIN, 1);
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @pool_storage, nft);

        stake_config::enable_global_emergency(&emergency_admin);

        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @pool_storage);
        assert!(option::is_some(&nft), 1);
        token::deposit_token(&alice_acc, option::extract(&mut nft));
        option::destroy_none(nft);
        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
        coin::deposit(@alice, coins);

        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@pool_storage, @alice), 3);
    }

    #[test]
    #[expected_failure(abort_code = 200)]
    fun test_cannot_enable_global_emergency_with_non_admin_account() {
        let (_, _) = initialize_test();
        let alice = new_account(@alice);
        stake_config::enable_global_emergency(&alice);
    }

    #[test]
    #[expected_failure(abort_code = 200)]
    fun test_cannot_change_admin_with_non_admin_account() {
        let (_, _) = initialize_test();
        let alice = new_account(@alice);
        stake_config::set_emergency_admin_address(&alice, @alice);
    }

    #[test]
    fun test_enable_emergency_with_changed_admin_account() {
        let (harvest, emergency_admin) = initialize_test();
        stake_config::set_emergency_admin_address(&emergency_admin, @alice);

        let alice = new_account(@alice);

        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );
        stake::enable_emergency<StakeCoin, RewardCoin>(&alice, @pool_storage);

        assert!(stake::is_local_emergency<StakeCoin, RewardCoin>(@pool_storage), 1);
        assert!(stake::is_emergency<StakeCoin, RewardCoin>(@pool_storage), 2);
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
        let (harvest, emergency_admin) = initialize_test();
        stake_config::set_emergency_admin_address(&emergency_admin, @alice);

        let alice = new_account(@alice);

        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
        let duration = 12345;
        stake::register_pool<StakeCoin, RewardCoin>(
            &harvest,
            b"some_seed",
            reward_coins,
            duration,
            option::none()
        );

        stake_config::enable_global_emergency(&alice);

        assert!(!stake::is_local_emergency<StakeCoin, RewardCoin>(@pool_storage), 1);
        assert!(stake::is_emergency<StakeCoin, RewardCoin>(@pool_storage), 2);
        assert!(stake_config::is_global_emergency(), 3);
    }

    // Cases for ERR_NOT_INITIALIZED.

    #[test]
    #[expected_failure(abort_code=201)]
    fun test_enable_global_emergency_not_initialized_fails() {
        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::enable_global_emergency(&emergency_admin);
    }

    #[test]
    #[expected_failure(abort_code=201)]
    fun test_is_global_emergency_not_initialized_fails() {
        stake_config::is_global_emergency();
    }

    #[test]
    #[expected_failure(abort_code=201)]
    fun test_get_emergency_admin_address_not_initialized_fails() {
        stake_config::get_emergency_admin_address();
    }

    #[test]
    #[expected_failure(abort_code=201)]
    fun test_get_treasury_admin_address_not_initialized_fails() {
        stake_config::get_treasury_admin_address();
    }

    #[test]
    #[expected_failure(abort_code=201)]
    fun test_set_emergency_admin_address_not_initialized_fails() {
        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::set_emergency_admin_address(&emergency_admin, @alice);
    }

    #[test]
    #[expected_failure(abort_code=201)]
    fun test_set_treasury_admin_address_not_initialized_fails() {
        let treasury_admin = new_account(@treasury);
        stake_config::set_emergency_admin_address(&treasury_admin, @alice);
    }
}
