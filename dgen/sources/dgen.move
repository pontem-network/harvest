/// Liquidswap DGEN coin module.
module dgen_coin::dgen {
    use std::signer;
    use std::string;

    use aptos_framework::coin::{Self, BurnCapability, Coin};

    // Errors.

    /// Only creator can execute.
    const ERR_NO_PERMISSIONS: u64 = 300;

    /// DGEN coin does not exist.
    const ERR_NO_COIN: u64 = 301;

    /// 100 millions total DGEN supply.
    const TOTAL_SUPPLY: u64 = 100000000000000;

    // Resources.

    /// DGEN coin.
    struct DGEN {}

    /// Burn capability for DGEN COIN.
    struct DGENCapabilities has key { burn_cap: BurnCapability<DGEN> }

    // Functions.

    /// Initializes DGEN coin, making total supply premint for owner.
    ///     * `dgen_admin` - deployer of the module.
    public entry fun initialize(dgen_admin: &signer) {
        let dgen_admin_addr = signer::address_of(dgen_admin);
        assert!(dgen_admin_addr == @dgen_coin, ERR_NO_PERMISSIONS);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<DGEN>(
            dgen_admin,
            string::utf8(b"Liquidswap DGEN"),
            string::utf8(b"DGEN"),
            6,
            true
        );

        let pre_mint_coins = coin::mint(TOTAL_SUPPLY, &mint_cap);
        coin::register<DGEN>(dgen_admin);
        coin::deposit(dgen_admin_addr, pre_mint_coins);

        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);

        move_to(dgen_admin, DGENCapabilities { burn_cap });
    }

    /// Burns provided DGEN coins.
    ///     * `coins` - DGEN coins to burn.
    /// Returns burned amount of DGEN coins.
    public fun burn(coins: Coin<DGEN>): u64 acquires DGENCapabilities {
        assert!(exists<DGENCapabilities>(@dgen_coin), ERR_NO_COIN);

        let amount = coin::value(&coins);
        let cap = borrow_global<DGENCapabilities>(@dgen_coin);

        coin::burn<DGEN>(coins, &cap.burn_cap);
        amount
    }
}
