#[test_only]
module staking_admin::staking_tests {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::genesis;
    use liquidswap::curves::Uncorrelated;
    use liquidswap::liquidity_pool;
    use liquidswap_lp::lp_coin::LP;
    use test_coins::coins::{Self, USDT, BTC};
    use test_helpers::test_pool;

    use staking_admin::staking;

    public fun create_account(account_address: address): (signer, address) {
        let new_acc = account::create_account_for_test(account_address);
        let new_addr = signer::address_of(&new_acc);

        (new_acc, new_addr)
    }

    public fun mint_9000_lp_coins(): Coin<LP<BTC, USDT, Uncorrelated>> {
        let (coins_owner_acc, coins_owner_addr) = create_account(@test_coins);
        let (lp_owner, _) = create_account(@0x42);

        coins::register_coins(&coins_owner_acc);

        genesis::setup();
        test_pool::initialize_liquidity_pool();

        // create a new pool in Liquidswap
        liquidity_pool::register<BTC, USDT, Uncorrelated>(&lp_owner);

        // mint coins for LP
        coin::register<BTC>(&coins_owner_acc);
        coin::register<USDT>(&coins_owner_acc);
        coins::mint_coin<BTC>(&coins_owner_acc, coins_owner_addr, 10000);
        coins::mint_coin<USDT>(&coins_owner_acc, coins_owner_addr, 10000);

        let coin_btc = coin::withdraw<BTC>(&coins_owner_acc, 10000);
        let coin_usdt = coin::withdraw<USDT>(&coins_owner_acc, 10000);

        // get LP coins
        let amount = test_pool::mint_liquidity<BTC, USDT, Uncorrelated>(&lp_owner, coin_btc, coin_usdt);
        coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&lp_owner, amount)
    }

    public fun create_account_with_lp_coins(
        account_address: address,
        coins: Coin<LP<BTC, USDT, Uncorrelated>>
    ): (signer, address) {
        let (new_acc, new_addr) = create_account(account_address);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&new_acc);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(new_addr, coins);

        (new_acc, new_addr)
    }

    #[test]
    public fun test_stake_and_unstake() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // create lp coins
        let lp_coin = mint_9000_lp_coins();
        let lp_coin_half = coin::extract(&mut lp_coin, 4500);

        // create alice and bob with LP coins
        let (alice_acc, alice_addr) =
            create_account_with_lp_coins(@0x10, lp_coin);
        let (bob_acc, bob_addr) =
            create_account_with_lp_coins(@0x11, lp_coin_half);

        // initialize staking pool
        staking::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc);

        // check empty balances
        assert!(staking::get_total_stake<BTC, USDT, Uncorrelated>() == 0, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 0, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 0, 1);

        // stake from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 500);
        staking::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 4000, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 500, 1);
        assert!(staking::get_total_stake<BTC, USDT, Uncorrelated>() == 500, 1);

        // stake from bob
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&bob_acc, 4500);
        staking::stake<BTC, USDT, Uncorrelated>(&bob_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(bob_addr) == 0, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 4500, 1);
        assert!(staking::get_total_stake<BTC, USDT, Uncorrelated>() == 5000, 1);

        // stake more from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 500);
        staking::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 3500, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 1000, 1);
        assert!(staking::get_total_stake<BTC, USDT, Uncorrelated>() == 5500, 1);

        // unstake some from alice
        let coins =
            staking::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 450);
        assert!(coin::value<LP<BTC, USDT, Uncorrelated>>(&coins) == 450, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 550, 1);
        assert!(staking::get_total_stake<BTC, USDT, Uncorrelated>() == 5050, 1);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);

        // unstake all from bob
        let coins =
            staking::unstake<BTC, USDT, Uncorrelated>(&bob_acc, 4500);
        assert!(coin::value<LP<BTC, USDT, Uncorrelated>>(&coins) == 4500, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(bob_addr) == 0, 1);
        assert!(staking::get_total_stake<BTC, USDT, Uncorrelated>() == 550, 1);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(bob_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_stake_fails_if_pool_does_not_exist() {
        // create lp coins
        let lp_coin = mint_9000_lp_coins();

        // create alice with LP coins
        let (alice_acc, _) =
            create_account_with_lp_coins(@0x10, lp_coin);

        // stake from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 123);
        staking::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_unstake_fails_if_pool_does_not_exist() {
        let (alice_acc, alice_addr) = create_account(@0x10);

        // unstake from alice
        let coins =
            staking::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 100);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_total_stake_fails_if_pool_does_not_exist() {
        staking::get_total_stake<BTC, USDT, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_POOL */)]
    public fun test_get_user_stake_fails_if_pool_does_not_exist() {
        let (_, alice_addr) = create_account(@0x10);

        staking::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr);
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_POOL_ALREADY_EXISTS */)]
    public fun test_initialize_fails_if_pool_already_exists() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // initialize staking pool twice
        staking::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc);
        staking::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc);
    }

    #[test]
    #[expected_failure(abort_code = 102 /* ERR_NO_STAKE */)]
    public fun test_unstake_fails_if_stake_not_exists() {
        let (staking_admin_acc, _) = create_account(@staking_admin);
        let (alice_acc, alice_addr) = create_account(@0x10);

        // initialize staking pool
        staking::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc);

        // unstake from alice
        let coins =
            staking::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 40);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 103 /* ERR_NOT_ENOUGHT_BALANCE */)]
    public fun test_unstake_fails_if_not_enough_balance() {
        let (staking_admin_acc, _) = create_account(@staking_admin);

        // create lp coins
        let lp_coin = mint_9000_lp_coins();

        // create alice with LP coins
        let (alice_acc, alice_addr) =
            create_account_with_lp_coins(@0x10, lp_coin);

        // initialize staking pool
        staking::initialize<BTC, USDT, Uncorrelated>(&staking_admin_acc);

        // stake from alice
        let coins =
            coin::withdraw<LP<BTC, USDT, Uncorrelated>>(&alice_acc, 9000);
        staking::stake<BTC, USDT, Uncorrelated>(&alice_acc, coins);
        assert!(coin::balance<LP<BTC, USDT, Uncorrelated>>(alice_addr) == 0, 1);
        assert!(staking::get_user_stake<BTC, USDT, Uncorrelated>(alice_addr) == 9000, 1);

        // unstake more than staked from alice
        let coins =
            staking::unstake<BTC, USDT, Uncorrelated>(&alice_acc, 9001);
        coin::deposit<LP<BTC, USDT, Uncorrelated>>(alice_addr, coins);
    }

    #[test]
    #[expected_failure(abort_code = 104 /* ERR_NO_PERMISSIONS */)]
    public fun test_initialize_fails_if_executed_not_by_admin() {
        let (alice_acc, _) = create_account(@0x10);

        // initialize staking pool
        staking::initialize<BTC, USDT, Uncorrelated>(&alice_acc);
    }
}
