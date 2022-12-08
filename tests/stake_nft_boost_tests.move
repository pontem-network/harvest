#[test_only]
module harvest::stake_nft_boost_tests {
    use std::option;
    use std::string::{Self, String};

    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use aptos_token::token::{Self, Token};

    use harvest::stake;
    use harvest::stake_test_helpers::{new_account, StakeCoin, RewardCoin, new_account_with_stake_coins, mint_default_coin};
    use harvest::stake_tests::initialize_test;

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    const START_TIME: u64 = 682981200;

    public fun create_collecton(owner_addr: address, collection_name: String): signer {
        let collection_owner = new_account(owner_addr);

        token::create_collection(
            &collection_owner,
            collection_name,
            string::utf8(b"Some Description"),
            string::utf8(b"https://aptos.dev"),
            50,
            vector<bool>[false, false, false]
        );

        collection_owner
    }

    public fun create_token(collection_owner: &signer, collection_name: String, name: String): Token {
        token::create_token_script(
            collection_owner,
            collection_name,
            name,
            string::utf8(b"Some Description"),
            1,
            1,
            string::utf8(b"https://aptos.dev"),
            @collection_owner,
            100,
            0,
            vector<bool>[ false, false, false, false, false, false ],
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
        );
        let token_id = token::create_token_id_raw(@collection_owner, collection_name, name, 0);

        token::withdraw_token(collection_owner, token_id, 1)
    }

    #[test]
    public fun test_register_with_boost_config() {
        initialize_test();

        let alice_acc = new_account(@alice);

        let collection_name = string::utf8(b"Test Collection");
        create_collecton(@collection_owner, collection_name);

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, reward_coins, duration, option::some(boost_config));

