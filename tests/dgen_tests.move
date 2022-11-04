#[test_only]
module harvest::dgen_tests {
    use std::option;
    use std::signer;
    use std::string;

    use aptos_framework::account;
    use aptos_framework::coin;

    use harvest::dgen::{Self, DGEN};
    use harvest::staking_test_helpers::{create_account, to_u128};

    // 100 millions total DGEN supply.
    const TOTAL_SUPPLY: u64 = 100000000000000;

    #[test(harvest = @harvest)]
    public fun test_initialize(harvest: &signer) {
        let harvest_addr = signer::address_of(harvest);
        create_account(harvest_addr);

        // initialize new coin
        dgen::initialize(harvest);

        // check coin parameters
        assert!(coin::is_coin_initialized<DGEN>(), 1);
        assert!(coin::name<DGEN>() == string::utf8(b"Liquidswap DGEN"), 1);
        assert!(coin::symbol<DGEN>() == string::utf8(b"DGEN"), 1);
        assert!(coin::decimals<DGEN>() == 6, 1);

        // check supply and creator balance
        assert!(option::extract(&mut coin::supply<DGEN>()) == to_u128(TOTAL_SUPPLY), 1);
        assert!(coin::balance<DGEN>(harvest_addr) == TOTAL_SUPPLY, 1);
    }

    #[test(harvest = @harvest, alice = @0x10)]
    public fun test_burn(harvest: &signer, alice: &signer) {
        let harvest_addr = signer::address_of(harvest);
        let alice_addr = signer::address_of(alice);

        create_account(harvest_addr);
        create_account(alice_addr);

        // initialize new coin
        dgen::initialize(harvest);

        // send 2 million coins to alice
        coin::register<DGEN>(alice);
        coin::transfer<DGEN>(harvest, alice_addr, 2000000000000);

        // check balances
        assert!(coin::balance<DGEN>(harvest_addr) == 98000000000000, 1);
        assert!(coin::balance<DGEN>(alice_addr) == 2000000000000, 1);

        // burn all from alice
        let coins = coin::withdraw<DGEN>(alice, 2000000000000);
        dgen::burn(coins);

        // burn some from creator
        let coins = coin::withdraw<DGEN>(harvest, 5000000000000);
        dgen::burn(coins);

        // check balances and supply
        assert!(coin::balance<DGEN>(harvest_addr) == 93000000000000, 1);
        assert!(coin::balance<DGEN>(alice_addr) == 0, 1);
        assert!(option::extract(&mut coin::supply<DGEN>()) == to_u128(93000000000000), 1);
    }

    #[test]
    #[expected_failure(abort_code = 100 /* ERR_NO_PERMISSIONS */)]
    public fun test_initialize_fails_if_executed_not_by_coin_creator() {
        let alice_acc = account::create_account_for_test(@0x10);

        // initialize coin from wrong account
        dgen::initialize(&alice_acc);
    }

    #[test]
    #[expected_failure(abort_code = 101 /* ERR_NO_COIN */)]
    public fun test_burn_fails_if_executed_before_initialization() {
        // burn before initialization
        dgen::burn(coin::zero<DGEN>());
    }
}
