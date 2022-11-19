#[test_only]
module harvest::stake_nft_boost_tests {
    use std::string::{Self, String};
    use std::bcs;

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;
    use aptos_token::token;
    use harvest::stake;
    use harvest::stake_config;
    use harvest::stake_test_helpers::{new_account, initialize_reward_coin, initialize_stake_coin, /*mint_default_coins,*/ StakeCoin, RewardCoin, new_account_with_stake_coins};
    use aptos_token::token::Token;

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

        // let balance = token::balance_of(@collection_owner, token_id);
        // std::debug::print(&balance);

        // let token_data_id = token::create_token_data_id(
        //     @collection_owner,
        //     string::utf8(b"Test collection"),
        //     string::utf8(b"Hello, Token"));

        // std::debug::print(&token_data_id);
        // let token_id = token::mint_token(
        //     &collection_owner,
        //     token_data_id,
        //     1,
        // );
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
        stake::register_pool<StakeCoin, RewardCoin>(&alice_acc, reward_per_sec_rate, @0x0, string::utf8(b""), 0);
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
        stake::register_pool<StakeCoin, RewardCoin>(&harvest, 1000000, @collection_owner, string::utf8(b"Test collection"), 5);

        // stake 500 StakeCoins from alice
        let coins =
            coin::withdraw<StakeCoin>(&alice_acc, 500000000);
        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);

        // wait 10 seconds
        timestamp::update_global_time_for_test_secs(start_time + 10);

        let pending_rewards = stake::get_pending_user_rewards<StakeCoin, RewardCoin>(@harvest, @alice);
        assert!(pending_rewards == 9999675, 1);
    }
}