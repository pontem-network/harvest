#[test_only]
module harvest::stake_nft_boost_tests {
    use std::option;
    use std::string::{Self, String};

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use aptos_token::token::{Self, Token};

    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_test_helpers::{new_account, initialize_reward_coin, initialize_stake_coin, StakeCoin, RewardCoin, new_account_with_stake_coins, mint_default_coin};

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    const START_TIME: u64 = 682981200;

    const MIN_NFT_BOOST_PRECENT: u64 = 1;

    const MAX_NFT_BOOST_PERCENT: u64 = 100;

    // todo: add test which checks calculations with different boost percents

    public fun initialize_test(): (signer, signer) {
        genesis::setup();

        timestamp::update_global_time_for_test_secs(START_TIME);

        let harvest = new_account(@harvest);

        // create coins for pool to be valid
        initialize_reward_coin(&harvest, 6);
        initialize_stake_coin(&harvest, 6);

        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::initialize(&emergency_admin, @treasury);
        (harvest, emergency_admin)
    }

    public fun create_collecton(collection_name: String): signer {
        let collection_owner = new_account(@collection_owner);

        token::create_collection(
            &collection_owner,
            collection_name,
            string::utf8(b"Some Description"),
            string::utf8(b"https"),
            50,
            vector<bool>[false, false, false]
        );

        collection_owner
    }

    public fun create_token(collection_owner: signer, name: String): Token {
        let default_keys = vector<String>[];
        let default_vals = vector<vector<u8>>[];
        let default_types = vector<String>[];
        let mutate_setting = vector<bool>[ false, false, false, false, false, false ];

        token::create_token_script(
            &collection_owner,
            string::utf8(b"Test Collection"),
            name,
            string::utf8(b"Hello, Token"),
            1,
            1,
            string::utf8(b"https://aptos.dev"),
            @collection_owner,
            100,
            0,
            mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );
        let token_id = token::create_token_id_raw(@collection_owner, string::utf8(b"Test Collection"), name, 0);

        token::withdraw_token(&collection_owner, token_id, 1)
    }

    #[test]
    public fun test_register_with_boost_config() {
        initialize_test();

        let alice_acc = new_account(@alice);
        let collection_name = string::utf8(b"Test Collection");
        let _ = create_collecton(collection_name);

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
        let (boost_percent, collection_owner_addr, coll_name) =
            stake::get_boost_config<StakeCoin, RewardCoin>(@alice);
        assert!(boost_percent == 5, 1);
        assert!(collection_owner_addr == @collection_owner, 1);
        assert!(coll_name == collection_name, 1);
    }

    #[test]
    public fun test_boost() {
        let (harvest, _) = initialize_test();
        let collection_owner = create_collecton(string::utf8(b"Test Collection"));
        let nft = create_token(collection_owner, string::utf8(b"Token 1"));

        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            string::utf8(b"Test Collection"),
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

        // claim nft
        let nft = stake::claim<StakeCoin, RewardCoin>(&alice_acc, @harvest);
        token::deposit_token(&alice_acc, nft);

        // check values
        let total_boosted = stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(total_boosted == 0, 1);
        assert!(user_boosted == 0, 1);
    }

    #[test]
    public fun test_get_pool_total_boosted() {
        let (harvest, _) = initialize_test();
        let collection_owner = create_collecton(string::utf8(b"Test Collection"));
        let nft = create_token(collection_owner, string::utf8(b"Token 1"));

        let alice_acc = new_account_with_stake_coins(@alice, 500000000);

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            string::utf8(b"Test Collection"),
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
        let user_boosted = stake::get_user_boosted<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(user_boosted == 25000000, 1);
    }

    #[test]
    public fun test_get_user_boosted() {
        let (harvest, _) = initialize_test();
        let collection_owner = create_collecton(string::utf8(b"Test Collection"));
        let nft = create_token(collection_owner, string::utf8(b"Token 1"));

        let alice_acc = new_account_with_stake_coins(@alice, 500000000);

        // register staking pool with rewards and boost config
        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
        let duration = 15768000;
        let boost_config = stake::create_boost_config(
            @collection_owner,
            string::utf8(b"Test Collection"),
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
        assert!(total_boosted == 25000000, 1);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_pool_total_boosted_fails_if_pool_does_not_exist() {
        stake::get_pool_total_boosted<StakeCoin, RewardCoin>(@harvest);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_user_boosted_fails_if_pool_does_not_exist() {
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
        let _ = create_collecton(string::utf8(b"Test Collection"));

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
        let _ = create_collecton(string::utf8(b"Test Collection"));

        let boost_config = stake::create_boost_config(
            @collection_owner,
            string::utf8(b"Test Collection"),
            0
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, coin::zero<RewardCoin>(), 12345, option::some(boost_config));
    }

    #[test]
    #[expected_failure(abort_code = 117 /* ERR_INVALID_BOOST_PERCENT */)]
    public fun test_create_boost_config_fails_if_boost_percent_more_then_max() {
        let (harvest, _) = initialize_test();
        let _ = create_collecton(string::utf8(b"Test Collection"));

        let boost_config = stake::create_boost_config(
            @collection_owner,
            string::utf8(b"Test Collection"),
            101
        );
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, coin::zero<RewardCoin>(), 12345, option::some(boost_config));
    }
}
