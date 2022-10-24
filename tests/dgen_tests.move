#[test_only]
module coin_creator::dgen_tests {
    use std::option;
    use std::signer;
    use std::string;

    use aptos_framework::account;
    use aptos_framework::coin;

    use coin_creator::dgen::{Self, DGEN};

    // multiplier to account six decimal places for DGEN coin
    const ONE_DGEN: u64 = 1000000;

    // 100 millions total DGEN supply
    const TOTAL_SUPPLY: u64 = 100000000000000;

    fun to_u128(num: u64): u128 {
        (num as u128)
    }

    public fun create_account(account_address: address): (signer, address) {
        let new_acc = account::create_account_for_test(account_address);
        let new_addr = signer::address_of(&new_acc);

        (new_acc, new_addr)
    }

    #[test]
    public fun test_initialize() {
        let (creator_acc, creator_addr) = create_account(@coin_creator);

        // initialize new coin
        dgen::initialize(&creator_acc);

        // check coin parameters
        assert!(coin::is_coin_initialized<DGEN>(), 1);
        assert!(coin::name<DGEN>() == string::utf8(b"Liquidswap DGEN"), 1);
        assert!(coin::symbol<DGEN>() == string::utf8(b"DGEN"), 1);
        assert!(coin::decimals<DGEN>() == 6, 1);

        // check supply and creator balance
        assert!(option::extract(&mut coin::supply<DGEN>()) == to_u128(TOTAL_SUPPLY), 1);
        assert!(coin::balance<DGEN>(creator_addr) == TOTAL_SUPPLY, 1);
    }

    #[test]
    public fun test_burn() {
        let (creator_acc, creator_addr) = create_account(@coin_creator);
        let (alice_acc, alice_addr) = create_account(@0x10);

        // initialize new coin
        dgen::initialize(&creator_acc);

        // send 2 million coins to alice
        coin::register<DGEN>(&alice_acc);
        coin::transfer<DGEN>(&creator_acc, alice_addr, 2000000 * ONE_DGEN);

        // check balances
        assert!(coin::balance<DGEN>(creator_addr) == 98000000 * ONE_DGEN, 1);
        assert!(coin::balance<DGEN>(alice_addr) == 2000000 * ONE_DGEN, 1);

        // burn all from alice
        let coins = coin::withdraw<DGEN>(&alice_acc,2000000 * ONE_DGEN);
        dgen::burn(coins);

        // burn some from creator
        let coins = coin::withdraw<DGEN>(&creator_acc,5000000 * ONE_DGEN);
        dgen::burn(coins);

        // check balances and supply
        assert!(coin::balance<DGEN>(creator_addr) == 93000000 * ONE_DGEN, 1);
        assert!(coin::balance<DGEN>(alice_addr) == 0, 1);
        assert!(option::extract(&mut coin::supply<DGEN>()) == to_u128(93000000 * ONE_DGEN), 1);
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
