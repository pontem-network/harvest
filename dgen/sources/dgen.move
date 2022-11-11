/// Liquidswap DGEN coin module.
module dgen_admin::dgen {
    use std::signer;
    use std::string;

    use aptos_framework::coin::{Self, BurnCapability, Coin};

    // Errors.

    /// only creator can execute
    const ERR_NO_PERMISSIONS: u64 = 100;

    /// coin does not exist
    const ERR_NO_COIN: u64 = 101;

    /// 100 millions total DGEN supply
    const TOTAL_SUPPLY: u64 = 100000000000000;

    // Resources.

    /// DGEN coin
    struct DGEN {}

    /// burn capabilities for DGEN COIN
    struct DGENCapabilities has key { burn_cap: BurnCapability<DGEN> }

    // Functions.

    /// Initializes DGEN coin, making total supply premint for owner.
    /// * `dgen_owner` - deployer of the module.
    public entry fun initialize(dgen_owner: &signer) {
        let dgen_owner_addr = signer::address_of(dgen_owner);
        assert!(dgen_owner_addr == @dgen_admin, ERR_NO_PERMISSIONS);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<DGEN>(
            dgen_owner,
            string::utf8(b"Liquidswap DGEN"),
            string::utf8(b"DGEN"),
            6,
            true
        );

        let pre_mint_coins = coin::mint(TOTAL_SUPPLY, &mint_cap);
        coin::register<DGEN>(dgen_owner);
        coin::deposit(dgen_owner_addr, pre_mint_coins);

        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);

        move_to(dgen_owner, DGENCapabilities { burn_cap });
    }

    /// Burns provided DGEN coins.
    /// * `coins` - DGEN coins to burn.
    /// Returns burned amount of DGEN coins.
    public fun burn(coins: Coin<DGEN>): u64 acquires DGENCapabilities {
        assert!(exists<DGENCapabilities>(@dgen_admin), ERR_NO_COIN);

        let amount = coin::value(&coins);
        let cap = borrow_global<DGENCapabilities>(@dgen_admin);

        coin::burn<DGEN>(coins, &cap.burn_cap);
        amount
    }
}