        // check pool statistics
        let (reward_per_sec, accum_reward, last_updated, reward_amount, s_scale) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@alice);
        let end_ts = stake::get_end_timestamp<StakeCoin, RewardCoin>(@alice);
        assert!(end_ts == START_TIME + duration, 1);
        assert!(reward_per_sec == 1000000, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == START_TIME, 1);
        assert!(reward_amount == 15768000000000, 1);
        assert!(s_scale == 1000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@alice) == 0, 1);

        // check boost config
        let (collection_owner_addr, coll_name, boost_percent) =
            stake::get_boost_config<StakeCoin, RewardCoin>(@alice);
        assert!(collection_owner_addr == @collection_owner, 1);
        assert!(coll_name == collection_name, 1);
        assert!(boost_percent == 5, 1);
    }

    #[test]
    public fun test_boost_and_remove_boost() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

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
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 25000000, 1);
        assert!(user_boosted == 25000000, 1);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + 10);

        let pending_rewards = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(pending_rewards == 9999675, 1);

        // remove nft boost
        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        token::deposit_token(&alice_acc, nft);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);
    }

    #[test]
    public fun test_reward_calculation_with_boost() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 150000000);
        let bob_acc = new_account_with_stake_coins(@bob, 150000000);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft_1 = create_token(&collection_owner, collection_name, string::utf8(b"Token 1"));
        let nft_2 = create_token(&collection_owner, collection_name, string::utf8(b"Token 2"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            100
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 100 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // stake 100 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 100000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        // boost stake with nft from alice
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft_1);

        // wait one week seconds
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS);

        let pending_rewards_1 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice);
        let pending_rewards_2 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(pending_rewards_1 == 403200000000, 1);
        assert!(pending_rewards_2 == 201600000000, 1);

        // unstake 50 StakeCoins from alice
        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 50000000);
        coin::deposit(@alice, coins);

        // boost stake with nft from bob
        stake::boost<StakeCoin, RewardCoin>(&bob_acc, @harvest, nft_2);

        // wait 100 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS + 100);

        let pending_rewards_1 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice);
        let pending_rewards_2 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(pending_rewards_1 == 403233333300, 1);
        assert!(pending_rewards_2 == 201666666600, 1);

        // unstake 50 StakeCoins from alice
        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 50000000);
        coin::deposit(@alice, coins);

        // stake 50 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 50000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        // wait 100 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS + 200);

        let pending_rewards_1 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice);
        let pending_rewards_2 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(pending_rewards_1 == 403233333300, 1);
        assert!(pending_rewards_2 == 201766666500, 1);

        // stake 150 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 150000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // remove nft boost from bob
        let nft_2 = stake::remove_boost<StakeCoin, RewardCoin>(&bob_acc, @harvest);
        token::deposit_token(&bob_acc, nft_2);

        // wait 100 seconds
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS + 300);

        let pending_rewards_1 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice);
        let pending_rewards_2 = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(pending_rewards_1 == 403299999900, 1);
        assert!(pending_rewards_2 == 201799999800, 1);

        let rewards_1 = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        let rewards_2 = stake::harvest<StakeCoin, RewardCoin>(&bob_acc, @harvest);
        let amount_1 = coin::value(&rewards_1);
        let amount_2 = coin::value(&rewards_2);

        coin::register<RewardCoin>(&alice_acc);
        coin::register<RewardCoin>(&bob_acc);
        coin::deposit(@alice, rewards_1);
        coin::deposit(@bob, rewards_2);

        assert!(amount_1 == 403299999900, 1);
        assert!(amount_2 == 201799999800, 1);

        // 0.0003 RewardCoin lost during calculations
        let total_rewards = (WEEK_IN_SECONDS + 300) * 1000000;
        let total_earned = amount_1 + amount_2;
        let losed_rewards =  total_rewards - total_earned;
        assert!(losed_rewards == 300, 1);
    }

    #[test]
    public fun test_boosted_amount_calculation() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);
        let bob_acc = new_account_with_stake_coins(@bob, 1500000000);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft_1 = create_token(&collection_owner, collection_name, string::utf8(b"Token 1"));
        let nft_2 = create_token(&collection_owner, collection_name, string::utf8(b"Token 2"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            1
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);

        // boost alice stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft_1);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 5000000, 1);
        assert!(user_boosted == 5000000, 1);

        // stake 10 StakeCoin from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 10000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 5100000, 1);
        assert!(user_boosted == 5100000, 1);

        // stake 800 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 800000000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        // boost bob stake with nft
        stake::boost<StakeCoin, RewardCoin>(&bob_acc, @harvest, nft_2);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(total_boosted == 13100000, 1);
        assert!(user_boosted == 8000000, 1);

        // remove boost from bob
        let nft_2 = stake::remove_boost<StakeCoin, RewardCoin>(&bob_acc, @harvest);
        token::deposit_token(&bob_acc, nft_2);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @bob);
        assert!(total_boosted == 5100000, 1);
        assert!(user_boosted == 0, 1);

        // wait one week to unstake
        timestamp::update_global_time_for_test_secs(START_TIME + WEEK_IN_SECONDS);

        // unstake 255 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 255000000);
        coin::deposit(@alice, coins);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 2550000, 1);
        assert!(user_boosted == 2550000, 1);

        // unstake 255 StakeCoins from alice
        let coins =
            stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 255000000);
        coin::deposit(@alice, coins);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);
    }

    // todo: update this test after PR35 merge
    #[test]
    public fun test_is_boostable() {
        let (harvest, _) = initialize_test();

        let collection_name = string::utf8(b"Test Collection");
        create_collecton(@collection_owner, collection_name);

        // register staking pool 1 with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            100
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // register staking pool 2 with rewards no boost config
        let reward_coins = mint_default_coin<StakeCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<RewardCoin, StakeCoin>(&harvest, reward_coins, duration, option::none());

        // check is boostable
        assert!(stake::is_boostable<StakeCoin, RewardCoin>(@harvest), 1);
        assert!(!stake::is_boostable<RewardCoin, StakeCoin>(@harvest), 1);
    }

    #[test]
    public fun test_is_boosted() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 500000000);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft_1 = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            100
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        assert!(!stake::is_boosted<StakeCoin, RewardCoin>(@harvest, @alice), 1);

        // boost alice stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft_1);

        assert!(stake::is_boosted<StakeCoin, RewardCoin>(@harvest, @alice), 1);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_boost_fails_if_pool_does_not_exist() {
        let (harvest, _) = initialize_test();

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        stake::boost<StakeCoin, RewardCoin>(&harvest, @harvest, nft);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_remove_boost_fails_if_pool_does_not_exist() {
        let (harvest, _) = initialize_test();

        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&harvest, @harvest);
        token::deposit_token(&harvest, nft);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_is_boostable_fails_if_pool_does_not_exist() {
        stake::is_boostable<StakeCoin, RewardCoin>(@harvest);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_boost_config_fails_if_pool_does_not_exist() {
        stake::get_boost_config<StakeCoin, RewardCoin>(@harvest);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_pool_total_boosted_fails_if_pool_does_not_exist() {
        stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_is_boosted_fails_if_pool_does_not_exist() {
        stake::is_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_user_boosted_fails_if_pool_does_not_exist() {
        stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_boost_fails_if_stake_does_not_exist() {
        let (harvest, _) = initialize_test();

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token 1"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        stake::boost<StakeCoin, RewardCoin>(&harvest, @harvest, nft);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_remove_boost_fails_if_stake_does_not_exist() {
        let (harvest, _) = initialize_test();

        let collection_name = string::utf8(b"Test Collection");
        create_collecton(@collection_owner, collection_name);

        // register staking pool with rewards
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());

        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&harvest, @harvest);
        token::deposit_token(&harvest, nft);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_is_boosted_fails_if_stake_not_exists() {
        let (harvest, _) = initialize_test();

        // register staking pool with rewards
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());

        stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NO_STAKE */)]
    public fun test_get_user_boosted_fails_if_stake_not_exists() {
        let (harvest, _) = initialize_test();

        // register staking pool with rewards
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());

        stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
    }

    #[test]
    #[expected_failure(abort_code = 116 /* ERR_NO_COLLECTION */)]
    public fun test_create_boost_config_fails_if_colleciont_does_not_exist_1() {
        let (harvest, _) = initialize_test();

        create_collecton(@collection_owner, string::utf8(b"Test Collection"));

        let boost_config = stake::create_boost_config(
            @collection_owner,
            string::utf8(b"Wrong Collection"),
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, coin::zero<RewardCoin>(), 12345, option::some(boost_config));
    }

    #[test]
    #[expected_failure(abort_code = 0x60001 /* ECOLLECTIONS_NOT_PUBLISHED token.move */)]
    public fun test_create_boost_config_fails_if_colleciont_does_not_exist_2() {
        let (harvest, _) = initialize_test();

        let boost_config = stake::create_boost_config(
            @collection_owner,
            string::utf8(b"Test Collection"),
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, coin::zero<RewardCoin>(), 12345, option::some(boost_config));
    }

    #[test]
    #[expected_failure(abort_code = 117 /* ERR_INVALID_BOOST_PERCENT */)]
    public fun test_create_boost_config_fails_if_boost_percent_less_then_min() {
        let (harvest, _) = initialize_test();

        let collection_name = string::utf8(b"Test Collection");
        create_collecton(@collection_owner, collection_name);

        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            0
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, coin::zero<RewardCoin>(), 12345, option::some(boost_config));
    }

    #[test]
    #[expected_failure(abort_code = 117 /* ERR_INVALID_BOOST_PERCENT */)]
    public fun test_create_boost_config_fails_if_boost_percent_more_then_max() {
        let (harvest, _) = initialize_test();

        let collection_name = string::utf8(b"Test Collection");
        create_collecton(@collection_owner, collection_name);

        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            101
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, coin::zero<RewardCoin>(), 12345, option::some(boost_config));
    }

    #[test]
    #[expected_failure(abort_code = 118 /* ERR_NON_BOOST_POOL */)]
    public fun test_boost_fails_when_non_boost_pool() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 500000000);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
    }

    #[test]
    #[expected_failure(abort_code = 118 /* ERR_NON_BOOST_POOL */)]
    public fun test_get_boost_config_fails_when_non_boost_pool() {
        let (harvest, _) = initialize_test();

        // register staking pool with rewards
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());

        stake::get_boost_config<StakeCoin, RewardCoin>(@harvest);
    }

    #[test]
    #[expected_failure(abort_code = 119 /* ERR_ALREADY_BOOSTED */)]
    public fun test_boost_fails_if_already_boosted() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let nft_1 = create_token(&collection_owner, collection_name, string::utf8(b"Token 1"));
        let nft_2 = create_token(&collection_owner, collection_name, string::utf8(b"Token 2"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // boost stake with nft twice
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft_1);
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft_2);
    }

    #[test]
    #[expected_failure(abort_code = 120 /* ERR_WRONG_TOKEN_COLLECTION */)]
    public fun test_boost_fails_if_token_from_wrong_collection_1() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

        let collection_name_1 = string::utf8(b"Test Collection 1");
        let collection_name_2 = string::utf8(b"Test Collection 2");
        let collection_owner = create_collecton(@collection_owner, collection_name_1);
        create_collecton(@collection_owner, collection_name_2);
        let nft = create_token(&collection_owner, collection_name_2, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name_1,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
    }

    #[test]
    #[expected_failure(abort_code = 120 /* ERR_WRONG_TOKEN_COLLECTION */)]
    public fun test_boost_fails_if_token_from_wrong_collection_2() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        create_collecton(@bob, collection_name);
        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @bob,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
    }

    #[test]
    #[expected_failure(abort_code = 121 /* ERR_NOTHING_TO_CLAIM */)]
    public fun test_remove_boost_fails_when_executed_with_non_boost_pool() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // remove boost
        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        token::deposit_token(&alice_acc, nft);
    }

    #[test]
    #[expected_failure(abort_code = 121 /* ERR_NOTHING_TO_CLAIM */)]
    public fun test_remove_boost_fails_if_executed_before_boost() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

        let collection_name = string::utf8(b"Test Collection");
        create_collecton(@collection_owner, collection_name);

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            5
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // remove boost
        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        token::deposit_token(&alice_acc, nft);
    }

    #[test]
    #[expected_failure(abort_code = 121 /* ERR_NOTHING_TO_CLAIM */)]
    public fun test_remove_boost_fails_when_executed_twice() {
        let (harvest, _) = initialize_test();
        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

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
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);

        // boost stake with nft
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);

        // remove nft boost twice
        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        token::deposit_token(&alice_acc, nft);
        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        token::deposit_token(&alice_acc, nft);
    }

    #[test]
    #[expected_failure(abort_code = 122 /* ERR_NFT_AMOUNT_MORE_THAN_ONE */)]
    public fun test_boost_fails_if_amount_more_than_one() {
        let (harvest, _) = initialize_test();
        let bob_acc = new_account_with_stake_coins(@bob, 1000);

        let collection_name = string::utf8(b"Test Collection");
        let collection_owner = create_collecton(@collection_owner, collection_name);
        let token_name = string::utf8(b"Token");

        token::create_token_script(
            &collection_owner,
            collection_name,
            token_name,
            string::utf8(b"Some Description"),
            2,
            2,
            string::utf8(b"https://aptos.dev"),
            @collection_owner,
            100,
            0,
            vector<bool>[ false, false, false, false, false, false ],
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
        );
        let token_id = token::create_token_id_raw(@collection_owner, collection_name, token_name, 0);
        let nft = token::withdraw_token(&collection_owner, token_id, 2);

        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            collection_name,
            1
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));

        // stake 800 StakeCoins from bob
        let coins =
            coin::withdraw<StakeCoin>(&bob_acc, 1000);
        stake::stake<StakeCoin, RewardCoin>(&bob_acc, @harvest, coins);

        stake::boost<StakeCoin, RewardCoin>(&bob_acc, @harvest, nft);
    }
}
