#[test_only]
module harvest::stake_nft_boost_tests {
    use std::bcs;
    use std::string::{Self, String};

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use aptos_token::token::{Self, Token};

    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_test_helpers::{new_account, initialize_reward_coin, initialize_stake_coin, StakeCoin, RewardCoin, new_account_with_stake_coins};
    use std::option;

    // week in seconds, lockup period
    const WEEK_IN_SECONDS: u64 = 604800;

    public fun initialize_test(): (signer, signer) {
        genesis::setup();

        let harvest = new_account(@harvest);
        // create coins for pool to be valid
        initialize_reward_coin(&harvest, 6);
        initialize_stake_coin(&harvest, 6);

        let emergency_admin = new_account(@stake_emergency_admin);
        stake_config::initialize(&emergency_admin);
        (harvest, emergency_admin)
    }

    public fun create_collecton(): (signer, Token) {
        let collection_owner = new_account(@collection_owner);

        token::create_collection(
            &collection_owner,
            string::utf8(b"Test collection"),
            string::utf8(b"Collection: Hello, World"),
            string::utf8(b"https"),
            50,
            vector<bool>[false, false, false]
        );

        let default_keys = vector<String>[ string::utf8(b"attack"), string::utf8(b"num_of_use") ];
        let default_vals = vector<vector<u8>>[ bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5) ];
        let default_types = vector<String>[ string::utf8(b"u64"), string::utf8(b"u64") ];
        let mutate_setting = vector<bool>[ false, false, false, false, false, false ];
        token::create_token_script(
            &collection_owner,
            string::utf8(b"Test collection"),
            string::utf8(b"Token"),
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
        let token_id = token::create_token_id_raw(@collection_owner, string::utf8(b"Test collection"), string::utf8(b"Token"), 0);
        let nft = token::withdraw_token(&collection_owner, token_id, 1);

        (collection_owner, nft)
    }

    // todo: check register with different wrong collection params 1,2,3
    #[test]
    public fun test_register() {
        initialize_test();

        let alice_acc = new_account(@alice);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        let reward_per_sec_rate = 1000000;
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, reward_per_sec_rate, option::none());
        // todo: check collection fields
        // check pool statistics
        let (reward_per_sec, accum_reward, last_updated, reward_amount, s_scale) =
            stake::get_pool_info<StakeCoin, RewardCoin>(@alice);
        assert!(reward_per_sec == reward_per_sec_rate, 1);
        assert!(accum_reward == 0, 1);
        assert!(last_updated == start_time, 1);
        assert!(reward_amount == 0, 1);
        assert!(s_scale == 1000000, 1);
        assert!(stake::get_pool_total_stake<StakeCoin, RewardCoin>(@alice) == 0, 1);
    }

    #[test]
    public fun test_boost() {
        let (harvest, _) = initialize_test();
        let (_, nft) = create_collecton();

        let alice_acc = new_account_with_stake_coins(@alice, 1500000000);

        let start_time = 682981200;
        timestamp::update_global_time_for_test_secs(start_time);

        // register staking pool
        let boost_config =
            stake::create_boost_config(@collection_owner, string::utf8(b"Test collection"), 5);
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1000000, option::some(boost_config));

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
        timestamp::update_global_time_for_test_secs(start_time + 10);

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
}