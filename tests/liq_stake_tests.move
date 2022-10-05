#[test_only]
module staking_admin::staking_tests {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin;

    use coin_creator::liq::{Self, LIQ};
    use staking_admin::staking;

    public fun create_account(account_address: address): (signer, address) {
        let new_acc = account::create_account_for_test(account_address);
        let new_addr = signer::address_of(&new_acc);

        (new_acc, new_addr)
    }

    public fun create_account_with_liq_coins(
        account_address: address,
        liq_amount: u64,
        coin_creator_acc: &signer
    ): (signer, address) {
        let (new_acc, new_addr) = create_account(account_address);
        let coins = liq::mint(coin_creator_acc, liq_amount);

        coin::register<LIQ>(&new_acc);
        coin::deposit<LIQ>(new_addr, coins);

        (new_acc, new_addr)
    }

    public fun create_coin(creator_addr: address): signer {
        let (coin_creator_acc, _) = create_account(creator_addr);

        liq::initialize(&coin_creator_acc);
        coin_creator_acc
    }

    #[test]
    public fun test_stake_and_unstake() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // create coin
        let coin_creator_acc = create_coin(@coin_creator);

        // mint coins for alice and bob
        let (alice_acc, alice_addr) =
            create_account_with_liq_coins(@0x10, 150, &coin_creator_acc);
        let (bob_acc, bob_addr) =
            create_account_with_liq_coins(@0x11, 40, &coin_creator_acc);

        // initialize staking pool
        staking::initialize<LIQ>(&staking_admin_acc);

        // check empty balances
        assert!(staking::get_total_stake<LIQ>() == 0, 1);
        assert!(staking::get_user_stake<LIQ>(alice_addr) == 0, 1);
        assert!(staking::get_user_stake<LIQ>(bob_addr) == 0, 1);

        // stake from alice
        let coins = coin::withdraw<LIQ>(&alice_acc, 33);
        staking::stake<LIQ>(&alice_acc, coins);
        assert!(coin::balance<LIQ>(alice_addr) == 117, 1);
        assert!(staking::get_user_stake<LIQ>(alice_addr) == 33, 1);
        assert!(staking::get_total_stake<LIQ>() == 33, 1);

        // stake from bob
        let coins = coin::withdraw<LIQ>(&bob_acc, 40);
        staking::stake<LIQ>(&bob_acc, coins);
        assert!(coin::balance<LIQ>(bob_addr) == 0, 1);
        assert!(staking::get_user_stake<LIQ>(bob_addr) == 40, 1);
        assert!(staking::get_total_stake<LIQ>() == 73, 1);

        // stake more from alice
        let coins = coin::withdraw<LIQ>(&alice_acc, 33);
        staking::stake<LIQ>(&alice_acc, coins);
        assert!(coin::balance<LIQ>(alice_addr) == 84, 1);
        assert!(staking::get_user_stake<LIQ>(alice_addr) == 66, 1);
        assert!(staking::get_total_stake<LIQ>() == 106, 1);

        // unstake some from alice
        let coins = staking::unstake<LIQ>(&alice_acc, 16);
        assert!(coin::value<LIQ>(&coins) == 16, 1);
        assert!(staking::get_user_stake<LIQ>(alice_addr) == 50, 1);
        assert!(staking::get_total_stake<LIQ>() == 90, 1);
        coin::deposit<LIQ>(alice_addr, coins);

        // unstake all from bob
        let coins = staking::unstake<LIQ>(&bob_acc, 40);
        assert!(coin::value<LIQ>(&coins) == 40, 1);
        assert!(staking::get_user_stake<LIQ>(bob_addr) == 0, 1);
        assert!(staking::get_total_stake<LIQ>() == 50, 1);
        coin::deposit<LIQ>(bob_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_stake_fails_if_pool_does_not_exist() {
        // create coin
        let coin_creator_acc= create_coin(@coin_creator);

        // mint coins for alice
        let (alice_acc, _) =
            create_account_with_liq_coins(@0x10, 150, &coin_creator_acc);

        // stake from alice
        let coins = coin::withdraw<LIQ>(&alice_acc, 33);
        staking::stake<LIQ>(&alice_acc, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_unstake_fails_if_pool_does_not_exist() {
        let (alice_acc, alice_addr) = create_account(@0x10);

        // unstake from alice
        let coins = staking::unstake<LIQ>(&alice_acc, 100);
        coin::deposit<LIQ>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_total_stake_fails_if_pool_does_not_exist() {
        staking::get_total_stake<LIQ>();
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_user_stake_fails_if_pool_does_not_exist() {
        let (_, alice_addr) = create_account(@0x10);

        staking::get_user_stake<LIQ>(alice_addr);
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_POOL_ALREADY_EXISTS */)]
    public fun test_initialize_fails_if_pool_already_exists() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // initialize staking pool twice
        staking::initialize<LIQ>(&staking_admin_acc);
        staking::initialize<LIQ>(&staking_admin_acc);
    }

    #[test]
    #[expected_failure(abort_code = 102 /* ERR_NO_STAKE */)]
    public fun test_unstake_fails_if_stake_not_exists() {
        let (staking_admin_acc, _) = create_account(@staking_admin);
        let (alice_acc, alice_addr) = create_account(@0x10);

        // initialize staking pool
        staking::initialize<LIQ>(&staking_admin_acc);

        // unstake from alice
        let coins = staking::unstake<LIQ>(&alice_acc, 40);
        coin::deposit<LIQ>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NOT_ENOUGHT_BALANCE */)]
    public fun test_unstake_fails_if_not_enough_balance() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // create coin
        let coin_creator_acc = create_coin(@coin_creator);

        // mint coins for alice
        let (alice_acc, alice_addr) =
            create_account_with_liq_coins(@0x10, 150, &coin_creator_acc);

        // initialize staking pool
        staking::initialize<LIQ>(&staking_admin_acc);

        // stake from alice
        let coins = coin::withdraw<LIQ>(&alice_acc, 150);
        staking::stake<LIQ>(&alice_acc, coins);
        assert!(coin::balance<LIQ>(alice_addr) == 0, 1);
        assert!(staking::get_user_stake<LIQ>(alice_addr) == 150, 1);

        // unstake more than staked from alice
        let coins = staking::unstake<LIQ>(&alice_acc, 151);
        coin::deposit<LIQ>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 104 /* ERR_NO_PERMISSIONS */)]
    public fun test_initialize_fails_if_executed_not_by_admin() {
        let (alice_acc, _) = create_account(@0x10);

        // initialize staking pool
        staking::initialize<LIQ>(&alice_acc);
    }
}
