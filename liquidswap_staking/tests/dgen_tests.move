#[test_only]
module dgen_owner::dgen_tests {
    use std::option;
    use std::string;

    use aptos_framework::coin;

    use dgen_owner::dgen::{Self, DGEN};
    use dgen_owner::lovely_helpers::{create_account, to_u128};

    // 100 millions total DGEN supply.
    const TOTAL_SUPPLY: u64 = 100000000000000;

    #[test(dgen_owner = @dgen_owner)]
    public fun test_initialize(dgen_owner: &signer) {
        let (dgen_owner_acc, dgen_owner_addr) = create_account(dgen_owner);

        // initialize new coin
        dgen::initialize(&dgen_owner_acc);

        // check coin parameters
        assert!(coin::is_coin_initialized<DGEN>(), 1);
        assert!(coin::name<DGEN>() == string::utf8(b"Liquidswap DGEN"), 1);
        assert!(coin::symbol<DGEN>() == string::utf8(b"DGEN"), 1);
        assert!(coin::decimals<DGEN>() == 6, 1);

        // check supply and creator balance
        assert!(option::extract(&mut coin::supply<DGEN>()) == to_u128(TOTAL_SUPPLY), 1);
        assert!(coin::balance<DGEN>(dgen_owner_addr) == TOTAL_SUPPLY, 1);
    }

    #[test(dgen_owner = @dgen_owner, alice = @alice)]
    public fun test_burn(dgen_owner: &signer, alice: &signer) {
        let (dgen_owner_acc, dgen_owner_addr) = create_account(dgen_owner);
        let (alice_acc, alice_addr) = create_account(alice);

        // initialize new coin
        dgen::initialize(&dgen_owner_acc);

        // send 2 million coins to alice
        coin::register<DGEN>(&alice_acc);
        coin::transfer<DGEN>(&dgen_owner_acc, alice_addr, 2000000000000);

        // check balances
        assert!(coin::balance<DGEN>(dgen_owner_addr) == 98000000000000, 1);
        assert!(coin::balance<DGEN>(alice_addr) == 2000000000000, 1);

        // burn all from alice
        let coins = coin::withdraw<DGEN>(&alice_acc, 2000000000000);
        dgen::burn(coins);

        // burn some from creator
        let coins = coin::withdraw<DGEN>(&dgen_owner_acc, 5000000000000);
        dgen::burn(coins);

        // check balances and supply
        assert!(coin::balance<DGEN>(dgen_owner_addr) == 93000000000000, 1);
        assert!(coin::balance<DGEN>(alice_addr) == 0, 1);
        assert!(option::extract(&mut coin::supply<DGEN>()) == to_u128(93000000000000), 1);
    }

    #[test(alice = @alice)]
    #[expected_failure(abort_code = 100 /* ERR_NO_PERMISSIONS */)]
    public fun test_initialize_fails_if_executed_not_by_coin_owner(alice: &signer) {
        let (alice_acc, _) = create_account(alice);

        // initialize coin from wrong account
        dgen::initialize(&alice_acc);
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_NO_COIN */)]
    public fun test_burn_fails_if_executed_before_initialization() {
        // burn before initialization
        dgen::burn(coin::zero<DGEN>());
    }

    #[test(dgen_owner = @dgen_owner)]
    #[expected_failure(abort_code=524290)]
    public fun test_initialize_fails_if_executed_twice(dgen_owner: &signer) {
        let (dgen_owner_acc, _) = create_account(dgen_owner);

        // initialize new coin
        dgen::initialize(&dgen_owner_acc);
        dgen::initialize(&dgen_owner_acc);
    }
}
