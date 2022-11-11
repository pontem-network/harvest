#[test_only]
module dgen_admin::dgen_tests {
    use std::option;
    use std::string;

    use aptos_framework::account;
    use aptos_framework::coin;

    use dgen_admin::dgen::{Self, DGEN};

    // 100 millions total DGEN supply.
    const TOTAL_SUPPLY: u64 = 100000000000000;

    #[test]
    public fun test_initialize() {
        let dgen_admin = account::create_account_for_test(@dgen_admin);

        // initialize new coin
        dgen::initialize(&dgen_admin);

        // check coin parameters
        assert!(coin::is_coin_initialized<DGEN>(), 1);
        assert!(coin::name<DGEN>() == string::utf8(b"Liquidswap DGEN"), 1);
        assert!(coin::symbol<DGEN>() == string::utf8(b"DGEN"), 1);
        assert!(coin::decimals<DGEN>() == 6, 1);

        // check supply and creator balance
        assert!(option::extract(&mut coin::supply<DGEN>()) == (TOTAL_SUPPLY as u128), 1);
        assert!(coin::balance<DGEN>(@dgen_admin) == TOTAL_SUPPLY, 1);
    }

    #[test]
    public fun test_burn() {
        let dgen_admin = account::create_account_for_test(@dgen_admin);
        let alice = account::create_account_for_test(@alice);

        // initialize new coin
        dgen::initialize(&dgen_admin);

        // send 2 million coins to alice
        coin::register<DGEN>(&alice);
        coin::transfer<DGEN>(&dgen_admin, @alice, 2000000000000);

        // check balances
        assert!(coin::balance<DGEN>(@dgen_admin) == 98000000000000, 1);
        assert!(coin::balance<DGEN>(@alice) == 2000000000000, 1);

        // burn all from alice
        let coins = coin::withdraw<DGEN>(&alice, 2000000000000);
        dgen::burn(coins);

        // burn some from creator
        let coins = coin::withdraw<DGEN>(&dgen_admin, 5000000000000);
        dgen::burn(coins);

        // check balances and supply
        assert!(coin::balance<DGEN>(@dgen_admin) == 93000000000000, 1);
        assert!(coin::balance<DGEN>(@alice) == 0, 1);
        assert!(option::extract(&mut coin::supply<DGEN>()) == 93000000000000u128, 1);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_PERMISSIONS */)]
    public fun test_initialize_fails_if_executed_not_by_coin_owner() {
        let alice = account::create_account_for_test(@alice);
        // initialize coin from wrong account
        dgen::initialize(&alice);
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_NO_COIN */)]
    public fun test_burn_fails_if_executed_before_initialization() {
        // burn before initialization
        dgen::burn(coin::zero<DGEN>());
    }

    #[test]
    #[expected_failure(abort_code = 524290)]
    public fun test_initialize_fails_if_executed_twice() {
        let dgen_admin = account::create_account_for_test(@dgen_admin);

        // initialize new coin
        dgen::initialize(&dgen_admin);
        dgen::initialize(&dgen_admin);
    }
}
